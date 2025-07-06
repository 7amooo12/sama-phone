/// Electronic wallet transaction type enumeration
enum ElectronicWalletTransactionType {
  deposit,
  withdrawal,
  transfer,
  payment,
  refund,
}

/// Electronic wallet transaction status enumeration
enum ElectronicWalletTransactionStatus {
  pending,
  completed,
  failed,
  cancelled,
}

/// Electronic wallet transaction model for tracking electronic wallet operations
class ElectronicWalletTransactionModel {

  const ElectronicWalletTransactionModel({
    required this.id,
    required this.walletId,
    required this.transactionType,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    this.status = ElectronicWalletTransactionStatus.pending,
    this.description,
    this.referenceId,
    this.paymentId,
    required this.createdAt,
    required this.updatedAt,
    this.processedBy,
    this.metadata,
    this.walletName,
    this.walletPhoneNumber,
    this.processedByName,
  });

  /// Create from database JSON
  factory ElectronicWalletTransactionModel.fromDatabase(Map<String, dynamic> json) {
    return ElectronicWalletTransactionModel(
      id: json['id'] as String,
      walletId: json['wallet_id'] as String,
      transactionType: _parseTransactionType(json['transaction_type'] as String),
      amount: (json['amount'] as num).toDouble(),
      balanceBefore: (json['balance_before'] as num).toDouble(),
      balanceAfter: (json['balance_after'] as num).toDouble(),
      status: _parseStatus(json['status'] as String? ?? 'pending'),
      description: json['description'] as String?,
      referenceId: json['reference_id'] as String?,
      paymentId: json['payment_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      processedBy: json['processed_by'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      walletName: json['wallet_name'] as String?,
      walletPhoneNumber: json['wallet_phone_number'] as String?,
      processedByName: json['processed_by_name'] as String?,
    );
  }

  /// Create from JSON
  factory ElectronicWalletTransactionModel.fromJson(Map<String, dynamic> json) {
    return ElectronicWalletTransactionModel.fromDatabase(json);
  }

  /// Create from database JSON with enhanced client information
  factory ElectronicWalletTransactionModel.fromDatabaseWithClientInfo(Map<String, dynamic> json) {
    return ElectronicWalletTransactionModel(
      id: json['id'] as String,
      walletId: json['wallet_id'] as String,
      transactionType: _parseTransactionType(json['transaction_type'] as String),
      amount: (json['amount'] as num).toDouble(),
      balanceBefore: (json['balance_before'] as num?)?.toDouble() ?? 0.0,
      balanceAfter: (json['balance_after'] as num?)?.toDouble() ?? 0.0,
      description: json['description'] as String? ?? '',
      status: _parseStatus(json['status'] as String? ?? 'completed'),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.parse(json['created_at'] as String),
      processedBy: json['processed_by'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      // Enhanced information with client details
      walletName: json['wallet_name'] as String?,
      walletPhoneNumber: json['wallet_phone_number'] as String?,
      processedByName: json['client_name'] as String? ?? json['processed_by_name'] as String?,
    );
  }
  final String id;
  final String walletId;
  final ElectronicWalletTransactionType transactionType;
  final double amount;
  final double balanceBefore;
  final double balanceAfter;
  final ElectronicWalletTransactionStatus status;
  final String? description;
  final String? referenceId;
  final String? paymentId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? processedBy;
  final Map<String, dynamic>? metadata;

  // Additional fields from joins
  final String? walletName;
  final String? walletPhoneNumber;
  final String? processedByName;

  /// Convert to database JSON
  Map<String, dynamic> toDatabase() {
    return {
      'id': id,
      'wallet_id': walletId,
      'transaction_type': _transactionTypeToString(transactionType),
      'amount': amount,
      'balance_before': balanceBefore,
      'balance_after': balanceAfter,
      'status': _statusToString(status),
      'description': description,
      'reference_id': referenceId,
      'payment_id': paymentId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'processed_by': processedBy,
      'metadata': metadata,
    };
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() => toDatabase();

  /// Parse transaction type from string
  static ElectronicWalletTransactionType _parseTransactionType(String type) {
    switch (type) {
      case 'deposit':
        return ElectronicWalletTransactionType.deposit;
      case 'withdrawal':
        return ElectronicWalletTransactionType.withdrawal;
      case 'transfer':
        return ElectronicWalletTransactionType.transfer;
      case 'payment':
        return ElectronicWalletTransactionType.payment;
      case 'refund':
        return ElectronicWalletTransactionType.refund;
      default:
        throw ArgumentError('Unknown transaction type: $type');
    }
  }

  /// Convert transaction type to string
  static String _transactionTypeToString(ElectronicWalletTransactionType type) {
    switch (type) {
      case ElectronicWalletTransactionType.deposit:
        return 'deposit';
      case ElectronicWalletTransactionType.withdrawal:
        return 'withdrawal';
      case ElectronicWalletTransactionType.transfer:
        return 'transfer';
      case ElectronicWalletTransactionType.payment:
        return 'payment';
      case ElectronicWalletTransactionType.refund:
        return 'refund';
    }
  }

  /// Parse status from string
  static ElectronicWalletTransactionStatus _parseStatus(String status) {
    switch (status) {
      case 'pending':
        return ElectronicWalletTransactionStatus.pending;
      case 'completed':
        return ElectronicWalletTransactionStatus.completed;
      case 'failed':
        return ElectronicWalletTransactionStatus.failed;
      case 'cancelled':
        return ElectronicWalletTransactionStatus.cancelled;
      default:
        return ElectronicWalletTransactionStatus.pending;
    }
  }

  /// Convert status to string
  static String _statusToString(ElectronicWalletTransactionStatus status) {
    switch (status) {
      case ElectronicWalletTransactionStatus.pending:
        return 'pending';
      case ElectronicWalletTransactionStatus.completed:
        return 'completed';
      case ElectronicWalletTransactionStatus.failed:
        return 'failed';
      case ElectronicWalletTransactionStatus.cancelled:
        return 'cancelled';
    }
  }

  /// Get display name for transaction type
  String get transactionTypeDisplayName {
    switch (transactionType) {
      case ElectronicWalletTransactionType.deposit:
        return 'إيداع';
      case ElectronicWalletTransactionType.withdrawal:
        return 'سحب';
      case ElectronicWalletTransactionType.transfer:
        return 'تحويل';
      case ElectronicWalletTransactionType.payment:
        return 'دفع';
      case ElectronicWalletTransactionType.refund:
        return 'استرداد';
    }
  }

  /// Get display name for status
  String get statusDisplayName {
    switch (status) {
      case ElectronicWalletTransactionStatus.pending:
        return 'قيد المعالجة';
      case ElectronicWalletTransactionStatus.completed:
        return 'مكتمل';
      case ElectronicWalletTransactionStatus.failed:
        return 'فشل';
      case ElectronicWalletTransactionStatus.cancelled:
        return 'ملغي';
    }
  }

  /// Get icon for transaction type
  String get transactionTypeIcon {
    switch (transactionType) {
      case ElectronicWalletTransactionType.deposit:
        return '⬇️';
      case ElectronicWalletTransactionType.withdrawal:
        return '⬆️';
      case ElectronicWalletTransactionType.transfer:
        return '🔄';
      case ElectronicWalletTransactionType.payment:
        return '💰';
      case ElectronicWalletTransactionType.refund:
        return '↩️';
    }
  }

  /// Get color for transaction type
  int get transactionTypeColor {
    switch (transactionType) {
      case ElectronicWalletTransactionType.deposit:
        return 0xFF10B981; // Green
      case ElectronicWalletTransactionType.withdrawal:
        return 0xFFEF4444; // Red
      case ElectronicWalletTransactionType.transfer:
        return 0xFF3B82F6; // Blue
      case ElectronicWalletTransactionType.payment:
        return 0xFFF59E0B; // Orange
      case ElectronicWalletTransactionType.refund:
        return 0xFF8B5CF6; // Purple
    }
  }

  /// Get color for status
  int get statusColor {
    switch (status) {
      case ElectronicWalletTransactionStatus.pending:
        return 0xFFF59E0B; // Orange
      case ElectronicWalletTransactionStatus.completed:
        return 0xFF10B981; // Green
      case ElectronicWalletTransactionStatus.failed:
        return 0xFFEF4444; // Red
      case ElectronicWalletTransactionStatus.cancelled:
        return 0xFF6B7280; // Gray
    }
  }

  /// Get formatted amount
  String get formattedAmount {
    return '${amount.toStringAsFixed(2)} ج.م';
  }

  /// Get formatted balance before
  String get formattedBalanceBefore {
    return '${balanceBefore.toStringAsFixed(2)} ج.م';
  }

  /// Get formatted balance after
  String get formattedBalanceAfter {
    return '${balanceAfter.toStringAsFixed(2)} ج.م';
  }

  /// Check if transaction is completed
  bool get isCompleted => status == ElectronicWalletTransactionStatus.completed;

  /// Check if transaction is pending
  bool get isPending => status == ElectronicWalletTransactionStatus.pending;

  /// Check if transaction failed
  bool get isFailed => status == ElectronicWalletTransactionStatus.failed;

  /// Check if transaction is cancelled
  bool get isCancelled => status == ElectronicWalletTransactionStatus.cancelled;

  /// Create a copy with updated fields
  ElectronicWalletTransactionModel copyWith({
    String? id,
    String? walletId,
    ElectronicWalletTransactionType? transactionType,
    double? amount,
    double? balanceBefore,
    double? balanceAfter,
    ElectronicWalletTransactionStatus? status,
    String? description,
    String? referenceId,
    String? paymentId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? processedBy,
    Map<String, dynamic>? metadata,
    String? walletName,
    String? walletPhoneNumber,
    String? processedByName,
  }) {
    return ElectronicWalletTransactionModel(
      id: id ?? this.id,
      walletId: walletId ?? this.walletId,
      transactionType: transactionType ?? this.transactionType,
      amount: amount ?? this.amount,
      balanceBefore: balanceBefore ?? this.balanceBefore,
      balanceAfter: balanceAfter ?? this.balanceAfter,
      status: status ?? this.status,
      description: description ?? this.description,
      referenceId: referenceId ?? this.referenceId,
      paymentId: paymentId ?? this.paymentId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      processedBy: processedBy ?? this.processedBy,
      metadata: metadata ?? this.metadata,
      walletName: walletName ?? this.walletName,
      walletPhoneNumber: walletPhoneNumber ?? this.walletPhoneNumber,
      processedByName: processedByName ?? this.processedByName,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ElectronicWalletTransactionModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ElectronicWalletTransactionModel(id: $id, walletId: $walletId, transactionType: $transactionType, amount: $amount, status: $status)';
  }
}
