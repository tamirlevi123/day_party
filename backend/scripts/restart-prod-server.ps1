# Restart Production Server
# This script restarts the production API server
#
# Usage:
#   .\restart-prod-server.ps1

param(
    [string]$ProdServer = "azureuser@172.167.43.172"
)

$ErrorActionPreference = "Stop"

# Colors for output
function Write-Step { Write-Host "`n[STEP] $args" -ForegroundColor Cyan }
function Write-Success { Write-Host "[OK] $args" -ForegroundColor Green }
function Write-Warning { Write-Host "[WARN] $args" -ForegroundColor Yellow }
function Write-Error { Write-Host "[ERROR] $args" -ForegroundColor Red }

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Restart Production Server" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Step "Connecting to production server..."

try {
    Write-Host "Restarting application..." -ForegroundColor Yellow
    $output = ssh $ProdServer "cd ~/dayparty/backend; pm2 restart dayparty-api || pm2 start dist/server.js --name dayparty-api; pm2 save; pm2 list" 2>&1
    $output | ForEach-Object { Write-Host $_ }
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to restart server (exit code: $LASTEXITCODE)"
        exit 1
    }
    
    Write-Success "Server restarted successfully"
    
    Write-Host "`nChecking server status..." -ForegroundColor Yellow
    $status = ssh $ProdServer "cd ~/dayparty/backend; pm2 status dayparty-api" 2>&1
    $status | ForEach-Object { Write-Host $_ }
    
    Write-Host "`nRecent logs (last 20 lines):" -ForegroundColor Yellow
    $logs = ssh $ProdServer "cd ~/dayparty/backend; pm2 logs dayparty-api --lines 20 --nostream" 2>&1
    $logs | ForEach-Object { Write-Host $_ }
    
} catch {
    Write-Error "Failed to restart server: $_"
    exit 1
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  Restart Complete!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green
