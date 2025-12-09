import { Node, ContentStatus, VideoSource, Prisma } from '@prisma/client';

type AuthorSummary = {
  id: string;
  displayName: string;
} | null;

type NodeWithAuthor = Node & { author?: AuthorSummary };

const mapMetadata = (metadata: Prisma.JsonValue | null): Record<string, unknown> | null => {
  if (metadata === null || metadata === undefined) {
    return null;
  }

  if (Array.isArray(metadata)) {
    return { items: metadata };
  }

  if (typeof metadata === 'object') {
    return metadata as Record<string, unknown>;
  }

  return { value: metadata };
};

const hasVideo = (node: Node): boolean => {
  if (node.videoUrl) return true;
  if (node.videoEmbedHtml) return true;
  return node.videoStatus !== ContentStatus.missing;
};

export const transformNodeToResponse = (node: NodeWithAuthor) => ({
  nodeId: node.id,
  threadId: node.threadId,
  parentNodeId: node.parentNodeId,
  parentRelation: node.parentRelation,
  title: node.title,
  textContent: node.textContent,
  textFormat: node.textFormat,
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
  video: hasVideo(node)
    ? {
        source: node.videoSource ?? VideoSource.upload,
        url: node.videoUrl,
        provider: node.videoProvider ?? null,
        providerId: node.videoProviderId ?? null,
        thumbnailUrl: node.videoThumbnailUrl ?? null,
        durationSec: node.videoDurationSec ?? null,
        embedHtml: node.videoEmbedHtml ?? null,
        status: node.videoStatus,
        metadata: mapMetadata(node.videoMetadataJson),
      }
    : null,
  createdAt: node.createdAt.toISOString(),
  editedAt: node.editedAt?.toISOString() || null,
  // Admin fields (for admin endpoints)
  moderationState: node.moderationState,
  isDeleted: node.isDeleted,
});

