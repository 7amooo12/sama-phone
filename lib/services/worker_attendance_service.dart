import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smartbiztracker_new/models/worker_attendance_model.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// خدمة إدارة حضور العمال مع نظام QR
class WorkerAttendanceService {
  static final WorkerAttendanceService _instance = WorkerAttendanceService._internal();
  factory WorkerAttendanceService() => _instance;
  WorkerAttendanceService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  
  // مفتاح سري للتوقيع (يجب أن يكون نفس المفتاح المستخدم في إنشاء QR)
  static const String _secretKey = 'SAMA_ATTENDANCE_SECRET_2024';
  
  /// إنشاء hash للجهاز
  Future<String> generateDeviceHash() async {
    try {
      String deviceIdentifier = '';
      
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        deviceIdentifier = '${androidInfo.id}_${androidInfo.model}_${androidInfo.brand}';
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        deviceIdentifier = '${iosInfo.identifierForVendor}_${iosInfo.model}_${iosInfo.systemVersion}';
      } else {
        // للمنصات الأخرى
        deviceIdentifier = 'web_${DateTime.now().millisecondsSinceEpoch}';
      }
      
      final bytes = utf8.encode(deviceIdentifier);
      final digest = sha256.convert(bytes);
      
      AppLogger.info('🔐 تم إنشاء device hash: ${digest.toString().substring(0, 8)}...');
      return digest.toString();
    } catch (e) {
      AppLogger.error('❌ خطأ في إنشاء device hash: $e');
      // إنشاء hash احتياطي
      final fallback = DateTime.now().millisecondsSinceEpoch.toString();
      return sha256.convert(utf8.encode(fallback)).toString();
    }
  }

  /// الحصول على معلومات الجهاز
  Future<DeviceInfo> getDeviceInfo() async {
    try {
      final deviceHash = await generateDeviceHash();
      
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return DeviceInfo(
          deviceId: androidInfo.id,
          deviceModel: androidInfo.model,
          deviceBrand: androidInfo.brand,
          osVersion: androidInfo.version.release,
          appVersion: '1.0.0', // يمكن الحصول عليها من package_info_plus
          deviceHash: deviceHash,
        );
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return DeviceInfo(
          deviceId: iosInfo.identifierForVendor ?? 'unknown',
          deviceModel: iosInfo.model,
          deviceBrand: 'Apple',
          osVersion: iosInfo.systemVersion,
          appVersion: '1.0.0',
          deviceHash: deviceHash,
        );
      } else {
        return DeviceInfo(
          deviceId: 'web_device',
          deviceModel: 'Web Browser',
          deviceBrand: 'Unknown',
          osVersion: 'Web',
          appVersion: '1.0.0',
          deviceHash: deviceHash,
        );
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في الحصول على معلومات الجهاز: $e');
      rethrow;
    }
  }

  /// إنشاء nonce عشوائي
  String generateNonce() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (i) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  /// التحقق من صحة التوقيع
  bool verifySignature(QRAttendanceToken token) {
    try {
      final payload = '${token.workerId}_${token.timestamp}_${token.deviceHash}_${token.nonce}';
      final key = utf8.encode(_secretKey);
      final message = utf8.encode(payload);
      
      final hmac = Hmac(sha256, key);
      final digest = hmac.convert(message);
      final expectedSignature = base64Url.encode(digest.bytes);
      
      final isValid = expectedSignature == token.signature;
      AppLogger.info('🔐 التحقق من التوقيع: ${isValid ? 'صحيح' : 'خطأ'}');
      
      return isValid;
    } catch (e) {
      AppLogger.error('❌ خطأ في التحقق من التوقيع: $e');
      return false;
    }
  }

  /// التحقق من صحة رمز QR
  Future<AttendanceValidationResponse> validateQRToken(String qrData) async {
    try {
      AppLogger.info('🔍 بدء التحقق من رمز QR...');
      
      // تحليل بيانات QR
      final Map<String, dynamic> qrJson;
      try {
        qrJson = jsonDecode(qrData);
      } catch (e) {
        AppLogger.error('❌ خطأ في تحليل بيانات QR: $e');
        return AttendanceValidationResponse.error(
          AttendanceErrorMessages.getMessage(AttendanceErrorCodes.invalidSignature),
          AttendanceErrorCodes.invalidSignature,
        );
      }

      final token = QRAttendanceToken.fromJson(qrJson);
      
      // التحقق من صحة الوقت
      if (!token.isValid()) {
        AppLogger.warning('⏰ انتهت صلاحية الرمز');
        return AttendanceValidationResponse.error(
          AttendanceErrorMessages.getMessage(AttendanceErrorCodes.tokenExpired),
          AttendanceErrorCodes.tokenExpired,
        );
      }

      // التحقق من صحة التوقيع
      if (!verifySignature(token)) {
        AppLogger.warning('🔐 توقيع غير صحيح');
        return AttendanceValidationResponse.error(
          AttendanceErrorMessages.getMessage(AttendanceErrorCodes.invalidSignature),
          AttendanceErrorCodes.invalidSignature,
        );
      }

      // التحقق من الجهاز
      final currentDeviceHash = await generateDeviceHash();
      if (token.deviceHash != currentDeviceHash) {
        AppLogger.warning('📱 عدم تطابق الجهاز');
        return AttendanceValidationResponse.error(
          AttendanceErrorMessages.getMessage(AttendanceErrorCodes.deviceMismatch),
          AttendanceErrorCodes.deviceMismatch,
        );
      }

      // استدعاء دالة التحقق في قاعدة البيانات
      final response = await _supabase.rpc('validate_qr_attendance_token', params: {
        'p_worker_id': token.workerId,
        'p_device_hash': token.deviceHash,
        'p_nonce': token.nonce,
        'p_timestamp': token.timestamp,
      });

      if (response == null) {
        return AttendanceValidationResponse.error(
          AttendanceErrorMessages.getMessage(AttendanceErrorCodes.databaseError),
          AttendanceErrorCodes.databaseError,
        );
      }

      final result = response as Map<String, dynamic>;
      final isValid = result['is_valid'] as bool? ?? false;
      final errorCode = result['error_code'] as String?;
      final errorMessage = result['error_message'] as String?;

      if (!isValid) {
        return AttendanceValidationResponse.error(
          errorMessage ?? AttendanceErrorMessages.getMessage(errorCode),
          errorCode,
        );
      }

      AppLogger.info('✅ تم التحقق من الرمز بنجاح');
      return AttendanceValidationResponse.success(
        WorkerAttendanceModel(
          id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
          workerId: token.workerId,
          workerName: result['worker_name'] ?? 'غير محدد',
          employeeId: result['employee_id'] ?? 'غير محدد',
          timestamp: DateTime.fromMillisecondsSinceEpoch(token.timestamp * 1000),
          type: _determineAttendanceType(result),
          deviceHash: token.deviceHash,
          status: AttendanceStatus.pending,
          createdAt: DateTime.now(),
        ),
      );

    } catch (e) {
      AppLogger.error('❌ خطأ في التحقق من رمز QR: $e');
      return AttendanceValidationResponse.error(
        AttendanceErrorMessages.getMessage(AttendanceErrorCodes.databaseError),
        AttendanceErrorCodes.databaseError,
      );
    }
  }

  /// تحديد نوع الحضور بناءً على آخر تسجيل
  AttendanceType _determineAttendanceType(Map<String, dynamic> result) {
    final lastType = result['last_attendance_type'] as String?;
    if (lastType == null || lastType == 'check_out') {
      return AttendanceType.checkIn;
    } else {
      return AttendanceType.checkOut;
    }
  }

  /// معالجة حضور العامل
  Future<AttendanceValidationResponse> processAttendance(QRAttendanceToken token) async {
    try {
      AppLogger.info('⚡ بدء معالجة الحضور...');

      final response = await _supabase.rpc('process_qr_attendance', params: {
        'p_worker_id': token.workerId,
        'p_device_hash': token.deviceHash,
        'p_nonce': token.nonce,
        'p_timestamp': token.timestamp,
      });

      if (response == null) {
        return AttendanceValidationResponse.error(
          AttendanceErrorMessages.getMessage(AttendanceErrorCodes.databaseError),
          AttendanceErrorCodes.databaseError,
        );
      }

      final result = response as Map<String, dynamic>;
      final success = result['success'] as bool? ?? false;
      final errorCode = result['error_code'] as String?;
      final errorMessage = result['error_message'] as String?;

      if (!success) {
        return AttendanceValidationResponse.error(
          errorMessage ?? AttendanceErrorMessages.getMessage(errorCode),
          errorCode,
        );
      }

      // إنشاء سجل الحضور
      final attendanceRecord = WorkerAttendanceModel(
        id: result['attendance_id'] ?? 'unknown',
        workerId: token.workerId,
        workerName: result['worker_name'] ?? 'غير محدد',
        employeeId: result['employee_id'] ?? 'غير محدد',
        timestamp: DateTime.fromMillisecondsSinceEpoch(token.timestamp * 1000),
        type: result['attendance_type'] == 'check_in' 
            ? AttendanceType.checkIn 
            : AttendanceType.checkOut,
        deviceHash: token.deviceHash,
        status: AttendanceStatus.confirmed,
        createdAt: DateTime.now(),
      );

      AppLogger.info('✅ تم تسجيل الحضور بنجاح: ${attendanceRecord.type}');
      return AttendanceValidationResponse.success(attendanceRecord);

    } catch (e) {
      AppLogger.error('❌ خطأ في معالجة الحضور: $e');
      return AttendanceValidationResponse.error(
        AttendanceErrorMessages.getMessage(AttendanceErrorCodes.databaseError),
        AttendanceErrorCodes.databaseError,
      );
    }
  }

  /// الحصول على إحصائيات الحضور
  Future<AttendanceStatistics> getAttendanceStatistics() async {
    try {
      AppLogger.info('📊 جاري تحميل إحصائيات الحضور...');

      final response = await _supabase.rpc('get_attendance_statistics');

      if (response == null) {
        AppLogger.info('⚠️ لا توجد بيانات إحصائيات - إرجاع إحصائيات فارغة');
        return AttendanceStatistics.empty();
      }

      final data = response as Map<String, dynamic>;
      AppLogger.info('✅ تم استلام بيانات الإحصائيات: ${data.keys.join(', ')}');

      // الحصول على الحضور الحديث مع معالجة الأخطاء
      List<WorkerAttendanceModel> recentAttendance = [];
      try {
        final recentResponse = await _supabase
            .from('worker_attendance_records')
            .select('*')
            .order('created_at', ascending: false)
            .limit(10);

        recentAttendance = (recentResponse as List)
            .map((item) => WorkerAttendanceModel.fromJson(item as Map<String, dynamic>))
            .toList();

        AppLogger.info('✅ تم تحميل ${recentAttendance.length} سجل حضور حديث');
      } catch (recentError) {
        AppLogger.error('⚠️ خطأ في تحميل الحضور الحديث: $recentError');
        // المتابعة بقائمة فارغة
      }

      final statistics = AttendanceStatistics(
        totalWorkers: (data['total_workers'] as num?)?.toInt() ?? 0,
        presentWorkers: (data['present_workers'] as num?)?.toInt() ?? 0,
        absentWorkers: (data['absent_workers'] as num?)?.toInt() ?? 0,
        lateWorkers: (data['late_workers'] as num?)?.toInt() ?? 0,
        recentAttendance: recentAttendance,
        lastUpdated: DateTime.now(),
      );

      AppLogger.info('✅ تم إنشاء إحصائيات الحضور بنجاح: ${statistics.totalWorkers} عامل');
      return statistics;

    } catch (e) {
      AppLogger.error('❌ خطأ في تحميل إحصائيات الحضور: $e');
      AppLogger.info('🔄 إرجاع إحصائيات فارغة كحل بديل');
      return AttendanceStatistics.empty();
    }
  }

  /// الحصول على سجل حضور عامل محدد
  Future<List<WorkerAttendanceModel>> getWorkerAttendanceHistory(
    String workerId, {
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  }) async {
    try {
      // Build query with correct pattern: from().select() first, then filters
      var query = _supabase
          .from('worker_attendance_records')
          .select('*')
          .eq('worker_id', workerId);

      // Apply date filters after select()
      if (startDate != null) {
        query = query.gte('timestamp', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('timestamp', endDate.toIso8601String());
      }

      // Apply ordering and limit
      final response = await query
          .order('timestamp', ascending: false)
          .limit(limit);

      return (response as List)
          .map((item) => WorkerAttendanceModel.fromJson(item as Map<String, dynamic>))
          .toList();

    } catch (e) {
      AppLogger.error('❌ خطأ في تحميل سجل الحضور: $e');
      return [];
    }
  }

  /// الحصول على سجلات الحضور الحديثة
  Future<List<WorkerAttendanceModel>> getRecentAttendanceRecords({int limit = 50}) async {
    try {
      AppLogger.info('📊 جاري تحميل سجلات الحضور الحديثة...');

      // Join with user_profiles to get worker name and employee ID
      final response = await _supabase
          .from('worker_attendance_records')
          .select('''
            *,
            user_profiles!worker_id (
              name,
              employee_id
            )
          ''')
          .order('timestamp', ascending: false)
          .limit(limit);

      final records = (response as List)
          .map((item) {
            final record = item as Map<String, dynamic>;
            final userProfile = record['user_profiles'] as Map<String, dynamic>?;

            // Flatten the structure for the model
            final flattenedRecord = Map<String, dynamic>.from(record);
            if (userProfile != null) {
              flattenedRecord['worker_name'] = userProfile['name'];
              flattenedRecord['employee_id'] = userProfile['employee_id'] ?? 'غير محدد';
            }
            // Remove the nested user_profiles object
            flattenedRecord.remove('user_profiles');

            return WorkerAttendanceModel.fromJson(flattenedRecord);
          })
          .toList();

      AppLogger.info('✅ تم تحميل ${records.length} سجل حضور حديث');
      return records;

    } catch (e) {
      AppLogger.error('❌ خطأ في تحميل سجلات الحضور الحديثة: $e');
      return [];
    }
  }
}
