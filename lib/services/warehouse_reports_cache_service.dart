import 'dart:convert';
import 'package:smartbiztracker_new/models/warehouse_reports_model.dart';
import 'package:smartbiztracker_new/models/warehouse_inventory_model.dart';
import 'package:smartbiztracker_new/models/product_model.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// Enhanced caching service specifically for warehouse reports
class WarehouseReportsCacheService {
  static final WarehouseReportsCacheService _instance = WarehouseReportsCacheService._internal();
  factory WarehouseReportsCacheService() => _instance;
  WarehouseReportsCacheService._internal();

  // Memory cache for fast access
  static final Map<String, dynamic> _memoryCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  
  // Cache expiration durations
  static const Duration _inventoryCacheExpiration = Duration(minutes: 15);
  static const Duration _apiProductsCacheExpiration = Duration(minutes: 30);
  static const Duration _reportCacheExpiration = Duration(minutes: 10);
  static const Duration _warehouseNamesCacheExpiration = Duration(hours: 2);

  /// Cache warehouse inventories with intelligent deduplication
  static Future<void> cacheWarehouseInventories(
    Map<String, List<WarehouseInventoryModel>> inventories,
  ) async {
    try {
      final timestamp = DateTime.now();
      
      for (final entry in inventories.entries) {
        final warehouseId = entry.key;
        final inventory = entry.value;
        
        final cacheKey = 'warehouse_inventory_$warehouseId';
        _memoryCache[cacheKey] = inventory;
        _cacheTimestamps[cacheKey] = timestamp;
      }
      
      AppLogger.info('💾 Cached inventories for ${inventories.length} warehouses');
    } catch (e) {
      AppLogger.error('❌ Failed to cache warehouse inventories: $e');
    }
  }

  /// Get cached warehouse inventory
  static List<WarehouseInventoryModel>? getCachedWarehouseInventory(String warehouseId) {
    try {
      final cacheKey = 'warehouse_inventory_$warehouseId';
      final timestamp = _cacheTimestamps[cacheKey];
      
      if (timestamp != null && 
          DateTime.now().difference(timestamp) < _inventoryCacheExpiration) {
        final cached = _memoryCache[cacheKey] as List<WarehouseInventoryModel>?;
        if (cached != null) {
          AppLogger.info('⚡ Retrieved warehouse inventory from cache: $warehouseId');
          return cached;
        }
      }
      
      return null;
    } catch (e) {
      AppLogger.error('❌ Failed to get cached warehouse inventory: $e');
      return null;
    }
  }

  /// Cache API products
  static Future<void> cacheApiProducts(List<ApiProductModel> products) async {
    try {
      const cacheKey = 'api_products';
      final timestamp = DateTime.now();
      
      _memoryCache[cacheKey] = products;
      _cacheTimestamps[cacheKey] = timestamp;
      
      AppLogger.info('💾 Cached ${products.length} API products');
    } catch (e) {
      AppLogger.error('❌ Failed to cache API products: $e');
    }
  }

  /// Get cached API products
  static List<ApiProductModel>? getCachedApiProducts() {
    try {
      const cacheKey = 'api_products';
      final timestamp = _cacheTimestamps[cacheKey];
      
      if (timestamp != null && 
          DateTime.now().difference(timestamp) < _apiProductsCacheExpiration) {
        final cached = _memoryCache[cacheKey] as List<ApiProductModel>?;
        if (cached != null) {
          AppLogger.info('⚡ Retrieved ${cached.length} API products from cache');
          return cached;
        }
      }
      
      return null;
    } catch (e) {
      AppLogger.error('❌ Failed to get cached API products: $e');
      return null;
    }
  }

  /// Cache warehouse names
  static Future<void> cacheWarehouseNames(Map<String, String> names) async {
    try {
      const cacheKey = 'warehouse_names';
      final timestamp = DateTime.now();
      
      _memoryCache[cacheKey] = names;
      _cacheTimestamps[cacheKey] = timestamp;
      
      AppLogger.info('💾 Cached ${names.length} warehouse names');
    } catch (e) {
      AppLogger.error('❌ Failed to cache warehouse names: $e');
    }
  }

  /// Get cached warehouse names
  static Map<String, String>? getCachedWarehouseNames() {
    try {
      const cacheKey = 'warehouse_names';
      final timestamp = _cacheTimestamps[cacheKey];
      
      if (timestamp != null && 
          DateTime.now().difference(timestamp) < _warehouseNamesCacheExpiration) {
        final cached = _memoryCache[cacheKey] as Map<String, String>?;
        if (cached != null) {
          AppLogger.info('⚡ Retrieved ${cached.length} warehouse names from cache');
          return cached;
        }
      }
      
      return null;
    } catch (e) {
      AppLogger.error('❌ Failed to get cached warehouse names: $e');
      return null;
    }
  }

