import 'package:flutter/material.dart';
import 'dart:convert';
import '../models/thread.dart';
import '../models/node.dart';
import '../services/thread_service.dart';
import '../core/api_client.dart';
import 'video_player_widget.dart';
import 'external_video_card.dart';
import 'zoomable_image_viewer.dart';
import '../core/logger.dart';

/// Widget to display a meme (image/video) from the memes topic
class MemeCard extends StatelessWidget {
  final ThreadSummary memeThread;
  final Node? memeNode; // Optional: if you have the root node already

  const MemeCard({
    super.key,
    required this.memeThread,
    this.memeNode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Meme cards are display-only: no voting, no replies, no navigation
    return Card(
      key: ValueKey('meme_card_${memeThread.threadId}'), // Unique key for each meme card
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primaryContainer.withOpacity(0.3),
              theme.colorScheme.secondaryContainer.withOpacity(0.3),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Meme label
              Row(
                children: [
                  Icon(
                    Icons.emoji_emotions_outlined,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'מם להארת האווירה',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Meme content - display only, no interaction
              if (memeNode != null) 
                _buildMemeContent(context, memeNode!)
              else
                FutureBuilder<ThreadDetailResponse?>(
                  key: ValueKey('meme_future_${memeThread.threadId}'), // Unique key for FutureBuilder
                  future: _loadMemeThread(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        height: 100,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasData && snapshot.data != null) {
                      final rootNode = snapshot.data!.nodes.firstWhere(
                        (n) => n.parentNodeId == null,
                        orElse: () => snapshot.data!.nodes.first,
                      );
                      return _buildMemeContent(context, rootNode);
                    }
                    return const SizedBox.shrink();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemeContent(BuildContext context, Node node) {
    // Check if it has video
    if (node.video != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: node.video!.source == VideoSource.external
            ? ExternalVideoCard(attachment: node.video!)
            : VideoPlayerWidget(
                urlOrPath: node.video!.url ?? '',
                height: 200,
              ),
      );
    }

    // Check if it has legacy video URL
    if (node.legacyVideoUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: VideoPlayerWidget(
          urlOrPath: node.legacyVideoUrl!,
          height: 200,
        ),
      );
    }

    // Check if text content contains image URLs or HTML with images
    if (node.textContent != null) {
      // Try to extract image URL from Delta JSON or HTML
      final imageUrl = _extractImageUrl(node.textContent!, node.textFormat);
      
      if (imageUrl != null) {
        appLogger.d('Displaying image from URL: $imageUrl');
        // Display image directly - make it clickable to open in zoomable viewer
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: GestureDetector(
            onTap: () {
              // Navigate to zoomable image viewer
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ZoomableImageViewer(
                    imageUrl: imageUrl,
                    title: node.title,
                  ),
                ),
              );
            },
            child: Hero(
              tag: imageUrl,
              child: Image.network(
                imageUrl,
                key: ValueKey('meme_image_$imageUrl'), // Unique key for each image
                fit: BoxFit.contain,
                cacheWidth: null, // Let Flutter handle caching naturally
                loadingBuilder: (context, child, loadingProgress) {
                  appLogger.d('Image loading progress: ${loadingProgress?.cumulativeBytesLoaded}/${loadingProgress?.expectedTotalBytes}');
                  if (loadingProgress == null) {
                    appLogger.d('Image loaded successfully');
                    return child;
                  }
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  appLogger.e('Error loading meme image from URL: $imageUrl', error: error, stackTrace: stackTrace);
                  appLogger.e('Error type: ${error.runtimeType}');
                  appLogger.e('Error details: ${error.toString()}');
                  // Don't fall back to HtmlContentWidget - show error instead
                  return Container(
                    height: 200,
                    color: Colors.grey[300],
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image, size: 48, color: Colors.grey[600]),
                          const SizedBox(height: 8),
                          Text(
                            'לא ניתן לטעון את התמונה',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              imageUrl,
                              style: TextStyle(color: Colors.grey[500], fontSize: 10),
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      }
      
      appLogger.d('No image URL extracted, falling back to HtmlContentWidget');
      appLogger.d('Text content preview: ${node.textContent!.substring(0, node.textContent!.length > 200 ? 200 : node.textContent!.length)}...');
      
      // Fallback to HTML widget if no image found
      // But don't show HTML as text - show a placeholder instead
      return Container(
        height: 200,
        color: Colors.grey[200],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image_not_supported, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text(
                'לא ניתן להציג את התמונה',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    // Fallback: show title
    return Text(
      node.title,
      style: Theme.of(context).textTheme.bodyLarge,
    );
  }

  /// Extract image URL from Delta JSON or HTML content
  String? _extractImageUrl(String content, String? format) {
    try {
      String? htmlContent;
      
      // If it's Delta format, parse it to extract HTML
      if (format == 'delta' || format == null) {
        try {
          String contentToParse = content;
          
          // Handle double-encoded JSON strings
          if (content.trim().startsWith('"') && content.trim().endsWith('"')) {
            contentToParse = jsonDecode(content) as String;
          }
          
          final decoded = jsonDecode(contentToParse);
          List<dynamic> ops;
          
          if (decoded is List) {
            ops = decoded;
          } else if (decoded is Map<String, dynamic>) {
            ops = decoded['ops'] as List<dynamic>? ?? [];
          } else {
            appLogger.d('Invalid Delta format: not a list or map with ops');
            return null;
          }
          
          // Extract HTML from Delta ops
          for (final op in ops) {
            if (op is Map && op.containsKey('insert')) {
              final insert = op['insert'];
              if (insert is String && insert.contains('<img')) {
                htmlContent = insert;
                appLogger.d('Found HTML content in Delta: ${htmlContent.substring(0, htmlContent.length > 100 ? 100 : htmlContent.length)}...');
                break;
              }
            }
          }
        } catch (e) {
          appLogger.e('Error parsing Delta JSON for image', error: e);
          return null;
        }
      } else if (format == 'html' || content.contains('<img')) {
        htmlContent = content;
      }
      
      // Extract image URL from HTML using regex
      if (htmlContent != null) {
        // Normalize HTML: remove newlines and extra whitespace for easier parsing
        final normalizedHtml = htmlContent.replaceAll(RegExp(r'\s+'), ' ');
        appLogger.d('Extracting image URL from HTML: ${normalizedHtml.substring(0, normalizedHtml.length > 200 ? 200 : normalizedHtml.length)}...');
        
        // Use regex to find src attribute value, handling both single and double quotes
        // Multi-line regex with dotAll flag to match across newlines
        // Try double quotes first
        final regexDoubleQuote = RegExp(r'<img[^>]*src\s*=\s*"([^"]+)"', caseSensitive: false, dotAll: true);
        var match = regexDoubleQuote.firstMatch(normalizedHtml);
        
        // If not found, try single quotes
        if (match == null) {
          final regexSingleQuote = RegExp(r"<img[^>]*src\s*=\s*'([^']+)'", caseSensitive: false, dotAll: true);
          match = regexSingleQuote.firstMatch(normalizedHtml);
        }
        
        if (match != null && match.groupCount >= 1) {
          var imageUrl = match.group(1);
          if (imageUrl != null && imageUrl.isNotEmpty) {
            appLogger.d('Extracted image URL: $imageUrl');
            
            // If it's already an absolute URL, extract the path and reconstruct with correct base URL
            if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
              // Extract the path from the absolute URL (handles both old imports with absolute URLs
              // and ensures we use the correct base URL for the current device)
              final uri = Uri.tryParse(imageUrl);
              if (uri != null) {
                // Get the path including query parameters if any
                var path = uri.path;
                if (uri.hasQuery) {
                  path += '?${uri.query}';
                }
                // Reconstruct URL using the correct base URL for this device
                final absoluteUrl = _makeAbsoluteUrl(path);
                appLogger.d('Converted absolute URL ($imageUrl) to relative path ($path) and reconstructed: $absoluteUrl');
                return absoluteUrl;
              }
              // Fallback: if URI parsing fails, try to replace known URLs
              appLogger.w('Failed to parse absolute URL, using fallback replacement: $imageUrl');
              imageUrl = imageUrl.replaceAll('http://localhost:3000', 'http://10.0.2.2:3000');
              imageUrl = imageUrl.replaceAll('http://127.0.0.1:3000', 'http://10.0.2.2:3000');
              // Replace Azure VM URL if we're on emulator (though this shouldn't happen)
              if (ApiClient.baseUrl.contains('10.0.2.2')) {
                imageUrl = imageUrl.replaceAll('https://dayparty.work.gd', 'http://10.0.2.2:3000');
              }
              appLogger.d('Using absolute URL (adjusted via fallback): $imageUrl');
              return imageUrl;
            }
            
            // If it's a relative URL, make it absolute
            final absoluteUrl = _makeAbsoluteUrl(imageUrl);
            appLogger.d('Absolute image URL: $absoluteUrl');
            return absoluteUrl;
          }
        }
        
        // Fallback: try without quotes (some HTML might not have quotes)
        final regexNoQuotes = RegExp(r'<img[^>]*src\s*=\s*([^\s>]+)', caseSensitive: false, dotAll: true);
        final matchNoQuotes = regexNoQuotes.firstMatch(normalizedHtml);
        if (matchNoQuotes != null && matchNoQuotes.groupCount >= 1) {
          final imageUrl = matchNoQuotes.group(1);
          if (imageUrl != null && imageUrl.isNotEmpty) {
            appLogger.d('Extracted image URL (no quotes): $imageUrl');
            final absoluteUrl = _makeAbsoluteUrl(imageUrl);
            appLogger.d('Absolute image URL: $absoluteUrl');
            return absoluteUrl;
          }
        }
        
        appLogger.d('Could not extract image URL from HTML');
      } else {
        appLogger.d('No HTML content found to extract image URL from');
      }
    } catch (e, stackTrace) {
      appLogger.e('Error extracting image URL', error: e, stackTrace: stackTrace);
    }
    
    return null;
  }

  /// Convert relative URL to absolute URL
  String _makeAbsoluteUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    
    // Get base URL from API client (includes /api)
    final apiBaseUrl = ApiClient.baseUrl;
    
    // Remove /api suffix since images are served from root, not /api
    String baseUrl = apiBaseUrl;
    if (baseUrl.endsWith('/api')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 4);
    } else if (baseUrl.endsWith('/api/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 5);
    }
    
    // Remove trailing slash from baseUrl and leading slash from url if present
    final cleanBaseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final cleanUrl = url.startsWith('/') ? url : '/$url';
    
    // URL is already encoded from the database, so use it as-is
    // Express static file serving will decode it automatically
    return '$cleanBaseUrl$cleanUrl';
  }

  Future<ThreadDetailResponse?> _loadMemeThread() async {
    try {
      final threadService = ThreadService();
      return await threadService.getThread(memeThread.threadId);
    } catch (e) {
      appLogger.e('Error loading meme thread', error: e);
      return null;
    }
  }

}

