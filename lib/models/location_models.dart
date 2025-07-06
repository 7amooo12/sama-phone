/// Location Management Models for Worker Attendance System
/// 
/// This file contains models for warehouse location settings, geofence configuration,
/// and location validation results for the SmartBizTracker attendance system.

import 'package:json_annotation/json_annotation.dart';
import 'package:geolocator/geolocator.dart';

part 'location_models.g.dart';

/// نموذج إعدادات موقع المخزن
@JsonSerializable()
class WarehouseLocationSettings {
  final String id;
  @JsonKey(name: 'warehouse_name')
  final String warehouseName;
  final double latitude;
  final double longitude;
  @JsonKey(name: 'geofence_radius')
  final double geofenceRadius; // بالمتر
  @JsonKey(name: 'is_active')
  final bool isActive;
  final String? description;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;
  @JsonKey(name: 'created_by')
  final String createdBy;

  const WarehouseLocationSettings({
    required this.id,
    required this.warehouseName,
    required this.latitude,
    required this.longitude,
    required this.geofenceRadius,
    required this.isActive,
    this.description,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
  });

  factory WarehouseLocationSettings.fromJson(Map<String, dynamic> json) =>
      _$WarehouseLocationSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$WarehouseLocationSettingsToJson(this);

  WarehouseLocationSettings copyWith({
    String? id,
    String? warehouseName,
    double? latitude,
    double? longitude,
    double? geofenceRadius,
    bool? isActive,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return WarehouseLocationSettings(
      id: id ?? this.id,
      warehouseName: warehouseName ?? this.warehouseName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      geofenceRadius: geofenceRadius ?? this.geofenceRadius,
      isActive: isActive ?? this.isActive,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}

/// نموذج نتيجة التحقق من الموقع
@JsonSerializable()
class LocationValidationResult {
  final bool isValid;
  final double? currentLatitude;
  final double? currentLongitude;
  final double? warehouseLatitude;
  final double? warehouseLongitude;
  final double? distanceFromWarehouse; // بالمتر
  final double? allowedRadius; // بالمتر
  final String? errorMessage;
  final LocationValidationStatus status;
  final DateTime validatedAt;

  const LocationValidationResult({
    required this.isValid,
    this.currentLatitude,
    this.currentLongitude,
    this.warehouseLatitude,
    this.warehouseLongitude,
    this.distanceFromWarehouse,
    this.allowedRadius,
    this.errorMessage,
    required this.status,
    required this.validatedAt,
  });

  factory LocationValidationResult.fromJson(Map<String, dynamic> json) =>
      _$LocationValidationResultFromJson(json);

  Map<String, dynamic> toJson() => _$LocationValidationResultToJson(this);

  /// إنشاء نتيجة صحيحة
  factory LocationValidationResult.valid({
    required double currentLatitude,
    required double currentLongitude,
    required double warehouseLatitude,
    required double warehouseLongitude,
    required double distanceFromWarehouse,
    required double allowedRadius,
  }) {
    return LocationValidationResult(
      isValid: true,
      currentLatitude: currentLatitude,
      currentLongitude: currentLongitude,
      warehouseLatitude: warehouseLatitude,
      warehouseLongitude: warehouseLongitude,
      distanceFromWarehouse: distanceFromWarehouse,
      allowedRadius: allowedRadius,
      status: LocationValidationStatus.withinGeofence,
      validatedAt: DateTime.now(),
    );
  }

  /// إنشاء نتيجة خاطئة
  factory LocationValidationResult.invalid({
    required String errorMessage,
    required LocationValidationStatus status,
    double? currentLatitude,
    double? currentLongitude,
    double? warehouseLatitude,
    double? warehouseLongitude,
    double? distanceFromWarehouse,
    double? allowedRadius,
  }) {
    return LocationValidationResult(
      isValid: false,
      currentLatitude: currentLatitude,
      currentLongitude: currentLongitude,
      warehouseLatitude: warehouseLatitude,
      warehouseLongitude: warehouseLongitude,
      distanceFromWarehouse: distanceFromWarehouse,
      allowedRadius: allowedRadius,
      errorMessage: errorMessage,
      status: status,
      validatedAt: DateTime.now(),
    );
  }
}

/// حالات التحقق من الموقع
enum LocationValidationStatus {
  @JsonValue('within_geofence')
  withinGeofence,
  
  @JsonValue('outside_geofence')
  outsideGeofence,
  
  @JsonValue('location_disabled')
  locationDisabled,
  
  @JsonValue('permission_denied')
  permissionDenied,
  
  @JsonValue('location_unavailable')
  locationUnavailable,
  
  @JsonValue('warehouse_location_not_set')
  warehouseLocationNotSet,
  
  @JsonValue('network_error')
  networkError,
  
  @JsonValue('unknown_error')
  unknownError;

  String get arabicLabel {
    switch (this) {
      case LocationValidationStatus.withinGeofence:
        return 'داخل النطاق المسموح';
      case LocationValidationStatus.outsideGeofence:
        return 'خارج النطاق المسموح';
      case LocationValidationStatus.locationDisabled:
        return 'خدمة الموقع معطلة';
      case LocationValidationStatus.permissionDenied:
        return 'تم رفض إذن الموقع';
      case LocationValidationStatus.locationUnavailable:
        return 'الموقع غير متاح';
      case LocationValidationStatus.warehouseLocationNotSet:
        return 'موقع المخزن غير محدد';
      case LocationValidationStatus.networkError:
        return 'خطأ في الشبكة';
      case LocationValidationStatus.unknownError:
        return 'خطأ غير معروف';
    }
  }
}

/// نموذج معلومات الموقع للحضور
@JsonSerializable()
class AttendanceLocationInfo {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? altitude;
  final double? speed;
  final double? heading;
  final DateTime timestamp;
  final bool locationValidated;
  final double? distanceFromWarehouse;
  final String? address;

  const AttendanceLocationInfo({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.altitude,
    this.speed,
    this.heading,
    required this.timestamp,
    required this.locationValidated,
    this.distanceFromWarehouse,
    this.address,
  });

  factory AttendanceLocationInfo.fromJson(Map<String, dynamic> json) =>
      _$AttendanceLocationInfoFromJson(json);

  Map<String, dynamic> toJson() => _$AttendanceLocationInfoToJson(this);
}

/// نموذج إعدادات الجيوفنس
@JsonSerializable()
class GeofenceSettings {
  final double defaultRadius;
  final double minRadius;
  final double maxRadius;
  final bool strictModeEnabled;
  final bool allowManualOverride;
  final int locationTimeoutSeconds;
  final double accuracyThreshold;

  const GeofenceSettings({
    required this.defaultRadius,
    required this.minRadius,
    required this.maxRadius,
    required this.strictModeEnabled,
    required this.allowManualOverride,
    required this.locationTimeoutSeconds,
    required this.accuracyThreshold,
  });

  factory GeofenceSettings.fromJson(Map<String, dynamic> json) =>
      _$GeofenceSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$GeofenceSettingsToJson(this);

  /// الإعدادات الافتراضية
  factory GeofenceSettings.defaultSettings() {
    return const GeofenceSettings(
      defaultRadius: 500.0, // 500 متر
      minRadius: 50.0,      // 50 متر
      maxRadius: 2000.0,    // 2 كيلومتر
      strictModeEnabled: true,
      allowManualOverride: false,
      locationTimeoutSeconds: 30,
      accuracyThreshold: 100.0, // 100 متر
    );
  }
}

/// حالة خدمة الموقع
enum LocationServiceStatus {
  available,
  disabled,
  permissionDenied,
  permissionDeniedForever,
  unknown,
}

/// نتيجة طلب إذن الموقع
class LocationPermissionResult {
  final bool isGranted;
  final LocationPermission status;
  final String message;
  final bool canOpenSettings;

  const LocationPermissionResult({
    required this.isGranted,
    required this.status,
    required this.message,
    required this.canOpenSettings,
  });
}

/// معلومات الموقع التفصيلية
class DetailedLocationInfo {
  final Position position;
  final LocationValidationResult validation;
  final double accuracy;
  final bool isAccurate;
  final DateTime timestamp;
  final String? formattedDistance;

  const DetailedLocationInfo({
    required this.position,
    required this.validation,
    required this.accuracy,
    required this.isAccurate,
    required this.timestamp,
    this.formattedDistance,
  });
}
