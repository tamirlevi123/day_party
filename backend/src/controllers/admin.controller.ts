import { Request, Response } from 'express';
import { Prisma, PrismaClient, ModerationState, ContentStatus, VideoSource, VideoProvider } from '@prisma/client';
import { AuthRequest } from '../middleware/auth.middleware';
import { transformNodeToResponse } from '../utils/node-response.util';
import { getVideoPreview } from '../services/video-link.service';

const prisma = new PrismaClient();

// ============================================================================
// Admin Node Management
// ============================================================================

type VideoPayload = {
  source: 'upload' | 'external';
  url?: string;
  externalUrl?: string;
  thumbnailUrl?: string | null;
  durationSec?: number | null;
};

type VideoPrismaData = {
  videoUrl: string | null;
  videoThumbnailUrl: string | null;
  videoDurationSec: number | null;
  videoSource: VideoSource;
  videoProvider: VideoProvider | null;
  videoProviderId: string | null;
  videoEmbedHtml: string | null;
  videoMetadataJson: Prisma.NullableJsonNullValueInput | Prisma.InputJsonValue;
  videoStatus: ContentStatus;
};

const EMPTY_VIDEO_DATA: VideoPrismaData = {
  videoUrl: null,
  videoThumbnailUrl: null,
  videoDurationSec: null,
  videoSource: VideoSource.upload,
  videoProvider: null,
  videoProviderId: null,
  videoEmbedHtml: null,
  videoMetadataJson: Prisma.DbNull,
  videoStatus: ContentStatus.missing,
};

const normaliseVideoPayload = (raw: unknown): VideoPayload | null | undefined => {
  if (raw === undefined) return undefined;
  if (raw === null) return null;

  if (typeof raw !== 'object') {
    throw new Error('video must be an object');
  }

  const payload = raw as Record<string, unknown>;
  const source = payload.source;

  if (source !== 'upload' && source !== 'external') {
    throw new Error('video.source must be "upload" or "external"');
  }

  return {
    source,
    url: typeof payload.url === 'string' ? payload.url : undefined,
    externalUrl: typeof payload.externalUrl === 'string' ? payload.externalUrl : undefined,
    thumbnailUrl: payload.thumbnailUrl === null || typeof payload.thumbnailUrl === 'string' ? payload.thumbnailUrl : undefined,
    durationSec: typeof payload.durationSec === 'number' ? payload.durationSec : undefined,
  };
};

const resolveVideoData = async (payload: VideoPayload | null | undefined): Promise<VideoPrismaData | null> => {
  if (payload === null || payload === undefined) {
    return null;
  }

  if (payload.source === 'external') {
    const externalUrl = payload.externalUrl || payload.url;
    if (!externalUrl) {
      throw new Error('externalUrl or url is required for external video source');
    }

    const preview = await getVideoPreview(externalUrl);
    return {
      videoUrl: preview.normalizedUrl,
      videoThumbnailUrl: preview.thumbnailUrl || null,
      videoDurationSec: preview.durationSec || null,
      videoSource: VideoSource.external,
      videoProvider: preview.provider || null,
      videoProviderId: preview.providerId || null,
      videoEmbedHtml: preview.embedHtml || null,
      videoMetadataJson: preview.metadata
        ? (preview.metadata as Prisma.JsonObject)
        : Prisma.DbNull,
      videoStatus: ContentStatus.linked,
    };
  }

  // Upload source
  const url = payload.url;
  if (!url) {
    return EMPTY_VIDEO_DATA;
  }

  return {
    videoUrl: url,
    videoThumbnailUrl: payload.thumbnailUrl || null,
    videoDurationSec: payload.durationSec || null,
    videoSource: VideoSource.upload,
    videoProvider: null,
    videoProviderId: null,
    videoEmbedHtml: null,
    videoMetadataJson: Prisma.DbNull,
    videoStatus: ContentStatus.provided,
  };
};

/**
 * Admin: List all nodes with optional filters
 * GET /admin/nodes
 */
export const listNodes = async (req: Request, res: Response): Promise<Response | void> => {
  try {
    const {
      threadId,
      authorId,
      isDeleted,
      moderationState,
      limit = '50',
      offset = '0',
    } = req.query;

    const where: Prisma.NodeWhereInput = {};

    if (threadId && typeof threadId === 'string') {
      where.threadId = threadId;
    }

    if (authorId && typeof authorId === 'string') {
      where.authorId = authorId;
    }

    if (isDeleted !== undefined) {
      where.isDeleted = isDeleted === 'true';
    }

    if (moderationState && typeof moderationState === 'string') {
      where.moderationState = moderationState as ModerationState;
    }

    const nodes = await prisma.node.findMany({
      where,
      include: {
        author: {
          select: {
            id: true,
            displayName: true,
          },
        },
        thread: {
          select: {
            id: true,
            title: true,
            topicId: true,
          },
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
      take: parseInt(limit as string, 10),
      skip: parseInt(offset as string, 10),
    });

    const total = await prisma.node.count({ where });

    return res.status(200).json({
      nodes: nodes.map(transformNodeToResponse),
      pagination: {
        total,
        limit: parseInt(limit as string, 10),
        offset: parseInt(offset as string, 10),
      },
    });
  } catch (error: any) {
    return res.status(500).json({
      error: 'internal_server_error',
      message: error.message,
    });
  }
};

/**
 * Admin: Get a single node by ID (including deleted)
 * GET /admin/nodes/:nodeId
 */
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
        thread: {
          select: {
            id: true,
            title: true,
            topicId: true,
          },
        },
      },
    });

    if (!node) {
      return res.status(404).json({
        error: 'not_found',
        message: 'Node not found',
      });
    }

    return res.status(200).json(transformNodeToResponse(node));
  } catch (error: any) {
    return res.status(500).json({
      error: 'internal_server_error',
      message: error.message,
    });
  }
};

