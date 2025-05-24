import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:smartbiztracker_new/utils/tab_optimization_service.dart';
import 'package:smartbiztracker_new/utils/logger.dart';

/// Service for managing app-wide performance optimizations
class AppPerformanceService {
  static final AppPerformanceService _instance = AppPerformanceService._internal();
  factory AppPerformanceService() => _instance;
  
  static const MethodChannel _performanceChannel = MethodChannel('smartbiztracker/performance');
  
  /// Whether performance optimizations have been applied
  bool _optimizationsApplied = false;
  
  /// List of widgets that are excessively rebuilding
  final Set<String> _problematicWidgets = {};
  
  AppPerformanceService._internal();
  
  /// Initialize performance optimizations
  Future<void> initializePerformance() async {
    if (_optimizationsApplied) return;
    
    AppLogger.info('Initializing app performance optimizations');
    
    try {
      // Apply memory optimizations
      TabOptimizationService.applyMemoryOptimizations();
      
      // Optimize image cache on Android platform
      if (!kIsWeb) {
        try {
          await _performanceChannel.invokeMethod('optimizeImageCache');
          await _performanceChannel.invokeMethod('optimizeRenderingPerformance');
          AppLogger.info('Native performance optimizations applied');
        } catch (e) {
          // Ignore errors from method channel (might not be available on all platforms)
          AppLogger.warning('Native performance optimizations not available: $e');
        }
      }
      
      // Register error handlers to prevent app crashes
      FlutterError.onError = (FlutterErrorDetails details) {
        // Log the error but prevent app crash
        AppLogger.error('Flutter error: ${details.exception}');
        AppLogger.error('Stack trace: ${details.stack}');
        
        // Report non-fatal error to the error reporting service
        // (would be implemented in a real app)
        
        // Don't crash the app for non-critical errors
        if (details.exception is! AssertionError) {
          FlutterError.dumpErrorToConsole(details);
        }
      };
      
      _optimizationsApplied = true;
    } catch (e) {
      AppLogger.error('Failed to apply performance optimizations: $e');
    }
  }
  
  /// Optimize a specific screen to prevent blank white pages
  void optimizeScreen(BuildContext context, String screenName) {
    // Force a frame render
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Ensure screen is rendered properly
      WidgetsBinding.instance.scheduleForcedFrame();
      
      // Precache commonly used assets
      _precacheAssets(context);
    });
  }
  
  /// Pre-cache commonly used assets for better performance
  Future<void> _precacheAssets(BuildContext context) async {
    try {
      // Add your app's commonly used images here
      const commonImages = [
        'assets/logo.png',
        'assets/icon_dashboard.png',
        'assets/icon_orders.png',
        'assets/icon_products.png',
      ];
      
      for (final assetPath in commonImages) {
        try {
          precacheImage(AssetImage(assetPath), context);
        } catch (e) {
          // Ignore if asset not found
        }
      }
    } catch (e) {
      AppLogger.warning('Failed to precache assets: $e');
    }
  }
  
  /// Optimize TabBarView to prevent blank screens
  TabBarView optimizeTabBarView({
    required TabController controller,
    required List<Widget> children,
    bool keepAlive = true,
  }) {
    return TabOptimizationService.optimizedTabBarView(
      controller: controller,
      children: children,
      keepAlive: keepAlive,
      deferRendering: true,
    );
  }
  
  /// Report a problematic widget that may be causing performance issues
  void reportProblematicWidget(String widgetName) {
    _problematicWidgets.add(widgetName);
    AppLogger.warning('Problematic widget detected: $widgetName');
    
    if (_problematicWidgets.length > 5) {
      // Too many problematic widgets, recommend action
      AppLogger.error('Multiple problematic widgets detected: $_problematicWidgets');
    }
  }
  
  /// Monitor excessive rebuilds
  void monitorRebuild(String widgetName) {
    // In development mode, track excessive rebuilds
    if (kDebugMode) {
      final rebuildCounter = _RebuildCounter();
      rebuildCounter.increment(widgetName);
      
      if (rebuildCounter.getRebuildCount(widgetName) > 10) {
        AppLogger.warning('Widget $widgetName is rebuilding excessively');
      }
    }
  }
}

/// Helper class to track widget rebuilds
class _RebuildCounter {
  static final Map<String, int> _counts = {};
  static final Stopwatch _stopwatch = Stopwatch()..start();
  static const int _resetThresholdMs = 5000; // Reset counters every 5 seconds
  
  void increment(String key) {
    if (_stopwatch.elapsedMilliseconds > _resetThresholdMs) {
      _counts.clear();
      _stopwatch.reset();
      _stopwatch.start();
    }
    
    _counts[key] = (_counts[key] ?? 0) + 1;
  }
  
  int getRebuildCount(String key) {
    return _counts[key] ?? 0;
  }
} 