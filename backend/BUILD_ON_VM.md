# Building Backend on Azure VM - Memory Issues

The Standard B1s VM has limited RAM (1GB), which can cause builds to be killed.

## Solution 1: Build Locally and Deploy dist/ Folder (Recommended)

Build on your local machine (more RAM), then copy just the `dist/` folder:

### On Local Machine:

```powershell
cd E:\day_party\backend
npm run build

# Verify dist folder was created
ls dist
```

### Copy dist folder to VM:

```powershell
# Copy dist folder
scp -r backend\dist azureuser@172.167.43.172:~/dayparty/backend/

# Also copy package.json and node_modules are already there
```

### On VM:

```bash
cd ~/dayparty/backend

# dist folder should now exist
ls dist

# Start PM2
pm2 start dist/server.js --name dayparty-api
pm2 save
```

## Solution 2: Increase Swap Space on VM

If you want to build on VM, increase swap:

```bash
# Create swap file (2GB)
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Make permanent
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Verify
free -h

# Now try build again
npm run build
```

## Solution 3: Build with Limited Memory

Use Node with memory limit:

```bash
# Build with 512MB memory limit for Node
NODE_OPTIONS="--max-old-space-size=512" npm run build
```

## Solution 4: Use PM2 to Build (Background)

You can't really "background" a build, but you can use `nohup` or `screen`:

```bash
# Install screen (if not installed)
sudo apt install screen -y

# Start screen session
screen -S build

# Run build
npm run build

# Detach: Press Ctrl+A then D
# Reattach: screen -r build
```

## Recommended: Build Locally + Deploy dist/

This is the fastest and most reliable approach:

1. **Local:** `npm run build` (has enough RAM)
2. **Copy:** `scp -r backend\dist azureuser@172.167.43.172:~/dayparty/backend/`
3. **VM:** `pm2 start dist/server.js --name dayparty-api`

No memory issues, faster builds, and you can see build errors locally.


