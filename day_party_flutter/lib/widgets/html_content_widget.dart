import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';

/// Widget that renders HTML content or plain text
/// Automatically detects if content is HTML and renders accordingly
class HtmlContentWidget extends StatelessWidget {
  final String content;
  final TextStyle? textStyle;
  final TextFormat? format; // If provided, uses this format explicitly

  const HtmlContentWidget({
    super.key,
    required this.content,
    this.textStyle,
    this.format,
  });

  /// Detects if content contains HTML tags
  static bool _isHtml(String content) {
    final htmlRegex = RegExp(r'<[a-z][\s\S]*>', caseSensitive: false);
    return htmlRegex.hasMatch(content.trim());
  }

  @override
  Widget build(BuildContext context) {
    // Determine format: explicit format, or auto-detect
    final useHtml = format == TextFormat.html || 
                   (format == null && _isHtml(content));

    if (useHtml) {
      // Render HTML
      return Html(
        data: content,
        style: {
          'body': Style(
            margin: Margins.zero,
            padding: HtmlPaddings.zero,
            fontSize: textStyle?.fontSize != null 
                ? FontSize(textStyle!.fontSize!)
                : FontSize(14),
            color: textStyle?.color ?? Theme.of(context).textTheme.bodyMedium?.color,
            lineHeight: textStyle?.height != null 
                ? LineHeight(textStyle!.height!)
                : LineHeight(1.5),
          ),
          'p': Style(
            margin: Margins.only(bottom: 8),
          ),
          'a': Style(
            color: Theme.of(context).colorScheme.primary,
            textDecoration: TextDecoration.underline,
          ),
          'img': Style(
            width: Width(double.infinity),
            height: Height.auto(),
          ),
          'ul': Style(
            margin: Margins.only(left: 16, top: 8, bottom: 8),
          ),
          'ol': Style(
            margin: Margins.only(left: 16, top: 8, bottom: 8),
          ),
          'li': Style(
            margin: Margins.only(bottom: 4),
          ),
          'h1': Style(
            fontSize: FontSize(24),
            fontWeight: FontWeight.bold,
            margin: Margins.only(bottom: 12, top: 8),
          ),
          'h2': Style(
            fontSize: FontSize(20),
            fontWeight: FontWeight.bold,
            margin: Margins.only(bottom: 10, top: 8),
          ),
          'h3': Style(
            fontSize: FontSize(18),
            fontWeight: FontWeight.bold,
            margin: Margins.only(bottom: 8, top: 8),
          ),
          'blockquote': Style(
            border: Border(
              left: BorderSide(
                color: Colors.grey.shade300,
                width: 4,
              ),
            ),
            padding: HtmlPaddings.only(left: 16),
            margin: Margins.only(left: 8, top: 8, bottom: 8),
            fontStyle: FontStyle.italic,
          ),
          'code': Style(
            backgroundColor: Colors.grey.shade200,
            padding: HtmlPaddings.symmetric(horizontal: 4, vertical: 2),
            fontFamily: 'monospace',
            fontSize: FontSize(13),
          ),
          'pre': Style(
            backgroundColor: Colors.grey.shade200,
            padding: HtmlPaddings.all(12),
            margin: Margins.only(bottom: 8),
          ),
        },
        onLinkTap: (url, attributes, element) {
          // Handle link clicks
          if (url != null) {
            launchUrl(
              Uri.parse(url),
              mode: LaunchMode.externalApplication,
            ).catchError((e) {
              // Handle error (e.g., invalid URL)
              debugPrint('Error launching URL: $e');
              return false;
            });
          }
        },
      );
    } else {
      // Render plain text
      return Text(
        content,
        style: textStyle ?? const TextStyle(fontSize: 14),
      );
    }
  }
}

/// Text format enum (matches backend)
enum TextFormat {
  plain,
  markdown,
  html,
}

