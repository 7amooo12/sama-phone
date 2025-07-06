import 'dart:io';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

class AppLogger {
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

  static final Logger _fileLogger = Logger(
    printer: SimplePrinter(colors: false, printTime: true),
  );

  static File? _logFile;
  static File? _errorLogFile;

  static Future<void> init() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      _logFile = File('${directory.path}/app_logs.txt');
      _errorLogFile = File('${directory.path}/error_logs.txt');
      
      // Create files if they don't exist
      if (!await _logFile!.exists()) {
        await _logFile!.create(recursive: true);
      }
      if (!await _errorLogFile!.exists()) {
        await _errorLogFile!.create(recursive: true);
      }
    } catch (e) {
      print('Failed to initialize logger: $e');
    }
  }

  static void info(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(message, error: error, stackTrace: stackTrace);
    _writeToFile('INFO', message, error);
  }

  static void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.d(message, error: error, stackTrace: stackTrace);
    _writeToFile('DEBUG', message, error);
  }

  static void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(message, error: error, stackTrace: stackTrace);
    _writeToFile('WARNING', message, error);
  }

  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
    _writeToFile('ERROR', message, error);
    _writeToErrorFile(message, error, stackTrace);
  }

  static void _writeToFile(String level, String message, [dynamic error]) {
    if (_logFile == null) return;
    
    try {
      final timestamp = DateTime.now().toIso8601String();
      final logEntry = '[$timestamp] [$level] $message${error != null ? ' - Error: $error' : ''}\n';
      _logFile!.writeAsStringSync(logEntry, mode: FileMode.append);
    } catch (e) {
      print('Failed to write to log file: $e');
    }
  }

  static void _writeToErrorFile(String message, [dynamic error, StackTrace? stackTrace]) {
    if (_errorLogFile == null) return;
    
    try {
      final timestamp = DateTime.now().toIso8601String();
      final logEntry = '[$timestamp] [ERROR] $message${error != null ? ' - Error: $error' : ''}${stackTrace != null ? '\nStackTrace: $stackTrace' : ''}\n\n';
      _errorLogFile!.writeAsStringSync(logEntry, mode: FileMode.append);
    } catch (e) {
      print('Failed to write to error log file: $e');
    }
  }

  static Future<String> getLogFilePath() async {
    if (_logFile == null) await init();
    return _logFile?.path ?? '';
  }

  static Future<String> getErrorLogFilePath() async {
    if (_errorLogFile == null) await init();
    return _errorLogFile?.path ?? '';
  }

  static Future<String> getLogs() async {
    if (_logFile == null) await init();
    try {
      if (_logFile != null && await _logFile!.exists()) {
        return await _logFile!.readAsString();
      }
    } catch (e) {
      error('Failed to read log file', e);
    }
    return '';
  }

  static Future<String> getErrorLogs() async {
    if (_errorLogFile == null) await init();
    try {
      if (_errorLogFile != null && await _errorLogFile!.exists()) {
        return await _errorLogFile!.readAsString();
      }
    } catch (e) {
      error('Failed to read error log file', e);
    }
    return '';
  }

  static Future<bool> clearLogFile() async {
    try {
      if (_logFile != null && await _logFile!.exists()) {
        await _logFile!.writeAsString('');
        return true;
      }
    } catch (e) {
      error('Failed to clear log file', e);
    }
    return false;
  }

  static Future<bool> clearErrorLogFile() async {
    try {
      if (_errorLogFile != null && await _errorLogFile!.exists()) {
        await _errorLogFile!.writeAsString('');
        return true;
      }
    } catch (e) {
      error('Failed to clear error log file', e);
    }
    return false;
  }
}
