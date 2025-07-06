import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import '../utils/app_logger.dart';

/// خدمة مراقبة الأداء لتتبع وتحسين أداء التطبيق
class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();

  final Map<String, Stopwatch> _activeOperations = {};
  final Map<String, List<int>> _operationHistory = {};
  final Map<String, int> _operationCounts = {};

  /// بدء مراقبة عملية
  void startOperation(String operationName) {
    if (_activeOperations.containsKey(operationName)) {
      AppLogger.warning('العملية $operationName قيد التنفيذ بالفعل');
      return;
    }

    final stopwatch = Stopwatch()..start();
    _activeOperations[operationName] = stopwatch;
    
    if (kDebugMode) {
      developer.Timeline.startSync(operationName);
    }
  }

  /// إنهاء مراقبة عملية
  void endOperation(String operationName) {
    final stopwatch = _activeOperations.remove(operationName);
    if (stopwatch == null) {
      AppLogger.warning('العملية $operationName غير موجودة');
      return;
    }

    stopwatch.stop();
    final duration = stopwatch.elapsedMilliseconds;

    // تسجيل في التاريخ
    _operationHistory.putIfAbsent(operationName, () => []).add(duration);
    _operationCounts[operationName] = (_operationCounts[operationName] ?? 0) + 1;

    // تنظيف التاريخ (الاحتفاظ بآخر 100 عملية)
    if (_operationHistory[operationName]!.length > 100) {
      _operationHistory[operationName]!.removeAt(0);
    }

    if (kDebugMode) {
      developer.Timeline.finishSync();
    }

    // تحذير إذا كانت العملية بطيئة
    if (duration > 1000) {
      AppLogger.warning('العملية $operationName استغرقت ${duration}ms (بطيئة)');
    } else if (duration > 500) {
      AppLogger.info('العملية $operationName استغرقت ${duration}ms');
    }
  }

  /// قياس عملية مع callback
  Future<T> measureOperation<T>(
    String operationName,
    Future<T> Function() operation,
  ) async {
    startOperation(operationName);
    try {
      final result = await operation();
      return result;
    } finally {
      endOperation(operationName);
    }
  }

  /// قياس عملية متزامنة
  T measureSync<T>(
    String operationName,
    T Function() operation,
  ) {
    startOperation(operationName);
    try {
      final result = operation();
      return result;
    } finally {
      endOperation(operationName);
    }
  }

  /// الحصول على إحصائيات العملية
  Map<String, dynamic> getOperationStats(String operationName) {
    final history = _operationHistory[operationName] ?? [];
    if (history.isEmpty) {
      return {
        'count': 0,
        'average': 0,
        'min': 0,
        'max': 0,
        'total': 0,
      };
    }

    final total = history.reduce((a, b) => a + b);
    final average = total / history.length;
    final min = history.reduce((a, b) => a < b ? a : b);
    final max = history.reduce((a, b) => a > b ? a : b);

    return {
      'count': history.length,
      'average': average.round(),
      'min': min,
      'max': max,
      'total': total,
      'recent': history.take(10).toList(),
    };
  }

  /// الحصول على جميع الإحصائيات
  Map<String, Map<String, dynamic>> getAllStats() {
    final stats = <String, Map<String, dynamic>>{};
    for (final operationName in _operationHistory.keys) {
      stats[operationName] = getOperationStats(operationName);
    }
    return stats;
  }

  /// طباعة تقرير الأداء
  void printPerformanceReport() {
    AppLogger.info('📊 تقرير الأداء:');
    final stats = getAllStats();
    
    if (stats.isEmpty) {
      AppLogger.info('لا توجد بيانات أداء');
      return;
    }

    for (final entry in stats.entries) {
      final operationName = entry.key;
      final operationStats = entry.value;
      
      AppLogger.info(
        '🔍 $operationName: '
        'العدد=${operationStats['count']}, '
        'المتوسط=${operationStats['average']}ms, '
        'الأدنى=${operationStats['min']}ms, '
        'الأعلى=${operationStats['max']}ms'
      );
    }
  }

  /// مسح جميع البيانات
  void clearStats() {
    _operationHistory.clear();
    _operationCounts.clear();
    AppLogger.info('تم مسح إحصائيات الأداء');
  }

  /// التحقق من العمليات المعلقة
  List<String> getActiveOperations() {
    return _activeOperations.keys.toList();
  }

  /// إنهاء جميع العمليات المعلقة
  void forceEndAllOperations() {
    final activeOps = List.from(_activeOperations.keys);
    for (final op in activeOps) {
      AppLogger.warning('إنهاء قسري للعملية المعلقة: $op');
      endOperation(op);
    }
  }

  /// مراقبة استخدام الذاكرة
  void logMemoryUsage(String context) {
    if (kDebugMode) {
      developer.Timeline.instantSync('Memory Check', arguments: {
        'context': context,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }
}

/// Extension لتسهيل استخدام مراقب الأداء
extension PerformanceMonitorExtension on Future {
  Future<T> withPerformanceMonitoring<T>(String operationName) async {
    return PerformanceMonitor().measureOperation(operationName, () async {
      return await this as T;
    });
  }
}
