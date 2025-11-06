import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/thread.dart';

class ThreadService {
	final Dio _dio = ApiClient.instance;

	Future<ThreadDetailResponse> getThread(String threadId) async {
		final resp = await _dio.get('/threads/$threadId');
		return ThreadDetailResponse.fromJson(resp.data);
	}

	Future<CreateNodeResponse> createNode({
		required String threadId,
		String? parentNodeId,
		String? parentRelation,
		required String title,
		String? textContent,
		String? videoUrl,
		bool isAnonymous = false,
	}) async {
		final resp = await _dio.post(
			'/nodes',
			data: {
				'threadId': threadId,
				if (parentNodeId != null) 'parentNodeId': parentNodeId,
				if (parentRelation != null) 'parentRelation': parentRelation,
				'title': title,
				if (textContent != null) 'textContent': textContent,
				if (videoUrl != null) 'videoUrl': videoUrl,
				'isAnonymous': isAnonymous,
			},
		);
		return CreateNodeResponse.fromJson(resp.data);
	}
}
