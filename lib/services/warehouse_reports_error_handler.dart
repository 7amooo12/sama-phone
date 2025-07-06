import 'dart:async';
import 'dart:math';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// Enhanced error handling service for warehouse reports with retry mechanisms
class WarehouseReportsErrorHandler {
  static final WarehouseReportsErrorHandler _instance = WarehouseReportsErrorHandler._internal();
  factory WarehouseReportsErrorHandler() => _instance;
  WarehouseReportsErrorHandler._internal();

  /// Retry configuration
  static const int maxRetries = 3;
  static const Duration baseDelay = Duration(seconds: 2);
  static const double backoffMultiplier = 2.0;

  /// Execute operation with retry mechanism and exponential backoff
  static Future<T> executeWithRetry<T>(
    Future<T> Function() operation,
    String operationName, {
    int maxRetries = WarehouseReportsErrorHandler.maxRetries,
    Duration baseDelay = WarehouseReportsErrorHandler.baseDelay,
    double backoffMultiplier = WarehouseReportsErrorHandler.backoffMultiplier,
    bool Function(dynamic error)? shouldRetry,
  }) async {
    int attempt = 0;
    Duration currentDelay = baseDelay;

    while (attempt < maxRetries) {
      try {
        AppLogger.info('🔄 تنفيذ العملية: $operationName (المحاولة ${attempt + 1}/$maxRetries)');
        final result = await operation();
        
        if (attempt > 0) {
          AppLogger.info('✅ نجحت العملية بعد ${attempt + 1} محاولة: $operationName');
        }
        
        return result;
      } catch (error) {
        attempt++;
        
        AppLogger.warning('⚠️ فشلت المحاولة $attempt لـ $operationName: $error');
        
        // Check if we should retry this error
        if (shouldRetry != null && !shouldRetry(error)) {
          AppLogger.error('❌ خطأ غير قابل للإعادة في $operationName: $error');
          rethrow;
        }
        
        // If this was the last attempt, throw the error
        if (attempt >= maxRetries) {
          AppLogger.error('❌ فشلت جميع المحاولات ($maxRetries) لـ $operationName: $error');
          throw WarehouseReportsException(
            'فشل في تنفيذ $operationName بعد $maxRetries محاولات',
            originalError: error,
            operationName: operationName,
          );
        }
        
        // Wait before retrying with exponential backoff
        AppLogger.info('⏳ انتظار ${currentDelay.inSeconds} ثانية قبل المحاولة التالية...');
        await Future.delayed(currentDelay);
        
        // Increase delay for next attempt
        currentDelay = Duration(
          milliseconds: (currentDelay.inMilliseconds * backoffMultiplier).round(),
        );
      }
    }
    
    // This should never be reached, but just in case
    throw WarehouseReportsException(
      'خطأ غير متوقع في آلية الإعادة لـ $operationName',
      operationName: operationName,
    );
  }

  /// Check if an error is retryable
  static bool isRetryableError(dynamic error) {
    if (error == null) return false;
    
    final errorString = error.toString().toLowerCase();
    
    // Network-related errors that are usually temporary
    final retryablePatterns = [
      'timeout',
      'connection',
      'network',
      'socket',
      'handshake',
      'certificate',
      'dns',
      'host',
      'unreachable',
      'temporary',
      'service unavailable',
      'server error',
      'internal server error',
      'bad gateway',
      'gateway timeout',
      'too many requests',
    ];
    
    for (final pattern in retryablePatterns) {
      if (errorString.contains(pattern)) {
        return true;
      }
    }
    
    return false;
  }

