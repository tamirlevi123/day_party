import { Request, Response } from 'express';
import { PrismaClient } from '@prisma/client';
import { getStatusDescription } from '../services/knesset-status.service';

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
    let statusIDs = statusIDParam 
      ? statusIDParam.split(',').map(id => parseInt(id.trim(), 10)).filter(id => !isNaN(id))
      : undefined;

    console.log(`[TopicController] getTopicThreads called: topicId=${topicId}, statusIDs=${statusIDs?.join(', ') || 'none'}`);

    // Verify topic exists
    console.log(`[SQL] Checking if topic exists: topicId=${topicId}`);
    const topic = await prisma.topic.findUnique({
      where: { id: topicId },
    });
    console.log(`[SQL] Topic lookup result: ${topic ? 'found' : 'not found'}`);

    if (!topic) {
      return res.status(404).json({
        error: 'not_found',
        message: 'Topic not found',
      });
    }

    // Knesset status filtering should only apply to the Knesset bills topic.
    // Other topics do not have bill metadata, so filtering would incorrectly hide all threads.
    const KNESSET_BILLS_TOPIC_NAME = 'חוקים מהמליאה';
    if (statusIDs !== undefined && statusIDs.length > 0 && topic.name !== KNESSET_BILLS_TOPIC_NAME) {
      console.log(
        `[TopicController] Ignoring statusIDs filter for non-knesset topic "${topic.name}" (topicId=${topicId}).`
      );
      statusIDs = undefined;
    }

    // IMPORTANT PERFORMANCE PATH:
    // If statusIDs are provided for the Knesset bills topic, filter in SQL (instead of
    // fetching thousands of threads and filtering in memory).
    if (statusIDs !== undefined && statusIDs.length > 0 && topic.name === KNESSET_BILLS_TOPIC_NAME) {
      const ids = statusIDs.filter((n) => Number.isFinite(n));
      if (ids.length === 0) {
        return res.status(200).json({ threads: [] });
      }

      const inList = ids.join(','); // ints only
      console.log(`[TopicController] Using SQL-level filtering for knesset statusIDs: ${inList}`);
      const escapedTopicId = topicId.replace(/'/g, "''");

      const rows = await prisma.$queryRawUnsafe<Array<{
        threadId: string;
        topicId: string;
        title: string;
        description: string | null;
        status: string;
        createdAt: Date;
        nodeCount: bigint | number;
        metadataJson: any;
      }>>(`
        SELECT
          t.id AS threadId,
          t.topic_id AS topicId,
          t.title AS title,
          t.description AS description,
          t.status AS status,
          t.created_at AS createdAt,
          COALESCE(nc.nodeCount, 0) AS nodeCount,
          rn.metadata_json AS metadataJson
        FROM threads t
        INNER JOIN nodes rn
          ON rn.thread_id = t.id
         AND rn.parent_node_id IS NULL
        LEFT JOIN (
          SELECT thread_id, COUNT(*) AS nodeCount
          FROM nodes
          GROUP BY thread_id
        ) nc ON nc.thread_id = t.id
        WHERE t.topic_id = '${escapedTopicId}'
          AND t.status = 'open'
          AND rn.metadata_json IS NOT NULL
          AND CAST(JSON_UNQUOTE(JSON_EXTRACT(rn.metadata_json, '$.statusID')) AS UNSIGNED) IN (${inList})
        ORDER BY t.created_at DESC
      `);

      const formatted = rows.map((r) => {
        const metadata = (r.metadataJson ?? null) as Record<string, any> | null;
        const billStatusID = metadata?.statusID as number | undefined;
        const statusDescription = getStatusDescription(billStatusID);
        const enhancedMetadata = metadata ? { ...metadata, statusDescription } : null;

        return {
          threadId: r.threadId,
          topicId: r.topicId,
          title: r.title,
          description: r.description,
          status: r.status,
          nodeCount: Number(r.nodeCount),
          createdAt: r.createdAt instanceof Date ? r.createdAt.toISOString() : new Date(r.createdAt as any).toISOString(),
          metadata: enhancedMetadata,
        };
      });

      console.log(`[TopicController] Returning ${formatted.length} filtered threads (SQL-level)`);
      return res.status(200).json({ threads: formatted });
    }

    // Get threads for this topic
    console.log(`[SQL] Fetching threads for topicId=${topicId}, status='open'`);
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
            id: true,
            metadataJson: true,
          },
          take: 1, // Just need the root node metadata
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
    });
    console.log(`[SQL] Found ${threads.length} threads`);
    
    // Log detailed node/metadata information
    const threadsWithMetadata = threads.filter(t => t.nodes.length > 0 && t.nodes[0].metadataJson != null).length;
    const threadsWithoutMetadata = threads.length - threadsWithMetadata;
    console.log(`[TopicController] Threads with metadata: ${threadsWithMetadata}, without: ${threadsWithoutMetadata}`);
    
    // Log first 5 threads' node and metadata details
    threads.slice(0, 5).forEach((thread, idx) => {
      const rootNode = thread.nodes[0];
      console.log(`[TopicController] Thread ${idx + 1} (${thread.id}):`);
      console.log(`[TopicController]   Title: ${thread.title}`);
      console.log(`[TopicController]   Node count: ${thread._count.nodes}`);
      console.log(`[TopicController]   Root node exists: ${rootNode != null}`);
      if (rootNode) {
        console.log(`[TopicController]   Root node ID: ${rootNode.id}`);
        console.log(`[TopicController]   Root node metadataJson: ${JSON.stringify(rootNode.metadataJson)}`);
        const metadata = rootNode.metadataJson as Record<string, any> | null;
        if (metadata) {
          console.log(`[TopicController]   Metadata keys: ${Object.keys(metadata).join(', ')}`);
          console.log(`[TopicController]   Metadata statusID: ${metadata.statusID}`);
          console.log(`[TopicController]   Metadata billId: ${metadata.billId}`);
        } else {
          console.log(`[TopicController]   Metadata is null`);
        }
      }
    });

    // Format response and filter by statusID if provided
    console.log(`[TopicController] Formatting ${threads.length} threads...`);
    let formattedThreads = threads.map((thread, idx) => {
      const rootNode = thread.nodes[0];
      const metadata = rootNode?.metadataJson as Record<string, any> | null;
      const billStatusID = metadata?.statusID as number | undefined;

      // Get status description from in-memory cache (no SQL query - uses in-memory cache)
      const statusDescription = getStatusDescription(billStatusID);
      
      // Log metadata for first 5 threads
      if (idx < 5) {
        console.log(`[TopicController] Thread ${idx + 1}/${threads.length} (${thread.id}):`);
        console.log(`[TopicController]   Title: ${thread.title}`);
        console.log(`[TopicController]   Root node exists: ${rootNode != null}`);
        if (rootNode) {
          console.log(`[TopicController]   Root node ID: ${rootNode.id}`);
        }
        console.log(`[TopicController]   Metadata raw: ${JSON.stringify(metadata)}`);
        console.log(`[TopicController]   Metadata parsed - billStatusID: ${billStatusID}, billId: ${metadata?.billId}`);
        console.log(`[TopicController]   statusDescription from cache: ${statusDescription || 'null'}`);
        console.log(`[TopicController]   nodeCount: ${thread._count.nodes}`);
      }

      // Enhance metadata with status description
      const enhancedMetadata = metadata 
        ? { ...metadata, statusDescription }
        : null;

      return {
        threadId: thread.id,
        topicId: thread.topicId,
        title: thread.title,
        description: thread.description,
        status: thread.status,
        nodeCount: thread._count.nodes,
        createdAt: thread.createdAt.toISOString(),
        metadata: enhancedMetadata, // Include root node metadata with status description
      };
    });

    // Filter by statusIDs if provided (match any of the provided statusIDs)
    if (statusIDs !== undefined && statusIDs.length > 0) {
      console.log(`[TopicController] Filtering threads by statusIDs: ${statusIDs.join(', ')}`);
      const beforeCount = formattedThreads.length;
      formattedThreads = formattedThreads.filter((thread) => {
        const metadata = thread.metadata as Record<string, any> | null;
        const billStatusID = metadata?.statusID as number | undefined;
        const matches = billStatusID !== undefined && statusIDs.includes(billStatusID);
        return matches;
      });
      console.log(`[TopicController] Filtered ${beforeCount} threads down to ${formattedThreads.length} threads`);
    }

    console.log(`[TopicController] Returning ${formattedThreads.length} threads to client`);
    console.log(`[TopicController] Response sample (first thread):`, formattedThreads.length > 0 ? {
      threadId: formattedThreads[0].threadId,
      title: formattedThreads[0].title,
      metadata: formattedThreads[0].metadata,
    } : 'no threads');

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

