import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../services/thread_service.dart';
import '../providers/auth_provider.dart';
import '../widgets/user_profile_action.dart';
import '../widgets/rich_text_editor.dart';
import 'login_screen.dart';

class CreateThreadScreen extends StatefulWidget {
  final String topicId;

  const CreateThreadScreen({
    super.key,
    required this.topicId,
  });

  @override
  State<CreateThreadScreen> createState() => _CreateThreadScreenState();
}

class _CreateThreadScreenState extends State<CreateThreadScreen> {
  final _service = ThreadService();
  final _titleController = TextEditingController();
  final GlobalKey<RichTextEditorState> _descriptionEditorKey = GlobalKey<RichTextEditorState>();
  String _descriptionDelta = ''; // Delta JSON string
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _submitThread() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (!authProvider.isLoggedIn) {
      // Show login prompt
      final shouldLogin = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('נדרשת התחברות'),
          content: const Text('עליך להתחבר כדי ליצור דיון חדש.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ביטול'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('התחבר'),
            ),
          ],
        ),
      );

      if (shouldLogin == true) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
      return;
    }

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() {
        _error = 'כותרת היא שדה חובה';
      });
      return;
    }

    if (title.length > 500) {
      setState(() {
        _error = 'כותרת חייבת להיות עד 500 תווים';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      // Get Delta content from editor
      String description = _descriptionDelta.trim();
      // Also try to get it directly from editor if available
      if (_descriptionEditorKey.currentState != null) {
        try {
          final editorContent = await _descriptionEditorKey.currentState!.getDeltaJson();
          if (editorContent.isNotEmpty && editorContent != '{"ops":[{"insert":"\\n"}]}') {
            description = editorContent.trim();
          }
        } catch (e) {
          // Fall back to cached content
          debugPrint('Error getting Delta from editor: $e');
        }
      }
      
      final response = await _service.createThread(
        topicId: widget.topicId,
        title: title,
        description: description.isEmpty ? null : description,
      );

      if (mounted) {
        Navigator.pop(context, response.threadId);
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        // Token expired or invalid - clear auth state and prompt login
        setState(() {
          _isSubmitting = false;
        });
        
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await authProvider.logout();
        
        if (mounted) {
          final shouldLogin = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('פג תוקף ההתחברות'),
              content: const Text('פג תוקף ההתחברות שלך. אנא התחבר שוב כדי ליצור דיון חדש.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('ביטול'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('התחבר'),
                ),
              ],
            ),
          );

          if (shouldLogin == true && mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          }
        }
      } else {
        final errorMessage = e.response?.data?['message'] ?? e.message ?? 'שגיאה לא ידועה';
        setState(() {
          _error = 'שגיאה ביצירת הדיון: $errorMessage';
          _isSubmitting = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'שגיאה ביצירת הדיון: $e';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('יצירת דיון חדש'),
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
                      hintText: 'הכנס כותרת לדיון...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                    maxLength: 500,
                  ),

                  const SizedBox(height: 16),

                  // Description
                  const Text(
                    'תיאור (אופציונלי):',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  RichTextEditor(
                    key: _descriptionEditorKey,
                    initialValue: _descriptionDelta.isEmpty ? null : _descriptionDelta,
                    hintText: 'הכנס תיאור לדיון...',
                    height: 250,
                    onChanged: (deltaJson) {
                      setState(() {
                        _descriptionDelta = deltaJson;
                      });
                    },
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Submit button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(26),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitThread,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('צור דיון'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

