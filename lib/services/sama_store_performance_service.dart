import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// Performance optimization service specifically for SamaStore product browsing
/// Ensures smooth 3D animations and optimal card rendering
class SamaStorePerformanceService {
  
  factory SamaStorePerformanceService() => _instance;
  
  SamaStorePerformanceService._internal();
  static final SamaStorePerformanceService _instance = SamaStorePerformanceService._internal();

  // Performance monitoring
  bool _isMonitoring = false;
  final List<double> _frameTimes = [];
  int _frameDropCount = 0;
  int _totalFrames = 0;
  DateTime? _lastResetTime;

  // Performance thresholds
  static const double _targetFrameTime = 16.67; // 60fps
  static const double _criticalFrameTime = 33.33; // 30fps
  static const int _maxFrameHistory = 100;

  /// Start performance monitoring for SamaStore
  void startMonitoring() {
    if (_isMonitoring) return;
    
    _isMonitoring = true;
    _lastResetTime = DateTime.now();
    
    if (kDebugMode) {
      AppLogger.info('🚀 SamaStore performance monitoring started');
      WidgetsBinding.instance.addTimingsCallback(_onFrameTimings);
    }
  }

  /// Stop performance monitoring
  void stopMonitoring() {
    if (!_isMonitoring) return;
    
    _isMonitoring = false;
    
    if (kDebugMode) {
      WidgetsBinding.instance.removeTimingsCallback(_onFrameTimings);
      AppLogger.info('⏹️ SamaStore performance monitoring stopped');
    }
  }

  /// Handle frame timing data
  void _onFrameTimings(List<FrameTiming> timings) {
    if (!_isMonitoring) return;

    for (final timing in timings) {
      _totalFrames++;
      final frameDuration = timing.totalSpan.inMicroseconds / 1000.0; // Convert to milliseconds
      
      _frameTimes.add(frameDuration);
      
      if (frameDuration > _targetFrameTime) {
        _frameDropCount++;
        
        // Log critical frame drops for 3D animations
        if (frameDuration > _criticalFrameTime) {
          AppLogger.warning('🔥 SamaStore critical frame drop: ${frameDuration.toStringAsFixed(1)}ms (target: ${_targetFrameTime.toStringAsFixed(1)}ms)');
        }
      }
    }

    // Keep only recent frame times
    if (_frameTimes.length > _maxFrameHistory) {
      _frameTimes.removeRange(0, _frameTimes.length - _maxFrameHistory);
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
    if (_frameTimes.isEmpty) return;

    final avgFrameTime = _frameTimes.reduce((a, b) => a + b) / _frameTimes.length;
    final maxFrameTime = _frameTimes.reduce((a, b) => a > b ? a : b);
    final frameDropRate = (_frameDropCount / _totalFrames) * 100;

    AppLogger.info('📊 SamaStore Performance Stats:');
    AppLogger.info('   Average frame time: ${avgFrameTime.toStringAsFixed(1)}ms');
    AppLogger.info('   Max frame time: ${maxFrameTime.toStringAsFixed(1)}ms');
    AppLogger.info('   Frame drop rate: ${frameDropRate.toStringAsFixed(1)}%');
    AppLogger.info('   Total frames: $_totalFrames');

    if (frameDropRate > 10) {
      AppLogger.warning('⚠️ High frame drop rate detected in SamaStore');
    }
  }

  /// Reset performance counters
  void _resetCounters() {
    _frameDropCount = 0;
    _totalFrames = 0;
    _lastResetTime = DateTime.now();
  }

  /// Get optimized grid delegate for product cards
  static SliverGridDelegate createOptimized3DGridDelegate({
    required int crossAxisCount,
    required double crossAxisSpacing,
    required double mainAxisSpacing,
    required double childAspectRatio,
  }) {
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: crossAxisSpacing,
      mainAxisSpacing: mainAxisSpacing,
      childAspectRatio: childAspectRatio,
    );
  }

  /// Check if device can handle 3D animations smoothly
  bool canHandle3DAnimations() {
    if (_frameTimes.isEmpty) return true; // Assume yes if no data

    final avgFrameTime = _frameTimes.reduce((a, b) => a + b) / _frameTimes.length;
    final frameDropRate = (_frameDropCount / _totalFrames) * 100;

    // Device can handle 3D if average frame time < 20ms and drop rate < 15%
    return avgFrameTime < 20.0 && frameDropRate < 15.0;
  }

