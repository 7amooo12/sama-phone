import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../utils/app_logger.dart';
import '../models/flask_product_model.dart';
import '../models/product_movement_model.dart';

/// Enhanced cache service specifically optimized for reports data
class EnhancedReportsCacheService {
  static const String _cachePrefix = 'reports_cache_';
  static const String _timestampPrefix = 'reports_timestamp_';
  // ULTRA-AGGRESSIVE cache expiration durations for maximum performance
  static const Duration _defaultExpiration = Duration(hours: 6); // Increased from 1 hour
  static const Duration _movementDataExpiration = Duration(hours: 12); // Increased from 4 hours
  static const Duration _analyticsExpiration = Duration(hours: 2); // Increased from 30 minutes
  static const Duration _chartDataExpiration = Duration(hours: 3); // Increased from 45 minutes
  static const Duration _backgroundProcessExpiration = Duration(hours: 8); // Increased from 2 hours
  static const Duration _bulkDataExpiration = Duration(hours: 24); // New: For bulk API results
  static const Duration _preComputedExpiration = Duration(days: 1); // New: For pre-computed results

  /// Cache product movement data with optimized storage
  static Future<void> cacheProductMovement(
    String productId,
    ProductMovementModel movement,
  ) async {
    try {
      final key = 'movement_$productId';
      await _setCacheData(key, movement.toJson(), _movementDataExpiration);
      AppLogger.info('📋 Cached movement data for product: $productId');
    } catch (e) {
      AppLogger.error('❌ Error caching product movement: $e');
    }
  }

