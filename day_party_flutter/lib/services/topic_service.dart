import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../core/logger.dart';
import '../models/topic.dart';
import '../models/thread.dart';

class TopicService {
  final Dio _dio = ApiClient.instance;

  Future<List<Topic>> getTopics() async {
    try {
      final baseUrl = ApiClient.baseUrl;
      appLogger.d('Fetching topics from: $baseUrl/topics');
      final response = await _dio.get('/topics');
      final data = TopicsResponse.fromJson(response.data);
      return data.topics;
    } on DioException catch (e) {
      final baseUrl = ApiClient.baseUrl;
      String errorMessage = 'Failed to fetch topics';
      
      if (e.type == DioExceptionType.connectionTimeout) {
        errorMessage = 'Connection timeout: Cannot reach backend at $baseUrl\n\n'
            'Please verify:\n'
            '1. Backend server is running (check: http://192.168.0.101:3000/health)\n'
            '2. Device and computer are on the same Wi-Fi network\n'
            '3. IP address is correct (current: 192.168.0.101)\n'
            '4. Firewall allows connections on port 3000';
      } else if (e.type == DioExceptionType.receiveTimeout) {
        errorMessage = 'Receive timeout: Backend took too long to respond';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage = 'Connection error: Cannot connect to $baseUrl\n\n'
            'Check if backend is running and accessible';
      }
      
      appLogger.e('TopicService error', error: e);
      throw Exception('$errorMessage\n\nOriginal error: $e');
    } catch (e) {
      appLogger.e('TopicService unexpected error', error: e);
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

  Future<List<ThreadSummary>> getTopicThreads(String topicId, {String? statusIDs}) async {
    try {
      final queryParams = statusIDs != null ? {'statusID': statusIDs} : null;
      final response = await _dio.get(
        '/topics/$topicId/threads',
        queryParameters: queryParams,
      );
      final data = ThreadsResponse.fromJson(response.data);
      return data.threads;
    } catch (e) {
      throw Exception('Failed to fetch topic threads: $e');
    }
  }
}

