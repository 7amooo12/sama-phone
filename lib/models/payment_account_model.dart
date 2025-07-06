/// Payment account model for managing Vodafone Cash and InstaPay accounts
class PaymentAccountModel {

  const PaymentAccountModel({
    required this.id,
    required this.accountType,
    required this.accountNumber,
    required this.accountHolderName,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create from database JSON
  factory PaymentAccountModel.fromDatabase(Map<String, dynamic> json) {
    return PaymentAccountModel(
      id: json['id'] as String,
      accountType: json['account_type'] as String,
      accountNumber: json['account_number'] as String,
      accountHolderName: json['account_holder_name'] as String,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Create from JSON
  factory PaymentAccountModel.fromJson(Map<String, dynamic> json) {
    return PaymentAccountModel.fromDatabase(json);
  }
  final String id;
  final String accountType;
  final String accountNumber;
  final String accountHolderName;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Convert to database JSON
  Map<String, dynamic> toDatabase() {
    return {
      'id': id,
      'account_type': accountType,
      'account_number': accountNumber,
      'account_holder_name': accountHolderName,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() => toDatabase();

  /// Create a copy with updated fields
  PaymentAccountModel copyWith({
    String? id,
    String? accountType,
    String? accountNumber,
    String? accountHolderName,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PaymentAccountModel(
      id: id ?? this.id,
      accountType: accountType ?? this.accountType,
      accountNumber: accountNumber ?? this.accountNumber,
      accountHolderName: accountHolderName ?? this.accountHolderName,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get masked account number for display
  String get maskedAccountNumber {
    if (accountNumber.length <= 4) return accountNumber;
    
    final visiblePart = accountNumber.substring(accountNumber.length - 4);
    final maskedPart = '*' * (accountNumber.length - 4);
    return '$maskedPart$visiblePart';
  }

  /// Get display name for account type
  String get accountTypeDisplayName {
    switch (accountType) {
      case 'vodafone_cash':
        return 'فودافون كاش';
      case 'instapay':
        return 'إنستاباي';
      default:
        return accountType;
    }
  }

  /// Get icon for account type
  String get accountTypeIcon {
    switch (accountType) {
      case 'vodafone_cash':
        return '🟥';
      case 'instapay':
        return '🟦';
      default:
        return '💳';
    }
  }

  /// Get color for account type
  String get accountTypeColor {
    switch (accountType) {
      case 'vodafone_cash':
        return '#E53E3E'; // Red
      case 'instapay':
        return '#3182CE'; // Blue
      default:
        return '#718096'; // Gray
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PaymentAccountModel &&
        other.id == id &&
        other.accountType == accountType &&
        other.accountNumber == accountNumber &&
        other.accountHolderName == accountHolderName &&
        other.isActive == isActive &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      accountType,
      accountNumber,
      accountHolderName,
      isActive,
      createdAt,
      updatedAt,
    );
  }

  @override
  String toString() {
    return 'PaymentAccountModel(id: $id, accountType: $accountType, accountNumber: $maskedAccountNumber, accountHolderName: $accountHolderName, isActive: $isActive)';
  }
}
