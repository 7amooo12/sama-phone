enum TaskPriority { low, medium, high, urgent }
enum TaskStatus { assigned, inProgress, completed, approved, rejected }

class WorkerTaskModel {

  const WorkerTaskModel({
    required this.id,
    required this.title,
    this.description,
    required this.assignedTo,
    this.assignedBy,
    required this.priority,
    required this.status,
    this.dueDate,
    required this.createdAt,
    required this.updatedAt,
    this.estimatedHours,
    this.category,
    this.location,
    this.requirements,
    this.isActive = true,
    this.assignedToName,
    this.assignedByName,
    this.orderId,
  });

  factory WorkerTaskModel.fromJson(Map<String, dynamic> json) {
    return WorkerTaskModel(
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      description: json['description'] as String?,
      assignedTo: (json['assigned_to'] as String?) ?? '',
      assignedBy: json['assigned_by'] as String?,
      priority: _parsePriority(json['priority'] as String?),
      status: _parseStatus(json['status'] as String?),
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date'] as String) : null,
      createdAt: DateTime.parse((json['created_at'] as String?) ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse((json['updated_at'] as String?) ?? DateTime.now().toIso8601String()),
      estimatedHours: (json['estimated_hours'] as num?)?.toInt(),
      category: json['category'] as String?,
      location: json['location'] as String?,
      requirements: json['requirements'] as String?,
      isActive: (json['is_active'] as bool?) ?? true,
      assignedToName: json['assigned_to_name'] as String?,
      assignedByName: json['assigned_by_name'] as String?,
      orderId: json['order_id'] as String?,
    );
  }
  final String id;
  final String title;
  final String? description;
  final String assignedTo;
  final String? assignedBy;
  final TaskPriority priority;
  final TaskStatus status;
  final DateTime? dueDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? estimatedHours;
  final String? category;
  final String? location;
  final String? requirements;
  final bool isActive;

  // Additional fields for display
  final String? assignedToName;
  final String? assignedByName;
  final String? orderId;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'assigned_to': assignedTo,
      'assigned_by': assignedBy,
      'priority': priority.name,
      'status': _statusToString(status),
      'due_date': dueDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'estimated_hours': estimatedHours,
      'category': category,
      'location': location,
      'requirements': requirements,
      'is_active': isActive,
      'order_id': orderId,
    };
  }

  static TaskPriority _parsePriority(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'low':
        return TaskPriority.low;
      case 'medium':
        return TaskPriority.medium;
      case 'high':
        return TaskPriority.high;
      case 'urgent':
        return TaskPriority.urgent;
      default:
        return TaskPriority.medium;
    }
  }

  static TaskStatus _parseStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'assigned':
        return TaskStatus.assigned;
      case 'in_progress':
        return TaskStatus.inProgress;
      case 'completed':
        return TaskStatus.completed;
      case 'approved':
        return TaskStatus.approved;
      case 'rejected':
        return TaskStatus.rejected;
      default:
        return TaskStatus.assigned;
    }
  }

  static String _statusToString(TaskStatus status) {
    switch (status) {
      case TaskStatus.assigned:
        return 'assigned';
      case TaskStatus.inProgress:
        return 'in_progress';
      case TaskStatus.completed:
        return 'completed';
      case TaskStatus.approved:
        return 'approved';
      case TaskStatus.rejected:
        return 'rejected';
    }
  }

  String get priorityDisplayName {
    switch (priority) {
      case TaskPriority.low:
        return 'منخفضة';
      case TaskPriority.medium:
        return 'متوسطة';
      case TaskPriority.high:
        return 'عالية';
      case TaskPriority.urgent:
        return 'عاجلة';
    }
  }

  String get statusDisplayName {
    switch (status) {
      case TaskStatus.assigned:
        return 'مسندة';
      case TaskStatus.inProgress:
        return 'قيد التنفيذ';
      case TaskStatus.completed:
        return 'مكتملة';
      case TaskStatus.approved:
        return 'معتمدة';
      case TaskStatus.rejected:
        return 'مرفوضة';
    }
  }

  WorkerTaskModel copyWith({
    String? id,
    String? title,
    String? description,
    String? assignedTo,
    String? assignedBy,
    TaskPriority? priority,
    TaskStatus? status,
    DateTime? dueDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? estimatedHours,
    String? category,
    String? location,
    String? requirements,
    bool? isActive,
    String? assignedToName,
    String? assignedByName,
    String? orderId,
  }) {
    return WorkerTaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedBy: assignedBy ?? this.assignedBy,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      estimatedHours: estimatedHours ?? this.estimatedHours,
      category: category ?? this.category,
      location: location ?? this.location,
      requirements: requirements ?? this.requirements,
      isActive: isActive ?? this.isActive,
      assignedToName: assignedToName ?? this.assignedToName,
      assignedByName: assignedByName ?? this.assignedByName,
      orderId: orderId ?? this.orderId,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WorkerTaskModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'WorkerTaskModel(id: $id, title: $title, status: $status, priority: $priority)';
  }
}