  /// Get recommended animation duration based on performance
  Duration getOptimized3DAnimationDuration(Duration defaultDuration) {
    if (!canHandle3DAnimations()) {
      // Reduce animation duration for slower devices
      return Duration(milliseconds: (defaultDuration.inMilliseconds * 0.7).round());
    }
    return defaultDuration;
  }

  /// Get performance statistics
  Map<String, dynamic> getPerformanceStats() {
    if (_frameTimes.isEmpty) {
      return {
        'averageFrameTime': 0.0,
        'maxFrameTime': 0.0,
        'frameDropRate': 0.0,
        'totalFrames': _totalFrames,
        'canHandle3D': true,
      };
    }

    final avgFrameTime = _frameTimes.reduce((a, b) => a + b) / _frameTimes.length;
    final maxFrameTime = _frameTimes.reduce((a, b) => a > b ? a : b);
    final frameDropRate = (_frameDropCount / _totalFrames) * 100;

    return {
      'averageFrameTime': avgFrameTime,
      'maxFrameTime': maxFrameTime,
      'frameDropRate': frameDropRate,
      'totalFrames': _totalFrames,
      'canHandle3D': canHandle3DAnimations(),
    };
  }

  /// Optimize widget for 3D card rendering
  static Widget optimize3DCard(Widget child, {String? debugLabel}) {
    return RepaintBoundary(
      child: child,
    );
  }

  /// Pre-warm shaders for 3D animations
  static void preWarmShaders(BuildContext context) {
    if (kDebugMode) {
      AppLogger.info('🔥 Pre-warming shaders for 3D animations');
    }

    // Pre-warm common shaders used in 3D cards
    Future.microtask(() {
      final canvas = Canvas(PictureRecorder());
      final paint = Paint();

      // Warm up gradient shader
      paint.shader = const LinearGradient(
        colors: [Colors.blue, Colors.purple],
      ).createShader(const Rect.fromLTWH(0, 0, 100, 100));
      canvas.drawRect(const Rect.fromLTWH(0, 0, 100, 100), paint);

      // Warm up shadow shader
      paint.shader = null;
      paint.color = Colors.black.withValues(alpha: 0.3);
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawRect(const Rect.fromLTWH(0, 0, 100, 100), paint);
    });
  }

  /// Dispose resources
  void dispose() {
    stopMonitoring();
    _frameTimes.clear();
  }
}

/// Extension for easy 3D card optimization
extension SamaStore3DOptimization on Widget {
  /// Wrap widget with 3D card optimizations
  Widget optimizedFor3D({String? debugLabel}) {
    return SamaStorePerformanceService.optimize3DCard(this, debugLabel: debugLabel);
  }
}

/// Mixin for SamaStore screens with 3D animations
mixin SamaStore3DPerformanceMixin<T extends StatefulWidget> on State<T> {
  final _performanceService = SamaStorePerformanceService();

  @override
  void initState() {
    super.initState();
    _performanceService.startMonitoring();
    
    // Pre-warm shaders after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SamaStorePerformanceService.preWarmShaders(context);
    });
  }

  @override
  void dispose() {
    _performanceService.stopMonitoring();
    super.dispose();
  }

  /// Get optimized animation duration for 3D effects
  Duration get get3DAnimationDuration => _performanceService.getOptimized3DAnimationDuration(
    const Duration(milliseconds: 600),
  );

  /// Check if device can handle 3D animations
  bool get canHandle3DAnimations => _performanceService.canHandle3DAnimations();

  /// Execute 3D animation with performance monitoring
  Future<void> execute3DAnimation(
    String animationName,
    Future<void> Function() animation,
  ) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      await animation();
      stopwatch.stop();
      
      if (kDebugMode && stopwatch.elapsedMilliseconds > 100) {
        AppLogger.warning('⚠️ Slow 3D animation: $animationName took ${stopwatch.elapsedMilliseconds}ms');
      }
    } catch (e) {
      stopwatch.stop();
      AppLogger.error('❌ 3D animation failed: $animationName after ${stopwatch.elapsedMilliseconds}ms', e);
      rethrow;
    }
  }
}
