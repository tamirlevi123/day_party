# Check Production Server for Import Issues
# This script connects to production and checks various things that might indicate why import failed
#
# Usage:
#   .\check-prod-import-issues.ps1

param(
    [string]$ProdServer = "azureuser@172.167.43.172",
    [string]$ProdDbUser = "dayparty",
    [string]$ProdDbPassword = "DayParty2024!SecurePW",
    [string]$ProdDbName = "dayparty"
)

$ErrorActionPreference = "Continue"

# Colors for output
function Write-Step { Write-Host "`n[STEP] $args" -ForegroundColor Cyan }
function Write-Success { Write-Host "[OK] $args" -ForegroundColor Green }
function Write-Warning { Write-Host "[WARN] $args" -ForegroundColor Yellow }
function Write-Error { Write-Host "[ERROR] $args" -ForegroundColor Red }
function Write-Info { Write-Host "[INFO] $args" -ForegroundColor White }

Write-Step "Checking production server for import issues..."

# Create remote diagnostic script
$remoteScript = @"
#!/bin/bash
set -e

cd ~/dayparty/backend

echo "=== Checking Database State ==="
echo "[INFO] Current node count:"
mysql -u $ProdDbUser -p'$ProdDbPassword' $ProdDbName -N -e "SELECT COUNT(*) FROM nodes;" 2>/dev/null || echo "ERROR: Could not query nodes"

echo ""
echo "[INFO] Table row counts:"
mysql -u $ProdDbUser -p'$ProdDbPassword' $ProdDbName -e "
  SELECT 'users' as table_name, COUNT(*) as count FROM users
  UNION ALL SELECT 'topics', COUNT(*) FROM topics
  UNION ALL SELECT 'threads', COUNT(*) FROM threads
  UNION ALL SELECT 'nodes', COUNT(*) FROM nodes;
" 2>/dev/null || echo "ERROR: Could not query tables"

echo ""
echo "=== Checking Import File ==="
if [ -f ~/dayparty-dev-export.sql.zip ]; then
    echo "[OK] Zip file exists"
    ls -lh ~/dayparty-dev-export.sql.zip
    echo ""
    echo "[INFO] Zip file contents:"
    unzip -l ~/dayparty-dev-export.sql.zip 2>/dev/null | head -10
    echo ""
    echo "[INFO] Extracting and checking SQL file size..."
    TEMP_CHECK="/tmp/check-sql-$$.sql"
    unzip -p ~/dayparty-dev-export.sql.zip > "\$TEMP_CHECK" 2>/dev/null
    if [ -s "\$TEMP_CHECK" ]; then
        SQL_SIZE=\$(wc -c < "\$TEMP_CHECK")
        echo "[OK] SQL file extracted successfully, size: \$SQL_SIZE bytes"
        echo "[INFO] First 5 lines of SQL file:"
        head -5 "\$TEMP_CHECK"
        echo ""
        echo "[INFO] Checking for INSERT statements in nodes table:"
        INSERT_COUNT=\$(grep -ci "INSERT INTO.*nodes" "\$TEMP_CHECK" 2>/dev/null || echo "0")
        echo "[INFO] Found \$INSERT_COUNT INSERT statements for nodes table"
        if [ "\$INSERT_COUNT" -gt 0 ]; then
            echo "[INFO] Sample INSERT statement:"
            grep -i "INSERT INTO.*nodes" "\$TEMP_CHECK" | head -1 | cut -c1-200
        fi
        rm -f "\$TEMP_CHECK"
    else
        echo "[ERROR] Failed to extract SQL file or file is empty"
        rm -f "\$TEMP_CHECK"
    fi
else
    echo "[WARN] Zip file not found at ~/dayparty-dev-export.sql.zip"
fi

echo ""
echo "=== Checking MySQL Error Log ==="
# Try to find MySQL error log
MYSQL_ERROR_LOG=\$(mysql -u $ProdDbUser -p'$ProdDbPassword' -e "SHOW VARIABLES LIKE 'log_error';" 2>/dev/null | grep log_error | awk '{print \$2}' || echo "")
if [ -n "\$MYSQL_ERROR_LOG" ] && [ -f "\$MYSQL_ERROR_LOG" ]; then
    echo "[INFO] MySQL error log location: \$MYSQL_ERROR_LOG"
    echo "[INFO] Last 20 lines of MySQL error log:"
    tail -20 "\$MYSQL_ERROR_LOG" 2>/dev/null || echo "Could not read error log"
else
    echo "[INFO] Checking common MySQL error log locations..."
    for log_path in /var/log/mysql/error.log /var/log/mysqld.log /var/log/mysql/mysql-error.log; do
        if [ -f "\$log_path" ]; then
            echo "[INFO] Found error log at: \$log_path"
            echo "[INFO] Last 20 lines:"
            tail -20 "\$log_path" 2>/dev/null | grep -i "error\|fail" || echo "No recent errors"
            break
        fi
    done
fi

echo ""
echo "=== Checking Recent Backups ==="
echo "[INFO] Recent backup files:"
ls -lth ~/dayparty/backend/dayparty-production-backup-*.sql 2>/dev/null | head -5 || echo "No backup files found"

echo ""
echo "=== Checking PM2 Status ==="
pm2 status dayparty-api || echo "PM2 not running or dayparty-api not found"

echo ""
echo "=== Checking Disk Space ==="
df -h ~ | tail -1

echo ""
echo "=== Checking MySQL Process ==="
ps aux | grep mysql | grep -v grep | head -3 || echo "MySQL process not found"

"@

# Write remote script to temp file
$tempScript = [System.IO.Path]::GetTempFileName() + ".sh"
$remoteScript | Out-File -FilePath $tempScript -Encoding UTF8 -NoNewline

Write-Step "Transferring diagnostic script to production server..."
scp $tempScript "${ProdServer}:~/check-import-issues.sh" 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to transfer diagnostic script"
    Remove-Item $tempScript -ErrorAction SilentlyContinue
    exit 1
}

Write-Step "Running diagnostic script on production server..."
ssh $ProdServer "chmod +x ~/check-import-issues.sh && bash ~/check-import-issues.sh && rm -f ~/check-import-issues.sh"

Remove-Item $tempScript -ErrorAction SilentlyContinue

Write-Step "Diagnostic check complete!"
