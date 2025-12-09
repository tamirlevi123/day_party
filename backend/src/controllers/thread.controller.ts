import { Request, Response } from 'express';
import { PrismaClient } from '@prisma/client';
import { transformNodeToResponse } from '../utils/node-response.util';
import { AuthRequest } from '../middleware/auth.middleware';

const prisma = new PrismaClient();

export const getThread = async (req: Request, res: Response): Promise<Response | void> => {
  try {
    const { threadId } = req.params;

    const thread = await prisma.thread.findUnique({
      where: { id: threadId },
      include: {
        topic: {
          select: {
            id: true,
            name: true,
          },
        },
      },
    });

    if (!thread) {
      return res.status(404).json({ error: 'not_found', message: 'Thread not found' });
    }

    // Get all nodes for this thread (excluding deleted nodes)
    const nodes = await prisma.node.findMany({
      where: { 
        threadId,
        isDeleted: false,
      },
      include: {
        author: {
          select: {
            id: true,
            displayName: true,
          },
        },
      },
      orderBy: {
        createdAt: 'asc',
      },
    });

    const formattedNodes = nodes.map(transformNodeToResponse);

    // Return thread with nodes
    return res.status(200).json({
      thread: {
        threadId: thread.id,
        topicId: thread.topicId,
        title: thread.title,
        description: thread.description,
        status: thread.status,
        createdAt: thread.createdAt.toISOString(),
      },
      nodes: formattedNodes,
    });
  } catch (error: any) {
    return res.status(500).json({ error: 'internal_server_error', message: error.message });
  }
};

export const getThreadNodes = async (req: Request, res: Response): Promise<Response | void> => {
  try {
    const { threadId } = req.params;

    // Verify thread exists
    const thread = await prisma.thread.findUnique({
      where: { id: threadId },
    });

    if (!thread) {
      return res.status(404).json({ error: 'not_found', message: 'Thread not found' });
    }

    // Get all nodes for this thread (excluding deleted nodes)
    const nodes = await prisma.node.findMany({
      where: { 
        threadId,
        isDeleted: false,
      },
      include: {
        author: {
          select: {
            id: true,
            displayName: true,
          },
        },
      },
      orderBy: {
        createdAt: 'asc',
      },
    });

    const formattedNodes = nodes.map(transformNodeToResponse);

    return res.status(200).json(formattedNodes);
  } catch (error: any) {
    return res.status(500).json({ error: 'internal_server_error', message: error.message });
  }
};

export const createThread = async (req: Request, res: Response): Promise<Response | void> => {
  try {
    const authReq = req as AuthRequest;
    if (!authReq.user) {
      return res.status(401).json({
        error: 'unauthorized',
        message: 'Authentication required',
      });
    }

    const { topicId, title, description } = req.body;

    // Validation
    if (!topicId || typeof topicId !== 'string') {
      return res.status(400).json({
        error: 'validation_error',
        message: 'topicId is required',
      });
    }

    if (!title || typeof title !== 'string' || title.trim().length === 0) {
      return res.status(400).json({
        error: 'validation_error',
        message: 'title is required and cannot be empty',
      });
    }

    if (title.length > 500) {
      return res.status(400).json({
        error: 'validation_error',
        message: 'title must be 500 characters or less',
      });
    }

    // Verify topic exists
    const topic = await prisma.topic.findUnique({
      where: { id: topicId },
    });

    if (!topic) {
      return res.status(404).json({
        error: 'not_found',
        message: 'Topic not found',
      });
    }

    // Create thread
    const thread = await prisma.thread.create({
      data: {
        topicId,
        title: title.trim(),
        description: description?.trim() || null,
        createdBy: authReq.user.id,
        status: 'open',
      },
      include: {
        topic: {
          select: {
            id: true,
            name: true,
          },
        },
      },
    });

    return res.status(201).json({
      threadId: thread.id,
      topicId: thread.topicId,
      title: thread.title,
      description: thread.description,
      status: thread.status,
      createdAt: thread.createdAt.toISOString(),
    });
  } catch (error: any) {
    return res.status(500).json({ error: 'internal_server_error', message: error.message });
  }
};

