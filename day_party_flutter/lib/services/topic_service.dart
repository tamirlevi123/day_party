import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/topic.dart';
import '../models/thread.dart';

class TopicService {
  final Dio _dio = ApiClient.instance;

  Future<List<Topic>> getTopics() async {
    try {
      final response = await _dio.get('/topics');
      final data = TopicsResponse.fromJson(response.data);
      return data.topics;
    } catch (e) {
      throw Exception('Failed to fetch topics: $e');
    }
  }

  Future<Topic> getTopic(String topicId) async {
    try {
      final response = await _dio.get('/topics/$topicId');
      return Topic.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to fetch topic: $e');
    }
  }

  Future<List<ThreadSummary>> getTopicThreads(String topicId) async {
    try {
      final response = await _dio.get('/topics/$topicId/threads');
      final data = ThreadsResponse.fromJson(response.data);
      return data.threads;
    } catch (e) {
      throw Exception('Failed to fetch topic threads: $e');
    }
  }
}

