import 'package:flutter/material.dart';
import '../models/topic.dart';
import '../services/topic_service.dart';

class HomeProvider with ChangeNotifier {
  final TopicService _topicService = TopicService();
  
  List<Topic> _topics = [];
  bool _isLoading = false;
  String? _error;

  List<Topic> get topics => _topics;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadTopics() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _topics = await _topicService.getTopics();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

