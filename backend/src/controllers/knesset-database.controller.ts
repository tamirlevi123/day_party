import { Request, Response } from 'express';
import * as fs from 'fs';
import * as path from 'path';
import Database from 'better-sqlite3';

/**
 * Controller for Knesset database download and info endpoints
 * Similar to DatabaseController.cs in the Knesset project
 */

// Path to Knesset database
// In compiled code (dist/), __dirname points to dist/controllers/
// In source code, we need to go up to backend root
// Use process.cwd() which points to backend/ when running from backend directory
const KNESSET_DB_PATH = path.resolve(process.cwd(), 'data', 'knesset_data.db');

/**
 * Get SQLite database connection (read-only)
 */
function getDatabase(): Database.Database | null {
  if (!fs.existsSync(KNESSET_DB_PATH)) {
    return null;
  }
  try {
    return new Database(KNESSET_DB_PATH, { readonly: true });
  } catch (error) {
    console.error('Error opening SQLite database:', error);
    return null;
  }
}

/**
 * GET /api/knesset-database/info
 * Returns database file info (last modified date)
 */
export const getDatabaseInfo = async (_req: Request, res: Response): Promise<void> => {
  try {
    if (!fs.existsSync(KNESSET_DB_PATH)) {
      res.status(404).json({
        message: `Database file not found at: ${KNESSET_DB_PATH}`,
      });
      return;
    }

    const stats = fs.statSync(KNESSET_DB_PATH);
    res.json({
      lastModifiedUtc: stats.mtime.toISOString(),
      size: stats.size,
      path: KNESSET_DB_PATH,
    });
  } catch (error: any) {
    console.error('Error accessing database file info:', error);
    res.status(500).json({
      message: 'Internal server error while retrieving database info',
      error: error.message,
    });
  }
};

/**
 * GET /api/knesset-database/download
 * Downloads the Knesset SQLite database file
 */
export const downloadDatabase = async (_req: Request, res: Response): Promise<void> => {
  try {
    console.log(`[KnessetDatabase] Download requested. Checking path: ${KNESSET_DB_PATH}`);
    
    if (!fs.existsSync(KNESSET_DB_PATH)) {
      console.error(`[KnessetDatabase] Database file not found at: ${KNESSET_DB_PATH}`);
      res.status(404).json({
        message: `Database file not found at: ${KNESSET_DB_PATH}`,
      });
      return;
    }

    const filename = path.basename(KNESSET_DB_PATH);
    const stats = fs.statSync(KNESSET_DB_PATH);
    console.log(`[KnessetDatabase] File found. Size: ${stats.size} bytes`);

    // Set headers for file download
    res.setHeader('Content-Type', 'application/octet-stream');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    res.setHeader('Content-Length', stats.size.toString());
    res.setHeader('Cache-Control', 'no-cache');
    console.log(`[KnessetDatabase] Headers set. Starting file stream...`);

    // Stream the file
    const fileStream = fs.createReadStream(KNESSET_DB_PATH);
    
    fileStream.on('open', () => {
      console.log(`[KnessetDatabase] File stream opened`);
    });
    
    fileStream.on('end', () => {
      console.log(`[KnessetDatabase] File stream ended successfully`);
    });
    
    fileStream.on('error', (error) => {
      console.error(`[KnessetDatabase] Error streaming database file:`, error);
      if (!res.headersSent) {
        res.status(500).json({
          message: 'Internal server error during database download',
          error: error.message,
        });
      }
    });
    
    res.on('finish', () => {
      console.log(`[KnessetDatabase] Response finished`);
    });
    
    res.on('close', () => {
      console.log(`[KnessetDatabase] Response closed`);
    });

    fileStream.pipe(res);
  } catch (error: any) {
    console.error(`[KnessetDatabase] Error downloading database file:`, error);
    if (!res.headersSent) {
      res.status(500).json({
        message: 'Internal server error during database download',
        error: error.message,
      });
    }
  }
};

/**
 * Map table names to their primary key column names
 */
const TABLE_PRIMARY_KEYS: Record<string, string> = {
  '_KNS_Bill': 'BillID',
  '_KNS_DocumentBill': 'DocumentBillID',
  '_KNS_Committee': 'CommitteeID',
  '_KNS_Person': 'PersonID',
  '_KNS_CommitteeSession': 'CommitteeSessionID',
  '_KNS_Faction': 'FactionID',
  '_KNS_Status': 'StatusID',
};

