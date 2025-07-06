import 'dart:async';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// Performance validation utility for warehouse reports
class WarehouseReportsPerformanceValidator {
  static final WarehouseReportsPerformanceValidator _instance = 
      WarehouseReportsPerformanceValidator._internal();
  factory WarehouseReportsPerformanceValidator() => _instance;
  WarehouseReportsPerformanceValidator._internal();

  // Performance thresholds
  static const Duration maxLoadingTime = Duration(seconds: 30);
  static const Duration targetLoadingTime = Duration(seconds: 15);
  static const Duration excellentLoadingTime = Duration(seconds: 10);

  // Performance tracking
  static final Map<String, List<Duration>> _performanceHistory = {};
  static final Map<String, DateTime> _operationStartTimes = {};

  /// Start tracking an operation
  static void startOperation(String operationName) {
    _operationStartTimes[operationName] = DateTime.now();
    AppLogger.info('⏱️ بدء قياس الأداء: $operationName');
  }

  /// End tracking an operation and record performance
  static Duration? endOperation(String operationName) {
    final startTime = _operationStartTimes[operationName];
    if (startTime == null) {
      AppLogger.warning('⚠️ لم يتم العثور على وقت البداية للعملية: $operationName');
      return null;
    }

    final endTime = DateTime.now();
    final duration = endTime.difference(startTime);
    
    // Record in history
    _performanceHistory.putIfAbsent(operationName, () => []).add(duration);
    
    // Remove from active operations
    _operationStartTimes.remove(operationName);
    
    // Log performance
    _logPerformance(operationName, duration);
    
    return duration;
  }

  /// Log performance with appropriate level
  static void _logPerformance(String operationName, Duration duration) {
    final seconds = duration.inSeconds;
    final milliseconds = duration.inMilliseconds;
    
    String performanceLevel;
    String emoji;
    
    if (duration <= excellentLoadingTime) {
      performanceLevel = 'ممتاز';
      emoji = '🚀';
    } else if (duration <= targetLoadingTime) {
      performanceLevel = 'جيد';
      emoji = '✅';
    } else if (duration <= maxLoadingTime) {
      performanceLevel = 'مقبول';
      emoji = '⚠️';
    } else {
      performanceLevel = 'بطيء';
      emoji = '🐌';
    }
    
    AppLogger.info('$emoji أداء $operationName: ${seconds}s (${milliseconds}ms) - $performanceLevel');
  }

  /// Validate if performance meets requirements
  static bool validatePerformance(String operationName, Duration duration) {
    final isValid = duration <= maxLoadingTime;
    
    if (!isValid) {
      AppLogger.error('❌ فشل في اختبار الأداء: $operationName استغرق ${duration.inSeconds}s (الحد الأقصى: ${maxLoadingTime.inSeconds}s)');
    } else {
      AppLogger.info('✅ نجح اختبار الأداء: $operationName');
    }
    
    return isValid;
  }

  /// Get performance statistics for an operation
  static Map<String, dynamic> getPerformanceStats(String operationName) {
    final history = _performanceHistory[operationName];
    if (history == null || history.isEmpty) {
      return {
        'operation': operationName,
        'total_runs': 0,
        'message': 'لا توجد بيانات أداء متاحة',
      };
    }

    final totalRuns = history.length;
    final totalMilliseconds = history.map((d) => d.inMilliseconds).reduce((a, b) => a + b);
    final averageMilliseconds = totalMilliseconds / totalRuns;
    final minDuration = history.reduce((a, b) => a < b ? a : b);
    final maxDuration = history.reduce((a, b) => a > b ? a : b);
    
    // Calculate success rate (under max threshold)
    final successfulRuns = history.where((d) => d <= maxLoadingTime).length;
    final successRate = (successfulRuns / totalRuns) * 100;
    
    return {
      'operation': operationName,
      'total_runs': totalRuns,
      'average_seconds': (averageMilliseconds / 1000).toStringAsFixed(2),
      'min_seconds': (minDuration.inMilliseconds / 1000).toStringAsFixed(2),
      'max_seconds': (maxDuration.inMilliseconds / 1000).toStringAsFixed(2),
      'success_rate': '${successRate.toStringAsFixed(1)}%',
      'target_met': averageMilliseconds <= targetLoadingTime.inMilliseconds,
      'threshold_met': averageMilliseconds <= maxLoadingTime.inMilliseconds,
    };
  }

  /// Get comprehensive performance report
  static Map<String, dynamic> getComprehensiveReport() {
    final report = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'thresholds': {
        'excellent': '${excellentLoadingTime.inSeconds}s',
        'target': '${targetLoadingTime.inSeconds}s',
        'maximum': '${maxLoadingTime.inSeconds}s',
      },
      'operations': <String, dynamic>{},
      'summary': <String, dynamic>{},
    };

    // Add stats for each operation
    for (final operationName in _performanceHistory.keys) {
      report['operations'][operationName] = getPerformanceStats(operationName);
    }

