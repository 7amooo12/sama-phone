import 'dart:async';
import 'package:smartbiztracker_new/models/warehouse_model.dart';
import 'package:smartbiztracker_new/models/warehouse_inventory_model.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// Enhanced caching service for warehouse data with intelligent cache management
/// Prevents duplicate statistics calculations and optimizes performance
class WarehouseCacheService {
  // Cache expiration times - optimized for performance
  static const Duration _warehousesCacheExpiration = Duration(minutes: 5);
  static const Duration _inventoryCacheExpiration = Duration(minutes: 3);
  static const Duration _statisticsCacheExpiration = Duration(minutes: 2);
  static const Duration _transactionsCacheExpiration = Duration(minutes: 1);

  // In-memory cache for ultra-fast access and duplicate prevention
  static final Map<String, List<WarehouseModel>> _memoryWarehousesCache = {};
  static final Map<String, List<WarehouseInventoryModel>> _memoryInventoryCache = {};
  static final Map<String, Map<String, dynamic>> _memoryStatisticsCache = {};
  static final Map<String, List<dynamic>> _memoryTransactionsCache = {};
  static final Map<String, DateTime> _memoryCacheTimestamps = {};

  // Cache invalidation tracking to prevent duplicate operations
  static final Map<String, String> _cacheVersions = {};
  static final Set<String> _pendingOperations = {};
  static final Map<String, Future<dynamic>> _ongoingOperations = {};

  /// Initialize the cache service
  static Future<void> initialize() async {
    try {
      AppLogger.info('🚀 Initializing enhanced warehouse cache service...');

      // Clear any stale pending operations
      _pendingOperations.clear();
      _ongoingOperations.clear();

      AppLogger.info('✅ Enhanced warehouse cache service initialized');

      // Clean expired cache entries on startup
      await _cleanExpiredEntries();

    } catch (e) {
      AppLogger.error('❌ Failed to initialize warehouse cache service: $e');
    }
  }

  /// Prevent duplicate operations by checking if operation is already in progress
  static Future<T?> preventDuplicateOperation<T>(
    String operationKey,
    Future<T> Function() operation,
  ) async {
    // Check if operation is already in progress
    if (_ongoingOperations.containsKey(operationKey)) {
      AppLogger.info('⏳ Operation $operationKey already in progress, waiting...');
      return await _ongoingOperations[operationKey] as T?;
    }

    // Start the operation and track it
    final operationFuture = operation();
    _ongoingOperations[operationKey] = operationFuture;

    try {
      final result = await operationFuture;
      return result;
    } finally {
      // Remove from ongoing operations when complete
      _ongoingOperations.remove(operationKey);
    }
  }

  /// Save warehouses to cache with intelligent deduplication
  static Future<void> saveWarehouses(List<WarehouseModel> warehouses, {String cacheKey = 'default'}) async {
    try {
      final timestamp = DateTime.now();

      // Save to memory cache (fastest and most reliable)
      _memoryWarehousesCache[cacheKey] = warehouses;
      _memoryCacheTimestamps['warehouses_$cacheKey'] = timestamp;

      // Generate cache version for invalidation tracking
      _cacheVersions['warehouses_$cacheKey'] = timestamp.millisecondsSinceEpoch.toString();

      AppLogger.info('💾 Cached ${warehouses.length} warehouses (key: $cacheKey)');
    } catch (e) {
      AppLogger.error('❌ Failed to save warehouses to cache: $e');
    }
  }

  /// Save warehouse statistics to prevent duplicate calculations
  static Future<void> saveWarehouseStatistics(String warehouseId, Map<String, dynamic> statistics) async {
    try {
      final timestamp = DateTime.now();

      // Save to memory cache
      _memoryStatisticsCache[warehouseId] = statistics;
      _memoryCacheTimestamps['statistics_$warehouseId'] = timestamp;

      // Generate cache version
      _cacheVersions['statistics_$warehouseId'] = timestamp.millisecondsSinceEpoch.toString();

      AppLogger.info('📊 Cached statistics for warehouse $warehouseId');
    } catch (e) {
      AppLogger.error('❌ Failed to save statistics to cache: $e');
    }
  }

  /// Save warehouse transactions to cache
  static Future<void> saveWarehouseTransactions(String warehouseId, List<dynamic> transactions) async {
    try {
      final timestamp = DateTime.now();

      // Save to memory cache
      _memoryTransactionsCache[warehouseId] = transactions;
      _memoryCacheTimestamps['transactions_$warehouseId'] = timestamp;

      // Generate cache version
      _cacheVersions['transactions_$warehouseId'] = timestamp.millisecondsSinceEpoch.toString();

      AppLogger.info('📋 Cached ${transactions.length} transactions for warehouse $warehouseId');
    } catch (e) {
      AppLogger.error('❌ Failed to save transactions to cache: $e');
    }
  }
  
