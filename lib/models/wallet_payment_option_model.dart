import 'electronic_wallet_model.dart';

/// Model to represent electronic wallets as payment options for clients
/// This bridges the gap between ElectronicWalletModel and the client payment interface
class WalletPaymentOptionModel {

  const WalletPaymentOptionModel({
    required this.id,
    required this.accountType,
    required this.accountNumber,
    required this.accountHolderName,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.currentBalance = 0.0,
  });

  /// Create from ElectronicWalletModel
  factory WalletPaymentOptionModel.fromElectronicWallet(ElectronicWalletModel wallet) {
    return WalletPaymentOptionModel(
      id: wallet.id,
      accountType: wallet.walletType == ElectronicWalletType.vodafoneCash ? 'vodafone_cash' : 'instapay',
      accountNumber: wallet.phoneNumber,
      accountHolderName: wallet.walletName,
      isActive: wallet.isActive,
      createdAt: wallet.createdAt,
      updatedAt: wallet.updatedAt,
      description: wallet.description,
      currentBalance: wallet.currentBalance,
    );
  }
  final String id;
  final String accountType; // 'vodafone_cash' or 'instapay'
  final String accountNumber; // phone number from wallet
  final String accountHolderName; // wallet name
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? description;
  final double currentBalance;

  /// Convert to PaymentAccountModel-compatible format
  Map<String, dynamic> toPaymentAccountFormat() {
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
        return '#E60012'; // Vodafone Red
      case 'instapay':
        return '#1E88E5'; // InstaPay Blue
      default:
        return '#718096'; // Gray
    }
  }

  /// Get formatted balance
  String get formattedBalance {
    return '${currentBalance.toStringAsFixed(2)} جنيه';
  }

  /// Check if wallet has sufficient balance for payment
  bool hasSufficientBalance(double amount) {
    return currentBalance >= amount;
  }

  /// Get wallet status display
  String get statusDisplay {
    return isActive ? 'نشط' : 'غير نشط';
  }

  /// Get wallet type enum
  ElectronicWalletType get walletType {
    return accountType == 'vodafone_cash' 
        ? ElectronicWalletType.vodafoneCash 
        : ElectronicWalletType.instaPay;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WalletPaymentOptionModel &&
        other.id == id &&
        other.accountType == accountType &&
        other.accountNumber == accountNumber &&
        other.accountHolderName == accountHolderName &&
        other.isActive == isActive;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      accountType,
      accountNumber,
      accountHolderName,
      isActive,
    );
  }

  @override
  String toString() {
    return 'WalletPaymentOptionModel(id: $id, type: $accountType, number: $maskedAccountNumber, name: $accountHolderName, active: $isActive, balance: $formattedBalance)';
  }

  /// Create a copy with updated fields
  WalletPaymentOptionModel copyWith({
    String? id,
    String? accountType,
    String? accountNumber,
    String? accountHolderName,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? description,
    double? currentBalance,
  }) {
    return WalletPaymentOptionModel(
      id: id ?? this.id,
      accountType: accountType ?? this.accountType,
      accountNumber: accountNumber ?? this.accountNumber,
      accountHolderName: accountHolderName ?? this.accountHolderName,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      description: description ?? this.description,
      currentBalance: currentBalance ?? this.currentBalance,
    );
  }
}
