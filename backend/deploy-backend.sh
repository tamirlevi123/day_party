#!/bin/bash
set -e

echo "🚀 Starting deployment..."

cd ~/dayparty/backend

echo "📥 Pulling latest code..."
git pull origin master

echo "📦 Installing dependencies..."
npm ci

echo "🔧 Generating Prisma client..."
npx prisma generate

echo "🏗️ Building TypeScript..."
npm run build

echo "🔄 Restarting PM2 process..."
pm2 restart dayparty-api || pm2 start dist/server.js --name dayparty-api

echo "✅ Deployment complete!"
pm2 logs dayparty-api --lines 20