  /// Load warehouses from cache with intelligent cache checking
  static Future<List<WarehouseModel>?> loadWarehouses({String cacheKey = 'default'}) async {
    try {
      // Check memory cache first (fastest and most reliable)
      final memoryTimestamp = _memoryCacheTimestamps['warehouses_$cacheKey'];
      if (memoryTimestamp != null &&
          DateTime.now().difference(memoryTimestamp) < _warehousesCacheExpiration) {
        final cachedWarehouses = _memoryWarehousesCache[cacheKey];
        if (cachedWarehouses != null) {
          AppLogger.info('⚡ Loaded ${cachedWarehouses.length} warehouses from memory cache');
          return cachedWarehouses;
        }
      }

      AppLogger.info('⏰ Warehouse cache expired or not found');
      return null;
    } catch (e) {
      AppLogger.error('❌ Failed to load warehouses from cache: $e');
      return null;
    }
  }

  /// Load warehouse statistics from cache to prevent duplicate calculations
  static Future<Map<String, dynamic>?> loadWarehouseStatistics(String warehouseId) async {
    try {
      // Check if statistics calculation is already in progress
      final operationKey = 'statistics_$warehouseId';
      if (_pendingOperations.contains(operationKey)) {
        AppLogger.info('⏳ Statistics calculation for $warehouseId already in progress');
        return null;
      }

      // Check memory cache
      final memoryTimestamp = _memoryCacheTimestamps['statistics_$warehouseId'];
      if (memoryTimestamp != null &&
          DateTime.now().difference(memoryTimestamp) < _statisticsCacheExpiration) {
        final cachedStatistics = _memoryStatisticsCache[warehouseId];
        if (cachedStatistics != null) {
          AppLogger.info('⚡ Loaded statistics for warehouse $warehouseId from memory cache');
          return cachedStatistics;
        }
      }

      return null;
    } catch (e) {
      AppLogger.error('❌ Failed to load statistics from cache: $e');
      return null;
    }
  }

  /// Load warehouse transactions from cache
  static Future<List<dynamic>?> loadWarehouseTransactions(String warehouseId) async {
    try {
      // Check memory cache
      final memoryTimestamp = _memoryCacheTimestamps['transactions_$warehouseId'];
      if (memoryTimestamp != null &&
          DateTime.now().difference(memoryTimestamp) < _transactionsCacheExpiration) {
        final cachedTransactions = _memoryTransactionsCache[warehouseId];
        if (cachedTransactions != null) {
          AppLogger.info('⚡ Loaded ${cachedTransactions.length} transactions for warehouse $warehouseId from memory cache');
          return cachedTransactions;
        }
      }

      return null;
    } catch (e) {
      AppLogger.error('❌ Failed to load transactions from cache: $e');
      return null;
    }
  }
  
  /// Save inventory to cache with intelligent management
  static Future<void> saveInventory(String warehouseId, List<WarehouseInventoryModel> inventory) async {
    try {
      final timestamp = DateTime.now();

      // Save to memory cache (fastest and most reliable)
      _memoryInventoryCache[warehouseId] = inventory;
      _memoryCacheTimestamps['inventory_$warehouseId'] = timestamp;

      // Generate cache version
      _cacheVersions['inventory_$warehouseId'] = timestamp.millisecondsSinceEpoch.toString();

      AppLogger.info('💾 Cached ${inventory.length} inventory items for warehouse $warehouseId');
    } catch (e) {
      AppLogger.error('❌ Failed to save inventory to cache: $e');
    }
  }
  
  /// Load inventory from cache with intelligent management
  static Future<List<WarehouseInventoryModel>?> loadInventory(String warehouseId) async {
    try {
      // Check memory cache first (fastest and most reliable)
      final memoryTimestamp = _memoryCacheTimestamps['inventory_$warehouseId'];
      if (memoryTimestamp != null &&
          DateTime.now().difference(memoryTimestamp) < _inventoryCacheExpiration) {
        final cachedInventory = _memoryInventoryCache[warehouseId];
        if (cachedInventory != null) {
          AppLogger.info('⚡ Loaded ${cachedInventory.length} inventory items from memory cache');
          return cachedInventory;
        }
      }

      return null;
    } catch (e) {
      AppLogger.error('❌ Failed to load inventory from cache: $e');
      return null;
    }
  }

  /// Mark operation as pending to prevent duplicates
  static void markOperationPending(String operationKey) {
    _pendingOperations.add(operationKey);
    AppLogger.info('🔒 Marked operation as pending: $operationKey');
  }

  /// Mark operation as complete
  static void markOperationComplete(String operationKey) {
    _pendingOperations.remove(operationKey);
    AppLogger.info('✅ Marked operation as complete: $operationKey');
  }

