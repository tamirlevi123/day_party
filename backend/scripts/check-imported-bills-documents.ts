/**
 * Check which imported bills have documents
 */

import Database from 'better-sqlite3';
import * as path from 'path';
import { PrismaClient } from '@prisma/client';

const SQLITE_DB_PATH = path.join(__dirname, '..', 'data', 'knesset_data.db');
const prisma = new PrismaClient();

async function checkImportedBills() {
  try {
    // Get all imported bills from MySQL
    const topic = await prisma.topic.findFirst({
      where: { name: 'חוקים מהמליאה' },
      include: {
        threads: {
          include: {
            nodes: {
              where: { parentNodeId: null }, // Root nodes only
            },
          },
        },
      },
    });

    if (!topic) {
      console.log('❌ Topic "חוקים מהמליאה" not found');
      return;
    }

    console.log(`\n📋 Found ${topic.threads.length} imported bills\n`);

    // Open SQLite database
    const sqliteDb = new Database(SQLITE_DB_PATH, { readonly: true });

    let billsWithDocs = 0;
    let billsWithoutDocs = 0;

    for (const thread of topic.threads.slice(0, 10)) {
      const rootNode = thread.nodes[0];
      if (!rootNode || !rootNode.metadataJson) {
        continue;
      }

      const metadata = rootNode.metadataJson as any;
      const billId = metadata.billId;

      if (!billId) {
        continue;
      }

      // Check documents in SQLite
      const documents = sqliteDb.prepare(`
        SELECT COUNT(*) as count
        FROM _KNS_DocumentBill
        WHERE BillID = ?
      `).get(billId) as { count: number };

      const docCount = documents.count;

      if (docCount > 0) {
        billsWithDocs++;
        console.log(`✅ ${thread.title.substring(0, 50)}...`);
        console.log(`   BillID: ${billId}, Documents: ${docCount}`);
      } else {
        billsWithoutDocs++;
        console.log(`❌ ${thread.title.substring(0, 50)}...`);
        console.log(`   BillID: ${billId}, Documents: 0`);
      }
    }

    sqliteDb.close();

    console.log(`\n📊 Summary:`);
    console.log(`   Bills with documents: ${billsWithDocs}`);
    console.log(`   Bills without documents: ${billsWithoutDocs}`);
  } catch (error) {
    console.error('Error:', error);
  } finally {
    await prisma.$disconnect();
  }
}

checkImportedBills();

