/// Attendance Service for SmartBizTracker Worker Attendance System
/// 
/// This service handles all attendance-related operations including QR validation,
/// attendance recording, profile management, and statistics retrieval.

import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/attendance_models.dart';
import '../models/qr_token_model.dart';
import '../utils/app_logger.dart';

class AttendanceService {
  static final AttendanceService _instance = AttendanceService._internal();
  factory AttendanceService() => _instance;
  AttendanceService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  // Request deduplication cache
  final Map<String, Future<List<WorkerAttendanceRecord>>> _activeRequests = {};
  final Map<String, DateTime> _requestTimestamps = {};
  static const Duration _requestCacheTimeout = Duration(seconds: 5);

  // Retry configuration
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(milliseconds: 500);

  /// Processes QR attendance token and records attendance
  ///
  /// This is the main entry point for QR-based attendance tracking
  Future<QRValidationResult> processQRAttendance({
    required String workerId,
    required String deviceHash,
    required String nonce,
    required DateTime qrTimestamp,
    required AttendanceType attendanceType,
    Map<String, dynamic>? locationInfo,
  }) async {
    try {
      AppLogger.info('🔄 Processing QR attendance for worker: $workerId');

      // Clear any cached requests for this worker to ensure fresh data
      _clearWorkerCache(workerId);

      // Call the database function for QR attendance processing
      final response = await _supabase.rpc('process_qr_attendance', params: {
        'p_worker_id': workerId,
        'p_device_hash': deviceHash,
        'p_nonce': nonce,
        'p_qr_timestamp': qrTimestamp.toIso8601String(),
        'p_attendance_type': attendanceType.value,
        'p_location_info': locationInfo != null ? jsonEncode(locationInfo) : null,
      });

      if (response == null) {
        throw Exception('No response from attendance processing function');
      }

      final result = QRValidationResult.fromJson(response as Map<String, dynamic>);

      if (result.success) {
        AppLogger.info('✅ QR attendance processed successfully: ${result.attendanceId}');

        // Clear cache again to ensure subsequent queries get fresh data
        _clearWorkerCache(workerId);

        // Add a small delay to ensure database consistency
        await Future.delayed(const Duration(milliseconds: 100));
      } else {
        AppLogger.warning('⚠️ QR attendance validation failed: ${result.error}');
      }

      return result;

    } catch (e) {
      AppLogger.error('❌ Error processing QR attendance: $e');

      // Return error result
      return QRValidationResult(
        success: false,
        error: 'خطأ في معالجة رمز الحضور: ${e.toString()}',
        timestamp: DateTime.now(),
        workerId: workerId,
        deviceHash: deviceHash,
        nonce: nonce,
        attendanceType: attendanceType,
        validations: {},
      );
    }
  }

