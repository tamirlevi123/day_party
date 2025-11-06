class Node {
  final String nodeId;
  final String threadId;
  final String? parentNodeId;
  final String? parentRelation; // "pro", "against", "neutral"
  final String title;
  final String? textContent;
  final String? videoUrl;
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
    this.videoUrl,
    this.author,
    required this.voteTallies,
    required this.createdAt,
    this.editedAt,
  });

  factory Node.fromJson(Map<String, dynamic> json) {
    return Node(
      nodeId: json['nodeId'],
      threadId: json['threadId'],
      parentNodeId: json['parentNodeId'],
      parentRelation: json['parentRelation'],
      title: json['title'],
      textContent: json['textContent'],
      videoUrl: json['videoUrl'],
      author: json['author'] != null ? Author.fromJson(json['author']) : null,
      voteTallies: VoteTallies.fromJson(json['voteTallies']),
      createdAt: json['createdAt'],
      editedAt: json['editedAt'],
    );
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

