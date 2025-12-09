import express from 'express';
import { authenticate, requireAdmin } from '../middleware/auth.middleware';
import * as adminController from '../controllers/admin.controller';

const router = express.Router();

// All admin routes require authentication and admin role
router.use(authenticate);
router.use(requireAdmin);

// Node management endpoints
router.get('/nodes', adminController.listNodes);
router.get('/nodes/:nodeId', adminController.getNode);
router.patch('/nodes/:nodeId', adminController.updateNode);
router.delete('/nodes/:nodeId', adminController.deleteNode);
router.post('/nodes/:nodeId/restore', adminController.restoreNode);

export default router;

