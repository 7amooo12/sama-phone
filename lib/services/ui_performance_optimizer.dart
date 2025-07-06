import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../utils/app_logger.dart';

/// UI Performance Optimizer Service
/// Provides optimizations for UI rendering, widget rebuilds, and memory usage
class UIPerformanceOptimizer {
  static const int _maxCacheSize = 100;
  static final Map<String, Widget> _widgetCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 5);

  /// Optimize ListView.builder for better performance
  static Widget optimizedListView({
    required int itemCount,
    required Widget Function(BuildContext, int) itemBuilder,
    ScrollController? controller,
    EdgeInsets? padding,
    bool shrinkWrap = false,
    ScrollPhysics? physics,
    bool addRepaintBoundary = true,
  }) {
    return ListView.builder(
      controller: controller,
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics ?? const BouncingScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        Widget child = itemBuilder(context, index);
        
        if (addRepaintBoundary) {
          child = RepaintBoundary(child: child);
        }
        
        return child;
      },
      // Performance optimizations
      cacheExtent: 250.0, // Cache 250 pixels beyond viewport
      addAutomaticKeepAlives: false, // Don't keep alive by default
      addRepaintBoundaries: addRepaintBoundary,
    );
  }

  /// Optimize GridView.builder for better performance
  static Widget optimizedGridView({
    required int itemCount,
    required Widget Function(BuildContext, int) itemBuilder,
    required SliverGridDelegate gridDelegate,
    ScrollController? controller,
    EdgeInsets? padding,
    bool shrinkWrap = false,
    ScrollPhysics? physics,
    bool addRepaintBoundary = true,
  }) {
    return GridView.builder(
      controller: controller,
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics ?? const BouncingScrollPhysics(),
      gridDelegate: gridDelegate,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        Widget child = itemBuilder(context, index);
        
        if (addRepaintBoundary) {
          child = RepaintBoundary(child: child);
        }
        
        return child;
      },
      // Performance optimizations
      cacheExtent: 250.0,
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: addRepaintBoundary,
    );
  }

  /// Wrap widget with RepaintBoundary for better performance
  static Widget withRepaintBoundary(Widget child, {String? debugLabel}) {
    return RepaintBoundary(
      child: child,
    );
  }

  /// Optimize expensive widgets with caching
  static Widget cachedWidget({
    required String cacheKey,
    required Widget Function() builder,
    Duration? customExpiry,
  }) {
    final now = DateTime.now();
    final expiry = customExpiry ?? _cacheExpiry;
    
    // Check if cached widget exists and is not expired
    if (_widgetCache.containsKey(cacheKey)) {
      final timestamp = _cacheTimestamps[cacheKey];
      if (timestamp != null && now.difference(timestamp) < expiry) {
        return _widgetCache[cacheKey]!;
      }
    }
    
    // Clean up expired cache entries
    _cleanupExpiredCache();
    
    // Build new widget and cache it
    final widget = builder();
    
    // Limit cache size
    if (_widgetCache.length >= _maxCacheSize) {
      final oldestKey = _cacheTimestamps.entries
          .reduce((a, b) => a.value.isBefore(b.value) ? a : b)
          .key;
      _widgetCache.remove(oldestKey);
      _cacheTimestamps.remove(oldestKey);
    }
    
    _widgetCache[cacheKey] = widget;
    _cacheTimestamps[cacheKey] = now;
    
    return widget;
  }

  /// Clean up expired cache entries
  static void _cleanupExpiredCache() {
    final now = DateTime.now();
    final expiredKeys = <String>[];
    
    _cacheTimestamps.forEach((key, timestamp) {
      if (now.difference(timestamp) > _cacheExpiry) {
        expiredKeys.add(key);
      }
    });
    
    for (final key in expiredKeys) {
      _widgetCache.remove(key);
      _cacheTimestamps.remove(key);
    }
  }

  /// Clear widget cache
  static void clearCache() {
    _widgetCache.clear();
    _cacheTimestamps.clear();
    AppLogger.info('🧹 UI widget cache cleared');
  }

  /// Optimize AnimatedBuilder for better performance
  static Widget optimizedAnimatedBuilder({
    required Animation<double> animation,
    required Widget Function(BuildContext, Widget?) builder,
    Widget? child,
  }) {
    return AnimatedBuilder(
      animation: animation,
      builder: builder,
      child: child != null ? RepaintBoundary(child: child) : null,
    );
  }

  /// Create optimized Consumer widget that only rebuilds when necessary
  static Widget optimizedConsumer<T extends ChangeNotifier>({
    required Widget Function(BuildContext, T, Widget?) builder,
    Widget? child,
    bool Function(T)? shouldRebuild,
  }) {
    return Consumer<T>(
      builder: (context, value, child) {
        // Optional rebuild condition
        if (shouldRebuild != null && !shouldRebuild(value)) {
          return child ?? const SizedBox.shrink();
        }
        return builder(context, value, child);
      },
      child: child,
    );
  }

  /// Optimize image loading with proper caching
  static Widget optimizedNetworkImage({
    required String imageUrl,
    double? width,
    double? height,
    BoxFit? fit,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return placeholder ?? 
          SizedBox(
            width: width,
            height: height,
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
      },
      errorBuilder: (context, error, stackTrace) {
        return errorWidget ?? 
          SizedBox(
            width: width,
            height: height,
            child: const Icon(Icons.error),
          );
      },
      // Performance optimizations
      cacheWidth: width?.toInt(),
      cacheHeight: height?.toInt(),
      isAntiAlias: true,
      filterQuality: FilterQuality.medium,
    );
  }

  /// Get cache statistics
  static Map<String, dynamic> getCacheStats() {
    return {
      'cached_widgets': _widgetCache.length,
      'max_cache_size': _maxCacheSize,
      'cache_expiry_minutes': _cacheExpiry.inMinutes,
      'oldest_cache_entry': _cacheTimestamps.values.isNotEmpty
          ? _cacheTimestamps.values.reduce((a, b) => a.isBefore(b) ? a : b)
          : null,
    };
  }

  /// Apply global performance optimizations
  static void applyGlobalOptimizations() {
    // Optimize image cache
    PaintingBinding.instance.imageCache.maximumSizeBytes = 100 * 1024 * 1024; // 100MB
    PaintingBinding.instance.imageCache.maximumSize = 1000;
    
    // Optimize rendering
    if (kDebugMode) {
      // Enable performance overlay in debug mode
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppLogger.info('🚀 UI Performance optimizations applied');
      });
    }
  }
}

/// Extension for easy performance optimization
extension PerformanceOptimization on Widget {
  /// Wrap widget with RepaintBoundary
  Widget withRepaintBoundary({String? debugLabel}) {
    return UIPerformanceOptimizer.withRepaintBoundary(this, debugLabel: debugLabel);
  }
  
  /// Cache expensive widget
  Widget cached(String cacheKey, {Duration? expiry}) {
    return UIPerformanceOptimizer.cachedWidget(
      cacheKey: cacheKey,
      builder: () => this,
      customExpiry: expiry,
    );
  }
}
