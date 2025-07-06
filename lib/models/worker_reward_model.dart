enum RewardType { monetary, bonus, commission, penalty, adjustment, overtime }
enum RewardStatus { active, pending, cancelled }

class WorkerRewardModel {

  const WorkerRewardModel({
    required this.id,
    required this.workerId,
    required this.amount,
    required this.rewardType,
    this.description,
    this.awardedBy,
    required this.awardedAt,
    this.relatedTaskId,
    required this.status,
    this.notes,
    this.workerName,
    this.awardedByName,
    this.taskTitle,
  });

  factory WorkerRewardModel.fromJson(Map<String, dynamic> json) {
    return WorkerRewardModel(
      id: json['id'] as String? ?? '',
      workerId: json['worker_id'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      rewardType: _parseRewardType(json['reward_type'] as String?),
      description: json['description'] as String?,
      awardedBy: json['awarded_by'] as String?,
      awardedAt: DateTime.parse(json['awarded_at'] as String? ?? DateTime.now().toIso8601String()),
      relatedTaskId: json['related_task_id'] as String?,
      status: _parseStatus(json['status'] as String?),
      notes: json['notes'] as String?,
      workerName: json['worker_name'] as String?,
      awardedByName: json['awarded_by_name'] as String?,
      taskTitle: json['task_title'] as String?,
    );
  }
  final String id;
  final String workerId;
  final double amount;
  final RewardType rewardType;
  final String? description;
  final String? awardedBy;
  final DateTime awardedAt;
  final String? relatedTaskId;
  final RewardStatus status;
  final String? notes;

  // Additional fields for display
  final String? workerName;
  final String? awardedByName;
  final String? taskTitle;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'worker_id': workerId,
      'amount': amount,
      'reward_type': _rewardTypeToString(rewardType),
      'description': description,
      'awarded_by': awardedBy,
      'awarded_at': awardedAt.toIso8601String(),
      'related_task_id': relatedTaskId,
      'status': _statusToString(status),
      'notes': notes,
    };
  }

  static RewardType _parseRewardType(String? type) {
    switch (type?.toLowerCase()) {
      case 'monetary':
        return RewardType.monetary;
      case 'bonus':
        return RewardType.bonus;
      case 'commission':
        return RewardType.commission;
      case 'penalty':
        return RewardType.penalty;
      case 'adjustment':
        return RewardType.adjustment;
      case 'overtime':
        return RewardType.overtime;
      default:
        return RewardType.monetary;
    }
  }

  static String _rewardTypeToString(RewardType type) {
    switch (type) {
      case RewardType.monetary:
        return 'monetary';
      case RewardType.bonus:
        return 'bonus';
      case RewardType.commission:
        return 'commission';
      case RewardType.penalty:
        return 'penalty';
      case RewardType.adjustment:
        return 'adjustment';
      case RewardType.overtime:
        return 'overtime';
    }
  }

  static RewardStatus _parseStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return RewardStatus.active;
      case 'pending':
        return RewardStatus.pending;
      case 'cancelled':
        return RewardStatus.cancelled;
      default:
        return RewardStatus.active;
    }
  }

  static String _statusToString(RewardStatus status) {
    switch (status) {
      case RewardStatus.active:
        return 'active';
      case RewardStatus.pending:
        return 'pending';
      case RewardStatus.cancelled:
        return 'cancelled';
    }
  }

  String get rewardTypeDisplayName {
    switch (rewardType) {
      case RewardType.monetary:
        return 'مكافأة مالية';
      case RewardType.bonus:
        return 'علاوة';
      case RewardType.commission:
        return 'عمولة';
      case RewardType.penalty:
        return 'خصم';
      case RewardType.adjustment:
        return 'تعديل';
      case RewardType.overtime:
        return 'ساعات إضافية';
    }
  }

  String get statusDisplayName {
    switch (status) {
      case RewardStatus.active:
        return 'نشطة';
      case RewardStatus.pending:
        return 'معلقة';
      case RewardStatus.cancelled:
        return 'ملغية';
    }
  }

  WorkerRewardModel copyWith({
    String? id,
    String? workerId,
    double? amount,
    RewardType? rewardType,
    String? description,
    String? awardedBy,
    DateTime? awardedAt,
    String? relatedTaskId,
    RewardStatus? status,
    String? notes,
    String? workerName,
    String? awardedByName,
    String? taskTitle,
  }) {
    return WorkerRewardModel(
      id: id ?? this.id,
      workerId: workerId ?? this.workerId,
      amount: amount ?? this.amount,
      rewardType: rewardType ?? this.rewardType,
      description: description ?? this.description,
      awardedBy: awardedBy ?? this.awardedBy,
      awardedAt: awardedAt ?? this.awardedAt,
      relatedTaskId: relatedTaskId ?? this.relatedTaskId,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      workerName: workerName ?? this.workerName,
      awardedByName: awardedByName ?? this.awardedByName,
      taskTitle: taskTitle ?? this.taskTitle,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WorkerRewardModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'WorkerRewardModel(id: $id, workerId: $workerId, amount: $amount, type: $rewardType)';
  }
}

class WorkerRewardBalanceModel {

  const WorkerRewardBalanceModel({
    required this.workerId,
    required this.currentBalance,
    required this.totalEarned,
    required this.totalWithdrawn,
    required this.lastUpdated,
    this.workerName,
  });

  factory WorkerRewardBalanceModel.fromJson(Map<String, dynamic> json) {
    return WorkerRewardBalanceModel(
      workerId: (json['worker_id'] as String?) ?? '',
      currentBalance: (json['current_balance'] as num?)?.toDouble() ?? 0.0,
      totalEarned: (json['total_earned'] as num?)?.toDouble() ?? 0.0,
      totalWithdrawn: (json['total_withdrawn'] as num?)?.toDouble() ?? 0.0,
      lastUpdated: DateTime.parse((json['last_updated'] as String?) ?? DateTime.now().toIso8601String()),
      workerName: json['worker_name'] as String?,
    );
  }
  final String workerId;
  final double currentBalance;
  final double totalEarned;
  final double totalWithdrawn;
  final DateTime lastUpdated;

  // Additional fields for display
  final String? workerName;

  Map<String, dynamic> toJson() {
    return {
      'worker_id': workerId,
      'current_balance': currentBalance,
      'total_earned': totalEarned,
      'total_withdrawn': totalWithdrawn,
      'last_updated': lastUpdated.toIso8601String(),
    };
  }

  WorkerRewardBalanceModel copyWith({
    String? workerId,
    double? currentBalance,
    double? totalEarned,
    double? totalWithdrawn,
    DateTime? lastUpdated,
    String? workerName,
  }) {
    return WorkerRewardBalanceModel(
      workerId: workerId ?? this.workerId,
      currentBalance: currentBalance ?? this.currentBalance,
      totalEarned: totalEarned ?? this.totalEarned,
      totalWithdrawn: totalWithdrawn ?? this.totalWithdrawn,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      workerName: workerName ?? this.workerName,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WorkerRewardBalanceModel && other.workerId == workerId;
  }

  @override
  int get hashCode => workerId.hashCode;

  @override
  String toString() {
    return 'WorkerRewardBalanceModel(workerId: $workerId, balance: $currentBalance)';
  }
}
