import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/thread.dart';
import '../models/node.dart';

class ThreadService {
	final Dio _dio = ApiClient.instance;

	Future<ThreadDetailResponse> getThread(String threadId) async {
		final resp = await _dio.get('/threads/$threadId');
		return ThreadDetailResponse.fromJson(resp.data);
	}

  Future<Node> getNode(String nodeId) async {
    final resp = await _dio.get('/nodes/$nodeId');
    return Node.fromJson(resp.data);
  }

  Future<CreateNodeResponse> createNode({
    required String threadId,
    String? parentNodeId,
    String? parentRelation,
    required String title,
    String? textContent,
    String? textFormat,
    Map<String, dynamic>? video,
    bool isAnonymous = false,
  }) async {
    final payload = <String, dynamic>{
      'threadId': threadId,
      'title': title,
      'isAnonymous': isAnonymous,
      if (parentNodeId != null) 'parentNodeId': parentNodeId,
      if (parentRelation != null) 'parentRelation': parentRelation,
      if (textContent != null) 'textContent': textContent,
      if (textFormat != null) 'textFormat': textFormat,
      if (video != null) 'video': video,
    };

    final resp = await _dio.post(
      '/nodes',
      data: payload,
    );
    return CreateNodeResponse.fromJson(resp.data);
  }

  Future<CreateThreadResponse> createThread({
    required String topicId,
    required String title,
    String? description,
  }) async {
    final payload = <String, dynamic>{
      'topicId': topicId,
      'title': title,
      if (description != null && description.isNotEmpty) 'description': description,
    };

    final resp = await _dio.post(
      '/threads',
      data: payload,
    );
    return CreateThreadResponse.fromJson(resp.data);
  }
}
