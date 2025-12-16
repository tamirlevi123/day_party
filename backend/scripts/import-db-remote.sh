#!/bin/bash
set -e

# Ensure we have a proper PATH
export PATH="/usr/bin:/bin:/usr/local/bin:$PATH"

cd ~/dayparty/backend

# Check required commands are available
command -v mysql >/dev/null 2>&1 || { echo "[ERROR] mysql command not found. Please install mysql-client."; exit 127; }
command -v mysqldump >/dev/null 2>&1 || { echo "[ERROR] mysqldump command not found. Please install mysql-client."; exit 127; }

echo "[INFO] Stopping application..."
pm2 stop dayparty-api || true

echo "[INFO] Backing up current production database..."
BACKUP_FILE="dayparty-production-backup-$(date +%Y%m%d-%H%M%S).sql"
# Suppress MySQL password warnings (redirect stderr to /dev/null, warnings are harmless)
mysqldump -u PLACEHOLDER_DB_USER -p'PLACEHOLDER_DB_PASSWORD' PLACEHOLDER_DB_NAME > "$BACKUP_FILE" 2>/dev/null || {
    echo "[ERROR] Backup failed"
    exit 1
}
echo "[OK] Backup saved: $BACKUP_FILE"

echo "[INFO] Importing dev database..."

# Check if SQL file exists (transferred directly, not zipped)
SQL_FILE="$HOME/dayparty-dev-export.sql"

# Check if file is UTF-16 or has UTF-8 BOM and convert if needed
if [ -f "$SQL_FILE" ]; then
    FILE_ENCODING=$(file -b "$SQL_FILE" | grep -i "UTF-16" || echo "")
    if [ -n "$FILE_ENCODING" ]; then
        echo "[INFO] SQL file is UTF-16, converting to UTF-8..."
        iconv -f UTF-16LE -t UTF-8 "$SQL_FILE" > "${SQL_FILE}.utf8" 2>/dev/null
        if [ $? -eq 0 ] && [ -s "${SQL_FILE}.utf8" ]; then
            mv "${SQL_FILE}.utf8" "$SQL_FILE"
            echo "[OK] Converted SQL file to UTF-8"
        else
            echo "[WARN] Conversion failed, trying to use file as-is"
        fi
    fi
    
    # Remove UTF-8 BOM if present (first 3 bytes: EF BB BF)
    if [ -f "$SQL_FILE" ]; then
        if head -c 3 "$SQL_FILE" | od -An -tx1 | grep -q "ef bb bf"; then
            echo "[INFO] Removing UTF-8 BOM from SQL file..."
            tail -c +4 "$SQL_FILE" > "${SQL_FILE}.nobom" && mv "${SQL_FILE}.nobom" "$SQL_FILE"
            echo "[OK] Removed BOM"
        fi
    fi
fi

if [ ! -f "$SQL_FILE" ]; then
    echo "[ERROR] SQL file not found at $SQL_FILE"
    echo "[INFO] Checking for alternative locations..."
    ls -lh ~/dayparty-dev-export.sql* 2>/dev/null || echo "[ERROR] No SQL file found"
    exit 1
fi

if [ ! -s "$SQL_FILE" ]; then
    echo "[ERROR] SQL file is empty"
    exit 1
fi

SQL_SIZE=$(wc -c < "$SQL_FILE")
echo "[INFO] SQL file found: $SQL_FILE"
echo "[INFO] SQL file size: $SQL_SIZE bytes"

# Use the SQL file directly
TEMP_SQL="$SQL_FILE"

# Get node count before import
NODE_COUNT_BEFORE=$(mysql -u PLACEHOLDER_DB_USER -p'PLACEHOLDER_DB_PASSWORD' PLACEHOLDER_DB_NAME -N -e "SELECT COUNT(*) FROM nodes;" 2>/dev/null || echo "0")
echo "[INFO] Node count before import: $NODE_COUNT_BEFORE"

# Import the SQL file
echo "[INFO] Importing SQL into database (this may take a few minutes for 14MB file)..."
# Disable foreign key checks and import
mysql -u PLACEHOLDER_DB_USER -p'PLACEHOLDER_DB_PASSWORD' PLACEHOLDER_DB_NAME <<EOF > /tmp/mysql-import-output.log 2>&1
SET FOREIGN_KEY_CHECKS=0;
SET UNIQUE_CHECKS=0;
SET SQL_MODE='NO_AUTO_VALUE_ON_ZERO';
SOURCE $TEMP_SQL;
SET FOREIGN_KEY_CHECKS=1;
SET UNIQUE_CHECKS=1;
EOF
MYSQL_EXIT_CODE=$?

# Filter password warnings from output but keep everything else
grep -v "Using a password" /tmp/mysql-import-output.log > /tmp/mysql-import-filtered.log 2>&1 || true

# Show import output
echo "[INFO] Import output (showing all non-password-warning lines):"
cat /tmp/mysql-import-filtered.log

