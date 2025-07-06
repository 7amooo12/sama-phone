import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:crypto/crypto.dart';

/// Smart Cache Manager with multi-layer caching and incremental updates
/// Provides intelligent caching for analytics data with automatic invalidation
class SmartCacheManager {
  static final SmartCacheManager _instance = SmartCacheManager._internal();
  factory SmartCacheManager() => _instance;
  SmartCacheManager._internal();

  // Memory cache (fastest access)
  final Map<String, dynamic> _memoryCache = {};
  final Map<String, DateTime> _memoryCacheTimestamps = {};
  final Map<String, String> _memoryCacheHashes = {};

  // Persistent cache keys
  static const String _persistentCachePrefix = 'smart_cache_';
  static const String _timestampSuffix = '_timestamp';
  static const String _hashSuffix = '_hash';

  // Cache configuration
  static const Duration _memoryExpiration = Duration(minutes: 15);
  static const Duration _persistentExpiration = Duration(hours: 2);
  static const int _maxMemoryItems = 50;

  // Performance tracking
  final Map<String, int> _hitCounts = {};
  final Map<String, int> _missCounts = {};
  final Map<String, Duration> _accessTimes = {};

  /// Get cached data with intelligent fallback strategy
  Future<T?> get<T>(
    String key, {
    Duration? customExpiration,
    bool skipMemory = false,
    bool skipPersistent = false,
  }) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      // Step 1: Check memory cache first (unless skipped)
      if (!skipMemory && _isMemoryCacheValid(key, customExpiration)) {
        _recordHit(key);
        _recordAccessTime(key, stopwatch.elapsed);
        AppLogger.info('📋 Memory cache hit for key: $key');
        return _memoryCache[key] as T?;
      }

      // Step 2: Check persistent cache (unless skipped)
      if (!skipPersistent) {
        final persistentData = await _getPersistentCache<T>(key, customExpiration);
        if (persistentData != null) {
          // Store in memory cache for faster future access
          _setMemoryCache(key, persistentData);
          _recordHit(key);
          _recordAccessTime(key, stopwatch.elapsed);
          AppLogger.info('📋 Persistent cache hit for key: $key');
          return persistentData;
        }
      }

