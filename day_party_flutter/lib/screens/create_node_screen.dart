import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/thread_service.dart';
import '../services/video_service.dart';
import '../widgets/user_profile_action.dart';

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
  final _contentController = TextEditingController();
  
  File? _selectedVideoFile;
  String? _selectedRelation; // 'pro', 'against', 'neutral'
  bool _isAnonymous = false;
  bool _isSubmitting = false;
  bool _isUploadingVideo = false;

  @override
  void initState() {
    super.initState();
    if (widget.title != null) {
      _titleController.text = widget.title!;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
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
      });
    }
  }

  Future<void> _submitNode() async {
    // Validation
    if (_titleController.text.trim().length < 3) {
      _showError('כותרת חייבת להיות לפחות 3 תווים');
      return;
    }

    if (_contentController.text.trim().length < 10) {
      _showError('תוכן חייב להיות לפחות 10 תווים');
      return;
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
      String? videoUrl;

      // Upload video first if one is selected
      if (_selectedVideoFile != null) {
        setState(() {
          _isUploadingVideo = true;
        });

        try {
          videoUrl = await _videoService.uploadVideo(_selectedVideoFile!);
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

      // Create the node with the video URL
      await _service.createNode(
        threadId: widget.threadId,
        parentNodeId: widget.parentNodeId,
        parentRelation: _selectedRelation,
        title: _titleController.text.trim(),
        textContent: _contentController.text.trim(),
        videoUrl: videoUrl,
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
                  TextField(
                    controller: _contentController,
                    decoration: const InputDecoration(
                      hintText: 'הכנס תוכן ההודעה...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 8,
                    minLines: 6,
                  ),

                  const SizedBox(height: 16),

                  // Video picker
                  OutlinedButton.icon(
                    onPressed: _isUploadingVideo ? null : _pickVideo,
                    icon: _isUploadingVideo
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.video_library),
                    label: Text(
                      _isUploadingVideo
                          ? 'מעלה סרטון...'
                          : (_selectedVideoFile != null
                              ? _selectedVideoFile!.path.split('/').last
                              : 'הוסף סרטון'),
                    ),
                  ),

                  if (_selectedVideoFile != null && !_isUploadingVideo) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _selectedVideoFile!.path.split('/').last,
                            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            setState(() {
                              _selectedVideoFile = null;
                            });
                          },
                        ),
                      ],
                    ),
                  ],

                  // Relation selector (only shown when replying)
                  if (isReply) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'יחס להודעה:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
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
}