  /// Cache complete reports
  static Future<void> cacheReport(String reportType, dynamic report) async {
    try {
      final cacheKey = 'report_$reportType';
      final timestamp = DateTime.now();
      
      _memoryCache[cacheKey] = report;
      _cacheTimestamps[cacheKey] = timestamp;
      
      AppLogger.info('💾 Cached $reportType report');
    } catch (e) {
      AppLogger.error('❌ Failed to cache $reportType report: $e');
    }
  }

  /// Get cached report
  static T? getCachedReport<T>(String reportType) {
    try {
      final cacheKey = 'report_$reportType';
      final timestamp = _cacheTimestamps[cacheKey];
      
      if (timestamp != null && 
          DateTime.now().difference(timestamp) < _reportCacheExpiration) {
        final cached = _memoryCache[cacheKey] as T?;
        if (cached != null) {
          AppLogger.info('⚡ Retrieved $reportType report from cache');
          return cached;
        }
      }
      
      return null;
    } catch (e) {
      AppLogger.error('❌ Failed to get cached $reportType report: $e');
      return null;
    }
  }

  /// Invalidate specific cache entries
  static void invalidateCache(String pattern) {
    try {
      final keysToRemove = <String>[];
      
      for (final key in _memoryCache.keys) {
        if (key.contains(pattern)) {
          keysToRemove.add(key);
        }
      }
      
      for (final key in keysToRemove) {
        _memoryCache.remove(key);
        _cacheTimestamps.remove(key);
      }
      
      AppLogger.info('🗑️ Invalidated ${keysToRemove.length} cache entries matching: $pattern');
    } catch (e) {
      AppLogger.error('❌ Failed to invalidate cache: $e');
    }
  }

  /// Clear all cache
  static void clearAll() {
    try {
      final count = _memoryCache.length;
      _memoryCache.clear();
      _cacheTimestamps.clear();
      
      AppLogger.info('🗑️ Cleared all cache entries ($count items)');
    } catch (e) {
      AppLogger.error('❌ Failed to clear cache: $e');
    }
  }

  /// Get cache statistics
  static Map<String, dynamic> getCacheStats() {
    try {
      final now = DateTime.now();
      final validEntries = <String>[];
      final expiredEntries = <String>[];
      
      for (final entry in _cacheTimestamps.entries) {
        final key = entry.key;
        final timestamp = entry.value;
        
        Duration expiration;
        if (key.contains('inventory')) {
          expiration = _inventoryCacheExpiration;
        } else if (key.contains('api_products')) {
          expiration = _apiProductsCacheExpiration;
        } else if (key.contains('report')) {
          expiration = _reportCacheExpiration;
        } else if (key.contains('warehouse_names')) {
          expiration = _warehouseNamesCacheExpiration;
        } else {
          expiration = _reportCacheExpiration;
        }
        
        if (now.difference(timestamp) < expiration) {
          validEntries.add(key);
        } else {
          expiredEntries.add(key);
        }
      }
      
      return {
        'total_entries': _memoryCache.length,
        'valid_entries': validEntries.length,
        'expired_entries': expiredEntries.length,
        'cache_types': {
          'inventories': validEntries.where((k) => k.contains('inventory')).length,
          'api_products': validEntries.where((k) => k.contains('api_products')).length,
          'reports': validEntries.where((k) => k.contains('report')).length,
          'warehouse_names': validEntries.where((k) => k.contains('warehouse_names')).length,
        },
      };
    } catch (e) {
      AppLogger.error('❌ Failed to get cache stats: $e');
      return {};
    }
  }

  /// Cleanup expired entries
  static void cleanupExpired() {
    try {
      final now = DateTime.now();
      final keysToRemove = <String>[];
      
      for (final entry in _cacheTimestamps.entries) {
        final key = entry.key;
        final timestamp = entry.value;
        
        Duration expiration;
        if (key.contains('inventory')) {
          expiration = _inventoryCacheExpiration;
        } else if (key.contains('api_products')) {
          expiration = _apiProductsCacheExpiration;
        } else if (key.contains('report')) {
          expiration = _reportCacheExpiration;
        } else if (key.contains('warehouse_names')) {
          expiration = _warehouseNamesCacheExpiration;
        } else {
          expiration = _reportCacheExpiration;
        }
        
        if (now.difference(timestamp) >= expiration) {
          keysToRemove.add(key);
        }
      }
      
      for (final key in keysToRemove) {
        _memoryCache.remove(key);
        _cacheTimestamps.remove(key);
      }
      
      if (keysToRemove.isNotEmpty) {
        AppLogger.info('🧹 Cleaned up ${keysToRemove.length} expired cache entries');
      }
    } catch (e) {
      AppLogger.error('❌ Failed to cleanup expired cache: $e');
    }
  }
}
