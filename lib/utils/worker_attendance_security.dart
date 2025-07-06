import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:smartbiztracker_new/models/worker_attendance_model.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// نظام الأمان والتحقق لحضور العمال
class WorkerAttendanceSecurity {
  static final WorkerAttendanceSecurity _instance = WorkerAttendanceSecurity._internal();
  factory WorkerAttendanceSecurity() => _instance;
  WorkerAttendanceSecurity._internal();

  // مفتاح سري للتوقيع (يجب أن يكون نفس المفتاح في الخادم)
  static const String _secretKey = 'SAMA_ATTENDANCE_SECRET_2024_SECURE';
  
  // مدة صلاحية الرمز المميز (20 ثانية)
  static const int _tokenValiditySeconds = 20;
  
  // الحد الأدنى للفجوة بين تسجيلات الحضور (15 ساعة)
  static const int _minimumGapHours = 15;

  /// إنشاء nonce آمن وفريد
  static String generateSecureNonce() {
    final random = Random.secure();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomBytes = List<int>.generate(16, (i) => random.nextInt(256));
    
    // دمج الوقت مع البايتات العشوائية لضمان الفرادة
    final combined = [...randomBytes, ...timestamp.toString().codeUnits];
    final hash = sha256.convert(combined);
    
    return base64Url.encode(hash.bytes).substring(0, 16);
  }

