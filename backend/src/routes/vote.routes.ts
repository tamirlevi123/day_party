import express from 'express';
import * as voteController from '../controllers/vote.controller';

const router = express.Router({ mergeParams: true });

// POST /nodes/:nodeId/vote
router.post('/:nodeId/vote', voteController.createOrUpdateVote);

// PATCH /nodes/:nodeId/vote/visibility
router.patch('/:nodeId/vote/visibility', voteController.updateVoteVisibility);

// GET /nodes/:nodeId/voters
router.get('/:nodeId/voters', voteController.getVoters);

export default router;

