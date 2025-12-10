// Web redirect utility
// Uses conditional imports to safely access web APIs

import 'package:flutter/foundation.dart' show kIsWeb;

// Conditional import - will use web_redirect_web.dart on web, stub on mobile
import 'web_redirect_stub.dart'
    if (dart.library.html) 'web_redirect_web.dart';

/// Redirects to a URL on web platform
/// On web: redirects current window using window.location.href
/// On mobile: does nothing (use url_launcher instead)
Future<void> redirectToUrl(String url) async {
  if (!kIsWeb) {
    return;
  }
  
  // Call the platform-specific implementation
  redirectWeb(url);
}

