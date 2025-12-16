import { Request, Response } from 'express';
import { Prisma, PrismaClient, ContentStatus, VideoSource, VideoProvider } from '@prisma/client';
import { getVideoPreview } from '../services/video-link.service';
import { transformNodeToResponse } from '../utils/node-response.util';
import { AuthRequest } from '../middleware/auth.middleware';

const prisma = new PrismaClient();

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
    throw new Error('video.source must be either "upload" or "external"');
  }

  const urlValue = payload.url ?? payload.videoUrl;
  const externalUrlValue = payload.externalUrl;
  const thumbnailUrl = typeof payload.thumbnailUrl === 'string' ? payload.thumbnailUrl : null;
  const durationSec =
    typeof payload.durationSec === 'number'
      ? payload.durationSec
      : typeof payload.durationSec === 'string' && payload.durationSec.trim() !== ''
      ? Number(payload.durationSec)
      : null;

  if (durationSec !== null && !Number.isFinite(durationSec)) {
    throw new Error('video.durationSec must be a finite number');
  }

  return {
    source,
    url: typeof urlValue === 'string' ? urlValue : undefined,
    externalUrl: typeof externalUrlValue === 'string' ? externalUrlValue : undefined,
    thumbnailUrl,
    durationSec: durationSec ?? null,
  };
};

const resolveVideoData = async (payload: VideoPayload | null | undefined): Promise<VideoPrismaData | null> => {
  if (payload === undefined) {
    return null; // no update requested
  }

  if (payload === null) {
    return { ...EMPTY_VIDEO_DATA };
  }

  if (payload.source === 'upload') {
    const url = payload.url;
    if (!url) {
      throw new Error('video.url is required when source is "upload"');
    }

    return {
      videoUrl: url,
      videoThumbnailUrl: payload.thumbnailUrl ?? null,
      videoDurationSec: payload.durationSec ?? null,
      videoSource: VideoSource.upload,
      videoProvider: null,
      videoProviderId: null,
      videoEmbedHtml: null,
      videoMetadataJson: Prisma.DbNull,
      videoStatus: ContentStatus.provided,
    };
  }

  const candidateUrl = payload.externalUrl ?? payload.url;
  if (!candidateUrl) {
    throw new Error('video.externalUrl (or url) is required when source is "external"');
  }

  const preview = await getVideoPreview(candidateUrl);

  return {
    videoUrl: preview.normalizedUrl,
    videoThumbnailUrl: preview.thumbnailUrl ?? payload.thumbnailUrl ?? null,
    videoDurationSec: preview.durationSec ?? payload.durationSec ?? null,
    videoSource: VideoSource.external,
    videoProvider: preview.provider as VideoProvider,
    videoProviderId: preview.providerId,
    videoEmbedHtml: preview.embedHtml ?? null,
    videoMetadataJson: preview.metadata
      ? (preview.metadata as Prisma.JsonObject)
      : Prisma.DbNull,
    videoStatus: ContentStatus.linked,
  };
};

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

    return res.status(200).json(transformNodeToResponse(node));
  } catch (error: any) {
    return res.status(500).json({ error: 'internal_server_error', message: error.message });
  }
};

