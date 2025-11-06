import express from 'express';
import * as topicController from '../controllers/topic.controller';

const router = express.Router();

// GET /topics - Get all topics
router.get('/', topicController.getTopics);

// GET /topics/:topicId/threads - Get threads for a topic
router.get('/:topicId/threads', topicController.getTopicThreads);

// GET /topics/:topicId - Get a specific topic
router.get('/:topicId', topicController.getTopic);

export default router;

