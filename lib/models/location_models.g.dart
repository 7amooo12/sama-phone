// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'location_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WarehouseLocationSettings _$WarehouseLocationSettingsFromJson(
        Map<String, dynamic> json) =>
    WarehouseLocationSettings(
      id: json['id'] as String,
      warehouseName: json['warehouse_name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      geofenceRadius: (json['geofence_radius'] as num).toDouble(),
      isActive: json['is_active'] as bool,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      createdBy: json['created_by'] as String,
    );

Map<String, dynamic> _$WarehouseLocationSettingsToJson(
        WarehouseLocationSettings instance) =>
    <String, dynamic>{
      'id': instance.id,
      'warehouse_name': instance.warehouseName,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'geofence_radius': instance.geofenceRadius,
      'is_active': instance.isActive,
      'description': instance.description,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
      'created_by': instance.createdBy,
    };

LocationValidationResult _$LocationValidationResultFromJson(
        Map<String, dynamic> json) =>
    LocationValidationResult(
      isValid: json['isValid'] as bool,
      currentLatitude: (json['currentLatitude'] as num?)?.toDouble(),
      currentLongitude: (json['currentLongitude'] as num?)?.toDouble(),
      warehouseLatitude: (json['warehouseLatitude'] as num?)?.toDouble(),
      warehouseLongitude: (json['warehouseLongitude'] as num?)?.toDouble(),
      distanceFromWarehouse:
          (json['distanceFromWarehouse'] as num?)?.toDouble(),
      allowedRadius: (json['allowedRadius'] as num?)?.toDouble(),
      errorMessage: json['errorMessage'] as String?,
      status: $enumDecode(_$LocationValidationStatusEnumMap, json['status']),
      validatedAt: DateTime.parse(json['validatedAt'] as String),
    );

Map<String, dynamic> _$LocationValidationResultToJson(
        LocationValidationResult instance) =>
    <String, dynamic>{
      'isValid': instance.isValid,
      'currentLatitude': instance.currentLatitude,
      'currentLongitude': instance.currentLongitude,
      'warehouseLatitude': instance.warehouseLatitude,
      'warehouseLongitude': instance.warehouseLongitude,
      'distanceFromWarehouse': instance.distanceFromWarehouse,
      'allowedRadius': instance.allowedRadius,
      'errorMessage': instance.errorMessage,
      'status': _$LocationValidationStatusEnumMap[instance.status]!,
      'validatedAt': instance.validatedAt.toIso8601String(),
    };

const _$LocationValidationStatusEnumMap = {
  LocationValidationStatus.withinGeofence: 'within_geofence',
  LocationValidationStatus.outsideGeofence: 'outside_geofence',
  LocationValidationStatus.locationDisabled: 'location_disabled',
  LocationValidationStatus.permissionDenied: 'permission_denied',
  LocationValidationStatus.locationUnavailable: 'location_unavailable',
  LocationValidationStatus.warehouseLocationNotSet:
      'warehouse_location_not_set',
  LocationValidationStatus.networkError: 'network_error',
  LocationValidationStatus.unknownError: 'unknown_error',
};

AttendanceLocationInfo _$AttendanceLocationInfoFromJson(
        Map<String, dynamic> json) =>
    AttendanceLocationInfo(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      altitude: (json['altitude'] as num?)?.toDouble(),
      speed: (json['speed'] as num?)?.toDouble(),
      heading: (json['heading'] as num?)?.toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      locationValidated: json['locationValidated'] as bool,
      distanceFromWarehouse:
          (json['distanceFromWarehouse'] as num?)?.toDouble(),
      address: json['address'] as String?,
    );

Map<String, dynamic> _$AttendanceLocationInfoToJson(
        AttendanceLocationInfo instance) =>
    <String, dynamic>{
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'accuracy': instance.accuracy,
      'altitude': instance.altitude,
      'speed': instance.speed,
      'heading': instance.heading,
      'timestamp': instance.timestamp.toIso8601String(),
      'locationValidated': instance.locationValidated,
      'distanceFromWarehouse': instance.distanceFromWarehouse,
      'address': instance.address,
    };

GeofenceSettings _$GeofenceSettingsFromJson(Map<String, dynamic> json) =>
    GeofenceSettings(
      defaultRadius: (json['defaultRadius'] as num).toDouble(),
      minRadius: (json['minRadius'] as num).toDouble(),
      maxRadius: (json['maxRadius'] as num).toDouble(),
      strictModeEnabled: json['strictModeEnabled'] as bool,
      allowManualOverride: json['allowManualOverride'] as bool,
      locationTimeoutSeconds: (json['locationTimeoutSeconds'] as num).toInt(),
      accuracyThreshold: (json['accuracyThreshold'] as num).toDouble(),
    );

Map<String, dynamic> _$GeofenceSettingsToJson(GeofenceSettings instance) =>
    <String, dynamic>{
      'defaultRadius': instance.defaultRadius,
      'minRadius': instance.minRadius,
      'maxRadius': instance.maxRadius,
      'strictModeEnabled': instance.strictModeEnabled,
      'allowManualOverride': instance.allowManualOverride,
      'locationTimeoutSeconds': instance.locationTimeoutSeconds,
      'accuracyThreshold': instance.accuracyThreshold,
    };
