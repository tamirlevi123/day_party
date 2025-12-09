# Fix for Flutter plugin issues
# This script patches Flutter plugins to fix common build issues:
# 1. Missing namespace declarations (required for AGP 8.0+)
# 2. Incorrect asset paths in html_editor_enhanced
# Run this after 'flutter pub get' if you encounter build errors

$pubCache = "$env:LOCALAPPDATA\Pub\Cache\hosted\pub.dev"

# Plugins that need namespace fixes
$pluginsToFix = @(
    @{
        Name = "flutter_inappwebview"
        Version = "5.8.0"
        Namespace = "com.pichillilorenzo.flutter_inappwebview"
    },
    @{
        Name = "flutter_keyboard_visibility"
        Version = "5.4.1"
        Namespace = "com.jrai.flutter_keyboard_visibility"
    }
)

$fixedCount = 0
$skippedCount = 0
$notFoundCount = 0

foreach ($plugin in $pluginsToFix) {
    $pluginPath = "$pubCache\$($plugin.Name)-$($plugin.Version)\android\build.gradle"
    
    if (Test-Path $pluginPath) {
        $content = Get-Content $pluginPath -Raw
        
        # Check if namespace is already added
        if ($content -notmatch "namespace\s*=") {
            # Find the android block and add namespace
            if ($content -match "(android\s*\{)") {
                $namespaceLine = "    namespace = `"$($plugin.Namespace)`""
                $newContent = $content -replace "(android\s*\{)", "`$1`r`n$namespaceLine"
                Set-Content -Path $pluginPath -Value $newContent -NoNewline
                Write-Host "[OK] Fixed namespace in $($plugin.Name) build.gradle"
                $fixedCount++
            } else {
                Write-Host "[WARN] Could not find android block in $($plugin.Name) build.gradle"
            }
        } else {
            Write-Host "[INFO] Namespace already exists in $($plugin.Name) build.gradle"
            $skippedCount++
        }
    } else {
        Write-Host "[ERROR] Plugin not found: $($plugin.Name)-$($plugin.Version)"
        Write-Host "        Path: $pluginPath"
        $notFoundCount++
    }
}

Write-Host ""
Write-Host "Summary:"
Write-Host "  Fixed: $fixedCount"
Write-Host "  Already fixed: $skippedCount"
Write-Host "  Not found: $notFoundCount"

if ($notFoundCount -gt 0) {
    Write-Host ""
    Write-Host "[WARN] Some plugins were not found. Run 'flutter pub get' first, then run this script again."
}

# Fix html_editor_enhanced asset paths
Write-Host ""
Write-Host "Fixing html_editor_enhanced asset paths..."
$htmlEditorPath = "$pubCache\html_editor_enhanced-1.8.0\pubspec.yaml"
if (Test-Path $htmlEditorPath) {
    $content = Get-Content $htmlEditorPath -Raw
    $originalContent = $content
    
    # Fix asset paths: packages/html_editor_enhanced/ -> lib/assets/
    if ($content -match "packages/html_editor_enhanced/") {
        $content = $content -replace "packages/html_editor_enhanced/", "lib/assets/"
        # Fix double assets path if it exists
        $content = $content -replace "lib/assets/assets/", "lib/assets/"
        
        if ($content -ne $originalContent) {
            Set-Content -Path $htmlEditorPath -Value $content -NoNewline
            Write-Host "[OK] Fixed asset paths in html_editor_enhanced pubspec.yaml"
        } else {
            Write-Host "[INFO] Asset paths already correct in html_editor_enhanced"
        }
    } else {
        Write-Host "[INFO] Asset paths already fixed in html_editor_enhanced"
    }
} else {
    Write-Host "[WARN] html_editor_enhanced not found at: $htmlEditorPath"
}
