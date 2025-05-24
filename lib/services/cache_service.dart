import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../utils/logger.dart';

/// A service for caching data to improve app performance
class CacheService {
  static const String _cachePrefix = 'cache_';
  static const Duration _defaultExpiration = Duration(hours: 24);

  /// Cache data with a specific key and expiration time
  static Future<void> setData(String key, dynamic data, {Duration? expiration}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        'data': data,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'expiration': (expiration ?? _defaultExpiration).inMilliseconds,
      };
      await prefs.setString(_cachePrefix + key, jsonEncode(cacheData));
    } catch (e) {
      debugPrint('Error caching data: $e');
    }
  }

  /// Get cached data for a specific key
  static Future<dynamic> getData(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedString = prefs.getString(_cachePrefix + key);
      
      if (cachedString == null) return null;
      
      final cacheData = jsonDecode(cachedString) as Map<String, dynamic>;
      final timestamp = cacheData['timestamp'] as int;
      final expiration = cacheData['expiration'] as int;
      
      if (DateTime.now().millisecondsSinceEpoch - timestamp > expiration) {
        await prefs.remove(_cachePrefix + key);
        return null;
      }
      
      return cacheData['data'];
    } catch (e) {
      debugPrint('Error retrieving cached data: $e');
      return null;
    }
  }

  /// Remove cached data for a specific key
  static Future<void> removeItem(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cachePrefix + key);
    } catch (e) {
      debugPrint('Error removing cached item: $e');
    }
  }

  /// Clear all cached data
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith(_cachePrefix)) {
        await prefs.remove(key);
        }
      }
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }

  /// Check if cache exists and is valid for a specific key
  static Future<bool> hasCachedData(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _cachePrefix + key;
      
      if (!prefs.containsKey(cacheKey)) {
        return false;
      }
      
      final String? cacheString = prefs.getString(cacheKey);
      if (cacheString == null) {
        return false;
      }
      
      final cacheData = jsonDecode(cacheString);
      final expiryTime = DateTime.fromMillisecondsSinceEpoch(cacheData['expiry']);
      
      // Check if cache has expired
      return !DateTime.now().isAfter(expiryTime);
    } catch (e) {
      AppLogger.error('Error checking cached data for key: $key', e);
      return false;
    }
  }
}
