import express from 'express';
import * as nodeController from '../controllers/node.controller';
import { authenticate } from '../middleware/auth.middleware';

const router = express.Router();

// GET /nodes/:nodeId
router.get('/:nodeId', nodeController.getNode);

// POST /nodes - Create a new node (requires auth)
router.post('/', authenticate, nodeController.createNode);

// PATCH /nodes/:nodeId
router.patch('/:nodeId', nodeController.updateNode);

export default router;

