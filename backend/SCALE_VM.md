# Scale Azure VM for Better Performance

## Current VM Configuration

- **VM Name**: dayparty-vm
- **Resource Group**: dayparty-rg
- **Current Size**: Standard_B1s
- **Specs**: 1 vCPU, 1GB RAM
- **Cost**: ~$10/month
- **Issue**: Too slow for compilation, halts during `npm run build` and `npx prisma generate`

## Recommended VM Sizes

### Option 1: Standard_B2s (Recommended for Development)
- **Specs**: 2 vCPU, 4GB RAM
- **Cost**: ~$30/month (~$0.04/hour)
- **Best for**: Building TypeScript, running Prisma, handling moderate traffic
- **Why**: Double CPU and 4x RAM - should handle compilation smoothly

### Option 2: Standard_B2ms (Better Performance)
- **Specs**: 2 vCPU, 8GB RAM
- **Cost**: ~$60/month (~$0.08/hour)
- **Best for**: Heavy compilation, multiple services, more traffic
- **Why**: Same CPU but more RAM for better multitasking

### Option 3: Standard_D2s_v3 (Production Ready)
- **Specs**: 2 vCPU, 8GB RAM
- **Cost**: ~$75/month (~$0.10/hour)
- **Best for**: Production workloads, better CPU performance
- **Why**: Faster CPU (not burstable), better for consistent workloads

### Option 4: Standard_B1ms (Minimal Upgrade)
- **Specs**: 1 vCPU, 2GB RAM
- **Cost**: ~$15/month (~$0.02/hour)
- **Best for**: Small improvement, still may struggle with compilation
- **Why**: 2x RAM but same CPU - may not solve compilation issues

## Scaling Steps

### Step 1: Check Current VM Status

```bash
# Check current VM size
az vm show \
  --resource-group dayparty-rg \
  --name dayparty-vm \
  --query "hardwareProfile.vmSize" \
  --output tsv

# Check VM state (must be deallocated to resize)
az vm show \
  --resource-group dayparty-rg \
  --name dayparty-vm \
  --query "powerState" \
  --output tsv
```

### Step 2: Deallocate VM (Required for Resize)

**⚠️ IMPORTANT**: This will cause brief downtime (1-2 minutes)

```bash
# Stop and deallocate VM
az vm deallocate \
  --resource-group dayparty-rg \
  --name dayparty-vm

# Wait for deallocation to complete (check status)
az vm show \
  --resource-group dayparty-rg \
  --name dayparty-vm \
  --query "powerState" \
  --output tsv
# Should show: "VM deallocated"
```

### Step 3: Resize VM

#### Recommended: Standard_B2s

```bash
# Resize to Standard_B2s (2 vCPU, 4GB RAM)
az vm resize \
  --resource-group dayparty-rg \
  --name dayparty-vm \
  --size Standard_B2s
```

#### Alternative: Standard_B2ms (More RAM)

```bash
# Resize to Standard_B2ms (2 vCPU, 8GB RAM)
az vm resize \
  --resource-group dayparty-rg \
  --name dayparty-vm \
  --size Standard_B2ms
```

### Step 4: Start VM

```bash
# Start the VM
az vm start \
  --resource-group dayparty-rg \
  --name dayparty-vm

# Wait for VM to be ready (30-60 seconds)
az vm show \
  --resource-group dayparty-rg \
  --name dayparty-vm \
  --query "powerState" \
  --output tsv
# Should show: "VM running"

# Get new IP (if changed)
az vm show -d -g dayparty-rg -n dayparty-vm --query publicIps -o tsv
```

### Step 5: Verify New Size

```bash
# SSH into VM and check
ssh azureuser@<VM_IP>

# Check CPU cores
nproc

# Check RAM
free -h

# Check VM size in Azure
az vm show \
  --resource-group dayparty-rg \
  --name dayparty-vm \
  --query "hardwareProfile.vmSize" \
  --output tsv
```

## Quick Resize Script

Save this as `resize-vm.sh`:

```bash
#!/bin/bash
set -e

VM_NAME="dayparty-vm"
RESOURCE_GROUP="dayparty-rg"
NEW_SIZE="Standard_B2s"  # Change to your desired size

echo "🛑 Stopping VM..."
az vm deallocate --resource-group $RESOURCE_GROUP --name $VM_NAME

echo "⏳ Waiting for deallocation..."
sleep 10

echo "📏 Resizing VM to $NEW_SIZE..."
az vm resize \
  --resource-group $RESOURCE_GROUP \
  --name $VM_NAME \
  --size $NEW_SIZE

echo "🚀 Starting VM..."
az vm start --resource-group $RESOURCE_GROUP --name $VM_NAME

echo "✅ VM resized and started!"
echo "📊 New VM size:"
az vm show \
  --resource-group $RESOURCE_GROUP \
  --name $VM_NAME \
  --query "hardwareProfile.vmSize" \
  --output tsv

echo "🌐 Public IP:"
az vm show -d -g $RESOURCE_GROUP -n $VM_NAME --query publicIps -o tsv
```

Make executable and run:
```bash
chmod +x resize-vm.sh
./resize-vm.sh
```

## Cost Comparison

| Size | vCPU | RAM | Monthly Cost | Hourly Cost | Best For |
|------|------|-----|--------------|-------------|----------|
| **B1s** (current) | 1 | 1GB | ~$10 | ~$0.013 | MVP only, no compilation |
| **B1ms** | 1 | 2GB | ~$15 | ~$0.02 | Slight improvement |
| **B2s** ⭐ | 2 | 4GB | ~$30 | ~$0.04 | **Recommended** - Good balance |
| **B2ms** | 2 | 8GB | ~$60 | ~$0.08 | Heavy compilation |
| **D2s_v3** | 2 | 8GB | ~$75 | ~$0.10 | Production workloads |

## Alternative: Build Locally (Cost-Free Solution)

Instead of scaling the VM, you can build locally and copy the `dist` folder:

### Benefits
- ✅ No VM cost increase
- ✅ Faster builds (your local machine is likely faster)
- ✅ No VM downtime

### Process

1. **Build locally:**
   ```powershell
   cd E:\day_party\backend
   npm run build
   npx prisma generate
   ```

2. **Copy dist folder to VM:**
   ```powershell
   scp -r E:\day_party\backend\dist azureuser@172.167.43.172:~/dayparty/backend/
   ```

3. **On VM, only generate Prisma client (quick):**
   ```bash
   cd ~/dayparty/backend
   npx prisma generate  # This is fast, only generates Prisma client
   pm2 restart dayparty-api
   ```

### Recommended Workflow

**For regular deployments:**
- Build locally
- Copy `dist/` folder via SCP
- Run `npx prisma generate` on VM (fast)
- Restart PM2

**Only compile on VM when:**
- Prisma schema changes (need to regenerate client)
- Dependencies change (need `npm ci`)

## When to Scale vs. Build Locally

### Scale VM if:
- ✅ You need to compile frequently on VM
- ✅ You want automated CI/CD that builds on VM
- ✅ You have budget for better performance
- ✅ You're running multiple services on same VM

### Build Locally if:
- ✅ You want to save costs
- ✅ Your local machine is faster
- ✅ You don't mind manual deployment
- ✅ Compilation is infrequent

## Recommendation

**For now (immediate solution):**
- ✅ **Build locally** and copy `dist/` folder (already set up)
- This solves the immediate problem at no cost

**For future (when budget allows):**
- ✅ **Scale to Standard_B2s** (~$30/month)
- Good balance of cost and performance
- Can handle compilation smoothly
- Enough resources for production traffic

## Resize Commands (Quick Reference)

```bash
# Check current size
az vm show -g dayparty-rg -n dayparty-vm --query "hardwareProfile.vmSize" -o tsv

# Deallocate
az vm deallocate -g dayparty-rg -n dayparty-vm

# Resize to B2s
az vm resize -g dayparty-rg -n dayparty-vm --size Standard_B2s

# Start
az vm start -g dayparty-rg -n dayparty-vm

# Get IP
az vm show -d -g dayparty-rg -n dayparty-vm --query publicIps -o tsv
```

## Monitoring After Resize

```bash
# Check VM metrics in Azure Portal
# Or use Azure CLI:
az vm monitor metrics list \
  --resource-group dayparty-rg \
  --resource dayparty-vm \
  --metric "Percentage CPU" "Available Memory Bytes" \
  --output table
```

