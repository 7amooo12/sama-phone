// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'worker_attendance_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WorkerAttendanceModel _$WorkerAttendanceModelFromJson(
        Map<String, dynamic> json) =>
    WorkerAttendanceModel(
      id: json['id'] as String,
      workerId: json['workerId'] as String,
      workerName: json['workerName'] as String,
      employeeId: json['employeeId'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      type: $enumDecode(_$AttendanceTypeEnumMap, json['type']),
      deviceHash: json['deviceHash'] as String,
      notes: json['notes'] as String?,
      status: $enumDecode(_$AttendanceStatusEnumMap, json['status']),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$WorkerAttendanceModelToJson(
        WorkerAttendanceModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'workerId': instance.workerId,
      'workerName': instance.workerName,
      'employeeId': instance.employeeId,
      'timestamp': instance.timestamp.toIso8601String(),
      'type': _$AttendanceTypeEnumMap[instance.type]!,
      'deviceHash': instance.deviceHash,
      'notes': instance.notes,
      'status': _$AttendanceStatusEnumMap[instance.status]!,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };

const _$AttendanceTypeEnumMap = {
  AttendanceType.checkIn: 'check_in',
  AttendanceType.checkOut: 'check_out',
};

const _$AttendanceStatusEnumMap = {
  AttendanceStatus.pending: 'pending',
  AttendanceStatus.confirmed: 'confirmed',
  AttendanceStatus.cancelled: 'cancelled',
};

QRAttendanceToken _$QRAttendanceTokenFromJson(Map<String, dynamic> json) =>
    QRAttendanceToken(
      workerId: json['workerId'] as String,
      timestamp: (json['timestamp'] as num).toInt(),
      deviceHash: json['deviceHash'] as String,
      nonce: json['nonce'] as String,
      signature: json['signature'] as String,
    );

Map<String, dynamic> _$QRAttendanceTokenToJson(QRAttendanceToken instance) =>
    <String, dynamic>{
      'workerId': instance.workerId,
      'timestamp': instance.timestamp,
      'deviceHash': instance.deviceHash,
      'nonce': instance.nonce,
      'signature': instance.signature,
    };

DeviceInfo _$DeviceInfoFromJson(Map<String, dynamic> json) => DeviceInfo(
      deviceId: json['deviceId'] as String,
      deviceModel: json['deviceModel'] as String,
      deviceBrand: json['deviceBrand'] as String,
      osVersion: json['osVersion'] as String,
      appVersion: json['appVersion'] as String,
      deviceHash: json['deviceHash'] as String,
    );

Map<String, dynamic> _$DeviceInfoToJson(DeviceInfo instance) =>
    <String, dynamic>{
      'deviceId': instance.deviceId,
      'deviceModel': instance.deviceModel,
      'deviceBrand': instance.deviceBrand,
      'osVersion': instance.osVersion,
      'appVersion': instance.appVersion,
      'deviceHash': instance.deviceHash,
    };

AttendanceValidationResponse _$AttendanceValidationResponseFromJson(
        Map<String, dynamic> json) =>
    AttendanceValidationResponse(
      isValid: json['isValid'] as bool,
      errorMessage: json['errorMessage'] as String?,
      errorCode: json['errorCode'] as String?,
      attendanceRecord: json['attendanceRecord'] == null
          ? null
          : WorkerAttendanceModel.fromJson(
              json['attendanceRecord'] as Map<String, dynamic>),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$AttendanceValidationResponseToJson(
        AttendanceValidationResponse instance) =>
    <String, dynamic>{
      'isValid': instance.isValid,
      'errorMessage': instance.errorMessage,
      'errorCode': instance.errorCode,
      'attendanceRecord': instance.attendanceRecord,
      'metadata': instance.metadata,
    };

AttendanceStatistics _$AttendanceStatisticsFromJson(
        Map<String, dynamic> json) =>
    AttendanceStatistics(
      totalWorkers: (json['totalWorkers'] as num).toInt(),
      presentWorkers: (json['presentWorkers'] as num).toInt(),
      absentWorkers: (json['absentWorkers'] as num).toInt(),
      lateWorkers: (json['lateWorkers'] as num).toInt(),
      recentAttendance: (json['recentAttendance'] as List<dynamic>)
          .map((e) => WorkerAttendanceModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
    );

Map<String, dynamic> _$AttendanceStatisticsToJson(
        AttendanceStatistics instance) =>
    <String, dynamic>{
      'totalWorkers': instance.totalWorkers,
      'presentWorkers': instance.presentWorkers,
      'absentWorkers': instance.absentWorkers,
      'lateWorkers': instance.lateWorkers,
      'recentAttendance': instance.recentAttendance,
      'lastUpdated': instance.lastUpdated.toIso8601String(),
    };
