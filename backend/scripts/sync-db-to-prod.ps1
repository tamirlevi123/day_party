# Sync MySQL Database from Dev to Production
# This script exports the dev database, transfers it to production, and imports it
#
# Usage:
#   .\sync-db-to-prod.ps1
#
# Prerequisites:
#   - MySQL client tools installed
#   - SSH access to production server (172.167.43.172)
#   - Dev MySQL credentials configured
#   - Production MySQL password: DayParty2024!SecurePW

param(
    [string]$DevDbUser = "dayparty",
    [string]$DevDbName = "dayparty",
    [string]$DevDbHost = "localhost",
    [string]$ProdServer = "azureuser@172.167.43.172",
    [string]$ProdDbUser = "dayparty",
    [string]$ProdDbPassword = "DayParty2024!SecurePW",
    [string]$ProdDbName = "dayparty",
    [string]$MySQLBinPath = "",
    [switch]$SkipBackup,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# Colors for output
function Write-Step { Write-Host "`n[STEP] $args" -ForegroundColor Cyan }
function Write-Success { Write-Host "[OK] $args" -ForegroundColor Green }
function Write-Warning { Write-Host "[WARN] $args" -ForegroundColor Yellow }
function Write-Error { Write-Host "[ERROR] $args" -ForegroundColor Red }

# Find MySQL client tools
function Find-MySQLBin {
    # If explicitly provided, use it
    if ($MySQLBinPath -and (Test-Path (Join-Path $MySQLBinPath "mysqldump.exe"))) {
        return $MySQLBinPath
    }
    
    # Check common MySQL installation paths
    $commonPaths = @(
        "C:\Program Files\MySQL\MySQL Server 8.0\bin",
        "C:\Program Files\MySQL\MySQL Server 8.1\bin",
        "C:\Program Files\MySQL\MySQL Server 8.2\bin",
        "C:\Program Files\MySQL\MySQL Server 8.3\bin",
        "C:\Program Files (x86)\MySQL\MySQL Server 8.0\bin",
        "C:\Program Files (x86)\MySQL\MySQL Server 8.1\bin",
        "C:\xampp\mysql\bin",
        "C:\wamp64\bin\mysql\mysql8.0.xx\bin"
    )
    
    foreach ($path in $commonPaths) {
        if (Test-Path (Join-Path $path "mysqldump.exe")) {
            return $path
        }
    }
    
    # Dynamically search C:\Program Files\MySQL for any MySQL Server installation
    if (Test-Path "C:\Program Files\MySQL") {
        $mysqlDirs = Get-ChildItem "C:\Program Files\MySQL" -Directory -ErrorAction SilentlyContinue
        foreach ($dir in $mysqlDirs) {
            $binPath = Join-Path $dir.FullName "bin"
            if (Test-Path (Join-Path $binPath "mysqldump.exe")) {
                return $binPath
            }
        }
    }
    
    # Check if mysqldump is in PATH
    $mysqldumpInPath = Get-Command mysqldump -ErrorAction SilentlyContinue
    if ($mysqldumpInPath) {
        return ""
    }
    
    return $null
}

# Find MySQL bin directory
$MySQLBin = Find-MySQLBin
if (-not $MySQLBin -and -not (Get-Command mysqldump -ErrorAction SilentlyContinue)) {
    Write-Error "mysqldump not found. Please either:"
    Write-Host "  1. Add MySQL bin directory to PATH, or" -ForegroundColor Yellow
    Write-Host "  2. Install MySQL client tools, or" -ForegroundColor Yellow
    Write-Host "  3. Specify MySQL bin path: .\sync-db-to-prod.ps1 -MySQLBinPath 'C:\Program Files\MySQL\MySQL Server 8.0\bin'" -ForegroundColor Yellow
    exit 1
}

# Set mysqldump command
if ($MySQLBin) {
    $mysqldumpCmd = Join-Path $MySQLBin "mysqldump.exe"
    $mysqlCmd = Join-Path $MySQLBin "mysql.exe"
} else {
    $mysqldumpCmd = "mysqldump"
    $mysqlCmd = "mysql"
}

# Get script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$BackendDir = Split-Path -Parent $ScriptDir
$ExportFile = Join-Path $BackendDir "dayparty-dev-export.sql"
$ExportZip = Join-Path $BackendDir "dayparty-dev-export.sql.zip"
# Timestamp variable removed (not used)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  MySQL Database Sync: Dev -> Production" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Step 1: Export from Dev
Write-Step "Step 1: Exporting MySQL database from dev server..."

if ($DryRun) {
    Write-Warning "DRY RUN: Would export database"
} else {
    # Try to read password from .env file first
    $envFile = Join-Path $BackendDir ".env"
    $DevDbPassword = $null
    
    if (Test-Path $envFile) {
        $envContent = Get-Content $envFile -Raw
        if ($envContent -match 'DATABASE_URL="mysql://[^:]+:([^@]+)@') {
            $DevDbPassword = $matches[1]
            Write-Host "Using password from .env file" -ForegroundColor Gray
        }
    }
    
    # If not found in .env, prompt for password
    if (-not $DevDbPassword) {
        $SecurePassword = Read-Host "Enter MySQL password for dev server ($DevDbUser@$DevDbHost)" -AsSecureString
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
        $DevDbPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    }
    
    # Remove old export files
    if (Test-Path $ExportFile) {
        Remove-Item $ExportFile -Force
        Write-Success "Removed old export file"
    }
    if (Test-Path $ExportZip) {
        Remove-Item $ExportZip -Force
        Write-Success "Removed old export zip"
    }
    
    # Export database
    Write-Host "Exporting database..." -ForegroundColor Yellow
    $env:MYSQL_PWD = $DevDbPassword
    
    # Export to temp file first, then remove BOM if present
    $TempExportFile = "$ExportFile.tmp"
    & $mysqldumpCmd -u $DevDbUser -h $DevDbHost `
        --single-transaction `
        --routines `
        --triggers `
        --events `
        --add-drop-table `
        --default-character-set=utf8mb4 `
        $DevDbName | Out-File -FilePath $TempExportFile -Encoding UTF8 -NoNewline
    
    # Remove UTF-8 BOM if present (MySQL doesn't like BOM)
    $content = Get-Content $TempExportFile -Raw -Encoding UTF8
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($ExportFile, $content, $utf8NoBom)
    Remove-Item $TempExportFile -Force
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to export database"
        exit 1
    }
    
    $ExportSize = (Get-Item $ExportFile).Length / 1MB
    Write-Success "Database exported: $ExportFile ($([math]::Round($ExportSize, 2)) MB)"
    
    # Skip compression - transfer SQL file directly (avoids need for unzip on production)
    Write-Host "Skipping compression - will transfer SQL file directly..." -ForegroundColor Yellow
    $env:MYSQL_PWD = $null
}

# Step 2: Transfer to Production
Write-Step "Step 2: Transferring database dump to production server..."

if ($DryRun) {
    Write-Warning "DRY RUN: Would transfer $ExportFile to $ProdServer"
} else {
    Write-Host "Transferring SQL file via SCP..." -ForegroundColor Yellow
    scp $ExportFile "${ProdServer}:~/dayparty-dev-export.sql"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to transfer file to production server"
        exit 1
    }
    
    Write-Success "SQL file transferred to production server"
}

# Step 3: Import on Production
Write-Step "Step 3: Importing database on production server..."

if ($DryRun) {
    Write-Warning "DRY RUN: Would import database on production server"
} else {
    Write-Host "Connecting to production server to import database..." -ForegroundColor Yellow
    
    # Read the bash script template from file and replace placeholders
    $ImportScriptPath = Join-Path $ScriptDir "import-db-remote.sh"
    $ImportScript = Get-Content $ImportScriptPath -Raw -Encoding UTF8
    
    # Replace placeholders in the script with actual values
    $ImportScript = $ImportScript -replace 'PLACEHOLDER_DB_USER', $ProdDbUser
    $ImportScript = $ImportScript -replace 'PLACEHOLDER_DB_PASSWORD', $ProdDbPassword
    $ImportScript = $ImportScript -replace 'PLACEHOLDER_DB_NAME', $ProdDbName
    
    # Execute via SSH - use temp file method to avoid line ending issues
    Write-Host "Executing import script on production server..." -ForegroundColor Yellow
    try {
        # Create temp file for the bash script
        $tempImportScript = [System.IO.Path]::GetTempFileName()
        
        # Remove Windows line endings and BOM
        $ImportScriptUnix = $ImportScript -replace "`r`n", "`n" -replace "`r", "`n"
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($ImportScriptUnix)
        if ($bytes.Length -gt 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
            $bytes = $bytes[3..($bytes.Length-1)]
            $ImportScriptUnix = [System.Text.Encoding]::UTF8.GetString($bytes)
        }
        
        # Write to temp file with Unix line endings (no BOM)
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($tempImportScript, $ImportScriptUnix, $utf8NoBom)
        
        # Transfer and execute
        Write-Host "Uploading import script..." -ForegroundColor Yellow
        scp $tempImportScript "${ProdServer}:~/import-db.sh"
        
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to upload import script"
        }
        
        Write-Host "Executing import script..." -ForegroundColor Yellow
        # Execute script and capture output
        $output = ssh $ProdServer "chmod +x ~/import-db.sh; bash ~/import-db.sh 2>&1; EXIT_CODE=`$?; rm ~/import-db.sh; exit `$EXIT_CODE" 2>&1
        # Filter out MySQL password warnings (they're just warnings, not errors)
        $filteredOutput = $output | Where-Object { $_ -notmatch "Using a password on the command line interface can be insecure" }
        $filteredOutput | ForEach-Object { Write-Host $_ }
        
        # Check exit code
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Import script failed with exit code: $LASTEXITCODE"
            Write-Host "`n=== Full Error Output ===" -ForegroundColor Red
            # Show all output, especially ERROR lines
            $output | ForEach-Object { 
                if ($_ -match "ERROR|error|Error|failed|Failed|FAILED|WARN") {
                    Write-Host $_ -ForegroundColor Red
                } else {
                    Write-Host $_
                }
            }
            Write-Host "`n=== Last 50 lines of output ===" -ForegroundColor Yellow
            $output | Select-Object -Last 50 | ForEach-Object { Write-Host $_ }
            exit 1
        }
        
        Write-Success "Database imported successfully on production server"
    } catch {
        Write-Error "Failed to execute import script: $_"
        exit 1
    } finally {
        # Clean up temp file
        if (Test-Path $tempImportScript) {
            Remove-Item $tempImportScript -Force
        }
    }
}

