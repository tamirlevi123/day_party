#!/bin/bash
# Sync MySQL Database from Dev to Production
# This script exports the dev database, transfers it to production, and imports it
#
# Usage:
#   ./sync-db-to-prod.sh
#
# Prerequisites:
#   - MySQL client tools installed
#   - SSH access to production server (172.167.43.172)
#   - Dev MySQL credentials configured
#   - Production MySQL password: DayParty2024!SecurePW

set -e

# Configuration
DEV_DB_USER="${DEV_DB_USER:-dayparty}"
DEV_DB_NAME="${DEV_DB_NAME:-dayparty}"
DEV_DB_HOST="${DEV_DB_HOST:-localhost}"
PROD_SERVER="${PROD_SERVER:-azureuser@172.167.43.172}"
PROD_DB_USER="${PROD_DB_USER:-dayparty}"
PROD_DB_PASSWORD="${PROD_DB_PASSWORD:-DayParty2024!SecurePW}"
PROD_DB_NAME="${PROD_DB_NAME:-dayparty}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Functions
step() { echo -e "\n${CYAN}🔵 $1${NC}"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BACKEND_DIR="$(dirname "$SCRIPT_DIR")"
EXPORT_FILE="$BACKEND_DIR/dayparty-dev-export.sql"
EXPORT_ZIP="$BACKEND_DIR/dayparty-dev-export.sql.zip"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

echo -e "\n${CYAN}========================================"
echo "  MySQL Database Sync: Dev → Production"
echo -e "========================================${NC}\n"

# Step 1: Export from Dev
step "Step 1: Exporting MySQL database from dev server..."

# Prompt for dev MySQL password
read -sp "Enter MySQL password for dev server ($DEV_DB_USER@$DEV_DB_HOST): " DEV_DB_PASSWORD
echo ""

# Remove old export files
if [ -f "$EXPORT_FILE" ]; then
    rm -f "$EXPORT_FILE"
    success "Removed old export file"
fi
if [ -f "$EXPORT_ZIP" ]; then
    rm -f "$EXPORT_ZIP"
    success "Removed old export zip"
fi

# Export database
echo -e "${YELLOW}Exporting database...${NC}"
MYSQL_PWD="$DEV_DB_PASSWORD" mysqldump -u "$DEV_DB_USER" -h "$DEV_DB_HOST" \
    --single-transaction \
    --routines \
    --triggers \
    --events \
    --add-drop-table \
    --default-character-set=utf8mb4 \
    "$DEV_DB_NAME" > "$EXPORT_FILE"

if [ $? -ne 0 ]; then
    error "Failed to export database"
    exit 1
fi

EXPORT_SIZE=$(du -h "$EXPORT_FILE" | cut -f1)
success "Database exported: $EXPORT_FILE ($EXPORT_SIZE)"

# Compress export
echo -e "${YELLOW}Compressing export...${NC}"
gzip -c "$EXPORT_FILE" > "${EXPORT_FILE}.gz" || zip -q "$EXPORT_ZIP" "$EXPORT_FILE"
ZIP_SIZE=$(du -h "${EXPORT_FILE}.gz" 2>/dev/null || du -h "$EXPORT_ZIP" | cut -f1)
success "Export compressed: ${EXPORT_FILE}.gz or $EXPORT_ZIP ($ZIP_SIZE)"

# Clean up uncompressed file
rm -f "$EXPORT_FILE"

# Step 2: Transfer to Production
step "Step 2: Transferring database dump to production server..."

TRANSFER_FILE="${EXPORT_FILE}.gz"
if [ ! -f "$TRANSFER_FILE" ]; then
    TRANSFER_FILE="$EXPORT_ZIP"
fi

echo -e "${YELLOW}Transferring file via SCP...${NC}"
scp "$TRANSFER_FILE" "${PROD_SERVER}:~/dayparty-dev-export.sql.gz"

if [ $? -ne 0 ]; then
    error "Failed to transfer file to production server"
    exit 1
fi

success "File transferred to production server"

# Step 3: Import on Production
step "Step 3: Importing database on production server..."

ssh "$PROD_SERVER" << EOF
set -e

cd ~/dayparty/backend

echo "📦 Stopping application..."
pm2 stop dayparty-api || true

echo "💾 Backing up current production database..."
BACKUP_FILE="dayparty-production-backup-\$(date +%Y%m%d-%H%M%S).sql"
mysqldump -u $PROD_DB_USER -p'$PROD_DB_PASSWORD' $PROD_DB_NAME > "\$BACKUP_FILE"
echo "✅ Backup saved: \$BACKUP_FILE"

echo "📥 Importing dev database..."
gunzip -c ~/dayparty-dev-export.sql.gz | mysql -u $PROD_DB_USER -p'$PROD_DB_PASSWORD' $PROD_DB_NAME

echo "🔍 Verifying import..."
mysql -u $PROD_DB_USER -p'$PROD_DB_PASSWORD' $PROD_DB_NAME -e "
  SELECT 'users' as table_name, COUNT(*) as count FROM users
  UNION ALL SELECT 'topics', COUNT(*) FROM topics
  UNION ALL SELECT 'threads', COUNT(*) FROM threads
  UNION ALL SELECT 'nodes', COUNT(*) FROM nodes;
"

echo "🔧 Running Prisma migrations..."
npx prisma migrate deploy || true

echo "🔧 Regenerating Prisma Client..."
npx prisma generate

echo "🏗️  Rebuilding application..."
npm run build

echo "🔄 Restarting application..."
pm2 restart dayparty-api || pm2 start dist/server.js --name dayparty-api
pm2 save

echo "📋 Recent logs:"
pm2 logs dayparty-api --lines 10 --nostream

echo "✅ Database sync complete!"
EOF

if [ $? -ne 0 ]; then
    error "Failed to import database on production server"
    exit 1
fi

success "Database imported successfully on production server"

echo -e "\n${GREEN}========================================"
echo "  Database Sync Complete!"
echo -e "========================================${NC}\n"
