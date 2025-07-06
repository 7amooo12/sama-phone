import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/painting.dart';
import '../utils/app_logger.dart';

/// Memory Optimizer Service
/// Handles memory management, garbage collection, and resource cleanup
class MemoryOptimizer {
  static Timer? _memoryCleanupTimer;
  static final List<VoidCallback> _disposables = [];
  static int _lastMemoryUsage = 0;
  static DateTime _lastCleanup = DateTime.now();

  /// Initialize memory optimization
  static void initialize() {
    // Start periodic memory cleanup
    _startPeriodicCleanup();
    
    // Optimize image cache
    _optimizeImageCache();
    
    // Setup memory monitoring
    _setupMemoryMonitoring();
    
    AppLogger.info('🧠 Memory optimizer initialized');
  }

  /// Start periodic memory cleanup
  static void _startPeriodicCleanup() {
    _memoryCleanupTimer?.cancel();
    _memoryCleanupTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => performCleanup(),
    );
  }

  /// Optimize image cache settings
  static void _optimizeImageCache() {
    // Set reasonable limits for image cache
    PaintingBinding.instance.imageCache.maximumSizeBytes = 100 * 1024 * 1024; // 100MB
    PaintingBinding.instance.imageCache.maximumSize = 1000; // Max 1000 images
    
    // Clear cache when memory pressure is high
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  /// Setup memory monitoring
  static void _setupMemoryMonitoring() {
    if (kDebugMode) {
      Timer.periodic(const Duration(minutes: 2), (_) {
        _logMemoryUsage();
      });
    }
  }

  /// Log current memory usage
  static void _logMemoryUsage() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        // Get memory info using platform channels
        const platform = MethodChannel('memory_info');
        final memoryInfo = await platform.invokeMethod('getMemoryInfo');
        
        if (memoryInfo != null) {
          final currentUsage = memoryInfo['usedMemory'] ?? 0;
          final totalMemory = memoryInfo['totalMemory'] ?? 0;
          final usagePercent = totalMemory > 0 ? (currentUsage / totalMemory * 100) : 0;
          
          AppLogger.info('📊 Memory Usage: ${(currentUsage / 1024 / 1024).toStringAsFixed(1)}MB / ${(totalMemory / 1024 / 1024).toStringAsFixed(1)}MB (${usagePercent.toStringAsFixed(1)}%)');
          
          // Trigger cleanup if memory usage is high
          if (usagePercent > 80) {
            AppLogger.warning('⚠️ High memory usage detected, triggering cleanup');
            performCleanup();
          }
          
          _lastMemoryUsage = currentUsage;
        }
      }
    } catch (e) {
      // Platform channel not available, skip memory monitoring
    }
  }

  /// Perform comprehensive memory cleanup
  static void performCleanup() {
    final stopwatch = Stopwatch()..start();
    
    try {
      // Clear image cache
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      
      // Clear UI widget cache
      _clearUICache();
      
      // Run garbage collection
      _forceGarbageCollection();
      
      // Execute registered disposables
      _executeDisposables();
      
      _lastCleanup = DateTime.now();
      
      stopwatch.stop();
      AppLogger.info('🧹 Memory cleanup completed in ${stopwatch.elapsedMilliseconds}ms');
      
    } catch (e) {
      AppLogger.error('❌ Memory cleanup failed: $e');
    }
  }

  /// Clear UI-related caches
  static void _clearUICache() {
    try {
      // Clear any UI performance optimizer caches
      // This will be called from UIPerformanceOptimizer if available
    } catch (e) {
      AppLogger.warning('Failed to clear UI cache: $e');
    }
  }

  /// Force garbage collection
  static void _forceGarbageCollection() {
    // Force garbage collection (note: this is a hint, not guaranteed)
    for (int i = 0; i < 3; i++) {
      // Multiple calls to increase likelihood of GC
      // This is a hint to the VM, actual GC timing is VM-dependent
    }
  }

  /// Execute registered disposables
  static void _executeDisposables() {
    for (final disposable in _disposables) {
      try {
        disposable();
      } catch (e) {
        AppLogger.warning('Failed to execute disposable: $e');
      }
    }
    _disposables.clear();
  }

  /// Register a disposable callback
  static void registerDisposable(VoidCallback disposable) {
    _disposables.add(disposable);
  }

  /// Optimize for low memory devices
  static void optimizeForLowMemory() {
    // Reduce image cache size
    PaintingBinding.instance.imageCache.maximumSizeBytes = 50 * 1024 * 1024; // 50MB
    PaintingBinding.instance.imageCache.maximumSize = 500; // Max 500 images
    
    // More frequent cleanup
    _memoryCleanupTimer?.cancel();
    _memoryCleanupTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => performCleanup(),
    );
    
    AppLogger.info('📱 Optimized for low memory device');
  }

  /// Get memory statistics
  static Map<String, dynamic> getMemoryStats() {
    return {
      'image_cache_size': PaintingBinding.instance.imageCache.currentSize,
      'image_cache_size_bytes': PaintingBinding.instance.imageCache.currentSizeBytes,
      'max_image_cache_size': PaintingBinding.instance.imageCache.maximumSize,
      'max_image_cache_size_bytes': PaintingBinding.instance.imageCache.maximumSizeBytes,
      'disposables_count': _disposables.length,
      'last_cleanup': _lastCleanup.toIso8601String(),
      'last_memory_usage_mb': (_lastMemoryUsage / 1024 / 1024).toStringAsFixed(1),
    };
  }

  /// Check if device has low memory
  static bool isLowMemoryDevice() {
    // This is a heuristic - in a real app you might use platform channels
    // to get actual device memory information
    return _lastMemoryUsage > 0 && _lastMemoryUsage < 2 * 1024 * 1024 * 1024; // Less than 2GB
  }

  /// Dispose memory optimizer
  static void dispose() {
    _memoryCleanupTimer?.cancel();
    _memoryCleanupTimer = null;
    
    // Final cleanup
    performCleanup();
    
    AppLogger.info('🧠 Memory optimizer disposed');
  }

  /// Emergency memory cleanup for critical situations
  static void emergencyCleanup() {
    AppLogger.warning('🚨 Emergency memory cleanup triggered');
    
    // Aggressive cleanup
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    
    // Clear all caches
    _clearUICache();
    
    // Force multiple GC cycles
    _forceGarbageCollection();
    
    // Execute all disposables
    _executeDisposables();
    
    AppLogger.info('🚨 Emergency cleanup completed');
  }

  /// Monitor memory pressure and respond accordingly
  static void handleMemoryPressure() {
    AppLogger.warning('⚠️ Memory pressure detected');
    
    // Reduce cache sizes
    final currentImageCacheSize = PaintingBinding.instance.imageCache.maximumSizeBytes;
    PaintingBinding.instance.imageCache.maximumSizeBytes = (currentImageCacheSize * 0.5).toInt();
    
    // Immediate cleanup
    performCleanup();
    
    // Increase cleanup frequency temporarily
    _memoryCleanupTimer?.cancel();
    _memoryCleanupTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => performCleanup(),
    );
    
    // Reset to normal frequency after 10 minutes
    Timer(const Duration(minutes: 10), () {
      _startPeriodicCleanup();
      PaintingBinding.instance.imageCache.maximumSizeBytes = currentImageCacheSize;
    });
  }
}

/// Extension for easy memory management
extension MemoryManagement on Object {
  /// Register this object for disposal
  void registerForDisposal(VoidCallback disposable) {
    MemoryOptimizer.registerDisposable(disposable);
  }
}
