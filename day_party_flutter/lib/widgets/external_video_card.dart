import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:youtube_player_embed/youtube_player_embed.dart';
import '../models/node.dart';
import '../core/logger.dart';
import 'external_video_iframe_stub.dart'
    if (dart.library.html) 'external_video_iframe_web.dart' as iframe;

class ExternalVideoCard extends StatelessWidget {
  final VideoAttachment attachment;

  const ExternalVideoCard({super.key, required this.attachment});

  /// Extracts the embed URL from embedHtml iframe
  String? _extractEmbedUrl(String? embedHtml) {
    if (embedHtml == null || embedHtml.isEmpty) {
      appLogger.w('🎬 ExternalVideoCard: No embedHtml provided');
      return null;
    }
    
    appLogger.d('🎬 ExternalVideoCard: Extracting embed URL from embedHtml');
    appLogger.d('🎬 ExternalVideoCard: embedHtml length: ${embedHtml.length}');
    appLogger.d('🎬 ExternalVideoCard: embedHtml content: $embedHtml');
    
    // Extract src from iframe: <iframe ... src="URL" ...>
    // Try double quotes first
    final doubleQuoteMatch = RegExp(r'src="([^"]+)"').firstMatch(embedHtml);
    if (doubleQuoteMatch != null) {
      final url = doubleQuoteMatch.group(1);
      appLogger.d('🎬 ExternalVideoCard: Extracted embed URL (double quotes): $url');
      return url;
    }
    // Try single quotes
    final singleQuoteMatch = RegExp(r"src='([^']+)'").firstMatch(embedHtml);
    if (singleQuoteMatch != null) {
      final url = singleQuoteMatch.group(1);
      appLogger.d('🎬 ExternalVideoCard: Extracted embed URL (single quotes): $url');
      return url;
    }
    
    appLogger.e('🎬 ExternalVideoCard: Failed to extract embed URL from embedHtml');
    appLogger.e('🎬 ExternalVideoCard: No src attribute found in iframe');
    return null;
  }

