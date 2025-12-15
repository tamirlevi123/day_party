import 'package:flutter/material.dart';
import 'dart:math';
import '../models/thread.dart';
import '../services/topic_service.dart';

class ThreadProvider with ChangeNotifier {
  final TopicService _topicService = TopicService();
  
  List<ThreadSummary> _threads = [];
  bool _isLoading = false;
  String? _error;
  String? _statusFilter = '114'; // Default filter to status 114 (as comma-separated string)
  // Map of position index to meme thread - stores which meme should be shown at each position
  Map<int, ThreadSummary> _memeAssignments = {};

  List<ThreadSummary> get threads => _threads;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get statusFilter => _statusFilter;
  Map<int, ThreadSummary> get memeAssignments => _memeAssignments;

  /// Set status filter and reload threads
  /// statusIDsValue can be null (show all) or a comma-separated string of StatusIDs
  Future<void> setStatusFilter(String topicId, String? statusIDsValue, {List<ThreadSummary>? availableMemes}) async {
    _statusFilter = statusIDsValue;
    await loadThreads(topicId, availableMemes: availableMemes);
  }

  /// Assign memes to positions in the list when threads are loaded
  /// This ensures memes stay consistent when scrolling
  /// Memes appear at list positions 3, 7, 11, ... (every 4th position starting from 3)
  void _assignMemesToPositions(List<ThreadSummary> availableMemes) {
    _memeAssignments.clear();
    if (availableMemes.isEmpty) return;
    
    const memeInterval = 3; // Memes appear after every 3 threads
    final random = Random();
    
    // Calculate positions where memes should appear in the final list
    // Memes appear at positions: 3, 7, 11, 15, ... (every 4th position starting from 3)
    // This corresponds to: (index + 1) % 4 == 0, where index is 3, 7, 11, ...
    int threadIndex = 0;
    int listPosition = 0;
    
    while (threadIndex < _threads.length) {
      // Add threads up to memeInterval
      for (int i = 0; i < memeInterval && threadIndex < _threads.length; i++) {
        listPosition++;
        threadIndex++;
      }
      
      // Add a meme if we haven't run out of threads
      if (threadIndex <= _threads.length) {
        final meme = availableMemes[random.nextInt(availableMemes.length)];
        _memeAssignments[listPosition] = meme;
        listPosition++;
      }
    }
  }

  /// Reassign memes to positions (useful when memes become available after threads are loaded)
  void reassignMemes(List<ThreadSummary> availableMemes) {
    if (_threads.isEmpty) return;
    _assignMemesToPositions(availableMemes);
    notifyListeners();
  }

  Future<void> loadThreads(String topicId, {List<ThreadSummary>? availableMemes}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _threads = await _topicService.getTopicThreads(topicId, statusIDs: _statusFilter);
      _error = null;
      
      // Assign memes to positions if memes are available
      if (availableMemes != null && availableMemes.isNotEmpty) {
        _assignMemesToPositions(availableMemes);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

