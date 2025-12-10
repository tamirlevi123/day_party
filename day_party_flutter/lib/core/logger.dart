import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:logger/logger.dart';
import 'browser_console_logger.dart';

/// Global logger instance for the app
/// Use this instead of print() statements
/// On web, logs also appear in browser DevTools console
final appLogger = Logger(
  printer: PrettyPrinter(
    methodCount: 0, // Don't show method calls
    errorMethodCount: 3, // Show method calls for errors
    lineLength: 80,
    colors: true,
    printEmojis: true,
    dateTimeFormat: DateTimeFormat.none,
  ),
  output: kIsWeb 
    ? MultiOutput([
        ConsoleOutput(), // Standard console (for Flutter debug)
        BrowserConsoleOutput(), // Browser console (for manually opened browsers)
      ])
    : ConsoleOutput(),
);

/// Simple logger for production (less verbose)
final productionLogger = Logger(
  printer: SimplePrinter(
    colors: false,
  ),
);

