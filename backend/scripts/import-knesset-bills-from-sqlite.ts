/**
 * Import script for Knesset Bills from SQLite database
 * 
 * This script imports bills from the Knesset SQLite database
 * into Day Party as threads in the "חוקים מהמליאה" topic.
 * 
 * Usage:
 *   # Import all bills from Knesset 25 (current Knesset):
 *   tsx scripts/import-knesset-bills-from-sqlite.ts --knesset-num 25
 * 
 *   # Import latest 100 bills (any Knesset):
 *   tsx scripts/import-knesset-bills-from-sqlite.ts --limit 100 --dry-run
 * 
 * Arguments:
 *   --limit <number>        Number of latest bills to import (default: 100, ignored if --knesset-num is set)
 *   --knesset-num <number>   Import all bills for specific Knesset (e.g., 25 for current Knesset)
 *   --topic-name <name>     Topic name (default: "חוקים מהמליאה")
 *   --db-path <path>        Path to SQLite database (default: ../data/knesset_data.db)
 *   --dry-run              Test without importing
 */

import { PrismaClient } from '@prisma/client';
import { randomUUID } from 'crypto';
import dotenv from 'dotenv';
import * as path from 'path';
import * as fs from 'fs';
import Database from 'better-sqlite3';
import { htmlToDelta } from './html-to-delta';

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
const LIMIT = parseInt((args['limit'] as string) || '100', 10);
const KNESSET_NUM = args['knesset-num'] ? parseInt(args['knesset-num'] as string, 10) : undefined;
const TOPIC_NAME = (args['topic-name'] as string) || 'חוקים מהמליאה';
const DB_PATH = (args['db-path'] as string) || path.join(__dirname, '..', 'data', 'knesset_data.db');
const DRY_RUN = args['dry-run'] === true || process.env.DRY_RUN === 'true';

interface KnessetBill {
  BillID: number;
  KnessetNum: number | null;
  Name: string;
  SummaryLaw: string | null;
  PublicationDate: string | null;
  StatusID: number | null;
  CommitteeID: number | null;
  Number: number | null;
  PrivateNumber: number | null;
  SubTypeDesc: string | null;
  LastUpdatedDate: string | null;
}

/**
 * Get or create the import topic
 */
async function getOrCreateTopic(adminUserId: string) {
  const existingTopic = await prisma.topic.findFirst({
    where: {
      name: TOPIC_NAME,
      createdBy: adminUserId,
    },
  });

  if (existingTopic) {
    console.log(`✅ Using existing topic: ${TOPIC_NAME}`);
    return existingTopic;
  }

  const topic = await prisma.topic.create({
    data: {
      id: randomUUID(),
      name: TOPIC_NAME,
      description: 'חוקים והצעות חוק מהמליאה - הכנסת',
      visibility: 'public',
      createdBy: adminUserId,
    },
  });

  console.log(`✅ Created topic: ${TOPIC_NAME}`);
  return topic;
}

/**
 * Get or create admin user for topic creation
 */
async function getOrCreateAdminUser() {
  let adminUser = await prisma.user.findFirst({
    where: { role: 'admin' },
  });

  if (!adminUser) {
    // Create a default admin user if none exists
    adminUser = await prisma.user.create({
      data: {
        id: randomUUID(),
        email: 'admin@dayparty.com',
        displayName: 'System Admin',
        role: 'admin',
      },
    });
    console.log('✅ Created default admin user');
  }

  return adminUser;
}

/**
 * Load latest bills from SQLite database
 * If knessetNum is provided, filters by that Knesset number (e.g., 25 for current Knesset)
 */