export const createNode = async (req: Request, res: Response): Promise<Response | void> => {
  try {
    const authReq = req as AuthRequest;
    if (!authReq.user) {
      return res.status(401).json({
        error: 'unauthorized',
        message: 'Authentication required',
      });
    }

    const { threadId, parentNodeId, parentRelation, title, textContent, textFormat, videoUrl, isAnonymous } = req.body;
    const videoPayloadRaw = req.body.video;

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

    const normalizedVideoPayload = normaliseVideoPayload(
      videoPayloadRaw ?? (typeof videoUrl === 'string' ? { source: 'upload', url: videoUrl } : undefined),
    );
    let videoData: VideoPrismaData | null = null;

    try {
      videoData = await resolveVideoData(normalizedVideoPayload);
    } catch (videoError: any) {
      return res.status(422).json({
        error: 'unprocessable',
        message: videoError?.message || 'Invalid video payload',
      });
    }

    // Determine textFormat: use provided format, or auto-detect Delta JSON
    let detectedTextFormat: 'plain' | 'markdown' | 'html' | 'delta' = 'plain';
    if (textFormat) {
      if (['plain', 'markdown', 'html', 'delta'].includes(textFormat)) {
        detectedTextFormat = textFormat as 'plain' | 'markdown' | 'html' | 'delta';
      }
    } else if (textContent) {
      // Auto-detect Delta JSON format
      // Handle case where textContent might be a string or already parsed object
      try {
        let parsed: any;
        if (typeof textContent === 'string') {
          parsed = JSON.parse(textContent);
        } else if (typeof textContent === 'object') {
          // Already parsed (shouldn't happen but handle gracefully)
          parsed = textContent;
        } else {
          // Not a valid type, keep default 'plain'
          parsed = null;
        }
        
        if (parsed && typeof parsed === 'object') {
          // Check if it's Delta format: has 'ops' array
          if (Array.isArray(parsed.ops) || Array.isArray(parsed)) {
            detectedTextFormat = 'delta';
            // If textContent was an object, convert it to string for storage
            if (typeof textContent !== 'string') {
              textContent = JSON.stringify(parsed);
            }
          }
        }
      } catch {
        // Not JSON, keep default 'plain'
      }
    }

    const node = await prisma.node.create({
      data: {
        threadId,
        parentNodeId: parentNodeId || null,
        parentRelation: parentRelation || null,
        title,
        textContent: textContent || null,
        textFormat: detectedTextFormat,
        isAnonymous: isAnonymous || false,
        authorId: isAnonymous ? null : authReq.user.id,
        ...(videoData ?? EMPTY_VIDEO_DATA),
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

    return res.status(201).json(transformNodeToResponse(node));
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
    const { title, textContent, textFormat, videoUrl, parentRelation } = req.body;
    const videoPayloadRaw = req.body.video;

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

    let videoData: VideoPrismaData | null = null;
    try {
      const normalizedVideoPayload = normaliseVideoPayload(
        videoPayloadRaw ??
          (videoUrl !== undefined
            ? videoUrl
              ? { source: 'upload', url: videoUrl }
              : null
            : undefined),
      );
      videoData = await resolveVideoData(normalizedVideoPayload);
    } catch (videoError: any) {
      return res.status(422).json({
        error: 'unprocessable',
        message: videoError?.message || 'Invalid video payload',
      });
    }

    // Determine textFormat: use provided format, or auto-detect Delta JSON
    let detectedTextFormat: 'plain' | 'markdown' | 'html' | 'delta' | undefined = undefined;
    if (textFormat !== undefined) {
      if (['plain', 'markdown', 'html', 'delta'].includes(textFormat)) {
        detectedTextFormat = textFormat as 'plain' | 'markdown' | 'html' | 'delta';
      }
    } else if (textContent !== undefined && textContent) {
      // Auto-detect Delta JSON format
      try {
        const parsed = JSON.parse(textContent);
        if (parsed && typeof parsed === 'object' && Array.isArray(parsed.ops)) {
          detectedTextFormat = 'delta';
        }
      } catch {
        // Not JSON, don't change format
      }
    }

    const updatedNode = await prisma.node.update({
      where: { id: nodeId },
      data: {
        ...(title !== undefined && { title }),
        ...(textContent !== undefined && { textContent }),
        ...(detectedTextFormat !== undefined && { textFormat: detectedTextFormat }),
        ...(parentRelation !== undefined && { parentRelation }),
        ...(videoData !== null ? videoData : {}),
        editedAt: new Date(),
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

    return res.status(200).json(transformNodeToResponse(updatedNode));
  } catch (error: any) {
    if (error.code === 'P2025') {
      return res.status(404).json({ error: 'not_found', message: 'Node not found' });
    }
    return res.status(500).json({ error: 'internal_server_error', message: error.message });
  }
};

