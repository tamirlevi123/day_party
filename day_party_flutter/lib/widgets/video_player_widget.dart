import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:dio/dio.dart';
import '../core/logger.dart';
import '../core/api_client.dart';
import 'video_file_controller.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String urlOrPath;
  final double? height;
  final BoxFit fit;

  const VideoPlayerWidget({super.key, required this.urlOrPath, this.height, this.fit = BoxFit.contain});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  Future<void>? _initializeFuture;

  bool get _isNetwork => widget.urlOrPath.startsWith('http://') || widget.urlOrPath.startsWith('https://');

  @override
  void initState() {
    super.initState();
    _initController();
  }

  @override
  void didUpdateWidget(covariant VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.urlOrPath != widget.urlOrPath) {
      _disposeController();
      _initController();
    }
  }

  /// Checks if a URL is a Google Drive URL
  /// 
  /// Note: This widget is only used for user-uploaded videos (source: 'upload'),
  /// which are stored in Google Drive. External videos (YouTube, etc.) use
  /// ExternalVideoCard instead and don't need proxying.
  bool _isGoogleDriveUrl(String url) {
    return url.contains('drive.google.com') || 
           url.contains('docs.google.com') ||
           url.contains('googledrive.com');
  }

  Future<void> _initController() async {
    appLogger.d('🎥 VideoPlayerWidget: Initializing with urlOrPath: "${widget.urlOrPath}"');
    appLogger.d('🎥 VideoPlayerWidget: Is web: $kIsWeb, Is network: $_isNetwork');
    
    // Check for empty URL
    if (widget.urlOrPath.isEmpty) {
      appLogger.w('🎥 VideoPlayerWidget: Empty URL provided - cannot load video');
      _controller = null;
      _initializeFuture = Future.value();
      return;
    }
    
    if (_isNetwork) {
      String videoUrl = widget.urlOrPath;
      
      // ARCHITECTURE NOTE:
      // This widget handles user-uploaded videos (source: 'upload') which are stored
      // in Google Drive. On web, Google Drive URLs cannot be played directly by HTML5
      // video players due to CORS and authentication restrictions. Therefore, we proxy
      // them through our backend endpoint (/api/videos/proxy) which:
      // 1. Uses Google Drive API to fetch the video stream
      // 2. Streams the video to the browser with proper headers
      //
      // External videos (YouTube, Vimeo, etc.) are handled by ExternalVideoCard
      // and don't need proxying since they're already hosted and playable.
      if (kIsWeb && _isGoogleDriveUrl(widget.urlOrPath)) {
        appLogger.d('🎥 VideoPlayerWidget: Google Drive URL detected on web - using backend proxy');
        try {
          // Construct proxy URL: /api/videos/proxy?url=GOOGLE_DRIVE_URL
          final proxyUrl = '${ApiClient.baseUrl}/videos/proxy?url=${Uri.encodeComponent(widget.urlOrPath)}';
          
          // Pre-check: Verify the proxy endpoint returns a video stream, not an error
          appLogger.d('🎥 VideoPlayerWidget: Verifying proxy endpoint...');
          appLogger.d('🎥 VideoPlayerWidget: Proxy URL: $proxyUrl');
          try {
            final dio = ApiClient.instance;
            // Use HEAD request to check if endpoint is accessible and returns video
            final response = await dio.head(
              '/videos/proxy',
              queryParameters: {'url': widget.urlOrPath},
              options: Options(
                followRedirects: false,
                validateStatus: (status) => true, // Don't throw on any status
                receiveTimeout: const Duration(seconds: 5),
              ),
            );
            
            final contentType = response.headers.value('content-type') ?? '';
            final statusCode = response.statusCode ?? 0;
            appLogger.d('🎥 VideoPlayerWidget: Proxy HEAD response status: $statusCode');
            appLogger.d('🎥 VideoPlayerWidget: Proxy HEAD Content-Type: $contentType');
            
            if (statusCode >= 400) {
              // Proxy returned an error - don't try to play it
              appLogger.e('🎥 VideoPlayerWidget: Proxy endpoint returned error: $statusCode');
              appLogger.e('🎥 VideoPlayerWidget: This usually means:');
              appLogger.e('🎥 VideoPlayerWidget:   1. Backend server is not running');
              appLogger.e('🎥 VideoPlayerWidget:   2. Google Drive API credentials are not configured');
              appLogger.e('🎥 VideoPlayerWidget:   3. The file is not accessible via Google Drive API');
              _controller = null;
              _initializeFuture = Future.value();
              return;
            }
            
            if (!contentType.startsWith('video/')) {
              appLogger.w('🎥 VideoPlayerWidget: Proxy endpoint returned non-video Content-Type: $contentType');
              appLogger.w('🎥 VideoPlayerWidget: This might indicate the backend is returning an error JSON instead of video');
            }
            
            videoUrl = proxyUrl;
            appLogger.d('🎥 VideoPlayerWidget: Proxy endpoint verified, using URL: $proxyUrl');
          } catch (e, stackTrace) {
            appLogger.e('🎥 VideoPlayerWidget: Failed to verify proxy endpoint', error: e);
            appLogger.e('🎥 VideoPlayerWidget: Exception type: ${e.runtimeType}');
            appLogger.e('🎥 VideoPlayerWidget: Stack trace: $stackTrace');
            if (e is DioException) {
              appLogger.e('🎥 VideoPlayerWidget: DioException status: ${e.response?.statusCode}');
              appLogger.e('🎥 VideoPlayerWidget: DioException message: ${e.message}');
              appLogger.e('🎥 VideoPlayerWidget: DioException type: ${e.type}');
              if (e.response?.data != null) {
                appLogger.e('🎥 VideoPlayerWidget: Response data: ${e.response?.data}');
              }
              // If verification fails with an error response, don't try to play
              if (e.response != null && e.response!.statusCode != null && e.response!.statusCode! >= 400) {
                appLogger.e('🎥 VideoPlayerWidget: Proxy endpoint returned error - skipping video initialization');
                _controller = null;
                _initializeFuture = Future.value();
                return;
              }
            }
            // Continue anyway - might be a network issue, let the video player handle it
            videoUrl = proxyUrl;
            appLogger.w('🎥 VideoPlayerWidget: Using proxy URL despite verification failure: $proxyUrl');
          }
        } catch (e) {
          appLogger.e('🎥 VideoPlayerWidget: Failed to construct proxy URL', error: e);
          _controller = null;
          _initializeFuture = Future.value();
          return;
        }
      }
      
      // Network URL - works on all platforms
      // On web, Google Drive URLs are proxied through backend
      appLogger.d('🎥 VideoPlayerWidget: Creating network video controller for: $videoUrl');
      try {
        final uri = Uri.parse(videoUrl);
        appLogger.d('🎥 VideoPlayerWidget: Parsed URI: $uri');
        _controller = VideoPlayerController.networkUrl(uri);
      } catch (e) {
        appLogger.e('🎥 VideoPlayerWidget: Failed to parse URL', error: e);
        _controller = null;
        _initializeFuture = Future.value();
        return;
      }
    } else if (kIsWeb) {
      // On web, local file paths are not supported
      appLogger.w('🎥 VideoPlayerWidget: Local file path not supported on web: ${widget.urlOrPath}');
      _controller = null;
      _initializeFuture = Future.value();
      return;
    } else {
      // Local file - only on mobile platforms
      appLogger.d('🎥 VideoPlayerWidget: Creating file video controller for: ${widget.urlOrPath}');
      final fileController = createFileVideoController(widget.urlOrPath);
      if (fileController == null) {
        appLogger.w('🎥 VideoPlayerWidget: File controller creation returned null');
        _controller = null;
        _initializeFuture = Future.value();
        return;
      }
      _controller = fileController;
    }
    
    if (_controller != null) {
      appLogger.d('🎥 VideoPlayerWidget: Initializing video controller...');
      _initializeFuture = _controller!.initialize().then((_) {
        appLogger.d('🎥 VideoPlayerWidget: Video initialized successfully');
        appLogger.d('🎥 VideoPlayerWidget: Video duration: ${_controller!.value.duration}');
        appLogger.d('🎥 VideoPlayerWidget: Video size: ${_controller!.value.size}');
        if (mounted) setState(() {});
      }).catchError((error) {
        appLogger.e('🎥 VideoPlayerWidget: Failed to initialize video player', error: error);
        appLogger.e('🎥 VideoPlayerWidget: URL was: ${widget.urlOrPath}');
        if (mounted) setState(() {});
      });
      _controller!.setLooping(false);
    } else {
      appLogger.w('🎥 VideoPlayerWidget: Controller is null - video unavailable');
      _initializeFuture = Future.value();
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  void _disposeController() {
    _controller?.dispose();
    _controller = null;
    _initializeFuture = null;
  }

  @override
  Widget build(BuildContext context) {
    final height = widget.height ?? 200;
    return FutureBuilder<void>(
      future: _initializeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: height,
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        if (_controller == null || !_controller!.value.isInitialized) {
          // Log why video is unavailable
          if (_controller == null) {
            appLogger.w('🎥 VideoPlayerWidget: Controller is null - URL: "${widget.urlOrPath}"');
          } else if (!_controller!.value.isInitialized) {
            appLogger.w('🎥 VideoPlayerWidget: Controller not initialized - URL: "${widget.urlOrPath}"');
            if (_controller!.value.hasError) {
              appLogger.e('🎥 VideoPlayerWidget: Controller has error: ${_controller!.value.errorDescription}');
            }
          }
          
          return Container(
            height: height,
            color: Colors.black12,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Video unavailable'),
                if (widget.urlOrPath.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'URL: ${widget.urlOrPath.length > 50 ? "${widget.urlOrPath.substring(0, 50)}..." : widget.urlOrPath}',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          );
        }
        final aspectRatio = _controller!.value.aspectRatio == 0 ? 16 / 9 : _controller!.value.aspectRatio;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: aspectRatio,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  FittedBox(
                    fit: widget.fit,
                    child: SizedBox(
                      width: _controller!.value.size.width,
                      height: _controller!.value.size.height,
                      child: VideoPlayer(_controller!),
                    ),
                  ),
                  _PlayPauseOverlay(controller: _controller!),
                ],
              ),
            ),
            _VideoScrubber(controller: _controller!),
          ],
        );
      },
    );
  }
}

