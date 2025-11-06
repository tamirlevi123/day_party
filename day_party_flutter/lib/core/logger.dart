import 'package:logger/logger.dart';

/// Global logger instance for the app
/// Use this instead of print() statements
final appLogger = Logger(
  printer: PrettyPrinter(
    methodCount: 0, // Don't show method calls
    errorMethodCount: 3, // Show method calls for errors
    lineLength: 80,
    colors: true,
    printEmojis: true,
    dateTimeFormat: DateTimeFormat.none,
  ),
);

/// Simple logger for production (less verbose)
final productionLogger = Logger(
  printer: SimplePrinter(
    colors: false,
  ),
);

