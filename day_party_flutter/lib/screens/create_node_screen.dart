import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/thread_service.dart';
import '../services/video_service.dart';
import '../widgets/user_profile_action.dart';
import '../widgets/rich_text_editor.dart';

class CreateNodeScreen extends StatefulWidget {
  final String threadId;
  final String? parentNodeId;
  final String? title; // Pre-filled title if replying to a node

  const CreateNodeScreen({
    super.key,
    required this.threadId,
    this.parentNodeId,
    this.title,
  });

  @override
  State<CreateNodeScreen> createState() => _CreateNodeScreenState();
}

class _CreateNodeScreenState extends State<CreateNodeScreen> {
  final _service = ThreadService();
  final _videoService = VideoService();
  final _titleController = TextEditingController();
  final GlobalKey<RichTextEditorState> _contentEditorKey = GlobalKey<RichTextEditorState>();
  String _deltaContent = ''; // Delta JSON string
  bool _isEditorInitialized = false; // Track if editor has been initialized

  File? _selectedVideoFile;
  VideoPreview? _linkPreview;
  String? _selectedRelation; // 'pro', 'against', 'neutral'
  bool _isAnonymous = false;
  bool _isSubmitting = false;
  bool _isUploadingVideo = false;
  String? _parentNodeTitle; // Title of the parent node being replied to
  bool _isLoadingParentNode = false;

  @override
  void initState() {
    super.initState();
    if (widget.title != null) {
      _titleController.text = widget.title!;
    }
    // Fetch parent node title if replying
    if (widget.parentNodeId != null) {
      _loadParentNode();
    }
  }

  /// Extract plain text from Delta JSON for validation
  String _extractPlainTextFromDelta(Map<String, dynamic> deltaJson) {
    try {
      final ops = deltaJson['ops'] as List?;
      if (ops == null) return '';
      
      final buffer = StringBuffer();
      for (final op in ops) {
        if (op is Map && op.containsKey('insert')) {
          final insert = op['insert'];
          if (insert is String) {
            buffer.write(insert);
          }
        }
      }
      return buffer.toString();
    } catch (e) {
      debugPrint('Error extracting text from Delta: $e');
      return '';
    }
  }

