enum FeedbackType { comment, approval, rejection, revisionRequest }

class TaskFeedbackModel {

  const TaskFeedbackModel({
    required this.id,
    required this.submissionId,
    required this.adminId,
    required this.feedbackText,
    required this.feedbackType,
    required this.createdAt,
    required this.isRead,
    this.adminName,
    this.taskTitle,
    this.workerName,
  });

  factory TaskFeedbackModel.fromJson(Map<String, dynamic> json) {
    return TaskFeedbackModel(
      id: json['id'] as String? ?? '',
      submissionId: json['submission_id'] as String? ?? '',
      adminId: json['admin_id'] as String? ?? '',
      feedbackText: json['feedback_text'] as String? ?? '',
      feedbackType: _parseFeedbackType(json['feedback_type'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String? ?? DateTime.now().toIso8601String()),
      isRead: json['is_read'] as bool? ?? false,
      adminName: json['admin_name'] as String?,
      taskTitle: json['task_title'] as String?,
      workerName: json['worker_name'] as String?,
    );
  }
  final String id;
  final String submissionId;
  final String adminId;
  final String feedbackText;
  final FeedbackType feedbackType;
  final DateTime createdAt;
  final bool isRead;

  // Additional fields for display
  final String? adminName;
  final String? taskTitle;
  final String? workerName;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'submission_id': submissionId,
      'admin_id': adminId,
      'feedback_text': feedbackText,
      'feedback_type': _feedbackTypeToString(feedbackType),
      'created_at': createdAt.toIso8601String(),
      'is_read': isRead,
    };
  }

  static FeedbackType _parseFeedbackType(String? type) {
    switch (type?.toLowerCase()) {
      case 'comment':
        return FeedbackType.comment;
      case 'approval':
        return FeedbackType.approval;
      case 'rejection':
        return FeedbackType.rejection;
      case 'revision_request':
        return FeedbackType.revisionRequest;
      default:
        return FeedbackType.comment;
    }
  }

  static String _feedbackTypeToString(FeedbackType type) {
    switch (type) {
      case FeedbackType.comment:
        return 'comment';
      case FeedbackType.approval:
        return 'approval';
      case FeedbackType.rejection:
        return 'rejection';
      case FeedbackType.revisionRequest:
        return 'revision_request';
    }
  }

  String get feedbackTypeDisplayName {
    switch (feedbackType) {
      case FeedbackType.comment:
        return 'تعليق';
      case FeedbackType.approval:
        return 'موافقة';
      case FeedbackType.rejection:
        return 'رفض';
      case FeedbackType.revisionRequest:
        return 'طلب مراجعة';
    }
  }

  TaskFeedbackModel copyWith({
    String? id,
    String? submissionId,
    String? adminId,
    String? feedbackText,
    FeedbackType? feedbackType,
    DateTime? createdAt,
    bool? isRead,
    String? adminName,
    String? taskTitle,
    String? workerName,
  }) {
    return TaskFeedbackModel(
      id: id ?? this.id,
      submissionId: submissionId ?? this.submissionId,
      adminId: adminId ?? this.adminId,
      feedbackText: feedbackText ?? this.feedbackText,
      feedbackType: feedbackType ?? this.feedbackType,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      adminName: adminName ?? this.adminName,
      taskTitle: taskTitle ?? this.taskTitle,
      workerName: workerName ?? this.workerName,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TaskFeedbackModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'TaskFeedbackModel(id: $id, type: $feedbackType, isRead: $isRead)';
  }
}
