import Database from 'better-sqlite3';
import * as path from 'path';

const DB_PATH = path.join(__dirname, '..', 'data', 'knesset_data.db');

const billId = 1046149; // From the Flutter logs

const db = new Database(DB_PATH, { readonly: true });

try {
  // First check if the bill exists
  const bill = db.prepare(`
    SELECT BillID, Number, Name, KnessetNum
    FROM _KNS_Bill
    WHERE BillID = ?
  `).get(billId) as any;

  if (bill) {
    console.log(`\n✅ Bill found:`);
    console.log(`  BillID: ${bill.BillID}`);
    console.log(`  Number: ${bill.Number}`);
    console.log(`  Name: ${bill.Name}`);
    console.log(`  KnessetNum: ${bill.KnessetNum}`);
  } else {
    console.log(`\n❌ BillID ${billId} not found in _KNS_Bill table`);
  }

  // Check documents (without FileName - it doesn't exist in the table)
  const documents = db.prepare(`
    SELECT DocumentBillID, BillID, GroupTypeDesc, ApplicationDesc, FilePath
    FROM _KNS_DocumentBill
    WHERE BillID = ?
    ORDER BY GroupTypeID, ApplicationID, DocumentBillID
  `).all(billId) as any[];

  console.log(`\n📄 Documents for BillID ${billId}:`);
  console.log(`  Found ${documents.length} documents\n`);
  
  if (documents.length > 0) {
    documents.forEach((doc: any, index: number) => {
      console.log(`  ${index + 1}. ${doc.GroupTypeDesc || 'N/A'}`);
      if (doc.ApplicationDesc) {
        console.log(`     Application: ${doc.ApplicationDesc}`);
      }
      console.log(`     FilePath: ${doc.FilePath || 'N/A'}`);
      console.log('');
    });
  } else {
    console.log('  ⚠️  No documents found for this bill');
    
    // Check if ANY bills have documents
    const sampleDocs = db.prepare(`
      SELECT DISTINCT BillID, COUNT(*) as docCount
      FROM _KNS_DocumentBill
      GROUP BY BillID
      ORDER BY docCount DESC
      LIMIT 5
    `).all() as any[];
    
    console.log(`\n📊 Sample bills with documents:`);
    sampleDocs.forEach((sample: any) => {
      console.log(`  BillID ${sample.BillID}: ${sample.docCount} documents`);
    });
  }
} finally {
  db.close();
}