# Check for critical errors
if grep -qi "ERROR" /tmp/mysql-import-filtered.log; then
    ERROR_COUNT=$(grep -ci "ERROR" /tmp/mysql-import-filtered.log)
    echo "[ERROR] Found $ERROR_COUNT errors during import:"
    grep -i "ERROR" /tmp/mysql-import-filtered.log | head -30
    echo "[ERROR] MySQL import had errors. Exit code: $MYSQL_EXIT_CODE"
    rm -f /tmp/mysql-import-output.log /tmp/mysql-import-filtered.log
    exit 1
fi

# If MySQL exit code indicates failure, exit
if [ $MYSQL_EXIT_CODE -ne 0 ]; then
    echo "[ERROR] MySQL import failed with exit code: $MYSQL_EXIT_CODE"
    echo "[INFO] Full MySQL output:"
    cat /tmp/mysql-import-filtered.log
    rm -f /tmp/mysql-import-output.log /tmp/mysql-import-filtered.log
    exit 1
fi

rm -f /tmp/mysql-import-output.log /tmp/mysql-import-filtered.log

# Verify import worked by checking node count (keep temp file until after verification)
NODE_COUNT_AFTER=$(mysql -u PLACEHOLDER_DB_USER -p'PLACEHOLDER_DB_PASSWORD' PLACEHOLDER_DB_NAME -N -e "SELECT COUNT(*) FROM nodes;" 2>/dev/null || echo "0")
echo "[INFO] Node count after import: $NODE_COUNT_AFTER"

if [ "$NODE_COUNT_AFTER" -le "$NODE_COUNT_BEFORE" ]; then
    echo "[ERROR] Node count did not increase (before: $NODE_COUNT_BEFORE, after: $NODE_COUNT_AFTER)"
    echo "[ERROR] Import failed - data was not imported correctly"
    echo "[INFO] Checking if SQL file contains INSERT statements..."
    # Count actual INSERT statements (not comments) - look for INSERT INTO at start of line or after semicolon
    INSERT_COUNT=$(grep -E "^INSERT INTO|;INSERT INTO" "$TEMP_SQL" 2>/dev/null | grep -i "INSERT INTO.*nodes" | wc -l || echo "0")
    echo "[INFO] Found $INSERT_COUNT INSERT statements for nodes table in SQL file"
    
    # Also check total INSERT statements
    TOTAL_INSERTS=$(grep -E "^INSERT INTO|;INSERT INTO" "$TEMP_SQL" 2>/dev/null | wc -l || echo "0")
    echo "[INFO] Total INSERT statements in SQL file: $TOTAL_INSERTS"
    
    if [ "$INSERT_COUNT" -eq 0 ]; then
        echo "[ERROR] SQL file does not contain INSERT statements for nodes table!"
        echo "[INFO] Checking SQL file structure..."
        echo "[INFO] First 50 lines:"
        head -50 "$TEMP_SQL"
        echo "[INFO] Looking for INSERT statements anywhere:"
        grep -i "INSERT" "$TEMP_SQL" | head -5
    else
        echo "[ERROR] SQL file has $INSERT_COUNT INSERT statements for nodes but import didn't work"
        echo "[INFO] This might be due to:"
        echo "  - Foreign key constraint violations"
        echo "  - Duplicate key errors (if tables weren't dropped)"
        echo "  - Missing referenced records"
        echo "  - SQL syntax errors"
        echo "[INFO] Sample INSERT statement:"
        grep -E "^INSERT INTO|;INSERT INTO" "$TEMP_SQL" | grep -i "nodes" | head -1 | cut -c1-200
        echo "[INFO] Checking for MySQL errors in import output..."
        echo "[INFO] Last 100 lines of SQL file to check syntax:"
        tail -100 "$TEMP_SQL" | head -20
    fi
    rm -f "$TEMP_SQL"
    exit 1
fi

# Success - show improvement
NODE_INCREASE=$((NODE_COUNT_AFTER - NODE_COUNT_BEFORE))
echo "[OK] Node count increased by $NODE_INCREASE (from $NODE_COUNT_BEFORE to $NODE_COUNT_AFTER)"

# Clean up SQL file now that verification passed
rm -f "$SQL_FILE"

echo "[OK] Import completed successfully"

echo "[INFO] Verifying import..."
# Suppress MySQL password warnings (redirect stderr to /dev/null)
mysql -u PLACEHOLDER_DB_USER -p'PLACEHOLDER_DB_PASSWORD' PLACEHOLDER_DB_NAME -e "
  SELECT 'users' as table_name, COUNT(*) as count FROM users
  UNION ALL SELECT 'topics', COUNT(*) FROM topics
  UNION ALL SELECT 'threads', COUNT(*) FROM threads
  UNION ALL SELECT 'nodes', COUNT(*) FROM nodes;
" 2>/dev/null

echo "[INFO] Running Prisma migrations..."
npx prisma migrate deploy || true

echo "[INFO] Regenerating Prisma Client..."
npx prisma generate

echo "[INFO] Rebuilding application..."
npm run build

echo "[INFO] Restarting application..."
pm2 restart dayparty-api || pm2 start dist/server.js --name dayparty-api
pm2 save

echo "[INFO] Recent logs:"
pm2 logs dayparty-api --lines 10 --nostream

echo "[OK] Database sync complete!"
