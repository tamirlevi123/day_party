import 'package:flutter/material.dart';
import '../models/thread.dart';
import '../services/topic_service.dart';

class ThreadProvider with ChangeNotifier {
  final TopicService _topicService = TopicService();
  
  List<ThreadSummary> _threads = [];
  bool _isLoading = false;
  String? _error;

  List<ThreadSummary> get threads => _threads;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadThreads(String topicId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _threads = await _topicService.getTopicThreads(topicId);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

