/**
 * Check if a specific thread (by thread ID) has documents in SQLite
 * 
 * Usage:
 *   tsx scripts/check-thread-documents.ts <thread-id>
 * 
 * Example:
 *   tsx scripts/check-thread-documents.ts 44201c8f-d24e-422e-ae24-fbaa25e487c4
 */

import { PrismaClient } from '@prisma/client';
import Database from 'better-sqlite3';
import * as path from 'path';
import * as fs from 'fs';

const prisma = new PrismaClient();
const SQLITE_DB_PATH = path.join(__dirname, '..', 'data', 'knesset_data.db');

async function checkThreadDocuments(threadId: string) {
  try {
    console.log(`🔍 Checking thread: ${threadId}\n`);

    // Get thread and root node from MySQL
    const thread = await prisma.thread.findUnique({
      where: { id: threadId },
      include: {
        nodes: {
          where: { parentNodeId: null }, // Root node only
          take: 1,
        },
        topic: true,
      },
    });

    if (!thread) {
      console.log(`❌ Thread not found: ${threadId}`);
      return;
    }

    console.log(`✅ Thread found:`);
    console.log(`   Title: ${thread.title}`);
    console.log(`   Topic: ${thread.topic.name}`);
    console.log(`   Created: ${thread.createdAt.toISOString()}\n`);

    const rootNode = thread.nodes[0];
    if (!rootNode) {
      console.log(`❌ No root node found for this thread`);
      return;
    }

    console.log(`📋 Root node:`);
    console.log(`   Node ID: ${rootNode.id}`);
    console.log(`   Title: ${rootNode.title}`);

    // Extract billId from metadata
    if (!rootNode.metadataJson) {
      console.log(`\n❌ Root node has no metadata`);
      return;
    }

    const metadata = rootNode.metadataJson as any;
    const billId = metadata.billId;

    if (!billId) {
      console.log(`\n❌ No billId found in metadata`);
      console.log(`   Metadata: ${JSON.stringify(metadata, null, 2)}`);
      return;
    }

    console.log(`\n📊 Metadata:`);
    console.log(`   BillID: ${billId}`);
    console.log(`   BillNumber: ${metadata.billNumber || 'N/A'}`);
    console.log(`   KnessetNum: ${metadata.knessetNum || 'N/A'}`);

    // Check SQLite database
    if (!fs.existsSync(SQLITE_DB_PATH)) {
      console.log(`\n❌ SQLite database not found at: ${SQLITE_DB_PATH}`);
      return;
    }

    const sqliteDb = new Database(SQLITE_DB_PATH, { readonly: true });

    try {
      // Check if bill exists in SQLite
      const bill = sqliteDb.prepare(`
        SELECT BillID, Number, Name, KnessetNum
        FROM _KNS_Bill
        WHERE BillID = ?
      `).get(billId) as any;

      if (!bill) {
        console.log(`\n❌ BillID ${billId} not found in SQLite database`);
        sqliteDb.close();
        return;
      }

      console.log(`\n✅ Bill found in SQLite:`);
      console.log(`   BillID: ${bill.BillID}`);
      console.log(`   Number: ${bill.Number || 'N/A'}`);
      console.log(`   Name: ${bill.Name?.substring(0, 80)}...`);
      console.log(`   KnessetNum: ${bill.KnessetNum || 'N/A'}`);

      // Check documents
      const documents = sqliteDb.prepare(`
        SELECT 
          DocumentBillID,
          GroupTypeDesc,
          ApplicationDesc,
          FilePath,
          LastUpdatedDate
        FROM _KNS_DocumentBill
        WHERE BillID = ?
        ORDER BY GroupTypeID, ApplicationID, DocumentBillID
      `).all(billId) as Array<{
        DocumentBillID: number;
        GroupTypeDesc: string | null;
        ApplicationDesc: string | null;
        FilePath: string | null;
        LastUpdatedDate: string | null;
      }>;

      console.log(`\n📄 Documents for BillID ${billId}:`);
      console.log(`   Found ${documents.length} documents\n`);

      if (documents.length > 0) {
        documents.forEach((doc, index) => {
          console.log(`   ${index + 1}. ${doc.GroupTypeDesc || 'N/A'}`);
          if (doc.ApplicationDesc) {
            console.log(`      Application: ${doc.ApplicationDesc}`);
          }
          if (doc.FilePath) {
            console.log(`      FilePath: ${doc.FilePath.substring(0, 80)}...`);
          }
          if (doc.LastUpdatedDate) {
            console.log(`      Updated: ${doc.LastUpdatedDate}`);
          }
          console.log('');
        });
      } else {
        console.log('   ⚠️  No documents found for this bill\n');

        // Check if ANY bills have documents
        const sampleDocs = sqliteDb.prepare(`
          SELECT DISTINCT BillID, COUNT(*) as docCount
          FROM _KNS_DocumentBill
          GROUP BY BillID
          ORDER BY docCount DESC
          LIMIT 5
        `).all() as Array<{ BillID: number; docCount: number }>;

        if (sampleDocs.length > 0) {
          console.log(`📊 Sample bills WITH documents:`);
          sampleDocs.forEach((sample) => {
            console.log(`   BillID ${sample.BillID}: ${sample.docCount} documents`);
          });
        }
      }
    } finally {
      sqliteDb.close();
    }
  } catch (error: any) {
    console.error(`\n❌ Error:`, error.message);
    console.error(error.stack);
  } finally {
    await prisma.$disconnect();
  }
}

// Get thread ID from command line
const threadId = process.argv[2];

if (!threadId) {
  console.log(`
Usage:
  tsx scripts/check-thread-documents.ts <thread-id>

Example:
  tsx scripts/check-thread-documents.ts 44201c8f-d24e-422e-ae24-fbaa25e487c4
`);
  process.exit(1);
}

checkThreadDocuments(threadId);

