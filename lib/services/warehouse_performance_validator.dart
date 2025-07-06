import 'dart:async';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:smartbiztracker_new/services/warehouse_cache_service.dart';
import 'package:smartbiztracker_new/utils/performance_monitor.dart';

/// Comprehensive performance validator for warehouse operations
/// Ensures all performance targets are met and validates optimization success
class WarehousePerformanceValidator {
  static final WarehousePerformanceValidator _instance = WarehousePerformanceValidator._internal();
  factory WarehousePerformanceValidator() => _instance;
  WarehousePerformanceValidator._internal();

  // Performance targets (in milliseconds)
  static const int _transactionsTargetMs = 2000;
  static const int _inventoryTargetMs = 3000;
  static const int _warehousesTargetMs = 2000;
  static const int _statisticsTargetMs = 1500;
  static const int _cacheTargetMs = 500;

  // Performance tracking
  final Map<String, List<int>> _performanceHistory = {};
  final Map<String, int> _successCount = {};
  final Map<String, int> _failureCount = {};
  Timer? _monitoringTimer;

  /// Initialize performance monitoring
  Future<void> initialize() async {
    AppLogger.info('🎯 Initializing Warehouse Performance Validator...');
    
    // Clear any existing monitoring
    _monitoringTimer?.cancel();
    
    // Start continuous monitoring
    _startContinuousMonitoring();
    
    AppLogger.info('✅ Warehouse Performance Validator initialized');
  }