  /// Check if operation is pending
  static bool isOperationPending(String operationKey) {
    return _pendingOperations.contains(operationKey);
  }
  
  /// Clear all caches
  static Future<void> clearAll() async {
    try {
      // Clear memory caches
      _memoryWarehousesCache.clear();
      _memoryInventoryCache.clear();
      _memoryStatisticsCache.clear();
      _memoryTransactionsCache.clear();
      _memoryCacheTimestamps.clear();

      // Clear cache tracking
      _cacheVersions.clear();
      _pendingOperations.clear();
      _ongoingOperations.clear();

      AppLogger.info('🗑️ All warehouse caches cleared');
    } catch (e) {
      AppLogger.error('❌ Failed to clear caches: $e');
    }
  }

  /// Clear cache for specific warehouse
  static Future<void> clearWarehouseCache(String warehouseId) async {
    try {
      // Clear warehouse-specific caches
      _memoryInventoryCache.remove(warehouseId);
      _memoryStatisticsCache.remove(warehouseId);
      _memoryTransactionsCache.remove(warehouseId);

      // Clear timestamps
      _memoryCacheTimestamps.remove('inventory_$warehouseId');
      _memoryCacheTimestamps.remove('statistics_$warehouseId');
      _memoryCacheTimestamps.remove('transactions_$warehouseId');

      // Clear versions
      _cacheVersions.remove('inventory_$warehouseId');
      _cacheVersions.remove('statistics_$warehouseId');
      _cacheVersions.remove('transactions_$warehouseId');

      AppLogger.info('🗑️ Cleared cache for warehouse $warehouseId');
    } catch (e) {
      AppLogger.error('❌ Failed to clear warehouse cache: $e');
    }
  }
  
  /// Clean expired cache entries from memory
  static Future<void> _cleanExpiredEntries() async {
    try {
      final now = DateTime.now();
      final expiredKeys = <String>[];

      // Check all timestamps for expired entries
      _memoryCacheTimestamps.forEach((key, timestamp) {
        Duration expiration;

        if (key.startsWith('warehouses_')) {
          expiration = _warehousesCacheExpiration;
        } else if (key.startsWith('inventory_')) {
          expiration = _inventoryCacheExpiration;
        } else if (key.startsWith('statistics_')) {
          expiration = _statisticsCacheExpiration;
        } else if (key.startsWith('transactions_')) {
          expiration = _transactionsCacheExpiration;
        } else {
          return; // Skip unknown keys
        }

        if (now.difference(timestamp) > expiration) {
          expiredKeys.add(key);
        }
      });

      // Remove expired entries
      for (final key in expiredKeys) {
        _memoryCacheTimestamps.remove(key);

        if (key.startsWith('warehouses_')) {
          final cacheKey = key.substring('warehouses_'.length);
          _memoryWarehousesCache.remove(cacheKey);
        } else if (key.startsWith('inventory_')) {
          final warehouseId = key.substring('inventory_'.length);
          _memoryInventoryCache.remove(warehouseId);
        } else if (key.startsWith('statistics_')) {
          final warehouseId = key.substring('statistics_'.length);
          _memoryStatisticsCache.remove(warehouseId);
        } else if (key.startsWith('transactions_')) {
          final warehouseId = key.substring('transactions_'.length);
          _memoryTransactionsCache.remove(warehouseId);
        }
      }

      if (expiredKeys.isNotEmpty) {
        AppLogger.info('🧹 Cleaned ${expiredKeys.length} expired cache entries');
      }
    } catch (e) {
      AppLogger.error('❌ Failed to clean expired cache entries: $e');
    }
  }
  
  /// Get cache statistics
  static Map<String, dynamic> getCacheStats() {
    return {
      'memory_warehouses_count': _memoryWarehousesCache.length,
      'memory_inventory_count': _memoryInventoryCache.length,
      'memory_statistics_count': _memoryStatisticsCache.length,
      'memory_transactions_count': _memoryTransactionsCache.length,
      'memory_timestamps_count': _memoryCacheTimestamps.length,
      'pending_operations_count': _pendingOperations.length,
      'ongoing_operations_count': _ongoingOperations.length,
      'cache_versions_count': _cacheVersions.length,
    };
  }

  /// Clear transactions cache for specific warehouse
  static Future<void> clearWarehouseTransactions(String warehouseId) async {
    try {
      // Clear warehouse-specific transactions cache
      _memoryTransactionsCache.remove(warehouseId);

      // Clear timestamps
      _memoryCacheTimestamps.remove('transactions_$warehouseId');

      // Clear versions
      _cacheVersions.remove('transactions_$warehouseId');

      AppLogger.info('🗑️ Cleared transactions cache for warehouse $warehouseId');
    } catch (e) {
      AppLogger.error('❌ Failed to clear transactions cache for warehouse $warehouseId: $e');
    }
  }
}
