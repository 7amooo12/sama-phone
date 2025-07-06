/// Database Integration Test for SmartBizTracker
/// 
/// This test verifies that the warehouse location settings and location validation
/// work correctly with the database and JSON serialization.

import 'package:flutter_test/flutter_test.dart';
import '../services/location_service.dart';
import '../models/location_models.dart';
import '../utils/app_logger.dart';

class DatabaseIntegrationTest {
  static final LocationService _locationService = LocationService();

  /// Test warehouse location settings database operations
  static Future<bool> testWarehouseLocationSettings() async {
    try {
      AppLogger.info('🧪 بدء اختبار إعدادات موقع المخزن...');

      // Test fetching warehouse location settings
      WarehouseLocationSettings? settings = 
          await _locationService.getWarehouseLocationSettings(null);

      if (settings != null) {
        AppLogger.info('✅ تم جلب إعدادات المخزن بنجاح');
        AppLogger.info('📍 اسم المخزن: ${settings.warehouseName}');
        AppLogger.info('📍 الإحداثيات: ${settings.latitude}, ${settings.longitude}');
        AppLogger.info('📍 نطاق الجيوفنس: ${settings.geofenceRadius} متر');
        AppLogger.info('📍 حالة التفعيل: ${settings.isActive}');
        
        // Test JSON serialization
        Map<String, dynamic> json = settings.toJson();
        WarehouseLocationSettings deserializedSettings = 
            WarehouseLocationSettings.fromJson(json);
        
        bool serializationTest = 
            settings.id == deserializedSettings.id &&
            settings.warehouseName == deserializedSettings.warehouseName &&
            settings.latitude == deserializedSettings.latitude &&
            settings.longitude == deserializedSettings.longitude &&
            settings.geofenceRadius == deserializedSettings.geofenceRadius &&
            settings.isActive == deserializedSettings.isActive;

        if (serializationTest) {
          AppLogger.info('✅ اختبار JSON serialization نجح');
        } else {
          AppLogger.error('❌ اختبار JSON serialization فشل');
          return false;
        }

        return true;
      } else {
        AppLogger.warning('⚠️ لم يتم العثور على إعدادات موقع المخزن');
        return false;
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في اختبار إعدادات موقع المخزن: $e');
      return false;
    }
  }

  /// Test location validation functionality
  static Future<bool> testLocationValidation() async {
    try {
      AppLogger.info('🧪 بدء اختبار التحقق من صحة الموقع...');

      // Test location validation
      LocationValidationResult result = 
          await _locationService.validateLocationForAttendance(null);

      AppLogger.info('📍 نتيجة التحقق: ${result.isValid ? "صحيح" : "غير صحيح"}');
      AppLogger.info('📍 حالة التحقق: ${result.status}');
      
      if (result.errorMessage != null) {
        AppLogger.info('📍 رسالة الخطأ: ${result.errorMessage}');
      }

      if (result.currentLatitude != null && result.currentLongitude != null) {
        AppLogger.info('📍 الموقع الحالي: ${result.currentLatitude}, ${result.currentLongitude}');
      }

      if (result.distanceFromWarehouse != null) {
        AppLogger.info('📍 المسافة من المخزن: ${result.distanceFromWarehouse!.toStringAsFixed(2)} متر');
      }

      // Test JSON serialization for LocationValidationResult
      Map<String, dynamic> json = result.toJson();
      LocationValidationResult deserializedResult = 
          LocationValidationResult.fromJson(json);

      bool serializationTest = 
          result.isValid == deserializedResult.isValid &&
          result.status == deserializedResult.status &&
          result.errorMessage == deserializedResult.errorMessage;

      if (serializationTest) {
        AppLogger.info('✅ اختبار JSON serialization للتحقق من الموقع نجح');
      } else {
        AppLogger.error('❌ اختبار JSON serialization للتحقق من الموقع فشل');
        return false;
      }

      return true;
    } catch (e) {
      AppLogger.error('❌ خطأ في اختبار التحقق من صحة الموقع: $e');
      return false;
    }
  }

  /// Test location service caching functionality
  static Future<bool> testLocationServiceCaching() async {
    try {
      AppLogger.info('🧪 بدء اختبار التخزين المؤقت لخدمة الموقع...');

      // Get cache status
      Map<String, dynamic> cacheStatus = _locationService.getCacheStatus();
      
      AppLogger.info('📊 حالة التخزين المؤقت:');
      cacheStatus.forEach((key, value) {
        AppLogger.info('  $key: $value');
      });

      // Test cache clearing
      _locationService.clearAllCaches();
      Map<String, dynamic> clearedCacheStatus = _locationService.getCacheStatus();
      
      bool cacheCleared = 
          clearedCacheStatus['position_cached'] == false &&
          clearedCacheStatus['warehouse_settings_cached'] == false &&
          clearedCacheStatus['validation_cached'] == false &&
          clearedCacheStatus['permission_cached'] == false;

      if (cacheCleared) {
        AppLogger.info('✅ اختبار مسح التخزين المؤقت نجح');
      } else {
        AppLogger.error('❌ اختبار مسح التخزين المؤقت فشل');
        return false;
      }

      return true;
    } catch (e) {
      AppLogger.error('❌ خطأ في اختبار التخزين المؤقت: $e');
      return false;
    }
  }

  /// Run all database integration tests
  static Future<bool> runAllTests() async {
    AppLogger.info('🚀 بدء اختبارات التكامل مع قاعدة البيانات...');

    List<Future<bool>> tests = [
      testWarehouseLocationSettings(),
      testLocationValidation(),
      testLocationServiceCaching(),
    ];

    List<bool> results = await Future.wait(tests);
    bool allTestsPassed = results.every((result) => result);

    if (allTestsPassed) {
      AppLogger.info('✅ جميع اختبارات التكامل مع قاعدة البيانات نجحت');
    } else {
      AppLogger.error('❌ بعض اختبارات التكامل مع قاعدة البيانات فشلت');
    }

    return allTestsPassed;
  }

  /// Dispose resources
  static void dispose() {
    _locationService.dispose();
  }
}
