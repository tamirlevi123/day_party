import 'package:flutter/material.dart';
import '../services/topic_service.dart';
import '../models/thread.dart';
import '../core/logger.dart';

/// Provider for managing memes from the "ממים" topic
class MemesProvider with ChangeNotifier {
  final TopicService _topicService = TopicService();
  
  List<ThreadSummary> _memes = [];
  bool _isLoading = false;
  String? _error;
  String? _memesTopicId;

  List<ThreadSummary> get memes => _memes;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasMemes => _memes.isNotEmpty;

  /// Load memes topic ID and fetch memes
  Future<void> loadMemes() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // First, find the "ממים" topic
      if (_memesTopicId == null) {
        final topics = await _topicService.getTopics();
        final memesTopic = topics.firstWhere(
          (topic) => topic.name == 'ממים',
          orElse: () => throw Exception('ממים topic not found'),
        );
        _memesTopicId = memesTopic.topicId;
      }

      // Load threads from memes topic
      _memes = await _topicService.getTopicThreads(_memesTopicId!);
      
      appLogger.d('Loaded ${_memes.length} memes');
    } catch (e, s) {
      appLogger.e('Error loading memes', error: e, stackTrace: s);
      _error = e.toString();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Get a random meme
  ThreadSummary? getRandomMeme() {
    if (_memes.isEmpty) return null;
    final random = DateTime.now().millisecondsSinceEpoch % _memes.length;
    return _memes[random];
  }

  /// Get a meme deterministically based on an index (for consistent display)
  ThreadSummary? getMemeByIndex(int index) {
    if (_memes.isEmpty) return null;
    return _memes[index % _memes.length];
  }

  /// Check if a topic ID is the memes topic
  bool isMemesTopic(String? topicId) {
    return topicId != null && topicId == _memesTopicId;
  }

  /// Get the memes topic ID (may be null if not loaded yet)
  String? get memesTopicId => _memesTopicId;

  void setState(VoidCallback fn) {
    fn();
    notifyListeners();
  }
}

