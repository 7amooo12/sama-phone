import 'package:cloud_firestore/cloud_firestore.dart';

class FaultModel {
  final String id;
  final String title;
  final String description;
  final String status;
  final String assignedTo;
  final String reportedBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String priority;
  final List<String> attachments;
  final bool isResolved;
  final String category;
  final String location;
  final Map<String, dynamic>? metadata;
  final String? reporterId;

  // Add getters for compatibility
  String get itemName => title;
  String get clientName => metadata?['clientName']?.toString() ?? '';
  int get quantity => metadata?['quantity'] as int? ?? 0;
  String get faultType => category;
  String get details => description;

  FaultModel({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.assignedTo,
    required this.reportedBy,
    required this.createdAt,
    this.updatedAt,
    required this.priority,
    required this.attachments,
    required this.isResolved,
    required this.category,
    required this.location,
    this.metadata,
    this.reporterId,
  });

  factory FaultModel.fromJson(Map<String, dynamic> json) {
    return FaultModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      status: json['status'] as String,
      assignedTo: json['assigned_to'] as String,
      reportedBy: json['reported_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
      priority: json['priority'] as String,
      attachments: List<String>.from(json['attachments'] as List),
      isResolved: json['is_resolved'] as bool,
      category: json['category'] as String,
      location: json['location'] as String,
      metadata: json['metadata'] as Map<String, dynamic>?,
      reporterId: json['reporter_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'status': status,
      'assigned_to': assignedTo,
      'reported_by': reportedBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'priority': priority,
      'attachments': attachments,
      'is_resolved': isResolved,
      'category': category,
      'location': location,
      'metadata': metadata,
      'reporter_id': reporterId,
    };
  }

  FaultModel copyWith({
    String? id,
    String? title,
    String? description,
    String? status,
    String? assignedTo,
    String? reportedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? priority,
    List<String>? attachments,
    bool? isResolved,
    String? category,
    String? location,
    Map<String, dynamic>? metadata,
    String? reporterId,
  }) {
    return FaultModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      assignedTo: assignedTo ?? this.assignedTo,
      reportedBy: reportedBy ?? this.reportedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      priority: priority ?? this.priority,
      attachments: attachments ?? this.attachments,
      isResolved: isResolved ?? this.isResolved,
      category: category ?? this.category,
      location: location ?? this.location,
      metadata: metadata ?? this.metadata,
      reporterId: reporterId ?? this.reporterId,
    );
  }
}

class FaultStatus {
  static const String newStatus = 'NEW';
  static const String inProgress = 'IN_PROGRESS';
  static const String resolved = 'RESOLVED';
  static const String closed = 'CLOSED';

  static const List<String> values = [newStatus, inProgress, resolved, closed];
}

class FaultPriority {
  static const String low = 'LOW';
  static const String medium = 'MEDIUM';
  static const String high = 'HIGH';
  static const String critical = 'CRITICAL';

  static const List<String> values = [low, medium, high, critical];
}

class FaultCategory {
  static const String machinery = 'MACHINERY';
  static const String electrical = 'ELECTRICAL';
  static const String plumbing = 'PLUMBING';
  static const String structural = 'STRUCTURAL';
  static const String safety = 'SAFETY';
  static const String other = 'OTHER';

  static const List<String> values = [
    machinery,
    electrical,
    plumbing,
    structural,
    safety,
    other
  ];
}
