import 'dart:async';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// Performance monitoring utility for warehouse operations
class PerformanceMonitor {
  static final Map<String, DateTime> _startTimes = {};
  static final Map<String, List<Duration>> _operationHistory = {};
  
  /// Start timing an operation
  static void startOperation(String operationName) {
    _startTimes[operationName] = DateTime.now();
    AppLogger.info('⏱️ Started: $operationName');
  }
  
  /// End timing an operation and log the duration
  static Duration endOperation(String operationName) {
    final startTime = _startTimes[operationName];
    if (startTime == null) {
      AppLogger.warning('⚠️ No start time found for operation: $operationName');
      return Duration.zero;
    }
    
    final duration = DateTime.now().difference(startTime);
    _startTimes.remove(operationName);
    
    // Store in history
    _operationHistory.putIfAbsent(operationName, () => []).add(duration);
    
    // Keep only last 10 measurements
    if (_operationHistory[operationName]!.length > 10) {
      _operationHistory[operationName]!.removeAt(0);
    }
    
    _logPerformance(operationName, duration);
    return duration;
  }
  
  /// Log performance with appropriate level based on duration
  static void _logPerformance(String operationName, Duration duration) {
    final milliseconds = duration.inMilliseconds;
    
    if (milliseconds < 1000) {
      AppLogger.info('✅ $operationName completed in ${milliseconds}ms');
    } else if (milliseconds < 3000) {
      AppLogger.warning('⚠️ $operationName took ${milliseconds}ms (acceptable)');
    } else {
      AppLogger.error('🐌 $operationName took ${milliseconds}ms (slow!)');
    }
  }
  
  /// Get average performance for an operation
  static Duration? getAveragePerformance(String operationName) {
    final history = _operationHistory[operationName];
    if (history == null || history.isEmpty) return null;
    
    final totalMs = history.fold<int>(0, (sum, duration) => sum + duration.inMilliseconds);
    return Duration(milliseconds: (totalMs / history.length).round());
  }
  
  /// Get performance report
  static Map<String, dynamic> getPerformanceReport() {
    final report = <String, dynamic>{};
    
    for (final operation in _operationHistory.keys) {
      final history = _operationHistory[operation]!;
      if (history.isNotEmpty) {
        final avgDuration = getAveragePerformance(operation)!;
        final lastDuration = history.last;
        
        report[operation] = {
          'average_ms': avgDuration.inMilliseconds,
          'last_ms': lastDuration.inMilliseconds,
          'sample_count': history.length,
          'performance_grade': _getPerformanceGrade(avgDuration.inMilliseconds),
        };
      }
    }
    
    return report;
  }
  
  /// Get performance grade based on milliseconds
  static String _getPerformanceGrade(int milliseconds) {
    if (milliseconds < 500) return 'Excellent';
    if (milliseconds < 1000) return 'Good';
    if (milliseconds < 2000) return 'Fair';
    if (milliseconds < 3000) return 'Poor';
    return 'Very Poor';
  }
  
  /// Log performance summary
  static void logPerformanceSummary() {
    final report = getPerformanceReport();
    
    AppLogger.info('📊 === Performance Summary ===');
    for (final operation in report.keys) {
      final data = report[operation];
      AppLogger.info('🔍 $operation: ${data['average_ms']}ms avg (${data['performance_grade']})');
    }
    AppLogger.info('================================');
  }
  
  /// Clear performance history
  static void clearHistory() {
    _operationHistory.clear();
    _startTimes.clear();
    AppLogger.info('🗑️ Performance history cleared');
  }
}

/// Specific performance constants for warehouse operations
class WarehousePerformanceTargets {
  static const int warehouseLoadingTargetMs = 2000;
  static const int inventoryLoadingTargetMs = 1500;
  static const int cacheLoadingTargetMs = 500;
  static const int databaseQueryTargetMs = 1000;
  
  /// Check if operation meets performance target
  static bool meetsTarget(String operation, Duration duration) {
    final ms = duration.inMilliseconds;
    
    switch (operation) {
      case 'warehouse_loading':
        return ms <= warehouseLoadingTargetMs;
      case 'inventory_loading':
        return ms <= inventoryLoadingTargetMs;
      case 'cache_loading':
        return ms <= cacheLoadingTargetMs;
      case 'database_query':
        return ms <= databaseQueryTargetMs;
      default:
        return ms <= 2000; // Default 2 second target
    }
  }
  
  /// Get target for operation
  static int getTarget(String operation) {
    switch (operation) {
      case 'warehouse_loading':
        return warehouseLoadingTargetMs;
      case 'inventory_loading':
        return inventoryLoadingTargetMs;
      case 'cache_loading':
        return cacheLoadingTargetMs;
      case 'database_query':
        return databaseQueryTargetMs;
      default:
        return 2000;
    }
  }
}

/// Wrapper for timing operations with automatic logging
class TimedOperation {
  final String operationName;
  final DateTime startTime;

  TimedOperation(this.operationName) : startTime = DateTime.now() {
    PerformanceMonitor.startOperation(operationName);
  }

  /// Get elapsed milliseconds since operation started
  int get elapsedMilliseconds {
    return DateTime.now().difference(startTime).inMilliseconds;
  }

  /// Complete the operation and return duration
  Duration complete() {
    return PerformanceMonitor.endOperation(operationName);
  }

  /// Complete with result and check performance target
  T completeWithResult<T>(T result) {
    try {
      final duration = complete();
      final meetsTarget = WarehousePerformanceTargets.meetsTarget(operationName, duration);

      if (!meetsTarget) {
        final target = WarehousePerformanceTargets.getTarget(operationName);
        AppLogger.warning('⚠️ $operationName exceeded target: ${duration.inMilliseconds}ms > ${target}ms');
      }

      return result;
    } catch (e) {
      // If complete() fails, ensure we still return the result
      AppLogger.warning('⚠️ Failed to complete timing for operation $operationName: $e');
      return result;
    }
  }

  /// Safe complete that handles missing start times
  Duration safeComplete() {
    try {
      return complete();
    } catch (e) {
      AppLogger.warning('⚠️ Safe complete failed for operation $operationName: $e');
      return Duration.zero;
    }
  }
}
