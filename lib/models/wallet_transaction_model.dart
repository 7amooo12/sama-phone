/// Transaction type enumeration
enum TransactionType {
  credit,
  debit,
  reward,
  salary,
  payment,
  refund,
  bonus,
  penalty,
  transfer,
}

/// Transaction status enumeration
enum TransactionStatus {
  pending,
  completed,
  failed,
  cancelled,
}

/// Reference type enumeration
enum ReferenceType {
  order,
  task,
  reward,
  salary,
  manual,
  transfer,
  adminAdjustment,
}

/// Wallet transaction model
class WalletTransactionModel {

  const WalletTransactionModel({
    required this.id,
    required this.walletId,
    required this.userId,
    required this.transactionType,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.description,
    this.referenceId,
    this.referenceType,
    this.status = TransactionStatus.completed,
    required this.createdAt,
    required this.createdBy,
    this.approvedBy,
    this.approvedAt,
    this.metadata,
    this.userName,
    this.createdByName,
    this.approvedByName,
  });

  factory WalletTransactionModel.fromJson(Map<String, dynamic> json) {
    return WalletTransactionModel.fromDatabase(json);
  }

  /// Create a transaction model from database response with enhanced client information
  factory WalletTransactionModel.fromDatabaseWithClientInfo(Map<String, dynamic> data) {
    return WalletTransactionModel(
      id: data['id'] as String,
      walletId: data['wallet_id'] as String,
      userId: data['user_id'] as String,
      transactionType: TransactionType.values.firstWhere(
        (type) => type.toString().split('.').last == data['transaction_type'],
      ),
      amount: (data['amount'] as num).toDouble(),
      balanceBefore: (data['balance_before'] as num).toDouble(),
      balanceAfter: (data['balance_after'] as num).toDouble(),
      description: data['description'] as String,
      referenceId: data['reference_id'] as String?,
      referenceType: data['reference_type'] != null
          ? ReferenceType.values.firstWhere(
              (type) => type.toString().split('.').last == data['reference_type'],
            )
          : null,
      status: TransactionStatus.values.firstWhere(
        (status) => status.toString().split('.').last == data['status'],
        orElse: () => TransactionStatus.completed,
      ),
      createdAt: DateTime.parse(data['created_at'] as String),
      createdBy: data['created_by'] as String,
      approvedBy: data['approved_by'] as String?,
      approvedAt: data['approved_at'] != null
          ? DateTime.parse(data['approved_at'] as String)
          : null,
      metadata: data['metadata'] as Map<String, dynamic>?,
      // Enhanced client information
      userName: data['client']?['name'] as String? ?? data['user_name'] as String?,
      createdByName: data['created_by_name'] as String?,
      approvedByName: data['approved_by_name'] as String?,
    );
  }