  /// Creates or updates worker attendance profile
  Future<WorkerAttendanceProfile> createOrUpdateProfile({
    required String workerId,
    required String deviceHash,
    String? deviceModel,
    String? deviceOsVersion,
  }) async {
    try {
      AppLogger.info('🔄 Creating/updating attendance profile for worker: $workerId');

      // Check if profile exists
      final existingProfile = await getWorkerProfile(workerId, deviceHash);
      
      if (existingProfile != null) {
        // Update existing profile
        final response = await _supabase
            .from('worker_attendance_profiles')
            .update({
              'device_model': deviceModel,
              'device_os_version': deviceOsVersion,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('worker_id', workerId)
            .eq('device_hash', deviceHash)
            .select()
            .single();

        AppLogger.info('✅ Attendance profile updated successfully');
        return WorkerAttendanceProfile.fromJson(response);
      } else {
        // Create new profile
        final response = await _supabase
            .from('worker_attendance_profiles')
            .insert({
              'worker_id': workerId,
              'device_hash': deviceHash,
              'device_model': deviceModel,
              'device_os_version': deviceOsVersion,
              'is_active': true,
            })
            .select()
            .single();

        AppLogger.info('✅ Attendance profile created successfully');
        return WorkerAttendanceProfile.fromJson(response);
      }

    } catch (e) {
      AppLogger.error('❌ Error creating/updating attendance profile: $e');
      throw Exception('فشل في إنشاء/تحديث ملف الحضور: ${e.toString()}');
    }
  }

  /// Gets worker attendance profile
  Future<WorkerAttendanceProfile?> getWorkerProfile(String workerId, String deviceHash) async {
    try {
      final response = await _supabase
          .from('worker_attendance_profiles')
          .select()
          .eq('worker_id', workerId)
          .eq('device_hash', deviceHash)
          .eq('is_active', true)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return WorkerAttendanceProfile.fromJson(response);

    } catch (e) {
      AppLogger.error('❌ Error getting worker profile: $e');
      return null;
    }
  }

  /// Gets worker attendance records with request deduplication
  Future<List<WorkerAttendanceRecord>> getWorkerAttendanceRecords({
    required String workerId,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    // Create unique request key
    final requestKey = _createRequestKey(workerId, startDate, endDate, limit);

    // Check if there's an active request for the same parameters
    if (_activeRequests.containsKey(requestKey)) {
      final timestamp = _requestTimestamps[requestKey];
      if (timestamp != null && DateTime.now().difference(timestamp) < _requestCacheTimeout) {
        AppLogger.info('🔄 Reusing active request for worker: $workerId');
        return await _activeRequests[requestKey]!;
      } else {
        // Clean up expired request
        _activeRequests.remove(requestKey);
        _requestTimestamps.remove(requestKey);
      }
    }

    // Create new request
    final requestFuture = _fetchWorkerAttendanceRecords(
      workerId: workerId,
      startDate: startDate,
      endDate: endDate,
      limit: limit,
    );

    // Cache the request
    _activeRequests[requestKey] = requestFuture;
    _requestTimestamps[requestKey] = DateTime.now();

    try {
      final result = await requestFuture;

      // Clean up completed request
      _activeRequests.remove(requestKey);
      _requestTimestamps.remove(requestKey);

      return result;
    } catch (e) {
      // Clean up failed request
      _activeRequests.remove(requestKey);
      _requestTimestamps.remove(requestKey);
      rethrow;
    }
  }

  /// Internal method to actually fetch attendance records with retry logic
  Future<List<WorkerAttendanceRecord>> _fetchWorkerAttendanceRecords({
    required String workerId,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    return await _executeWithRetry(() async {
      AppLogger.info('🔄 Fetching attendance records for worker: $workerId');

      // Build query with single chain to avoid type assignment issues
      var baseQuery = _supabase
          .from('worker_attendance_records')
          .select('*')
          .eq('worker_id', workerId);

      // Apply date filters
      if (startDate != null) {
        baseQuery = baseQuery.gte('timestamp', startDate.toIso8601String());
      }

      if (endDate != null) {
        baseQuery = baseQuery.lte('timestamp', endDate.toIso8601String());
      }

      // Apply transformations in final chain
      var finalQuery = baseQuery.order('timestamp', ascending: false);

      if (limit != null) {
        finalQuery = finalQuery.limit(limit);
      }

      final response = await finalQuery;

      final records = (response as List<dynamic>)
          .map((record) => WorkerAttendanceRecord.fromJson(record as Map<String, dynamic>))
          .toList();

      AppLogger.info('✅ Fetched ${records.length} attendance records');
      return records;
    }, 'fetch attendance records for worker $workerId');
  }

  /// Execute a function with retry logic
  Future<T> _executeWithRetry<T>(
    Future<T> Function() operation,
    String operationName,
  ) async {
    Exception? lastException;

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        return await operation();
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());

        if (attempt == _maxRetries) {
          AppLogger.error('❌ Failed $operationName after $_maxRetries attempts: $e');
          break;
        }

        AppLogger.warning('⚠️ Attempt $attempt failed for $operationName: $e. Retrying in ${_retryDelay.inMilliseconds}ms...');
        await Future.delayed(_retryDelay * attempt); // Exponential backoff
      }
    }

    throw lastException ?? Exception('Unknown error in $operationName');
  }

  /// Creates a unique key for request deduplication
  String _createRequestKey(String workerId, DateTime? startDate, DateTime? endDate, int? limit) {
    final parts = [
      workerId,
      startDate?.toIso8601String() ?? 'null',
      endDate?.toIso8601String() ?? 'null',
      limit?.toString() ?? 'null',
    ];
    return parts.join('|');
  }

  /// Clears all cached requests for a specific worker
  void _clearWorkerCache(String workerId) {
    final keysToRemove = <String>[];

    for (final key in _activeRequests.keys) {
      if (key.startsWith(workerId)) {
        keysToRemove.add(key);
      }
    }

    for (final key in keysToRemove) {
      _activeRequests.remove(key);
      _requestTimestamps.remove(key);
    }

    if (keysToRemove.isNotEmpty) {
      AppLogger.info('🧹 Cleared ${keysToRemove.length} cached requests for worker: $workerId');
    }
  }

  /// Clears all expired requests from cache
  void _cleanupExpiredRequests() {
    final now = DateTime.now();
    final keysToRemove = <String>[];

    for (final entry in _requestTimestamps.entries) {
      if (now.difference(entry.value) > _requestCacheTimeout) {
        keysToRemove.add(entry.key);
      }
    }

    for (final key in keysToRemove) {
      _activeRequests.remove(key);
      _requestTimestamps.remove(key);
    }
  }

  /// Gets worker attendance statistics
  Future<AttendanceStatistics> getWorkerAttendanceStats({
    required String workerId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      AppLogger.info('🔄 Fetching attendance statistics for worker: $workerId');

      final response = await _supabase.rpc('get_worker_attendance_stats', params: {
        'p_worker_id': workerId,
        'p_start_date': startDate?.toIso8601String().split('T')[0],
        'p_end_date': endDate?.toIso8601String().split('T')[0],
      });

      if (response == null) {
        throw Exception('No response from attendance statistics function');
      }

      final stats = AttendanceStatistics.fromJson(response as Map<String, dynamic>);
      
      AppLogger.info('✅ Fetched attendance statistics successfully');
      return stats;

    } catch (e) {
      AppLogger.error('❌ Error fetching attendance statistics: $e');
      throw Exception('فشل في جلب إحصائيات الحضور: ${e.toString()}');
    }
  }

  /// Gets today's attendance status for a worker
  Future<Map<String, dynamic>> getTodayAttendanceStatus(String workerId) async {
    try {
      AppLogger.info('🔍 Getting today attendance status for worker: $workerId');

      // Clear cache to ensure we get the most recent data
      _clearWorkerCache(workerId);

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Force fresh data by bypassing cache
      final records = await _fetchWorkerAttendanceRecords(
        workerId: workerId,
        startDate: startOfDay,
        endDate: endOfDay,
      );

      // Find check-in and check-out for today (most recent of each type)
      WorkerAttendanceRecord? checkIn;
      WorkerAttendanceRecord? checkOut;

      for (final record in records) {
        if (record.attendanceType == AttendanceType.checkIn && checkIn == null) {
          checkIn = record;
        } else if (record.attendanceType == AttendanceType.checkOut && checkOut == null) {
          checkOut = record;
        }
      }

      // Calculate work duration if both check-in and check-out exist
      Duration? workDuration;
      if (checkIn != null && checkOut != null) {
        workDuration = checkOut.timestamp.difference(checkIn.timestamp);
      }

      final status = {
        'hasCheckedIn': checkIn != null,
        'hasCheckedOut': checkOut != null,
        'checkInTime': checkIn?.timestamp,
        'checkOutTime': checkOut?.timestamp,
        'workDuration': workDuration,
        'isCurrentlyWorking': checkIn != null && checkOut == null,
        'canCheckIn': checkIn == null,
        'canCheckOut': checkIn != null && checkOut == null,
        'totalRecords': records.length,
        'lastUpdate': DateTime.now(),
      };

      AppLogger.info('✅ Today attendance status: hasCheckedIn=${status['hasCheckedIn']}, hasCheckedOut=${status['hasCheckedOut']}, totalRecords=${status['totalRecords']}');
      return status;

    } catch (e) {
      AppLogger.error('❌ Error getting today attendance status: $e');
      throw Exception('فشل في جلب حالة الحضور اليوم: ${e.toString()}');
    }
  }

  /// Validates if worker can perform attendance action
  Future<Map<String, dynamic>> validateAttendanceAction({
    required String workerId,
    required AttendanceType attendanceType,
  }) async {
    try {
      final profile = await _supabase
          .from('worker_attendance_profiles')
          .select()
          .eq('worker_id', workerId)
          .eq('is_active', true)
          .maybeSingle();

      if (profile == null) {
        return {
          'canPerform': false,
          'reason': 'ملف الحضور غير موجود أو غير نشط',
        };
      }

      final lastAttendanceType = profile['last_attendance_type'] as String?;
      
      // Check logical sequence
      if (attendanceType == AttendanceType.checkIn) {
        if (lastAttendanceType == 'check_in') {
          return {
            'canPerform': false,
            'reason': 'لا يمكن تسجيل الحضور مرتين متتاليتين',
          };
        }
      } else if (attendanceType == AttendanceType.checkOut) {
        if (lastAttendanceType != 'check_in') {
          return {
            'canPerform': false,
            'reason': 'يجب تسجيل الحضور أولاً قبل تسجيل الانصراف',
          };
        }
      }

      // Check 15-hour gap for check-in
      if (attendanceType == AttendanceType.checkIn && lastAttendanceType == 'check_in') {
        final lastAttendanceTime = DateTime.parse(profile['last_attendance_time'] as String);
        final timeDiff = DateTime.now().difference(lastAttendanceTime);
        
        if (timeDiff.inHours < 15) {
          return {
            'canPerform': false,
            'reason': 'يجب انتظار 15 ساعة على الأقل بين تسجيلات الحضور',
            'remainingHours': 15 - timeDiff.inHours,
          };
        }
      }

      return {
        'canPerform': true,
        'reason': 'يمكن تسجيل ${attendanceType.arabicLabel}',
      };

    } catch (e) {
      AppLogger.error('❌ Error validating attendance action: $e');
      return {
        'canPerform': false,
        'reason': 'خطأ في التحقق من صحة العملية: ${e.toString()}',
      };
    }
  }

  /// Cleanup expired nonces (for maintenance)
  Future<int> cleanupExpiredNonces() async {
    try {
      final response = await _supabase.rpc('cleanup_expired_nonces');
      final deletedCount = response as int;
      
      AppLogger.info('🧹 Cleaned up $deletedCount expired nonces');
      return deletedCount;

    } catch (e) {
      AppLogger.error('❌ Error cleaning up expired nonces: $e');
      return 0;
    }
  }
}
