/**
 * Verify Knesset SQLite database contents
 * Checks bills and documents to ensure data integrity
 */

import * as path from 'path';
import * as fs from 'fs';
import Database from 'better-sqlite3';

const DB_PATH = path.join(__dirname, '..', 'data', 'knesset_data.db');

if (!fs.existsSync(DB_PATH)) {
  console.error(`❌ Database not found at: ${DB_PATH}`);
  process.exit(1);
}

const db = new Database(DB_PATH, { readonly: true });

try {
  console.log('🔍 Verifying Knesset SQLite database...\n');

  // Check total bills
  const totalBills = db.prepare('SELECT COUNT(*) as count FROM _KNS_Bill').get() as { count: number };
  console.log(`📊 Total bills in database: ${totalBills.count}`);

  // Check total documents
  const totalDocs = db.prepare('SELECT COUNT(*) as count FROM _KNS_DocumentBill').get() as { count: number };
  console.log(`📄 Total documents in database: ${totalDocs.count}`);

  // Check bills with documents
  const billsWithDocs = db.prepare(`
    SELECT COUNT(DISTINCT BillID) as count
    FROM _KNS_DocumentBill
  `).get() as { count: number };
  console.log(`📋 Bills with documents: ${billsWithDocs.count}`);

  // Check the specific bill from the logs
  const testBillId = 1046149;
  console.log(`\n🔍 Checking BillID ${testBillId}...`);
  
  const bill = db.prepare(`
    SELECT BillID, Number, Name, KnessetNum
    FROM _KNS_Bill
    WHERE BillID = ?
  `).get(testBillId) as any;

  if (bill) {
    console.log(`  ✅ Bill found:`);
    console.log(`     BillID: ${bill.BillID}`);
    console.log(`     Number: ${bill.Number}`);
    console.log(`     Name: ${bill.Name?.substring(0, 60)}...`);
    console.log(`     KnessetNum: ${bill.KnessetNum}`);
  } else {
    console.log(`  ❌ BillID ${testBillId} not found`);
  }

  // Check documents for this bill
  const docs = db.prepare(`
    SELECT DocumentBillID, GroupTypeDesc, ApplicationDesc, FilePath
    FROM _KNS_DocumentBill
    WHERE BillID = ?
  `).all(testBillId) as Array<{
    DocumentBillID: number;
    GroupTypeDesc: string | null;
    ApplicationDesc: string | null;
    FilePath: string | null;
  }>;

  console.log(`  📄 Documents for BillID ${testBillId}: ${docs.length}`);
  if (docs.length > 0) {
    docs.slice(0, 5).forEach((doc, idx) => {
      console.log(`     ${idx + 1}. ${doc.GroupTypeDesc || 'N/A'} - ${doc.ApplicationDesc || 'N/A'}`);
      if (doc.FilePath) {
        console.log(`        Path: ${doc.FilePath.substring(0, 60)}...`);
      }
    });
    if (docs.length > 5) {
      console.log(`     ... and ${docs.length - 5} more`);
    }
  }

  // Check sample bills that DO have documents
  console.log(`\n📋 Sample bills WITH documents:`);
  const billsWithDocuments = db.prepare(`
    SELECT b.BillID, b.Number, b.Name, COUNT(d.DocumentBillID) as doc_count
    FROM _KNS_Bill b
    INNER JOIN _KNS_DocumentBill d ON b.BillID = d.BillID
    GROUP BY b.BillID, b.Number, b.Name
    ORDER BY b.BillID DESC
    LIMIT 5
  `).all() as Array<{
    BillID: number;
    Number: number | null;
    Name: string;
    doc_count: number;
  }>;

  billsWithDocuments.forEach((b, idx) => {
    console.log(`  ${idx + 1}. BillID ${b.BillID} (Number: ${b.Number || 'N/A'}) - ${b.doc_count} documents`);
    console.log(`     Name: ${b.Name.substring(0, 60)}...`);
  });

  // Check the latest 10 imported bills (from metadata we know)
  console.log(`\n🔍 Checking latest imported bills (from import script logic)...`);
  const latestBills = db.prepare(`
    SELECT 
      BillID,
      KnessetNum,
      Number,
      Name,
      PublicationDate
    FROM _KNS_Bill
    WHERE Name IS NOT NULL AND Name != ''
    ORDER BY 
      CASE WHEN PublicationDate IS NOT NULL AND PublicationDate != '' THEN 0 ELSE 1 END,
      PublicationDate DESC,
      BillID DESC
    LIMIT 10
  `).all() as Array<{
    BillID: number;
    KnessetNum: number | null;
    Number: number | null;
    Name: string;
    PublicationDate: string | null;
  }>;

  console.log(`\n📊 Latest 10 bills (as imported):`);
  latestBills.forEach((b, idx) => {
    const docCount = db.prepare(`
      SELECT COUNT(*) as count
      FROM _KNS_DocumentBill
      WHERE BillID = ?
    `).get(b.BillID) as { count: number };
    
    console.log(`  ${idx + 1}. BillID ${b.BillID} - ${docCount.count} documents`);
    console.log(`     Name: ${b.Name.substring(0, 50)}...`);
  });

} catch (error: any) {
  console.error('❌ Error:', error.message);
  process.exit(1);
} finally {
  db.close();
}

