/// Location Service for Worker Attendance System
/// 
/// This service handles GPS operations, distance calculations, and location validation
/// for the SmartBizTracker biometric attendance system.

import 'dart:async';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/location_models.dart';
import '../utils/app_logger.dart';
import '../utils/uuid_validator.dart';

class LocationService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Enhanced cache for location permissions and settings
  static bool? _cachedPermissionStatus;
  static DateTime? _lastPermissionCheck;
  static Position? _cachedPosition;
  static DateTime? _lastPositionFetch;
  static WarehouseLocationSettings? _cachedWarehouseSettings;
  static DateTime? _lastSettingsFetch;
  static LocationValidationResult? _cachedValidationResult;
  static DateTime? _lastValidationCheck;

  // Optimized cache duration constants
  static const Duration _permissionCacheDuration = Duration(minutes: 10); // Increased from 5 minutes
  static const Duration _positionCacheDuration = Duration(minutes: 1); // Reduced from 2 minutes
  static const Duration _settingsCacheDuration = Duration(minutes: 15); // Increased from 10 minutes
  static const Duration _validationCacheDuration = Duration(seconds: 30); // New validation cache

  // Enhanced debouncing for location requests
  static Timer? _locationRequestTimer;
  static Timer? _validationRequestTimer;
  static const Duration _locationRequestDebounce = Duration(milliseconds: 1500); // Reduced from 3 seconds
  static const Duration _validationRequestDebounce = Duration(milliseconds: 800); // New validation debounce

  // Performance monitoring and throttling
  static int _locationRequestCount = 0;
  static DateTime? _lastPerformanceReset;
  static const int _maxRequestsPerMinute = 10;

  /// التحقق من أذونات الموقع وطلبها إذا لزم الأمر مع تحسين التخزين المؤقت
  Future<bool> checkAndRequestLocationPermissions() async {
    try {
      // Check cache first
      if (_cachedPermissionStatus != null &&
          _lastPermissionCheck != null &&
          DateTime.now().difference(_lastPermissionCheck!) < _permissionCacheDuration) {
        AppLogger.info('🔍 استخدام أذونات الموقع المحفوظة: $_cachedPermissionStatus');
        return _cachedPermissionStatus!;
      }

      AppLogger.info('🔍 فحص أذونات الموقع...');

      // التحقق من تفعيل خدمة الموقع أولاً
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        AppLogger.warning('⚠️ خدمة الموقع معطلة');
        _updatePermissionCache(false);
        return false;
      }

      // فحص حالة الإذن الحالية
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        AppLogger.info('📍 طلب إذن الموقع...');
        permission = await Geolocator.requestPermission();
      }

      bool hasPermission = permission == LocationPermission.whileInUse ||
                          permission == LocationPermission.always;

      _updatePermissionCache(hasPermission);

      if (!hasPermission) {
        AppLogger.warning('⚠️ تم رفض إذن الموقع: $permission');
      }

      return hasPermission;
    } catch (e) {
      AppLogger.error('❌ خطأ في فحص أذونات الموقع: $e');
      _updatePermissionCache(false);
      return false;
    }
  }

  /// الحصول على الموقع الحالي مع تحسين الأداء والتخزين المؤقت
  Future<Position?> getCurrentLocation({bool forceRefresh = false}) async {
    try {
      // Performance throttling
      if (!_canMakeLocationRequest()) {
        AppLogger.warning('⚠️ تم تجاوز حد طلبات الموقع. استخدام الموقع المحفوظ');
        return _cachedPosition;
      }

      // Check cache first (unless force refresh)
      if (!forceRefresh &&
          _cachedPosition != null &&
          _lastPositionFetch != null &&
          DateTime.now().difference(_lastPositionFetch!) < _positionCacheDuration) {
        AppLogger.info('📍 استخدام الموقع المحفوظ: ${_cachedPosition!.latitude}, ${_cachedPosition!.longitude}');
        return _cachedPosition;
      }

      // Debounce location requests
      if (_locationRequestTimer?.isActive == true) {
        AppLogger.info('⏳ انتظار انتهاء طلب الموقع السابق...');
        _locationRequestTimer!.cancel();
      }

      Completer<Position?> completer = Completer<Position?>();

      _locationRequestTimer = Timer(_locationRequestDebounce, () async {
        try {
          // التحقق من الأذونات
          bool hasPermission = await checkAndRequestLocationPermissions();
          if (!hasPermission) {
            completer.complete(null);
            return;
          }

          AppLogger.info('📍 الحصول على الموقع الحالي...');
          _locationRequestCount++;

          // الحصول على الموقع
          Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 15), // Reduced timeout for better performance
          );

          _updatePositionCache(position);
          AppLogger.info('✅ تم الحصول على الموقع: ${position.latitude}, ${position.longitude}');
          completer.complete(position);
        } catch (e) {
          AppLogger.error('❌ خطأ في الحصول على الموقع: $e');
          completer.complete(null);
        }
      });

      return await completer.future;
    } catch (e) {
      AppLogger.error('❌ خطأ في getCurrentLocation: $e');
      return null;
    }
  }

  /// حساب المسافة بين نقطتين (بالمتر)
  double calculateDistance(
    double lat1, double lon1,
    double lat2, double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  /// التحقق من صحة الموقع للحضور مع تحسين الأداء والتخزين المؤقت
  Future<LocationValidationResult> validateLocationForAttendance(
    String? warehouseId, {
    bool forceRefresh = false,
  }) async {
    try {
      // Check validation cache first
      if (!forceRefresh &&
          _cachedValidationResult != null &&
          _lastValidationCheck != null &&
          DateTime.now().difference(_lastValidationCheck!) < _validationCacheDuration) {
        AppLogger.info('🔍 استخدام نتيجة التحقق المحفوظة');
        return _cachedValidationResult!;
      }

      // Debounce validation requests
      if (_validationRequestTimer?.isActive == true) {
        AppLogger.info('⏳ انتظار انتهاء طلب التحقق السابق...');
        _validationRequestTimer!.cancel();
      }

      Completer<LocationValidationResult> completer = Completer<LocationValidationResult>();

      _validationRequestTimer = Timer(_validationRequestDebounce, () async {
        try {
          AppLogger.info('🔍 بدء التحقق من صحة الموقع للحضور...');

          // الحصول على الموقع الحالي
          Position? currentPosition = await getCurrentLocation();
          if (currentPosition == null) {
            LocationValidationResult result = LocationValidationResult.invalid(
              errorMessage: 'لا يمكن تحديد موقعك الحالي',
              status: LocationValidationStatus.locationUnavailable,
            );
            _updateValidationCache(result);
            completer.complete(result);
            return;
          }

          // الحصول على إعدادات موقع المخزن
          WarehouseLocationSettings? warehouseLocation =
              await getWarehouseLocationSettings(warehouseId);

          if (warehouseLocation == null || !warehouseLocation.isActive) {
            LocationValidationResult result = LocationValidationResult.invalid(
              errorMessage: 'موقع المخزن غير محدد أو معطل',
              status: LocationValidationStatus.warehouseLocationNotSet,
            );
            _updateValidationCache(result);
            completer.complete(result);
            return;
          }

          // حساب المسافة
          double distance = calculateDistance(
            currentPosition.latitude,
            currentPosition.longitude,
            warehouseLocation.latitude,
            warehouseLocation.longitude,
          );

          AppLogger.info('📏 المسافة من المخزن: ${distance.toStringAsFixed(2)} متر');

          // التحقق من النطاق المسموح
          LocationValidationResult result;
          if (distance <= warehouseLocation.geofenceRadius) {
            result = LocationValidationResult.valid(
              currentLatitude: currentPosition.latitude,
              currentLongitude: currentPosition.longitude,
              warehouseLatitude: warehouseLocation.latitude,
              warehouseLongitude: warehouseLocation.longitude,
              distanceFromWarehouse: distance,
              allowedRadius: warehouseLocation.geofenceRadius,
            );
          } else {
            result = LocationValidationResult.invalid(
              errorMessage: 'أنت خارج النطاق المسموح للمخزن. توجه للمخزن لتسجيل الحضور',
              status: LocationValidationStatus.outsideGeofence,
              currentLatitude: currentPosition.latitude,
              currentLongitude: currentPosition.longitude,
              warehouseLatitude: warehouseLocation.latitude,
              warehouseLongitude: warehouseLocation.longitude,
              distanceFromWarehouse: distance,
              allowedRadius: warehouseLocation.geofenceRadius,
            );
          }

          _updateValidationCache(result);
          AppLogger.info(result.isValid
              ? '✅ الموقع صحيح - داخل النطاق المسموح'
              : '⚠️ الموقع خارج النطاق المسموح');

          completer.complete(result);
        } catch (e) {
          AppLogger.error('❌ خطأ في التحقق من صحة الموقع: $e');
          LocationValidationResult result = LocationValidationResult.invalid(
            errorMessage: 'خطأ في التحقق من الموقع: $e',
            status: LocationValidationStatus.unknownError,
          );
          _updateValidationCache(result);
          completer.complete(result);
        }
      });

      return await completer.future;
    } catch (e) {
      AppLogger.error('❌ خطأ في validateLocationForAttendance: $e');
      return LocationValidationResult.invalid(
        errorMessage: 'خطأ في التحقق من الموقع: $e',
        status: LocationValidationStatus.unknownError,
      );
    }
  }

  /// الحصول على إعدادات موقع المخزن مع تحسين التخزين المؤقت
  Future<WarehouseLocationSettings?> getWarehouseLocationSettings(
    String? warehouseId,
  ) async {
    try {
      // Check cache first
      if (_cachedWarehouseSettings != null &&
          _lastSettingsFetch != null &&
          DateTime.now().difference(_lastSettingsFetch!) < _settingsCacheDuration) {
        AppLogger.info('🏢 استخدام إعدادات المخزن المحفوظة');
        return _cachedWarehouseSettings;
      }

      AppLogger.info('🏢 جلب إعدادات موقع المخزن...');

      final response = await _supabase
          .from('warehouse_location_settings')
          .select()
          .eq('is_active', true)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        AppLogger.warning('⚠️ لم يتم العثور على إعدادات موقع المخزن');
        return null;
      }

      WarehouseLocationSettings settings = WarehouseLocationSettings.fromJson(response);
      _updateWarehouseSettingsCache(settings);

      AppLogger.info('✅ تم جلب إعدادات المخزن: ${settings.warehouseName}');
      return settings;
    } catch (e) {
      AppLogger.error('❌ خطأ في جلب إعدادات موقع المخزن: $e');
      return null;
    }
  }

  /// حفظ إعدادات موقع المخزن (للمدير)
  Future<bool> saveWarehouseLocationSettings(
    WarehouseLocationSettings settings,
  ) async {
    try {
      AppLogger.info('💾 حفظ إعدادات موقع المخزن...');

      // Validate UUID fields before database operation
      UuidValidator.validateUuidWithMessage(
        settings.createdBy,
        'معرف المستخدم المنشئ غير صحيح - يجب أن يكون UUID صالح'
      );

      // إلغاء تفعيل الإعدادات السابقة
      await _supabase
          .from('warehouse_location_settings')
          .update({'is_active': false})
          .eq('is_active', true);

      // إدراج الإعدادات الجديدة مع التحقق من UUID
      final jsonData = settings.toJson();

      // Ensure created_by is a valid UUID
      if (!UuidValidator.isValidUuid(jsonData['created_by'])) {
        throw Exception('معرف المستخدم المنشئ غير صحيح: ${jsonData['created_by']}');
      }

      await _supabase
          .from('warehouse_location_settings')
          .insert(jsonData);

      // Clear cache after successful save
      _clearWarehouseSettingsCache();

      AppLogger.info('✅ تم حفظ إعدادات موقع المخزن بنجاح');
      return true;
    } catch (e) {
      AppLogger.error('❌ خطأ في حفظ إعدادات موقع المخزن: $e');

      // Provide more specific error message for UUID validation
      if (e.toString().contains('invalid input syntax for type uuid')) {
        AppLogger.error('❌ خطأ في تنسيق UUID - تأكد من صحة معرف المستخدم');
      }

      return false;
    }
  }

  /// إنشاء معلومات الموقع للحضور
  Future<AttendanceLocationInfo?> createAttendanceLocationInfo(
    Position position,
    LocationValidationResult validation,
  ) async {
    try {
      return AttendanceLocationInfo(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        altitude: position.altitude,
        speed: position.speed,
        heading: position.heading,
        timestamp: position.timestamp ?? DateTime.now(),
        locationValidated: validation.isValid,
        distanceFromWarehouse: validation.distanceFromWarehouse,
      );
    } catch (e) {
      AppLogger.error('❌ خطأ في إنشاء معلومات موقع الحضور: $e');
      return null;
    }
  }

  /// فتح إعدادات الموقع
  Future<void> openLocationSettings() async {
    try {
      await Geolocator.openLocationSettings();
    } catch (e) {
      AppLogger.error('❌ خطأ في فتح إعدادات الموقع: $e');
    }
  }

  /// فتح إعدادات التطبيق
  Future<void> openAppSettings() async {
    try {
      await Geolocator.openAppSettings();
    } catch (e) {
      AppLogger.error('❌ خطأ في فتح إعدادات التطبيق: $e');
    }
  }

  /// الحصول على المسافة المنسقة كنص
  String getFormattedDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.toStringAsFixed(0)} متر';
    } else {
      double distanceInKm = distanceInMeters / 1000;
      return '${distanceInKm.toStringAsFixed(2)} كيلومتر';
    }
  }

  /// التحقق من دقة الموقع
  bool isLocationAccurate(Position position, {double threshold = 100.0}) {
    return position.accuracy <= threshold;
  }

  /// الحصول على الموقع مع إعادة المحاولة
  Future<Position?> getCurrentLocationWithRetry({
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 2),
  }) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        AppLogger.info('📍 محاولة الحصول على الموقع ($attempt/$maxRetries)...');

        Position? position = await getCurrentLocation();
        if (position != null) {
          AppLogger.info('✅ تم الحصول على الموقع في المحاولة $attempt');
          return position;
        }
      } catch (e) {
        AppLogger.warning('⚠️ فشلت المحاولة $attempt: $e');
        if (attempt < maxRetries) {
          AppLogger.info('🔄 إعادة المحاولة خلال ${retryDelay.inSeconds} ثانية...');
          await Future.delayed(retryDelay);
        }
      }
    }

    AppLogger.error('❌ فشل في الحصول على الموقع بعد $maxRetries محاولات');
    return null;
  }

  /// فحص حالة خدمات الموقع
  Future<LocationServiceStatus> checkLocationServiceStatus() async {
    try {
      // فحص تفعيل خدمة الموقع
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationServiceStatus.disabled;
      }

      // فحص الأذونات
      LocationPermission permission = await Geolocator.checkPermission();

      switch (permission) {
        case LocationPermission.denied:
          return LocationServiceStatus.permissionDenied;
        case LocationPermission.deniedForever:
          return LocationServiceStatus.permissionDeniedForever;
        case LocationPermission.whileInUse:
        case LocationPermission.always:
          return LocationServiceStatus.available;
        default:
          return LocationServiceStatus.unknown;
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في فحص حالة خدمة الموقع: $e');
      return LocationServiceStatus.unknown;
    }
  }

  /// طلب أذونات الموقع مع معالجة شاملة
  Future<LocationPermissionResult> requestLocationPermission() async {
    try {
      // فحص حالة الخدمة أولاً
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationPermissionResult(
          isGranted: false,
          status: LocationPermission.denied,
          message: 'خدمة الموقع معطلة. يرجى تفعيلها من الإعدادات',
          canOpenSettings: true,
        );
      }

      // فحص الإذن الحالي
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.deniedForever) {
        return LocationPermissionResult(
          isGranted: false,
          status: permission,
          message: 'تم رفض إذن الموقع نهائياً. يرجى تفعيله من إعدادات التطبيق',
          canOpenSettings: true,
        );
      }

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      bool isGranted = permission == LocationPermission.whileInUse ||
                      permission == LocationPermission.always;

      return LocationPermissionResult(
        isGranted: isGranted,
        status: permission,
        message: isGranted
            ? 'تم منح إذن الموقع بنجاح'
            : 'تم رفض إذن الموقع',
        canOpenSettings: !isGranted,
      );

    } catch (e) {
      AppLogger.error('❌ خطأ في طلب إذن الموقع: $e');
      return LocationPermissionResult(
        isGranted: false,
        status: LocationPermission.denied,
        message: 'خطأ في طلب إذن الموقع: $e',
        canOpenSettings: true,
      );
    }
  }

  /// الحصول على معلومات تفصيلية عن الموقع
  Future<DetailedLocationInfo?> getDetailedLocationInfo() async {
    try {
      Position? position = await getCurrentLocationWithRetry();
      if (position == null) return null;

      LocationValidationResult validation = await validateLocationForAttendance(null);

      return DetailedLocationInfo(
        position: position,
        validation: validation,
        accuracy: position.accuracy,
        isAccurate: isLocationAccurate(position),
        timestamp: DateTime.now(),
        formattedDistance: validation.distanceFromWarehouse != null
            ? getFormattedDistance(validation.distanceFromWarehouse!)
            : null,
      );
    } catch (e) {
      AppLogger.error('❌ خطأ في الحصول على معلومات الموقع التفصيلية: $e');
      return null;
    }
  }

  /// الحصول على إحصائيات الحضور المبنية على الموقع
  Future<Map<String, dynamic>?> getLocationAttendanceStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      AppLogger.info('📊 جلب إحصائيات الحضور المبنية على الموقع...');

      final response = await _supabase.rpc('get_location_attendance_stats', params: {
        'start_date': startDate?.toIso8601String().split('T')[0] ?? DateTime.now().toIso8601String().split('T')[0],
        'end_date': endDate?.toIso8601String().split('T')[0] ?? DateTime.now().toIso8601String().split('T')[0],
      });

      if (response != null) {
        AppLogger.info('✅ تم جلب إحصائيات الموقع بنجاح');
        return Map<String, dynamic>.from(response);
      } else {
        AppLogger.warning('⚠️ لا توجد بيانات إحصائية للموقع');
        return {
          'total_records': 0,
          'location_validated': 0,
          'biometric_records': 0,
          'qr_records': 0,
          'average_distance': 0.0,
          'outside_geofence': 0,
          'location_validation_rate': 0.0,
        };
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في جلب إحصائيات الموقع: $e');
      return null;
    }
  }

  /// Performance monitoring and throttling
  bool _canMakeLocationRequest() {
    DateTime now = DateTime.now();

    // Reset counter every minute
    if (_lastPerformanceReset == null ||
        now.difference(_lastPerformanceReset!) > const Duration(minutes: 1)) {
      _locationRequestCount = 0;
      _lastPerformanceReset = now;
    }

    return _locationRequestCount < _maxRequestsPerMinute;
  }

  /// Cache update methods
  void _updatePositionCache(Position position) {
    _cachedPosition = position;
    _lastPositionFetch = DateTime.now();
  }

  void _updateWarehouseSettingsCache(WarehouseLocationSettings settings) {
    _cachedWarehouseSettings = settings;
    _lastSettingsFetch = DateTime.now();
  }

  /// مسح تخزين إعدادات المخزن المؤقت
  void _clearWarehouseSettingsCache() {
    _cachedWarehouseSettings = null;
    _lastSettingsFetch = null;
    AppLogger.info('🗑️ تم مسح تخزين إعدادات المخزن المؤقت');
  }

  void _updateValidationCache(LocationValidationResult result) {
    _cachedValidationResult = result;
    _lastValidationCheck = DateTime.now();
  }

  void _updatePermissionCache(bool hasPermission) {
    _cachedPermissionStatus = hasPermission;
    _lastPermissionCheck = DateTime.now();
  }

  /// Clear all caches (useful for testing or when settings change)
  void clearAllCaches() {
    _cachedPosition = null;
    _lastPositionFetch = null;
    _cachedWarehouseSettings = null;
    _lastSettingsFetch = null;
    _cachedValidationResult = null;
    _lastValidationCheck = null;
    _cachedPermissionStatus = null;
    _lastPermissionCheck = null;
    _locationRequestCount = 0;
    _lastPerformanceReset = null;

    AppLogger.info('🧹 تم مسح جميع ذاكرة التخزين المؤقت للموقع');
  }

  /// Get cache status for debugging
  Map<String, dynamic> getCacheStatus() {
    return {
      'position_cached': _cachedPosition != null,
      'position_age_seconds': _lastPositionFetch != null
          ? DateTime.now().difference(_lastPositionFetch!).inSeconds
          : null,
      'warehouse_settings_cached': _cachedWarehouseSettings != null,
      'warehouse_settings_age_seconds': _lastSettingsFetch != null
          ? DateTime.now().difference(_lastSettingsFetch!).inSeconds
          : null,
      'validation_cached': _cachedValidationResult != null,
      'validation_age_seconds': _lastValidationCheck != null
          ? DateTime.now().difference(_lastValidationCheck!).inSeconds
          : null,
      'permission_cached': _cachedPermissionStatus != null,
      'permission_age_seconds': _lastPermissionCheck != null
          ? DateTime.now().difference(_lastPermissionCheck!).inSeconds
          : null,
      'location_requests_count': _locationRequestCount,
      'performance_reset_age_seconds': _lastPerformanceReset != null
          ? DateTime.now().difference(_lastPerformanceReset!).inSeconds
          : null,
    };
  }

  /// تنظيف الموارد
  void dispose() {
    _locationRequestTimer?.cancel();
    _validationRequestTimer?.cancel();
    clearAllCaches();
    AppLogger.info('🧹 تنظيف موارد خدمة الموقع');
  }
}
