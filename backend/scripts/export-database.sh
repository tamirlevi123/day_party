#!/bin/bash
# Export MySQL database from development server
# Usage: ./export-database.sh [output-file]

set -e

DB_USER="${DB_USER:-dayparty}"
DB_PASSWORD="${DB_PASSWORD:-}"
DB_NAME="${DB_NAME:-dayparty}"
DB_HOST="${DB_HOST:-localhost}"
OUTPUT_FILE="${1:-dayparty-export-$(date +%Y%m%d-%H%M%S).sql}"

echo "📤 Exporting MySQL database..."
echo "   Database: $DB_NAME"
echo "   Host: $DB_HOST"
echo "   Output: $OUTPUT_FILE"

# Export database
mysqldump -h "$DB_HOST" \
  -u "$DB_USER" \
  -p"$DB_PASSWORD" \
  --single-transaction \
  --routines \
  --triggers \
  --events \
  --add-drop-table \
  --default-character-set=utf8mb4 \
  "$DB_NAME" > "$OUTPUT_FILE"

# Compress the dump
gzip "$OUTPUT_FILE"
echo "✅ Database exported and compressed: ${OUTPUT_FILE}.gz"
echo "   Size: $(du -h ${OUTPUT_FILE}.gz | cut -f1)"
