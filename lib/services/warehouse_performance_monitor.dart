import 'dart:async';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:smartbiztracker_new/services/warehouse_cache_service.dart';

/// Performance monitoring service for warehouse operations
class WarehousePerformanceMonitor {
  static final WarehousePerformanceMonitor _instance = WarehousePerformanceMonitor._internal();
  factory WarehousePerformanceMonitor() => _instance;
  WarehousePerformanceMonitor._internal();
  
  // Performance metrics
  final Map<String, List<int>> _loadTimes = {};
  final Map<String, int> _cacheHits = {};
  final Map<String, int> _cacheMisses = {};
  final Map<String, int> _operationCounts = {};
  
  // Performance targets (in milliseconds)
  static const int _targetInitialLoadTime = 3000; // 3 seconds
  static const int _targetCachedLoadTime = 1000;  // 1 second
  static const double _targetCacheHitRate = 0.8;  // 80%
  
  /// Record a warehouse operation load time
  void recordLoadTime(String operation, int milliseconds, {bool fromCache = false}) {
    _loadTimes.putIfAbsent(operation, () => []);
    _loadTimes[operation]!.add(milliseconds);
    
    _operationCounts[operation] = (_operationCounts[operation] ?? 0) + 1;
    
    if (fromCache) {
      _cacheHits[operation] = (_cacheHits[operation] ?? 0) + 1;
    } else {
      _cacheMisses[operation] = (_cacheMisses[operation] ?? 0) + 1;
    }
    
    // Log performance if it exceeds targets
    _checkPerformanceTargets(operation, milliseconds, fromCache);
  }
  
  /// Check if performance meets targets and log warnings if not
  void _checkPerformanceTargets(String operation, int milliseconds, bool fromCache) {
    final target = fromCache ? _targetCachedLoadTime : _targetInitialLoadTime;
    
    if (milliseconds > target) {
      final status = fromCache ? 'CACHED' : 'INITIAL';
      AppLogger.warning('⚠️ Performance target exceeded for $operation ($status): ${milliseconds}ms > ${target}ms');
    } else {
      final status = fromCache ? 'CACHED' : 'INITIAL';
      AppLogger.info('✅ Performance target met for $operation ($status): ${milliseconds}ms <= ${target}ms');
    }
  }
  
  /// Get average load time for an operation
  double getAverageLoadTime(String operation) {
    final times = _loadTimes[operation];
    if (times == null || times.isEmpty) return 0.0;
    
    return times.reduce((a, b) => a + b) / times.length;
  }
  
  /// Get cache hit rate for an operation
  double getCacheHitRate(String operation) {
    final hits = _cacheHits[operation] ?? 0;
    final misses = _cacheMisses[operation] ?? 0;
    final total = hits + misses;
    
    if (total == 0) return 0.0;
    return hits / total;
  }
  
  /// Get performance summary for all operations
  Map<String, dynamic> getPerformanceSummary() {
    final summary = <String, dynamic>{};
    
    for (final operation in _loadTimes.keys) {
      final avgLoadTime = getAverageLoadTime(operation);
      final cacheHitRate = getCacheHitRate(operation);
      final operationCount = _operationCounts[operation] ?? 0;
      
      summary[operation] = {
        'average_load_time_ms': avgLoadTime.round(),
        'cache_hit_rate': (cacheHitRate * 100).round(),
        'operation_count': operationCount,
        'meets_initial_target': avgLoadTime <= _targetInitialLoadTime,
        'meets_cached_target': avgLoadTime <= _targetCachedLoadTime,
        'meets_cache_hit_target': cacheHitRate >= _targetCacheHitRate,
      };
    }
    
    return summary;
  }
  
