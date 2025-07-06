import 'package:json_annotation/json_annotation.dart';

part 'worker_attendance_model.g.dart';

/// نموذج بيانات حضور العامل
@JsonSerializable()
class WorkerAttendanceModel {
  final String id;
  final String workerId;
  final String workerName;
  final String employeeId;
  final DateTime timestamp;
  final AttendanceType type;
  final String deviceHash;
  final String? notes;
  final AttendanceStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const WorkerAttendanceModel({
    required this.id,
    required this.workerId,
    required this.workerName,
    required this.employeeId,
    required this.timestamp,
    required this.type,
    required this.deviceHash,
    this.notes,
    required this.status,
    required this.createdAt,
    this.updatedAt,
  });

  factory WorkerAttendanceModel.fromJson(Map<String, dynamic> json) {
    // Handle both snake_case (database) and camelCase (API) field names
    return WorkerAttendanceModel(
      id: json['id'] as String,
      workerId: (json['worker_id'] ?? json['workerId']) as String,
      workerName: (json['worker_name'] ?? json['workerName'] ?? 'غير محدد') as String,
      employeeId: (json['employee_id'] ?? json['employeeId'] ?? 'غير محدد') as String,
      timestamp: DateTime.parse((json['timestamp'] ?? json['created_at']) as String),
      type: _parseAttendanceType(json['attendance_type'] ?? json['type']),
      deviceHash: (json['device_hash'] ?? json['deviceHash']) as String,
      notes: (json['notes']) as String?,
      status: _parseAttendanceStatus(json['status'] ?? 'confirmed'),
      createdAt: DateTime.parse((json['created_at'] ?? json['createdAt']) as String),
      updatedAt: json['updated_at'] != null || json['updatedAt'] != null
          ? DateTime.parse((json['updated_at'] ?? json['updatedAt']) as String)
          : null,
    );
  }

  static AttendanceType _parseAttendanceType(dynamic value) {
    if (value == null) return AttendanceType.checkIn;
    final stringValue = value.toString();
    switch (stringValue) {
      case 'check_in':
        return AttendanceType.checkIn;
      case 'check_out':
        return AttendanceType.checkOut;
      default:
        return AttendanceType.checkIn;
    }
  }

  static AttendanceStatus _parseAttendanceStatus(dynamic value) {
    if (value == null) return AttendanceStatus.confirmed;
    final stringValue = value.toString();
    switch (stringValue) {
      case 'pending':
        return AttendanceStatus.pending;
      case 'confirmed':
        return AttendanceStatus.confirmed;
      case 'cancelled':
        return AttendanceStatus.cancelled;
      default:
        return AttendanceStatus.confirmed;
    }
  }

  Map<String, dynamic> toJson() => _$WorkerAttendanceModelToJson(this);

  WorkerAttendanceModel copyWith({
    String? id,
    String? workerId,
    String? workerName,
    String? employeeId,
    DateTime? timestamp,
    AttendanceType? type,
    String? deviceHash,
    String? notes,
    AttendanceStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WorkerAttendanceModel(
      id: id ?? this.id,
      workerId: workerId ?? this.workerId,
      workerName: workerName ?? this.workerName,
      employeeId: employeeId ?? this.employeeId,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      deviceHash: deviceHash ?? this.deviceHash,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkerAttendanceModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'WorkerAttendanceModel{id: $id, workerId: $workerId, workerName: $workerName, type: $type, timestamp: $timestamp}';
  }
}

/// أنواع الحضور
enum AttendanceType {
  @JsonValue('check_in')
  checkIn,
  @JsonValue('check_out')
  checkOut,
}

/// حالة الحضور
enum AttendanceStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('confirmed')
  confirmed,
  @JsonValue('cancelled')
  cancelled,
}

/// نموذج رمز QR للحضور
@JsonSerializable()
class QRAttendanceToken {
  final String workerId;
  final int timestamp;
  final String deviceHash;
  final String nonce;
  final String signature;

  const QRAttendanceToken({
    required this.workerId,
    required this.timestamp,
    required this.deviceHash,
    required this.nonce,
    required this.signature,
  });

  factory QRAttendanceToken.fromJson(Map<String, dynamic> json) =>
      _$QRAttendanceTokenFromJson(json);

  Map<String, dynamic> toJson() => _$QRAttendanceTokenToJson(this);

  /// التحقق من صحة الرمز المميز
  bool isValid() {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final tokenTime = timestamp;
    final timeDiff = (now - tokenTime).abs();
    
    // صالح لمدة 20 ثانية
    return timeDiff <= 20;
  }

  /// الحصول على الوقت المتبقي بالثواني
  int get remainingSeconds {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final timeDiff = 20 - (now - timestamp);
    return timeDiff > 0 ? timeDiff : 0;
  }

  @override
  String toString() {
    return 'QRAttendanceToken{workerId: $workerId, timestamp: $timestamp, deviceHash: $deviceHash}';
  }
}

/// نموذج معلومات الجهاز
@JsonSerializable()
class DeviceInfo {
  final String deviceId;
  final String deviceModel;
  final String deviceBrand;
  final String osVersion;
  final String appVersion;
  final String deviceHash;