  /// Extracts YouTube video ID from embed URL or uses providerId
  String? _extractYouTubeVideoId(String? embedUrl) {
    // First try providerId if available
    if (attachment.providerId != null && attachment.providerId!.isNotEmpty) {
      appLogger.d('🎬 ExternalVideoCard: Using providerId as video ID: ${attachment.providerId}');
      return attachment.providerId;
    }
    
    // Extract from embed URL: https://www.youtube.com/embed/VIDEO_ID
    if (embedUrl != null && embedUrl.isNotEmpty) {
      final embedMatch = RegExp(r'youtube\.com/embed/([a-zA-Z0-9_-]+)').firstMatch(embedUrl);
      if (embedMatch != null) {
        final videoId = embedMatch.group(1);
        appLogger.d('🎬 ExternalVideoCard: Extracted YouTube video ID from embed URL: $videoId');
        return videoId;
      }
      
      // Also try youtu.be format
      final shortMatch = RegExp(r'youtu\.be/([a-zA-Z0-9_-]+)').firstMatch(embedUrl);
      if (shortMatch != null) {
        final videoId = shortMatch.group(1);
        appLogger.d('🎬 ExternalVideoCard: Extracted YouTube video ID from short URL: $videoId');
        return videoId;
      }
    }
    
    appLogger.w('🎬 ExternalVideoCard: Could not extract YouTube video ID');
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final providerName = attachment.provider?.toUpperCase() ?? 'VIDEO';
    final embedUrl = _extractEmbedUrl(attachment.embedHtml);
    final hasEmbedUrl = embedUrl != null && embedUrl.isNotEmpty;
    final hasThumbnail = attachment.thumbnailUrl != null && attachment.thumbnailUrl!.isNotEmpty;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Show embedded video if embedHtml is available
          if (hasEmbedUrl)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: attachment.provider == 'youtube' && !kIsWeb
                  ? _buildYouTubeEmbed()
                  : kIsWeb
                      ? _buildWebEmbed(embedUrl)
                      : _buildMobileEmbed(embedUrl),
            )
          // Fallback to thumbnail with play button
          else if (hasThumbnail)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    attachment.thumbnailUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: Colors.black12),
                  ),
                  Container(
                    color: Colors.black45,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.play_circle_fill,
                      color: Colors.white,
                      size: 56,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              height: 180,
              color: Colors.black12,
              alignment: Alignment.center,
              child: const Icon(Icons.play_circle_outline, size: 48, color: Colors.black54),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Chip(
                      label: Text(providerName),
                      labelStyle: const TextStyle(color: Colors.white),
                      backgroundColor: theme.colorScheme.primary,
                    ),
                    if (!hasEmbedUrl)
                      TextButton.icon(
                        onPressed: () => _openUrl(context, attachment.url),
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('פתח'),
                      ),
                  ],
                ),
                if (attachment.title != null && attachment.title!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    attachment.title!,
                    style: theme.textTheme.titleMedium,
                  ),
                ],
                if (attachment.description != null && attachment.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    attachment.description!,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds iframe embed for web
  Widget _buildWebEmbed(String embedUrl) {
    return Builder(
      builder: (context) {
        // Use conditional import for web iframe
        if (kIsWeb) {
          return _buildWebIframe(embedUrl);
        }
        return Container(color: Colors.black12);
      },
    );
  }

  /// Web-specific iframe implementation
  Widget _buildWebIframe(String embedUrl) {
    // Use conditional import for iframe on web
    return iframe.buildWebVideoIframe(embedUrl);
  }

  /// Builds YouTube embed using youtube_player_embed package (mobile only)
  Widget _buildYouTubeEmbed() {
    return Builder(
      builder: (context) {
        final embedUrl = _extractEmbedUrl(attachment.embedHtml);
        final videoId = _extractYouTubeVideoId(embedUrl);
        
        if (videoId == null || videoId.isEmpty) {
          appLogger.e('🎬 ExternalVideoCard: Cannot build YouTube embed - no video ID');
          return Container(
            color: Colors.black12,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 8),
                const Text('Video unavailable', style: TextStyle(color: Colors.red)),
                if (attachment.url != null) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _openUrl(context, attachment.url!),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open in browser'),
                  ),
                ],
              ],
            ),
          );
        }
        
        appLogger.d('🎬 ExternalVideoCard: Building YouTube embed with video ID: $videoId');
        
        return YoutubePlayerEmbed(
          key: ValueKey(videoId), // Unique key for the video
          videoId: videoId,
          customVideoTitle: attachment.title,
          autoPlay: false,
          hidenVideoControls: false,
          mute: false,
          enabledShareButton: false,
          hidenChannelImage: true,
          aspectRatio: 16 / 9,
          onVideoEnd: () {
            appLogger.d('🎬 ExternalVideoCard: YouTube video ended');
          },
          onVideoSeek: (currentTime) {
            appLogger.d('🎬 ExternalVideoCard: YouTube video seeked to $currentTime seconds');
          },
          onVideoTimeUpdate: (currentTime) {
            // Don't log every time update to avoid spam
          },
          onVideoStateChange: (state) {
            appLogger.d('🎬 ExternalVideoCard: YouTube video state changed: $state');
          },
        );
      },
    );
  }

  /// Builds WebView embed for mobile (for non-YouTube videos like Vimeo)
  Widget _buildMobileEmbed(String embedUrl) {
    appLogger.d('🎬 ExternalVideoCard: Building mobile embed');
    appLogger.d('🎬 ExternalVideoCard: Original embed URL: $embedUrl');
    
    // Enhance YouTube embed URL with additional parameters for better compatibility
    String enhancedUrl = embedUrl;
    if (embedUrl.contains('youtube.com/embed') || embedUrl.contains('youtu.be')) {
      appLogger.d('🎬 ExternalVideoCard: Detected YouTube URL, enhancing...');
      
      // Parse the URL and clean it up
      final uri = Uri.parse(embedUrl);
      appLogger.d('🎬 ExternalVideoCard: Parsed URI - scheme: ${uri.scheme}, host: ${uri.host}, path: ${uri.path}');
      appLogger.d('🎬 ExternalVideoCard: Original query parameters: ${uri.queryParameters}');
      
      // Remove 'feature=oembed' as it can cause issues in WebView
      final cleanParams = Map<String, String>.from(uri.queryParameters);
      final hadFeature = cleanParams.containsKey('feature');
      cleanParams.remove('feature');
      if (hadFeature) {
        appLogger.d('🎬 ExternalVideoCard: Removed "feature" parameter (was: ${uri.queryParameters['feature']})');
      }
      
      // Add parameters for better WebView compatibility
      final enhancedParams = {
        ...cleanParams,
        'enablejsapi': '1',
        'playsinline': '1',
        'rel': '0', // Don't show related videos
        'modestbranding': '1', // Reduce YouTube branding
      };
      
      appLogger.d('🎬 ExternalVideoCard: Enhanced query parameters: $enhancedParams');
      
      final enhancedUri = uri.replace(queryParameters: enhancedParams);
      enhancedUrl = enhancedUri.toString();
      appLogger.d('🎬 ExternalVideoCard: Enhanced YouTube URL: $enhancedUrl');
    } else {
      appLogger.d('🎬 ExternalVideoCard: Not a YouTube URL, using original URL as-is');
    }
    
    // Create an HTML page that wraps the iframe for better YouTube compatibility
    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
  <meta http-equiv="Content-Security-Policy" content="frame-src https://www.youtube.com https://youtube.com https://player.vimeo.com;">
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }
    html, body {
      width: 100%;
      height: 100%;
      overflow: hidden;
      background-color: #000;
    }
    iframe {
      width: 100%;
      height: 100%;
      border: none;
      position: absolute;
      top: 0;
      left: 0;
    }
  </style>
  <script>
    // Log when page loads
    console.log('HTML page loaded');
    console.log('Enhanced embed URL: $enhancedUrl');
    
    // Log iframe load events
    window.addEventListener('load', function() {
      console.log('Window loaded');
      var iframe = document.querySelector('iframe');
      if (iframe) {
        console.log('Iframe found, src:', iframe.src);
        iframe.addEventListener('load', function() {
          console.log('Iframe loaded successfully');
        });
        iframe.addEventListener('error', function(e) {
          console.error('Iframe error:', e);
        });
      } else {
        console.error('Iframe not found!');
      }
    });
  </script>