  Future<void> _loadParentNode() async {
    if (widget.parentNodeId == null) return;
    
    setState(() {
      _isLoadingParentNode = true;
    });

    try {
      final parentNode = await _service.getNode(widget.parentNodeId!);
      if (mounted) {
        setState(() {
          _parentNodeTitle = parentNode.title;
          _isLoadingParentNode = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingParentNode = false;
        });
        // Silently fail - parent title is nice to have but not critical
        debugPrint('Failed to load parent node: $e');
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
    );

    if (result != null && result.files.single.path != null) {
      final filePath = result.files.single.path!;
      setState(() {
        _selectedVideoFile = File(filePath);
        _linkPreview = null;
      });
    }
  }

  Future<void> _promptLinkVideo() async {
    final controller = TextEditingController(text: _linkPreview?.normalizedUrl ?? '');
    VideoPreview? dialogResult;
    String? error;
    bool isLoading = false;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> fetchPreview() async {
              final rawUrl = controller.text.trim();
              if (rawUrl.isEmpty) {
                setDialogState(() {
                  error = 'אנא הזן כתובת תקינה';
                });
                return;
              }
              setDialogState(() {
                error = null;
                isLoading = true;
              });
              try {
                final preview = await _videoService.previewExternalLink(rawUrl);
                dialogResult = preview;
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              } catch (e) {
                setDialogState(() {
                  error = e.toString();
                });
              } finally {
                setDialogState(() {
                  isLoading = false;
                });
              }
            }

            return AlertDialog(
              title: const Text('קישור לסרטון'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'כתובת YouTube / Vimeo',
                      hintText: 'https://...',
                    ),
                    keyboardType: TextInputType.url,
                    autofocus: true,
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('ביטול'),
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : fetchPreview,
                  child: isLoading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('שמירה'),
                ),
              ],
            );
          },
        );
      },
    );

    if (dialogResult != null && mounted) {
      setState(() {
        _linkPreview = dialogResult;
        _selectedVideoFile = null;
      });
    }
  }

  void _clearMedia() {
    setState(() {
      _selectedVideoFile = null;
      _linkPreview = null;
    });
  }

  Future<void> _submitNode() async {
    // Validation
    if (_titleController.text.trim().length < 3) {
      _showError('כותרת חייבת להיות לפחות 3 תווים');
      return;
    }

    // Get Delta content from editor
    String deltaContent = _deltaContent.trim();
    // Also try to get it directly from editor if available
    if (_contentEditorKey.currentState != null) {
      try {
        final editorContent = await _contentEditorKey.currentState!.getDeltaJson();
        if (editorContent.isNotEmpty) {
          deltaContent = editorContent.trim();
        }
      } catch (e) {
        // Fall back to cached content
        debugPrint('Error getting Delta from editor: $e');
      }
    }
    
    // Ensure deltaContent is always a JSON string (not a parsed object)
    // This handles cases where deltaContent might be a parsed object
    if (deltaContent.isNotEmpty) {
      try {
        // If it's already a string, try to parse and re-encode to ensure it's valid JSON
        final parsed = jsonDecode(deltaContent);
        // Re-encode to ensure it's a proper JSON string
        deltaContent = jsonEncode(parsed);
      } catch (e) {
        // If parsing fails, it might already be a string, try to validate it
        try {
          jsonDecode(deltaContent); // Validate it's valid JSON
        } catch (e2) {
          debugPrint('Invalid Delta JSON format: $e2');
          _showError('שגיאה בפורמט התוכן. אנא נסה שוב.');
          return;
        }
      }
    }
    
    final hasText = deltaContent.isNotEmpty && deltaContent != '{"ops":[{"insert":"\\n"}]}';
    final hasMedia = _selectedVideoFile != null || _linkPreview != null;

    if (!hasText && !hasMedia) {
      _showError('חייב להזין תוכן או לצרף סרטון');
      return;
    }

    // Check plain text length (parse Delta and extract text for validation)
    if (hasText) {
      try {
        final deltaJson = jsonDecode(deltaContent);
        // Handle both formats: {"ops": [...]} or just [...]
        Map<String, dynamic> deltaMap;
        if (deltaJson is Map<String, dynamic>) {
          deltaMap = deltaJson;
        } else if (deltaJson is List) {
          deltaMap = {'ops': deltaJson};
        } else {
          throw FormatException('Invalid Delta format');
        }
        final plainText = _extractPlainTextFromDelta(deltaMap);
        if (plainText.trim().length < 10) {
          _showError('תוכן חייב להיות לפחות 10 תווים');
          return;
        }
      } catch (e) {
        debugPrint('Error validating Delta content: $e');
        _showError('שגיאה בוולידציה של התוכן. אנא נסה שוב.');
        return;
      }
    }

    // If replying, relation is required
    if (widget.parentNodeId != null && _selectedRelation == null) {
      _showError('חייב לבחור יחס: בעד/נגד/ניטרלי');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      Map<String, dynamic>? videoPayload;

      // Upload video first if one is selected
      if (_selectedVideoFile != null) {
        setState(() {
          _isUploadingVideo = true;
        });

        try {
          final uploadedUrl = await _videoService.uploadVideo(_selectedVideoFile!);
          videoPayload = {
            'source': 'upload',
            'url': uploadedUrl,
          };
        } catch (e) {
          if (!mounted) return;
          _showError('שגיאה בהעלאת הסרטון: $e');
          return;
        } finally {
          if (mounted) {
            setState(() {
              _isUploadingVideo = false;
            });
          }
        }
      }

      if (_linkPreview != null) {
        videoPayload = {
          'source': 'external',
          'url': _linkPreview!.normalizedUrl,
          'externalUrl': _linkPreview!.normalizedUrl,
          'provider': _linkPreview!.provider,
          if (_linkPreview!.thumbnailUrl != null) 'thumbnailUrl': _linkPreview!.thumbnailUrl,
          if (_linkPreview!.durationSec != null) 'durationSec': _linkPreview!.durationSec,
          if (_linkPreview!.embedHtml != null) 'embedHtml': _linkPreview!.embedHtml,
          if (_linkPreview!.title != null) 'title': _linkPreview!.title,
          if (_linkPreview!.description != null) 'description': _linkPreview!.description,
        };
      }

      // Create the node with the selected media
      await _service.createNode(
        threadId: widget.threadId,
        parentNodeId: widget.parentNodeId,
        parentRelation: _selectedRelation,
        title: _titleController.text.trim(),
        textContent: hasText ? deltaContent : null,
        textFormat: hasText ? 'delta' : null,
        video: videoPayload,
        isAnonymous: _isAnonymous,
      );

      if (!mounted) return;
      
      Navigator.pop(context, true); // Return success
    } catch (e) {
      if (!mounted) return;
      _showError('שגיאה ביצירת הודעה: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Widget _buildRelationButton({
    required String value,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedRelation == value;
    return OutlinedButton(
      onPressed: () {
        setState(() {
          _selectedRelation = isSelected ? null : value;
        });
      },
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected ? color : null,
        foregroundColor: isSelected ? Colors.white : null,
        side: BorderSide(
          color: isSelected ? color : Colors.grey,
          width: isSelected ? 2 : 1,
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isReply = widget.parentNodeId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isReply ? 'יצירת תגובה' : 'יצירת הודעה'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: const [UserProfileAction()],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  const Text(
                    'כותרת:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      hintText: 'הכנס כותרת...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),

                  const SizedBox(height: 16),

                  // Content
                  const Text(
                    'תוכן:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  RichTextEditor(
                    key: _contentEditorKey,
                    // Only pass initialValue on first build, not on updates
                    initialValue: _isEditorInitialized ? null : (_deltaContent.isEmpty ? null : _deltaContent),
                    hintText: 'הכנס תוכן ההודעה...',
                    height: 300,
                    onChanged: (deltaJson) {
                      // Update content without setState to avoid losing focus
                      // Mark as initialized after first change
                      if (!_isEditorInitialized) {
                        _isEditorInitialized = true;
                      }
                      _deltaContent = deltaJson;
                    },
                  ),

                  const SizedBox(height: 16),

                  _buildMediaSection(),

                  // Relation selector (only shown when replying)
                  if (isReply) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'יחס להודעה:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (_parentNodeTitle != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.message, size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _parentNodeTitle!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_isLoadingParentNode) ...[
                      const SizedBox(height: 4),
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'טוען...',
                              style: TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildRelationButton(
                            value: 'pro',
                            label: 'בעד',
                            icon: Icons.thumb_up,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _buildRelationButton(
                            value: 'against',
                            label: 'נגד',
                            icon: Icons.thumb_down,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _buildRelationButton(
                            value: 'neutral',
                            label: 'ניטרלי',
                            icon: Icons.help_outline,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Anonymous toggle
                  Row(
                    children: [
                      Switch(
                        value: _isAnonymous,
                        onChanged: (value) {
                          setState(() {
                            _isAnonymous = value;
                          });
                        },
                      ),
                      const Text('פרסם באופן אנונימי'),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Submit button (fixed at bottom)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_isSubmitting || _isUploadingVideo) ? null : _submitNode,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: (_isSubmitting || _isUploadingVideo)
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('פרסם'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'מדיה:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isUploadingVideo ? null : _pickVideo,
                icon: _isUploadingVideo
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file),
                label: Text(_isUploadingVideo
                    ? 'מעלה סרטון...'
                    : (_selectedVideoFile != null ? 'שנה סרטון' : 'העלה סרטון')),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _promptLinkVideo,
                icon: const Icon(Icons.link),
                label: Text(_linkPreview != null ? 'ערוך קישור' : 'צרף קישור'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_selectedVideoFile != null && !_isUploadingVideo)
          Card(
            child: ListTile(
              leading: const Icon(Icons.video_file),
              title: Text(
                _selectedVideoFile!.path.split('/').last,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: const Text('הקובץ יועלה לשרת'),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _clearMedia,
              ),
            ),
          )
        else if (_linkPreview != null)
          Card(
            child: ListTile(
              leading: _linkPreview!.hasThumbnail
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        _linkPreview!.thumbnailUrl!,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.link),
                      ),
                    )
                  : const Icon(Icons.link),
              title: Text(
                _linkPreview!.title ?? _linkPreview!.normalizedUrl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                _linkPreview!.provider.toUpperCase(),
                style: const TextStyle(fontSize: 12),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _clearMedia,
              ),
            ),
          )
        else
          const Text(
            'לא נבחרה מדיה',
            style: TextStyle(color: Colors.grey),
          ),
      ],
    );
  }
}