# Step 4: Verify Import
Write-Step "Step 4: Verifying database on production server..."

if ($DryRun) {
    Write-Warning "DRY RUN: Would verify database"
} else {
    Write-Host "Running verification checks..." -ForegroundColor Yellow
    
    # Read verification script template from file and replace placeholders
    $VerifyScriptPath = Join-Path $ScriptDir "verify-db-remote.sh"
    $VerifyScript = Get-Content $VerifyScriptPath -Raw -Encoding UTF8
    
    $VerifyScript = $VerifyScript -replace 'PLACEHOLDER_DB_USER', $ProdDbUser
    $VerifyScript = $VerifyScript -replace 'PLACEHOLDER_DB_PASSWORD', $ProdDbPassword
    $VerifyScript = $VerifyScript -replace 'PLACEHOLDER_DB_NAME', $ProdDbName
    
    try {
        # Use temp file method for verification too
        $tempVerifyScript = [System.IO.Path]::GetTempFileName()
        
        # Remove Windows line endings and BOM
        $VerifyScriptUnix = $VerifyScript -replace "`r`n", "`n" -replace "`r", "`n"
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($VerifyScriptUnix)
        if ($bytes.Length -gt 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
            $bytes = $bytes[3..($bytes.Length-1)]
            $VerifyScriptUnix = [System.Text.Encoding]::UTF8.GetString($bytes)
        }
        
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($tempVerifyScript, $VerifyScriptUnix, $utf8NoBom)
        
        scp $tempVerifyScript "${ProdServer}:~/verify-db.sh"
        $verifyOutput = ssh $ProdServer "chmod +x ~/verify-db.sh; bash ~/verify-db.sh; EXIT_CODE=`$?; rm ~/verify-db.sh; exit `$EXIT_CODE" 2>&1
        $verifyOutput | ForEach-Object { Write-Host $_ }
        
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Verification check had issues (exit code: $LASTEXITCODE)"
        } else {
            Write-Success "Database verification passed"
        }
    } catch {
        Write-Warning "Verification check failed: $_"
    } finally {
        if (Test-Path $tempVerifyScript) {
            Remove-Item $tempVerifyScript -Force
        }
    }
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  Database Sync Complete!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green
