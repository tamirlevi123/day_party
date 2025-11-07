import { Request, Response } from 'express';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

export const getNode = async (req: Request, res: Response): Promise<Response | void> => {
  try {
    const { nodeId } = req.params;

    const node = await prisma.node.findUnique({
      where: { id: nodeId },
      include: {
        author: {
          select: {
            id: true,
            displayName: true,
          },
        },
      },
    });

    if (!node) {
      return res.status(404).json({ error: 'not_found', message: 'Node not found' });
    }

    // Return node with vote tallies
    return res.status(200).json({
      nodeId: node.id,
      threadId: node.threadId,
      parentNodeId: node.parentNodeId,
      parentRelation: node.parentRelation,
      title: node.title,
      textContent: node.textContent,
      videoUrl: node.videoUrl,
      author: node.author ? {
        id: node.author.id,
        displayName: node.author.displayName,
      } : null,
      voteTallies: {
        like: node.likeCount,
        dislike: node.dislikeCount,
        abstain: node.abstainCount,
      },
      createdAt: node.createdAt.toISOString(),
      editedAt: node.editedAt?.toISOString() || null,
    });
  } catch (error: any) {
    return res.status(500).json({ error: 'internal_server_error', message: error.message });
  }
};

export const createNode = async (req: Request, res: Response): Promise<Response | void> => {
  try {
    const { threadId, parentNodeId, parentRelation, title, textContent, videoUrl, isAnonymous } = req.body;

    // Validation: parentRelation required if parentNodeId provided
    if (parentNodeId && !parentRelation) {
      return res.status(422).json({
        error: 'unprocessable',
        message: 'parentRelation is required when parentNodeId is provided',
      });
    }

    // Validation: parentRelation must be NULL for root nodes
    if (!parentNodeId && parentRelation !== null && parentRelation !== undefined) {
      return res.status(422).json({
        error: 'unprocessable',
        message: 'parentRelation must be NULL for root nodes',
      });
    }

    // Validation: parentRelation must be valid enum value
    if (parentRelation && !['pro', 'against', 'neutral'].includes(parentRelation)) {
      return res.status(422).json({
        error: 'unprocessable',
        message: 'parentRelation must be one of: pro, against, neutral',
      });
    }

    // TODO: Get user ID from JWT token (for now, allow anonymous)
    const authorId = isAnonymous ? null : undefined; // Will need auth middleware later

    const node = await prisma.node.create({
      data: {
        threadId,
        parentNodeId: parentNodeId || null,
        parentRelation: parentRelation || null,
        title,
        textContent: textContent || null,
        videoUrl: videoUrl || null,
        authorId,
        isAnonymous: isAnonymous || false,
      },
      include: {
        author: {
          select: {
            id: true,
            displayName: true,
          },
        },
      },
    });

    return res.status(201).json({
      nodeId: node.id,
      threadId: node.threadId,
      parentNodeId: node.parentNodeId,
      parentRelation: node.parentRelation,
      title: node.title,
      author: node.author ? {
        id: node.author.id,
        displayName: node.author.displayName,
      } : null,
      createdAt: node.createdAt,
    });
  } catch (error: any) {
    if (error.code === 'P2003') {
      // Foreign key constraint failure
      return res.status(404).json({
        error: 'not_found',
        message: 'Thread or parent node not found',
      });
    }
    return res.status(500).json({ error: 'internal_server_error', message: error.message });
  }
};

export const updateNode = async (req: Request, res: Response): Promise<Response | void> => {
  try {
    const { nodeId } = req.params;
    const { title, textContent, videoUrl, parentRelation } = req.body;

    // Get existing node to check if it's a reply
    const existingNode = await prisma.node.findUnique({
      where: { id: nodeId },
    });

    if (!existingNode) {
      return res.status(404).json({ error: 'not_found', message: 'Node not found' });
    }

    // Validation: parentRelation can only be changed if node is a reply
    if (parentRelation !== undefined) {
      if (!existingNode.parentNodeId) {
        return res.status(422).json({
          error: 'unprocessable',
          message: 'Cannot add or change parentRelation on root nodes',
        });
      }

      if (!['pro', 'against', 'neutral'].includes(parentRelation)) {
        return res.status(422).json({
          error: 'unprocessable',
          message: 'parentRelation must be one of: pro, against, neutral',
        });
      }
    }

    const updatedNode = await prisma.node.update({
      where: { id: nodeId },
      data: {
        ...(title !== undefined && { title }),
        ...(textContent !== undefined && { textContent }),
        ...(videoUrl !== undefined && { videoUrl }),
        ...(parentRelation !== undefined && { parentRelation }),
        editedAt: new Date(),
      },
    });

    return res.status(200).json({
      nodeId: updatedNode.id,
      title: updatedNode.title,
      parentRelation: updatedNode.parentRelation,
      editedAt: updatedNode.editedAt,
    });
  } catch (error: any) {
    if (error.code === 'P2025') {
      return res.status(404).json({ error: 'not_found', message: 'Node not found' });
    }
    return res.status(500).json({ error: 'internal_server_error', message: error.message });
  }
};

