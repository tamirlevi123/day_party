class Node {
  final String nodeId;
  final String threadId;
  final String? parentNodeId;
  final String? parentRelation; // "pro", "against", "neutral"
  final String title;
  final String? textContent;
  final String? textFormat; // 'plain', 'markdown', 'html', 'delta'
  final String? legacyVideoUrl;
  final VideoAttachment? video;
  final Author? author;
  final VoteTallies voteTallies;
  final String createdAt;
  final String? editedAt;

  Node({
    required this.nodeId,
    required this.threadId,
    this.parentNodeId,
    this.parentRelation,
    required this.title,
    this.textContent,
    this.textFormat,
    this.legacyVideoUrl,
    this.video,
    this.author,
    required this.voteTallies,
    required this.createdAt,
    this.editedAt,
  });

  bool get hasVideo => video != null || legacyVideoUrl != null;
  bool get hasExternalVideo => video?.source == VideoSource.external;
  String? get videoUrl => video?.url ?? legacyVideoUrl;

  factory Node.fromJson(Map<String, dynamic> json) {
    return Node(
      nodeId: json['nodeId'],
      threadId: json['threadId'],
      parentNodeId: json['parentNodeId'],
      parentRelation: json['parentRelation'],
      title: json['title'],
      textContent: json['textContent'],
      textFormat: json['textFormat'],
      legacyVideoUrl: json['videoUrl'],
      video: json['video'] != null ? VideoAttachment.fromJson(json['video']) : null,
      author: json['author'] != null ? Author.fromJson(json['author']) : null,
      voteTallies: VoteTallies.fromJson(json['voteTallies']),
      createdAt: json['createdAt'],
      editedAt: json['editedAt'],
    );
  }
}

class VideoAttachment {
  final VideoSource source;
  final String? url;
  final String? provider;
  final String? providerId;
  final String? thumbnailUrl;
  final int? durationSec;
  final String? embedHtml;
  final Map<String, dynamic>? metadata;
  final String? title;
  final String? description;

  const VideoAttachment({
    required this.source,
    this.url,
    this.provider,
    this.providerId,
    this.thumbnailUrl,
    this.durationSec,
    this.embedHtml,
    this.metadata,
    this.title,
    this.description,
  });

  factory VideoAttachment.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? metadata;
    if (json['metadata'] is Map<String, dynamic>) {
      metadata = Map<String, dynamic>.from(json['metadata']);
    }
    return VideoAttachment(
      source: VideoSourceExtension.fromJson(json['source']),
      url: json['url'],
      provider: json['provider'],
      providerId: json['providerId'],
      thumbnailUrl: json['thumbnailUrl'],
      durationSec: json['durationSec'],
      embedHtml: json['embedHtml'],
      metadata: metadata,
      title: json['title'] ?? metadata?['title'],
      description: json['description'] ?? metadata?['description'],
    );
  }

  bool get isExternal => source == VideoSource.external;
}

enum VideoSource {
  upload,
  external,
}

extension VideoSourceExtension on VideoSource {
  static VideoSource fromJson(String? value) {
    switch (value) {
      case 'external':
        return VideoSource.external;
      case 'upload':
      default:
        return VideoSource.upload;
    }
  }
}

class Author {
  final String id;
  final String displayName;

  Author({
    required this.id,
    required this.displayName,
  });

  factory Author.fromJson(Map<String, dynamic> json) {
    return Author(
      id: json['id'],
      displayName: json['displayName'],
    );
  }
}

class VoteTallies {
  final int like;
  final int dislike;
  final int abstain;

  VoteTallies({
    required this.like,
    required this.dislike,
    required this.abstain,
  });

  factory VoteTallies.fromJson(Map<String, dynamic> json) {
    return VoteTallies(
      like: json['like'],
      dislike: json['dislike'],
      abstain: json['abstain'],
    );
  }
}

// Note: ThreadDetailResponse moved to thread.dart to avoid circular import

