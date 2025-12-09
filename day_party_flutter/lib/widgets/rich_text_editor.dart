import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'dart:convert';

/// A rich text editor widget that uses Flutter Quill with Delta format
/// Delta is a JSON-based format that's more efficient for Flutter rendering
class RichTextEditor extends StatefulWidget {
  final String? initialValue; // Delta JSON string or HTML (will be converted)
  final String? hintText;
  final double? height;
  final ValueChanged<String>? onChanged; // Returns Delta JSON string

  const RichTextEditor({
    super.key,
    this.initialValue,
    this.hintText,
    this.height = 300,
    this.onChanged,
  });

  @override
  State<RichTextEditor> createState() => RichTextEditorState();
}

class RichTextEditorState extends State<RichTextEditor> {
  late final QuillController _controller;
  bool _isInitialized = false;
  bool _isSettingInitialValue = false; // Flag to prevent onChanged during initialization

  @override
  void initState() {
    super.initState();
    
    // Initialize controller with empty document
    _controller = QuillController.basic();
    
    // Set up change listener
    _controller.document.changes.listen((event) {
      // Only call onChanged if:
      // 1. We're initialized (not during initial setup)
      // 2. We're not programmatically setting the initial value
      if (widget.onChanged != null && _isInitialized && !_isSettingInitialValue) {
        final deltaJson = jsonEncode(_controller.document.toDelta().toJson());
        widget.onChanged!(deltaJson);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _isInitialized = true;
      // Set initial value after widget tree is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeEditor();
      });
    }
  }

  void _initializeEditor() {
    if (!mounted) return;
    
    // Set initial value if provided
    if (widget.initialValue != null && widget.initialValue!.isNotEmpty) {
      _isSettingInitialValue = true; // Prevent onChanged from firing
      try {
        // Try to parse as Delta JSON first
        final json = jsonDecode(widget.initialValue!) as Map<String, dynamic>;
        final ops = json['ops'] as List<dynamic>?;
        if (ops != null) {
          _controller.document = Document.fromJson(ops);
        }
      } catch (e) {
        // If not valid JSON, try to parse as HTML (for backward compatibility)
        try {
          final htmlDelta = _htmlToDelta(widget.initialValue!);
          final ops = htmlDelta['ops'] as List<dynamic>?;
          if (ops != null) {
            _controller.document = Document.fromJson(ops);
          }
        } catch (e2) {
          // If all else fails, treat as plain text
          _controller.document = Document()..insert(0, widget.initialValue!);
        }
      } finally {
        _isSettingInitialValue = false;
      }
    }
  }

