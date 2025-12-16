/**
 * Import Knesset SQLite database into MySQL
 * 
 * This script imports all Knesset tables from the SQLite database
 * into MySQL, preserving table structure and data.
 * 
 * Usage:
 *   tsx scripts/import-sqlite-to-mysql.ts
 *   tsx scripts/import-sqlite-to-mysql.ts --db-path ../data/knesset_data.db
 *   tsx scripts/import-sqlite-to-mysql.ts --dry-run
 */

import { PrismaClient } from '@prisma/client';
import dotenv from 'dotenv';
import * as path from 'path';
import * as fs from 'fs';
import Database from 'better-sqlite3';

dotenv.config();

const prisma = new PrismaClient();

// Parse command line arguments
function parseArgs() {
  const args: Record<string, string | boolean> = {};
  const argv = process.argv.slice(2);
  
  for (let i = 0; i < argv.length; i++) {
    if (argv[i].startsWith('--')) {
      const key = argv[i].substring(2);
      if (i + 1 < argv.length && !argv[i + 1].startsWith('--')) {
        args[key] = argv[i + 1];
        i++;
      } else {
        args[key] = true;
      }
    }
  }
  
  return args;
}

const args = parseArgs();
const DB_PATH = (args['db-path'] as string) || path.join(__dirname, '..', 'data', 'knesset_data.db');
const DRY_RUN = args['dry-run'] === true || process.env.DRY_RUN === 'true';

// Tables to import (in order - tables with foreign keys last)
const TABLES_TO_IMPORT = [
  '_KNS_Status',
  '_KNS_Faction',
  '_KNS_Person',
  '_KNS_Committee',
  '_KNS_Bill',
  '_KNS_DocumentBill',
  '_KNS_CommitteeSession',
];

/**
 * Get table schema from SQLite
 */
function getTableSchema(db: Database.Database, tableName: string): string {
  const schema = db.prepare(`SELECT sql FROM sqlite_master WHERE type='table' AND name=?`).get(tableName) as { sql: string } | undefined;
  return schema?.sql || '';
}

/**
 * Convert SQLite CREATE TABLE statement to MySQL compatible
 */
function convertToMySQLSchema(sqliteSchema: string, tableName: string): string {
  if (!sqliteSchema) {
    throw new Error(`No schema found for table ${tableName}`);
  }

  // Remove SQLite-specific syntax
  let mysqlSchema = sqliteSchema
    // Remove IF NOT EXISTS (we'll handle that separately)
    .replace(/CREATE TABLE\s+IF\s+NOT\s+EXISTS\s+/i, 'CREATE TABLE IF NOT EXISTS ')
    .replace(/CREATE TABLE\s+/i, 'CREATE TABLE IF NOT EXISTS ')
    // Convert INTEGER PRIMARY KEY AUTOINCREMENT to AUTO_INCREMENT
    .replace(/INTEGER\s+PRIMARY\s+KEY\s+AUTOINCREMENT/gi, 'INTEGER PRIMARY KEY AUTO_INCREMENT')
    // Convert INTEGER PRIMARY KEY to INT PRIMARY KEY
    .replace(/INTEGER\s+PRIMARY\s+KEY/gi, 'INT PRIMARY KEY')
    // Convert INTEGER to INT
    .replace(/\bINTEGER\b/gi, 'INT')
    // Convert TEXT to TEXT (keep as is, but ensure proper syntax)
    // Remove SQLite-specific constraints
    .replace(/\s+ON\s+CONFLICT\s+[^\s]+/gi, '')
    // Convert all double-quoted identifiers to backticks (for MySQL)
    .replace(/"([^"]+)"/g, '`$1`')
    // Convert square brackets to backticks (SQL Server style)
    .replace(/\[([^\]]+)\]/g, '`$1`')
    // Remove trailing semicolon if present
    .replace(/;\s*$/, '');

  // Add MySQL-specific settings
  mysqlSchema += ' ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci';

  return mysqlSchema;
}

/**
 * Get all rows from a SQLite table
 */
function getTableData(db: Database.Database, tableName: string): Array<Record<string, any>> {
  return db.prepare(`SELECT * FROM ${tableName}`).all() as Array<Record<string, any>>;
}

/**
 * Escape value for MySQL
 */
