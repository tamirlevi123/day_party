import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

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

  void _initController() {
    if (_isNetwork) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.urlOrPath));
    } else {
      _controller = VideoPlayerController.file(File(widget.urlOrPath));
    }
    _initializeFuture = _controller!.initialize().then((_) {
      if (mounted) setState(() {});
    });
    _controller!.setLooping(false);
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
          return Container(
            height: height,
            color: Colors.black12,
            alignment: Alignment.center,
            child: const Text('Video unavailable'),
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