      // Cache miss
      _recordMiss(key);
      _recordAccessTime(key, stopwatch.elapsed);
      AppLogger.info('❌ Cache miss for key: $key');
      return null;
    } catch (e) {
      AppLogger.error('❌ Error getting cached data for key $key: $e');
      _recordMiss(key);
      return null;
    }
  }

  /// Set data in cache with intelligent storage strategy
  Future<void> set<T>(
    String key,
    T data, {
    Duration? customExpiration,
    bool skipMemory = false,
    bool skipPersistent = false,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final dataHash = _generateDataHash(data);
      
      // Check if data has actually changed
      if (_memoryCacheHashes.containsKey(key) && _memoryCacheHashes[key] == dataHash) {
        AppLogger.info('📋 Data unchanged for key: $key, skipping cache update');
        return;
      }

      // Store in memory cache (unless skipped)
      if (!skipMemory) {
        _setMemoryCache(key, data, dataHash);
      }

      // Store in persistent cache (unless skipped)
      if (!skipPersistent) {
        await _setPersistentCache(key, data, dataHash, metadata);
      }

      AppLogger.info('✅ Cached data for key: $key');
    } catch (e) {
      AppLogger.error('❌ Error setting cache for key $key: $e');
    }
  }

  /// Invalidate cache for specific key or pattern
  Future<void> invalidate(String keyOrPattern, {bool isPattern = false}) async {
    try {
      if (isPattern) {
        // Invalidate all keys matching pattern
        final keysToRemove = <String>[];
        
        // Memory cache
        for (final key in _memoryCache.keys) {
          if (key.contains(keyOrPattern)) {
            keysToRemove.add(key);
          }
        }
        
        for (final key in keysToRemove) {
          _removeFromMemoryCache(key);
        }

        // Persistent cache
        await _invalidatePersistentPattern(keyOrPattern);
        
        AppLogger.info('🧹 Invalidated cache pattern: $keyOrPattern (${keysToRemove.length} items)');
      } else {
        // Invalidate specific key
        _removeFromMemoryCache(keyOrPattern);
        await _removePersistentCache(keyOrPattern);
        
        AppLogger.info('🧹 Invalidated cache key: $keyOrPattern');
      }
    } catch (e) {
      AppLogger.error('❌ Error invalidating cache: $e');
    }
  }

  /// Get cache statistics for monitoring
  Map<String, dynamic> getStatistics() {
    final totalHits = _hitCounts.values.fold(0, (sum, count) => sum + count);
    final totalMisses = _missCounts.values.fold(0, (sum, count) => sum + count);
    final hitRate = totalHits + totalMisses > 0 ? totalHits / (totalHits + totalMisses) : 0.0;
    
    final avgAccessTime = _accessTimes.values.isNotEmpty
        ? _accessTimes.values.map((d) => d.inMicroseconds).reduce((a, b) => a + b) / _accessTimes.length
        : 0.0;

    return {
      'hitRate': hitRate,
      'totalHits': totalHits,
      'totalMisses': totalMisses,
      'memoryItems': _memoryCache.length,
      'averageAccessTimeMicros': avgAccessTime,
      'lastUpdated': DateTime.now().toIso8601String(),
    };
  }

  /// Clear all caches
  Future<void> clearAll() async {
    try {
      // Clear memory cache
      _memoryCache.clear();
      _memoryCacheTimestamps.clear();
      _memoryCacheHashes.clear();
      
      // Clear persistent cache
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith(_persistentCachePrefix));
      for (final key in keys) {
        await prefs.remove(key);
      }
      
      // Clear statistics
      _hitCounts.clear();
      _missCounts.clear();
      _accessTimes.clear();
      
      AppLogger.info('🧹 Cleared all caches');
    } catch (e) {
      AppLogger.error('❌ Error clearing caches: $e');
    }
  }

  /// Optimize cache by removing expired and least used items
  Future<void> optimize() async {
    try {
      final now = DateTime.now();
      final itemsToRemove = <String>[];
      
      // Remove expired memory cache items
      for (final entry in _memoryCacheTimestamps.entries) {
        if (now.difference(entry.value) > _memoryExpiration) {
          itemsToRemove.add(entry.key);
        }
      }
      
      // Remove least used items if cache is too large
      if (_memoryCache.length > _maxMemoryItems) {
        final sortedByUsage = _hitCounts.entries.toList()
          ..sort((a, b) => a.value.compareTo(b.value));
        
        final itemsToRemoveCount = _memoryCache.length - _maxMemoryItems;
        for (int i = 0; i < itemsToRemoveCount && i < sortedByUsage.length; i++) {
          itemsToRemove.add(sortedByUsage[i].key);
        }
      }
      
      // Remove items
      for (final key in itemsToRemove) {
        _removeFromMemoryCache(key);
      }
      
      // Optimize persistent cache
      await _optimizePersistentCache();
      
      AppLogger.info('🔧 Cache optimized: removed ${itemsToRemove.length} items');
    } catch (e) {
      AppLogger.error('❌ Error optimizing cache: $e');
    }
  }

  /// Preload frequently accessed data
  Future<void> preloadFrequentData(Map<String, Future<dynamic> Function()> dataLoaders) async {
    try {
      AppLogger.info('🔄 Preloading frequent data...');
      
      final futures = <Future<void>>[];
      
      for (final entry in dataLoaders.entries) {
        final key = entry.key;
        final loader = entry.value;
        
        // Only preload if not already cached
        if (!_isMemoryCacheValid(key) && await _getPersistentCache(key) == null) {
          futures.add(
            loader().then((data) => set(key, data)).catchError((e) {
              AppLogger.warning('⚠️ Failed to preload data for key $key: $e');
            })
          );
        }
      }
      
      await Future.wait(futures);
      AppLogger.info('✅ Preloading completed');
    } catch (e) {
      AppLogger.error('❌ Error preloading data: $e');
    }
  }

  // Private helper methods
  bool _isMemoryCacheValid(String key, [Duration? customExpiration]) {
    if (!_memoryCache.containsKey(key) || !_memoryCacheTimestamps.containsKey(key)) {
      return false;
    }
    
    final expiration = customExpiration ?? _memoryExpiration;
    final timestamp = _memoryCacheTimestamps[key]!;
    return DateTime.now().difference(timestamp) < expiration;
  }

  void _setMemoryCache<T>(String key, T data, [String? dataHash]) {
    _memoryCache[key] = data;
    _memoryCacheTimestamps[key] = DateTime.now();
    if (dataHash != null) {
      _memoryCacheHashes[key] = dataHash;
    }
  }

  void _removeFromMemoryCache(String key) {
    _memoryCache.remove(key);
    _memoryCacheTimestamps.remove(key);
    _memoryCacheHashes.remove(key);
  }

  String _generateDataHash<T>(T data) {
    final dataString = jsonEncode(data);
    final bytes = utf8.encode(dataString);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  void _recordHit(String key) {
    _hitCounts[key] = (_hitCounts[key] ?? 0) + 1;
  }

  void _recordMiss(String key) {
    _missCounts[key] = (_missCounts[key] ?? 0) + 1;
  }

  void _recordAccessTime(String key, Duration duration) {
    _accessTimes[key] = duration;
  }

  Future<T?> _getPersistentCache<T>(String key, [Duration? customExpiration]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataKey = '$_persistentCachePrefix$key';
      final timestampKey = '$dataKey$_timestampSuffix';
      
      final dataString = prefs.getString(dataKey);
      final timestampString = prefs.getString(timestampKey);
      
      if (dataString == null || timestampString == null) {
        return null;
      }
      
      final timestamp = DateTime.parse(timestampString);
      final expiration = customExpiration ?? _persistentExpiration;
      
      if (DateTime.now().difference(timestamp) > expiration) {
        // Remove expired data
        await prefs.remove(dataKey);
        await prefs.remove(timestampKey);
        return null;
      }
      
      final data = jsonDecode(dataString);
      return data as T?;
    } catch (e) {
      AppLogger.warning('⚠️ Error getting persistent cache for key $key: $e');
      return null;
    }
  }

  Future<void> _setPersistentCache<T>(String key, T data, String dataHash, Map<String, dynamic>? metadata) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataKey = '$_persistentCachePrefix$key';
      final timestampKey = '$dataKey$_timestampSuffix';
      final hashKey = '$dataKey$_hashSuffix';
      
      await prefs.setString(dataKey, jsonEncode(data));
      await prefs.setString(timestampKey, DateTime.now().toIso8601String());
      await prefs.setString(hashKey, dataHash);
      
      if (metadata != null) {
        await prefs.setString('${dataKey}_metadata', jsonEncode(metadata));
      }
    } catch (e) {
      AppLogger.warning('⚠️ Error setting persistent cache for key $key: $e');
    }
  }

  Future<void> _removePersistentCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataKey = '$_persistentCachePrefix$key';
      
      await prefs.remove(dataKey);
      await prefs.remove('$dataKey$_timestampSuffix');
      await prefs.remove('$dataKey$_hashSuffix');
      await prefs.remove('${dataKey}_metadata');
    } catch (e) {
      AppLogger.warning('⚠️ Error removing persistent cache for key $key: $e');
    }
  }

  Future<void> _invalidatePersistentPattern(String pattern) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => 
          key.startsWith(_persistentCachePrefix) && key.contains(pattern));
      
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (e) {
      AppLogger.warning('⚠️ Error invalidating persistent cache pattern $pattern: $e');
    }
  }

  Future<void> _optimizePersistentCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final keysToRemove = <String>[];
      
      final dataKeys = prefs.getKeys().where((key) => 
          key.startsWith(_persistentCachePrefix) && !key.endsWith(_timestampSuffix) && !key.endsWith(_hashSuffix));
      
      for (final dataKey in dataKeys) {
        final timestampKey = '$dataKey$_timestampSuffix';
        final timestampString = prefs.getString(timestampKey);
        
        if (timestampString != null) {
          final timestamp = DateTime.parse(timestampString);
          if (now.difference(timestamp) > _persistentExpiration) {
            keysToRemove.add(dataKey);
            keysToRemove.add(timestampKey);
            keysToRemove.add('$dataKey$_hashSuffix');
            keysToRemove.add('${dataKey}_metadata');
          }
        }
      }
      
      for (final key in keysToRemove) {
        await prefs.remove(key);
      }
      
      AppLogger.info('🔧 Optimized persistent cache: removed ${keysToRemove.length} expired items');
    } catch (e) {
      AppLogger.warning('⚠️ Error optimizing persistent cache: $e');
    }
  }
}
