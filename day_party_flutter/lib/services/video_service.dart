import 'dart:io';
import 'package:dio/dio.dart';
import '../core/api_client.dart';

class VideoService {
  final Dio _dio = ApiClient.instance;

  /// Upload a video file to the backend (which uploads to Google Drive)
  /// Returns the public URL for the video
  Future<String> uploadVideo(File videoFile) async {
    try {
      // Get file name and size
      final fileName = videoFile.path.split('/').last;
      final fileSize = await videoFile.length();

      // Validate file size (500MB limit)
      if (fileSize > 500 * 1024 * 1024) {
        throw Exception('Video file size exceeds 500MB limit');
      }

      // Create FormData for multipart upload
      final formData = FormData.fromMap({
        'video': await MultipartFile.fromFile(
          videoFile.path,
          filename: fileName,
        ),
      });

      // Upload to backend
      final response = await _dio.post(
        '/videos/upload',
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      // Return the videoUrl from response
      final videoUrl = response.data['videoUrl'] as String?;
      if (videoUrl == null || videoUrl.isEmpty) {
        throw Exception('Server did not return a video URL');
      }

      return videoUrl;
    } on DioException catch (e) {
      if (e.response != null) {
        final errorMsg = e.response?.data['message'] ?? 'Upload failed';
        throw Exception(errorMsg);
      } else {
        throw Exception('Network error: ${e.message}');
      }
    } catch (e) {
      throw Exception('Failed to upload video: $e');
    }
  }

  /// Delete a video from Google Drive (optional cleanup)
  Future<void> deleteVideo(String fileId) async {
    try {
      await _dio.delete('/videos/$fileId');
    } on DioException catch (e) {
      if (e.response != null) {
        final errorMsg = e.response?.data['message'] ?? 'Delete failed';
        throw Exception(errorMsg);
      } else {
        throw Exception('Network error: ${e.message}');
      }
    } catch (e) {
      throw Exception('Failed to delete video: $e');
    }
  }

  Future<VideoPreview> previewExternalLink(String url) async {
    try {
      final response = await _dio.post(
        '/videos/preview',
        data: {'url': url},
      );
      return VideoPreview.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final message = e.response?.data['message'] ?? 'Failed to preview video link';
      throw Exception(message);
    } catch (e) {
      throw Exception('שגיאה בשליפת תצוגה מקדימה: $e');
    }
  }
}

class VideoPreview {
  final String provider;
  final String normalizedUrl;
  final String? providerId;
  final String? title;
  final String? description;
  final int? durationSec;
  final String? thumbnailUrl;
  final String? embedHtml;

  VideoPreview({
    required this.provider,
    required this.normalizedUrl,
    this.providerId,
    this.title,
    this.description,
    this.durationSec,
    this.thumbnailUrl,
    this.embedHtml,
  });

  factory VideoPreview.fromJson(Map<String, dynamic> json) {
    return VideoPreview(
      provider: (json['provider'] as String?) ?? 'other',
      normalizedUrl: json['normalizedUrl'] as String? ?? json['url'] as String? ?? '',
      providerId: json['providerId'] as String?,
      title: json['title'] as String?,
      description: json['description'] as String?,
      durationSec: json['durationSec'] is num ? (json['durationSec'] as num).toInt() : null,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      embedHtml: json['embedHtml'] as String?,
    );
  }

  bool get hasThumbnail => thumbnailUrl != null && thumbnailUrl!.isNotEmpty;
  bool get isYouTube => provider.toLowerCase() == 'youtube';
  bool get isVimeo => provider.toLowerCase() == 'vimeo';
}
