import express from 'express';
import { getDatabaseInfo, downloadDatabase, getBillDocuments } from '../controllers/knesset-database.controller';

const router = express.Router();

/**
 * GET /api/knesset-database/info
 * Get database file information (last modified, size)
 */
router.get('/info', getDatabaseInfo);

/**
 * GET /api/knesset-database/download
 * Download the Knesset SQLite database file
 */
router.get('/download', downloadDatabase);

/**
 * GET /api/knesset-database/bills/:billId/documents
 * Get all documents for a specific bill
 */
router.get('/bills/:billId/documents', getBillDocuments);

export default router;

