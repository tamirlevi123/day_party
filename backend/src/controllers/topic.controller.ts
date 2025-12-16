import { Request, Response } from 'express';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

export const getTopics = async (_req: Request, res: Response): Promise<Response | void> => {
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

    return res.status(200).json({
      topics: formattedTopics,
    });
  } catch (error: any) {
    console.error('Error fetching topics:', error);
    return res.status(500).json({
      error: 'internal_error',
      message: 'Failed to fetch topics',
    });
  }
};

export const getTopic = async (req: Request, res: Response): Promise<Response | void> => {
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

    return res.status(200).json({
      topicId: topic.id,
      name: topic.name,
      description: topic.description,
      visibility: topic.visibility,
      threadCount: topic._count.threads,
      createdAt: topic.createdAt.toISOString(),
    });
  } catch (error: any) {
    console.error('Error fetching topic:', error);
    return res.status(500).json({
      error: 'internal_error',
      message: 'Failed to fetch topic',
    });
  }
};

export const getTopicThreads = async (req: Request, res: Response): Promise<Response | void> => {
  try {
    const { topicId } = req.params;
    // Support both single statusID and comma-separated list of statusIDs
    const statusIDParam = req.query.statusID as string | undefined;
    const statusIDs = statusIDParam 
      ? statusIDParam.split(',').map(id => parseInt(id.trim(), 10)).filter(id => !isNaN(id))
      : undefined;

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
        nodes: {
          where: {
            parentNodeId: null, // Root nodes only
          },
          select: {
            metadataJson: true,
          },
          take: 1, // Just need the root node metadata
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
    });

    // Format response and filter by statusID if provided
    let formattedThreads = threads.map((thread) => {
      const rootNode = thread.nodes[0];
      const metadata = rootNode?.metadataJson as Record<string, any> | null;
      const billStatusID = metadata?.statusID as number | undefined;

      return {
        threadId: thread.id,
        topicId: thread.topicId,
        title: thread.title,
        description: thread.description,
        status: thread.status,
        nodeCount: thread._count.nodes,
        createdAt: thread.createdAt.toISOString(),
        metadata: metadata || null, // Include root node metadata
      };
    });

    // Filter by statusIDs if provided (match any of the provided statusIDs)
    if (statusIDs !== undefined && statusIDs.length > 0) {
      formattedThreads = formattedThreads.filter((thread) => {
        const metadata = thread.metadata as Record<string, any> | null;
        const billStatusID = metadata?.statusID as number | undefined;
        return billStatusID !== undefined && statusIDs.includes(billStatusID);
      });
    }

    return res.status(200).json({
      threads: formattedThreads,
    });
  } catch (error: any) {
    console.error('Error fetching topic threads:', error);
    return res.status(500).json({
      error: 'internal_error',
      message: 'Failed to fetch topic threads',
    });
  }
};

