# Database Migration Guide: Dev to Production

This guide covers migrating MySQL data from your development server to the production Azure VM.

## Prerequisites

- MySQL client tools installed on both dev and production servers
- Access to both databases
- SSH access to Azure VM

## Step 1: Export Database from Development Server

### Option A: Using MySQL Workbench (Easiest)

1. Open **MySQL Workbench**
2. Connect to your development database
3. Go to **Server** → **Data Export**
4. Select the `dayparty` database
5. Choose **Export to Self-Contained File**
6. Select **Include Create Schema**
7. Click **Start Export**
8. Save the file (e.g., `dayparty-dev-export.sql`)

### Option B: Using Command Line (Windows PowerShell)

```powershell
cd E:\day_party\backend

# Set your dev database password
$env:DB_PASSWORD = "your-dev-password"

# Export database
mysqldump -u dayparty -p$env:DB_PASSWORD `
  --single-transaction `
  --routines `
  --triggers `
  --events `
  --add-drop-table `
  --default-character-set=utf8mb4 `
  dayparty > dayparty-dev-export.sql

# Compress the dump (optional but recommended)
Compress-Archive -Path dayparty-dev-export.sql -DestinationPath dayparty-dev-export.sql.zip
```

### Option C: Using the Export Script

```powershell
cd E:\day_party\backend\scripts

# Set environment variables
$env:DB_USER = "dayparty"
$env:DB_PASSWORD = "your-dev-password"
$env:DB_NAME = "dayparty"
$env:DB_HOST = "localhost"

# Run export script (if you have bash/WSL)
bash export-database.sh dayparty-dev-export.sql
```

## Step 2: Transfer Dump File to Production Server

### Option A: Using SCP (Recommended)

```powershell
# From your local machine (PowerShell)
scp E:\day_party\backend\dayparty-dev-export.sql.gz azureuser@172.167.43.172:~/dayparty-dev-export.sql.gz
```

### Option B: Using Git (if file is small enough)

```powershell
# Add to git (if under size limit)
git add dayparty-dev-export.sql.gz
git commit -m "Database export for production migration"
git push origin master

# On VM, pull the file
ssh azureuser@172.167.43.172
cd ~/dayparty/backend
git pull origin master
```

### Option C: Using Azure Storage/Blob (for large files)

If the dump is very large, upload to Azure Blob Storage and download on the VM.

## Step 3: Import Database on Production Server

**⚠️ WARNING: This will REPLACE all existing data in production!**

### Option A: Using MySQL Command Line

```bash
# SSH into Azure VM
ssh azureuser@172.167.43.172

# Navigate to backend directory
cd ~/dayparty/backend

# Stop the application (to prevent conflicts)
pm2 stop dayparty-api

# Backup current production database (safety first!)
mysqldump -u dayparty -p dayparty > dayparty-production-backup-$(date +%Y%m%d-%H%M%S).sql
# Password: DayParty2024!SecurePW

# Import the dev database
# If compressed:
gunzip -c dayparty-dev-export.sql.gz | mysql -u dayparty -p dayparty
# Password: DayParty2024!SecurePW

# Or if not compressed:
mysql -u dayparty -p dayparty < dayparty-dev-export.sql
# Password: DayParty2024!SecurePW

# Verify import
mysql -u dayparty -p dayparty -e "
  SELECT 
    'users' as table_name, COUNT(*) as count FROM users
  UNION ALL
  SELECT 'topics', COUNT(*) FROM topics
  UNION ALL
  SELECT 'threads', COUNT(*) FROM threads
  UNION ALL
  SELECT 'nodes', COUNT(*) FROM nodes;
"

# Run Prisma migrations to ensure schema is up to date
npx prisma migrate deploy

# Regenerate Prisma Client
npx prisma generate

# Rebuild application
npm run build

# Restart the application
pm2 start ecosystem.config.js
pm2 save

# Check logs
pm2 logs dayparty-api --lines 20
```

### Option B: Using the Import Script

```bash
cd ~/dayparty/backend/scripts

# Set environment variables
export DB_USER=dayparty
export DB_PASSWORD="DayParty2024!SecurePW"
export DB_NAME=dayparty
export DB_HOST=localhost

# Make script executable
chmod +x import-database.sh

# Run import
./import-database.sh ~/dayparty-dev-export.sql.gz
```

## Step 4: Verify Migration

```bash
# Test API endpoints
curl http://localhost:3000/health
curl http://localhost:3000/api/topics

# Check specific data
mysql -u dayparty -p dayparty -e "
  SELECT name, description FROM topics LIMIT 5;
  SELECT COUNT(*) as total_threads FROM threads;
  SELECT COUNT(*) as total_nodes FROM nodes;
"
```

## Important Notes

1. **Backup First**: Always backup production before importing!
2. **Schema Compatibility**: Ensure production schema matches or is newer than dev schema
3. **User Accounts**: User passwords and authentication tokens will be migrated
4. **File Paths**: If your app uses file paths, ensure they're correct for production
5. **Environment Variables**: Update `.env` on production if needed
6. **Static Files**: Don't forget to copy `public/memes/` and other static files if needed

## Troubleshooting

### Error: "Table already exists"
The dump includes `DROP TABLE` statements. If you get this error, the tables might be locked. Stop the application first.

### Error: "Access denied"
Check database user permissions:
```bash
mysql -u dayparty -p -e "SHOW GRANTS FOR 'dayparty'@'localhost';"
```

### Error: "Unknown collation"
Ensure both databases use `utf8mb4_unicode_ci`:
```sql
ALTER DATABASE dayparty CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

### Large File Transfer Issues
If the dump is very large (>100MB), consider:
- Using `mysqldump` with compression: `mysqldump ... | gzip > dump.sql.gz`
- Transferring via Azure Blob Storage
- Using `rsync` for resumable transfers

## Partial Migration (Selective Tables)

If you only want to migrate specific tables:

```bash
# Export only specific tables
mysqldump -u dayparty -p dayparty users topics threads nodes > partial-export.sql

# Import only those tables
mysql -u dayparty -p dayparty < partial-export.sql
```

## Rollback Plan

If something goes wrong:

```bash
# Restore from backup
mysql -u dayparty -p dayparty < dayparty-production-backup-YYYYMMDD-HHMMSS.sql

# Restart application
pm2 restart dayparty-api
```

---

**Remember**: Test the migration process on a staging environment first if possible!