  /// Create a transaction model from database response with enhanced null safety
  factory WalletTransactionModel.fromDatabase(Map<String, dynamic> data) {
    try {
      // Validate required fields first
      final id = data['id']?.toString();
      final walletId = data['wallet_id']?.toString();
      final userId = data['user_id']?.toString();
      final createdBy = data['created_by']?.toString();
      final description = data['description']?.toString();

      if (id == null || id.isEmpty) {
        throw Exception('Transaction ID is null or empty');
      }
      if (walletId == null || walletId.isEmpty) {
        throw Exception('Wallet ID is null or empty');
      }
      if (userId == null || userId.isEmpty) {
        throw Exception('User ID is null or empty');
      }
      if (createdBy == null || createdBy.isEmpty) {
        throw Exception('Created by is null or empty');
      }

      // Parse transaction type with enhanced error handling
      TransactionType transactionType = TransactionType.credit;
      try {
        final typeString = data['transaction_type']?.toString();
        if (typeString != null && typeString.isNotEmpty) {
          transactionType = TransactionType.values.firstWhere(
            (type) => type.toString().split('.').last == typeString,
            orElse: () => TransactionType.credit,
          );
        }
      } catch (e) {
        transactionType = TransactionType.credit; // Default to credit
      }

      // Parse reference type with enhanced error handling
      ReferenceType? referenceType;
      try {
        final refTypeString = data['reference_type']?.toString();
        if (refTypeString != null && refTypeString.isNotEmpty) {
          referenceType = ReferenceType.values.firstWhere(
            (type) => type.toString().split('.').last == refTypeString,
            orElse: () => ReferenceType.manual,
          );
        }
      } catch (e) {
        referenceType = null; // Allow null for reference type
      }

      // Parse status with enhanced error handling
      TransactionStatus status = TransactionStatus.completed;
      try {
        final statusString = data['status']?.toString();
        if (statusString != null && statusString.isNotEmpty) {
          status = TransactionStatus.values.firstWhere(
            (s) => s.toString().split('.').last == statusString,
            orElse: () => TransactionStatus.completed,
          );
        }
      } catch (e) {
        status = TransactionStatus.completed; // Default to completed
      }

      // Parse numeric values with null safety
      double amount = 0.0;
      double balanceBefore = 0.0;
      double balanceAfter = 0.0;

      try {
        amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
        balanceBefore = (data['balance_before'] as num?)?.toDouble() ?? 0.0;
        balanceAfter = (data['balance_after'] as num?)?.toDouble() ?? 0.0;
      } catch (e) {
        // Keep default values if parsing fails
      }

      // Parse dates with null safety
      DateTime createdAt = DateTime.now();
      DateTime? approvedAt;

      try {
        final createdAtString = data['created_at']?.toString();
        if (createdAtString != null && createdAtString.isNotEmpty) {
          createdAt = DateTime.parse(createdAtString);
        }
      } catch (e) {
        createdAt = DateTime.now();
      }

      try {
        final approvedAtString = data['approved_at']?.toString();
        if (approvedAtString != null && approvedAtString.isNotEmpty) {
          approvedAt = DateTime.parse(approvedAtString);
        }
      } catch (e) {
        approvedAt = null;
      }

      return WalletTransactionModel(
        id: id,
        walletId: walletId,
        userId: userId,
        transactionType: transactionType,
        amount: amount,
        balanceBefore: balanceBefore,
        balanceAfter: balanceAfter,
        description: description ?? 'معاملة غير محددة',
        referenceId: data['reference_id']?.toString(),
        referenceType: referenceType,
        status: status,
        createdAt: createdAt,
        createdBy: createdBy,
        approvedBy: data['approved_by']?.toString(),
        approvedAt: approvedAt,
        metadata: data['metadata'] as Map<String, dynamic>?,
        userName: data['user_name']?.toString(),
        createdByName: data['created_by_name']?.toString(),
        approvedByName: data['approved_by_name']?.toString(),
      );
    } catch (e) {
      throw Exception('Failed to parse transaction data: $e. Data: $data');
    }
  }
  final String id;
  final String walletId;
  final String userId;
  final TransactionType transactionType;
  final double amount;
  final double balanceBefore;
  final double balanceAfter;
  final String description;
  final String? referenceId;
  final ReferenceType? referenceType;
  final TransactionStatus status;
  final DateTime createdAt;
  final String createdBy;
  final String? approvedBy;
  final DateTime? approvedAt;
  final Map<String, dynamic>? metadata;

  // Additional fields from joins
  final String? userName;
  final String? createdByName;
  final String? approvedByName;

  Map<String, dynamic> toJson() => toDatabase();

  /// Convert to database format
  Map<String, dynamic> toDatabase() {
    return {
      'id': id,
      'wallet_id': walletId,
      'user_id': userId,
      'transaction_type': transactionType.toString().split('.').last,
      'amount': amount,
      'balance_before': balanceBefore,
      'balance_after': balanceAfter,
      'description': description,
      'reference_id': referenceId,
      'reference_type': referenceType?.toString().split('.').last,
      'status': status.toString().split('.').last,
      'created_at': createdAt.toIso8601String(),
      'created_by': createdBy,
      'approved_by': approvedBy,
      'approved_at': approvedAt?.toIso8601String(),
      'metadata': metadata,
    };
  }

