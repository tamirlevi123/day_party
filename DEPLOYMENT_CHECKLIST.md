# Deployment Checklist - Memes Feature

## Pre-Deployment Checklist

- [x] Code committed and pushed to repository
- [ ] Verify VM is accessible
- [ ] Check current backend status on VM
- [ ] Backup database (if needed)

## Deployment Steps

### Step 1: SSH into Azure VM

```powershell
ssh azureuser@172.167.43.172
```

### Step 2: Navigate to Backend Directory

```bash
cd ~/dayparty-api/backend
```

### Step 3: Pull Latest Code

```bash
git pull origin master
```

### Step 4: Install Dependencies and Build

```bash
# Install dependencies
npm ci

# Generate Prisma client
npx prisma generate

# Build TypeScript
npm run build
```

### Step 5: Copy Memes Images (if not already on VM)

The memes images need to be in `backend/public/memes/` directory on the VM.

**Option A: Copy via SCP from local machine:**

```powershell
# From PowerShell on your local machine
scp -r E:\day_party\backend\public\memes azureuser@172.167.43.172:~/dayparty-api/backend/public/
```

**Option B: Copy from GoodMemes directory:**

```powershell
# From PowerShell on your local machine
scp -r E:\day_party\GoodMemes\* azureuser@172.167.43.172:~/dayparty-api/backend/public/memes/
```

### Step 6: Run Database Migrations (if needed)

```bash
cd ~/dayparty-api/backend

# Check if there are new migrations
npx prisma migrate status

# Deploy migrations
npx prisma migrate deploy
```

### Step 7: Restart PM2 Process

```bash
# Restart the application
pm2 restart dayparty-api

# Or if process doesn't exist:
pm2 start dist/server.js --name dayparty-api
pm2 save

# Check status
pm2 status
pm2 logs dayparty-api --lines 50
```

### Step 8: Verify Deployment

```bash
# Test health endpoint
curl http://localhost:3000/health

# Test memes endpoint (if you have memes topic)
curl http://localhost:3000/api/topics
```

### Step 9: Import Memes (if needed)

If you need to import memes from the GoodMemes directory:

```bash
cd ~/dayparty-api/backend

# First, ensure memes images are in public/memes/
# Then run the import script
tsx scripts/create-memes-topic.ts
tsx scripts/import-memes.ts --memes-dir ~/dayparty-api/backend/public/memes
```

## Quick Deployment Script

If the deployment script exists on the VM, you can use it:

```bash
~/deploy-backend.sh
```

Or run it remotely from your local machine:

```powershell
ssh azureuser@172.167.43.172 "~/deploy-backend.sh"
```

## Post-Deployment Verification

- [ ] Health endpoint responds: `https://172.167.43.172/health`
- [ ] API endpoints work: `https://172.167.43.172/api/topics`
- [ ] Memes images are accessible: `https://172.167.43.172/memes/1.png`
- [ ] PM2 process is running: `pm2 status`
- [ ] No errors in logs: `pm2 logs dayparty-api`

## Troubleshooting

### If git pull fails:
```bash
# Check git status
git status

# If there are local changes, stash them
git stash
git pull origin master
```

### If build fails:
```bash
# Clear and reinstall
rm -rf node_modules package-lock.json
npm install
npm run build
```

### If PM2 process won't start:
```bash
# Check logs
pm2 logs dayparty-api

# Check if port 3000 is in use
sudo netstat -tlnp | grep 3000

# Kill existing process if needed
pm2 delete dayparty-api
pm2 start dist/server.js --name dayparty-api
```

### If images don't load:
```bash
# Verify images exist
ls -la ~/dayparty-api/backend/public/memes/

# Check Nginx configuration
sudo nginx -t
sudo systemctl reload nginx
```

## Notes

- The VM IP is: **172.167.43.172**
- Backend runs on port **3000** (proxied by Nginx on port 80/443)
- Static files are served from `backend/public/` directory
- Memes images should be in `backend/public/memes/`
- Database migrations are handled by Prisma