  const DeviceInfo({
    required this.deviceId,
    required this.deviceModel,
    required this.deviceBrand,
    required this.osVersion,
    required this.appVersion,
    required this.deviceHash,
  });

  factory DeviceInfo.fromJson(Map<String, dynamic> json) =>
      _$DeviceInfoFromJson(json);

  Map<String, dynamic> toJson() => _$DeviceInfoToJson(this);

  @override
  String toString() {
    return 'DeviceInfo{deviceId: $deviceId, model: $deviceModel, brand: $deviceBrand}';
  }
}

/// نموذج استجابة التحقق من الحضور
@JsonSerializable()
class AttendanceValidationResponse {
  final bool isValid;
  final String? errorMessage;
  final String? errorCode;
  final WorkerAttendanceModel? attendanceRecord;
  final Map<String, dynamic>? metadata;

  const AttendanceValidationResponse({
    required this.isValid,
    this.errorMessage,
    this.errorCode,
    this.attendanceRecord,
    this.metadata,
  });

  factory AttendanceValidationResponse.fromJson(Map<String, dynamic> json) =>
      _$AttendanceValidationResponseFromJson(json);

  Map<String, dynamic> toJson() => _$AttendanceValidationResponseToJson(this);

  /// إنشاء استجابة نجاح
  factory AttendanceValidationResponse.success(WorkerAttendanceModel record) {
    return AttendanceValidationResponse(
      isValid: true,
      attendanceRecord: record,
    );
  }

  /// إنشاء استجابة خطأ
  factory AttendanceValidationResponse.error(String message, [String? code]) {
    return AttendanceValidationResponse(
      isValid: false,
      errorMessage: message,
      errorCode: code,
    );
  }

  @override
  String toString() {
    return 'AttendanceValidationResponse{isValid: $isValid, errorMessage: $errorMessage}';
  }
}

/// نموذج إحصائيات الحضور
@JsonSerializable()
class AttendanceStatistics {
  final int totalWorkers;
  final int presentWorkers;
  final int absentWorkers;
  final int lateWorkers;
  final List<WorkerAttendanceModel> recentAttendance;
  final DateTime lastUpdated;

  const AttendanceStatistics({
    required this.totalWorkers,
    required this.presentWorkers,
    required this.absentWorkers,
    required this.lateWorkers,
    required this.recentAttendance,
    required this.lastUpdated,
  });

  factory AttendanceStatistics.fromJson(Map<String, dynamic> json) =>
      _$AttendanceStatisticsFromJson(json);

  Map<String, dynamic> toJson() => _$AttendanceStatisticsToJson(this);

  /// إحصائيات فارغة
  factory AttendanceStatistics.empty() {
    return AttendanceStatistics(
      totalWorkers: 0,
      presentWorkers: 0,
      absentWorkers: 0,
      lateWorkers: 0,
      recentAttendance: [],
      lastUpdated: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'AttendanceStatistics{total: $totalWorkers, present: $presentWorkers, absent: $absentWorkers}';
  }
}

/// أكواد الأخطاء
class AttendanceErrorCodes {
  static const String tokenExpired = 'TOKEN_EXPIRED';
  static const String invalidSignature = 'INVALID_SIGNATURE';
  static const String replayAttack = 'REPLAY_ATTACK';
  static const String deviceMismatch = 'DEVICE_MISMATCH';
  static const String gapViolation = 'GAP_VIOLATION';
  static const String sequenceError = 'SEQUENCE_ERROR';
  static const String workerNotFound = 'WORKER_NOT_FOUND';
  static const String databaseError = 'DATABASE_ERROR';
  static const String networkError = 'NETWORK_ERROR';
  static const String cameraError = 'CAMERA_ERROR';
  static const String permissionDenied = 'PERMISSION_DENIED';
}

/// رسائل الأخطاء بالعربية
class AttendanceErrorMessages {
  static const Map<String, String> messages = {
    AttendanceErrorCodes.tokenExpired: 'انتهت صلاحية رمز QR. يرجى إنشاء رمز جديد.',
    AttendanceErrorCodes.invalidSignature: 'رمز QR غير صحيح أو تالف.',
    AttendanceErrorCodes.replayAttack: 'تم استخدام هذا الرمز من قبل.',
    AttendanceErrorCodes.deviceMismatch: 'الجهاز غير مطابق للجهاز المسجل.',
    AttendanceErrorCodes.gapViolation: 'يجب انتظار 15 ساعة على الأقل بين تسجيلات الحضور.',
    AttendanceErrorCodes.sequenceError: 'تسلسل الحضور غير صحيح. يجب تسجيل الخروج أولاً.',
    AttendanceErrorCodes.workerNotFound: 'العامل غير موجود في النظام.',
    AttendanceErrorCodes.databaseError: 'خطأ في قاعدة البيانات. يرجى المحاولة مرة أخرى.',
    AttendanceErrorCodes.networkError: 'خطأ في الاتصال. تحقق من الإنترنت.',
    AttendanceErrorCodes.cameraError: 'خطأ في الكاميرا. تحقق من الأذونات.',
    AttendanceErrorCodes.permissionDenied: 'تم رفض إذن الكاميرا. يرجى السماح بالوصول.',
  };

  static String getMessage(String? errorCode) {
    return messages[errorCode] ?? 'حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى.';
  }
}
