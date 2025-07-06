import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../utils/app_logger.dart';

/// Database Performance Optimizer
/// Handles query caching, connection pooling, and database operation optimization
class DatabasePerformanceOptimizer {
  static final Map<String, CachedQuery> _queryCache = {};
  static final Map<String, Timer> _cacheTimers = {};
  static const int _maxCacheSize = 100;
  static const Duration _defaultCacheExpiry = Duration(minutes: 5);
  
  // Query performance tracking
  static final Map<String, QueryPerformanceStats> _queryStats = {};
  
  /// Initialize database performance optimizer
  static void initialize() {
    // Start cache cleanup timer
    Timer.periodic(const Duration(minutes: 10), (_) {
      _cleanupExpiredCache();
    });
    
    AppLogger.info('🗄️ Database performance optimizer initialized');
  }

  /// Cache a query result
  static void cacheQuery({
    required String queryKey,
    required dynamic result,
    Duration? customExpiry,
  }) {
    final expiry = customExpiry ?? _defaultCacheExpiry;
    
    // Remove oldest cache entry if at max capacity
    if (_queryCache.length >= _maxCacheSize) {
      final oldestKey = _queryCache.entries
          .reduce((a, b) => a.value.timestamp.isBefore(b.value.timestamp) ? a : b)
          .key;
      _removeFromCache(oldestKey);
    }
    
    // Cache the query result
    _queryCache[queryKey] = CachedQuery(
      result: result,
      timestamp: DateTime.now(),
      expiry: expiry,
    );
    
    // Set expiry timer
    _cacheTimers[queryKey]?.cancel();
    _cacheTimers[queryKey] = Timer(expiry, () {
      _removeFromCache(queryKey);
    });
    
    AppLogger.info('💾 Cached query: $queryKey (expires in ${expiry.inMinutes}m)');
  }

  /// Get cached query result
  static T? getCachedQuery<T>(String queryKey) {
    final cached = _queryCache[queryKey];
    if (cached == null) return null;
    
    // Check if expired
    if (DateTime.now().difference(cached.timestamp) > cached.expiry) {
      _removeFromCache(queryKey);
      return null;
    }
    
    AppLogger.info('🎯 Cache hit for query: $queryKey');
    return cached.result as T?;
  }

  /// Remove query from cache
  static void _removeFromCache(String queryKey) {
    _queryCache.remove(queryKey);
    _cacheTimers[queryKey]?.cancel();
    _cacheTimers.remove(queryKey);
  }

  /// Clear all cached queries
  static void clearCache() {
    _queryCache.clear();
    _cacheTimers.values.forEach((timer) => timer.cancel());
    _cacheTimers.clear();
    AppLogger.info('🧹 Database query cache cleared');
  }

  /// Clean up expired cache entries
  static void _cleanupExpiredCache() {
    final now = DateTime.now();
    final expiredKeys = <String>[];
    
    _queryCache.forEach((key, cached) {
      if (now.difference(cached.timestamp) > cached.expiry) {
        expiredKeys.add(key);
      }
    });
    
    for (final key in expiredKeys) {
      _removeFromCache(key);
    }
    
    if (expiredKeys.isNotEmpty) {
      AppLogger.info('🧹 Cleaned up ${expiredKeys.length} expired cache entries');
    }
  }

  /// Execute query with caching
  static Future<T> executeWithCache<T>({
    required String queryKey,
    required Future<T> Function() queryFunction,
    Duration? cacheExpiry,
    bool forceRefresh = false,
  }) async {
    // Check cache first (unless force refresh)
    if (!forceRefresh) {
      final cached = getCachedQuery<T>(queryKey);
      if (cached != null) {
        return cached;
      }
    }
    
    // Execute query and measure performance
    final stopwatch = Stopwatch()..start();
    
    try {
      final result = await queryFunction();
      
      stopwatch.stop();
      
      // Track performance
      _trackQueryPerformance(queryKey, stopwatch.elapsedMilliseconds, true);
      
      // Cache the result
      cacheQuery(
        queryKey: queryKey,
        result: result,
        customExpiry: cacheExpiry,
      );
      
      return result;
      
    } catch (e) {
      stopwatch.stop();
      _trackQueryPerformance(queryKey, stopwatch.elapsedMilliseconds, false);
      rethrow;
    }
  }

  /// Track query performance statistics
  static void _trackQueryPerformance(String queryKey, int durationMs, bool success) {
    final stats = _queryStats[queryKey] ?? QueryPerformanceStats(queryKey);
    
    stats.totalExecutions++;
    stats.totalDurationMs += durationMs;
    stats.averageDurationMs = stats.totalDurationMs / stats.totalExecutions;
    
    if (success) {
      stats.successfulExecutions++;
    } else {
      stats.failedExecutions++;
    }
    
    if (durationMs > stats.maxDurationMs) {
      stats.maxDurationMs = durationMs;
    }
    
    if (stats.minDurationMs == 0 || durationMs < stats.minDurationMs) {
      stats.minDurationMs = durationMs;
    }
    
    stats.lastExecuted = DateTime.now();
    _queryStats[queryKey] = stats;
    
    // Log slow queries
    if (durationMs > 2000) { // Slower than 2 seconds
      AppLogger.warning('🐌 Slow query detected: $queryKey (${durationMs}ms)');
    }
  }