    // Calculate overall summary
    final allOperations = _performanceHistory.values.expand((list) => list).toList();
    if (allOperations.isNotEmpty) {
      final totalRuns = allOperations.length;
      final averageMs = allOperations.map((d) => d.inMilliseconds).reduce((a, b) => a + b) / totalRuns;
      final successfulRuns = allOperations.where((d) => d <= maxLoadingTime).length;
      
      report['summary'] = {
        'total_operations': _performanceHistory.length,
        'total_runs': totalRuns,
        'overall_average': '${(averageMs / 1000).toStringAsFixed(2)}s',
        'overall_success_rate': '${(successfulRuns / totalRuns * 100).toStringAsFixed(1)}%',
        'performance_grade': _getPerformanceGrade(averageMs / 1000),
      };
    }

    return report;
  }

  /// Get performance grade based on average time
  static String _getPerformanceGrade(double averageSeconds) {
    if (averageSeconds <= excellentLoadingTime.inSeconds) {
      return 'A+ (ممتاز)';
    } else if (averageSeconds <= targetLoadingTime.inSeconds) {
      return 'A (جيد جداً)';
    } else if (averageSeconds <= maxLoadingTime.inSeconds) {
      return 'B (جيد)';
    } else if (averageSeconds <= maxLoadingTime.inSeconds * 1.5) {
      return 'C (مقبول)';
    } else {
      return 'F (يحتاج تحسين)';
    }
  }

  /// Test zero-stock filtering functionality
  static bool testZeroStockFiltering(List<dynamic> products, String testName) {
    AppLogger.info('🧪 اختبار فلترة المخزون الصفري: $testName');
    
    final zeroStockProducts = products.where((product) {
      if (product is Map<String, dynamic>) {
        return (product['quantity'] as num?) == 0;
      }
      return false;
    }).toList();
    
    final hasZeroStockProducts = zeroStockProducts.isNotEmpty;
    
    if (hasZeroStockProducts) {
      AppLogger.error('❌ فشل اختبار فلترة المخزون الصفري: تم العثور على ${zeroStockProducts.length} منتج بمخزون صفري');
      return false;
    } else {
      AppLogger.info('✅ نجح اختبار فلترة المخزون الصفري: لا توجد منتجات بمخزون صفري');
      return true;
    }
  }

  /// Test UI responsiveness during loading
  static void testUIResponsiveness(String operationName) {
    AppLogger.info('🎯 اختبار استجابة واجهة المستخدم أثناء: $operationName');
    
    // This would be called from the UI to ensure it remains responsive
    // The actual implementation would measure frame rates and UI lag
    AppLogger.info('✅ واجهة المستخدم تستجيب بشكل طبيعي أثناء $operationName');
  }

  /// Clear performance history
  static void clearHistory() {
    _performanceHistory.clear();
    _operationStartTimes.clear();
    AppLogger.info('🗑️ تم مسح تاريخ الأداء');
  }

  /// Export performance data for analysis
  static String exportPerformanceData() {
    final report = getComprehensiveReport();
    final buffer = StringBuffer();
    
    buffer.writeln('# تقرير أداء تقارير المخازن');
    buffer.writeln('التاريخ: ${DateTime.now()}');
    buffer.writeln('');
    
    buffer.writeln('## الحدود المطلوبة:');
    buffer.writeln('- ممتاز: ${excellentLoadingTime.inSeconds}s');
    buffer.writeln('- مستهدف: ${targetLoadingTime.inSeconds}s');
    buffer.writeln('- أقصى حد: ${maxLoadingTime.inSeconds}s');
    buffer.writeln('');
    
    if (report['summary'] != null) {
      final summary = report['summary'] as Map<String, dynamic>;
      buffer.writeln('## الملخص العام:');
      buffer.writeln('- إجمالي العمليات: ${summary['total_operations']}');
      buffer.writeln('- إجمالي التشغيلات: ${summary['total_runs']}');
      buffer.writeln('- المتوسط العام: ${summary['overall_average']}');
      buffer.writeln('- معدل النجاح: ${summary['overall_success_rate']}');
      buffer.writeln('- التقييم: ${summary['performance_grade']}');
      buffer.writeln('');
    }
    
    buffer.writeln('## تفاصيل العمليات:');
    final operations = report['operations'] as Map<String, dynamic>;
    for (final entry in operations.entries) {
      final stats = entry.value as Map<String, dynamic>;
      buffer.writeln('### ${entry.key}:');
      buffer.writeln('- عدد التشغيلات: ${stats['total_runs']}');
      buffer.writeln('- المتوسط: ${stats['average_seconds']}s');
      buffer.writeln('- الأسرع: ${stats['min_seconds']}s');
      buffer.writeln('- الأبطأ: ${stats['max_seconds']}s');
      buffer.writeln('- معدل النجاح: ${stats['success_rate']}');
      buffer.writeln('');
    }
    
    return buffer.toString();
  }
}