/**
 * Admin: Update any node (full edit access)
 * PATCH /admin/nodes/:nodeId
 */
export const updateNode = async (req: Request, res: Response): Promise<Response | void> => {
  try {
    const { nodeId } = req.params;
    const authReq = req as AuthRequest;
    const {
      title,
      textContent,
      textFormat,
      parentRelation,
      moderationState,
      isAnonymous,
      video,
    } = req.body;

    // Check if node exists
    const existingNode = await prisma.node.findUnique({
      where: { id: nodeId },
    });

    if (!existingNode) {
      return res.status(404).json({
        error: 'not_found',
        message: 'Node not found',
      });
    }

    // Validate parentRelation if provided
    if (parentRelation !== undefined) {
      if (parentRelation !== null && !['pro', 'against', 'neutral'].includes(parentRelation)) {
        return res.status(422).json({
          error: 'unprocessable',
          message: 'parentRelation must be one of: pro, against, neutral, or null',
        });
      }
    }

    // Validate moderationState if provided
    if (moderationState !== undefined) {
      if (!['visible', 'limited', 'hidden', 'removed'].includes(moderationState)) {
        return res.status(422).json({
          error: 'unprocessable',
          message: 'moderationState must be one of: visible, limited, hidden, removed',
        });
      }
    }

    // Process video data if provided
    let videoData: VideoPrismaData | null = null;
    if (video !== undefined) {
      try {
        const normalizedVideoPayload = normaliseVideoPayload(video);
        videoData = await resolveVideoData(normalizedVideoPayload);
      } catch (videoError: any) {
        return res.status(422).json({
          error: 'unprocessable',
          message: videoError?.message || 'Invalid video payload',
        });
      }
    }

    // Build update data
    const updateData: Prisma.NodeUpdateInput = {
      ...(title !== undefined && { title }),
      ...(textContent !== undefined && { textContent }),
      ...(textFormat !== undefined && { textFormat }),
      ...(parentRelation !== undefined && { parentRelation }),
      ...(moderationState !== undefined && { moderationState }),
      ...(isAnonymous !== undefined && { isAnonymous }),
      ...(videoData !== null && videoData),
      editedAt: new Date(),
    };

    // Update node
    const updatedNode = await prisma.node.update({
      where: { id: nodeId },
      data: updateData,
      include: {
        author: {
          select: {
            id: true,
            displayName: true,
          },
        },
        thread: {
          select: {
            id: true,
            title: true,
            topicId: true,
          },
        },
      },
    });

    // Create version history entry
    await prisma.nodeVersion.create({
      data: {
        nodeId: nodeId,
        versionNumber: (await prisma.nodeVersion.count({ where: { nodeId } })) + 1,
        title: updatedNode.title,
        textContent: updatedNode.textContent,
        textFormat: updatedNode.textFormat,
        videoUrl: updatedNode.videoUrl,
        videoDurationSec: updatedNode.videoDurationSec,
        videoThumbnailUrl: updatedNode.videoThumbnailUrl,
        videoSource: updatedNode.videoSource,
        videoProvider: updatedNode.videoProvider,
        videoProviderId: updatedNode.videoProviderId,
        videoEmbedHtml: updatedNode.videoEmbedHtml,
        videoMetadataJson: updatedNode.videoMetadataJson
          ? (updatedNode.videoMetadataJson as Prisma.InputJsonValue)
          : Prisma.DbNull,
        textLanguage: updatedNode.textLanguage,
        textConfidence: updatedNode.textConfidence,
        textStatus: updatedNode.textStatus,
        videoStatus: updatedNode.videoStatus,
        moderationState: updatedNode.moderationState,
        editedBy: authReq.user?.id || null,
        changeSummary: 'Admin edit',
      },
    });

    return res.status(200).json(transformNodeToResponse(updatedNode));
  } catch (error: any) {
    if (error.code === 'P2025') {
      return res.status(404).json({
        error: 'not_found',
        message: 'Node not found',
      });
    }
    return res.status(500).json({
      error: 'internal_server_error',
      message: error.message,
    });
  }
};

/**
 * Admin: Soft delete a node
 * DELETE /admin/nodes/:nodeId
 */
