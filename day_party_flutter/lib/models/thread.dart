import 'node.dart';

class Thread {
  final String threadId;
  final String topicId;
  final String title;
  final String? description;
  final String status;
  final String createdAt;

  Thread({
    required this.threadId,
    required this.topicId,
    required this.title,
    this.description,
    required this.status,
    required this.createdAt,
  });

  factory Thread.fromJson(Map<String, dynamic> json) {
    return Thread(
      threadId: json['threadId'],
      topicId: json['topicId'],
      title: json['title'],
      description: json['description'],
      status: json['status'],
      createdAt: json['createdAt'],
    );
  }
}

class ThreadSummary {
  final String threadId;
  final String topicId;
  final String title;
  final String? description;
  final String status;
  final int nodeCount;
  final String createdAt;
  final Map<String, dynamic>? metadata; // Root node metadata (for bill info)

  ThreadSummary({
    required this.threadId,
    required this.topicId,
    required this.title,
    this.description,
    required this.status,
    required this.nodeCount,
    required this.createdAt,
    this.metadata,
  });

  factory ThreadSummary.fromJson(Map<String, dynamic> json) {
    return ThreadSummary(
      threadId: json['threadId'],
      topicId: json['topicId'],
      title: json['title'],
      description: json['description'],
      status: json['status'],
      nodeCount: json['nodeCount'],
      createdAt: json['createdAt'],
      metadata: json['metadata'] != null 
        ? Map<String, dynamic>.from(json['metadata'])
        : null,
    );
  }

  /// Get bill StatusID from metadata
  int? get billStatusID {
    if (metadata == null) return null;
    final statusID = metadata!['statusID'];
    if (statusID is int) return statusID;
    if (statusID is String) return int.tryParse(statusID);
    return null;
  }

  /// Get bill ID from metadata
  int? get billId {
    if (metadata == null) return null;
    final billId = metadata!['billId'];
    if (billId is int) return billId;
    if (billId is String) return int.tryParse(billId);
    return null;
  }
}

class ThreadsResponse {
  final List<ThreadSummary> threads;

  ThreadsResponse({required this.threads});

  factory ThreadsResponse.fromJson(Map<String, dynamic> json) {
    return ThreadsResponse(
      threads: (json['threads'] as List)
          .map((thread) => ThreadSummary.fromJson(thread))
          .toList(),
    );
  }
}

class ThreadDetailResponse {
  final Thread thread;
  final List<Node> nodes;

  ThreadDetailResponse({
    required this.thread,
    required this.nodes,
  });

  factory ThreadDetailResponse.fromJson(Map<String, dynamic> json) {
    return ThreadDetailResponse(
      thread: Thread.fromJson(json['thread']),
      nodes: (json['nodes'] as List).map((n) => Node.fromJson(n)).toList(),
    );
  }
}

class CreateNodeResponse {
  final String nodeId;
  final String threadId;
  final String? parentNodeId;
  final String? parentRelation;
  final String title;
  final Author? author;
  final String createdAt;

  CreateNodeResponse({
    required this.nodeId,
    required this.threadId,
    this.parentNodeId,
    this.parentRelation,
    required this.title,
    this.author,
    required this.createdAt,
  });

  factory CreateNodeResponse.fromJson(Map<String, dynamic> json) {
    return CreateNodeResponse(
      nodeId: json['nodeId'],
      threadId: json['threadId'],
      parentNodeId: json['parentNodeId'],
      parentRelation: json['parentRelation'],
      title: json['title'],
      author: json['author'] != null ? Author.fromJson(json['author']) : null,
      createdAt: json['createdAt'],
    );
  }
}

class CreateThreadResponse {
  final String threadId;
  final String topicId;
  final String title;
  final String? description;
  final String status;
  final String createdAt;

  CreateThreadResponse({
    required this.threadId,
    required this.topicId,
    required this.title,
    this.description,
    required this.status,
    required this.createdAt,
  });

  factory CreateThreadResponse.fromJson(Map<String, dynamic> json) {
    return CreateThreadResponse(
      threadId: json['threadId'],
      topicId: json['topicId'],
      title: json['title'],
      description: json['description'],
      status: json['status'],
      createdAt: json['createdAt'],
    );
  }
}

