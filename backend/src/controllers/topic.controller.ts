import { Request, Response } from 'express';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

export const getTopics = async (req: Request, res: Response) => {
  try {
    const topics = await prisma.topic.findMany({
      where: {
        visibility: 'public',
      },
      include: {
        threads: {
          where: {
            status: 'open',
          },
          select: {
            id: true,
          },
        },
        _count: {
          select: {
            threads: true,
          },
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
    });

    // Format response to include thread count
    const formattedTopics = topics.map((topic) => ({
      topicId: topic.id,
      name: topic.name,
      description: topic.description,
      visibility: topic.visibility,
      threadCount: topic._count.threads,
      createdAt: topic.createdAt.toISOString(),
    }));

    res.status(200).json({
      topics: formattedTopics,
    });
  } catch (error: any) {
    console.error('Error fetching topics:', error);
    res.status(500).json({
      error: 'internal_error',
      message: 'Failed to fetch topics',
    });
  }
};

export const getTopic = async (req: Request, res: Response) => {
  try {
    const { topicId } = req.params;

    const topic = await prisma.topic.findUnique({
      where: { id: topicId },
      include: {
        threads: {
          where: {
            status: 'open',
          },
          select: {
            id: true,
          },
        },
        _count: {
          select: {
            threads: true,
          },
        },
      },
    });

    if (!topic) {
      return res.status(404).json({
        error: 'not_found',
        message: 'Topic not found',
      });
    }

    res.status(200).json({
      topicId: topic.id,
      name: topic.name,
      description: topic.description,
      visibility: topic.visibility,
      threadCount: topic._count.threads,
      createdAt: topic.createdAt.toISOString(),
    });
  } catch (error: any) {
    console.error('Error fetching topic:', error);
    res.status(500).json({
      error: 'internal_error',
      message: 'Failed to fetch topic',
    });
  }
};

export const getTopicThreads = async (req: Request, res: Response) => {
  try {
    const { topicId } = req.params;

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

    // Get threads for this topic
    const threads = await prisma.thread.findMany({
      where: {
        topicId: topicId,
        status: 'open',
      },
      include: {
        _count: {
          select: {
            nodes: true,
          },
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
    });

    // Format response
    const formattedThreads = threads.map((thread) => ({
      threadId: thread.id,
      topicId: thread.topicId,
      title: thread.title,
      description: thread.description,
      status: thread.status,
      nodeCount: thread._count.nodes,
      createdAt: thread.createdAt.toISOString(),
    }));

    res.status(200).json({
      threads: formattedThreads,
    });
  } catch (error: any) {
    console.error('Error fetching topic threads:', error);
    res.status(500).json({
      error: 'internal_error',
      message: 'Failed to fetch topic threads',
    });
  }
};

