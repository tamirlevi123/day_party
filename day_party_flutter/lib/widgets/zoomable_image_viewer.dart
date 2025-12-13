import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import '../core/logger.dart';

/// Full-screen zoomable image viewer
class ZoomableImageViewer extends StatelessWidget {
  final String imageUrl;
  final String? title;

  const ZoomableImageViewer({
    super.key,
    required this.imageUrl,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: title != null
            ? Text(
                title!,
                style: const TextStyle(color: Colors.white),
              )
            : null,
      ),
      body: PhotoView(
        imageProvider: NetworkImage(imageUrl),
        loadingBuilder: (context, event) {
          if (event == null) {
            return const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            );
          }
          final value = event.cumulativeBytesLoaded / (event.expectedTotalBytes ?? 1);
          return Center(
            child: CircularProgressIndicator(
              value: value,
              color: Colors.white,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          appLogger.e('Error loading image in zoomable viewer', error: error, stackTrace: stackTrace);
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.broken_image,
                  color: Colors.white,
                  size: 64,
                ),
                SizedBox(height: 16),
                Text(
                  'לא ניתן לטעון את התמונה',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          );
        },
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 4,
        initialScale: PhotoViewComputedScale.contained,
        heroAttributes: PhotoViewHeroAttributes(tag: imageUrl),
      ),
    );
  }
}
