/// Wallet status enumeration
enum WalletStatus {
  active,
  suspended,
  closed,
}

/// Wallet model representing a user's wallet
class WalletModel {

  const WalletModel({
    required this.id,
    required this.userId,
    required this.balance,
    required this.role,
    this.currency = 'EGP',
    this.status = WalletStatus.active,
    required this.createdAt,
    required this.updatedAt,
    this.metadata,
    this.userName,
    this.userEmail,
    this.phoneNumber,
    this.transactionCount,
    this.lastTransactionDate,
  });

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel.fromDatabase(json);
  }

  /// Create a wallet model from database response with enhanced null safety
  factory WalletModel.fromDatabase(Map<String, dynamic> data) {
    try {
      // Validate required fields first
      final id = data['id']?.toString();
      final userId = data['user_id']?.toString();
      final role = data['role']?.toString();

      if (id == null || id.isEmpty) {
        throw Exception('Wallet ID is null or empty');
      }
      if (userId == null || userId.isEmpty) {
        throw Exception('User ID is null or empty');
      }
      if (role == null || role.isEmpty) {
        throw Exception('Role is null or empty');
      }

      // Parse balance with null safety
      double balance = 0.0;
      try {
        balance = (data['balance'] as num?)?.toDouble() ?? 0.0;
      } catch (e) {
        balance = 0.0; // Default to 0 if parsing fails
      }

      // Parse status with enhanced error handling
      WalletStatus status = WalletStatus.active;
      try {
        final statusString = data['status']?.toString();
        if (statusString != null && statusString.isNotEmpty) {
          status = WalletStatus.values.firstWhere(
            (s) => s.toString().split('.').last == statusString,
            orElse: () => WalletStatus.active,
          );
        }
      } catch (e) {
        status = WalletStatus.active; // Default to active if parsing fails
      }

      // Parse dates with null safety
      DateTime createdAt = DateTime.now();
      DateTime updatedAt = DateTime.now();

      try {
        final createdAtString = data['created_at']?.toString();
        if (createdAtString != null && createdAtString.isNotEmpty) {
          createdAt = DateTime.parse(createdAtString);
        }
      } catch (e) {
        createdAt = DateTime.now();
      }

      try {
        final updatedAtString = data['updated_at']?.toString();
        if (updatedAtString != null && updatedAtString.isNotEmpty) {
          updatedAt = DateTime.parse(updatedAtString);
        }
      } catch (e) {
        updatedAt = DateTime.now();
      }

      // Parse optional last transaction date
      DateTime? lastTransactionDate;
      try {
        final lastTransactionString = data['last_transaction_date']?.toString();
        if (lastTransactionString != null && lastTransactionString.isNotEmpty) {
          lastTransactionDate = DateTime.parse(lastTransactionString);
        }
      } catch (e) {
        lastTransactionDate = null;
      }

      return WalletModel(
        id: id,
        userId: userId,
        balance: balance,
        role: role,
        currency: data['currency']?.toString() ?? 'EGP',
        status: status,
        createdAt: createdAt,
        updatedAt: updatedAt,
        metadata: data['metadata'] as Map<String, dynamic>?,
        userName: data['user_name']?.toString(),
        userEmail: data['user_email']?.toString(),
        phoneNumber: data['phone_number']?.toString(),
        transactionCount: (data['transaction_count'] as num?)?.toInt(),
        lastTransactionDate: lastTransactionDate,
      );
    } catch (e) {
      throw Exception('Failed to parse wallet data: $e. Data: $data');
    }
  }
  final String id;
  final String userId;
  final double balance;
  final String role;
  final String currency;
  final WalletStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? metadata;

  // Additional fields from joins
  final String? userName;
  final String? userEmail;
  final String? phoneNumber;
  final int? transactionCount;
  final DateTime? lastTransactionDate;

  Map<String, dynamic> toJson() => toDatabase();

  /// Convert to database format
  Map<String, dynamic> toDatabase() {
    return {
      'id': id,
      'user_id': userId,
      'balance': balance,
      'role': role,
      'currency': currency,
      'status': status.toString().split('.').last,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  /// Create a copy with updated fields
  WalletModel copyWith({
    String? id,
    String? userId,
    double? balance,
    String? role,
    String? currency,
    WalletStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
    String? userName,
    String? userEmail,
    String? phoneNumber,
    int? transactionCount,
    DateTime? lastTransactionDate,
  }) {
    return WalletModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      balance: balance ?? this.balance,
      role: role ?? this.role,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      transactionCount: transactionCount ?? this.transactionCount,
      lastTransactionDate: lastTransactionDate ?? this.lastTransactionDate,
    );
  }

  /// Get formatted balance with currency
  String get formattedBalance => '$balance $currency';

  /// Get formatted balance with debt/credit labeling in Arabic
  String get formattedBalanceWithLabel {
    if (balance < 0) {
      return 'مديونية: ${balance.abs().toStringAsFixed(2)} ج.م';
    } else if (balance > 0) {
      return 'رصيد: ${balance.toStringAsFixed(2)} ج.م';
    } else {
      return 'رصيد: 0.00 ج.م';
    }
  }

  /// Check if wallet has debt (negative balance)
  bool get hasDebt => balance < 0;

  /// Get debt amount (absolute value of negative balance)
  double get debtAmount => balance < 0 ? balance.abs() : 0.0;

  /// Get formatted debt amount
  String get formattedDebtAmount => '${debtAmount.toStringAsFixed(2)} ج.م';

  /// Get status display name in Arabic
  String get statusDisplayName {
    switch (status) {
      case WalletStatus.active:
        return 'نشط';
      case WalletStatus.suspended:
        return 'معلق';
      case WalletStatus.closed:
        return 'مغلق';
    }
  }

  /// Get role display name in Arabic
  String get roleDisplayName {
    switch (role) {
      case 'admin':
        return 'مدير النظام';
      case 'accountant':
        return 'محاسب';
      case 'worker':
        return 'عامل';
      case 'client':
        return 'عميل';
      case 'owner':
        return 'مالك';
      default:
        return role;
    }
  }

  /// Check if wallet is active
  bool get isActive => status == WalletStatus.active;

  /// Check if wallet can receive transactions
  bool get canReceiveTransactions => status == WalletStatus.active;

  /// Check if wallet can send transactions
  bool get canSendTransactions => status == WalletStatus.active && balance > 0;

  @override
  String toString() {
    return 'WalletModel(id: $id, userId: $userId, balance: $balance, role: $role, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WalletModel &&
        other.id == id &&
        other.userId == userId &&
        other.balance == balance &&
        other.role == role &&
        other.currency == currency &&
        other.status == status;
  }

  @override
  int get hashCode {
    return Object.hash(id, userId, balance, role, currency, status);
  }
}
