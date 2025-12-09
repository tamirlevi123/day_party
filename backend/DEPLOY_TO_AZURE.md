# Deploy Backend to Azure VM

Quick deployment guide for the current backend code to Azure VM.

## Prerequisites

1. Azure VM exists (or create new one per `20-Azure-VM-Setup.md`)
2. SSH access to VM
3. Backend code ready locally

## Step 1: Check/Recreate VM

```bash
# Login to Azure
az login

# Check if VM exists
az vm list --resource-group dayparty-rg --output table

# If VM doesn't exist, create it (see 20-Azure-VM-Setup.md)
# Get VM IP
az vm show -d -g dayparty-rg -n dayparty-vm --query publicIps -o tsv
```

**Current VM IP:** `172.167.43.172` (uksouth)

## Step 2: Prepare Backend for Deployment

From your local machine:

```bash
cd E:\day_party\backend

# Ensure everything is built
npm install
npm run build

# Create deployment package (optional - or use git)
# tar -czf backend-deploy.tar.gz . --exclude node_modules --exclude .git
```

## Step 3: Deploy to VM

### Option A: Using Git (Recommended)

```bash
# SSH into VM
ssh azureuser@172.167.43.172

# Navigate to app directory
cd /var/www/dayparty-api

# Pull latest code (if using git)
git pull origin main

# Or clone if first time
# git clone <YOUR_REPO_URL> /var/www/dayparty-api
```

### Option B: Using SCP (Direct Copy)

```bash
# From local machine, copy backend folder
scp -r E:\day_party\backend azureuser@172.167.43.172:/var/www/dayparty-api/
```

## Step 4: Install Dependencies and Build

```bash
# SSH into VM
ssh azureuser@172.167.43.172

cd /var/www/dayparty-api/backend

# Install dependencies
npm ci --production=false

# Generate Prisma client
npx prisma generate

# Build TypeScript
npm run build
```

## Step 5: Configure Environment Variables

```bash
# Create .env file
cd /var/www/dayparty-api/backend
cp env.example .env
nano .env
```

**Required .env values:**

```env
# Database (already configured on VM)
DATABASE_URL="mysql://dayparty:DayParty2024!SecurePW@localhost:3306/dayparty"

# JWT Secret (generate a secure random string)
JWT_SECRET="your-super-secret-jwt-key-change-this-in-production"

# Server
PORT=3000
NODE_ENV="production"

# Google OAuth (update with your credentials)
GOOGLE_CLIENT_ID="your-google-client-id"
GOOGLE_CLIENT_SECRET="your-google-client-secret"
GOOGLE_CALLBACK_URL="https://172.167.43.172/api/auth/google/callback"

# CORS (update with your Flutter app domain/IP)
CORS_ORIGIN="*"

# Google Drive (if using)
GOOGLE_DRIVE_CLIENT_ID="your-drive-client-id"
GOOGLE_DRIVE_CLIENT_SECRET="your-drive-client-secret"
GOOGLE_DRIVE_REFRESH_TOKEN="your-refresh-token"
GOOGLE_DRIVE_FOLDER_ID="your-folder-id"
```

## Step 6: Run Database Migrations

```bash
cd /var/www/dayparty-api/backend

# If using Prisma migrations
npx prisma migrate deploy

# Or if using db push (development)
# npx prisma db push

# 📌 New (Nov 2025): External video links
# If migrate deploy is not available, run the SQL in
# `prisma/migrations/20251110090000_add_external_video_support/migration.sql`
# to add the new columns and enum values required for linked videos.
```

## Step 7: Start with PM2

```bash
# Stop existing process (if any)
pm2 stop dayparty-api || true
pm2 delete dayparty-api || true

# Start new process
pm2 start dist/server.js --name dayparty-api

# Save PM2 configuration
pm2 save

# Check status
pm2 status
pm2 logs dayparty-api
```

## Step 8: Update Nginx Configuration

```bash
# Edit Nginx config
sudo nano /etc/nginx/sites-available/dayparty-api
```

Ensure it proxies to port 3000:

```nginx
server {
    listen 80;
    server_name 172.167.43.172;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Increase body size for video uploads
    client_max_body_size 500M;
}
```

```bash
# Test and reload Nginx
sudo nginx -t
sudo systemctl reload nginx
```

## Step 9: Test the API

```bash
# Health check
curl http://172.167.43.172/health

# Or from browser
# http://172.167.43.172/health
```

## Step 10: Update Flutter App

Update `lib/core/api_client.dart` to use Azure VM IP:

```dart
static const String _physicalDeviceIp = '172.167.43.172';
```

Or better - update the baseUrl logic to use the Azure VM for both emulator and physical device:

```dart
// For production, use Azure VM
static const String _azureVmIp = '172.167.43.172';
```

## Troubleshooting

### PM2 Process Not Starting
```bash
pm2 logs dayparty-api
# Check for errors in logs
```

### Database Connection Issues
```bash
# Test MySQL connection
mysql -u dayparty -p dayparty
# Password: DayParty2024!SecurePW

# Check .env DATABASE_URL
cat /var/www/dayparty-api/backend/.env | grep DATABASE_URL
```

### Port Already in Use
```bash
# Check what's using port 3000
sudo netstat -tlnp | grep 3000

# Kill process if needed
sudo kill -9 <PID>
```

### Nginx 502 Bad Gateway
```bash
# Check if app is running
pm2 status

# Check Nginx error logs
sudo tail -f /var/log/nginx/error.log
```

## Quick Deployment Script

Save this as `deploy.sh` on the VM:

```bash
#!/bin/bash
cd /var/www/dayparty-api/backend
git pull
npm ci
npx prisma generate
npm run build
pm2 reload dayparty-api
echo "Deployment complete!"
```

Make it executable:
```bash
chmod +x deploy.sh
```

Then deploy with:
```bash
./deploy.sh
```

