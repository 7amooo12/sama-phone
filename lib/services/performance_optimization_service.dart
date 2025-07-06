import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// Service for optimizing app performance and monitoring frame rates
class PerformanceOptimizationService {
  factory PerformanceOptimizationService() => _instance;
  PerformanceOptimizationService._internal();
  static final PerformanceOptimizationService _instance = PerformanceOptimizationService._internal();

  static const int _targetFrameTime = 16; // 60fps target
  static const int _warningFrameTime = 33; // 30fps warning threshold
  static const int _criticalFrameTime = 50; // Critical performance threshold

  bool _isMonitoring = false;
  int _frameDropCount = 0;
  int _totalFrames = 0;
  DateTime? _lastResetTime;

  /// Initialize performance monitoring
  void startMonitoring() {
    if (_isMonitoring || !kDebugMode) return;
    
    _isMonitoring = true;
    _lastResetTime = DateTime.now();
    
    WidgetsBinding.instance.addTimingsCallback(_onFrameTimings);
    AppLogger.info('🚀 Performance monitoring started');
  }

  /// Stop performance monitoring
  void stopMonitoring() {
    if (!_isMonitoring) return;
    
    _isMonitoring = false;
    WidgetsBinding.instance.removeTimingsCallback(_onFrameTimings);
    AppLogger.info('⏹️ Performance monitoring stopped');
  }

  /// Handle frame timing data
  void _onFrameTimings(List<FrameTiming> timings) {
    if (!_isMonitoring) return;

    for (final timing in timings) {
      _totalFrames++;
      final frameDuration = timing.totalSpan.inMilliseconds;
      
      if (frameDuration > _targetFrameTime) {
        _frameDropCount++;
        
        // Only log critical performance issues to avoid overhead
        if (frameDuration > _criticalFrameTime) {
          AppLogger.warning('🔥 Critical frame drop: ${frameDuration}ms (target: ${_targetFrameTime}ms)');
        }
      }
    }

    // Reset counters every 30 seconds
    if (_lastResetTime != null && 
        DateTime.now().difference(_lastResetTime!).inSeconds > 30) {
      _logPerformanceStats();
      _resetCounters();
    }
  }

  /// Log performance statistics
  void _logPerformanceStats() {
    if (_totalFrames == 0) return;

    final dropRate = (_frameDropCount / _totalFrames * 100).toStringAsFixed(1);
    AppLogger.info('📊 Performance Stats: $_frameDropCount/$_totalFrames frames dropped ($dropRate%)');
  }

  /// Reset performance counters
  void _resetCounters() {
    _frameDropCount = 0;
    _totalFrames = 0;
    _lastResetTime = DateTime.now();
  }

  /// Get current performance statistics
  Map<String, dynamic> getPerformanceStats() {
    if (_totalFrames == 0) {
      return {
        'totalFrames': 0,
        'frameDrops': 0,
        'dropRate': 0.0,
        'isHealthy': true,
      };
    }

    final dropRate = _frameDropCount / _totalFrames * 100;
    return {
      'totalFrames': _totalFrames,
      'frameDrops': _frameDropCount,
      'dropRate': dropRate,
      'isHealthy': dropRate < 5.0, // Consider healthy if less than 5% drops
    };
  }

  /// Apply general performance optimizations
  static void applyOptimizations() {
    // Optimize image cache
    PaintingBinding.instance.imageCache.maximumSizeBytes = 100 * 1024 * 1024; // 100MB
    PaintingBinding.instance.imageCache.maximumSize = 1000;

    // Optimize scheduler
    if (kDebugMode) {
      SchedulerBinding.instance.addPersistentFrameCallback(_frameCallback);
    }

    AppLogger.info('⚡ Performance optimizations applied');
  }

  /// Frame callback for monitoring
  static void _frameCallback(Duration timestamp) {
    // This runs every frame - keep it minimal
    // Only used for critical performance monitoring
  }

  /// Optimize widget for better performance
  static Widget optimizeWidget(Widget child, {String? debugLabel}) {
    return RepaintBoundary(
      child: child,
    );
  }

  /// Create optimized grid delegate
  static SliverGridDelegate createOptimizedGridDelegate({
    required int crossAxisCount,
    double childAspectRatio = 1.0,
    double crossAxisSpacing = 0.0,
    double mainAxisSpacing = 0.0,
  }) {
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: crossAxisCount,
      childAspectRatio: childAspectRatio,
      crossAxisSpacing: crossAxisSpacing,
      mainAxisSpacing: mainAxisSpacing,
    );
  }

  /// Create optimized list delegate
  static SliverChildDelegate createOptimizedListDelegate({
    required List<Widget> children,
    bool addRepaintBoundaries = true,
  }) {
    if (addRepaintBoundaries) {
      final optimizedChildren = children.map((child) => RepaintBoundary(child: child)).toList();
      return SliverChildListDelegate(optimizedChildren);
    }
    return SliverChildListDelegate(children);
  }

  /// Check if device can handle heavy animations
  static bool canHandleHeavyAnimations() {
    // Simple heuristic - in production, you might want more sophisticated detection
    return !kDebugMode; // Assume release builds can handle more
  }

  /// Get recommended animation duration based on performance
  static Duration getOptimizedAnimationDuration(Duration defaultDuration) {
    if (!canHandleHeavyAnimations()) {
      // Reduce animation duration in debug mode or low-performance scenarios
      return Duration(milliseconds: (defaultDuration.inMilliseconds * 0.7).round());
    }
    return defaultDuration;
  }

  /// Dispose resources
  void dispose() {
    stopMonitoring();
  }
}

/// Extension for easy performance optimization
extension PerformanceOptimization on Widget {
  /// Wrap widget with RepaintBoundary for better performance
  Widget optimized({String? debugLabel}) {
    return PerformanceOptimizationService.optimizeWidget(this, debugLabel: debugLabel);
  }
}