  /// Create a copy with updated fields
  WalletTransactionModel copyWith({
    String? id,
    String? walletId,
    String? userId,
    TransactionType? transactionType,
    double? amount,
    double? balanceBefore,
    double? balanceAfter,
    String? description,
    String? referenceId,
    ReferenceType? referenceType,
    TransactionStatus? status,
    DateTime? createdAt,
    String? createdBy,
    String? approvedBy,
    DateTime? approvedAt,
    Map<String, dynamic>? metadata,
    String? userName,
    String? createdByName,
    String? approvedByName,
  }) {
    return WalletTransactionModel(
      id: id ?? this.id,
      walletId: walletId ?? this.walletId,
      userId: userId ?? this.userId,
      transactionType: transactionType ?? this.transactionType,
      amount: amount ?? this.amount,
      balanceBefore: balanceBefore ?? this.balanceBefore,
      balanceAfter: balanceAfter ?? this.balanceAfter,
      description: description ?? this.description,
      referenceId: referenceId ?? this.referenceId,
      referenceType: referenceType ?? this.referenceType,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      metadata: metadata ?? this.metadata,
      userName: userName ?? this.userName,
      createdByName: createdByName ?? this.createdByName,
      approvedByName: approvedByName ?? this.approvedByName,
    );
  }

  /// Get transaction type display name in Arabic
  String get typeDisplayName {
    switch (transactionType) {
      case TransactionType.credit:
        return 'إيداع';
      case TransactionType.debit:
        return 'سحب';
      case TransactionType.reward:
        return 'مكافأة';
      case TransactionType.salary:
        return 'راتب';
      case TransactionType.payment:
        return 'دفع';
      case TransactionType.refund:
        return 'استرداد';
      case TransactionType.bonus:
        return 'علاوة';
      case TransactionType.penalty:
        return 'خصم';
      case TransactionType.transfer:
        return 'تحويل';
    }
  }

  /// Get status display name in Arabic
  String get statusDisplayName {
    switch (status) {
      case TransactionStatus.pending:
        return 'قيد الانتظار';
      case TransactionStatus.completed:
        return 'مكتمل';
      case TransactionStatus.failed:
        return 'فشل';
      case TransactionStatus.cancelled:
        return 'ملغي';
    }
  }

  /// Check if transaction is credit (increases balance)
  bool get isCredit => [
    TransactionType.credit,
    TransactionType.reward,
    TransactionType.salary,
    TransactionType.bonus,
    TransactionType.refund,
  ].contains(transactionType);

  /// Check if transaction is debit (decreases balance)
  bool get isDebit => [
    TransactionType.debit,
    TransactionType.payment,
    TransactionType.penalty,
  ].contains(transactionType);

  /// Get formatted amount with sign
  String get formattedAmount {
    final sign = isCredit ? '+' : '-';
    return '$sign${amount.toStringAsFixed(2)} جنيه';
  }

  /// Get formatted date
  String get formattedDate {
    // Convert to local time if UTC to ensure proper timezone handling
    final localDate = createdAt.isUtc ? createdAt.toLocal() : createdAt;
    return '${localDate.day}/${localDate.month}/${localDate.year}';
  }

  /// Get formatted time
  String get formattedTime {
    // Convert to local time if UTC to ensure proper timezone handling
    final localTime = createdAt.isUtc ? createdAt.toLocal() : createdAt;
    return '${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  String toString() {
    return 'WalletTransactionModel(id: $id, type: $transactionType, amount: $amount, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WalletTransactionModel &&
        other.id == id &&
        other.walletId == walletId &&
        other.userId == userId &&
        other.transactionType == transactionType &&
        other.amount == amount;
  }

  @override
  int get hashCode {
    return Object.hash(id, walletId, userId, transactionType, amount);
  }
}
