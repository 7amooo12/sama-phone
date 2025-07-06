import 'dart:async';
import 'dart:collection';
import 'dart:isolate';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// خدمة تحسين الأداء - تحسين معالجة الملفات الكبيرة وضمان أوقات معالجة أقل من 30 ثانية
class PerformanceOptimizer {
  static const int _maxProcessingTimeSeconds = 30;
  static const int _batchSize = 100;
  static const int _maxConcurrentOperations = 4;
  
  // ذاكرة التخزين المؤقت للنتائج
  static final Map<String, CachedResult> _cache = {};
  static const Duration _cacheExpiration = Duration(minutes: 15);
  
  /// معالجة البيانات بشكل محسن مع ضمان الوقت المحدد
  static Future<T> processWithTimeLimit<T>({
    required Future<T> Function() operation,
    required String operationName,
    Duration? timeLimit,
  }) async {
    final limit = timeLimit ?? const Duration(seconds: _maxProcessingTimeSeconds);
    final stopwatch = Stopwatch()..start();
    
    AppLogger.info('🚀 بدء العملية المحسنة: $operationName (الحد الأقصى: ${limit.inSeconds}s)');
    
    try {
      final result = await operation().timeout(limit);
      stopwatch.stop();
      
      AppLogger.info('✅ اكتملت العملية: $operationName في ${stopwatch.elapsedMilliseconds}ms');
      return result;
      
    } on TimeoutException {
      stopwatch.stop();
      AppLogger.error('⏰ انتهت مهلة العملية: $operationName بعد ${stopwatch.elapsedMilliseconds}ms');
      throw PerformanceException(
        'انتهت مهلة العملية "$operationName" بعد ${limit.inSeconds} ثانية',
        PerformanceErrorType.timeout,
      );
    } catch (e) {
      stopwatch.stop();
      AppLogger.error('❌ فشلت العملية: $operationName بعد ${stopwatch.elapsedMilliseconds}ms - $e');
      rethrow;
    }
  }
  
  /// معالجة البيانات على دفعات لتحسين الأداء
  static Future<List<T>> processBatches<T, R>({
    required List<R> data,
    required Future<T> Function(R item) processor,
    required String operationName,
    int? batchSize,
    int? maxConcurrent,
  }) async {
    final effectiveBatchSize = batchSize ?? _batchSize;
    final effectiveMaxConcurrent = maxConcurrent ?? _maxConcurrentOperations;
    
    AppLogger.info('📦 معالجة ${data.length} عنصر على دفعات (حجم الدفعة: $effectiveBatchSize، متوازي: $effectiveMaxConcurrent)');
    
    final results = <T>[];
    final semaphore = Semaphore(effectiveMaxConcurrent);
    
    for (int i = 0; i < data.length; i += effectiveBatchSize) {
      final batch = data.skip(i).take(effectiveBatchSize).toList();
      
      await semaphore.acquire();
      
      try {
        final batchResults = await Future.wait(
          batch.map((item) => processor(item)),
        );
        results.addAll(batchResults);
        
        AppLogger.info('✅ تمت معالجة الدفعة ${(i / effectiveBatchSize).floor() + 1}/${(data.length / effectiveBatchSize).ceil()}');
        
      } finally {
        semaphore.release();
      }
    }
    
    AppLogger.info('🎯 اكتملت معالجة جميع الدفعات: ${results.length} نتيجة');
    return results;
  }
  
  /// معالجة في الخلفية باستخدام Isolate للملفات الكبيرة
  static Future<T> processInIsolate<T>({
    required Map<String, dynamic> data,
    required String Function(Map<String, dynamic>) isolateFunction,
    required T Function(String) resultParser,
    required String operationName,
  }) async {
    AppLogger.info('🔄 بدء المعالجة في الخلفية: $operationName');
    
    final receivePort = ReceivePort();
    final isolate = await Isolate.spawn(
      _isolateEntryPoint,
      IsolateData(
        sendPort: receivePort.sendPort,
        data: data,
        functionName: isolateFunction.toString(),
      ),
    );
    
    final completer = Completer<T>();
    
    receivePort.listen((message) {
      if (message is String) {
        try {
          final result = resultParser(message);
          completer.complete(result);
        } catch (e) {
          completer.completeError(e);
        }
      } else if (message is Map && message['error'] != null) {
        completer.completeError(Exception(message['error']));
      }
      
      receivePort.close();
      isolate.kill();
    });
    
    return completer.future.timeout(
      const Duration(seconds: _maxProcessingTimeSeconds),
      onTimeout: () {
        receivePort.close();
        isolate.kill();
        throw PerformanceException(
          'انتهت مهلة المعالجة في الخلفية لـ $operationName',
          PerformanceErrorType.isolateTimeout,
        );
      },
    );
  }
  
  /// التخزين المؤقت للنتائج
  static Future<T> cacheResult<T>({
    required String key,
    required Future<T> Function() operation,
    Duration? expiration,
  }) async {
    final effectiveExpiration = expiration ?? _cacheExpiration;
    
    // فحص الذاكرة المؤقتة
    final cached = _cache[key];
    if (cached != null && !cached.isExpired) {
      AppLogger.info('📋 استخدام النتيجة المخزنة مؤقتاً: $key');
      return cached.data as T;
    }
    
    // تنفيذ العملية وحفظ النتيجة
    AppLogger.info('🔄 تنفيذ العملية وحفظها في الذاكرة المؤقتة: $key');
    final result = await operation();
    
    _cache[key] = CachedResult(
      data: result,
      timestamp: DateTime.now(),
      expiration: effectiveExpiration,
    );
    
    // تنظيف الذاكرة المؤقتة من النتائج المنتهية الصلاحية
    _cleanExpiredCache();
    
    return result;
  }
  
