enum SubmissionStatus { submitted, approved, rejected, needsRevision }

class TaskSubmissionModel {

  const TaskSubmissionModel({
    required this.id,
    required this.taskId,
    required this.workerId,
    required this.progressReport,
    required this.completionPercentage,
    required this.status,
    required this.submittedAt,
    this.approvedAt,
    this.approvedBy,
    this.hoursWorked,
    this.attachments = const [],
    this.notes,
    this.isFinalSubmission = false,
    this.workerName,
    this.approvedByName,
    this.taskTitle,
  });

  factory TaskSubmissionModel.fromJson(Map<String, dynamic> json) {
    return TaskSubmissionModel(
      id: json['id'] as String? ?? '',
      taskId: json['task_id'] as String? ?? '',
      workerId: json['worker_id'] as String? ?? '',
      progressReport: json['progress_report'] as String? ?? '',
      completionPercentage: (json['completion_percentage'] as num?)?.toInt() ?? 0,
      status: _parseStatus(json['status'] as String?),
      submittedAt: DateTime.parse(json['submitted_at'] as String? ?? DateTime.now().toIso8601String()),
      approvedAt: json['approved_at'] != null ? DateTime.parse(json['approved_at'] as String) : null,
      approvedBy: json['approved_by'] as String?,
      hoursWorked: (json['hours_worked'] as num?)?.toDouble(),
      attachments: _parseAttachments(json['attachments']),
      notes: json['notes'] as String?,
      isFinalSubmission: json['is_final_submission'] as bool? ?? false,
      workerName: json['worker_name'] as String?,
      approvedByName: json['approved_by_name'] as String?,
      taskTitle: json['task_title'] as String?,
    );
  }
  final String id;
  final String taskId;
  final String workerId;
  final String progressReport;
  final int completionPercentage;
  final SubmissionStatus status;
  final DateTime submittedAt;
  final DateTime? approvedAt;
  final String? approvedBy;
  final double? hoursWorked;
  final List<String> attachments;
  final String? notes;
  final bool isFinalSubmission;

  // Additional fields for display
  final String? workerName;
  final String? approvedByName;
  final String? taskTitle;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'task_id': taskId,
      'worker_id': workerId,
      'progress_report': progressReport,
      'completion_percentage': completionPercentage,
      'status': _statusToString(status),
      'submitted_at': submittedAt.toIso8601String(),
      'approved_at': approvedAt?.toIso8601String(),
      'approved_by': approvedBy,
      'hours_worked': hoursWorked,
      'attachments': attachments,
      'notes': notes,
      'is_final_submission': isFinalSubmission,
    };
  }

  static SubmissionStatus _parseStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'submitted':
        return SubmissionStatus.submitted;
      case 'approved':
        return SubmissionStatus.approved;
      case 'rejected':
        return SubmissionStatus.rejected;
      case 'needs_revision':
        return SubmissionStatus.needsRevision;
      default:
        return SubmissionStatus.submitted;
    }
  }

  static String _statusToString(SubmissionStatus status) {
    switch (status) {
      case SubmissionStatus.submitted:
        return 'submitted';
      case SubmissionStatus.approved:
        return 'approved';
      case SubmissionStatus.rejected:
        return 'rejected';
      case SubmissionStatus.needsRevision:
        return 'needs_revision';
    }
  }

  static List<String> _parseAttachments(dynamic attachments) {
    if (attachments == null) return [];
    if (attachments is List) {
      return attachments.map((e) => e.toString()).toList();
    }
    return [];
  }

  String get statusDisplayName {
    switch (status) {
      case SubmissionStatus.submitted:
        return 'مرسلة';
      case SubmissionStatus.approved:
        return 'معتمدة';
      case SubmissionStatus.rejected:
        return 'مرفوضة';
      case SubmissionStatus.needsRevision:
        return 'تحتاج مراجعة';
    }
  }

  TaskSubmissionModel copyWith({
    String? id,
    String? taskId,
    String? workerId,
    String? progressReport,
    int? completionPercentage,
    SubmissionStatus? status,
    DateTime? submittedAt,
    DateTime? approvedAt,
    String? approvedBy,
    double? hoursWorked,
    List<String>? attachments,
    String? notes,
    bool? isFinalSubmission,
    String? workerName,
    String? approvedByName,
    String? taskTitle,
  }) {
    return TaskSubmissionModel(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      workerId: workerId ?? this.workerId,
      progressReport: progressReport ?? this.progressReport,
      completionPercentage: completionPercentage ?? this.completionPercentage,
      status: status ?? this.status,
      submittedAt: submittedAt ?? this.submittedAt,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      hoursWorked: hoursWorked ?? this.hoursWorked,
      attachments: attachments ?? this.attachments,
      notes: notes ?? this.notes,
      isFinalSubmission: isFinalSubmission ?? this.isFinalSubmission,
      workerName: workerName ?? this.workerName,
      approvedByName: approvedByName ?? this.approvedByName,
      taskTitle: taskTitle ?? this.taskTitle,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TaskSubmissionModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'TaskSubmissionModel(id: $id, taskId: $taskId, status: $status, completion: $completionPercentage%)';
  }
}
