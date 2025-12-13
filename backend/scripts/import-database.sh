#!/bin/bash
# Import MySQL database dump to production server
# Usage: ./import-database.sh [dump-file.sql.gz]

set -e

DB_USER="${DB_USER:-dayparty}"
DB_PASSWORD="${DB_PASSWORD:-}"
DB_NAME="${DB_NAME:-dayparty}"
DB_HOST="${DB_HOST:-localhost}"
DUMP_FILE="${1:-dayparty-export-latest.sql.gz}"

if [ ! -f "$DUMP_FILE" ]; then
  echo "❌ Error: Dump file not found: $DUMP_FILE"
  exit 1
fi

echo "📥 Importing MySQL database..."
echo "   Database: $DB_NAME"
echo "   Host: $DB_HOST"
echo "   Dump file: $DUMP_FILE"

# Check if dump is compressed
if [[ "$DUMP_FILE" == *.gz ]]; then
  echo "   Decompressing dump file..."
  gunzip -c "$DUMP_FILE" | mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME"
else
  echo "   Importing SQL file..."
  mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" < "$DUMP_FILE"
fi

echo "✅ Database imported successfully!"

# Verify import
echo ""
echo "📊 Verifying import..."
mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "
  SELECT 
    'users' as table_name, COUNT(*) as count FROM users
  UNION ALL
  SELECT 'topics', COUNT(*) FROM topics
  UNION ALL
  SELECT 'threads', COUNT(*) FROM threads
  UNION ALL
  SELECT 'nodes', COUNT(*) FROM nodes
  UNION ALL
  SELECT 'node_votes', COUNT(*) FROM node_votes;
"
