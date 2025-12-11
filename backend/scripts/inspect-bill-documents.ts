/**
 * Inspect bill documents from SQLite database
 */

import * as path from 'path';
import * as fs from 'fs';
import Database from 'better-sqlite3';

const DB_PATH = path.join(__dirname, '..', 'data', 'knesset_data.db');

const db = new Database(DB_PATH, { readonly: true });

try {
  // Get document types
  const docTypes = db.prepare('SELECT DISTINCT GroupTypeDesc FROM _KNS_DocumentBill WHERE GroupTypeDesc IS NOT NULL ORDER BY GroupTypeDesc').all() as Array<{ GroupTypeDesc: string }>;
  console.log('Document Types:');
  docTypes.forEach(t => console.log(`  - ${t.GroupTypeDesc}`));

  // Get application types
  const appTypes = db.prepare('SELECT DISTINCT ApplicationDesc FROM _KNS_DocumentBill WHERE ApplicationDesc IS NOT NULL ORDER BY ApplicationDesc').all() as Array<{ ApplicationDesc: string }>;
  console.log('\nApplication Types:');
  appTypes.forEach(t => console.log(`  - ${t.ApplicationDesc}`));

  // Get sample documents for a bill with documents
  const billWithDocs = db.prepare(`
    SELECT b.BillID, b.Name, COUNT(d.DocumentBillID) as doc_count
    FROM _KNS_Bill b
    INNER JOIN _KNS_DocumentBill d ON b.BillID = d.BillID
    GROUP BY b.BillID, b.Name
    ORDER BY b.PublicationDate DESC
    LIMIT 1
  `).get() as { BillID: number; Name: string; doc_count: number };

  if (billWithDocs) {
    console.log(`\n\nSample bill with documents:`);
    console.log(`  BillID: ${billWithDocs.BillID}`);
    console.log(`  Name: ${billWithDocs.Name}`);
    console.log(`  Document count: ${billWithDocs.doc_count}`);

    const docs = db.prepare(`
      SELECT DocumentBillID, GroupTypeDesc, ApplicationDesc, FilePath
      FROM _KNS_DocumentBill
      WHERE BillID = ?
      LIMIT 10
    `).all(billWithDocs.BillID) as Array<{
      DocumentBillID: string;
      GroupTypeDesc: string | null;
      ApplicationDesc: string | null;
      FilePath: string | null;
    }>;

    console.log(`\n  Sample documents:`);
    docs.forEach((doc, idx) => {
      console.log(`\n  ${idx + 1}. Document ID: ${doc.DocumentBillID}`);
      console.log(`     Type: ${doc.GroupTypeDesc || 'N/A'}`);
      console.log(`     Format: ${doc.ApplicationDesc || 'N/A'}`);
      console.log(`     Path: ${doc.FilePath || 'N/A'}`);
    });
  }

  // Statistics
  const stats = db.prepare(`
    SELECT 
      COUNT(*) as total_docs,
      COUNT(DISTINCT BillID) as bills_with_docs,
      AVG(doc_count) as avg_docs_per_bill
    FROM (
      SELECT BillID, COUNT(*) as doc_count
      FROM _KNS_DocumentBill
      GROUP BY BillID
    )
  `).get() as { total_docs: number; bills_with_docs: number; avg_docs_per_bill: number };

  console.log(`\n\nStatistics:`);
  console.log(`  Total documents: ${stats.total_docs}`);
  console.log(`  Bills with documents: ${stats.bills_with_docs}`);
  console.log(`  Average documents per bill: ${stats.avg_docs_per_bill?.toFixed(2) || 'N/A'}`);

} finally {
  db.close();
}

