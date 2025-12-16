# Full database dump and import to production
# This will make production database identical to development

$ErrorActionPreference = "Stop"

Write-Host "📤 Step 1: Exporting full database from development..." -ForegroundColor Cyan

# Get database credentials from .env file
$envFile = Join-Path $PSScriptRoot "..\.env"
if (-not (Test-Path $envFile)) {
    Write-Error ".env file not found at $envFile"
    exit 1
}

$envContent = Get-Content $envFile -Raw
if ($envContent -match 'DATABASE_URL="mysql://([^:]+):([^@]+)@([^:]+):(\d+)/([^"]+)"') {
    $dbUser = $matches[1]
    $dbPassword = $matches[2]
    $dbHost = $matches[3]
    $dbPort = $matches[4]
    $dbName = $matches[5]
} else {
    Write-Error "Could not parse DATABASE_URL from .env file"
    exit 1
}

# Output file
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outputFile = Join-Path $PSScriptRoot "..\dayparty-full-export-$timestamp.sql"

Write-Host "   Database: $dbName" -ForegroundColor Gray
Write-Host "   Host: $dbHost" -ForegroundColor Gray
Write-Host "   Output: $outputFile" -ForegroundColor Gray

# Export entire database
$env:MYSQL_PWD = $dbPassword

try {
    Write-Host "   Exporting (this may take a few minutes)..." -ForegroundColor Yellow
    mysqldump -h $dbHost -P $dbPort -u $dbUser `
        --single-transaction `
        --routines `
        --triggers `
        --events `
        --add-drop-table `
        --default-character-set=utf8mb4 `
        $dbName | Out-File -FilePath $outputFile -Encoding UTF8 -NoNewline
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to export database"
        exit 1
    }
    
    $fileSize = (Get-Item $outputFile).Length / 1MB
    Write-Host "✅ Database exported: $outputFile ($([math]::Round($fileSize, 2)) MB)" -ForegroundColor Green
    
} finally {
    $env:MYSQL_PWD = $null
}

Write-Host ""
Write-Host "📤 Step 2: Transferring to production server..." -ForegroundColor Cyan

$prodServer = "azureuser@172.167.43.172"
$remoteFile = "~/dayparty-full-export.sql"

scp $outputFile "${prodServer}:${remoteFile}"

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to transfer file to production server"
    exit 1
}

Write-Host "✅ File transferred to production server" -ForegroundColor Green

Write-Host ""
Write-Host "📥 Step 3: Importing on production server..." -ForegroundColor Cyan
Write-Host "   (This will backup current DB, then import the new one)" -ForegroundColor Gray

# SSH command to import on production
$sshCommand = @"
cd ~/dayparty/backend

echo '💾 Backing up current production database...'
BACKUP_FILE="dayparty-production-backup-\$(date +%Y%m%d-%H%M%S).sql"
if [ -f .env ]; then
    DB_URL=\$(grep DATABASE_URL .env | cut -d'=' -f2 | tr -d '"')
    DB_USER=\$(echo \$DB_URL | sed -n 's/.*:\/\/\([^:]*\):.*/\1/p')
    DB_PASSWORD=\$(echo \$DB_URL | sed -n 's/.*:\/\/[^:]*:\([^@]*\)@.*/\1/p')
    DB_HOST=\$(echo \$DB_URL | sed -n 's/.*@\([^:]*\):.*/\1/p')
    DB_PORT=\$(echo \$DB_URL | sed -n 's/.*:\([0-9]*\)\/.*/\1/p')
    DB_NAME=\$(echo \$DB_URL | sed -n 's/.*\/\([^?]*\).*/\1/p')
    
    MYSQL_PWD=\$DB_PASSWORD mysqldump -h \$DB_HOST -P \$DB_PORT -u \$DB_USER \$DB_NAME > "\$BACKUP_FILE"
    echo "✅ Backup saved: \$BACKUP_FILE"
    
    echo '📥 Importing development database...'
    MYSQL_PWD=\$DB_PASSWORD mysql -h \$DB_HOST -P \$DB_PORT -u \$DB_USER \$DB_NAME < ~/dayparty-full-export.sql
    
    if [ \$? -eq 0 ]; then
        echo '✅ Database imported successfully'
        echo ''
        echo '🔍 Verifying import...'
        MYSQL_PWD=\$DB_PASSWORD mysql -h \$DB_HOST -P \$DB_PORT -u \$DB_USER \$DB_NAME -e "
        SELECT 'users' as table_name, COUNT(*) as count FROM users
        UNION ALL SELECT 'topics', COUNT(*) FROM topics
        UNION ALL SELECT 'threads', COUNT(*) FROM threads
        UNION ALL SELECT 'nodes', COUNT(*) FROM nodes
        UNION ALL SELECT '_KNS_Status', COUNT(*) FROM \`_KNS_Status\`
        UNION ALL SELECT '_KNS_Bill', COUNT(*) FROM \`_KNS_Bill\`;
        "
    else
        echo '❌ Import failed'
        exit 1
    fi
else
    echo '❌ .env file not found'
    exit 1
fi
"@

ssh $prodServer $sshCommand

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to import database on production server"
    exit 1
}

Write-Host ""
Write-Host "✅ Full database import complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Mark migrations as applied: ssh $prodServer 'cd ~/dayparty/backend && npx prisma migrate resolve --applied 20250127000001_add_node_metadata_json'" -ForegroundColor White
Write-Host "2. Verify migration status: ssh $prodServer 'cd ~/dayparty/backend && npx prisma migrate status'" -ForegroundColor White
Write-Host "3. Restart the application: ssh $prodServer 'pm2 restart dayparty-api'" -ForegroundColor White
