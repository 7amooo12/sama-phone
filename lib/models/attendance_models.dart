/// Attendance Models for SmartBizTracker Worker Attendance System
///
/// This file contains all data models related to worker attendance tracking,
/// QR validation, and attendance records management.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'location_models.dart';

/// Enumeration for attendance types
enum AttendanceType {
  checkIn('check_in', 'تسجيل حضور'),
  checkOut('check_out', 'تسجيل انصراف');

  const AttendanceType(this.value, this.arabicLabel);
  
  final String value;
  final String arabicLabel;

  static AttendanceType fromString(String value) {
    switch (value) {
      case 'check_in':
        return AttendanceType.checkIn;
      case 'check_out':
        return AttendanceType.checkOut;
      default:
        throw ArgumentError('Invalid attendance type: $value');
    }
  }
}

/// Worker Attendance Profile Model
class WorkerAttendanceProfile {
  final String id;
  final String workerId;
  final String deviceHash;
  final String? deviceModel;
  final String? deviceOsVersion;
  final AttendanceType? lastAttendanceType;
  final DateTime? lastAttendanceTime;
  final int totalCheckIns;
  final int totalCheckOuts;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WorkerAttendanceProfile({
    required this.id,
    required this.workerId,
    required this.deviceHash,
    this.deviceModel,
    this.deviceOsVersion,
    this.lastAttendanceType,
    this.lastAttendanceTime,
    required this.totalCheckIns,
    required this.totalCheckOuts,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WorkerAttendanceProfile.fromJson(Map<String, dynamic> json) {
    return WorkerAttendanceProfile(
      id: json['id'] as String,
      workerId: json['worker_id'] as String,
      deviceHash: json['device_hash'] as String,
      deviceModel: json['device_model'] as String?,
      deviceOsVersion: json['device_os_version'] as String?,
      lastAttendanceType: json['last_attendance_type'] != null
          ? AttendanceType.fromString(json['last_attendance_type'] as String)
          : null,
      lastAttendanceTime: json['last_attendance_time'] != null
          ? DateTime.parse(json['last_attendance_time'] as String)
          : null,
      totalCheckIns: json['total_check_ins'] as int? ?? 0,
      totalCheckOuts: json['total_check_outs'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'worker_id': workerId,
      'device_hash': deviceHash,
      'device_model': deviceModel,
      'device_os_version': deviceOsVersion,
      'last_attendance_type': lastAttendanceType?.value,
      'last_attendance_time': lastAttendanceTime?.toIso8601String(),
      'total_check_ins': totalCheckIns,
      'total_check_outs': totalCheckOuts,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  WorkerAttendanceProfile copyWith({
    String? id,
    String? workerId,
    String? deviceHash,
    String? deviceModel,
    String? deviceOsVersion,
    AttendanceType? lastAttendanceType,
    DateTime? lastAttendanceTime,
    int? totalCheckIns,
    int? totalCheckOuts,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WorkerAttendanceProfile(
      id: id ?? this.id,
      workerId: workerId ?? this.workerId,
      deviceHash: deviceHash ?? this.deviceHash,
      deviceModel: deviceModel ?? this.deviceModel,
      deviceOsVersion: deviceOsVersion ?? this.deviceOsVersion,
      lastAttendanceType: lastAttendanceType ?? this.lastAttendanceType,
      lastAttendanceTime: lastAttendanceTime ?? this.lastAttendanceTime,
      totalCheckIns: totalCheckIns ?? this.totalCheckIns,
      totalCheckOuts: totalCheckOuts ?? this.totalCheckOuts,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Worker Attendance Record Model
class WorkerAttendanceRecord {
  final String id;
  final String workerId;
  final AttendanceType attendanceType;
  final DateTime timestamp;
  final String deviceHash;
  final String qrNonce;
  final Map<String, dynamic>? locationInfo;
  final Map<String, dynamic>? validationDetails;
  final String? notes;
  final DateTime createdAt;

  const WorkerAttendanceRecord({
    required this.id,
    required this.workerId,
    required this.attendanceType,
    required this.timestamp,
    required this.deviceHash,
    required this.qrNonce,
    this.locationInfo,
    this.validationDetails,
    this.notes,
    required this.createdAt,
  });

  factory WorkerAttendanceRecord.fromJson(Map<String, dynamic> json) {
    return WorkerAttendanceRecord(
      id: json['id'] as String,
      workerId: json['worker_id'] as String,
      attendanceType: AttendanceType.fromString(json['attendance_type'] as String),
      timestamp: DateTime.parse(json['timestamp'] as String),
      deviceHash: json['device_hash'] as String,
      qrNonce: json['qr_nonce'] as String,
      locationInfo: json['location_info'] as Map<String, dynamic>?,
      validationDetails: json['validation_details'] as Map<String, dynamic>?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'worker_id': workerId,
      'attendance_type': attendanceType.value,
      'timestamp': timestamp.toIso8601String(),
      'device_hash': deviceHash,
      'qr_nonce': qrNonce,
      'location_info': locationInfo,
      'validation_details': validationDetails,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// QR Validation Result Model
class QRValidationResult {
  final bool success;
  final String? error;
  final String? message;
  final DateTime timestamp;
  final String workerId;
  final String deviceHash;
  final String nonce;
  final AttendanceType attendanceType;
  final Map<String, dynamic> validations;
  final String? attendanceId;
  final bool? profileUpdated;
  final DateTime? processedAt;

  const QRValidationResult({
    required this.success,
    this.error,
    this.message,
    required this.timestamp,
    required this.workerId,
    required this.deviceHash,
    required this.nonce,
    required this.attendanceType,
    required this.validations,
    this.attendanceId,
    this.profileUpdated,
    this.processedAt,
  });

  factory QRValidationResult.fromJson(Map<String, dynamic> json) {
    return QRValidationResult(
      success: json['success'] as bool,
      error: json['error'] as String?,
      message: json['message'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      workerId: json['worker_id'] as String,
      deviceHash: json['device_hash'] as String,
      nonce: json['nonce'] as String,
      attendanceType: AttendanceType.fromString(json['attendance_type'] as String),
      validations: json['validations'] as Map<String, dynamic>,
      attendanceId: json['attendance_id'] as String?,
      profileUpdated: json['profile_updated'] as bool?,
      processedAt: json['processed_at'] != null
          ? DateTime.parse(json['processed_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'error': error,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'worker_id': workerId,
      'device_hash': deviceHash,
      'nonce': nonce,
      'attendance_type': attendanceType.value,
      'validations': validations,
      'attendance_id': attendanceId,
      'profile_updated': profileUpdated,
      'processed_at': processedAt?.toIso8601String(),
    };
  }
}

/// Attendance Statistics Model
class AttendanceStatistics {
  final DateRange period;
  final AttendanceMetrics attendance;
  final List<DailyAttendance> details;

  const AttendanceStatistics({
    required this.period,
    required this.attendance,
    required this.details,
  });

  factory AttendanceStatistics.fromJson(Map<String, dynamic> json) {
    final periodJson = json['period'] as Map<String, dynamic>;
    final attendanceJson = json['attendance'] as Map<String, dynamic>;
    final detailsList = json['details'] as List<dynamic>;

    return AttendanceStatistics(
      period: DateRange.fromJson(periodJson),
      attendance: AttendanceMetrics.fromJson(attendanceJson),
      details: detailsList
          .map((detail) => DailyAttendance.fromJson(detail as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Date Range Model
class DateRange {
  final DateTime startDate;
  final DateTime endDate;
  final int totalDays;

  const DateRange({
    required this.startDate,
    required this.endDate,
    required this.totalDays,
  });

  factory DateRange.fromJson(Map<String, dynamic> json) {
    return DateRange(
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      totalDays: json['total_days'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'total_days': totalDays,
    };
  }
}

/// Attendance Metrics Model
class AttendanceMetrics {
  final int presentDays;
  final double totalHours;
  final double averageHoursPerDay;

  const AttendanceMetrics({
    required this.presentDays,
    required this.totalHours,
    required this.averageHoursPerDay,
  });

  factory AttendanceMetrics.fromJson(Map<String, dynamic> json) {
    return AttendanceMetrics(
      presentDays: json['present_days'] as int,
      totalHours: (json['total_hours'] as num).toDouble(),
      averageHoursPerDay: (json['average_hours_per_day'] as num).toDouble(),
    );
  }
}

/// Daily Attendance Model
class DailyAttendance {
  final DateTime date;
  final double hoursWorked;

  const DailyAttendance({
    required this.date,
    required this.hoursWorked,
  });

  factory DailyAttendance.fromJson(Map<String, dynamic> json) {
    return DailyAttendance(
      date: DateTime.parse(json['date'] as String),
      hoursWorked: (json['hours_worked'] as num).toDouble(),
    );
  }
}

/// Time Period for Attendance Reports
enum AttendanceReportPeriod {
  daily,
  weekly,
  monthly,
}

extension AttendanceReportPeriodExtension on AttendanceReportPeriod {
  String get displayName {
    switch (this) {
      case AttendanceReportPeriod.daily:
        return 'يومي';
      case AttendanceReportPeriod.weekly:
        return 'أسبوعي';
      case AttendanceReportPeriod.monthly:
        return 'شهري';
    }
  }

  String get description {
    switch (this) {
      case AttendanceReportPeriod.daily:
        return 'تقرير اليوم الحالي';
      case AttendanceReportPeriod.weekly:
        return 'تقرير الأسبوع الحالي';
      case AttendanceReportPeriod.monthly:
        return 'تقرير الشهر الحالي';
    }
  }

  /// Get date range for the period
  DateRange getDateRange() {
    final now = DateTime.now();
    switch (this) {
      case AttendanceReportPeriod.daily:
        final startOfDay = DateTime(now.year, now.month, now.day);
        final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
        return DateRange(
          startDate: startOfDay,
          endDate: endOfDay,
          totalDays: 1,
        );
      case AttendanceReportPeriod.weekly:
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final startOfWeekDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        final endOfWeek = startOfWeekDay.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
        return DateRange(
          startDate: startOfWeekDay,
          endDate: endOfWeek,
          totalDays: 7,
        );
      case AttendanceReportPeriod.monthly:
        final startOfMonth = DateTime(now.year, now.month, 1);
        final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        final totalDays = endOfMonth.day;
        return DateRange(
          startDate: startOfMonth,
          endDate: endOfMonth,
          totalDays: totalDays,
        );
    }
  }
}

/// Attendance Status for Reports
enum AttendanceReportStatus {
  onTime,
  late,
  absent,
  earlyDeparture,
  missingCheckOut,
}

extension AttendanceReportStatusExtension on AttendanceReportStatus {
  String get displayName {
    switch (this) {
      case AttendanceReportStatus.onTime:
        return 'في الوقت المحدد';
      case AttendanceReportStatus.late:
        return 'متأخر';
      case AttendanceReportStatus.absent:
        return 'غائب';
      case AttendanceReportStatus.earlyDeparture:
        return 'انصراف مبكر';
      case AttendanceReportStatus.missingCheckOut:
        return 'لم يسجل الانصراف';
    }
  }

  Color get statusColor {
    switch (this) {
      case AttendanceReportStatus.onTime:
        return const Color(0xFF10B981); // Green
      case AttendanceReportStatus.late:
        return const Color(0xFFF59E0B); // Orange
      case AttendanceReportStatus.absent:
        return const Color(0xFFEF4444); // Red
      case AttendanceReportStatus.earlyDeparture:
        return const Color(0xFFF59E0B); // Orange
      case AttendanceReportStatus.missingCheckOut:
        return const Color(0xFFEF4444); // Red
    }
  }
}

/// Worker Attendance Report Data
class WorkerAttendanceReportData {
  final String workerId;
  final String workerName;
  final String? profileImageUrl;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final AttendanceReportStatus checkInStatus;
  final AttendanceReportStatus checkOutStatus;
  final double totalHoursWorked;
  final int attendanceDays;
  final int absenceDays;
  final int lateArrivals;
  final int earlyDepartures;
  final int lateMinutes;
  final int earlyMinutes;
  final DateTime reportDate;

  const WorkerAttendanceReportData({
    required this.workerId,
    required this.workerName,
    this.profileImageUrl,
    this.checkInTime,
    this.checkOutTime,
    required this.checkInStatus,
    required this.checkOutStatus,
    required this.totalHoursWorked,
    required this.attendanceDays,
    required this.absenceDays,
    required this.lateArrivals,
    required this.earlyDepartures,
    required this.lateMinutes,
    required this.earlyMinutes,
    required this.reportDate,
  });

  factory WorkerAttendanceReportData.fromJson(Map<String, dynamic> json) {
    return WorkerAttendanceReportData(
      workerId: json['worker_id'] as String? ?? '',
      workerName: json['worker_name'] as String? ?? '',
      profileImageUrl: json['profile_image_url'] as String?,
      checkInTime: json['check_in_time'] != null
          ? DateTime.parse(json['check_in_time'] as String)
          : null,
      checkOutTime: json['check_out_time'] != null
          ? DateTime.parse(json['check_out_time'] as String)
          : null,
      checkInStatus: AttendanceReportStatus.values.firstWhere(
        (e) => e.toString().split('.').last == (json['check_in_status'] as String? ?? 'absent'),
        orElse: () => AttendanceReportStatus.absent,
      ),
      checkOutStatus: AttendanceReportStatus.values.firstWhere(
        (e) => e.toString().split('.').last == (json['check_out_status'] as String? ?? 'missingCheckOut'),
        orElse: () => AttendanceReportStatus.missingCheckOut,
      ),
      totalHoursWorked: (json['total_hours_worked'] as num? ?? 0.0).toDouble(),
      attendanceDays: json['attendance_days'] as int? ?? 0,
      absenceDays: json['absence_days'] as int? ?? 0,
      lateArrivals: json['late_arrivals'] as int? ?? 0,
      earlyDepartures: json['early_departures'] as int? ?? 0,
      lateMinutes: json['late_minutes'] as int? ?? 0,
      earlyMinutes: json['early_minutes'] as int? ?? 0,
      reportDate: DateTime.parse(json['report_date'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'worker_id': workerId,
      'worker_name': workerName,
      'profile_image_url': profileImageUrl,
      'check_in_time': checkInTime?.toIso8601String(),
      'check_out_time': checkOutTime?.toIso8601String(),
      'check_in_status': checkInStatus.toString().split('.').last,
      'check_out_status': checkOutStatus.toString().split('.').last,
      'total_hours_worked': totalHoursWorked,
      'attendance_days': attendanceDays,
      'absence_days': absenceDays,
      'late_arrivals': lateArrivals,
      'early_departures': earlyDepartures,
      'late_minutes': lateMinutes,
      'early_minutes': earlyMinutes,
      'report_date': reportDate.toIso8601String(),
    };
  }
}

/// Attendance Settings Model
class AttendanceSettings {
  final TimeOfDay workStartTime;
  final TimeOfDay workEndTime;
  final int lateToleranceMinutes;
  final int earlyDepartureToleranceMinutes;
  final double requiredDailyHours;
  final List<int> workDays; // 1=Monday, 7=Sunday

  const AttendanceSettings({
    required this.workStartTime,
    required this.workEndTime,
    required this.lateToleranceMinutes,
    required this.earlyDepartureToleranceMinutes,
    required this.requiredDailyHours,
    required this.workDays,
  });

  factory AttendanceSettings.defaultSettings() {
    return const AttendanceSettings(
      workStartTime: TimeOfDay(hour: 9, minute: 0), // 9:00 AM
      workEndTime: TimeOfDay(hour: 17, minute: 0), // 5:00 PM
      lateToleranceMinutes: 15,
      earlyDepartureToleranceMinutes: 10,
      requiredDailyHours: 8.0,
      workDays: [1, 2, 3, 4, 5], // Monday to Friday
    );
  }

  factory AttendanceSettings.fromJson(Map<String, dynamic> json) {
    return AttendanceSettings(
      workStartTime: TimeOfDay(
        hour: json['work_start_hour'] as int? ?? 9,
        minute: json['work_start_minute'] as int? ?? 0,
      ),
      workEndTime: TimeOfDay(
        hour: json['work_end_hour'] as int? ?? 17,
        minute: json['work_end_minute'] as int? ?? 0,
      ),
      lateToleranceMinutes: json['late_tolerance_minutes'] as int? ?? 15,
      earlyDepartureToleranceMinutes: json['early_departure_tolerance_minutes'] as int? ?? 10,
      requiredDailyHours: (json['required_daily_hours'] as num? ?? 8.0).toDouble(),
      workDays: (json['work_days'] as List<dynamic>?)?.cast<int>() ?? [1, 2, 3, 4, 5],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'work_start_hour': workStartTime.hour,
      'work_start_minute': workStartTime.minute,
      'work_end_hour': workEndTime.hour,
      'work_end_minute': workEndTime.minute,
      'late_tolerance_minutes': lateToleranceMinutes,
      'early_departure_tolerance_minutes': earlyDepartureToleranceMinutes,
      'required_daily_hours': requiredDailyHours,
      'work_days': workDays,
    };
  }

  AttendanceSettings copyWith({
    TimeOfDay? workStartTime,
    TimeOfDay? workEndTime,
    int? lateToleranceMinutes,
    int? earlyDepartureToleranceMinutes,
    double? requiredDailyHours,
    List<int>? workDays,
  }) {
    return AttendanceSettings(
      workStartTime: workStartTime ?? this.workStartTime,
      workEndTime: workEndTime ?? this.workEndTime,
      lateToleranceMinutes: lateToleranceMinutes ?? this.lateToleranceMinutes,
      earlyDepartureToleranceMinutes: earlyDepartureToleranceMinutes ?? this.earlyDepartureToleranceMinutes,
      requiredDailyHours: requiredDailyHours ?? this.requiredDailyHours,
      workDays: workDays ?? this.workDays,
    );
  }

  /// Validate attendance settings
  String? validate() {
    // Validate work hours
    final startMinutes = workStartTime.hour * 60 + workStartTime.minute;
    final endMinutes = workEndTime.hour * 60 + workEndTime.minute;

    if (startMinutes >= endMinutes) {
      return 'وقت بداية العمل يجب أن يكون قبل وقت نهاية العمل';
    }

    // Validate tolerance minutes
    if (lateToleranceMinutes < 0 || lateToleranceMinutes > 120) {
      return 'فترة تسامح التأخير يجب أن تكون بين 0 و 120 دقيقة';
    }

    if (earlyDepartureToleranceMinutes < 0 || earlyDepartureToleranceMinutes > 120) {
      return 'فترة تسامح الانصراف المبكر يجب أن تكون بين 0 و 120 دقيقة';
    }

    // Validate required daily hours
    if (requiredDailyHours < 1.0 || requiredDailyHours > 24.0) {
      return 'ساعات العمل المطلوبة يومياً يجب أن تكون بين 1 و 24 ساعة';
    }

    // Validate work days
    if (workDays.isEmpty) {
      return 'يجب تحديد يوم واحد على الأقل للعمل';
    }

    if (workDays.any((day) => day < 1 || day > 7)) {
      return 'أيام العمل يجب أن تكون بين 1 (الاثنين) و 7 (الأحد)';
    }

    // Check for duplicate work days
    if (workDays.toSet().length != workDays.length) {
      return 'لا يمكن تكرار أيام العمل';
    }

    // Validate that work hours make sense with required daily hours
    final totalWorkMinutes = endMinutes - startMinutes;
    final totalWorkHours = totalWorkMinutes / 60.0;

    if (requiredDailyHours > totalWorkHours + 2.0) { // Allow 2 hours buffer for breaks
      return 'ساعات العمل المطلوبة أكبر من إجمالي ساعات العمل المحددة';
    }

    return null; // No validation errors
  }

  /// Check if settings are valid
  bool get isValid => validate() == null;

  /// Get work day names in Arabic
  List<String> get workDayNames {
    const dayNames = {
      1: 'الاثنين',
      2: 'الثلاثاء',
      3: 'الأربعاء',
      4: 'الخميس',
      5: 'الجمعة',
      6: 'السبت',
      7: 'الأحد',
    };
    return workDays.map((day) => dayNames[day] ?? '').toList();
  }

  /// Check if a given day is a work day
  bool isWorkDay(DateTime date) {
    return workDays.contains(date.weekday);
  }
}

/// Attendance Report Summary Statistics
class AttendanceReportSummary {
  final int totalWorkers;
  final int presentWorkers;
  final int absentWorkers;
  final double attendanceRate;
  final int totalLateArrivals;
  final int totalEarlyDepartures;
  final double averageWorkingHours;
  final AttendanceReportPeriod period;
  final DateRange dateRange;

  const AttendanceReportSummary({
    required this.totalWorkers,
    required this.presentWorkers,
    required this.absentWorkers,
    required this.attendanceRate,
    required this.totalLateArrivals,
    required this.totalEarlyDepartures,
    required this.averageWorkingHours,
    required this.period,
    required this.dateRange,
  });

  factory AttendanceReportSummary.fromJson(Map<String, dynamic> json) {
    return AttendanceReportSummary(
      totalWorkers: json['total_workers'] as int? ?? 0,
      presentWorkers: json['present_workers'] as int? ?? 0,
      absentWorkers: json['absent_workers'] as int? ?? 0,
      attendanceRate: (json['attendance_rate'] as num? ?? 0.0).toDouble(),
      totalLateArrivals: json['total_late_arrivals'] as int? ?? 0,
      totalEarlyDepartures: json['total_early_departures'] as int? ?? 0,
      averageWorkingHours: (json['average_working_hours'] as num? ?? 0.0).toDouble(),
      period: AttendanceReportPeriod.values.firstWhere(
        (e) => e.toString().split('.').last == (json['period'] as String? ?? 'daily'),
        orElse: () => AttendanceReportPeriod.daily,
      ),
      dateRange: DateRange.fromJson(json['date_range'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_workers': totalWorkers,
      'present_workers': presentWorkers,
      'absent_workers': absentWorkers,
      'attendance_rate': attendanceRate,
      'total_late_arrivals': totalLateArrivals,
      'total_early_departures': totalEarlyDepartures,
      'average_working_hours': averageWorkingHours,
      'period': period.toString().split('.').last,
      'date_range': dateRange.toJson(),
    };
  }

  /// Get formatted attendance rate as percentage
  String get formattedAttendanceRate {
    return '${(attendanceRate * 100).toStringAsFixed(1)}%';
  }

  /// Get formatted average working hours
  String get formattedAverageHours {
    final hours = averageWorkingHours.floor();
    final minutes = ((averageWorkingHours - hours) * 60).round();
    return '${hours}س ${minutes}د';
  }
}

/// نتيجة فحص توفر المصادقة البيومترية
class BiometricAvailabilityResult {
  final bool isAvailable;
  final String? errorMessage;
  final List<BiometricType> supportedTypes;

  const BiometricAvailabilityResult({
    required this.isAvailable,
    this.errorMessage,
    required this.supportedTypes,
  });

  /// الحصول على أنواع المصادقة المدعومة كنص
  String get supportedTypesText {
    if (supportedTypes.isEmpty) return 'لا توجد أنواع مدعومة';

    List<String> typeNames = supportedTypes.map((type) {
      switch (type) {
        case BiometricType.face:
          return 'التعرف على الوجه';
        case BiometricType.fingerprint:
          return 'بصمة الإصبع';
        case BiometricType.iris:
          return 'بصمة العين';
        case BiometricType.weak:
          return 'مصادقة ضعيفة';
        case BiometricType.strong:
          return 'مصادقة قوية';
        default:
          return 'نوع غير معروف';
      }
    }).toList();

    return typeNames.join(', ');
  }
}

/// نتيجة المصادقة البيومترية
class BiometricAuthResult {
  final bool isAuthenticated;
  final String? errorMessage;
  final BiometricType? usedBiometricType;

  const BiometricAuthResult({
    required this.isAuthenticated,
    this.errorMessage,
    this.usedBiometricType,
  });
}

/// أنواع أخطاء الحضور البيومتري
enum BiometricAttendanceErrorType {
  locationValidationFailed,
  biometricAuthFailed,
  deviceHashGenerationFailed,
  databaseError,
  unknownError,
}

/// نتيجة معالجة الحضور البيومتري
class BiometricAttendanceResult {
  final bool success;
  final String? errorMessage;
  final BiometricAttendanceErrorType? errorType;
  final String? attendanceId;
  final LocationValidationResult? locationValidation;
  final AttendanceLocationInfo? locationInfo;

  const BiometricAttendanceResult({
    required this.success,
    this.errorMessage,
    this.errorType,
    this.attendanceId,
    this.locationValidation,
    this.locationInfo,
  });

  /// الحصول على رسالة الخطأ المترجمة
  String get localizedErrorMessage {
    if (errorMessage != null) return errorMessage!;

    switch (errorType) {
      case BiometricAttendanceErrorType.locationValidationFailed:
        return 'فشل في التحقق من الموقع';
      case BiometricAttendanceErrorType.biometricAuthFailed:
        return 'فشلت المصادقة البيومترية';
      case BiometricAttendanceErrorType.deviceHashGenerationFailed:
        return 'خطأ في تحديد هوية الجهاز';
      case BiometricAttendanceErrorType.databaseError:
        return 'خطأ في قاعدة البيانات';
      case BiometricAttendanceErrorType.unknownError:
      default:
        return 'خطأ غير معروف';
    }
  }
}

/// نتيجة التحقق من متطلبات الحضور
class AttendancePrerequisiteResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
  final bool canProceed;
  final LocationValidationResult? locationValidation;
  final BiometricAvailabilityResult? biometricAvailability;

  const AttendancePrerequisiteResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
    required this.canProceed,
    this.locationValidation,
    this.biometricAvailability,
  });

  /// الحصول على رسالة موجزة عن الحالة
  String get statusMessage {
    if (isValid) {
      return 'جميع المتطلبات متوفرة';
    } else if (errors.isNotEmpty) {
      return errors.first;
    } else {
      return 'متطلبات غير مكتملة';
    }
  }

  /// هل يمكن المتابعة مع تحذيرات
  bool get canProceedWithWarnings {
    return errors.isEmpty;
  }
}