  /// Start continuous performance monitoring
  void _startContinuousMonitoring() {
    _monitoringTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      _generatePerformanceReport();
    });
  }

  /// Record performance measurement for validation
  void recordPerformance(String operation, int milliseconds) {
    _performanceHistory.putIfAbsent(operation, () => []);
    _performanceHistory[operation]!.add(milliseconds);
    
    // Keep only last 20 measurements
    if (_performanceHistory[operation]!.length > 20) {
      _performanceHistory[operation]!.removeAt(0);
    }
    
    // Check if target is met
    final targetMet = _checkPerformanceTarget(operation, milliseconds);
    
    if (targetMet) {
      _successCount[operation] = (_successCount[operation] ?? 0) + 1;
      AppLogger.info('✅ Performance target met for $operation: ${milliseconds}ms');
    } else {
      _failureCount[operation] = (_failureCount[operation] ?? 0) + 1;
      AppLogger.warning('⚠️ Performance target missed for $operation: ${milliseconds}ms');
    }
  }

  /// Check if performance meets target
  bool _checkPerformanceTarget(String operation, int milliseconds) {
    switch (operation) {
      case 'warehouse_transactions_loading':
        return milliseconds <= _transactionsTargetMs;
      case 'warehouse_inventory_loading':
        return milliseconds <= _inventoryTargetMs;
      case 'warehouse_loading':
        return milliseconds <= _warehousesTargetMs;
      case 'warehouse_statistics_loading':
        return milliseconds <= _statisticsTargetMs;
      case 'cache_loading':
        return milliseconds <= _cacheTargetMs;
      default:
        return milliseconds <= 2000; // Default 2-second target
    }
  }

  /// Get performance target for operation
  int _getPerformanceTarget(String operation) {
    switch (operation) {
      case 'warehouse_transactions_loading':
        return _transactionsTargetMs;
      case 'warehouse_inventory_loading':
        return _inventoryTargetMs;
      case 'warehouse_loading':
        return _warehousesTargetMs;
      case 'warehouse_statistics_loading':
        return _statisticsTargetMs;
      case 'cache_loading':
        return _cacheTargetMs;
      default:
        return 2000;
    }
  }

  /// Validate all performance targets are being met
  bool validateAllTargets() {
    bool allTargetsMet = true;
    final report = <String, Map<String, dynamic>>{};

    for (final operation in _performanceHistory.keys) {
      final measurements = _performanceHistory[operation]!;
      if (measurements.isEmpty) continue;

      final avgTime = measurements.reduce((a, b) => a + b) / measurements.length;
      final target = _getPerformanceTarget(operation);
      final targetMet = avgTime <= target;
      final successRate = _getSuccessRate(operation);

      report[operation] = {
        'average_time_ms': avgTime.round(),
        'target_ms': target,
        'target_met': targetMet,
        'success_rate': successRate,
        'sample_count': measurements.length,
        'latest_time_ms': measurements.last,
      };

      if (!targetMet || successRate < 0.8) {
        allTargetsMet = false;
      }
    }

    AppLogger.info('📊 Performance Validation Report:');
    report.forEach((operation, metrics) {
      final status = metrics['target_met'] ? '✅' : '❌';
      AppLogger.info('$status $operation: ${metrics['average_time_ms']}ms (target: ${metrics['target_ms']}ms, success: ${(metrics['success_rate'] * 100).toStringAsFixed(1)}%)');
    });

    return allTargetsMet;
  }

  /// Get success rate for an operation
  double _getSuccessRate(String operation) {
    final successes = _successCount[operation] ?? 0;
    final failures = _failureCount[operation] ?? 0;
    final total = successes + failures;
    
    if (total == 0) return 1.0;
    return successes / total;
  }

  /// Generate comprehensive performance report
  void _generatePerformanceReport() {
    if (_performanceHistory.isEmpty) return;

    AppLogger.info('📈 === WAREHOUSE PERFORMANCE REPORT ===');
    
    final allTargetsMet = validateAllTargets();
    
    if (allTargetsMet) {
      AppLogger.info('🎉 ALL PERFORMANCE TARGETS ARE BEING MET!');
    } else {
      AppLogger.warning('⚠️ Some performance targets are not being met');
    }

    // Cache performance
    final cacheStats = WarehouseCacheService.getCacheStats();
    AppLogger.info('💾 Cache Statistics:');
    cacheStats.forEach((key, value) {
      AppLogger.info('   $key: $value');
    });

    AppLogger.info('=== END PERFORMANCE REPORT ===');
  }

  /// Run comprehensive performance test
  Future<bool> runPerformanceTest() async {
    AppLogger.info('🧪 Running comprehensive warehouse performance test...');
    
    try {
      // Test 1: Cache performance
      final cacheTimer = TimedOperation('cache_performance_test');
      await WarehouseCacheService.initialize();
      final cacheDuration = cacheTimer.complete();
      recordPerformance('cache_loading', cacheDuration.inMilliseconds);

      // Test 2: Performance monitor functionality
      final monitorTimer = TimedOperation('performance_monitor_test');
      PerformanceMonitor.startOperation('test_operation');
      await Future.delayed(const Duration(milliseconds: 100));
      PerformanceMonitor.endOperation('test_operation');
      final monitorDuration = monitorTimer.complete();

      // Test 3: Validate current performance state
      final allTargetsMet = validateAllTargets();

      AppLogger.info('🧪 Performance test completed:');
      AppLogger.info('   Cache loading: ${cacheDuration.inMilliseconds}ms');
      AppLogger.info('   Monitor overhead: ${monitorDuration.inMilliseconds}ms');
      AppLogger.info('   All targets met: $allTargetsMet');

      return allTargetsMet;
    } catch (e) {
      AppLogger.error('❌ Performance test failed: $e');
      return false;
    }
  }

  /// Get detailed performance metrics
  Map<String, dynamic> getDetailedMetrics() {
    final metrics = <String, dynamic>{};
    
    for (final operation in _performanceHistory.keys) {
      final measurements = _performanceHistory[operation]!;
      if (measurements.isEmpty) continue;

      final avgTime = measurements.reduce((a, b) => a + b) / measurements.length;
      final minTime = measurements.reduce((a, b) => a < b ? a : b);
      final maxTime = measurements.reduce((a, b) => a > b ? a : b);
      final target = _getPerformanceTarget(operation);
      final successRate = _getSuccessRate(operation);

      metrics[operation] = {
        'average_ms': avgTime.round(),
        'min_ms': minTime,
        'max_ms': maxTime,
        'target_ms': target,
        'target_met': avgTime <= target,
        'success_rate': successRate,
        'sample_count': measurements.length,
        'performance_grade': _getPerformanceGrade(avgTime, target),
      };
    }

    return metrics;
  }

  /// Get performance grade based on target achievement
  String _getPerformanceGrade(double avgTime, int target) {
    final ratio = avgTime / target;
    
    if (ratio <= 0.5) return 'Excellent';
    if (ratio <= 0.7) return 'Good';
    if (ratio <= 0.9) return 'Fair';
    if (ratio <= 1.0) return 'Acceptable';
    return 'Poor';
  }

  /// Dispose of resources
  void dispose() {
    _monitoringTimer?.cancel();
    _performanceHistory.clear();
    _successCount.clear();
    _failureCount.clear();
  }
}
