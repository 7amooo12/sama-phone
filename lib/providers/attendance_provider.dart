/// Attendance Provider for SmartBizTracker Worker Attendance System
/// 
/// This provider manages attendance-related state and operations following
/// the established Provider pattern used throughout SmartBizTracker.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/scheduler.dart';
import '../models/attendance_models.dart';
import '../models/qr_token_model.dart';
import '../models/location_models.dart';
import '../services/attendance_service.dart';
import '../services/qr_token_service.dart';
import '../services/biometric_attendance_service.dart';
import '../services/location_service.dart';
import '../utils/app_logger.dart';
import '../services/database_performance_optimizer.dart';

class AttendanceProvider extends ChangeNotifier {
  final AttendanceService _attendanceService = AttendanceService();
  final QRTokenService _qrTokenService = QRTokenService();
  final BiometricAttendanceService _biometricService = BiometricAttendanceService();
  final LocationService _locationService = LocationService();

  // State variables
  WorkerAttendanceProfile? _currentProfile;
  List<WorkerAttendanceRecord> _attendanceRecords = [];
  AttendanceStatistics? _attendanceStats;
  Map<String, dynamic>? _todayStatus;
  Map<String, dynamic>? _validationStatus;
  LocationValidationResult? _lastLocationValidation;
  BiometricAvailabilityResult? _biometricAvailability;

  bool _isLoading = false;
  bool _isProcessingQR = false;
  bool _isProcessingBiometric = false;
  bool _isCheckingLocation = false;
  String? _error;

  // Getters
  WorkerAttendanceProfile? get currentProfile => _currentProfile;
  List<WorkerAttendanceRecord> get attendanceRecords => _attendanceRecords;
  AttendanceStatistics? get attendanceStats => _attendanceStats;
  Map<String, dynamic>? get todayStatus => _todayStatus;
  Map<String, dynamic>? get validationStatus => _validationStatus;
  LocationValidationResult? get lastLocationValidation => _lastLocationValidation;
  BiometricAvailabilityResult? get biometricAvailability => _biometricAvailability;

  bool get isLoading => _isLoading;
  bool get isProcessingQR => _isProcessingQR;
  bool get isProcessingBiometric => _isProcessingBiometric;
  bool get isCheckingLocation => _isCheckingLocation;
  String? get error => _error;

  // Computed getters
  bool get hasCheckedInToday => _todayStatus?['hasCheckedIn'] ?? false;
  bool get hasCheckedOutToday => _todayStatus?['hasCheckedOut'] ?? false;
  bool get isCurrentlyWorking => _todayStatus?['isCurrentlyWorking'] ?? false;
  bool get canCheckIn => _todayStatus?['canCheckIn'] ?? false;
  bool get canCheckOut => _todayStatus?['canCheckOut'] ?? false;
  
  DateTime? get todayCheckInTime => _todayStatus?['checkInTime'];
  DateTime? get todayCheckOutTime => _todayStatus?['checkOutTime'];
  Duration? get todayWorkDuration => _todayStatus?['workDuration'];

