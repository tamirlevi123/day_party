# Verify Production Database
# This script connects to production and checks database status
#
# Usage:
#   .\verify-prod-db.ps1

param(
    [string]$ProdServer = "azureuser@172.167.43.172",
    [string]$ProdDbUser = "dayparty",
    [string]$ProdDbPassword = "DayParty2024!SecurePW",
    [string]$ProdDbName = "dayparty"
)

$ErrorActionPreference = "Stop"

# Colors for output
function Write-Step { Write-Host "`n🔵 $args" -ForegroundColor Cyan }
function Write-Success { Write-Host "✅ $args" -ForegroundColor Green }
function Write-Warning { Write-Host "⚠️  $args" -ForegroundColor Yellow }
function Write-Error { Write-Host "❌ $args" -ForegroundColor Red }
function Write-Info { Write-Host "ℹ️  $args" -ForegroundColor Blue }

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Production Database Verification" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Create verification script
$VerifyScript = @'
#!/bin/bash
set -e

cd ~/dayparty/backend

echo "📊 Checking database connection..."
mysql -u PLACEHOLDER_DB_USER -p'PLACEHOLDER_DB_PASSWORD' PLACEHOLDER_DB_NAME -e "SELECT 'Connection OK' as status;" || {
    echo "❌ Failed to connect to database"
    exit 1
}

echo ""
echo "📋 MySQL Table counts (main application data):"
mysql -u PLACEHOLDER_DB_USER -p'PLACEHOLDER_DB_PASSWORD' PLACEHOLDER_DB_NAME -e "
SELECT 'users' as table_name, COUNT(*) as count FROM users
UNION ALL SELECT 'topics', COUNT(*) FROM topics
UNION ALL SELECT 'threads', COUNT(*) FROM threads
UNION ALL SELECT 'nodes', COUNT(*) FROM nodes
ORDER BY table_name;
" 2>/dev/null || echo "⚠️  Some tables may be missing"

echo ""
echo "📊 Detailed node count by type (if available):"
mysql -u PLACEHOLDER_DB_USER -p'PLACEHOLDER_DB_PASSWORD' PLACEHOLDER_DB_NAME -e "
SELECT 
    CASE 
        WHEN thread_id IS NOT NULL THEN 'Thread Nodes'
        ELSE 'Other Nodes'
    END as node_type,
    COUNT(*) as count
FROM nodes
GROUP BY node_type;
" 2>/dev/null || echo "⚠️  Could not get detailed node counts"

echo ""
echo "📅 Recent threads (last 5):"
mysql -u PLACEHOLDER_DB_USER -p'PLACEHOLDER_DB_PASSWORD' PLACEHOLDER_DB_NAME -e "
SELECT 
    id,
    title,
    created_at
FROM threads
ORDER BY created_at DESC
LIMIT 5;
"

echo ""
echo "🔄 PM2 Status:"
pm2 list

echo ""
echo "📋 Recent application logs (last 20 lines):"
pm2 logs dayparty-api --lines 20 --nostream

echo ""
echo "✅ Verification complete!"
'@

# Replace placeholders
$VerifyScript = $VerifyScript -replace 'PLACEHOLDER_DB_USER', $ProdDbUser
$VerifyScript = $VerifyScript -replace 'PLACEHOLDER_DB_PASSWORD', $ProdDbPassword
$VerifyScript = $VerifyScript -replace 'PLACEHOLDER_DB_NAME', $ProdDbName

# Execute via SSH
Write-Step "Connecting to production server..."

# Create a temporary file to store the bash script
$tempScript = [System.IO.Path]::GetTempFileName()
try {
    # Remove Windows line endings and BOM, convert to Unix format
    $VerifyScriptUnix = $VerifyScript -replace "`r`n", "`n" -replace "`r", "`n"
    # Remove BOM if present
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($VerifyScriptUnix)
    if ($bytes.Length -gt 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        $bytes = $bytes[3..($bytes.Length-1)]
        $VerifyScriptUnix = [System.Text.Encoding]::UTF8.GetString($bytes)
    }
    # Write script to temp file with Unix line endings (no BOM)
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($tempScript, $VerifyScriptUnix, $utf8NoBom)
    
    # Transfer and execute on remote server
    Write-Host "Uploading verification script..." -ForegroundColor Yellow
    scp $tempScript "${ProdServer}:~/verify-db.sh"
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to upload verification script"
    }
    
    # Execute the script and capture output
    Write-Host "Executing verification script..." -ForegroundColor Yellow
    $verifyOutput = ssh $ProdServer "chmod +x ~/verify-db.sh; bash ~/verify-db.sh; EXIT_CODE=`$?; rm ~/verify-db.sh; exit `$EXIT_CODE" 2>&1
    
    # Filter out MySQL password warnings
    $filteredOutput = $verifyOutput | Where-Object { $_ -notmatch "Using a password on the command line interface can be insecure" }
    $filteredOutput | ForEach-Object { Write-Host $_ }
    
    # Don't exit on error - just show warning
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Verification completed with warnings (exit code: $LASTEXITCODE)"
    } else {
        Write-Success "Verification completed successfully"
    }
} catch {
    Write-Error "Failed to connect or execute verification: $_"
    exit 1
} finally {
    # Clean up temp file
    if (Test-Path $tempScript) {
        Remove-Item $tempScript -Force
    }
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  Verification Complete!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green
