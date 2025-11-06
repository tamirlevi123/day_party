import express from 'express';
import * as nodeController from '../controllers/node.controller';

const router = express.Router();

// GET /nodes/:nodeId
router.get('/:nodeId', nodeController.getNode);

// POST /nodes
router.post('/', nodeController.createNode);

// PATCH /nodes/:nodeId
router.patch('/:nodeId', nodeController.updateNode);

export default router;

