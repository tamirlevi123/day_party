import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';
import 'dart:convert';

/// Widget that renders Delta JSON content or HTML (for backward compatibility)
/// Uses Flutter Quill's native renderer for Delta format
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

  /// Detects if content is Delta JSON
  static bool _isDeltaJson(String content) {
    try {
      final json = jsonDecode(content);
      return json is Map && json.containsKey('ops');
    } catch (e) {
      return false;
    }
  }

  /// Detects if content contains HTML tags
  static bool _isHtml(String content) {
    final htmlRegex = RegExp(r'<[a-z][\s\S]*>', caseSensitive: false);
    return htmlRegex.hasMatch(content.trim());
  }

  @override
  Widget build(BuildContext context) {
    // Determine format: explicit format, or auto-detect
    final isDelta = format == TextFormat.delta || 
                   (format == null && _isDeltaJson(content));
    final useHtml = format == TextFormat.html || 
                   (format == null && !isDelta && _isHtml(content));

    if (isDelta) {
      // Render Delta JSON using Flutter Quill
      try {
        // Handle case where content might be double-encoded (string containing JSON string)
        String contentToParse = content;
        
        // Check if content is a JSON string (starts with quote)
        if (content.trim().startsWith('"') && content.trim().endsWith('"')) {
          try {
            // Try to decode it once (it's a JSON-encoded string)
            contentToParse = jsonDecode(content) as String;
          } catch (_) {
            // If that fails, use original content
          }
        }
        
        final decoded = jsonDecode(contentToParse);
        
        // Handle both formats: {"ops": [...]} or just [...]
        List<dynamic> ops;
        if (decoded is List) {
          // Content is stored as array directly
          ops = decoded;
        } else if (decoded is Map<String, dynamic>) {
          // Content is stored as object with ops key
          ops = decoded['ops'] as List<dynamic>? ?? [];
        } else {
          throw FormatException('Invalid Delta format: expected array or object with ops');
        }
        
        // Ensure Delta ends with newline (Flutter Quill requirement)
        if (ops.isNotEmpty) {
          final lastOp = ops.last;
          if (lastOp is Map) {
            final lastInsert = lastOp['insert'];
            if (lastInsert is String && !lastInsert.endsWith('\n')) {
              // Add newline to last operation or add a new operation
              if (lastInsert.isEmpty) {
                ops[ops.length - 1] = {'insert': '\n'};
              } else {
                ops.add({'insert': '\n'});
              }
            }
          }
        } else {
          // Empty ops, add a newline
          ops = [{'insert': '\n'}];
        }
        
        // Debug: Log the Delta ops to see what we're working with
        debugPrint('📋 Delta Ops (${ops.length} operations):');
        for (int i = 0; i < ops.length && i < 10; i++) {
          debugPrint('  Op $i: ${ops[i]}');
        }
        if (ops.length > 10) {
          debugPrint('  ... and ${ops.length - 10} more operations');
        }
        
        // Parse Delta and render with clickable links
        // Since Flutter Quill's onLaunchUrl doesn't work reliably in read-only mode,
        // we'll render using RichText with custom link handling
        return Builder(
          builder: (context) => _DeltaRichTextRenderer(
            ops: ops,
            textStyle: textStyle,
          ),
        );
      } catch (e) {
        debugPrint('Error rendering Delta content: $e');
        debugPrint('Content length: ${content.length}');
        debugPrint('Content preview: ${content.substring(0, content.length > 500 ? 500 : content.length)}');
        debugPrint('Content format: ${format?.toString() ?? "auto-detected"}');
        
        // Try to extract readable text from corrupted Delta JSON
        String fallbackText = content;
        try {
          // Try to extract text from malformed JSON by looking for "insert" values
          final insertRegex = RegExp(r'"insert"\s*:\s*"([^"]+)"');
          final matches = insertRegex.allMatches(content);
          if (matches.isNotEmpty) {
            final buffer = StringBuffer();
            for (final match in matches) {
              final text = match.group(1);
              if (text != null && text != '\\n' && text.trim().isNotEmpty) {
                buffer.writeln(text.replaceAll('\\n', ' '));
              }
            }
            final extracted = buffer.toString().trim();
            if (extracted.isNotEmpty) {
              fallbackText = extracted;
            }
          }
        } catch (_) {
          // If extraction fails, use original content
        }
        
        // Fallback to extracted text or original content
        return Text(
          fallbackText,
          style: textStyle ?? const TextStyle(fontSize: 14),
        );
      }
    } else if (useHtml) {
      // For backward compatibility: render HTML as plain text for now
      // In production, you might want to use flutter_html or convert HTML to Delta
      final plainText = content
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .replaceAll('&nbsp;', ' ')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&amp;', '&');
      
      return Text(
        plainText,
        style: textStyle ?? const TextStyle(fontSize: 14),
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


/// Custom renderer for Delta content with clickable links and formatting
class _DeltaRichTextRenderer extends StatelessWidget {
  final List<dynamic> ops;
  final TextStyle? textStyle;

  const _DeltaRichTextRenderer({
    required this.ops,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final widgets = <Widget>[];
    final textSpans = <TextSpan>[];
    String? currentListType; // 'bullet' or 'ordered'
    int orderedListCounter = 0;
    
    for (int i = 0; i < ops.length; i++) {
      final op = ops[i];
      if (op is Map<String, dynamic>) {
        final insert = op['insert'];
        final attributes = op['attributes'] as Map<String, dynamic>?;
        
        if (insert is String) {
          // Check for list attributes
          final listType = attributes?['list'] as String?;
          
          // In Quill Delta, list attribute is on NEWLINES, not text
          // Pattern: text -> newline with list -> text (next item) -> newline with list -> ...
          
          bool isNewListItem = false;
          
          if (insert == '\n' && listType != null) {
            // Newline with list attribute - marks end of current list item
            // The text we've accumulated so far (before this newline) was a list item
            // If we haven't added a prefix yet, we need to add it now (for the first item)
            if (textSpans.isNotEmpty && currentListType == null) {
              // This is the first list item - add prefix to the beginning
              // Counter should be 1 for the first item
              final prefix = listType == 'bullet' 
                  ? '• ' 
                  : '1. ';
              final defaultColor = textStyle?.color ?? Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87;
              final prefixStyle = TextStyle(
                fontSize: textStyle?.fontSize ?? 14,
                color: defaultColor,
              );
              textSpans.insert(0, TextSpan(text: prefix, style: prefixStyle));
              debugPrint('  Op $i: Added prefix to first list item: $prefix');
              // Set counter to 1 for first item, then increment for next item
              if (listType == 'ordered') {
                orderedListCounter = 2; // Next item will be 2
              }
            } else if (currentListType != null) {
              // We're already in a list - increment counter for the next item
              if (listType == 'ordered') {
                orderedListCounter++;
              }
            }
            
            // Set current list type - next text will be part of this list
            currentListType = listType;
            debugPrint('  Op $i: newline with list=$listType, counter now=$orderedListCounter (for next item)');
          } else if (insert == '\n' && listType == null && currentListType != null) {
            // Newline without list attribute while in a list - end the list
            debugPrint('  Op $i: newline without list, ending list');
            currentListType = null;
            orderedListCounter = 0;
          } else if (insert != '\n') {
            // Text content - check if this is start of a new list item
            // Look back: if previous op was a newline with list attribute, this is a new item
            if (i > 0) {
              final prevOp = ops[i - 1];
              if (prevOp is Map<String, dynamic>) {
                final prevInsert = prevOp['insert'];
                final prevAttributes = prevOp['attributes'] as Map<String, dynamic>?;
                final prevListType = prevAttributes?['list'] as String?;
                if (prevInsert == '\n' && prevListType != null) {
                  // Previous was newline with list - this text starts a new list item
                  // The counter was already incremented when we saw the newline,
                  // so we use the current counter value (which is correct for this item)
                  isNewListItem = true;
                  currentListType = prevListType; // Set list type from previous newline
                  debugPrint('  Op $i: NEW LIST ITEM detected, insert="${insert.replaceAll('\n', '\\n')}" listType=$currentListType counter=$orderedListCounter');
                }
              }
            }
          }
          
          // Handle text with potential formatting
          final baseColor = textStyle?.color ?? Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87;
          final defaultStyle = TextStyle(
            fontSize: textStyle?.fontSize ?? 14,
            color: baseColor,
          );
          TextStyle style = textStyle?.copyWith(color: baseColor) ?? defaultStyle;
          
          // Apply formatting attributes
          if (attributes != null) {
            if (attributes.containsKey('bold')) {
              style = style.copyWith(fontWeight: FontWeight.bold);
            }
            if (attributes.containsKey('italic')) {
              style = style.copyWith(fontStyle: FontStyle.italic);
            }
            if (attributes.containsKey('underline')) {
              style = style.copyWith(decoration: TextDecoration.underline);
            }
            if (attributes.containsKey('strike')) {
              style = style.copyWith(decoration: TextDecoration.lineThrough);
            }
            
            // Handle links
            if (attributes.containsKey('link')) {
              final linkUrl = attributes['link'] as String;
              final linkText = insert.trim();
              if (linkText.isNotEmpty) {
                textSpans.add(
                  TextSpan(
                    text: insert,
                    style: style.copyWith(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () async {
                        debugPrint('🔗 Link tapped: $linkUrl');
                        final uri = Uri.tryParse(linkUrl);
                        if (uri != null) {
                          try {
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                              debugPrint('🔗 Successfully launched URL');
                            } else {
                              debugPrint('❌ Cannot launch URL: $linkUrl');
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('לא ניתן לפתוח את הקישור'),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            debugPrint('❌ Error launching URL: $e');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('שגיאה בפתיחת הקישור'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                        }
                      },
                  ),
                );
              }
            } else {
              // Regular text (no link)
              // Add list prefix for new list items (text, not newline)
              if (isNewListItem && insert != '\n') {
                final prefix = currentListType == 'bullet' 
                    ? '• ' 
                    : '${orderedListCounter}. ';
                textSpans.add(TextSpan(text: prefix, style: style));
              }
              textSpans.add(TextSpan(text: insert, style: style));
            }
          } else {
            // No attributes, just plain text
            // Add list prefix for new list items
            if (isNewListItem && insert != '\n') {
              final prefix = currentListType == 'bullet' 
                  ? '• ' 
                  : '${orderedListCounter}. ';
              textSpans.add(TextSpan(text: prefix, style: style));
            }
            textSpans.add(TextSpan(text: insert, style: style));
          }
          
          // If this is a newline without list attribute and we were in a list, end the list
          if (insert == '\n' && listType == null && currentListType != null) {
            if (textSpans.isNotEmpty) {
              final defaultColor = textStyle?.color ?? Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87;
              widgets.add(RichText(
                text: TextSpan(
                  children: textSpans,
                  style: TextStyle(color: defaultColor),
                ),
                textDirection: TextDirection.rtl,
              ));
              textSpans.clear();
            }
            currentListType = null;
            orderedListCounter = 0;
          }
        }
      }
    }
    
    // Flush remaining text
    if (textSpans.isNotEmpty) {
      final defaultColor = textStyle?.color ?? Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87;
      widgets.add(RichText(
        text: TextSpan(
          children: textSpans,
          style: TextStyle(color: defaultColor), // Ensure parent has color
        ),
        textDirection: TextDirection.rtl,
      ));
    }
    
    // Return single RichText if only one widget, otherwise Column
    if (widgets.length == 1) {
      return widgets.first;
    } else if (widgets.isEmpty) {
      return const SizedBox.shrink();
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widgets,
      );
    }
  }
}

/// Text format enum (matches backend)
enum TextFormat {
  plain,
  markdown,
  html,
  delta,
}
