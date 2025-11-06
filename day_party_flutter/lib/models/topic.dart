class Topic {
  final String topicId;
  final String name;
  final String description;
  final String visibility;
  final int threadCount;
  final String createdAt;

  Topic({
    required this.topicId,
    required this.name,
    required this.description,
    required this.visibility,
    required this.threadCount,
    required this.createdAt,
  });

  factory Topic.fromJson(Map<String, dynamic> json) {
    return Topic(
      topicId: json['topicId'],
      name: json['name'],
      description: json['description'],
      visibility: json['visibility'],
      threadCount: json['threadCount'],
      createdAt: json['createdAt'],
    );
  }
}

class TopicsResponse {
  final List<Topic> topics;

  TopicsResponse({required this.topics});

  factory TopicsResponse.fromJson(Map<String, dynamic> json) {
    return TopicsResponse(
      topics: (json['topics'] as List)
          .map((topic) => Topic.fromJson(topic))
          .toList(),
    );
  }
}

