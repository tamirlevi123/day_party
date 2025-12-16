import express from 'express';
import { getStatuses, getCommittees, getBills, getBillDocuments } from '../controllers/knesset.controller';

const router = express.Router();

/**
 * GET /api/knesset/statuses
 * Get all statuses
 */
router.get('/statuses', getStatuses);

/**
 * GET /api/knesset/committees
 * Get all committees as a map
 */
router.get('/committees', getCommittees);

/**
 * GET /api/knesset/bills
 * Get bills filtered by knessetNum and optionally statusID
 * Query params: knessetNum (required), statusID (optional)
 */
router.get('/bills', getBills);

/**
 * GET /api/knesset/bills/:billId/documents
 * Get all documents for a specific bill
 */
router.get('/bills/:billId/documents', getBillDocuments);

export default router;