  /// Get cached product movement data
  static Future<ProductMovementModel?> getCachedProductMovement(String productId) async {
    try {
      final key = 'movement_$productId';
      final data = await _getCacheData(key);
      if (data != null) {
        AppLogger.info('📋 Retrieved cached movement data for product: $productId');
        return ProductMovementModel.fromJson(data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      AppLogger.error('❌ Error retrieving cached movement: $e');
      return null;
    }
  }

  /// Cache category analytics with compression
  static Future<void> cacheCategoryAnalytics(
    String category,
    Map<String, dynamic> analytics,
  ) async {
    try {
      final key = 'category_analytics_$category';
      await _setCacheData(key, analytics, _analyticsExpiration);
      AppLogger.info('📋 Cached analytics for category: $category');
    } catch (e) {
      AppLogger.error('❌ Error caching category analytics: $e');
    }
  }

  /// Get cached category analytics
  static Future<Map<String, dynamic>?> getCachedCategoryAnalytics(String category) async {
    try {
      final key = 'category_analytics_$category';
      final data = await _getCacheData(key);
      if (data != null) {
        AppLogger.info('📋 Retrieved cached analytics for category: $category');
        return Map<String, dynamic>.from(data as Map<dynamic, dynamic>);
      }
      return null;
    } catch (e) {
      AppLogger.error('❌ Error retrieving cached analytics: $e');
      return null;
    }
  }

  /// Cache customer data for category
  static Future<void> cacheCategoryCustomers(
    String category,
    List<Map<String, dynamic>> customers,
  ) async {
    try {
      final key = 'category_customers_$category';
      await _setCacheData(key, customers, _analyticsExpiration);
      AppLogger.info('📋 Cached customers for category: $category');
    } catch (e) {
      AppLogger.error('❌ Error caching category customers: $e');
    }
  }

  /// Get cached category customers
  static Future<List<Map<String, dynamic>>?> getCachedCategoryCustomers(String category) async {
    try {
      final key = 'category_customers_$category';
      final data = await _getCacheData(key);
      if (data != null) {
        AppLogger.info('📋 Retrieved cached customers for category: $category');
        return List<Map<String, dynamic>>.from(data);
      }
      return null;
    } catch (e) {
      AppLogger.error('❌ Error retrieving cached customers: $e');
      return null;
    }
  }

  /// Cache products list with metadata
  static Future<void> cacheProductsList(
    List<FlaskProductModel> products,
    Set<String> categories,
  ) async {
    try {
      final productsData = products.map((p) => p.toJson()).toList();
      await _setCacheData('products_list', productsData, _defaultExpiration);
      await _setCacheData('categories_list', categories.toList(), _defaultExpiration);
      AppLogger.info('📋 Cached ${products.length} products and ${categories.length} categories');
    } catch (e) {
      AppLogger.error('❌ Error caching products list: $e');
    }
  }

  /// Get cached products list
  static Future<Map<String, dynamic>?> getCachedProductsList() async {
    try {
      final productsData = await _getCacheData('products_list');
      final categoriesData = await _getCacheData('categories_list');

      if (productsData != null && categoriesData != null) {
        final products = (productsData as List)
            .map((json) => FlaskProductModel.fromJson(json))
            .toList();
        final categories = Set<String>.from(categoriesData);

        AppLogger.info('📋 Retrieved cached products list: ${products.length} products');
        return {
          'products': products,
          'categories': categories,
        };
      }
      return null;
    } catch (e) {
      AppLogger.error('❌ Error retrieving cached products: $e');
      return null;
    }
  }

  /// Cache chart data for performance optimization
  static Future<void> cacheChartData(
    String chartType,
    String identifier,
    List<Map<String, dynamic>> chartData,
  ) async {
    try {
      final key = 'chart_${chartType}_$identifier';
      await _setCacheData(key, chartData, _chartDataExpiration);
      AppLogger.info('📋 Cached chart data: $chartType for $identifier');
    } catch (e) {
      AppLogger.error('❌ Error caching chart data: $e');
    }
  }

  /// Get cached chart data
  static Future<List<Map<String, dynamic>>?> getCachedChartData(
    String chartType,
    String identifier,
  ) async {
    try {
      final key = 'chart_${chartType}_$identifier';
      final data = await _getCacheData(key);
      if (data != null) {
        AppLogger.info('📋 Retrieved cached chart data: $chartType for $identifier');
        return List<Map<String, dynamic>>.from(data);
      }
      return null;
    } catch (e) {
      AppLogger.error('❌ Error retrieving cached chart data: $e');
      return null;
    }
  }

  /// Cache background processed data
  static Future<void> cacheBackgroundProcessedData(
    String operationId,
    Map<String, dynamic> processedData,
  ) async {
    try {
      final key = 'background_$operationId';
      await _setCacheData(key, processedData, _backgroundProcessExpiration);
      AppLogger.info('📋 Cached background processed data: $operationId');
    } catch (e) {
      AppLogger.error('❌ Error caching background processed data: $e');
    }
  }

  /// Get cached background processed data
  static Future<Map<String, dynamic>?> getCachedBackgroundProcessedData(
    String operationId,
  ) async {
    try {
      final key = 'background_$operationId';
      final data = await _getCacheData(key);
      if (data != null) {
        AppLogger.info('📋 Retrieved cached background processed data: $operationId');
        return Map<String, dynamic>.from(data);
      }
      return null;
    } catch (e) {
      AppLogger.error('❌ Error retrieving cached background processed data: $e');
      return null;
    }
  }

  /// Check if cache is valid for a specific key
  static Future<bool> isCacheValid(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestampKey = _timestampPrefix + key;
      final expirationKey = '${_timestampPrefix}expiration_$key';
      
      final timestamp = prefs.getInt(timestampKey);
      final expiration = prefs.getInt(expirationKey);
      
      if (timestamp == null || expiration == null) return false;
      
      final now = DateTime.now().millisecondsSinceEpoch;
      return (now - timestamp) < expiration;
    } catch (e) {
      AppLogger.error('❌ Error checking cache validity: $e');
      return false;
    }
  }

  /// Clear expired cache entries
  static Future<void> clearExpiredCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final expiredKeys = <String>[];
      
      for (final key in keys) {
        if (key.startsWith(_cachePrefix)) {
          final cacheKey = key.replaceFirst(_cachePrefix, '');
          if (!await isCacheValid(cacheKey)) {
            expiredKeys.add(key);
            expiredKeys.add(_timestampPrefix + cacheKey);
            expiredKeys.add('${_timestampPrefix}expiration_$cacheKey');
          }
        }
      }
      
      for (final key in expiredKeys) {
        await prefs.remove(key);
      }
      
      if (expiredKeys.isNotEmpty) {
        AppLogger.info('🧹 Cleared ${expiredKeys.length ~/ 3} expired cache entries');
      }
    } catch (e) {
      AppLogger.error('❌ Error clearing expired cache: $e');
    }
  }

  /// Clear all reports cache
  static Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final cacheKeys = keys.where((key) => 
          key.startsWith(_cachePrefix) || key.startsWith(_timestampPrefix));
      
      for (final key in cacheKeys) {
        await prefs.remove(key);
      }
      
      AppLogger.info('🧹 Cleared all reports cache');
    } catch (e) {
      AppLogger.error('❌ Error clearing all cache: $e');
    }
  }

  /// Get cache statistics
  static Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      final cacheKeys = keys.where((key) => key.startsWith(_cachePrefix)).toList();
      final validKeys = <String>[];
      final expiredKeys = <String>[];
      
      for (final key in cacheKeys) {
        final cacheKey = key.replaceFirst(_cachePrefix, '');
        if (await isCacheValid(cacheKey)) {
          validKeys.add(key);
        } else {
          expiredKeys.add(key);
        }
      }
      
      return {
        'totalEntries': cacheKeys.length,
        'validEntries': validKeys.length,
        'expiredEntries': expiredKeys.length,
        'cacheHitRate': cacheKeys.isNotEmpty ? validKeys.length / cacheKeys.length : 0.0,
      };
    } catch (e) {
      AppLogger.error('❌ Error getting cache stats: $e');
      return {};
    }
  }

  /// CRITICAL OPTIMIZATION: Cache bulk movement data results
  static Future<void> cacheBulkMovementData(
    Map<int, ProductMovementModel> bulkData,
  ) async {
    try {
      final key = 'bulk_movement_${DateTime.now().day}';
      final dataToCache = bulkData.map((key, value) => MapEntry(key.toString(), value.toJson()));
      await _setCacheData(key, dataToCache, _bulkDataExpiration);
      AppLogger.info('📋 Cached bulk movement data for ${bulkData.length} products');
    } catch (e) {
      AppLogger.error('❌ Error caching bulk movement data: $e');
    }
  }

  /// CRITICAL OPTIMIZATION: Get cached bulk movement data
  static Future<Map<int, ProductMovementModel>?> getCachedBulkMovementData() async {
    try {
      final key = 'bulk_movement_${DateTime.now().day}';
      final data = await _getCacheData(key);
      if (data != null) {
        final Map<int, ProductMovementModel> result = {};
        final dataMap = data as Map<String, dynamic>;

        for (final entry in dataMap.entries) {
          final productId = int.parse(entry.key);
          result[productId] = ProductMovementModel.fromJson(entry.value as Map<String, dynamic>);
        }

        AppLogger.info('📋 Retrieved cached bulk movement data for ${result.length} products');
        return result;
      }
      return null;
    } catch (e) {
      AppLogger.error('❌ Error getting cached bulk movement data: $e');
      return null;
    }
  }

  /// ULTRA-OPTIMIZATION: Cache pre-computed category results
  static Future<void> cachePreComputedCategoryResults(
    String category,
    Map<String, dynamic> results,
  ) async {
    try {
      final key = 'precomputed_$category';
      await _setCacheData(key, results, _preComputedExpiration);
      AppLogger.info('📋 Cached pre-computed results for category: $category');
    } catch (e) {
      AppLogger.error('❌ Error caching pre-computed category results: $e');
    }
  }

  /// ULTRA-OPTIMIZATION: Get cached pre-computed category results
  static Future<Map<String, dynamic>?> getCachedPreComputedCategoryResults(String category) async {
    try {
      final key = 'precomputed_$category';
      final data = await _getCacheData(key);
      if (data != null) {
        AppLogger.info('📋 Retrieved pre-computed results for category: $category');
        return Map<String, dynamic>.from(data as Map<dynamic, dynamic>);
      }
      return null;
    } catch (e) {
      AppLogger.error('❌ Error getting cached pre-computed category results: $e');
      return null;
    }
  }

  /// PERFORMANCE BOOST: Cache session-level complete data
  static Future<void> cacheCompleteSessionData(
    Map<String, dynamic> sessionData,
  ) async {
    try {
      final key = 'complete_session_${DateTime.now().day}';
      await _setCacheData(key, sessionData, _preComputedExpiration);
      AppLogger.info('📋 Cached complete session data');
    } catch (e) {
      AppLogger.error('❌ Error caching complete session data: $e');
    }
  }

  /// PERFORMANCE BOOST: Get cached session-level complete data
  static Future<Map<String, dynamic>?> getCachedCompleteSessionData() async {
    try {
      final key = 'complete_session_${DateTime.now().day}';
      final data = await _getCacheData(key);
      if (data != null) {
        AppLogger.info('📋 Retrieved complete session data - INSTANT LOAD!');
        return Map<String, dynamic>.from(data as Map<dynamic, dynamic>);
      }
      return null;
    } catch (e) {
      AppLogger.error('❌ Error getting cached complete session data: $e');
      return null;
    }
  }

  /// Private helper methods
  static Future<void> _setCacheData(
    String key,
    dynamic data,
    Duration expiration,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    
    await prefs.setString(_cachePrefix + key, jsonEncode(data));
    await prefs.setInt(_timestampPrefix + key, now);
    await prefs.setInt('${_timestampPrefix}expiration_$key', expiration.inMilliseconds);
  }

  static Future<dynamic> _getCacheData(String key) async {
    if (!await isCacheValid(key)) return null;
    
    final prefs = await SharedPreferences.getInstance();
    final cachedString = prefs.getString(_cachePrefix + key);
    
    if (cachedString == null) return null;
    
    return jsonDecode(cachedString);
  }
}
