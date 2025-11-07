# Clone Only Backend Folder from Git Repository

Use Git sparse checkout to clone only the `backend` folder from your repository.

## On Azure VM

```bash
cd ~/dayparty-api

# Remove old backend (if needed - use force)
sudo rm -rf backend

# Create directory
mkdir backend
cd backend

# Initialize git
git init

# Add remote
git remote add origin https://github.com/tamirlevi123/day_party.git

# Enable sparse checkout
git config core.sparseCheckout true

# Specify which folder to checkout
echo "backend/*" > .git/info/sparse-checkout

# Fetch and checkout
git fetch origin master
git checkout master

# Now you have only the backend folder
ls -la
```

## Alternative: Clone Full Repo but Work Only with Backend

If sparse checkout doesn't work or you prefer simpler approach:

```bash
cd ~/dayparty-api

# Clone full repo to a temp location
git clone https://github.com/tamirlevi123/day_party.git temp-repo

# Move backend folder
mv temp-repo/backend .

# Remove temp repo
rm -rf temp-repo

# Initialize git in backend folder (optional - for future pulls)
cd backend
git init
git remote add origin https://github.com/tamirlevi123/day_party.git
git fetch origin master
git checkout master -- backend/
```

## Recommended: Keep Full Clone (Simpler)

Actually, cloning the full repo is simpler and doesn't take much extra space:

```bash
cd ~/dayparty-api

# Clone full repo
git clone https://github.com/tamirlevi123/day_party.git repo

# Work with backend folder
cd repo/backend

# Install and build
npm ci
npx prisma generate
npm run build
```

Then for deployments, just pull from the repo root:

```bash
cd ~/dayparty-api/repo
git pull origin master
cd backend
npm ci && npx prisma generate && npm run build
pm2 restart dayparty-api
```

