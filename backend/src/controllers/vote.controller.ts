import { Request, Response } from 'express';
import { PrismaClient, VoteType } from '@prisma/client';

const prisma = new PrismaClient();

// POST /nodes/:nodeId/vote
export const createOrUpdateVote = async (req: Request, res: Response): Promise<Response | void> => {
  try {
    const { nodeId } = req.params;
    const { type, isPublic = false } = req.body;

    // Validation
    if (!['like', 'dislike', 'abstain'].includes(type)) {
      return res.status(400).json({
        error: 'validation_error',
        message: 'type must be one of: like, dislike, abstain',
      });
    }

    // TODO: Get user ID from JWT token (for now, use a test user)
    const userId = '2f44cff6-302d-4fed-bd17-d03b873d0759'; // Test User from seed

    // Check if node exists
    const node = await prisma.node.findUnique({ where: { id: nodeId } });
    if (!node) {
      return res.status(404).json({ error: 'not_found', message: 'Node not found' });
    }

    // TODO: Validate voting deadline if set

    // Use upsert to create or update vote
    const vote = await prisma.nodeVote.upsert({
      where: {
        nodeId_userId: {
          nodeId,
          userId,
        },
      },
      create: {
        nodeId,
        userId,
        type: type as VoteType,
        isPublic,
      },
      update: {
        type: type as VoteType,
        isPublic,
        updatedAt: new Date(),
      },
    });

    // Update vote counts on the node
    const counts = await prisma.nodeVote.groupBy({
      by: ['type'],
      where: { nodeId },
      _count: { type: true },
    });

    // Recalculate counts
    const likeCount = counts.find(c => c.type === 'like')?._count.type || 0;
    const dislikeCount = counts.find(c => c.type === 'dislike')?._count.type || 0;
    const abstainCount = counts.find(c => c.type === 'abstain')?._count.type || 0;

    await prisma.node.update({
      where: { id: nodeId },
      data: {
        likeCount,
        dislikeCount,
        abstainCount,
      },
    });

    return res.status(200).json({
      nodeId,
      tallies: {
        like: likeCount,
        dislike: dislikeCount,
        abstain: abstainCount,
      },
      myVote: {
        type: vote.type,
        isPublic: vote.isPublic,
      },
    });
  } catch (error: any) {
    return res.status(500).json({ error: 'internal_server_error', message: error.message });
  }
};

// PATCH /nodes/:nodeId/vote/visibility
export const updateVoteVisibility = async (req: Request, res: Response): Promise<Response | void> => {
  try {
    const { nodeId } = req.params;
    const { isPublic } = req.body;

    const userId = '2f44cff6-302d-4fed-bd17-d03b873d0759'; // Test User

    const vote = await prisma.nodeVote.findUnique({
      where: {
        nodeId_userId: {
          nodeId,
          userId,
        },
      },
    });

    if (!vote) {
      return res.status(404).json({
        error: 'not_found',
        message: 'You have not voted on this node yet',
      });
    }

    const updatedVote = await prisma.nodeVote.update({
      where: {
        nodeId_userId: {
          nodeId,
          userId,
        },
      },
      data: { isPublic },
    });

    return res.status(200).json({
      nodeId,
      myVote: {
        type: updatedVote.type,
        isPublic: updatedVote.isPublic,
      },
    });
  } catch (error: any) {
    return res.status(500).json({ error: 'internal_server_error', message: error.message });
  }
};

// GET /nodes/:nodeId/voters
export const getVoters = async (req: Request, res: Response) => {
  try {
    const { nodeId } = req.params;
    const { type, limit = 20, cursor } = req.query;

    // Only return public votes
    const votes = await prisma.nodeVote.findMany({
      where: {
        nodeId,
        isPublic: true,
        ...(type && ['like', 'dislike', 'abstain'].includes(type as string) && { type: type as VoteType }),
      },
      take: parseInt(limit as string) + 1, // Take one extra to check if there's a next page
      ...(cursor && { skip: 1, cursor: { id: cursor as string } }),
      include: {
        user: {
          select: {
            id: true,
            displayName: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    const hasNextPage = votes.length > parseInt(limit as string);
    const voters = votes.slice(0, parseInt(limit as string));

    res.status(200).json({
      voters: voters.map(v => ({
        userId: v.user.id,
        displayName: v.user.displayName,
      })),
      nextCursor: hasNextPage ? voters[voters.length - 1].id : null,
    });
  } catch (error: any) {
    res.status(500).json({ error: 'internal_server_error', message: error.message });
  }
};