class _PlayPauseOverlay extends StatelessWidget {
  final VideoPlayerController controller;
  const _PlayPauseOverlay({required this.controller});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (controller.value.isPlaying) {
          controller.pause();
        } else {
          controller.play();
        }
      },
      child: AnimatedOpacity(
        opacity: controller.value.isPlaying ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          color: Colors.black26,
          child: const Icon(Icons.play_arrow, color: Colors.white, size: 64),
        ),
      ),
    );
  }
}

class _VideoScrubber extends StatefulWidget {
  final VideoPlayerController controller;
  const _VideoScrubber({required this.controller});

  @override
  State<_VideoScrubber> createState() => _VideoScrubberState();
}

class _VideoScrubberState extends State<_VideoScrubber> {
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTick);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() {
    if (!mounted) return;
    setState(() {
      _position = widget.controller.value.position;
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.controller.value.duration;
    // Force LTR direction for video controls (slider should go left to right)
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        children: [
          IconButton(
            icon: Icon(widget.controller.value.isPlaying ? Icons.pause : Icons.play_arrow),
            onPressed: () {
              if (widget.controller.value.isPlaying) {
                widget.controller.pause();
              } else {
                widget.controller.play();
              }
            },
          ),
          Expanded(
            child: Slider(
              value: _position.inMilliseconds.clamp(0, total.inMilliseconds).toDouble(),
              min: 0,
              max: total.inMilliseconds.toDouble().clamp(1, double.infinity),
              onChanged: (v) {
                widget.controller.seekTo(Duration(milliseconds: v.toInt()));
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(_fmt(_position)),
          ),
        ],
      ),
    );
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }
}


