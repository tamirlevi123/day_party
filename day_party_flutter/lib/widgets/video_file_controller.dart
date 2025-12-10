// Conditional import for File-based video controller
// This file provides a stub for web and real implementation for mobile

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:video_player/video_player.dart';

// Conditional import - will use video_file_controller_io.dart on mobile
import 'video_file_controller_stub.dart'
    if (dart.library.io) 'video_file_controller_io.dart';

/// Creates a VideoPlayerController for a local file
/// On web: returns null (files not supported)
/// On mobile: returns VideoPlayerController.file()
VideoPlayerController? createFileVideoController(String path) {
  if (kIsWeb) {
    return null;
  }
  return createFileController(path);
}

