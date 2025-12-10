# Windows Development Environment Guide

**Last Updated:** 2025-01-27  
**Target Audience:** AI Agents, Developers, Contributors

## ⚠️ CRITICAL: Command Line Syntax

This project is developed on **Windows PowerShell**. This has important implications for all terminal commands.

### Command Chaining

**DO NOT USE `&&`** - This is Unix/Linux syntax and will **FAIL** on Windows.

**USE `;` (semicolon)** instead for command chaining in PowerShell.

#### Examples

✅ **Correct (Windows PowerShell):**
```powershell
cd backend ; npm install ; npm run build
```

❌ **Incorrect (Unix/Linux - will fail on Windows):**
```bash
cd backend && npm install && npm run build
```

### Other Windows-Specific Commands

| Unix/Linux | Windows PowerShell | Notes |
|------------|-------------------|-------|
| `cp file1 file2` | `copy file1 file2` | Copy files |
| `mv file1 file2` | `move file1 file2` | Move/rename files |
| `rm file` | `del file` or `Remove-Item file` | Delete files |
| `rm -r dir` | `rmdir /s dir` or `Remove-Item -Recurse dir` | Delete directory |
| `ls` | `dir` or `Get-ChildItem` | List files |
| `cat file` | `type file` or `Get-Content file` | View file contents |
| `grep pattern file` | `Select-String pattern file` | Search in files |
| `&&` | `;` | Chain commands |

### PowerShell vs CMD

- **PowerShell** is the primary shell used in this project
- PowerShell supports both `;` and `-and` for different purposes
- For sequential command execution, use `;`
- CMD also uses `;` but has different syntax for other operations

### Running NPM Scripts on Windows

**⚠️ CRITICAL**: **ALWAYS use `cmd /c` prefix when running npm scripts** to avoid PowerShell script restrictions:

✅ **Correct (REQUIRED):**
```powershell
cmd /c npm run db:update-enum-delta
cmd /c npm run db:generate
cmd /c npm run build
cmd /c npm run cleanup:imported -- --topic-name "Topic Name"
```

❌ **Incorrect (will fail with execution policy error):**
```powershell
npm run db:update-enum-delta
npm run build
```

**Why this is required**: PowerShell has execution policy restrictions that prevent npm scripts from running directly. Using `cmd /c` runs the command in CMD instead of PowerShell, bypassing these restrictions while still allowing the command to execute properly.

**Note**: This is not just for error cases - it's the standard way to run npm scripts in this Windows environment.

### Prisma Client Generation Errors (EPERM)

**⚠️ IMPORTANT**: If you encounter this error when running `npm run db:generate`:

```
Error: EPERM: operation not permitted, rename '...query_engine-windows.dll.node.tmp...' -> '...query_engine-windows.dll.node'
```

**Cause**: The Prisma client file is locked by a running process (usually the dev server).

**Solutions**:

1. **Stop the dev server** (recommended):
   ```powershell
   # Press Ctrl+C in the terminal where npm run dev is running
   # Or find and stop the specific Node process
   ```

2. **Kill all Node processes** (if safe to do so):
   ```powershell
   Get-Process node | Stop-Process -Force
   cmd /c npm run db:generate
   ```

3. **Check what's using the file**:
   ```powershell
   Get-Process | Where-Object {$_.ProcessName -like "*node*"} | Select-Object ProcessName, Id, Path
   ```

4. **Wait and retry**: Sometimes the lock clears after a few seconds.

**Prevention**: Always stop the dev server before regenerating Prisma client.

### Path Separators

- Windows uses backslashes `\` for paths: `E:\day_party\backend`
- PowerShell accepts both `/` and `\` in most contexts
- When in doubt, use backslashes for Windows paths

### Environment Variables

- PowerShell: `$env:VARIABLE_NAME`
- CMD: `%VARIABLE_NAME%`
- Example: `$env:USERPROFILE` (PowerShell) vs `%USERPROFILE%` (CMD)

## Examples from This Project

### Backend Development

✅ **Correct:**
```powershell
cd E:\day_party\backend ; npm install ; npm run dev
```

❌ **Incorrect:**
```bash
cd E:\day_party\backend && npm install && npm run dev
```

### Flutter Development

✅ **Correct:**
```powershell
cd day_party_flutter ; flutter pub get ; flutter run
```

❌ **Incorrect:**
```bash
cd day_party_flutter && flutter pub get && flutter run
```

### Git Operations

✅ **Correct:**
```powershell
git add . ; git commit -m "message" ; git push
```

❌ **Incorrect:**
```bash
git add . && git commit -m "message" && git push
```

## For AI Agents

When generating terminal commands for this project:

1. **Always check** if commands are being chained
2. **Replace all `&&`** with `;` (semicolon)
3. **Use Windows-compatible commands** (copy, move, del, etc.)
4. **Use backslashes** for Windows paths when appropriate
5. **Use `cmd /c`** for npm scripts if PowerShell execution policy errors occur
6. **Test commands** in PowerShell context

## Android Emulator Setup

**⚠️ IMPORTANT**: When testing on Android emulator, you must set up ADB reverse port forwarding for OAuth to work:

```powershell
cd day_party_flutter
.\setup-port-forwarding.ps1
```

This creates a TCP tunnel: `adb reverse tcp:3000 tcp:3000` to forward `localhost:3000` from the emulator to your host machine.

**Note**: Port forwarding resets when you restart the emulator - you must run the setup script again.

See `EMULATOR_SETUP.md` in the project root for complete documentation.

## Related Documentation

- `03-Decision-Log.md` - Decision entry dated 2025-01-27
- `EMULATOR_SETUP.md` - ⚠️ **REQUIRED** Android emulator port forwarding setup
- `23-Android-Gradle-Tasks.md` - Android-specific command examples
- `20-Azure-VM-Setup.md` - Server setup (Linux, different syntax)

## Quick Reference Card

```
Windows PowerShell Command Chaining:
  command1 ; command2 ; command3    ✅ CORRECT
  command1 && command2 && command3  ❌ WRONG (Unix/Linux only)

NPM Scripts (REQUIRED):
  cmd /c npm run script-name        ✅ CORRECT (REQUIRED - bypasses PowerShell restrictions)
  npm run script-name                ❌ WRONG (will fail with PowerShell execution policy)

File Operations:
  copy src dest                     ✅ CORRECT
  cp src dest                       ❌ WRONG (Unix/Linux only)

Path Examples:
  E:\day_party\backend             ✅ CORRECT (Windows)
  E:/day_party/backend             ✅ ALSO WORKS (PowerShell accepts both)
  /day_party/backend               ❌ WRONG (Unix/Linux absolute path)
```

---

**Remember**: When in doubt, use `;` instead of `&&` for command chaining on Windows!

