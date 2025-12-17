import express from 'express';
import { getStatuses, getCommittees, getBills, getBillDocuments, getKnessetDiagnostics } from '../controllers/knesset.controller';
import { authenticate, requireAdmin } from '../middleware/auth.middleware';

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

/**
 * GET /api/knesset/diagnostics
 * Admin-only diagnostics (helps debug VM DB mismatches).
 */
router.get('/diagnostics', authenticate, requireAdmin, getKnessetDiagnostics);

export default router;