function loadLatestBills(dbPath: string, limit: number, knessetNum?: number): KnessetBill[] {
  const knessetFilter = knessetNum ? `AND KnessetNum = ${knessetNum}` : '';
  const logMessage = knessetNum 
    ? `📁 Loading all Knesset ${knessetNum} bills from SQLite: ${dbPath}`
    : `📁 Loading latest ${limit} bills from SQLite: ${dbPath}`;
  
  console.log(logMessage);
  
  if (!fs.existsSync(dbPath)) {
    throw new Error(`SQLite database not found: ${dbPath}`);
  }

  const db = new Database(dbPath, { readonly: true });
  
  try {
    // Query bills - if knessetNum is provided, get all bills for that Knesset
    // Otherwise, limit to latest bills
    const query = knessetNum
      ? `
        SELECT 
          BillID,
          KnessetNum,
          Name,
          SummaryLaw,
          PublicationDate,
          StatusID,
          CommitteeID,
          Number,
          PrivateNumber,
          SubTypeDesc,
          LastUpdatedDate
        FROM _KNS_Bill
        WHERE Name IS NOT NULL AND Name != ''
          ${knessetFilter}
        ORDER BY 
          CASE WHEN PublicationDate IS NOT NULL AND PublicationDate != '' THEN 0 ELSE 1 END,
          PublicationDate DESC,
          BillID DESC
      `
      : `
        SELECT 
          BillID,
          KnessetNum,
          Name,
          SummaryLaw,
          PublicationDate,
          StatusID,
          CommitteeID,
          Number,
          PrivateNumber,
          SubTypeDesc,
          LastUpdatedDate
        FROM _KNS_Bill
        WHERE Name IS NOT NULL AND Name != ''
        ORDER BY 
          CASE WHEN PublicationDate IS NOT NULL AND PublicationDate != '' THEN 0 ELSE 1 END,
          PublicationDate DESC,
          BillID DESC
        LIMIT ?
      `;
    
    const bills = knessetNum 
      ? db.prepare(query).all() as KnessetBill[]
      : db.prepare(query).all(limit) as KnessetBill[];
    
    console.log(`✅ Loaded ${bills.length} bills from SQLite`);
    return bills;
  } finally {
    db.close();
  }
}

/**
 * Check if bill already imported (by checking thread title)
 */
async function isBillAlreadyImported(bill: KnessetBill, topicId: string): Promise<boolean> {
  const title = bill.Name || `חוק ${bill.BillID}`;
  const existing = await prisma.thread.findFirst({
    where: {
      topicId: topicId,
      title: title.substring(0, 500),
    },
  });
  return existing !== null;
}

/**
 * Import a single bill as a thread with root node
 */
async function importBill(
  bill: KnessetBill,
  topicId: string,
  defaultUserId: string
): Promise<string | null> {
  try {
    const title = bill.Name || `חוק ${bill.BillID}`;
    const summary = bill.SummaryLaw || '';
    
    // Convert summary to Delta format
    let deltaContent = null;
    if (summary.trim().length > 0) {
      try {
        deltaContent = htmlToDelta(summary);
      } catch (error) {
        console.warn(`  ⚠️  Could not convert summary to Delta for bill ${bill.BillID}, using plain text`);
        // Fallback to plain text Delta
        deltaContent = {
          ops: [{ insert: summary + '\n' }]
        };
      }
    } else {
      // Create a simple Delta with just the title if no summary
      deltaContent = {
        ops: [{ insert: title + '\n' }]
      };
    }

    // Parse publication date
    let createdAt = new Date();
    if (bill.PublicationDate) {
      const parsedDate = new Date(bill.PublicationDate);
      if (!isNaN(parsedDate.getTime())) {
        createdAt = parsedDate;
      }
    }

    // Create thread
    const thread = await prisma.thread.create({
      data: {
        id: randomUUID(),
        topicId: topicId,
        title: title.substring(0, 500),
        description: null,
        createdBy: defaultUserId,
        status: 'open',
        createdAt: createdAt,
      },
    });

    // Create root node with the bill summary as content
    await prisma.node.create({
      data: {
        id: randomUUID(),
        threadId: thread.id,
        parentNodeId: null,
        parentRelation: null,
        title: title.substring(0, 500),
        textContent: JSON.stringify(deltaContent),
        textFormat: 'delta',
        authorId: defaultUserId,
        isAnonymous: false,
        moderationState: 'visible',
        textStatus: 'provided',
        videoStatus: 'missing',
        votingEnabled: true,
        createdAt: createdAt,
        // Store BillID and StatusID in metadata for easy lookup and filtering
        metadataJson: {
          billId: bill.BillID,
          knessetNum: bill.KnessetNum,
          billNumber: bill.Number,
          statusID: bill.StatusID,
        },
      },
    });

    const knessetInfo = bill.KnessetNum ? ` (כנסת ${bill.KnessetNum})` : '';
    const billNum = bill.Number ? ` מס' ${bill.Number}` : '';
    console.log(`  ✅ Created thread: ${title.substring(0, 50)}...${knessetInfo}${billNum}`);
    return thread.id;
  } catch (error: any) {
    console.error(`  ❌ Error importing bill ${bill.BillID}:`, error.message);
    return null;
  }
}

