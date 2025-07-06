import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// A utility class for logging throughout the application
class AppLogger {
  factory AppLogger() => _instance;
  AppLogger._();
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
  );

  // مستمعين للرسائل
  static final List<Function(String)> _listeners = [];

  // إضافة وإزالة المستمعين
  static void addListener(Function(String) listener) {
    _listeners.add(listener);
  }

  static void removeListener(Function(String) listener) {
    _listeners.remove(listener);
  }

  static void _notifyListeners(String message) {
    for (final listener in _listeners) {
      try {
        listener(message);
      } catch (e) {
        print('Error notifying listener: $e');
      }
    }
  }

  // Static methods only - no instance methods to avoid confusion
  static void debug(String message) {
    _logger.d(message);
    _writeToLogFile('DEBUG: $message');
    _notifyListeners('DEBUG: $message');
  }

  static void info(String message) {
    _logger.i(message);
    _writeToLogFile('INFO: $message');
    _notifyListeners('INFO: $message');
  }

  static void warning(String message, [dynamic error]) {
    _logger.w(message, error: error);
    final fullMessage = 'WARNING: $message${error != null ? '\nError: $error' : ''}';
    _writeToLogFile(fullMessage);
    _notifyListeners(fullMessage);
  }

  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
    final fullMessage = 'ERROR: $message${error != null ? '\nError: $error' : ''}${stackTrace != null ? '\nStackTrace: $stackTrace' : ''}';
    _writeToErrorLogFile(fullMessage);
    _notifyListeners(fullMessage);
  }

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

  static Future<void> _writeToLogFile(String message) async {
    try {
      final file = await _getLogFile();
      await file.writeAsString('${DateTime.now()}: $message\n', mode: FileMode.append);
    } catch (e) {
      print('Error writing to log file: $e');
    }
  }

  static Future<void> _writeToErrorLogFile(String message) async {
    try {
      final file = await _getErrorLogFile();
      await file.writeAsString('${DateTime.now()}: $message\n', mode: FileMode.append);
    } catch (e) {
      print('Error writing to error log file: $e');
    }
  }

  static Future<File> _getLogFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/app.log');
  }

  static Future<File> _getErrorLogFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/error.log');
  }

  static Future<String> getLogFilePath() async {
    final file = await _getLogFile();
    return file.path;
  }

  static Future<String> getErrorLogFilePath() async {
    final file = await _getErrorLogFile();
    return file.path;
  }

  static Future<String> readLogFile() async {
    try {
      final file = await _getLogFile();
      return await file.readAsString();
    } catch (e) {
      return 'Error reading log file: $e';
    }
  }

  static Future<String> readErrorLogFile() async {
    try {
      final file = await _getErrorLogFile();
      return await file.readAsString();
    } catch (e) {
      return 'Error reading error log file: $e';
    }
  }

  static Future<bool> clearLogFile() async {
    try {
      final file = await _getLogFile();
      await file.writeAsString('');
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> clearErrorLogFile() async {
    try {
      final file = await _getErrorLogFile();
      await file.writeAsString('');
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<void> shareLogFile() async {
    try {
      final file = await _getLogFile();
      // Implement sharing functionality here
      print('Sharing log file: ${file.path}');
    } catch (e) {
      print('Error sharing log file: $e');
    }
  }

  static Future<void> shareErrorLogFile() async {
    try {
      final file = await _getErrorLogFile();
      // Implement sharing functionality here
      AppLogger.info('Sharing error log file: ${file.path}');
    } catch (e) {
      AppLogger.error('Error sharing error log file: $e');
    }
  }
}