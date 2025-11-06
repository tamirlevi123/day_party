# Deploy Backend to Azure VM using SCP

Quick guide to copy backend code to Azure VM using SCP.

## Prerequisites

1. Azure VM IP: `172.167.43.172`
2. SSH access configured
3. Backend code ready in `E:\day_party\backend`

## Step 1: Build Backend Locally (Optional but Recommended)

```powershell
cd E:\day_party\backend

# Install dependencies
npm install

# Build TypeScript
npm run build

# Generate Prisma client
npx prisma generate
```

## Step 2: Prepare Deployment Package

Create a clean copy excluding unnecessary files:

```powershell
cd E:\day_party\backend

# Create a temporary deployment directory
mkdir ..\backend-deploy
xcopy /E /I /Y . ..\backend-deploy

# Remove unnecessary files from deployment folder
cd ..\backend-deploy
rmdir /S /Q node_modules
rmdir /S /Q .git
del /F /Q *.log
del /F /Q .env
```

Or use PowerShell to create a clean archive:

```powershell
cd E:\day_party\backend

# Create deployment archive (excludes node_modules, .git, etc.)
Compress-Archive -Path * -DestinationPath ..\backend-deploy.zip -Force
```

## Step 3: Copy to Azure VM using SCP

### Option A: Copy Entire Backend Folder

```powershell
# From PowerShell (Windows)
cd E:\day_party

# Copy backend folder to VM
scp -r backend azureuser@172.167.43.172:/var/www/dayparty-api/
```

### Option B: Copy Deployment Archive

```powershell
# Copy zip file
scp backend-deploy.zip azureuser@172.167.43.172:/tmp/

# Then SSH and extract
ssh azureuser@172.167.43.172
cd /var/www/dayparty-api
sudo rm -rf backend
sudo mkdir -p backend
cd backend
sudo unzip /tmp/backend-deploy.zip
sudo chown -R azureuser:azureuser /var/www/dayparty-api/backend
```

### Option C: Copy Specific Files Only (Faster)

```powershell
# Copy only source and config files (exclude node_modules)
cd E:\day_party\backend

# Copy package files
scp package.json package-lock.json azureuser@172.167.43.172:/var/www/dayparty-api/backend/

# Copy source code
scp -r src azureuser@172.167.43.172:/var/www/dayparty-api/backend/
scp -r prisma azureuser@172.167.43.172:/var/www/dayparty-api/backend/
scp tsconfig.json azureuser@172.167.43.172:/var/www/dayparty-api/backend/
scp env.example azureuser@172.167.43.172:/var/www/dayparty-api/backend/
```

## Step 4: SSH into VM and Complete Setup

```powershell
# SSH into VM
ssh azureuser@172.167.43.172
```

Then on the VM:

```bash
# Navigate to backend directory
cd /var/www/dayparty-api/backend

# Install dependencies
npm ci

# Generate Prisma client
npx prisma generate

# Build TypeScript
npm run build

# Create .env file
cp env.example .env
nano .env
# Edit with your configuration (see below)

# Run database migrations (if needed)
npx prisma migrate deploy
# OR if using db push:
# npx prisma db push
```

## Step 5: Configure Environment Variables

```bash
nano .env
```

Required configuration:

```env
DATABASE_URL="mysql://dayparty:DayParty2024!SecurePW@localhost:3306/dayparty"
JWT_SECRET="your-super-secret-jwt-key-change-this"
PORT=3000
NODE_ENV="production"
GOOGLE_CLIENT_ID="your-google-client-id"
GOOGLE_CLIENT_SECRET="your-google-client-secret"
GOOGLE_CALLBACK_URL="https://172.167.43.172/api/auth/google/callback"
CORS_ORIGIN="*"
GOOGLE_DRIVE_CLIENT_ID="your-drive-client-id"
GOOGLE_DRIVE_CLIENT_SECRET="your-drive-client-secret"
GOOGLE_DRIVE_REFRESH_TOKEN="your-refresh-token"
GOOGLE_DRIVE_FOLDER_ID="your-folder-id"
```

## Step 6: Start with PM2

```bash
# Stop existing process (if any)
pm2 stop dayparty-api || true
pm2 delete dayparty-api || true

# Start new process
pm2 start dist/server.js --name dayparty-api

# Save PM2 configuration
pm2 save

# Check status and logs
pm2 status
pm2 logs dayparty-api
```

## Step 7: Verify Deployment

```bash
# Test health endpoint
curl http://localhost:3000/health

# Or from your local machine
curl http://172.167.43.172/health
```

## Quick One-Liner SCP Command

If you just want to copy everything quickly:

```powershell
cd E:\day_party
scp -r backend azureuser@172.167.43.172:/var/www/dayparty-api/
```

Then SSH and run:
```bash
cd /var/www/dayparty-api/backend
npm ci && npx prisma generate && npm run build
pm2 restart dayparty-api
```

## Troubleshooting

### SCP Permission Denied
```bash
# On VM, ensure directory exists and has correct permissions
sudo mkdir -p /var/www/dayparty-api
sudo chown -R azureuser:azureuser /var/www/dayparty-api
```

### Connection Refused
- Check if VM is running: `az vm show -d -g dayparty-rg -n dayparty-vm --query powerState`
- Verify SSH port is open: `az vm show -d -g dayparty-rg -n dayparty-vm --query networkProfile.networkSecurityGroup`
- Check if you can ping: `ping 172.167.43.172`

### File Transfer Slow
- Use compression: `scp -C -r backend azureuser@172.167.43.172:/var/www/dayparty-api/`
- Or use rsync if available: `rsync -avz --exclude node_modules backend/ azureuser@172.167.43.172:/var/www/dayparty-api/backend/`

