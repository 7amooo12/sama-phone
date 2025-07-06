/// Worker Attendance Setup Utility
/// 
/// This utility helps initialize attendance profiles for workers who don't have them yet.
/// This is useful for existing workers who were created before the attendance system was implemented.

import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../utils/app_logger.dart';
import '../services/biometric_attendance_service.dart';

class WorkerAttendanceSetup {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Initialize attendance profiles for all workers who don't have them
  static Future<void> initializeAllWorkerProfiles() async {
    try {
      AppLogger.info('🔧 بدء تهيئة ملفات الحضور للعمال...');

      // Get all workers from the system
      final workersResponse = await _supabase
          .from('user_profiles')
          .select('id, name, email')
          .eq('role', 'worker')
          .eq('is_approved', true);

      if (workersResponse.isEmpty) {
        AppLogger.info('ℹ️ لا يوجد عمال في النظام');
        return;
      }

      AppLogger.info('👥 تم العثور على ${workersResponse.length} عامل');

      // Generate device hash (this will be the same for all workers on this device)
      final deviceHash = await _generateDeviceHash();
      
      // Get device information
      String deviceModel = 'Unknown Device';
      String deviceOsVersion = 'Unknown OS';
      
      try {
        if (Platform.isAndroid) {
          final androidInfo = await _deviceInfo.androidInfo;
          deviceModel = '${androidInfo.brand} ${androidInfo.model}';
          deviceOsVersion = 'Android ${androidInfo.version.release}';
        } else if (Platform.isIOS) {
          final iosInfo = await _deviceInfo.iosInfo;
          deviceModel = iosInfo.model;
          deviceOsVersion = '${iosInfo.systemName} ${iosInfo.systemVersion}';
        }
      } catch (e) {
        AppLogger.warning('⚠️ لا يمكن الحصول على معلومات الجهاز: $e');
      }

      int createdCount = 0;
      int existingCount = 0;

      for (final worker in workersResponse) {
        try {
          final workerId = worker['id'] as String;
          final workerName = worker['name'] as String;

          // Check if profile already exists
          final existingProfile = await _supabase
              .from('worker_attendance_profiles')
              .select()
              .eq('worker_id', workerId)
              .eq('device_hash', deviceHash)
              .maybeSingle();

          if (existingProfile == null) {
            // Create new profile
            await _supabase.from('worker_attendance_profiles').insert({
              'worker_id': workerId,
              'device_hash': deviceHash,
              'device_model': deviceModel,
              'device_os_version': deviceOsVersion,
              'is_active': true,
              'total_check_ins': 0,
              'total_check_outs': 0,
            });

            createdCount++;
            AppLogger.info('✅ تم إنشاء ملف حضور للعامل: $workerName');
          } else {
            existingCount++;
            AppLogger.info('ℹ️ ملف الحضور موجود للعامل: $workerName');
          }

          // Small delay to avoid overwhelming the database
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          AppLogger.error('❌ خطأ في معالجة العامل ${worker['name']}: $e');
        }
      }

      AppLogger.info('🎉 تم الانتهاء من تهيئة ملفات الحضور:');
      AppLogger.info('   📝 تم إنشاء: $createdCount ملف');
      AppLogger.info('   ✅ موجود مسبقاً: $existingCount ملف');
    } catch (e) {
      AppLogger.error('❌ خطأ في تهيئة ملفات الحضور: $e');
      rethrow;
    }
  }

  /// Initialize attendance profile for a specific worker
  static Future<bool> initializeWorkerProfile(String workerId) async {
    try {
      AppLogger.info('🔧 تهيئة ملف الحضور للعامل: $workerId');

      final deviceHash = await _generateDeviceHash();
      
      // Check if profile already exists
      final existingProfile = await _supabase
          .from('worker_attendance_profiles')
          .select()
          .eq('worker_id', workerId)
          .eq('device_hash', deviceHash)
          .maybeSingle();

      if (existingProfile != null) {
        AppLogger.info('ℹ️ ملف الحضور موجود مسبقاً للعامل: $workerId');
        return true;
      }

      // Get device information
      String deviceModel = 'Unknown Device';
      String deviceOsVersion = 'Unknown OS';
      
      try {
        if (Platform.isAndroid) {
          final androidInfo = await _deviceInfo.androidInfo;
          deviceModel = '${androidInfo.brand} ${androidInfo.model}';
          deviceOsVersion = 'Android ${androidInfo.version.release}';
        } else if (Platform.isIOS) {
          final iosInfo = await _deviceInfo.iosInfo;
          deviceModel = iosInfo.model;
          deviceOsVersion = '${iosInfo.systemName} ${iosInfo.systemVersion}';
        }
      } catch (e) {
        AppLogger.warning('⚠️ لا يمكن الحصول على معلومات الجهاز: $e');
      }

      // Create new profile
      await _supabase.from('worker_attendance_profiles').insert({
        'worker_id': workerId,
        'device_hash': deviceHash,
        'device_model': deviceModel,
        'device_os_version': deviceOsVersion,
        'is_active': true,
        'total_check_ins': 0,
        'total_check_outs': 0,
      });

      AppLogger.info('✅ تم إنشاء ملف الحضور للعامل: $workerId');
      return true;
    } catch (e) {
      AppLogger.error('❌ خطأ في إنشاء ملف الحضور للعامل $workerId: $e');
      return false;
    }
  }

  /// Generate device hash (same logic as BiometricAttendanceService)
  static Future<String> _generateDeviceHash() async {
    try {
      String deviceId = 'unknown';
      
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        deviceId = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? 'unknown';
      }
      
      // Create a simple hash from device ID and app identifier
      final combined = '$deviceId-smartbiztracker-attendance';
      return combined.hashCode.abs().toString();
    } catch (e) {
      AppLogger.warning('⚠️ خطأ في إنشاء هاش الجهاز: $e');
      return 'fallback-${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// Check if a worker has an attendance profile
  static Future<bool> hasAttendanceProfile(String workerId) async {
    try {
      final deviceHash = await _generateDeviceHash();
      
      final profile = await _supabase
          .from('worker_attendance_profiles')
          .select()
          .eq('worker_id', workerId)
          .eq('device_hash', deviceHash)
          .maybeSingle();

      return profile != null;
    } catch (e) {
      AppLogger.error('❌ خطأ في التحقق من ملف الحضور: $e');
      return false;
    }
  }
}