/**
 * GET /api/knesset-database/updates/:tableName
 * Returns records from a table where primary key > maxId
 * Query params: maxId (required)
 */
export const getTableUpdates = async (req: Request, res: Response): Promise<void> => {
  try {
    const tableName = req.params.tableName;
    const maxIdParam = req.query.maxId as string;

    if (!tableName) {
      res.status(400).json({
        message: 'Table name is required',
      });
      return;
    }

    if (!maxIdParam) {
      res.status(400).json({
        message: 'maxId query parameter is required',
      });
      return;
    }

    const primaryKey = TABLE_PRIMARY_KEYS[tableName];
    if (!primaryKey) {
      res.status(400).json({
        message: `Unknown table: ${tableName}. Supported tables: ${Object.keys(TABLE_PRIMARY_KEYS).join(', ')}`,
      });
      return;
    }

    // Parse maxId - handle both integer and string (for DocumentBillID which is TEXT)
    let maxId: number | string;
    if (primaryKey === 'DocumentBillID') {
      // DocumentBillID is stored as TEXT, so keep as string
      maxId = maxIdParam;
    } else {
      maxId = parseInt(maxIdParam, 10);
      if (isNaN(maxId)) {
        res.status(400).json({
          message: `Invalid maxId for table ${tableName}: must be a number`,
        });
        return;
      }
    }

    const db = getDatabase();
    if (!db) {
      res.status(404).json({
        message: 'Knesset database not available',
      });
      return;
    }

    try {
      // Build query: SELECT * FROM table WHERE primaryKey > maxId ORDER BY primaryKey ASC LIMIT 1000
      // Using LIMIT to prevent huge responses
      const query = `
        SELECT * 
        FROM ${tableName}
        WHERE ${primaryKey} > ?
        ORDER BY ${primaryKey} ASC
        LIMIT 1000
      `;

      console.log(`[KnessetDatabase] Querying ${tableName} for records where ${primaryKey} > ${maxId}`);
      
      const records = db.prepare(query).all(maxId) as Array<Record<string, any>>;

      console.log(`[KnessetDatabase] Found ${records.length} records in ${tableName} where ${primaryKey} > ${maxId}`);

      res.json({
        tableName: tableName,
        primaryKey: primaryKey,
        maxId: maxId,
        records: records,
        count: records.length,
        hasMore: records.length === 1000, // If we got exactly 1000, there might be more
      });
    } finally {
      db.close();
    }
  } catch (error: any) {
    console.error('Error querying table updates:', error);
    res.status(500).json({
      message: 'Internal server error while retrieving table updates',
      error: error.message,
    });
  }
};

/**
 * GET /api/knesset-database/bills/:billId/documents
 * Returns all documents for a specific bill
 */
export const getBillDocuments = async (req: Request, res: Response): Promise<void> => {
  try {
    const billId = parseInt(req.params.billId, 10);
    
    if (isNaN(billId)) {
      res.status(400).json({
        message: 'Invalid BillID parameter',
      });
      return;
    }

    const db = getDatabase();
    if (!db) {
      res.status(404).json({
        message: 'Knesset database not available',
      });
      return;
    }

    try {
      const documents = db.prepare(`
        SELECT 
          DocumentBillID,
          BillID,
          GroupTypeID,
          GroupTypeDesc,
          ApplicationID,
          ApplicationDesc,
          FilePath,
          LastUpdatedDate
        FROM _KNS_DocumentBill
        WHERE BillID = ?
        ORDER BY GroupTypeID, ApplicationID, DocumentBillID
      `).all(billId) as Array<{
        DocumentBillID: string;
        BillID: number;
        GroupTypeID: number | null;
        GroupTypeDesc: string | null;
        ApplicationID: number | null;
        ApplicationDesc: string | null;
        FilePath: string | null;
        LastUpdatedDate: string | null;
      }>;

      res.json({
        billId: billId,
        documents: documents,
        count: documents.length,
      });
    } finally {
      db.close();
    }
  } catch (error: any) {
    console.error('Error querying bill documents:', error);
    res.status(500).json({
      message: 'Internal server error while retrieving bill documents',
      error: error.message,
    });
  }
};