  /// Initializes attendance data for a worker with performance optimization
  Future<void> initializeAttendance(String workerId) async {
    try {
      _setLoading(true);
      _setError(null);

      AppLogger.info('🔄 Initializing attendance for worker: $workerId');

      // Use database performance optimizer for caching
      await DatabasePerformanceOptimizer.executeWithCache(
        queryKey: 'attendance_init_$workerId',
        cacheExpiry: const Duration(minutes: 2), // Cache for 2 minutes
        queryFunction: () async {
          // Load worker profile, today's status, and recent records in parallel
          await Future.wait([
            _loadWorkerProfile(workerId),
            _loadTodayStatus(workerId),
            _loadRecentAttendanceRecords(workerId),
          ]);
          return true;
        },
      );

      AppLogger.info('✅ Attendance initialization completed');

    } catch (e) {
      AppLogger.error('❌ Error initializing attendance: $e');
      _setError('فشل في تهيئة بيانات الحضور: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  /// Creates or updates worker attendance profile
  Future<void> createOrUpdateProfile({
    required String workerId,
    required String deviceHash,
    String? deviceModel,
    String? deviceOsVersion,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      AppLogger.info('🔄 Creating/updating attendance profile');

      _currentProfile = await _attendanceService.createOrUpdateProfile(
        workerId: workerId,
        deviceHash: deviceHash,
        deviceModel: deviceModel,
        deviceOsVersion: deviceOsVersion,
      );

      AppLogger.info('✅ Attendance profile updated successfully');
      notifyListeners();

    } catch (e) {
      AppLogger.error('❌ Error creating/updating profile: $e');
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// Processes QR attendance with comprehensive validation
  Future<QRValidationResult> processQRAttendance({
    required String workerId,
    required AttendanceType attendanceType,
    Map<String, dynamic>? locationInfo,
  }) async {
    try {
      _setProcessingQR(true);
      _setError(null);

      AppLogger.info('🔄 Processing QR attendance: ${attendanceType.arabicLabel}');

      // Generate QR token
      final qrData = await _qrTokenService.generateQRToken(workerId);
      final qrToken = QRTokenModel.fromJsonString(
        String.fromCharCodes(base64Decode(qrData))
      );

      // Process attendance
      final result = await _attendanceService.processQRAttendance(
        workerId: workerId,
        deviceHash: qrToken.deviceHash,
        nonce: qrToken.nonce,
        qrTimestamp: DateTime.fromMillisecondsSinceEpoch(qrToken.timestamp),
        attendanceType: attendanceType,
        locationInfo: locationInfo,
      );

      if (result.success) {
        AppLogger.info('✅ QR attendance processed successfully');

        // Refresh data after successful attendance with proper state management
        await _refreshDataAfterAttendance(workerId);
      } else {
        AppLogger.warning('⚠️ QR attendance validation failed: ${result.error}');
        _setErrorSafely(result.error ?? 'فشل في معالجة رمز الحضور');
      }

      return result;

    } catch (e) {
      AppLogger.error('❌ Error processing QR attendance: $e');
      final errorResult = QRValidationResult(
        success: false,
        error: 'خطأ في معالجة رمز الحضور: ${e.toString()}',
        timestamp: DateTime.now(),
        workerId: workerId,
        deviceHash: '',
        nonce: '',
        attendanceType: attendanceType,
        validations: {},
      );
      _setError(errorResult.error!);
      return errorResult;
    } finally {
      _setProcessingQR(false);
    }
  }

  /// Validates if worker can perform attendance action
  Future<void> validateAttendanceAction({
    required String workerId,
    required AttendanceType attendanceType,
  }) async {
    try {
      AppLogger.info('🔄 Validating attendance action: ${attendanceType.arabicLabel}');

      _validationStatus = await _attendanceService.validateAttendanceAction(
        workerId: workerId,
        attendanceType: attendanceType,
      );

      AppLogger.info('✅ Attendance validation completed');
      notifyListeners();

    } catch (e) {
      AppLogger.error('❌ Error validating attendance action: $e');
      _validationStatus = {
        'canPerform': false,
        'reason': 'خطأ في التحقق من صحة العملية: ${e.toString()}',
      };
      notifyListeners();
    }
  }

  /// Loads attendance statistics for a date range
  Future<void> loadAttendanceStats({
    required String workerId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      AppLogger.info('🔄 Loading attendance statistics');

      _attendanceStats = await _attendanceService.getWorkerAttendanceStats(
        workerId: workerId,
        startDate: startDate,
        endDate: endDate,
      );

      AppLogger.info('✅ Attendance statistics loaded successfully');
      notifyListeners();

    } catch (e) {
      AppLogger.error('❌ Error loading attendance statistics: $e');
      _setError('فشل في جلب إحصائيات الحضور: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  /// Loads attendance records for a date range
  Future<void> loadAttendanceRecords({
    required String workerId,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      AppLogger.info('🔄 Loading attendance records');

      _attendanceRecords = await _attendanceService.getWorkerAttendanceRecords(
        workerId: workerId,
        startDate: startDate,
        endDate: endDate,
        limit: limit,
      );

      AppLogger.info('✅ Loaded ${_attendanceRecords.length} attendance records');
      notifyListeners();

    } catch (e) {
      AppLogger.error('❌ Error loading attendance records: $e');
      _setError('فشل في جلب سجلات الحضور: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  // Debouncing and loop prevention
  Timer? _refreshDebounceTimer;
  bool _isRefreshPending = false;
  DateTime? _lastRefreshTime;
  int _refreshCallCount = 0;
  DateTime? _refreshCallCountResetTime;
  static const Duration _refreshDebounceDelay = Duration(milliseconds: 500);
  static const Duration _minRefreshInterval = Duration(seconds: 2);
  static const int _maxRefreshCallsPerMinute = 10;

  /// Refreshes all attendance data with comprehensive loop prevention
  Future<void> refreshAttendanceData(String workerId) async {
    // CRITICAL FIX: Prevent excessive calls and infinite loops
    final now = DateTime.now();

    // Performance monitoring: Track call frequency
    _trackRefreshCall(now);

    // Check if we're exceeding call limits
    if (_isExceedingCallLimits()) {
      AppLogger.warning('⚠️ Refresh call limit exceeded, blocking further calls');
      return;
    }

    // Check if refresh was called too recently
    if (_lastRefreshTime != null &&
        now.difference(_lastRefreshTime!) < _minRefreshInterval) {
      AppLogger.warning('⚠️ Refresh called too frequently, throttling (${now.difference(_lastRefreshTime!).inMilliseconds}ms ago)');
      return;
    }

    // Prevent calling during build phase or if already loading
    if (_isLoading) {
      AppLogger.warning('⚠️ Refresh already in progress, skipping duplicate call');
      return;
    }

    // Check if refresh is already pending
    if (_isRefreshPending) {
      AppLogger.warning('⚠️ Refresh already pending, skipping duplicate call');
      return;
    }

    // Check if we're in build phase - use debounced approach instead of recursive call
    if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle) {
      AppLogger.info('🔄 Deferring refresh until after build phase (debounced)');
      _scheduleRefreshAfterBuild(workerId);
      return;
    }

    await _performRefresh(workerId);
  }

  /// Schedule refresh after build phase with debouncing
  void _scheduleRefreshAfterBuild(String workerId) {
    if (_isRefreshPending) return;

    _isRefreshPending = true;

    // Cancel any existing timer
    _refreshDebounceTimer?.cancel();

    // Schedule debounced refresh
    _refreshDebounceTimer = Timer(_refreshDebounceDelay, () {
      _isRefreshPending = false;
      if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
        _performRefresh(workerId);
      } else {
        // If still in build phase, schedule for next frame (but only once)
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (!_isRefreshPending) {
            _performRefresh(workerId);
          }
        });
      }
    });
  }

  /// Perform the actual refresh operation
  Future<void> _performRefresh(String workerId) async {
    if (_isLoading) return;

    try {
      _lastRefreshTime = DateTime.now();
      AppLogger.info('🔄 Refreshing attendance data');

      // Set loading state safely
      _setLoadingSafely(true);
      _setErrorSafely(null);

      await Future.wait([
        _loadWorkerProfile(workerId),
        _loadTodayStatus(workerId),
        _loadRecentAttendanceRecords(workerId),
      ]);

      AppLogger.info('✅ Attendance data refreshed successfully');

    } catch (e) {
      AppLogger.error('❌ Error refreshing attendance data: $e');
      _setErrorSafely('فشل في تحديث بيانات الحضور: ${e.toString()}');
    } finally {
      _setLoadingSafely(false);
    }
  }

  // Private helper methods

  Future<void> _loadWorkerProfile(String workerId) async {
    try {
      final deviceFingerprint = await _qrTokenService.getDeviceFingerprint();
      _currentProfile = await _attendanceService.getWorkerProfile(
        workerId,
        deviceFingerprint.hash,
      );
    } catch (e) {
      AppLogger.warning('⚠️ Could not load worker profile: $e');
    }
  }

  Future<void> _loadTodayStatus(String workerId) async {
    try {
      _todayStatus = await _attendanceService.getTodayAttendanceStatus(workerId);
    } catch (e) {
      AppLogger.warning('⚠️ Could not load today status: $e');
    }
  }

  Future<void> _loadRecentAttendanceRecords(String workerId) async {
    try {
      _attendanceRecords = await _attendanceService.getWorkerAttendanceRecords(
        workerId: workerId,
        limit: 50, // Load last 50 records
      );
    } catch (e) {
      AppLogger.warning('⚠️ Could not load recent attendance records: $e');
    }
  }

  /// Track refresh call frequency for performance monitoring
  void _trackRefreshCall(DateTime now) {
    // Reset counter every minute
    if (_refreshCallCountResetTime == null ||
        now.difference(_refreshCallCountResetTime!) > const Duration(minutes: 1)) {
      _refreshCallCount = 0;
      _refreshCallCountResetTime = now;
    }

    _refreshCallCount++;

    // Log excessive calls
    if (_refreshCallCount > 5) {
      AppLogger.warning('⚠️ High refresh call frequency detected: $_refreshCallCount calls in the last minute');
    }
  }

  /// Check if refresh calls are exceeding safe limits
  bool _isExceedingCallLimits() {
    return _refreshCallCount > _maxRefreshCallsPerMinute;
  }

  /// Reset refresh call tracking (useful for testing or manual reset)
  void resetRefreshTracking() {
    _refreshCallCount = 0;
    _refreshCallCountResetTime = null;
    _lastRefreshTime = null;
    AppLogger.info('🔄 Refresh call tracking reset');
  }

  /// Optimized refresh after attendance processing
  Future<void> _refreshDataAfterAttendance(String workerId) async {
    try {
      AppLogger.info('🔄 Refreshing data after attendance processing...');

      // Use sequential loading to ensure data consistency
      await _loadTodayStatus(workerId);
      await _loadRecentAttendanceRecords(workerId);
      await _loadWorkerProfile(workerId);

      // Notify listeners safely
      if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
        notifyListeners();
      } else {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          notifyListeners();
        });
      }

      // Trigger reports system update
      _notifyReportsSystem();

      AppLogger.info('✅ Data refreshed successfully after attendance processing');
    } catch (e) {
      AppLogger.error('❌ Error refreshing data after attendance: $e');
      _setErrorSafely('فشل في تحديث البيانات بعد تسجيل الحضور: ${e.toString()}');
    }
  }

  /// Notify the reports system that new attendance data is available
  void _notifyReportsSystem() {
    try {
      // This will trigger real-time updates in the reports system
      // The reports provider listens for attendance record changes
      AppLogger.info('📡 Notifying reports system of attendance update');

      // The notification happens automatically through Supabase real-time subscriptions
      // that are set up in the WorkerAttendanceReportsProvider
    } catch (e) {
      AppLogger.warning('⚠️ Could not notify reports system: $e');
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Safe version of _setLoading that checks build phase
  void _setLoadingSafely(bool loading) {
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      _setLoading(loading);
    } else {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _setLoading(loading);
      });
    }
  }

  void _setProcessingQR(bool processing) {
    _isProcessingQR = processing;
    notifyListeners();
  }

  void _setProcessingBiometric(bool processing) {
    _isProcessingBiometric = processing;
    notifyListeners();
  }

  void _setCheckingLocation(bool checking) {
    _isCheckingLocation = checking;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  /// Safe version of _setError that checks build phase
  void _setErrorSafely(String? error) {
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      _setError(error);
    } else {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _setError(error);
      });
    }
  }

  /// Checks biometric availability
  Future<void> checkBiometricAvailability() async {
    try {
      AppLogger.info('🔍 Checking biometric availability...');
      _biometricAvailability = await _biometricService.checkBiometricAvailability();
      notifyListeners();
    } catch (e) {
      AppLogger.error('❌ Error checking biometric availability: $e');
      _biometricAvailability = BiometricAvailabilityResult(
        isAvailable: false,
        errorMessage: 'خطأ في فحص المصادقة البيومترية: $e',
        supportedTypes: [],
      );
      notifyListeners();
    }
  }

  /// Validates location for attendance
  Future<LocationValidationResult> validateLocationForAttendance({
    String? warehouseId,
  }) async {
    try {
      _setCheckingLocation(true);
      AppLogger.info('📍 Validating location for attendance...');

      _lastLocationValidation = await _locationService.validateLocationForAttendance(warehouseId);
      notifyListeners();

      return _lastLocationValidation!;
    } catch (e) {
      AppLogger.error('❌ Error validating location: $e');
      _lastLocationValidation = LocationValidationResult.invalid(
        errorMessage: 'خطأ في التحقق من الموقع: $e',
        status: LocationValidationStatus.unknownError,
      );
      notifyListeners();
      return _lastLocationValidation!;
    } finally {
      _setCheckingLocation(false);
    }
  }

  /// Processes biometric attendance with location validation
  Future<BiometricAttendanceResult> processBiometricAttendance({
    required String workerId,
    required AttendanceType attendanceType,
    String? warehouseId,
  }) async {
    try {
      _setProcessingBiometric(true);
      _setError(null);

      AppLogger.info('🔐 Processing biometric attendance: ${attendanceType.arabicLabel}');

      final result = await _biometricService.processBiometricAttendance(
        workerId: workerId,
        attendanceType: attendanceType,
        warehouseId: warehouseId,
      );

      if (result.success) {
        AppLogger.info('✅ Biometric attendance processed successfully');

        // Update location validation if available
        if (result.locationValidation != null) {
          _lastLocationValidation = result.locationValidation;
        }

        // Add a small delay to ensure database transaction is committed
        await Future.delayed(const Duration(milliseconds: 500));

        // Refresh data after successful attendance
        await Future.wait([
          _loadTodayStatus(workerId),
          _loadRecentAttendanceRecords(workerId),
          _loadWorkerProfile(workerId),
        ]);
      } else {
        AppLogger.warning('⚠️ Biometric attendance failed: ${result.errorMessage}');
        _setError(result.errorMessage ?? 'فشل في تسجيل الحضور البيومتري');
      }

      return result;

    } catch (e) {
      AppLogger.error('❌ Error processing biometric attendance: $e');
      final errorResult = BiometricAttendanceResult(
        success: false,
        errorMessage: 'خطأ في معالجة الحضور البيومتري: ${e.toString()}',
        errorType: BiometricAttendanceErrorType.unknownError,
      );
      _setError(errorResult.errorMessage!);
      return errorResult;
    } finally {
      _setProcessingBiometric(false);
    }
  }

  /// Gets location-based attendance statistics
  Future<Map<String, dynamic>?> getLocationAttendanceStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      AppLogger.info('📊 Loading location attendance statistics...');

      // This would call a database function to get location-based stats
      // For now, return a placeholder
      return {
        'total_records': 0,
        'location_validated': 0,
        'biometric_records': 0,
        'qr_records': 0,
        'average_distance': 0.0,
        'outside_geofence': 0,
        'location_validation_rate': 0.0,
      };
    } catch (e) {
      AppLogger.error('❌ Error loading location attendance stats: $e');
      return null;
    }
  }

  /// Gets detailed location information
  Future<DetailedLocationInfo?> getDetailedLocationInfo() async {
    try {
      _setCheckingLocation(true);
      _setError(null);

      AppLogger.info('📍 Getting detailed location information...');
      final locationInfo = await _locationService.getDetailedLocationInfo();

      if (locationInfo != null) {
        _lastLocationValidation = locationInfo.validation;
        notifyListeners();
      }

      return locationInfo;
    } catch (e) {
      AppLogger.error('❌ Error getting detailed location info: $e');
      _setError('فشل في الحصول على معلومات الموقع: ${e.toString()}');
      return null;
    } finally {
      _setCheckingLocation(false);
    }
  }

  /// Checks if biometric authentication is available and ready
  Future<bool> isBiometricReadyForAttendance() async {
    try {
      // Check biometric availability
      await checkBiometricAvailability();

      if (_biometricAvailability?.isAvailable != true) {
        return false;
      }

      // Check location if required
      await validateLocationForAttendance();

      return _lastLocationValidation?.isValid ?? false;
    } catch (e) {
      AppLogger.error('❌ Error checking biometric readiness: $e');
      return false;
    }
  }

  /// Validates attendance prerequisites (location, biometric, etc.)
  Future<AttendancePrerequisiteResult> validateAttendancePrerequisites({
    required String workerId,
    required AttendanceType attendanceType,
    bool requireBiometric = false,
    bool requireLocation = true,
  }) async {
    try {
      AppLogger.info('🔍 Validating attendance prerequisites...');

      final List<String> errors = [];
      final List<String> warnings = [];

      // Check today's status first
      await _loadTodayStatus(workerId);

      // Validate attendance sequence
      if (attendanceType == AttendanceType.checkIn && hasCheckedInToday) {
        errors.add('تم تسجيل الحضور مسبقاً اليوم');
      } else if (attendanceType == AttendanceType.checkOut && !hasCheckedInToday) {
        errors.add('يجب تسجيل الحضور أولاً قبل الانصراف');
      } else if (attendanceType == AttendanceType.checkOut && hasCheckedOutToday) {
        errors.add('تم تسجيل الانصراف مسبقاً اليوم');
      }

      // Check biometric availability if required
      if (requireBiometric) {
        await checkBiometricAvailability();
        if (_biometricAvailability?.isAvailable != true) {
          errors.add(_biometricAvailability?.errorMessage ?? 'المصادقة البيومترية غير متاحة');
        }
      }

      // Check location validation if required
      if (requireLocation) {
        await validateLocationForAttendance();
        if (_lastLocationValidation?.isValid != true) {
          errors.add(_lastLocationValidation?.errorMessage ?? 'الموقع خارج النطاق المسموح');
        } else if ((_lastLocationValidation?.distanceFromWarehouse ?? 0) > 100) {
          warnings.add('أنت بعيد نسبياً عن المخزن (${_lastLocationValidation?.distanceFromWarehouse?.toStringAsFixed(0)} متر)');
        }
      }

      return AttendancePrerequisiteResult(
        isValid: errors.isEmpty,
        errors: errors,
        warnings: warnings,
        canProceed: errors.isEmpty,
        locationValidation: _lastLocationValidation,
        biometricAvailability: _biometricAvailability,
      );

    } catch (e) {
      AppLogger.error('❌ Error validating attendance prerequisites: $e');
      return AttendancePrerequisiteResult(
        isValid: false,
        errors: ['خطأ في التحقق من متطلبات الحضور: $e'],
        warnings: [],
        canProceed: false,
      );
    }
  }

  /// Processes attendance with automatic method selection (QR or Biometric)
  Future<dynamic> processSmartAttendance({
    required String workerId,
    required AttendanceType attendanceType,
    String? qrCode,
    bool preferBiometric = false,
    String? warehouseId,
  }) async {
    try {
      AppLogger.info('🤖 Processing smart attendance...');

      // Validate prerequisites first
      final prerequisites = await validateAttendancePrerequisites(
        workerId: workerId,
        attendanceType: attendanceType,
        requireBiometric: preferBiometric,
        requireLocation: true,
      );

      if (!prerequisites.canProceed) {
        _setError(prerequisites.statusMessage);
        return null;
      }

      // Choose method based on availability and preference
      if (preferBiometric && _biometricAvailability?.isAvailable == true) {
        AppLogger.info('🔐 Using biometric authentication...');
        return await processBiometricAttendance(
          workerId: workerId,
          attendanceType: attendanceType,
          warehouseId: warehouseId,
        );
      } else if (qrCode != null) {
        AppLogger.info('📱 Using QR code authentication...');
        return await processQRAttendance(
          workerId: workerId,
          attendanceType: attendanceType,
        );
      } else {
        _setError('لا توجد طريقة مصادقة متاحة');
        return null;
      }
    } catch (e) {
      AppLogger.error('❌ Error in smart attendance processing: $e');
      _setError('خطأ في معالجة الحضور الذكي: ${e.toString()}');
      return null;
    }
  }

  /// Clears all attendance data
  void clearAttendanceData() {
    _currentProfile = null;
    _attendanceRecords.clear();
    _attendanceStats = null;
    _todayStatus = null;
    _validationStatus = null;
    _lastLocationValidation = null;
    _biometricAvailability = null;
    _error = null;
    _isLoading = false;
    _isProcessingQR = false;
    _isProcessingBiometric = false;
    _isCheckingLocation = false;
    notifyListeners();
  }

  /// Dispose resources
  @override
  void dispose() {
    // Clean up debounce timer to prevent memory leaks
    _refreshDebounceTimer?.cancel();
    _refreshDebounceTimer = null;

    _locationService.dispose();
    _biometricService.dispose();
    super.dispose();
  }
}
