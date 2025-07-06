import 'package:smartbiztracker_new/utils/uuid_validator.dart';

class ErrorReport {

  ErrorReport({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.title,
    required this.description,
    required this.location,
    required this.priority,
    required this.status,
    this.screenshotUrl,
    required this.createdAt,
    this.resolvedAt,
    this.adminNotes,
    this.adminResponse,
    this.adminResponseDate,
    this.assignedTo,
  });

  factory ErrorReport.fromJson(Map<String, dynamic> json) {
    return ErrorReport(
      id: (json['id'] as String?) ?? '',
      customerId: (json['customer_id'] as String?) ?? '',
      customerName: (json['customer_name'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      location: (json['location'] as String?) ?? '',
      priority: (json['priority'] as String?) ?? 'medium',
      status: (json['status'] as String?) ?? 'pending',
      screenshotUrl: json['screenshot_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'] as String)
          : null,
      adminNotes: json['admin_notes'] as String?,
      adminResponse: json['admin_response'] as String?,
      adminResponseDate: json['admin_response_date'] != null
          ? DateTime.parse(json['admin_response_date'] as String)
          : null,
      assignedTo: json['assigned_to'] as String?,
    );
  }
  final String id;
  final String customerId;
  final String customerName;
  final String title;
  final String description;
  final String location;
  final String priority;
  final String status;
  final String? screenshotUrl;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? adminNotes;
  final String? adminResponse;
  final DateTime? adminResponseDate;
  final String? assignedTo;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'customer_id': customerId,
      'customer_name': customerName,
      'title': title,
      'description': description,
      'location': location,
      'priority': priority,
      'status': status,
      'screenshot_url': screenshotUrl,
      'created_at': createdAt.toIso8601String(),
      'resolved_at': resolvedAt?.toIso8601String(),
      'admin_notes': adminNotes,
      'admin_response': adminResponse,
      'admin_response_date': adminResponseDate?.toIso8601String(),
      'assigned_to': assignedTo,
    };

    // Only include 'id' if it's a valid UUID (not empty)
    UuidValidator.addUuidToJson(json, 'id', id);

    return json;
  }

  ErrorReport copyWith({
    String? id,
    String? customerId,
    String? customerName,
    String? title,
    String? description,
    String? location,
    String? priority,
    String? status,
    String? screenshotUrl,
    DateTime? createdAt,
    DateTime? resolvedAt,
    String? adminNotes,
    String? adminResponse,
    DateTime? adminResponseDate,
    String? assignedTo,
  }) {
    return ErrorReport(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      screenshotUrl: screenshotUrl ?? this.screenshotUrl,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      adminNotes: adminNotes ?? this.adminNotes,
      adminResponse: adminResponse ?? this.adminResponse,
      adminResponseDate: adminResponseDate ?? this.adminResponseDate,
      assignedTo: assignedTo ?? this.assignedTo,
    );
  }

  @override
  String toString() {
    return 'ErrorReport(id: $id, title: $title, status: $status, priority: $priority)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ErrorReport && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// Enum for error report status
enum ErrorReportStatus {
  pending,
  resolved,
  rejected,
  processing,
}

// Enum for error report priority
enum ErrorReportPriority {
  low,
  medium,
  high,
}

// Extension methods for enums
extension ErrorReportStatusExtension on ErrorReportStatus {
  String get value {
    switch (this) {
      case ErrorReportStatus.pending:
        return 'pending';
      case ErrorReportStatus.resolved:
        return 'resolved';
      case ErrorReportStatus.rejected:
        return 'rejected';
      case ErrorReportStatus.processing:
        return 'processing';
    }
  }

  String get arabicText {
    switch (this) {
      case ErrorReportStatus.pending:
        return 'قيد المراجعة';
      case ErrorReportStatus.resolved:
        return 'تم الحل';
      case ErrorReportStatus.rejected:
        return 'مرفوض';
      case ErrorReportStatus.processing:
        return 'قيد المعالجة';
    }
  }
}

extension ErrorReportPriorityExtension on ErrorReportPriority {
  String get value {
    switch (this) {
      case ErrorReportPriority.low:
        return 'low';
      case ErrorReportPriority.medium:
        return 'medium';
      case ErrorReportPriority.high:
        return 'high';
    }
  }

  String get arabicText {
    switch (this) {
      case ErrorReportPriority.low:
        return 'منخفض';
      case ErrorReportPriority.medium:
        return 'متوسط';
      case ErrorReportPriority.high:
        return 'عالي';
    }
  }
}
