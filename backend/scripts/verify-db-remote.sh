#!/bin/bash
set -e

echo "[INFO] Checking database connection and table counts..."
# Suppress MySQL password warnings (redirect stderr to /dev/null)
mysql -u PLACEHOLDER_DB_USER -p'PLACEHOLDER_DB_PASSWORD' PLACEHOLDER_DB_NAME -e "
SELECT 
    'users' as table_name, COUNT(*) as count FROM users
UNION ALL SELECT 'topics', COUNT(*) FROM topics
UNION ALL SELECT 'threads', COUNT(*) FROM threads
UNION ALL SELECT 'nodes', COUNT(*) FROM nodes
ORDER BY table_name;
" 2>/dev/null || {
    echo "[ERROR] Database verification failed"
    exit 1
}

echo "[OK] Database verification passed"