  /// تنظيف الذاكرة المؤقتة
  static void clearCache([String? key]) {
    if (key != null) {
      _cache.remove(key);
      AppLogger.info('🗑️ تم حذف النتيجة المخزنة: $key');
    } else {
      _cache.clear();
      AppLogger.info('🗑️ تم مسح جميع النتائج المخزنة');
    }
  }
  
  /// تنظيف النتائج المنتهية الصلاحية
  static void _cleanExpiredCache() {
    final expiredKeys = _cache.entries
        .where((entry) => entry.value.isExpired)
        .map((entry) => entry.key)
        .toList();
    
    for (final key in expiredKeys) {
      _cache.remove(key);
    }
    
    if (expiredKeys.isNotEmpty) {
      AppLogger.info('🗑️ تم حذف ${expiredKeys.length} نتيجة منتهية الصلاحية');
    }
  }
  
  /// نقطة دخول Isolate
  static void _isolateEntryPoint(IsolateData data) {
    try {
      // هنا يمكن تنفيذ المعالجة المعقدة
      // في التطبيق الحقيقي، ستكون هناك معالجة فعلية للبيانات
      final result = 'processed_${data.data.length}_items';
      data.sendPort.send(result);
    } catch (e) {
      data.sendPort.send({'error': e.toString()});
    }
  }
  
  /// تحسين استهلاك الذاكرة
  static Future<T> optimizeMemoryUsage<T>({
    required Future<T> Function() operation,
    required String operationName,
  }) async {
    AppLogger.info('🧠 تحسين استهلاك الذاكرة لـ: $operationName');
    
    // تنظيف الذاكرة المؤقتة قبل العملية الكبيرة
    _cleanExpiredCache();
    
    try {
      final result = await operation();
      
      // تنظيف إضافي بعد العملية
      _cleanExpiredCache();
      
      return result;
    } catch (e) {
      // تنظيف في حالة الخطأ أيضاً
      _cleanExpiredCache();
      rethrow;
    }
  }
  
  /// مراقبة الأداء
  static Future<PerformanceMetrics> measurePerformance<T>({
    required Future<T> Function() operation,
    required String operationName,
  }) async {
    final stopwatch = Stopwatch()..start();
    final startMemory = _getApproximateMemoryUsage();
    
    try {
      final result = await operation();
      stopwatch.stop();
      
      final endMemory = _getApproximateMemoryUsage();
      final metrics = PerformanceMetrics(
        operationName: operationName,
        executionTime: stopwatch.elapsed,
        memoryUsed: endMemory - startMemory,
        success: true,
      );
      
      AppLogger.info('📊 مقاييس الأداء لـ $operationName: ${metrics.toString()}');
      return metrics;
      
    } catch (e) {
      stopwatch.stop();
      final metrics = PerformanceMetrics(
        operationName: operationName,
        executionTime: stopwatch.elapsed,
        memoryUsed: 0,
        success: false,
        error: e.toString(),
      );
      
      AppLogger.error('📊 فشل في $operationName: ${metrics.toString()}');
      rethrow;
    }
  }
  
  /// تقدير استهلاك الذاكرة (تقريبي)
  static int _getApproximateMemoryUsage() {
    // تقدير تقريبي لاستهلاك الذاكرة
    return _cache.length * 1000; // تقدير 1KB لكل عنصر مخزن
  }
}

/// فئة للتحكم في عدد العمليات المتزامنة
class Semaphore {
  final int maxCount;
  int _currentCount;
  final Queue<Completer<void>> _waitQueue = Queue<Completer<void>>();
  
  Semaphore(this.maxCount) : _currentCount = maxCount;
  
  Future<void> acquire() async {
    if (_currentCount > 0) {
      _currentCount--;
      return;
    }
    
    final completer = Completer<void>();
    _waitQueue.add(completer);
    return completer.future;
  }
  
  void release() {
    if (_waitQueue.isNotEmpty) {
      final completer = _waitQueue.removeFirst();
      completer.complete();
    } else {
      _currentCount++;
    }
  }
}

/// نتيجة مخزنة مؤقتاً
class CachedResult {
  final dynamic data;
  final DateTime timestamp;
  final Duration expiration;
  
  CachedResult({
    required this.data,
    required this.timestamp,
    required this.expiration,
  });
  
  bool get isExpired => DateTime.now().difference(timestamp) > expiration;
}

/// بيانات Isolate
class IsolateData {
  final SendPort sendPort;
  final Map<String, dynamic> data;
  final String functionName;
  
  IsolateData({
    required this.sendPort,
    required this.data,
    required this.functionName,
  });
}

/// مقاييس الأداء
class PerformanceMetrics {
  final String operationName;
  final Duration executionTime;
  final int memoryUsed;
  final bool success;
  final String? error;
  
  PerformanceMetrics({
    required this.operationName,
    required this.executionTime,
    required this.memoryUsed,
    required this.success,
    this.error,
  });
  
  @override
  String toString() {
    return 'PerformanceMetrics(operation: $operationName, time: ${executionTime.inMilliseconds}ms, memory: ${memoryUsed}B, success: $success${error != null ? ', error: $error' : ''})';
  }
}

/// استثناء الأداء
class PerformanceException implements Exception {
  final String message;
  final PerformanceErrorType type;
  
  PerformanceException(this.message, this.type);
  
  @override
  String toString() => 'PerformanceException: $message (type: $type)';
}

/// أنواع أخطاء الأداء
enum PerformanceErrorType {
  timeout,
  isolateTimeout,
  memoryLimit,
  processingError,
}
