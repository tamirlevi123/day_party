import express from 'express';
import { getDatabaseInfo, downloadDatabase, getBillDocuments, getTableUpdates } from '../controllers/knesset-database.controller';

const router = express.Router();

// Log all requests to knesset-database routes
router.use((req, res, next) => {
  console.log(`[KnessetDatabase Routes] ${req.method} ${req.path}`);
  next();
});

/**
 * GET /api/knesset-database/info
 * Get database file information (last modified, size)
 */
router.get('/info', (req, res, next) => {
  console.log('[KnessetDatabase Routes] /info route hit');
  getDatabaseInfo(req, res).catch(next);
});

/**
 * GET /api/knesset-database/download
 * Download the Knesset SQLite database file
 */
router.get('/download', (req, res, next) => {
  console.log('[KnessetDatabase Routes] /download route hit');
  downloadDatabase(req, res).catch(next);
});

/**
 * GET /api/knesset-database/updates/:tableName?maxId=X
 * Get incremental updates for a table (records where primary key > maxId)
 */
router.get('/updates/:tableName', (req, res, next) => {
  console.log('[KnessetDatabase Routes] /updates route hit');
  getTableUpdates(req, res).catch(next);
});

/**
 * GET /api/knesset-database/bills/:billId/documents
 * Get all documents for a specific bill
 */
router.get('/bills/:billId/documents', getBillDocuments);

export default router;