  /// Get detailed performance report
  String getDetailedPerformanceReport() {
    final summary = getPerformanceSummary();
    final cacheStats = WarehouseCacheService.getCacheStats();
    
    final buffer = StringBuffer();
    buffer.writeln('📊 WAREHOUSE PERFORMANCE REPORT');
    buffer.writeln('=' * 50);
    
    // Overall targets
    buffer.writeln('🎯 PERFORMANCE TARGETS:');
    buffer.writeln('  - Initial load time: ≤ ${_targetInitialLoadTime}ms');
    buffer.writeln('  - Cached load time: ≤ ${_targetCachedLoadTime}ms');
    buffer.writeln('  - Cache hit rate: ≥ ${(_targetCacheHitRate * 100).round()}%');
    buffer.writeln();
    
    // Operation-specific metrics
    buffer.writeln('📈 OPERATION METRICS:');
    for (final entry in summary.entries) {
      final operation = entry.key;
      final metrics = entry.value as Map<String, dynamic>;
      
      buffer.writeln('  $operation:');
      buffer.writeln('    - Average load time: ${metrics['average_load_time_ms']}ms');
      buffer.writeln('    - Cache hit rate: ${metrics['cache_hit_rate']}%');
      buffer.writeln('    - Operation count: ${metrics['operation_count']}');
      buffer.writeln('    - Meets initial target: ${metrics['meets_initial_target'] ? '✅' : '❌'}');
      buffer.writeln('    - Meets cached target: ${metrics['meets_cached_target'] ? '✅' : '❌'}');
      buffer.writeln('    - Meets cache hit target: ${metrics['meets_cache_hit_target'] ? '✅' : '❌'}');
      buffer.writeln();
    }
    
    // Cache statistics
    buffer.writeln('💾 CACHE STATISTICS:');
    buffer.writeln('  - Memory warehouses: ${cacheStats['memory_warehouses_count']}');
    buffer.writeln('  - Memory inventory: ${cacheStats['memory_inventory_count']}');
    buffer.writeln('  - Hive warehouses: ${cacheStats['hive_warehouses_count']}');
    buffer.writeln('  - Hive inventory: ${cacheStats['hive_inventory_count']}');
    buffer.writeln();
    
    // Overall assessment
    buffer.writeln('🏆 OVERALL ASSESSMENT:');
    final allOperationsMeetTargets = summary.values.every((metrics) {
      final m = metrics as Map<String, dynamic>;
      return m['meets_initial_target'] && m['meets_cached_target'] && m['meets_cache_hit_target'];
    });
    
    if (allOperationsMeetTargets) {
      buffer.writeln('  ✅ All performance targets are being met!');
    } else {
      buffer.writeln('  ⚠️ Some performance targets are not being met. Review the metrics above.');
    }
    
    return buffer.toString();
  }
  
  /// Log performance summary to console
  void logPerformanceSummary() {
    AppLogger.info(getDetailedPerformanceReport());
  }
  
  /// Reset all performance metrics
  void resetMetrics() {
    _loadTimes.clear();
    _cacheHits.clear();
    _cacheMisses.clear();
    _operationCounts.clear();
    AppLogger.info('🔄 Performance metrics reset');
  }
  
  /// Start periodic performance reporting
  Timer startPeriodicReporting({Duration interval = const Duration(minutes: 5)}) {
    AppLogger.info('📊 Starting periodic performance reporting every ${interval.inMinutes} minutes');
    
    return Timer.periodic(interval, (timer) {
      if (_operationCounts.isNotEmpty) {
        logPerformanceSummary();
      }
    });
  }
  
  /// Check if performance targets are being met
  bool arePerformanceTargetsMet() {
    final summary = getPerformanceSummary();
    
    return summary.values.every((metrics) {
      final m = metrics as Map<String, dynamic>;
      return m['meets_initial_target'] && m['meets_cached_target'] && m['meets_cache_hit_target'];
    });
  }
  
  /// Get performance score (0-100)
  int getPerformanceScore() {
    final summary = getPerformanceSummary();
    if (summary.isEmpty) return 100; // No data means perfect score
    
    int totalTargetsMet = 0;
    int totalTargets = 0;
    
    for (final metrics in summary.values) {
      final m = metrics as Map<String, dynamic>;
      totalTargets += 3; // 3 targets per operation
      
      if (m['meets_initial_target']) totalTargetsMet++;
      if (m['meets_cached_target']) totalTargetsMet++;
      if (m['meets_cache_hit_target']) totalTargetsMet++;
    }
    
    return ((totalTargetsMet / totalTargets) * 100).round();
  }
}
