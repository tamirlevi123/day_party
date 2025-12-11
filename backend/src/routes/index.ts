import express from 'express';
import nodeRoutes from './node.routes';
import voteRoutes from './vote.routes';
import threadRoutes from './thread.routes';
import topicRoutes from './topic.routes';
import authRoutes from './auth.routes';
import videoRoutes from './video.routes';
import adminRoutes from './admin.routes';
import knessetDatabaseRoutes from './knesset-database.routes';

const router = express.Router();

router.use('/auth', authRoutes);
router.use('/topics', topicRoutes);
router.use('/nodes', nodeRoutes);
router.use('/nodes', voteRoutes);
router.use('/threads', threadRoutes);
router.use('/videos', videoRoutes);
router.use('/admin', adminRoutes);
router.use('/knesset-database', knessetDatabaseRoutes);

export default router;

