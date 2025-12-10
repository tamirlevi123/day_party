import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:logger/logger.dart';

// Conditional import for browser console
import 'browser_console_logger_stub.dart'
    if (dart.library.html) 'browser_console_logger_web.dart';

/// Browser console output for web platform
/// This ensures logs appear in browser DevTools console even when manually opened
class BrowserConsoleOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    if (!kIsWeb) return;
    
    // Output to browser console
    final console = getBrowserConsole();
    if (console == null) return;
    
    for (final line in event.lines) {
      switch (event.level) {
        case Level.trace:
        case Level.debug:
          console.debug(line);
          break;
        case Level.info:
          console.info(line);
          break;
        case Level.warning:
          console.warn(line);
          break;
        case Level.error:
        case Level.fatal:
          console.error(line);
          break;
        case Level.all:
        default:
          console.log(line);
          break;
      }
    }
  }
}