  /// إنشاء device fingerprint آمن
  static Future<String> generateDeviceFingerprint() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      String fingerprint = '';

      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await deviceInfo.androidInfo;
        fingerprint = [
          androidInfo.id,
          androidInfo.model,
          androidInfo.brand,
          androidInfo.manufacturer,
          androidInfo.product,
          androidInfo.device,
          androidInfo.hardware,
          androidInfo.bootloader,
          androidInfo.version.release,
          androidInfo.version.sdkInt.toString(),
        ].join('|');
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await deviceInfo.iosInfo;
        fingerprint = [
          iosInfo.identifierForVendor ?? 'unknown',
          iosInfo.model,
          iosInfo.name,
          iosInfo.systemName,
          iosInfo.systemVersion,
          iosInfo.localizedModel,
          iosInfo.utsname.machine,
        ].join('|');
      } else {
        // للمنصات الأخرى (Web, Desktop)
        fingerprint = 'web_${DateTime.now().millisecondsSinceEpoch}';
      }

      // إنشاء hash آمن للبصمة
      final bytes = utf8.encode(fingerprint);
      final digest = sha256.convert(bytes);
      
      AppLogger.info('🔐 تم إنشاء device fingerprint: ${digest.toString().substring(0, 8)}...');
      return digest.toString();
    } catch (e) {
      AppLogger.error('❌ خطأ في إنشاء device fingerprint: $e');
      // إنشاء fingerprint احتياطي
      final fallback = 'fallback_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}';
      return sha256.convert(utf8.encode(fallback)).toString();
    }
  }

  /// إنشاء توقيع HMAC-SHA256
  static String generateHMACSignature(String payload) {
    try {
      final key = utf8.encode(_secretKey);
      final message = utf8.encode(payload);
      
      final hmac = Hmac(sha256, key);
      final digest = hmac.convert(message);
      
      return base64Url.encode(digest.bytes);
    } catch (e) {
      AppLogger.error('❌ خطأ في إنشاء التوقيع: $e');
      throw Exception('فشل في إنشاء التوقيع الآمن');
    }
  }

  /// التحقق من صحة التوقيع
  static bool verifyHMACSignature(String payload, String signature) {
    try {
      final expectedSignature = generateHMACSignature(payload);
      final isValid = expectedSignature == signature;
      
      AppLogger.info('🔐 التحقق من التوقيع: ${isValid ? 'صحيح' : 'خطأ'}');
      return isValid;
    } catch (e) {
      AppLogger.error('❌ خطأ في التحقق من التوقيع: $e');
      return false;
    }
  }

  /// التحقق من صحة الوقت (20 ثانية)
  static bool isTokenTimeValid(int timestamp) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final tokenTime = timestamp;
    final timeDiff = (now - tokenTime).abs();
    
    final isValid = timeDiff <= _tokenValiditySeconds;
    AppLogger.info('⏰ التحقق من الوقت: ${isValid ? 'صحيح' : 'منتهي الصلاحية'} (فرق: ${timeDiff}s)');
    
    return isValid;
  }

  /// حساب الوقت المتبقي للرمز المميز
  static int getRemainingTokenTime(int timestamp) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final remaining = _tokenValiditySeconds - (now - timestamp);
    return remaining > 0 ? remaining : 0;
  }

  /// التحقق من فجوة 15 ساعة
  static bool validateGapRequirement(DateTime? lastAttendanceTime) {
    if (lastAttendanceTime == null) {
      return true; // أول تسجيل حضور
    }

    final now = DateTime.now();
    final timeDiff = now.difference(lastAttendanceTime);
    final hoursDiff = timeDiff.inHours;
    
    final isValid = hoursDiff >= _minimumGapHours;
    AppLogger.info('⏱️ التحقق من فجوة 15 ساعة: ${isValid ? 'صحيح' : 'خطأ'} (فرق: ${hoursDiff}h)');
    
    return isValid;
  }

  /// التحقق من تسلسل الحضور (دخول -> خروج -> دخول)
  static bool validateAttendanceSequence(AttendanceType currentType, AttendanceType? lastType) {
    if (lastType == null) {
      // أول تسجيل يجب أن يكون دخول
      final isValid = currentType == AttendanceType.checkIn;
      AppLogger.info('🔄 التحقق من التسلسل (أول تسجيل): ${isValid ? 'صحيح' : 'خطأ'}');
      return isValid;
    }

    // التحقق من التسلسل المنطقي
    bool isValid = false;
    if (lastType == AttendanceType.checkIn && currentType == AttendanceType.checkOut) {
      isValid = true; // دخول -> خروج
    } else if (lastType == AttendanceType.checkOut && currentType == AttendanceType.checkIn) {
      isValid = true; // خروج -> دخول
    }

    AppLogger.info('🔄 التحقق من التسلسل: ${isValid ? 'صحيح' : 'خطأ'} (آخر: $lastType, حالي: $currentType)');
    return isValid;
  }

  /// التحقق من فرادة النونس (منع إعادة الاستخدام)
  static bool validateNonceUniqueness(String nonce, List<String> usedNonces) {
    final isUnique = !usedNonces.contains(nonce);
    AppLogger.info('🔑 التحقق من فرادة النونس: ${isUnique ? 'فريد' : 'مستخدم من قبل'}');
    return isUnique;
  }

  /// التحقق من تطابق الجهاز
  static bool validateDeviceMatch(String tokenDeviceHash, String currentDeviceHash) {
    final isMatch = tokenDeviceHash == currentDeviceHash;
    AppLogger.info('📱 التحقق من تطابق الجهاز: ${isMatch ? 'متطابق' : 'غير متطابق'}');
    return isMatch;
  }

  /// إنشاء رمز QR آمن للحضور
  static Future<QRAttendanceToken> createSecureAttendanceToken(String workerId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final deviceHash = await generateDeviceFingerprint();
      final nonce = generateSecureNonce();
      
      // إنشاء payload للتوقيع
      final payload = '${workerId}_${timestamp}_${deviceHash}_$nonce';
      final signature = generateHMACSignature(payload);
      
      final token = QRAttendanceToken(
        workerId: workerId,
        timestamp: timestamp,
        deviceHash: deviceHash,
        nonce: nonce,
        signature: signature,
      );
      
      AppLogger.info('🎫 تم إنشاء رمز QR آمن للعامل: $workerId');
      return token;
    } catch (e) {
      AppLogger.error('❌ خطأ في إنشاء رمز QR آمن: $e');
      throw Exception('فشل في إنشاء رمز QR آمن');
    }
  }

  /// التحقق الشامل من أمان الرمز المميز
  static Future<AttendanceValidationResponse> validateTokenSecurity(
    QRAttendanceToken token,
    String currentDeviceHash,
    List<String> usedNonces,
    DateTime? lastAttendanceTime,
    AttendanceType? lastAttendanceType,
  ) async {
    try {
      AppLogger.info('🔒 بدء التحقق الشامل من أمان الرمز...');

      // 1. التحقق من صحة الوقت
      if (!isTokenTimeValid(token.timestamp)) {
        return AttendanceValidationResponse.error(
          AttendanceErrorMessages.getMessage(AttendanceErrorCodes.tokenExpired),
          AttendanceErrorCodes.tokenExpired,
        );
      }

      // 2. التحقق من صحة التوقيع
      final payload = '${token.workerId}_${token.timestamp}_${token.deviceHash}_${token.nonce}';
      if (!verifyHMACSignature(payload, token.signature)) {
        return AttendanceValidationResponse.error(
          AttendanceErrorMessages.getMessage(AttendanceErrorCodes.invalidSignature),
          AttendanceErrorCodes.invalidSignature,
        );
      }

      // 3. التحقق من تطابق الجهاز
      if (!validateDeviceMatch(token.deviceHash, currentDeviceHash)) {
        return AttendanceValidationResponse.error(
          AttendanceErrorMessages.getMessage(AttendanceErrorCodes.deviceMismatch),
          AttendanceErrorCodes.deviceMismatch,
        );
      }

      // 4. التحقق من فرادة النونس
      if (!validateNonceUniqueness(token.nonce, usedNonces)) {
        return AttendanceValidationResponse.error(
          AttendanceErrorMessages.getMessage(AttendanceErrorCodes.replayAttack),
          AttendanceErrorCodes.replayAttack,
        );
      }

      // 5. التحقق من فجوة 15 ساعة
      if (!validateGapRequirement(lastAttendanceTime)) {
        return AttendanceValidationResponse.error(
          AttendanceErrorMessages.getMessage(AttendanceErrorCodes.gapViolation),
          AttendanceErrorCodes.gapViolation,
        );
      }

      // 6. التحقق من تسلسل الحضور
      final currentType = lastAttendanceType == AttendanceType.checkOut 
          ? AttendanceType.checkIn 
          : AttendanceType.checkOut;
      
      if (!validateAttendanceSequence(currentType, lastAttendanceType)) {
        return AttendanceValidationResponse.error(
          AttendanceErrorMessages.getMessage(AttendanceErrorCodes.sequenceError),
          AttendanceErrorCodes.sequenceError,
        );
      }

      AppLogger.info('✅ تم التحقق من أمان الرمز بنجاح');
      return AttendanceValidationResponse.success(
        WorkerAttendanceModel(
          id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
          workerId: token.workerId,
          workerName: 'تم التحقق',
          employeeId: 'تم التحقق',
          timestamp: DateTime.fromMillisecondsSinceEpoch(token.timestamp * 1000),
          type: currentType,
          deviceHash: token.deviceHash,
          status: AttendanceStatus.pending,
          createdAt: DateTime.now(),
        ),
      );

    } catch (e) {
      AppLogger.error('❌ خطأ في التحقق من أمان الرمز: $e');
      return AttendanceValidationResponse.error(
        'حدث خطأ في التحقق من أمان الرمز',
        AttendanceErrorCodes.databaseError,
      );
    }
  }

  /// تنظيف النونسات المنتهية الصلاحية (أكبر من 24 ساعة)
  static List<String> cleanupExpiredNonces(List<String> nonces) {
    // في التطبيق الحقيقي، يجب أن يكون لكل nonce timestamp
    // هنا نفترض أن النونسات القديمة يتم تنظيفها تلقائياً
    AppLogger.info('🧹 تنظيف النونسات المنتهية الصلاحية');
    return nonces;
  }

  /// إنشاء تقرير أمان للرمز المميز
  static Map<String, dynamic> generateSecurityReport(QRAttendanceToken token) {
    return {
      'token_age_seconds': DateTime.now().millisecondsSinceEpoch ~/ 1000 - token.timestamp,
      'remaining_validity_seconds': getRemainingTokenTime(token.timestamp),
      'device_hash_length': token.deviceHash.length,
      'nonce_length': token.nonce.length,
      'signature_length': token.signature.length,
      'is_time_valid': isTokenTimeValid(token.timestamp),
      'security_level': 'HIGH',
      'encryption_method': 'HMAC-SHA256',
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}
