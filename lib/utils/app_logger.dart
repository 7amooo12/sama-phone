import 'package:logger/logger.dart';

/// A utility class for logging throughout the application
class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
  );

  // Static methods only - no instance methods to avoid confusion
  static void debug(String message) => _logger.d(message);
  static void info(String message) => _logger.i(message);
  static void warning(String message) => _logger.w(message);
  static void error(String message, [dynamic error, StackTrace? stackTrace]) => 
    _logger.e(message, error: error, stackTrace: stackTrace);
  static void verbose(String message) => _logger.v(message);

  // Shorthand methods
  static void d(String message) => debug(message);
  static void i(String message) => info(message);
  static void w(String message) => warning(message);
  static void e(String message, [dynamic error, StackTrace? stackTrace]) => 
    error(message, error, stackTrace);
  static void v(String message) => verbose(message);

  // Static instance for legacy support
  static final AppLogger _instance = AppLogger._();
  factory AppLogger() => _instance;
  AppLogger._();
} 