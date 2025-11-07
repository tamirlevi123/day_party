# Deploy Backend to Azure VM using Git

Guide to deploy backend code using Git (recommended method).

## Prerequisites

1. Git repository set up (GitHub, GitLab, or Azure DevOps)
2. Azure VM accessible via SSH
3. Backend code committed to git

## Step 1: Initialize Git Repository (If Not Already Done)

```powershell
cd E:\day_party\backend

# Initialize git (if not already done)
git init

# Add all files
git add .

# Commit
git commit -m "Initial backend commit"
```

## Step 2: Push to Remote Repository

### Option A: GitHub (Recommended)

```powershell
# Create repository on GitHub first, then:
git remote add origin https://github.com/YOUR_USERNAME/dayparty-backend.git
git branch -M main
git push -u origin main
```

### Option B: Azure DevOps

```powershell
git remote add origin https://dev.azure.com/YOUR_ORG/dayparty/_git/backend
git push -u origin main
```

### Option C: GitLab

```powershell
git remote add origin https://gitlab.com/YOUR_USERNAME/dayparty-backend.git
git push -u origin main
```

## Step 3: Set Up Git on Azure VM

SSH into the VM:

```powershell
ssh azureuser@172.167.43.172
```

On the VM:

```bash
# Navigate to app directory
cd ~/dayparty-api

# Clone repository (first time)
git clone <YOUR_REPO_URL> backend

# Or if directory already exists with old code:
cd ~/dayparty-api/backend
git init
git remote add origin <YOUR_REPO_URL>
git fetch
git checkout -b main origin/main
```

## Step 4: Deploy Latest Code

### On VM (after initial setup):

```bash
cd ~/dayparty-api/backend

# Pull latest changes
git pull origin main

# Install/update dependencies
npm ci

# Generate Prisma client
npx prisma generate

# Build TypeScript
npm run build

# Restart PM2
pm2 restart dayparty-api
```

## Step 5: Create Deployment Script

Create a script on the VM for easy deployments:

```bash
# On VM
nano ~/deploy-backend.sh
```

Add this content:

```bash
#!/bin/bash
set -e

echo "🚀 Starting deployment..."

cd ~/dayparty-api/backend

echo "📥 Pulling latest code..."
git pull origin main

echo "📦 Installing dependencies..."
npm ci

echo "🔧 Generating Prisma client..."
npx prisma generate

echo "🏗️ Building TypeScript..."
npm run build

echo "🔄 Restarting PM2 process..."
pm2 restart dayparty-api

echo "✅ Deployment complete!"
pm2 logs dayparty-api --lines 20
```

Make it executable:

```bash
chmod +x ~/deploy-backend.sh
```

Then deploy with:

```bash
~/deploy-backend.sh
```

## Step 6: Workflow for Future Deployments

### Local Development:

```powershell
# Make changes in E:\day_party\backend

# Commit changes
cd E:\day_party\backend
git add .
git commit -m "Your commit message"
git push origin main
```

### Deploy to VM:

```powershell
# SSH and run deployment script
ssh azureuser@172.167.43.172 "~/deploy-backend.sh"
```

Or SSH and run manually:

```powershell
ssh azureuser@172.167.43.172
cd ~/dayparty-api/backend
git pull origin main
npm ci && npx prisma generate && npm run build
pm2 restart dayparty-api
```

## Step 7: Handle Environment Variables

**Important:** Don't commit `.env` file to git!

### First Time Setup:

```bash
# On VM
cd ~/dayparty-api/backend
cp env.example .env
nano .env
# Edit with your configuration
```

### After Git Pull:

The `.env` file should be in `.gitignore`, so it won't be overwritten. But if you need to update it:

```bash
# On VM
cd ~/dayparty-api/backend
nano .env
# Make changes
pm2 restart dayparty-api
```

## Step 8: Database Migrations

After pulling code with new migrations:

```bash
cd ~/dayparty-api/backend
npx prisma migrate deploy
# OR if using db push:
# npx prisma db push
```

## Troubleshooting

### Git Pull Fails Due to Local Changes

```bash
# Stash local changes
git stash

# Pull
git pull origin main

# Apply stashed changes (if needed)
git stash pop
```

### PM2 Process Not Found

```bash
# Start process
pm2 start dist/server.js --name dayparty-api
pm2 save
```

### Build Fails

```bash
# Check for errors
npm run build

# Clear and reinstall
rm -rf node_modules package-lock.json
npm install
npm run build
```

## Quick Reference

**Deploy from local:**
```powershell
cd E:\day_party\backend
git add . && git commit -m "Update" && git push
ssh azureuser@172.167.43.172 "~/deploy-backend.sh"
```

**Check status on VM:**
```bash
cd ~/dayparty-api/backend
git status
pm2 status
pm2 logs dayparty-api
```

