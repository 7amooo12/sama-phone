import 'package:flutter/foundation.dart';
import '../utils/app_logger.dart';
import 'ui_performance_optimizer.dart';
import 'memory_optimizer.dart';
import 'database_performance_optimizer.dart';
import 'arabic_rtl_optimizer.dart';

/// Performance Dashboard
/// Provides comprehensive performance monitoring and reporting
class PerformanceDashboard {
  static final Map<String, PerformanceMetric> _metrics = {};
  static DateTime _lastReport = DateTime.now();
  
  /// Initialize performance dashboard
  static void initialize() {
    if (kDebugMode) {
      AppLogger.info('📊 Performance dashboard initialized');
      
      // Generate initial report
      generateReport();
    }
  }

  /// Record a performance metric
  static void recordMetric({
    required String name,
    required double value,
    required String unit,
    String? category,
    Map<String, dynamic>? metadata,
  }) {
    final metric = PerformanceMetric(
      name: name,
      value: value,
      unit: unit,
      category: category ?? 'general',
      timestamp: DateTime.now(),
      metadata: metadata ?? {},
    );
    
    _metrics[name] = metric;
    
    if (kDebugMode && value > _getThreshold(name)) {
      AppLogger.warning('⚠️ Performance threshold exceeded: $name = $value$unit');
    }
  }

  /// Get performance threshold for a metric
  static double _getThreshold(String metricName) {
    const thresholds = {
      'frame_time': 16.67, // 60 FPS = 16.67ms per frame
      'memory_usage_mb': 500.0, // 500MB memory usage
      'query_time_ms': 1000.0, // 1 second query time
      'cache_hit_ratio': 0.8, // 80% cache hit ratio
      'ui_rebuild_count': 10.0, // 10 rebuilds per second
    };
    
    return thresholds[metricName] ?? double.infinity;
  }

  /// Generate comprehensive performance report
  static Map<String, dynamic> generateReport() {
    final now = DateTime.now();
    final report = {
      'timestamp': now.toIso8601String(),
      'duration_since_last_report': now.difference(_lastReport).inSeconds,
      'ui_performance': _getUIPerformanceStats(),
      'memory_performance': _getMemoryStats(),
      'database_performance': _getDatabaseStats(),
      'arabic_rtl_performance': _getArabicRTLStats(),
      'custom_metrics': _getCustomMetrics(),
      'performance_grade': _calculatePerformanceGrade(),
      'recommendations': _generateRecommendations(),
    };
    
    _lastReport = now;
    
    if (kDebugMode) {
      _logReport(report);
    }
    
    return report;
  }

  /// Get UI performance statistics
  static Map<String, dynamic> _getUIPerformanceStats() {
    try {
      return UIPerformanceOptimizer.getCacheStats();
    } catch (e) {
      return {'error': 'Failed to get UI stats: $e'};
    }
  }

  /// Get memory performance statistics
  static Map<String, dynamic> _getMemoryStats() {
    try {
      return MemoryOptimizer.getMemoryStats();
    } catch (e) {
      return {'error': 'Failed to get memory stats: $e'};
    }
  }

  /// Get database performance statistics
  static Map<String, dynamic> _getDatabaseStats() {
    try {
      return {
        'cache_stats': DatabasePerformanceOptimizer.getCacheStats(),
        'query_stats': DatabasePerformanceOptimizer.getQueryStats().length,
      };
    } catch (e) {
      return {'error': 'Failed to get database stats: $e'};
    }
  }

  /// Get Arabic RTL performance statistics
  static Map<String, dynamic> _getArabicRTLStats() {
    try {
      return ArabicRTLOptimizer.getCacheStats();
    } catch (e) {
      return {'error': 'Failed to get Arabic RTL stats: $e'};
    }
  }

  /// Get custom metrics
  static Map<String, dynamic> _getCustomMetrics() {
    final customMetrics = <String, dynamic>{};
    
    _metrics.forEach((name, metric) {
      customMetrics[name] = {
        'value': metric.value,
        'unit': metric.unit,
        'category': metric.category,
        'timestamp': metric.timestamp.toIso8601String(),
        'metadata': metric.metadata,
      };
    });
    
    return customMetrics;
  }