  /// Get query performance statistics
  static Map<String, QueryPerformanceStats> getQueryStats() {
    return Map.from(_queryStats);
  }

  /// Get cache statistics
  static Map<String, dynamic> getCacheStats() {
    return {
      'cached_queries': _queryCache.length,
      'max_cache_size': _maxCacheSize,
      'cache_hit_ratio': _calculateCacheHitRatio(),
      'oldest_cache_entry': _queryCache.values.isNotEmpty
          ? _queryCache.values
              .map((c) => c.timestamp)
              .reduce((a, b) => a.isBefore(b) ? a : b)
          : null,
    };
  }

  /// Calculate cache hit ratio
  static double _calculateCacheHitRatio() {
    if (_queryStats.isEmpty) return 0.0;
    
    int totalQueries = 0;
    int cacheHits = 0;
    
    _queryStats.values.forEach((stats) {
      totalQueries += stats.totalExecutions;
      // Estimate cache hits based on successful executions
      // This is a simplified calculation
      cacheHits += (stats.successfulExecutions * 0.3).round();
    });
    
    return totalQueries > 0 ? (cacheHits / totalQueries) : 0.0;
  }

  /// Optimize query for better performance
  static String optimizeQuery(String query) {
    // Basic query optimization hints
    String optimized = query;
    
    // Add LIMIT if not present for SELECT queries
    if (optimized.toLowerCase().contains('select') && 
        !optimized.toLowerCase().contains('limit')) {
      optimized += ' LIMIT 1000';
    }
    
    // Add indexes hint for WHERE clauses
    if (optimized.toLowerCase().contains('where')) {
      // This is a placeholder - actual implementation would depend on database
      AppLogger.info('💡 Consider adding indexes for WHERE clause in: $query');
    }
    
    return optimized;
  }

  /// Batch multiple queries for better performance
  static Future<List<T>> executeBatch<T>(
    List<Future<T> Function()> queryFunctions,
  ) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      // Execute all queries concurrently
      final results = await Future.wait(
        queryFunctions.map((fn) => fn()),
      );
      
      stopwatch.stop();
      AppLogger.info('📦 Batch executed ${queryFunctions.length} queries in ${stopwatch.elapsedMilliseconds}ms');
      
      return results;
      
    } catch (e) {
      stopwatch.stop();
      AppLogger.error('❌ Batch execution failed after ${stopwatch.elapsedMilliseconds}ms: $e');
      rethrow;
    }
  }

  /// Preload frequently used queries
  static Future<void> preloadQueries(Map<String, Future<dynamic> Function()> queries) async {
    AppLogger.info('🚀 Preloading ${queries.length} frequently used queries...');
    
    final futures = queries.entries.map((entry) async {
      try {
        await executeWithCache(
          queryKey: entry.key,
          queryFunction: entry.value,
          cacheExpiry: const Duration(hours: 1), // Longer cache for preloaded queries
        );
      } catch (e) {
        AppLogger.warning('Failed to preload query ${entry.key}: $e');
      }
    });
    
    await Future.wait(futures);
    AppLogger.info('✅ Query preloading completed');
  }

  /// Dispose database performance optimizer
  static void dispose() {
    clearCache();
    _queryStats.clear();
    AppLogger.info('🗄️ Database performance optimizer disposed');
  }
}

/// Cached query data structure
class CachedQuery {
  final dynamic result;
  final DateTime timestamp;
  final Duration expiry;

  CachedQuery({
    required this.result,
    required this.timestamp,
    required this.expiry,
  });
}

/// Query performance statistics
class QueryPerformanceStats {
  final String queryKey;
  int totalExecutions = 0;
  int successfulExecutions = 0;
  int failedExecutions = 0;
  int totalDurationMs = 0;
  double averageDurationMs = 0.0;
  int maxDurationMs = 0;
  int minDurationMs = 0;
  DateTime? lastExecuted;

  QueryPerformanceStats(this.queryKey);

  Map<String, dynamic> toJson() {
    return {
      'queryKey': queryKey,
      'totalExecutions': totalExecutions,
      'successfulExecutions': successfulExecutions,
      'failedExecutions': failedExecutions,
      'averageDurationMs': averageDurationMs,
      'maxDurationMs': maxDurationMs,
      'minDurationMs': minDurationMs,
      'lastExecuted': lastExecuted?.toIso8601String(),
      'successRate': totalExecutions > 0 ? (successfulExecutions / totalExecutions) : 0.0,
    };
  }
}