  /// Get user-friendly error message in Arabic
  static String getUserFriendlyMessage(dynamic error, String operationName) {
    if (error == null) {
      return 'حدث خطأ غير معروف في $operationName';
    }
    
    final errorString = error.toString().toLowerCase();
    
    // Network errors
    if (errorString.contains('timeout')) {
      return 'انتهت مهلة الاتصال. يرجى التحقق من اتصال الإنترنت والمحاولة مرة أخرى.';
    }
    
    if (errorString.contains('connection') || errorString.contains('network')) {
      return 'مشكلة في الاتصال بالشبكة. يرجى التحقق من اتصال الإنترنت.';
    }
    
    if (errorString.contains('server') || errorString.contains('service')) {
      return 'مشكلة في الخادم. يرجى المحاولة مرة أخرى بعد قليل.';
    }
    
    if (errorString.contains('permission') || errorString.contains('unauthorized')) {
      return 'ليس لديك صلاحية للوصول إلى هذه البيانات.';
    }
    
    if (errorString.contains('not found') || errorString.contains('404')) {
      return 'البيانات المطلوبة غير موجودة.';
    }
    
    if (errorString.contains('too many requests')) {
      return 'تم تجاوز الحد المسموح من الطلبات. يرجى المحاولة بعد قليل.';
    }
    
    // Database errors
    if (errorString.contains('database') || errorString.contains('sql')) {
      return 'مشكلة في قاعدة البيانات. يرجى المحاولة مرة أخرى.';
    }
    
    // Memory/resource errors
    if (errorString.contains('memory') || errorString.contains('resource')) {
      return 'نفدت موارد النظام. يرجى تقليل حجم البيانات أو المحاولة لاحقاً.';
    }
    
    // Generic error
    return 'حدث خطأ في $operationName. يرجى المحاولة مرة أخرى.';
  }

  /// Get recovery suggestions for different error types
  static List<String> getRecoverySuggestions(dynamic error, String operationName) {
    if (error == null) {
      return ['يرجى المحاولة مرة أخرى', 'تحقق من اتصال الإنترنت'];
    }
    
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('timeout') || errorString.contains('connection')) {
      return [
        'تحقق من اتصال الإنترنت',
        'أعد تشغيل التطبيق',
        'حاول مرة أخرى بعد قليل',
        'تحقق من إعدادات الشبكة',
      ];
    }
    
    if (errorString.contains('server') || errorString.contains('service')) {
      return [
        'حاول مرة أخرى بعد دقائق قليلة',
        'تحقق من حالة الخادم',
        'اتصل بالدعم الفني إذا استمرت المشكلة',
      ];
    }
    
    if (errorString.contains('permission') || errorString.contains('unauthorized')) {
      return [
        'تحقق من صلاحياتك',
        'قم بتسجيل الدخول مرة أخرى',
        'اتصل بالمدير لمنحك الصلاحيات المطلوبة',
      ];
    }
    
    if (errorString.contains('memory') || errorString.contains('resource')) {
      return [
        'قلل من حجم البيانات المطلوبة',
        'أغلق التطبيقات الأخرى',
        'أعد تشغيل الجهاز',
        'حاول في وقت لاحق عندما يكون النظام أقل انشغالاً',
      ];
    }
    
    return [
      'حاول مرة أخرى',
      'أعد تشغيل التطبيق',
      'تحقق من اتصال الإنترنت',
      'اتصل بالدعم الفني إذا استمرت المشكلة',
    ];
  }

  /// Create a detailed error report
  static Map<String, dynamic> createErrorReport(
    dynamic error,
    String operationName,
    Map<String, dynamic>? context,
  ) {
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'operation': operationName,
      'error_type': error.runtimeType.toString(),
      'error_message': error.toString(),
      'user_message': getUserFriendlyMessage(error, operationName),
      'recovery_suggestions': getRecoverySuggestions(error, operationName),
      'is_retryable': isRetryableError(error),
      'context': context ?? {},
    };
  }
}

/// Custom exception for warehouse reports operations
class WarehouseReportsException implements Exception {
  final String message;
  final dynamic originalError;
  final String? operationName;
  final Map<String, dynamic>? context;

  const WarehouseReportsException(
    this.message, {
    this.originalError,
    this.operationName,
    this.context,
  });

  @override
  String toString() {
    if (operationName != null) {
      return 'WarehouseReportsException in $operationName: $message';
    }
    return 'WarehouseReportsException: $message';
  }

  /// Get user-friendly message
  String get userMessage {
    return WarehouseReportsErrorHandler.getUserFriendlyMessage(
      originalError ?? this,
      operationName ?? 'العملية',
    );
  }

  /// Get recovery suggestions
  List<String> get recoverySuggestions {
    return WarehouseReportsErrorHandler.getRecoverySuggestions(
      originalError ?? this,
      operationName ?? 'العملية',
    );
  }

  /// Check if this error is retryable
  bool get isRetryable {
    return WarehouseReportsErrorHandler.isRetryableError(originalError ?? this);
  }
}
