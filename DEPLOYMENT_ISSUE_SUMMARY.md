# Deployment Issue Summary

## Problem
The physical device is connecting to Azure VM backend (`http://172.167.43.172/api`) which is missing:
1. New Knesset API routes (`/api/knesset/statuses`, `/api/knesset/bills`)
2. Thread metadata in responses (no `metadata` field with `billId`, `statusID`, `statusDescription`)

## Evidence from Logs

### Physical Device Logs Show:
- ❌ `GET /api/knesset/statuses` → **404 "Route not found"**
- ❌ `GET /api/knesset/bills?knessetNum=25` → **404 "Route not found"**
- ❌ Threads response has **NO metadata**: `billId: null, billStatusID: null`
- ❌ `🔍 ThreadProvider: Threads with billStatusID: 0, without: 5614`

### Local Dev (Emulator) Logs Show:
- ✅ Routes work correctly
- ✅ Threads include metadata with `statusDescription`
- ✅ Filtering works: `Filtered 5614 threads down to 17 threads`

## Root Cause
Azure VM backend is running **old code** that doesn't include:
- `backend/src/routes/knesset.routes.ts` (new file)
- `backend/src/controllers/knesset.controller.ts` (new file)
- Updated `backend/src/controllers/topic.controller.ts` (with metadata enhancement)
- Updated `backend/src/services/knesset-status.service.ts` (with SQL fixes)

## Solution: Deploy Updated Backend to Azure VM

### Quick Deploy Steps:

1. **SSH into Azure VM:**
   ```bash
   ssh azureuser@172.167.43.172
   ```

2. **Navigate to backend directory:**
   ```bash
   cd /var/www/dayparty-api/backend
   # OR wherever your backend is deployed
   ```

3. **Pull latest code** (if using git):
   ```bash
   git pull origin main
   ```

4. **Or copy files manually** (if not using git):
   ```powershell
   # From local machine (PowerShell)
   cd E:\day_party\backend
   scp -r src/routes/knesset.routes.ts azureuser@172.167.43.172:/var/www/dayparty-api/backend/src/routes/
   scp -r src/controllers/knesset.controller.ts azureuser@172.167.43.172:/var/www/dayparty-api/backend/src/controllers/
   scp src/routes/index.ts azureuser@172.167.43.172:/var/www/dayparty-api/backend/src/routes/
   scp src/controllers/topic.controller.ts azureuser@172.167.43.172:/var/www/dayparty-api/backend/src/controllers/
   scp src/services/knesset-status.service.ts azureuser@172.167.43.172:/var/www/dayparty-api/backend/src/services/
   scp src/server.ts azureuser@172.167.43.172:/var/www/dayparty-api/backend/src/
   ```

5. **On Azure VM - Install dependencies and build:**
   ```bash
   cd /var/www/dayparty-api/backend
   npm install
   npm run build
   ```

6. **Restart PM2:**
   ```bash
   pm2 restart dayparty-api
   # OR
   pm2 restart all
   ```

7. **Verify routes are working:**
   ```bash
   curl http://localhost:3000/api/knesset/statuses
   # Should return JSON with statuses array, not 404
   ```

## Files That Need to Be Deployed

### New Files:
- `backend/src/routes/knesset.routes.ts`
- `backend/src/controllers/knesset.controller.ts`

### Updated Files:
- `backend/src/routes/index.ts` (added knesset routes)
- `backend/src/controllers/topic.controller.ts` (added metadata enhancement)
- `backend/src/services/knesset-status.service.ts` (fixed SQL syntax)
- `backend/src/server.ts` (added Prisma logging, status cache loading)

## Verification

After deployment, test these endpoints on Azure VM:

```bash
# Test statuses endpoint
curl http://localhost:3000/api/knesset/statuses

# Test bills endpoint  
curl "http://localhost:3000/api/knesset/bills?knessetNum=25"

# Test threads endpoint (should include metadata)
curl "http://localhost:3000/api/topics/67890500-2024-49f4-aac1-b4da3f0eae7c/threads?statusID=114" | jq '.threads[0].metadata'
```

Expected response should include:
```json
{
  "metadata": {
    "billId": 2194599,
    "statusID": 114,
    "statusDescription": "לדיון במליאה לקראת קריאה שנייה-שלישית"
  }
}
```

## Current Status

- ✅ **Local dev backend:** Working correctly
- ❌ **Azure VM backend:** Needs deployment update
- ✅ **Code ready:** All changes committed locally

---

## Database Import Issue Resolution

### Problem
Database import from command-line `mysqldump` was completing immediately but not importing any data. Tables remained empty after import.

### Root Cause
Command-line `mysqldump` can produce SQL dumps with:
- Encoding issues (UTF-16 vs UTF-8)
- Formatting problems that cause silent import failures
- Path resolution issues with `SOURCE` command

### Solution
**Use MySQL Workbench to create database dumps instead of command-line `mysqldump`.**

MySQL Workbench:
- Handles encoding automatically (UTF-8/UTF-16)
- Produces properly formatted SQL that imports reliably
- Avoids path and encoding issues
- Provides better error reporting

### Steps for Future Imports
1. **Export:** Use MySQL Workbench → Server → Data Export → Export to Self-Contained File
2. **Transfer:** Upload SQL file to production server via SCP
3. **Import:** Use absolute path with `SOURCE` command and proper error handling:
   ```bash
   SQL_FILE=$(readlink -f ~/dayparty-dev-export.sql || realpath ~/dayparty-dev-export.sql)
   mysql -u dayparty -p'DayParty2024!SecurePW' dayparty <<EOF > /tmp/import.log 2>&1
   SET FOREIGN_KEY_CHECKS=0;
   SET UNIQUE_CHECKS=0;
   SET SQL_MODE='NO_AUTO_VALUE_ON_ZERO';
   SOURCE $SQL_FILE;
   SET FOREIGN_KEY_CHECKS=1;
   SET UNIQUE_CHECKS=1;
   EOF
   cat /tmp/import.log | grep -v "Using a password"
   ```
4. **Verify:** Always check that data was imported:
   ```bash
   mysql -u dayparty -p'DayParty2024!SecurePW' dayparty -e "SELECT COUNT(*) FROM _KNS_Faction;"
   ```

**See `backend/DATABASE_MIGRATION.md` for complete documentation.**
