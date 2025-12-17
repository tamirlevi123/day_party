import 'package:flutter/material.dart';
import 'dart:math';
import '../models/thread.dart';
import '../services/topic_service.dart';
import '../core/logger.dart';

class ThreadProvider with ChangeNotifier {
  final TopicService _topicService = TopicService();
  
  List<ThreadSummary> _threads = [];
  bool _isLoading = false;
  String? _error;
  // Knesset status filter (comma-separated StatusIDs). Must only be used for the Knesset bills topic.
  String? _statusFilter;
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
      appLogger.d('🔍 ThreadProvider: Loading threads for topic $topicId with statusFilter: $_statusFilter');
      _threads = await _topicService.getTopicThreads(topicId, statusIDs: _statusFilter);
      _error = null;
      
      appLogger.d('🔍 ThreadProvider: Loaded ${_threads.length} threads');
      if (_threads.isNotEmpty) {
        appLogger.d('🔍 ThreadProvider: First 3 thread IDs: ${_threads.take(3).map((t) => t.threadId).join(", ")}');
        appLogger.d('🔍 ThreadProvider: First 3 thread titles: ${_threads.take(3).map((t) => t.title).join(" | ")}');
        
        // Check metadata presence
        final threadsWithMetadata = _threads.where((t) => t.billStatusID != null).length;
        final threadsWithoutMetadata = _threads.length - threadsWithMetadata;
        appLogger.d('🔍 ThreadProvider: Threads with billStatusID: $threadsWithMetadata, without: $threadsWithoutMetadata');
        
        if (_threads.any((t) => t.billStatusID != null)) {
          final statusIds = _threads.where((t) => t.billStatusID != null).map((t) => t.billStatusID).toSet();
          appLogger.d('🔍 ThreadProvider: Unique billStatusIDs in threads: ${statusIds.join(", ")}');
        } else {
          appLogger.w('⚠️ ThreadProvider: WARNING - No threads have billStatusID! Filter may not be working.');
          // Show sample of first thread's metadata structure
          if (_threads.isNotEmpty) {
            final firstThread = _threads.first;
            appLogger.d('🔍 ThreadProvider: Sample thread metadata - billId: ${firstThread.billId}, billStatusID: ${firstThread.billStatusID}');
          }
        }
      }
      
      // Assign memes to positions if memes are available
      if (availableMemes != null && availableMemes.isNotEmpty) {
        _assignMemesToPositions(availableMemes);
      }
    } catch (e) {
      _error = e.toString();
      appLogger.e('❌ ThreadProvider: Error loading threads', error: e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