function escapeMySQLValue(value: any): string {
  if (value === null || value === undefined) {
    return 'NULL';
  }
  if (typeof value === 'number') {
    return String(value);
  }
  if (typeof value === 'boolean') {
    return value ? '1' : '0';
  }
  // String - escape quotes and backslashes
  const escaped = String(value)
    .replace(/\\/g, '\\\\')
    .replace(/'/g, "''")
    .replace(/\n/g, '\\n')
    .replace(/\r/g, '\\r')
    .replace(/\t/g, '\\t');
  return `'${escaped}'`;
}

/**
 * Create INSERT statement for a row
 */
function createInsertStatement(tableName: string, row: Record<string, any>): string {
  const columns = Object.keys(row).map(col => `\`${col}\``).join(', ');
  const values = Object.values(row).map(escapeMySQLValue).join(', ');
  return `INSERT INTO \`${tableName}\` (${columns}) VALUES (${values})`;
}

/**
 * Import a single table
 */
async function importTable(tableName: string, db: Database.Database): Promise<{ imported: number; errors: number }> {
  console.log(`\n📦 Importing table: ${tableName}`);

  try {
    // Check if table exists in SQLite
    const tableExists = db.prepare(`
      SELECT name FROM sqlite_master 
      WHERE type='table' AND name=?
    `).get(tableName);

    if (!tableExists) {
      console.log(`  ⚠️  Table ${tableName} does not exist in SQLite, skipping`);
      return { imported: 0, errors: 0 };
    }

    // Get schema and create table in MySQL
    const sqliteSchema = getTableSchema(db, tableName);
    if (!sqliteSchema) {
      console.log(`  ⚠️  Could not get schema for ${tableName}, skipping`);
      return { imported: 0, errors: 0 };
    }

    const mysqlSchema = convertToMySQLSchema(sqliteSchema, tableName);

    if (DRY_RUN) {
      console.log(`  🔍 Would create table:\n${mysqlSchema.substring(0, 200)}...`);
    } else {
      // Create table in MySQL
      await prisma.$executeRawUnsafe(`DROP TABLE IF EXISTS \`${tableName}\``);
      try {
        await prisma.$executeRawUnsafe(mysqlSchema);
        console.log(`  ✅ Created table ${tableName}`);
      } catch (createError: any) {
        console.error(`  ❌ Failed to create table ${tableName}`);
        console.error(`  📋 Original SQLite schema:\n${sqliteSchema}`);
        console.error(`  📋 Converted MySQL schema:\n${mysqlSchema}`);
        console.error(`  ❌ Error: ${createError.message}`);
        throw createError;
      }
    }

    // Get data from SQLite
    const rows = getTableData(db, tableName);
    console.log(`  📊 Found ${rows.length} rows in SQLite`);

    if (rows.length === 0) {
      return { imported: 0, errors: 0 };
    }

    if (DRY_RUN) {
      console.log(`  🔍 Would import ${rows.length} rows`);
      if (rows.length > 0) {
        console.log(`  📋 Sample row:`, JSON.stringify(rows[0], null, 2).substring(0, 200));
      }
      return { imported: 0, errors: 0 };
    }

    // Import data in batches
    const BATCH_SIZE = 1000;
    let imported = 0;
    let errors = 0;

    for (let i = 0; i < rows.length; i += BATCH_SIZE) {
      const batch = rows.slice(i, i + BATCH_SIZE);
      
      try {
        // Build batch INSERT statement
        const firstRow = batch[0];
        const columns = Object.keys(firstRow).map(col => `\`${col}\``).join(', ');
        
        const valuesList = batch.map(row => {
          const values = Object.values(row).map(escapeMySQLValue).join(', ');
          return `(${values})`;
        }).join(', ');

        const insertSql = `INSERT INTO \`${tableName}\` (${columns}) VALUES ${valuesList}`;
        
        await prisma.$executeRawUnsafe(insertSql);
        imported += batch.length;
        
        if ((i + BATCH_SIZE) % 5000 === 0 || i + BATCH_SIZE >= rows.length) {
          console.log(`  ✅ Imported ${imported}/${rows.length} rows...`);
        }
      } catch (error: any) {
        console.error(`  ❌ Error importing batch starting at row ${i}:`, error.message);
        errors += batch.length;
        
        // Try inserting one by one to find the problematic row
        if (batch.length > 1) {
          console.log(`  🔍 Attempting individual inserts for this batch...`);
          for (const row of batch) {
            try {
              const insertSql = createInsertStatement(tableName, row);
              await prisma.$executeRawUnsafe(insertSql);
              imported++;
              errors--;
            } catch (rowError: any) {
              console.error(`  ❌ Failed to import row:`, rowError.message);
            }
          }
        }
      }
    }

    console.log(`  ✅ Imported ${imported} rows, ${errors} errors`);
    return { imported, errors };
  } catch (error: any) {
    console.error(`  ❌ Error importing table ${tableName}:`, error.message);
    return { imported: 0, errors: 1 };
  }
}

/**
 * Main import function
 */
async function importSQLiteToMySQL() {
  try {
    console.log('🚀 Starting SQLite to MySQL import...\n');

    if (DRY_RUN) {
      console.log('🔍 DRY RUN MODE - No data will be imported\n');
    }

    // Check if SQLite database exists
    if (!fs.existsSync(DB_PATH)) {
      throw new Error(`SQLite database not found: ${DB_PATH}`);
    }

    console.log(`📁 SQLite database: ${DB_PATH}`);

    // Open SQLite database
    const db = new Database(DB_PATH, { readonly: true });

    try {
      // Get list of all tables
      const allTables = db.prepare(`
        SELECT name FROM sqlite_master 
        WHERE type='table' AND name LIKE '_KNS_%'
        ORDER BY name
      `).all() as Array<{ name: string }>;

      console.log(`\n📋 Found ${allTables.length} Knesset tables in SQLite:`);
      allTables.forEach(t => console.log(`  - ${t.name}`));

      // Import each table
      let totalImported = 0;
      let totalErrors = 0;

      for (const table of TABLES_TO_IMPORT) {
        const result = await importTable(table, db);
        totalImported += result.imported;
        totalErrors += result.errors;
      }

      console.log(`\n📊 Import Summary:`);
      console.log(`  Total rows imported: ${totalImported}`);
      console.log(`  Total errors: ${totalErrors}`);

      // Verify import
      if (!DRY_RUN && totalImported > 0) {
        console.log(`\n🔍 Verifying import...`);
        for (const table of TABLES_TO_IMPORT) {
          try {
            const count = await prisma.$queryRawUnsafe<Array<{ count: bigint }>>(
              `SELECT COUNT(*) as count FROM \`${table}\``
            );
            console.log(`  ✅ ${table}: ${count[0].count} rows`);
          } catch (error: any) {
            console.log(`  ⚠️  ${table}: Could not verify (${error.message})`);
          }
        }
      }

      console.log('\n✅ Import complete!\n');
    } finally {
      db.close();
    }
  } catch (error: any) {
    console.error('❌ Import failed:', error);
    throw error;
  } finally {
    await prisma.$disconnect();
  }
}

// Run import
importSQLiteToMySQL()
  .catch((e) => {
    console.error('❌ Fatal error:', e);
    process.exit(1);
  });