  /// Calculate overall performance grade
  static String _calculatePerformanceGrade() {
    final scores = <double>[];
    
    // UI Performance Score (0-100)
    final uiStats = _getUIPerformanceStats();
    if (uiStats.containsKey('cached_widgets')) {
      final cacheEfficiency = (uiStats['cached_widgets'] as int) / 100.0;
      scores.add((cacheEfficiency * 100).clamp(0, 100));
    }
    
    // Memory Performance Score (0-100)
    final memoryStats = _getMemoryStats();
    if (memoryStats.containsKey('last_memory_usage_mb')) {
      final memoryUsage = double.tryParse(memoryStats['last_memory_usage_mb'] ?? '0') ?? 0;
      final memoryScore = (500 - memoryUsage).clamp(0, 500) / 500 * 100;
      scores.add(memoryScore);
    }
    
    // Database Performance Score (0-100)
    final dbStats = _getDatabaseStats();
    if (dbStats.containsKey('cache_stats')) {
      final cacheStats = dbStats['cache_stats'] as Map<String, dynamic>;
      final hitRatio = cacheStats['cache_hit_ratio'] ?? 0.0;
      scores.add(hitRatio * 100);
    }
    
    // Calculate average score
    final averageScore = scores.isNotEmpty 
        ? scores.reduce((a, b) => a + b) / scores.length 
        : 50.0;
    
    if (averageScore >= 90) return 'Excellent';
    if (averageScore >= 80) return 'Good';
    if (averageScore >= 70) return 'Fair';
    if (averageScore >= 60) return 'Poor';
    return 'Critical';
  }

  /// Generate performance recommendations
  static List<String> _generateRecommendations() {
    final recommendations = <String>[];
    
    // Check memory usage
    final memoryStats = _getMemoryStats();
    final memoryUsage = double.tryParse(memoryStats['last_memory_usage_mb'] ?? '0') ?? 0;
    if (memoryUsage > 400) {
      recommendations.add('High memory usage detected. Consider clearing caches or optimizing image loading.');
    }
    
    // Check cache efficiency
    final dbStats = _getDatabaseStats();
    if (dbStats.containsKey('cache_stats')) {
      final cacheStats = dbStats['cache_stats'] as Map<String, dynamic>;
      final hitRatio = cacheStats['cache_hit_ratio'] ?? 0.0;
      if (hitRatio < 0.7) {
        recommendations.add('Low database cache hit ratio. Consider increasing cache duration or preloading data.');
      }
    }
    
    // Check UI performance
    final uiStats = _getUIPerformanceStats();
    final cachedWidgets = uiStats['cached_widgets'] ?? 0;
    if (cachedWidgets < 10) {
      recommendations.add('Low UI widget caching. Consider caching expensive widgets for better performance.');
    }
    
    // Check custom metrics
    _metrics.forEach((name, metric) {
      if (metric.value > _getThreshold(name)) {
        recommendations.add('$name is above threshold (${metric.value}${metric.unit}). Consider optimization.');
      }
    });
    
    if (recommendations.isEmpty) {
      recommendations.add('Performance is optimal. No recommendations at this time.');
    }
    
    return recommendations;
  }

  /// Log performance report
  static void _logReport(Map<String, dynamic> report) {
    AppLogger.info('📊 Performance Report Generated');
    AppLogger.info('🎯 Performance Grade: ${report['performance_grade']}');
    
    final recommendations = report['recommendations'] as List<String>;
    if (recommendations.isNotEmpty) {
      AppLogger.info('💡 Recommendations:');
      for (int i = 0; i < recommendations.length; i++) {
        AppLogger.info('   ${i + 1}. ${recommendations[i]}');
      }
    }
  }

  /// Get performance metrics for a specific category
  static Map<String, PerformanceMetric> getMetricsByCategory(String category) {
    return Map.fromEntries(
      _metrics.entries.where((entry) => entry.value.category == category),
    );
  }

  /// Clear all metrics
  static void clearMetrics() {
    _metrics.clear();
    AppLogger.info('🧹 Performance metrics cleared');
  }

  /// Get metric by name
  static PerformanceMetric? getMetric(String name) {
    return _metrics[name];
  }

  /// Check if performance is healthy
  static bool isPerformanceHealthy() {
    final grade = _calculatePerformanceGrade();
    return ['Excellent', 'Good'].contains(grade);
  }

  /// Trigger performance optimization if needed
  static void optimizeIfNeeded() {
    if (!isPerformanceHealthy()) {
      AppLogger.warning('⚠️ Performance issues detected, triggering optimizations...');
      
      // Trigger memory cleanup
      MemoryOptimizer.performCleanup();
      
      // Clear UI cache
      UIPerformanceOptimizer.clearCache();
      
      // Clear database cache if hit ratio is low
      final dbStats = _getDatabaseStats();
      if (dbStats.containsKey('cache_stats')) {
        final cacheStats = dbStats['cache_stats'] as Map<String, dynamic>;
        final hitRatio = cacheStats['cache_hit_ratio'] ?? 0.0;
        if (hitRatio < 0.5) {
          DatabasePerformanceOptimizer.clearCache();
        }
      }
      
      AppLogger.info('✅ Performance optimizations completed');
    }
  }

  /// Dispose performance dashboard
  static void dispose() {
    clearMetrics();
    AppLogger.info('📊 Performance dashboard disposed');
  }
}

/// Performance metric data structure
class PerformanceMetric {
  final String name;
  final double value;
  final String unit;
  final String category;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  PerformanceMetric({
    required this.name,
    required this.value,
    required this.unit,
    required this.category,
    required this.timestamp,
    required this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'value': value,
      'unit': unit,
      'category': category,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
    };
  }
}
