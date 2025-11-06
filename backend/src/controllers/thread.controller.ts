import { Request, Response } from 'express';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

export const getThread = async (req: Request, res: Response) => {
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

    // Get all nodes for this thread
    const nodes = await prisma.node.findMany({
      where: { threadId },
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

    // Transform nodes to match API format
    const formattedNodes = nodes.map((node) => ({
      nodeId: node.id,
      threadId: node.threadId,
      parentNodeId: node.parentNodeId,
      parentRelation: node.parentRelation,
      title: node.title,
      textContent: node.textContent,
      videoUrl: node.videoUrl,
      author: node.author
        ? {
            id: node.author.id,
            displayName: node.author.displayName,
          }
        : null,
      voteTallies: {
        like: node.likeCount,
        dislike: node.dislikeCount,
        abstain: node.abstainCount,
      },
      createdAt: node.createdAt.toISOString(),
      editedAt: node.editedAt?.toISOString() || null,
    }));

    // Return thread with nodes
    res.status(200).json({
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
    res.status(500).json({ error: 'internal_server_error', message: error.message });
  }
};

export const getThreadNodes = async (req: Request, res: Response) => {
  try {
    const { threadId } = req.params;

    // Verify thread exists
    const thread = await prisma.thread.findUnique({
      where: { id: threadId },
    });

    if (!thread) {
      return res.status(404).json({ error: 'not_found', message: 'Thread not found' });
    }

    // Get all nodes for this thread
    const nodes = await prisma.node.findMany({
      where: { threadId },
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

    // Transform nodes to match API format
    const formattedNodes = nodes.map((node) => ({
      nodeId: node.id,
      threadId: node.threadId,
      parentNodeId: node.parentNodeId,
      parentRelation: node.parentRelation,
      title: node.title,
      textContent: node.textContent,
      videoUrl: node.videoUrl,
      author: node.author
        ? {
            id: node.author.id,
            displayName: node.author.displayName,
          }
        : null,
      voteTallies: {
        like: node.likeCount,
        dislike: node.dislikeCount,
        abstain: node.abstainCount,
      },
      createdAt: node.createdAt.toISOString(),
      editedAt: node.editedAt?.toISOString() || null,
    }));

    res.status(200).json(formattedNodes);
  } catch (error: any) {
    res.status(500).json({ error: 'internal_server_error', message: error.message });
  }
};