export const deleteNode = async (req: Request, res: Response): Promise<Response | void> => {
  try {
    const { nodeId } = req.params;
    const authReq = req as AuthRequest;

    // Check if node exists
    const existingNode = await prisma.node.findUnique({
      where: { id: nodeId },
    });

    if (!existingNode) {
      return res.status(404).json({
        error: 'not_found',
        message: 'Node not found',
      });
    }

    if (existingNode.isDeleted) {
      return res.status(400).json({
        error: 'bad_request',
        message: 'Node is already deleted',
      });
    }

    // Soft delete: set isDeleted flag and update moderation state
    const deletedNode = await prisma.node.update({
      where: { id: nodeId },
      data: {
        isDeleted: true,
        moderationState: ModerationState.removed,
        editedAt: new Date(),
      },
      include: {
        author: {
          select: {
            id: true,
            displayName: true,
          },
        },
        thread: {
          select: {
            id: true,
            title: true,
            topicId: true,
          },
        },
      },
    });

    // Create version history entry
    await prisma.nodeVersion.create({
      data: {
        nodeId: nodeId,
        versionNumber: (await prisma.nodeVersion.count({ where: { nodeId } })) + 1,
        title: deletedNode.title,
        textContent: deletedNode.textContent,
        textFormat: deletedNode.textFormat,
        videoUrl: deletedNode.videoUrl,
        videoDurationSec: deletedNode.videoDurationSec,
        videoThumbnailUrl: deletedNode.videoThumbnailUrl,
        videoSource: deletedNode.videoSource,
        videoProvider: deletedNode.videoProvider,
        videoProviderId: deletedNode.videoProviderId,
        videoEmbedHtml: deletedNode.videoEmbedHtml,
        videoMetadataJson: deletedNode.videoMetadataJson
          ? (deletedNode.videoMetadataJson as Prisma.InputJsonValue)
          : Prisma.DbNull,
        textLanguage: deletedNode.textLanguage,
        textConfidence: deletedNode.textConfidence,
        textStatus: deletedNode.textStatus,
        videoStatus: deletedNode.videoStatus,
        moderationState: deletedNode.moderationState,
        editedBy: authReq.user?.id || null,
        changeSummary: 'Admin deletion',
      },
    });

    return res.status(200).json({
      message: 'Node deleted successfully',
      node: transformNodeToResponse(deletedNode),
    });
  } catch (error: any) {
    if (error.code === 'P2025') {
      return res.status(404).json({
        error: 'not_found',
        message: 'Node not found',
      });
    }
    return res.status(500).json({
      error: 'internal_server_error',
      message: error.message,
    });
  }
};

/**
 * Admin: Restore a deleted node
 * POST /admin/nodes/:nodeId/restore
 */
export const restoreNode = async (req: Request, res: Response): Promise<Response | void> => {
  try {
    const { nodeId } = req.params;
    const authReq = req as AuthRequest;

    // Check if node exists
    const existingNode = await prisma.node.findUnique({
      where: { id: nodeId },
    });

    if (!existingNode) {
      return res.status(404).json({
        error: 'not_found',
        message: 'Node not found',
      });
    }

    if (!existingNode.isDeleted) {
      return res.status(400).json({
        error: 'bad_request',
        message: 'Node is not deleted',
      });
    }

    // Restore: unset isDeleted flag and set moderation state to visible
    const restoredNode = await prisma.node.update({
      where: { id: nodeId },
      data: {
        isDeleted: false,
        moderationState: ModerationState.visible,
        editedAt: new Date(),
      },
      include: {
        author: {
          select: {
            id: true,
            displayName: true,
          },
        },
        thread: {
          select: {
            id: true,
            title: true,
            topicId: true,
          },
        },
      },
    });

    // Create version history entry
    await prisma.nodeVersion.create({
      data: {
        nodeId: nodeId,
        versionNumber: (await prisma.nodeVersion.count({ where: { nodeId } })) + 1,
        title: restoredNode.title,
        textContent: restoredNode.textContent,
        textFormat: restoredNode.textFormat,
        videoUrl: restoredNode.videoUrl,
        videoDurationSec: restoredNode.videoDurationSec,
        videoThumbnailUrl: restoredNode.videoThumbnailUrl,
        videoSource: restoredNode.videoSource,
        videoProvider: restoredNode.videoProvider,
        videoProviderId: restoredNode.videoProviderId,
        videoEmbedHtml: restoredNode.videoEmbedHtml,
        videoMetadataJson: restoredNode.videoMetadataJson
          ? (restoredNode.videoMetadataJson as Prisma.InputJsonValue)
          : Prisma.DbNull,
        textLanguage: restoredNode.textLanguage,
        textConfidence: restoredNode.textConfidence,
        textStatus: restoredNode.textStatus,
        videoStatus: restoredNode.videoStatus,
        moderationState: restoredNode.moderationState,
        editedBy: authReq.user?.id || null,
        changeSummary: 'Admin restoration',
      },
    });

    return res.status(200).json({
      message: 'Node restored successfully',
      node: transformNodeToResponse(restoredNode),
    });
  } catch (error: any) {
    if (error.code === 'P2025') {
      return res.status(404).json({
        error: 'not_found',
        message: 'Node not found',
      });
    }
    return res.status(500).json({
      error: 'internal_server_error',
      message: error.message,
    });
  }
};