  @override
  void didUpdateWidget(RichTextEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Only update if initialValue changed AND it's different from current content
    // This prevents re-setting the document when onChanged updates the parent's state
    if (widget.initialValue != oldWidget.initialValue &&
        widget.initialValue != null &&
        widget.initialValue!.isNotEmpty) {
      // Check if the new initialValue is different from current document
      final currentDelta = jsonEncode(_controller.document.toDelta().toJson());
      if (currentDelta != widget.initialValue) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _isSettingInitialValue = true; // Prevent onChanged from firing
            try {
              final json = jsonDecode(widget.initialValue!) as Map<String, dynamic>;
              final ops = json['ops'] as List<dynamic>?;
              if (ops != null) {
                _controller.document = Document.fromJson(ops);
              }
            } catch (e) {
              try {
                final htmlDelta = _htmlToDelta(widget.initialValue!);
                final ops = htmlDelta['ops'] as List<dynamic>?;
                if (ops != null) {
                  _controller.document = Document.fromJson(ops);
                }
              } catch (e2) {
                _controller.document = Document()..insert(0, widget.initialValue!);
              }
            } finally {
              _isSettingInitialValue = false;
            }
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Convert HTML to Delta format (simple implementation)
  /// For production, consider using a more robust HTML parser
  Map<String, dynamic> _htmlToDelta(String html) {
    // Remove HTML tags and convert to plain text for now
    // In production, you might want to use a proper HTML parser
    final plainText = html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&');
    
    return {'ops': [{'insert': plainText}]};
  }

  /// Get Delta JSON string
  Future<String> getDeltaJson() async {
    try {
      return jsonEncode(_controller.document.toDelta().toJson());
    } catch (e) {
      debugPrint('Error getting Delta JSON: $e');
      return jsonEncode({'ops': [{'insert': '\n'}]});
    }
  }

  /// Get HTML string (for backward compatibility or export)
  Future<String> getHtml() async {
    try {
      final delta = _controller.document.toDelta();
      return _deltaToHtml(delta);
    } catch (e) {
      debugPrint('Error getting HTML: $e');
      return '';
    }
  }

  /// Convert Delta to HTML (simple implementation)
  String _deltaToHtml(dynamic delta) {
    final buffer = StringBuffer();
    for (final op in delta.toList()) {
      if (op.data is String) {
        final text = op.data as String;
        final attributes = op.attributes ?? {};
        
        if (attributes.containsKey('bold')) {
          buffer.write('<strong>$text</strong>');
        } else if (attributes.containsKey('italic')) {
          buffer.write('<em>$text</em>');
        } else if (attributes.containsKey('underline')) {
          buffer.write('<u>$text</u>');
        } else if (attributes.containsKey('link')) {
          final link = attributes['link'] as String;
          buffer.write('<a href="$link">$text</a>');
        } else if (attributes.containsKey('header')) {
          final level = attributes['header'] as int;
          buffer.write('<h$level>$text</h$level>');
        } else if (attributes.containsKey('list')) {
          final listType = attributes['list'] as String;
          if (listType == 'bullet') {
            buffer.write('<ul><li>$text</li></ul>');
          } else {
            buffer.write('<ol><li>$text</li></ol>');
          }
        } else {
          buffer.write(text);
        }
      } else if (op.data is Map && (op.data as Map)['insert'] == '\n') {
        buffer.write('<br>');
      }
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          // Editor
          Expanded(
            child: QuillEditor.basic(
              configurations: QuillEditorConfigurations(
                controller: _controller,
                placeholder: widget.hintText ?? 'הכנס תוכן...',
                padding: const EdgeInsets.all(16),
                sharedConfigurations: const QuillSharedConfigurations(
                  locale: Locale('he'),
                ),
              ),
            ),
          ),
          // Toolbar at bottom - prevents overlap with selection menu
          Material(
            elevation: 4,
            color: Colors.grey.shade100,
            child: SizedBox(
              height: 48,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: QuillToolbar.simple(
                  configurations: QuillSimpleToolbarConfigurations(
                    controller: _controller,
                    sharedConfigurations: const QuillSharedConfigurations(
                      locale: Locale('he'),
                    ),
                    showBoldButton: true,
                    showItalicButton: true,
                    showUnderLineButton: true,
                    showStrikeThrough: false,
                    showInlineCode: false,
                    showColorButton: false,
                    showBackgroundColorButton: false,
                    showClearFormat: true,
                    showAlignmentButtons: false,
                    showLeftAlignment: false,
                    showCenterAlignment: false,
                    showRightAlignment: false,
                    showJustifyAlignment: false,
                    showHeaderStyle: false,
                    showListNumbers: true,
                    showListBullets: true,
                    showListCheck: false,
                    showCodeBlock: false,
                    showQuote: false,
                    showIndent: false,
                    showLink: true,
                    showUndo: true,
                    showRedo: true,
                    showDirection: false,
                    showSearchButton: false,
                    showSubscript: false,
                    showSuperscript: false,
                    showFontFamily: false,
                    showFontSize: false,
                    showDividers: true,
                    showSmallButton: false,
                    toolbarIconAlignment: WrapAlignment.start,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