/**
 * Main import function
 */
async function importKnessetBills() {
  try {
    console.log('🚀 Starting Knesset bills import from SQLite...\n');

    if (DRY_RUN) {
      console.log('🔍 DRY RUN MODE - No data will be imported\n');
    }

    // Load bills from SQLite
    // If knesset-num is provided (e.g., 25), load all bills for that Knesset
    // Otherwise, use limit to get latest bills
    const bills = loadLatestBills(DB_PATH, LIMIT, KNESSET_NUM);
    
    if (bills.length === 0) {
      console.log('⚠️  No bills found in database');
      return;
    }

    if (DRY_RUN) {
      console.log('\n📋 Sample Bills (first 5):');
      console.log('='.repeat(80));
      bills.slice(0, 5).forEach((bill, idx) => {
        console.log(`\nBill ${idx + 1}:`);
        console.log(`  ID: ${bill.BillID}`);
        console.log(`  Name: ${bill.Name}`);
        console.log(`  Knesset: ${bill.KnessetNum || 'N/A'}`);
        console.log(`  Summary length: ${bill.SummaryLaw?.length || 0} chars`);
        console.log(`  Publication Date: ${bill.PublicationDate || 'N/A'}`);
        console.log(`  Status ID: ${bill.StatusID || 'N/A'}`);
      });

      console.log(`\n📊 Would import ${bills.length} bills`);
      console.log('✅ Dry run complete - no data imported\n');
      return;
    }

    // Get or create admin user
    const adminUser = await getOrCreateAdminUser();
    console.log(`👤 Admin user ID: ${adminUser.id}\n`);

    // Get or create topic
    const topic = await getOrCreateTopic(adminUser.id);
    console.log(`📁 Topic ID: ${topic.id}\n`);

    // Use admin user as default author for bills
    const defaultUserId = adminUser.id;

    // Import bills
    console.log(`📥 Importing ${bills.length} bills...\n`);
    let importedThreads = 0;
    let skippedThreads = 0;
    let failedThreads = 0;

    for (const bill of bills) {
      // Check if already imported
      const alreadyImported = await isBillAlreadyImported(bill, topic.id);
      if (alreadyImported) {
        console.log(`  ⏭️  Skipping bill ${bill.BillID} (already imported)`);
        skippedThreads++;
        continue;
      }

      const threadId = await importBill(bill, topic.id, defaultUserId);
      if (threadId) {
        importedThreads++;
      } else {
        failedThreads++;
      }
    }

    console.log(`\n📊 Import Summary:`);
    console.log(`  Imported: ${importedThreads}`);
    console.log(`  Skipped (already exists): ${skippedThreads}`);
    console.log(`  Failed: ${failedThreads}`);
    console.log(`  Total processed: ${bills.length}\n`);

    console.log('✅ Import complete!\n');
  } catch (error: any) {
    console.error('❌ Import failed:', error);
    throw error;
  } finally {
    await prisma.$disconnect();
  }
}

// Show usage if no arguments provided
if (process.argv.length === 2) {
  console.log(`
Usage:
  tsx scripts/import-knesset-bills-from-sqlite.ts [options]

Options:
  --limit <number>        Number of latest bills to import (default: 100, ignored if --knesset-num is set)
  --knesset-num <number> Import all bills for specific Knesset (e.g., 25 for current Knesset)
  --topic-name <name>     Topic name (default: "חוקים מהמליאה")
  --db-path <path>        Path to SQLite database (default: ../data/knesset_data.db)
  --dry-run              Test parsing without importing

Examples:
  # Dry run to test:
  tsx scripts/import-knesset-bills-from-sqlite.ts --limit 100 --dry-run
  
  # Import all bills from Knesset 25:
  tsx scripts/import-knesset-bills-from-sqlite.ts --knesset-num 25
  
  # Import 100 latest bills:
  tsx scripts/import-knesset-bills-from-sqlite.ts --limit 100
  
  # Import 50 latest bills:
  tsx scripts/import-knesset-bills-from-sqlite.ts --limit 50
`);
  process.exit(0);
}

// Run import
importKnessetBills()
  .catch((e) => {
    console.error('❌ Fatal error:', e);
    process.exit(1);
  });

