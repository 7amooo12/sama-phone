import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_logger.dart';

/// Service to handle local storage for offline mode
class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  late SharedPreferences _prefs;
  
  /// Initialize the service
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    AppLogger.info('LocalStorageService initialized');
  }

  /// Store data in local storage
  Future<bool> storeData(String key, dynamic data) async {
    try {
      String jsonData = json.encode(data);
      await _prefs.setString(key, jsonData);
      return true;
    } catch (e) {
      AppLogger.error('Error storing data in local storage: $e');
      return false;
    }
  }

  /// Get data from local storage
  dynamic getData(String key) {
    try {
      String? jsonData = _prefs.getString(key);
      if (jsonData == null) {
        return null;
      }
      return json.decode(jsonData);
    } catch (e) {
      AppLogger.error('Error retrieving data from local storage: $e');
      return null;
    }
  }

  /// Remove data from local storage
  Future<bool> removeData(String key) async {
    try {
      await _prefs.remove(key);
      return true;
    } catch (e) {
      AppLogger.error('Error removing data from local storage: $e');
      return false;
    }
  }

  /// Clear all data from local storage
  Future<bool> clearAll() async {
    try {
      await _prefs.clear();
      return true;
    } catch (e) {
      AppLogger.error('Error clearing local storage: $e');
      return false;
    }
  }

  /// Store sync queue for offline changes
  Future<bool> addToSyncQueue(String table, Map<String, dynamic> data, String operation) async {
    try {
      List<Map<String, dynamic>> syncQueue = getSyncQueue();
      
      syncQueue.add({
        'table': table,
        'data': data,
        'operation': operation,
        'timestamp': DateTime.now().toIso8601String()
      });
      
      return await storeData('sync_queue', syncQueue);
    } catch (e) {
      AppLogger.error('Error adding to sync queue: $e');
      return false;
    }
  }

  /// Get sync queue
  List<Map<String, dynamic>> getSyncQueue() {
    try {
      dynamic data = getData('sync_queue');
      if (data == null) {
        return [];
      }
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      AppLogger.error('Error getting sync queue: $e');
      return [];
    }
  }

  /// Remove item from sync queue
  Future<bool> removeFromSyncQueue(int index) async {
    try {
      List<Map<String, dynamic>> syncQueue = getSyncQueue();
      if (index >= 0 && index < syncQueue.length) {
        syncQueue.removeAt(index);
        return await storeData('sync_queue', syncQueue);
      }
      return false;
    } catch (e) {
      AppLogger.error('Error removing from sync queue: $e');
      return false;
    }
  }

  /// Clear sync queue
  Future<bool> clearSyncQueue() async {
    try {
      return await storeData('sync_queue', []);
    } catch (e) {
      AppLogger.error('Error clearing sync queue: $e');
      return false;
    }
  }

  /// Store user data for offline login
  Future<bool> storeUserData(Map<String, dynamic> userData) async {
    try {
      return await storeData('user_data', userData);
    } catch (e) {
      AppLogger.error('Error storing user data: $e');
      return false;
    }
  }

  /// Get user data for offline login
  Map<String, dynamic>? getUserData() {
    try {
      dynamic data = getData('user_data');
      if (data == null) {
        return null;
      }
      return Map<String, dynamic>.from(data);
    } catch (e) {
      AppLogger.error('Error getting user data: $e');
      return null;
    }
  }

  /// Store offline mode flag
  Future<bool> setOfflineMode(bool value) async {
    try {
      await _prefs.setBool('offline_mode', value);
      return true;
    } catch (e) {
      AppLogger.error('Error setting offline mode: $e');
      return false;
    }
  }

  /// Get offline mode flag
  bool getOfflineMode() {
    try {
      return _prefs.getBool('offline_mode') ?? false;
    } catch (e) {
      AppLogger.error('Error getting offline mode: $e');
      return false;
    }
  }

  /// Cache table data for offline use
  Future<bool> cacheTableData(String table, List<Map<String, dynamic>> data) async {
    try {
      return await storeData('table_$table', data);
    } catch (e) {
      AppLogger.error('Error caching table data: $e');
      return false;
    }
  }

  /// Get cached table data
  List<Map<String, dynamic>> getCachedTableData(String table) {
    try {
      dynamic data = getData('table_$table');
      if (data == null) {
        return [];
      }
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      AppLogger.error('Error getting cached table data: $e');
      return [];
    }
  }
} 