</head>
<body>
  <iframe
    id="youtube-iframe"
    src="$enhancedUrl"
    frameborder="0"
    allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
    allowfullscreen
    scrolling="no">
  </iframe>
</body>
</html>
''';

    appLogger.d('🎬 ExternalVideoCard: HTML content length: ${htmlContent.length}');
    appLogger.d('🎬 ExternalVideoCard: HTML content preview (first 200 chars): ${htmlContent.substring(0, htmlContent.length > 200 ? 200 : htmlContent.length)}...');
    appLogger.d('🎬 ExternalVideoCard: Loading HTML with baseUrl: https://www.youtube.com');
    appLogger.d('🎬 ExternalVideoCard: Enhanced embed URL that should be in iframe: $enhancedUrl');
    
    final controller = WebViewController();
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..enableZoom(false)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            appLogger.d('🎬 ExternalVideoCard: WebView navigation started to: $url');
          },
          onPageFinished: (String url) {
            appLogger.d('🎬 ExternalVideoCard: WebView page finished loading: $url');
            // Check iframe state after page loads
            controller.runJavaScript('''
              (function() {
                console.log('Checking iframe state...');
                var iframe = document.getElementById('youtube-iframe');
                if (iframe) {
                  console.log('Iframe found');
                  console.log('Iframe src:', iframe.src);
                  console.log('Iframe contentWindow:', iframe.contentWindow ? 'exists' : 'null');
                  
                  // Try to access iframe content (will fail due to CORS, but we can try)
                  try {
                    var iframeDoc = iframe.contentDocument || iframe.contentWindow.document;
                    console.log('Iframe document accessible:', iframeDoc ? 'yes' : 'no');
                    if (iframeDoc) {
                      console.log('Iframe document URL:', iframeDoc.URL);
                      console.log('Iframe document title:', iframeDoc.title);
                      // Try to find error messages
                      var bodyText = iframeDoc.body ? iframeDoc.body.innerText : 'no body';
                      console.log('Iframe body text (first 200 chars):', bodyText.substring(0, 200));
                      // Look for error elements
                      var errorElements = iframeDoc.querySelectorAll('[class*="error"], [id*="error"], [class*="Error"], [id*="Error"]');
                      console.log('Error elements found:', errorElements.length);
                      for (var i = 0; i < Math.min(errorElements.length, 3); i++) {
                        console.log('Error element ' + i + ':', errorElements[i].textContent.substring(0, 100));
                      }
                    }
                  } catch (e) {
                    console.log('Cannot access iframe content (CORS):', e.message);
                  }
                  
                  // Check iframe load state
                  iframe.addEventListener('load', function() {
                    console.log('Iframe load event fired');
                    // Try to check content after load
                    setTimeout(function() {
                      try {
                        var iframeDoc = iframe.contentDocument || iframe.contentWindow.document;
                        if (iframeDoc && iframeDoc.body) {
                          console.log('After load - Iframe body text:', iframeDoc.body.innerText.substring(0, 300));
                        }
                      } catch (e) {
                        console.log('After load - Cannot access iframe:', e.message);
                      }
                    }, 2000);
                  });
                  
                  iframe.addEventListener('error', function(e) {
                    console.error('Iframe error event:', e);
                  });
                } else {
                  console.error('Iframe not found in DOM!');
                }
              })();
            ''');
          },
          onWebResourceError: (error) {
            // Log errors for debugging
            appLogger.e('🎬 ExternalVideoCard: ========== WebView Error ==========');
            appLogger.e('🎬 ExternalVideoCard: Error description: ${error.description}');
            appLogger.e('🎬 ExternalVideoCard: Error code: ${error.errorCode}');
            appLogger.e('🎬 ExternalVideoCard: Error type: ${error.errorType}');
            appLogger.e('🎬 ExternalVideoCard: Failed URL: ${error.url}');
            appLogger.e('🎬 ExternalVideoCard: Is for main frame: ${error.isForMainFrame}');
            appLogger.e('🎬 ExternalVideoCard: ====================================');
            appLogger.e('🎬 ExternalVideoCard: Possible causes:');
            appLogger.e('🎬 ExternalVideoCard:   1. Video has embedding restrictions');
            appLogger.e('🎬 ExternalVideoCard:   2. Geographic restrictions');
            appLogger.e('🎬 ExternalVideoCard:   3. Network connectivity issues');
            appLogger.e('🎬 ExternalVideoCard:   4. YouTube blocking WebView user agent');
            appLogger.e('🎬 ExternalVideoCard:   5. CORS or security policy issues');
          },
          onNavigationRequest: (NavigationRequest request) {
            // Allow navigation to YouTube embed URLs
            if (request.url.contains('youtube.com') || request.url.contains('youtu.be') || request.url.contains('vimeo.com')) {
              return NavigationDecision.navigate;
            }
            // Block other navigations to keep user in the app
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadHtmlString(htmlContent, baseUrl: 'https://www.youtube.com');

    return WebViewWidget(controller: controller);
  }

  Future<void> _openUrl(BuildContext context, String? url) async {
    final target = url ?? attachment.url;
    if (target == null || target.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('לא ניתן לפתוח את הסרטון'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final success = await launchUrl(Uri.parse(target), mode: LaunchMode.externalApplication);
    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('לא ניתן לפתוח את הקישור'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}


