/**
 * Simple SQLite query tool
 * 
 * Usage:
 *   npx tsx scripts/sqlite-query.ts "SELECT * FROM _KNS_Bill LIMIT 5"
 *   npx tsx scripts/sqlite-query.ts "SELECT COUNT(*) FROM _KNS_DocumentBill WHERE BillID = 1046149"
 */

import Database from 'better-sqlite3';
import * as path from 'path';
import * as fs from 'fs';

const DB_PATH = path.join(__dirname, '..', 'data', 'knesset_data.db');

const query = process.argv[2];

if (!query) {
  console.log(`
Usage:
  npx tsx scripts/sqlite-query.ts "<SQL query>"

Examples:
  npx tsx scripts/sqlite-query.ts "SELECT COUNT(*) FROM _KNS_Bill"
  npx tsx scripts/sqlite-query.ts "SELECT * FROM _KNS_Bill WHERE BillID = 1046149"
  npx tsx scripts/sqlite-query.ts "SELECT * FROM _KNS_DocumentBill WHERE BillID = 1046149"
`);
  process.exit(1);
}

if (!fs.existsSync(DB_PATH)) {
  console.error(`❌ Database not found: ${DB_PATH}`);
  process.exit(1);
}

const db = new Database(DB_PATH, { readonly: true });

try {
  const result = db.prepare(query).all();
  console.log(JSON.stringify(result, null, 2));
} catch (error: any) {
  console.error(`❌ Error: ${error.message}`);
  process.exit(1);
} finally {
  db.close();
}

