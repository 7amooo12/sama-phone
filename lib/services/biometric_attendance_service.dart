/// Biometric Attendance Service for Worker Attendance System
/// 
/// This service handles biometric authentication for attendance with location validation
/// integration for the SmartBizTracker system.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../models/location_models.dart';
import '../models/attendance_models.dart';
import '../services/location_service.dart';
import '../utils/app_logger.dart';

class BiometricAttendanceService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final LocationService _locationService = LocationService();
  final SupabaseClient _supabase = Supabase.instance.client;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// التحقق من توفر المصادقة البيومترية
  Future<BiometricAvailabilityResult> checkBiometricAvailability() async {
    try {
      AppLogger.info('🔍 فحص توفر المصادقة البيومترية...');

      // فحص دعم الجهاز للمصادقة البيومترية
      bool isAvailable = await _localAuth.canCheckBiometrics;
      bool isDeviceSupported = await _localAuth.isDeviceSupported();

      if (!isAvailable || !isDeviceSupported) {
        return BiometricAvailabilityResult(
          isAvailable: false,
          errorMessage: 'المصادقة البيومترية غير مدعومة على هذا الجهاز',
          supportedTypes: [],
        );
      }

      // الحصول على أنواع المصادقة المتاحة
      List<BiometricType> availableBiometrics = await _localAuth.getAvailableBiometrics();

      if (availableBiometrics.isEmpty) {
        return BiometricAvailabilityResult(
          isAvailable: false,
          errorMessage: 'لا توجد بيانات بيومترية مسجلة على الجهاز',
          supportedTypes: [],
        );
      }

      AppLogger.info('✅ المصادقة البيومترية متاحة: ${availableBiometrics.length} نوع');
      return BiometricAvailabilityResult(
        isAvailable: true,
        supportedTypes: availableBiometrics,
      );
    } catch (e) {
      AppLogger.error('❌ خطأ في فحص المصادقة البيومترية: $e');
      return BiometricAvailabilityResult(
        isAvailable: false,
        errorMessage: 'خطأ في فحص المصادقة البيومترية: $e',
        supportedTypes: [],
      );
    }
  }

  /// تنفيذ المصادقة البيومترية
  Future<BiometricAuthResult> authenticateWithBiometrics({
    required String reason,
  }) async {
    try {
      AppLogger.info('🔐 بدء المصادقة البيومترية...');

      // فحص التوفر أولاً
      BiometricAvailabilityResult availability = await checkBiometricAvailability();
      if (!availability.isAvailable) {
        return BiometricAuthResult(
          isAuthenticated: false,
          errorMessage: availability.errorMessage,
        );
      }

      // تنفيذ المصادقة
      bool isAuthenticated = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (isAuthenticated) {
        AppLogger.info('✅ تمت المصادقة البيومترية بنجاح');
        return BiometricAuthResult(isAuthenticated: true);
      } else {
        return BiometricAuthResult(
          isAuthenticated: false,
          errorMessage: 'فشلت المصادقة البيومترية',
        );
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في المصادقة البيومترية: $e');
      return BiometricAuthResult(
        isAuthenticated: false,
        errorMessage: 'خطأ في المصادقة البيومترية: $e',
      );
    }
  }

  /// معالجة حضور العامل بالمصادقة البيومترية
  Future<BiometricAttendanceResult> processBiometricAttendance({
    required String workerId,
    required AttendanceType attendanceType,
    String? warehouseId,
  }) async {
    try {
      AppLogger.info('⚡ بدء معالجة الحضور البيومتري للعامل: $workerId');

      // 0. إنشاء أو تحديث ملف الحضور للعامل
      await _ensureWorkerAttendanceProfile(workerId);

      // 1. التحقق من صحة الموقع أولاً
      LocationValidationResult locationValidation =
          await _locationService.validateLocationForAttendance(warehouseId);

      if (!locationValidation.isValid) {
        return BiometricAttendanceResult(
          success: false,
          errorMessage: locationValidation.errorMessage ?? 'موقعك خارج النطاق المسموح',
          errorType: BiometricAttendanceErrorType.locationValidationFailed,
          locationValidation: locationValidation,
        );
      }

      // 2. تنفيذ المصادقة البيومترية
      BiometricAuthResult authResult = await authenticateWithBiometrics(
        reason: attendanceType == AttendanceType.checkIn 
            ? 'تأكيد هويتك لتسجيل الحضور'
            : 'تأكيد هويتك لتسجيل الانصراف',
      );

      if (!authResult.isAuthenticated) {
        return BiometricAttendanceResult(
          success: false,
          errorMessage: authResult.errorMessage ?? 'فشلت المصادقة البيومترية',
          errorType: BiometricAttendanceErrorType.biometricAuthFailed,
          locationValidation: locationValidation,
        );
      }

      // 3. إنشاء معلومات الجهاز
      String deviceHash = await _generateDeviceHash();
      AppLogger.info('🔐 Device hash للحضور: ${deviceHash.substring(0, 8)}...');

      // 4. إنشاء معلومات الموقع
      AttendanceLocationInfo? locationInfo;
      if (locationValidation.currentLatitude != null && 
          locationValidation.currentLongitude != null) {
        locationInfo = AttendanceLocationInfo(
          latitude: locationValidation.currentLatitude!,
          longitude: locationValidation.currentLongitude!,
          timestamp: DateTime.now(),
          locationValidated: true,
          distanceFromWarehouse: locationValidation.distanceFromWarehouse,
        );
      }

      // 5. تسجيل الحضور في قاعدة البيانات
      final response = await _supabase.rpc('process_biometric_attendance', params: {
        'p_worker_id': workerId,
        'p_attendance_type': attendanceType.value,
        'p_device_hash': deviceHash,
        'p_location_info': locationInfo?.toJson(),
        'p_location_validation': locationValidation.toJson(),
      });

      if (response == null) {
        throw Exception('لا توجد استجابة من خادم قاعدة البيانات');
      }

      final result = Map<String, dynamic>.from(response);
      
      if (result['success'] == true) {
        AppLogger.info('✅ تم تسجيل الحضور البيومتري بنجاح');

        return BiometricAttendanceResult(
          success: true,
          attendanceId: result['attendance_id'],
          locationValidation: locationValidation,
          locationInfo: locationInfo,
        );
      } else {
        String errorMessage = result['error_message'] ?? 'فشل في تسجيل الحضور';
        String errorCode = result['error_code'] ?? 'UNKNOWN_ERROR';

        // Log debug information if available
        if (result['debug_info'] != null) {
          AppLogger.info('🔍 Debug info: ${result['debug_info']}');
        }

        // إذا كان الخطأ متعلق بعدم وجود العامل، نحاول إنشاء الملف مرة أخرى
        if (errorCode == 'WORKER_NOT_FOUND') {
          AppLogger.warning('⚠️ العامل غير مسجل، محاولة إعادة التسجيل...');
          try {
            await _ensureWorkerAttendanceProfile(workerId);
            AppLogger.info('🔄 إعادة محاولة تسجيل الحضور بعد إنشاء الملف...');

            // إعادة محاولة تسجيل الحضور
            final retryResponse = await _supabase.rpc('process_biometric_attendance', params: {
              'p_worker_id': workerId,
              'p_attendance_type': attendanceType.value,
              'p_device_hash': deviceHash,
              'p_location_info': locationInfo?.toJson(),
              'p_location_validation': locationValidation.toJson(),
            });

            if (retryResponse != null && retryResponse['success'] == true) {
              AppLogger.info('✅ نجح تسجيل الحضور في المحاولة الثانية');
              return BiometricAttendanceResult(
                success: true,
                attendanceId: retryResponse['attendance_id'],
                locationValidation: locationValidation,
                locationInfo: locationInfo,
              );
            }
          } catch (retryError) {
            AppLogger.error('❌ فشلت إعادة المحاولة: $retryError');
            errorMessage = 'فشل في تسجيل العامل في النظام. يرجى المحاولة مرة أخرى أو الاتصال بالإدارة.';
          }
        }
        // إذا كان الخطأ متعلق بالتسلسل، حاول تشخيص وإصلاح المشكلة
        else if (errorCode == 'SEQUENCE_ERROR') {
          AppLogger.warning('⚠️ خطأ في تسلسل الحضور، محاولة التشخيص والإصلاح...');

          try {
            final diagnosisResult = await diagnoseAndFixWorkerState(workerId);
            if (diagnosisResult['success'] == true && diagnosisResult['fix_applied'] != null) {
              AppLogger.info('🔄 تم إصلاح حالة العامل، إعادة محاولة تسجيل الحضور...');

              // إعادة محاولة تسجيل الحضور بعد الإصلاح
              final retryResponse = await _supabase.rpc('process_biometric_attendance', params: {
                'p_worker_id': workerId,
                'p_attendance_type': attendanceType.value,
                'p_device_hash': deviceHash,
                'p_location_info': locationInfo?.toJson(),
                'p_location_validation': locationValidation.toJson(),
              });

              if (retryResponse != null && retryResponse['success'] == true) {
                AppLogger.info('✅ تم تسجيل الحضور بنجاح بعد إصلاح حالة العامل');

                return BiometricAttendanceResult(
                  success: true,
                  attendanceId: retryResponse['attendance_id'],
                  locationValidation: locationValidation,
                  locationInfo: locationInfo,
                );
              }
            }
          } catch (diagnosisError) {
            AppLogger.error('❌ فشل في تشخيص حالة العامل: $diagnosisError');
          }
        }

        return BiometricAttendanceResult(
          success: false,
          errorMessage: errorMessage,
          errorType: BiometricAttendanceErrorType.databaseError,
          locationValidation: locationValidation,
        );
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في معالجة الحضور البيومتري: $e');
      return BiometricAttendanceResult(
        success: false,
        errorMessage: 'خطأ في معالجة الحضور: $e',
        errorType: BiometricAttendanceErrorType.unknownError,
      );
    }
  }

  /// التأكد من وجود ملف الحضور للعامل أو إنشاؤه
  Future<void> _ensureWorkerAttendanceProfile(String workerId) async {
    try {
      AppLogger.info('🔍 التحقق من ملف الحضور للعامل: $workerId');

      final deviceHash = await _generateDeviceHash();
      AppLogger.info('🔐 Device hash للتحقق: ${deviceHash.substring(0, 8)}...');

      // الحصول على معلومات الجهاز
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

      // استخدام الدالة المحفوظة الآمنة للحصول على الملف أو إنشاؤه
      final response = await _supabase.rpc('get_or_create_worker_profile', params: {
        'p_worker_id': workerId,
        'p_device_hash': deviceHash,
        'p_device_model': deviceModel,
        'p_device_os_version': deviceOsVersion,
      });

      if (response != null && response.isNotEmpty) {
        final profileData = response[0];
        final createdAt = profileData['created_at'] as String?;

        // تحديد ما إذا كان الملف جديداً (تم إنشاؤه خلال آخر 10 ثوانٍ)
        bool isNewProfile = false;
        if (createdAt != null) {
          final createdTime = DateTime.parse(createdAt);
          isNewProfile = createdTime.isAfter(
            DateTime.now().subtract(const Duration(seconds: 10))
          );
        }

        if (isNewProfile) {
          AppLogger.info('✅ تم إنشاء ملف حضور جديد للعامل: $workerId');
        } else {
          AppLogger.info('✅ ملف الحضور موجود للعامل: $workerId');
        }
      } else {
        throw Exception('فشل في الحصول على استجابة من دالة إدارة ملف الحضور');
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في التأكد من ملف الحضور: $e');
      // رمي الاستثناء لأن الدالة المحفوظة تتعامل مع الأمان بشكل صحيح
      throw Exception('فشل في التأكد من ملف الحضور: ${e.toString()}');
    }
  }

  /// إنشاء هاش الجهاز
  Future<String> _generateDeviceHash() async {
    try {
      String deviceId = '';

      // استخدام معلومات الجهاز المتاحة
      try {
        final androidInfo = await _deviceInfo.androidInfo;
        deviceId = '${androidInfo.model}_${androidInfo.id}_android';
      } catch (e) {
        try {
          final iosInfo = await _deviceInfo.iosInfo;
          deviceId = '${iosInfo.model}_${iosInfo.identifierForVendor}_ios';
        } catch (e) {
          deviceId = 'unknown_device_${DateTime.now().millisecondsSinceEpoch}';
        }
      }

      // إنشاء هاش SHA-256
      var bytes = utf8.encode(deviceId);
      var digest = sha256.convert(bytes);
      return digest.toString();
    } catch (e) {
      AppLogger.error('❌ خطأ في إنشاء هاش الجهاز: $e');
      return 'unknown_device_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// إنشاء هاش آمن للجهاز مع معلومات إضافية
  Future<String> _generateSecureDeviceHash() async {
    try {
      String deviceId = '';
      String additionalInfo = '';

      // جمع معلومات الجهاز حسب النظام
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        deviceId = '${androidInfo.model}_${androidInfo.id}_android';
        additionalInfo = '${androidInfo.brand}_${androidInfo.manufacturer}_${androidInfo.version.release}';
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        deviceId = '${iosInfo.model}_${iosInfo.identifierForVendor}_ios';
        additionalInfo = '${iosInfo.systemName}_${iosInfo.systemVersion}_${iosInfo.name}';
      } else {
        deviceId = 'unknown_device_${DateTime.now().millisecondsSinceEpoch}';
        additionalInfo = 'web_platform';
      }

      // إنشاء هاش مركب آمن
      final combinedString = '$deviceId|$additionalInfo|${DateTime.now().day}';
      final bytes = utf8.encode(combinedString);
      final digest = sha256.convert(bytes);

      AppLogger.info('🔐 تم إنشاء هاش آمن للجهاز');
      return digest.toString();
    } catch (e) {
      AppLogger.error('❌ خطأ في إنشاء هاش الجهاز الآمن: $e');
      // إنشاء هاش احتياطي
      final fallback = 'fallback_${DateTime.now().millisecondsSinceEpoch}';
      return sha256.convert(utf8.encode(fallback)).toString();
    }
  }

  /// التحقق من أمان الجهاز
  Future<bool> _isDeviceSecure() async {
    try {
      // فحص إذا كان الجهاز محمي بكلمة مرور أو نمط
      bool isDeviceSupported = await _localAuth.isDeviceSupported();
      bool canCheckBiometrics = await _localAuth.canCheckBiometrics;

      if (!isDeviceSupported || !canCheckBiometrics) {
        return false;
      }

      // فحص توفر البيانات البيومترية
      List<BiometricType> availableBiometrics = await _localAuth.getAvailableBiometrics();
      return availableBiometrics.isNotEmpty;
    } catch (e) {
      AppLogger.error('❌ خطأ في فحص أمان الجهاز: $e');
      return false;
    }
  }

  /// إنشاء nonce آمن للجلسة
  String _generateSecureNonce() {
    final random = Random.secure();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomBytes = List<int>.generate(16, (i) => random.nextInt(256));

    // دمج الوقت مع البايتات العشوائية
    final combined = [...randomBytes, ...timestamp.toString().codeUnits];
    final hash = sha256.convert(combined);

    return base64Url.encode(hash.bytes).substring(0, 16);
  }

  /// التحقق من صحة الجلسة البيومترية
  Future<bool> validateBiometricSession(String sessionToken) async {
    try {
      // فحص صحة التوقيت (الجلسة صالحة لمدة 5 دقائق)
      final now = DateTime.now().millisecondsSinceEpoch;
      final sessionTime = int.tryParse(sessionToken.substring(0, 8), radix: 16) ?? 0;
      final timeDiff = now - sessionTime;

      if (timeDiff > 300000) { // 5 دقائق
        AppLogger.warning('⚠️ انتهت صلاحية الجلسة البيومترية');
        return false;
      }

      return true;
    } catch (e) {
      AppLogger.error('❌ خطأ في التحقق من الجلسة البيومترية: $e');
      return false;
    }
  }

  /// تشخيص وإصلاح حالة العامل في حالة وجود مشاكل في التسلسل
  Future<Map<String, dynamic>> diagnoseAndFixWorkerState(String workerId) async {
    try {
      final deviceHash = await _generateDeviceHash();

      // تشخيص الحالة الحالية
      final diagnosisResponse = await _supabase.rpc('diagnose_worker_attendance_state', params: {
        'p_worker_id': workerId,
        'p_device_hash': deviceHash,
      });

      if (diagnosisResponse != null) {
        final diagnosis = Map<String, dynamic>.from(diagnosisResponse);
        AppLogger.info('🔍 تشخيص حالة العامل: $diagnosis');

        // إذا كانت هناك مشكلة، حاول إصلاحها
        final recommendedAction = diagnosis['consistency_check']?['recommended_action'];
        if (recommendedAction != null && recommendedAction != 'NO_ACTION_NEEDED') {
          AppLogger.info('🔧 محاولة إصلاح حالة العامل...');

          final fixResponse = await _supabase.rpc('fix_worker_attendance_state', params: {
            'p_worker_id': workerId,
            'p_device_hash': deviceHash,
          });

          if (fixResponse != null) {
            final fixResult = Map<String, dynamic>.from(fixResponse);
            AppLogger.info('✅ تم إصلاح حالة العامل: ${fixResult['action_taken']}');

            return {
              'success': true,
              'diagnosis': diagnosis,
              'fix_applied': fixResult,
            };
          }
        }

        return {
          'success': true,
          'diagnosis': diagnosis,
          'fix_applied': null,
        };
      }

      return {
        'success': false,
        'error': 'فشل في تشخيص حالة العامل',
      };
    } catch (e) {
      AppLogger.error('❌ خطأ في تشخيص حالة العامل: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// معالجة أخطاء المصادقة البيومترية
  BiometricAuthResult _handleBiometricError(dynamic error) {
    String errorMessage = 'خطأ غير معروف في المصادقة البيومترية';

    if (error.toString().contains('UserCancel')) {
      errorMessage = 'تم إلغاء المصادقة البيومترية من قبل المستخدم';
    } else if (error.toString().contains('NotAvailable')) {
      errorMessage = 'المصادقة البيومترية غير متاحة على هذا الجهاز';
    } else if (error.toString().contains('NotEnrolled')) {
      errorMessage = 'لا توجد بيانات بيومترية مسجلة على الجهاز';
    } else if (error.toString().contains('LockedOut')) {
      errorMessage = 'تم قفل المصادقة البيومترية مؤقتاً. حاول مرة أخرى لاحقاً';
    } else if (error.toString().contains('PermanentlyLockedOut')) {
      errorMessage = 'تم قفل المصادقة البيومترية نهائياً. استخدم كلمة المرور';
    }

    return BiometricAuthResult(
      isAuthenticated: false,
      errorMessage: errorMessage,
    );
  }

  /// تنظيف الموارد
  void dispose() {
    AppLogger.info('🧹 تنظيف موارد خدمة المصادقة البيومترية');
  }
}


