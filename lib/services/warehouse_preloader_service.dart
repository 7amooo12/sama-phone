import 'dart:async';
import 'package:smartbiztracker_new/services/warehouse_service.dart';
import 'package:smartbiztracker_new/services/warehouse_cache_service.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:smartbiztracker_new/utils/performance_monitor.dart';

/// Service for preloading warehouse data in the background during app startup
class WarehousePreloaderService {
  static final WarehousePreloaderService _instance = WarehousePreloaderService._internal();
  factory WarehousePreloaderService() => _instance;
  WarehousePreloaderService._internal();
  
  final WarehouseService _warehouseService = WarehouseService();
  bool _isPreloading = false;
  bool _preloadingCompleted = false;
  Timer? _preloadingTimer;
  
  /// Start background preloading of warehouse data
  Future<void> startBackgroundPreloading() async {
    if (_isPreloading || _preloadingCompleted) {
      AppLogger.info('📦 Warehouse preloading already in progress or completed');
      return;
    }
    
    _isPreloading = true;
    AppLogger.info('🚀 Starting background warehouse data preloading...');
    
    // Start preloading after a short delay to not interfere with app startup
    _preloadingTimer = Timer(const Duration(milliseconds: 500), () {
      _performBackgroundPreloading();
    });
  }
  
  /// Perform the actual background preloading
  Future<void> _performBackgroundPreloading() async {
    try {
      final timer = TimedOperation('warehouse_preloading');
      
      // Phase 1: Preload warehouses list (highest priority)
      await _preloadWarehouses();
      
      // Phase 2: Preload inventory for the first few warehouses (medium priority)
      await _preloadTopWarehousesInventory();
      
      // Phase 3: Warm up cache statistics (lowest priority)
      await _warmUpCacheStatistics();
      
      timer.complete();
      _preloadingCompleted = true;
      _isPreloading = false;
      
      AppLogger.info('✅ Background warehouse preloading completed successfully');
      
      // Log cache statistics
      final cacheStats = WarehouseCacheService.getCacheStats();
      AppLogger.info('📊 Cache statistics after preloading: $cacheStats');
      
    } catch (e) {
      _isPreloading = false;
      AppLogger.error('❌ Background warehouse preloading failed: $e');
    }
  }
  
  /// Preload warehouses list
  Future<void> _preloadWarehouses() async {
    try {
      AppLogger.info('📦 Preloading warehouses list...');
      
      // Load both active and all warehouses for different use cases
      final activeWarehouses = await _warehouseService.getWarehouses(
        activeOnly: true,
        useCache: true,
      );
      
      final allWarehouses = await _warehouseService.getWarehouses(
        activeOnly: false,
        useCache: true,
      );
      
      AppLogger.info('✅ Preloaded ${activeWarehouses.length} active warehouses and ${allWarehouses.length} total warehouses');
    } catch (e) {
      AppLogger.error('❌ Failed to preload warehouses: $e');
    }
  }
  
  /// Preload inventory for the top warehouses (most likely to be accessed first)
  Future<void> _preloadTopWarehousesInventory() async {
    try {
      AppLogger.info('📦 Preloading inventory for top warehouses...');
      
      // Get warehouses first
      final warehouses = await _warehouseService.getWarehouses(
        activeOnly: true,
        useCache: true,
      );
      
      if (warehouses.isEmpty) {
        AppLogger.info('ℹ️ No warehouses found for inventory preloading');
        return;
      }
      
      // Preload inventory for the first 3 warehouses (most likely to be accessed)
      final warehousesToPreload = warehouses.take(3).toList();
      
      for (final warehouse in warehousesToPreload) {
        try {
          AppLogger.info('📦 Preloading inventory for warehouse: ${warehouse.name}');
          
          final inventory = await _warehouseService.getWarehouseInventory(
            warehouse.id,
            useCache: true,
          );
          
          AppLogger.info('✅ Preloaded ${inventory.length} inventory items for ${warehouse.name}');
          
          // Add a small delay between warehouse inventory loads to not overwhelm the system
          await Future.delayed(const Duration(milliseconds: 100));
          
        } catch (e) {
          AppLogger.error('❌ Failed to preload inventory for warehouse ${warehouse.name}: $e');
          // Continue with other warehouses even if one fails
        }
      }
      
      AppLogger.info('✅ Completed inventory preloading for ${warehousesToPreload.length} warehouses');
    } catch (e) {
      AppLogger.error('❌ Failed to preload warehouse inventories: $e');
    }
  }
  
  /// Warm up cache statistics and metadata
  Future<void> _warmUpCacheStatistics() async {
    try {
      AppLogger.info('📊 Warming up cache statistics...');
      
      // Get cache statistics to warm up the cache system
      final cacheStats = WarehouseCacheService.getCacheStats();
      
      // Log some useful statistics
      AppLogger.info('📊 Cache warm-up completed:');
      AppLogger.info('  - Memory warehouses: ${cacheStats['memory_warehouses_count']}');
      AppLogger.info('  - Memory inventory: ${cacheStats['memory_inventory_count']}');
      AppLogger.info('  - Hive warehouses: ${cacheStats['hive_warehouses_count']}');
      AppLogger.info('  - Hive inventory: ${cacheStats['hive_inventory_count']}');
      
    } catch (e) {
      AppLogger.error('❌ Failed to warm up cache statistics: $e');
    }
  }
  
  /// Check if preloading is completed
  bool get isPreloadingCompleted => _preloadingCompleted;
  
  /// Check if preloading is in progress
  bool get isPreloading => _isPreloading;
  
  /// Force restart preloading (useful for testing or manual refresh)
  Future<void> restartPreloading() async {
    AppLogger.info('🔄 Restarting warehouse preloading...');
    
    // Cancel any existing preloading
    _preloadingTimer?.cancel();
    _isPreloading = false;
    _preloadingCompleted = false;
    
    // Start fresh preloading
    await startBackgroundPreloading();
  }
  
  /// Stop preloading if in progress
  void stopPreloading() {
    if (_isPreloading) {
      AppLogger.info('⏹️ Stopping warehouse preloading...');
      _preloadingTimer?.cancel();
      _isPreloading = false;
    }
  }
  
  /// Get preloading status information
  Map<String, dynamic> getPreloadingStatus() {
    return {
      'is_preloading': _isPreloading,
      'preloading_completed': _preloadingCompleted,
      'has_timer': _preloadingTimer != null,
      'timer_is_active': _preloadingTimer?.isActive ?? false,
    };
  }
  
  /// Dispose of resources
  void dispose() {
    _preloadingTimer?.cancel();
    _preloadingTimer = null;
    _isPreloading = false;
    AppLogger.info('🗑️ WarehousePreloaderService disposed');
  }
}
