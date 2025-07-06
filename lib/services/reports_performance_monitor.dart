import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// Performance Monitor specifically for Reports Tab optimization
/// Tracks loading times, cache performance, and provides alerts for degradation
class ReportsPerformanceMonitor {
  static final ReportsPerformanceMonitor _instance = ReportsPerformanceMonitor._internal();
  factory ReportsPerformanceMonitor() => _instance;
  ReportsPerformanceMonitor._internal();

  // Performance tracking
  final Map<String, Stopwatch> _activeOperations = {};
  final Queue<PerformanceMetric> _performanceHistory = Queue<PerformanceMetric>();
  final Map<String, List<Duration>> _operationTimes = {};
  
  // Cache performance tracking
  final Map<String, int> _cacheHits = {};
  final Map<String, int> _cacheMisses = {};
  
  // Performance thresholds
  static const Duration _warningThreshold = Duration(seconds: 2);
  static const Duration _criticalThreshold = Duration(seconds: 5);
  static const int _maxHistorySize = 100;
  
  // Performance alerts callback
  Function(PerformanceAlert)? _alertCallback;

  /// Set callback for performance alerts
  void setAlertCallback(Function(PerformanceAlert) callback) {
    _alertCallback = callback;
  }

  /// Start tracking an operation
  void startOperation(String operationName) {
    if (_activeOperations.containsKey(operationName)) {
      AppLogger.warning('⚠️ Operation $operationName already being tracked');
      return;
    }
    
    _activeOperations[operationName] = Stopwatch()..start();
    AppLogger.info('🔄 Started tracking operation: $operationName');
  }

  /// End tracking an operation and record performance
  Duration? endOperation(String operationName) {
    final stopwatch = _activeOperations.remove(operationName);
    if (stopwatch == null) {
      AppLogger.warning('⚠️ Operation $operationName was not being tracked');
      return null;
    }
    
    stopwatch.stop();
    final duration = stopwatch.elapsed;
    
    // Record performance metric
    _recordPerformanceMetric(operationName, duration);
    
    // Check for performance issues
    _checkPerformanceThresholds(operationName, duration);
    
    AppLogger.info('✅ Operation $operationName completed in ${duration.inMilliseconds}ms');
    return duration;
  }

  /// Record cache hit
  void recordCacheHit(String cacheKey) {
    _cacheHits[cacheKey] = (_cacheHits[cacheKey] ?? 0) + 1;
  }

  /// Record cache miss
  void recordCacheMiss(String cacheKey) {
    _cacheMisses[cacheKey] = (_cacheMisses[cacheKey] ?? 0) + 1;
  }

  /// Get cache hit rate for a specific key
  double getCacheHitRate(String cacheKey) {
    final hits = _cacheHits[cacheKey] ?? 0;
    final misses = _cacheMisses[cacheKey] ?? 0;
    final total = hits + misses;
    
    return total > 0 ? hits / total : 0.0;
  }

  /// Get overall cache hit rate
  double getOverallCacheHitRate() {
    final totalHits = _cacheHits.values.fold(0, (sum, hits) => sum + hits);
    final totalMisses = _cacheMisses.values.fold(0, (sum, misses) => sum + misses);
    final total = totalHits + totalMisses;
    
    return total > 0 ? totalHits / total : 0.0;
  }

  /// Get performance statistics
  Map<String, dynamic> getPerformanceStatistics() {
    final stats = <String, dynamic>{};
    
    // Operation performance
    for (final entry in _operationTimes.entries) {
      final times = entry.value;
      if (times.isNotEmpty) {
        final avgTime = times.map((d) => d.inMilliseconds).reduce((a, b) => a + b) / times.length;
        final minTime = times.map((d) => d.inMilliseconds).reduce((a, b) => a < b ? a : b);
        final maxTime = times.map((d) => d.inMilliseconds).reduce((a, b) => a > b ? a : b);
        
        stats[entry.key] = {
          'averageMs': avgTime.round(),
          'minMs': minTime,
          'maxMs': maxTime,
          'count': times.length,
        };
      }
    }
    
    // Cache performance
    stats['cache'] = {
      'overallHitRate': getOverallCacheHitRate(),
      'totalHits': _cacheHits.values.fold(0, (sum, hits) => sum + hits),
      'totalMisses': _cacheMisses.values.fold(0, (sum, misses) => sum + misses),
      'keyStats': _getCacheKeyStatistics(),
    };
    
    // Recent performance trends
    stats['trends'] = _getPerformanceTrends();
    
    return stats;
  }

  /// Get performance trends from recent history
  Map<String, dynamic> _getPerformanceTrends() {
    if (_performanceHistory.length < 10) {
      return {'status': 'insufficient_data'};
    }
    
    final recentMetrics = _performanceHistory.toList().reversed.take(20).toList();
    final avgRecentTime = recentMetrics
        .map((m) => m.duration.inMilliseconds)
        .reduce((a, b) => a + b) / recentMetrics.length;
    
    final olderMetrics = _performanceHistory.toList().reversed.skip(20).take(20).toList();
    if (olderMetrics.isEmpty) {
      return {'status': 'improving', 'trend': 'stable'};
    }
    
    final avgOlderTime = olderMetrics
        .map((m) => m.duration.inMilliseconds)
        .reduce((a, b) => a + b) / olderMetrics.length;
    
    final improvement = ((avgOlderTime - avgRecentTime) / avgOlderTime) * 100;
    
    String trend;
    if (improvement > 10) {
      trend = 'improving';
    } else if (improvement < -10) {
      trend = 'degrading';
    } else {
      trend = 'stable';
    }
    
    return {
      'status': 'analyzed',
      'trend': trend,
      'improvement_percentage': improvement.round(),
      'recent_avg_ms': avgRecentTime.round(),
      'older_avg_ms': avgOlderTime.round(),
    };
  }

