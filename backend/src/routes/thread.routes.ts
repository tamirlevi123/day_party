import express from 'express';
import * as threadController from '../controllers/thread.controller';

const router = express.Router();

// GET /threads/:threadId - Get thread with all nodes
router.get('/:threadId', threadController.getThread);

// GET /threads/:threadId/nodes - Get all nodes for a thread
router.get('/:threadId/nodes', threadController.getThreadNodes);

export default router;

