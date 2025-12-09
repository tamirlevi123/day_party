import express from 'express';
import * as threadController from '../controllers/thread.controller';
import { authenticate } from '../middleware/auth.middleware';

const router = express.Router();

// POST /threads - Create a new thread (requires auth)
router.post('/', authenticate, threadController.createThread);

// GET /threads/:threadId - Get thread with all nodes
router.get('/:threadId', threadController.getThread);

// GET /threads/:threadId/nodes - Get all nodes for a thread
router.get('/:threadId/nodes', threadController.getThreadNodes);

export default router;

