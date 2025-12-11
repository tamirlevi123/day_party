#!/usr/bin/env python3
"""
Simple SQLite query tool using Python's built-in sqlite3 module
(No need to install sqlite3.exe separately)

Usage:
    python scripts/sqlite-query.py "SELECT * FROM _KNS_Bill LIMIT 5"
    python scripts/sqlite-query.py "SELECT COUNT(*) FROM _KNS_DocumentBill WHERE BillID = 1046149"
"""

import sqlite3
import sys
import json
import os
from pathlib import Path

# Get database path
script_dir = Path(__file__).parent
db_path = script_dir.parent / 'data' / 'knesset_data.db'

if len(sys.argv) < 2:
    print("""
Usage:
    python scripts/sqlite-query.py "<SQL query>"

Examples:
    python scripts/sqlite-query.py "SELECT COUNT(*) FROM _KNS_Bill"
    python scripts/sqlite-query.py "SELECT * FROM _KNS_Bill WHERE BillID = 1046149"
    python scripts/sqlite-query.py "SELECT * FROM _KNS_DocumentBill WHERE BillID = 1046149"
    python scripts/sqlite-query.py ".tables"  # List all tables
    python scripts/sqlite-query.py ".schema _KNS_Bill"  # Show table schema
""")
    sys.exit(1)

query = sys.argv[1]

if not db_path.exists():
    print(f"❌ Database not found: {db_path}")
    sys.exit(1)

try:
    conn = sqlite3.connect(str(db_path))
    conn.row_factory = sqlite3.Row  # Return rows as dict-like objects
    cursor = conn.cursor()
    
    # Handle SQLite meta-commands
    if query.startswith('.'):
        # For meta-commands, we need to handle them specially
        if query == '.tables':
            cursor.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
            tables = cursor.fetchall()
            print("\nTables in database:")
            for table in tables:
                print(f"  - {table[0]}")
        elif query.startswith('.schema'):
            table_name = query.split()[-1] if len(query.split()) > 1 else None
            if table_name:
                cursor.execute(f"SELECT sql FROM sqlite_master WHERE type='table' AND name='{table_name}'")
                schema = cursor.fetchone()
                if schema:
                    print(f"\nSchema for {table_name}:")
                    print(schema[0])
                else:
                    print(f"❌ Table '{table_name}' not found")
            else:
                cursor.execute("SELECT name, sql FROM sqlite_master WHERE type='table' ORDER BY name")
                schemas = cursor.fetchall()
                print("\nAll table schemas:")
                for name, sql in schemas:
                    print(f"\n--- {name} ---")
                    print(sql)
        else:
            print(f"❌ Unknown meta-command: {query}")
    else:
        # Regular SQL query
        cursor.execute(query)
        
        # Check if it's a SELECT query (has results)
        if query.strip().upper().startswith('SELECT'):
            rows = cursor.fetchall()
            if rows:
                # Convert rows to list of dicts for JSON output
                results = [dict(row) for row in rows]
                print(json.dumps(results, indent=2, default=str))
            else:
                print("[]")
        else:
            # For INSERT/UPDATE/DELETE, commit and show affected rows
            conn.commit()
            print(f"✅ Query executed. Rows affected: {cursor.rowcount}")
    
    conn.close()
    
except sqlite3.Error as e:
    print(f"❌ SQLite Error: {e}")
    sys.exit(1)
except Exception as e:
    print(f"❌ Error: {e}")
    sys.exit(1)