  /// Get cache statistics for each key
  Map<String, Map<String, dynamic>> _getCacheKeyStatistics() {
    final keyStats = <String, Map<String, dynamic>>{};
    
    final allKeys = {..._cacheHits.keys, ..._cacheMisses.keys};
    for (final key in allKeys) {
      final hits = _cacheHits[key] ?? 0;
      final misses = _cacheMisses[key] ?? 0;
      final total = hits + misses;
      
      keyStats[key] = {
        'hits': hits,
        'misses': misses,
        'hitRate': total > 0 ? hits / total : 0.0,
        'total': total,
      };
    }
    
    return keyStats;
  }

  /// Record a performance metric
  void _recordPerformanceMetric(String operationName, Duration duration) {
    final metric = PerformanceMetric(
      operationName: operationName,
      duration: duration,
      timestamp: DateTime.now(),
    );
    
    _performanceHistory.add(metric);
    
    // Maintain history size limit
    while (_performanceHistory.length > _maxHistorySize) {
      _performanceHistory.removeFirst();
    }
    
    // Record in operation times for statistics
    _operationTimes[operationName] ??= [];
    _operationTimes[operationName]!.add(duration);
    
    // Keep only recent times for each operation
    if (_operationTimes[operationName]!.length > 20) {
      _operationTimes[operationName]!.removeAt(0);
    }
  }

  /// Check performance thresholds and trigger alerts
  void _checkPerformanceThresholds(String operationName, Duration duration) {
    PerformanceAlert? alert;
    
    if (duration > _criticalThreshold) {
      alert = PerformanceAlert(
        level: AlertLevel.critical,
        operationName: operationName,
        duration: duration,
        message: 'Critical performance issue: $operationName took ${duration.inSeconds}s',
        timestamp: DateTime.now(),
      );
    } else if (duration > _warningThreshold) {
      alert = PerformanceAlert(
        level: AlertLevel.warning,
        operationName: operationName,
        duration: duration,
        message: 'Performance warning: $operationName took ${duration.inMilliseconds}ms',
        timestamp: DateTime.now(),
      );
    }
    
    if (alert != null) {
      AppLogger.warning('⚠️ Performance Alert: ${alert.message}');
      _alertCallback?.call(alert);
    }
  }

  /// Clear all performance data
  void clearPerformanceData() {
    _activeOperations.clear();
    _performanceHistory.clear();
    _operationTimes.clear();
    _cacheHits.clear();
    _cacheMisses.clear();
    
    AppLogger.info('🧹 Cleared all performance monitoring data');
  }

  /// Get active operations count
  int getActiveOperationsCount() {
    return _activeOperations.length;
  }

  /// Force end all active operations (cleanup)
  void forceEndAllOperations() {
    final activeOps = _activeOperations.keys.toList();
    for (final op in activeOps) {
      endOperation(op);
    }
    AppLogger.info('🛑 Force ended ${activeOps.length} active operations');
  }

  /// Generate performance report
  String generatePerformanceReport() {
    final stats = getPerformanceStatistics();
    final trends = stats['trends'] as Map<String, dynamic>;
    final cache = stats['cache'] as Map<String, dynamic>;
    
    final report = StringBuffer();
    report.writeln('📊 Reports Performance Monitor Report');
    report.writeln('Generated: ${DateTime.now()}');
    report.writeln('');
    
    // Cache performance
    report.writeln('🗄️ Cache Performance:');
    report.writeln('  Overall Hit Rate: ${(cache['overallHitRate'] * 100).toStringAsFixed(1)}%');
    report.writeln('  Total Hits: ${cache['totalHits']}');
    report.writeln('  Total Misses: ${cache['totalMisses']}');
    report.writeln('');
    
    // Performance trends
    report.writeln('📈 Performance Trends:');
    if (trends['status'] == 'analyzed') {
      report.writeln('  Trend: ${trends['trend']}');
      report.writeln('  Improvement: ${trends['improvement_percentage']}%');
      report.writeln('  Recent Avg: ${trends['recent_avg_ms']}ms');
    } else {
      report.writeln('  Status: ${trends['status']}');
    }
    report.writeln('');
    
    // Operation statistics
    report.writeln('⚡ Operation Performance:');
    stats.forEach((key, value) {
      if (key != 'cache' && key != 'trends' && value is Map) {
        final opStats = value as Map<String, dynamic>;
        report.writeln('  $key:');
        report.writeln('    Average: ${opStats['averageMs']}ms');
        report.writeln('    Min: ${opStats['minMs']}ms');
        report.writeln('    Max: ${opStats['maxMs']}ms');
        report.writeln('    Count: ${opStats['count']}');
      }
    });
    
    return report.toString();
  }
}

/// Performance metric data class
class PerformanceMetric {
  final String operationName;
  final Duration duration;
  final DateTime timestamp;

  PerformanceMetric({
    required this.operationName,
    required this.duration,
    required this.timestamp,
  });
}

/// Performance alert data class
class PerformanceAlert {
  final AlertLevel level;
  final String operationName;
  final Duration duration;
  final String message;
  final DateTime timestamp;

  PerformanceAlert({
    required this.level,
    required this.operationName,
    required this.duration,
    required this.message,
    required this.timestamp,
  });
}

/// Alert severity levels
enum AlertLevel {
  warning,
  critical,
}
