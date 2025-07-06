import 'package:flutter/material.dart';

/// Connection Point Enum for Treasury Connections
enum ConnectionPoint {
  top,
  bottom,
  left,
  right,
  center; // Default for existing connections

  String get name {
    switch (this) {
      case ConnectionPoint.top:
        return 'top';
      case ConnectionPoint.bottom:
        return 'bottom';
      case ConnectionPoint.left:
        return 'left';
      case ConnectionPoint.right:
        return 'right';
      case ConnectionPoint.center:
        return 'center';
    }
  }

  static ConnectionPoint fromString(String value) {
    switch (value.toLowerCase()) {
      case 'top':
        return ConnectionPoint.top;
      case 'bottom':
        return ConnectionPoint.bottom;
      case 'left':
        return ConnectionPoint.left;
      case 'right':
        return ConnectionPoint.right;
      case 'center':
      default:
        return ConnectionPoint.center;
    }
  }
}

/// Treasury Type Enum
enum TreasuryType {
  cash('cash', 'نقدي'),
  bank('bank', 'بنكي');

  const TreasuryType(this.code, this.nameAr);

  final String code;
  final String nameAr;
}

/// Egyptian Banks Enum
enum EgyptianBank {
  cib('Commercial International Bank', 'البنك التجاري الدولي', '🏦'),
  bankOfEgypt('Bank of Egypt', 'بنك مصر', '🇪🇬'),
  bankOfCairo('Bank of Cairo', 'بنك القاهرة', '🏛️'),
  nbe('National Bank of Egypt', 'البنك الأهلي المصري', '🏪'),
  alexBank('Alexandria Bank', 'بنك الإسكندرية', '🏖️'),
  misr('Misr Bank', 'بنك مصر', '🏺'),
  adib('Abu Dhabi Islamic Bank', 'مصرف أبوظبي الإسلامي', '🕌'),
  hsbc('HSBC Bank Egypt', 'بنك إتش إس بي سي مصر', '🌍'),
  qnb('QNB Al Ahli', 'بنك قطر الوطني الأهلي', '🏦'),
  mashreq('Mashreq Bank', 'بنك المشرق', '🌅'),
  other('Other Bank', 'بنك آخر', '🏦');

  const EgyptianBank(this.nameEn, this.nameAr, this.icon);

  final String nameEn;
  final String nameAr;
  final String icon;
}

/// Treasury Vault Model
class TreasuryVault {
  final String id;
  final String name;
  final String currency;
  final double balance;
  final double exchangeRateToEgp;
  final bool isMainTreasury;
  final double positionX;
  final double positionY;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;

  // Bank account fields
  final TreasuryType treasuryType;
  final String? bankName;
  final String? accountNumber;
  final String? accountHolderName;

  const TreasuryVault({
    required this.id,
    required this.name,
    required this.currency,
    required this.balance,
    required this.exchangeRateToEgp,
    required this.isMainTreasury,
    required this.positionX,
    required this.positionY,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.treasuryType = TreasuryType.cash,
    this.bankName,
    this.accountNumber,
    this.accountHolderName,
  });

  factory TreasuryVault.fromJson(Map<String, dynamic> json) {
    // Parse treasury type
    final treasuryTypeCode = json['treasury_type'] as String? ?? 'cash';
    final treasuryType = TreasuryType.values.firstWhere(
      (type) => type.code == treasuryTypeCode,
      orElse: () => TreasuryType.cash,
    );

    return TreasuryVault(
      id: json['id'] as String,
      name: json['name'] as String,
      currency: json['currency'] as String,
      balance: (json['balance'] as num).toDouble(),
      exchangeRateToEgp: (json['exchange_rate_to_egp'] as num).toDouble(),
      isMainTreasury: json['is_main_treasury'] as bool,
      positionX: (json['position_x'] as num?)?.toDouble() ?? 0.0,
      positionY: (json['position_y'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      createdBy: json['created_by'] as String?,
      treasuryType: treasuryType,
      bankName: json['bank_name'] as String?,
      accountNumber: json['account_number'] as String?,
      accountHolderName: json['account_holder_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'currency': currency,
      'balance': balance,
      'exchange_rate_to_egp': exchangeRateToEgp,
      'is_main_treasury': isMainTreasury,
      'position_x': positionX,
      'position_y': positionY,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'created_by': createdBy,
      'treasury_type': treasuryType.code,
      'bank_name': bankName,
      'account_number': accountNumber,
      'account_holder_name': accountHolderName,
    };
  }

  TreasuryVault copyWith({
    String? id,
    String? name,
    String? currency,
    double? balance,
    double? exchangeRateToEgp,
    bool? isMainTreasury,
    double? positionX,
    double? positionY,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    TreasuryType? treasuryType,
    String? bankName,
    String? accountNumber,
    String? accountHolderName,
  }) {
    return TreasuryVault(
      id: id ?? this.id,
      name: name ?? this.name,
      currency: currency ?? this.currency,
      balance: balance ?? this.balance,
      exchangeRateToEgp: exchangeRateToEgp ?? this.exchangeRateToEgp,
      isMainTreasury: isMainTreasury ?? this.isMainTreasury,
      positionX: positionX ?? this.positionX,
      positionY: positionY ?? this.positionY,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      treasuryType: treasuryType ?? this.treasuryType,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      accountHolderName: accountHolderName ?? this.accountHolderName,
    );
  }

  /// Get balance in EGP equivalent
  double get balanceInEgp => balance * exchangeRateToEgp;

  /// Get currency flag emoji
  String get currencyFlag {
    switch (currency) {
      case 'USD':
        return '🇺🇸';
      case 'EGP':
        return '🇪🇬';
      case 'SAR':
        return '🇸🇦';
      case 'CNY':
        return '🇨🇳';
      case 'EUR':
        return '🇪🇺';
      default:
        return '💰';
    }
  }

  /// Get currency symbol
  String get currencySymbol {
    switch (currency) {
      case 'USD':
        return '\$';
      case 'EGP':
        return 'ج.م';
      case 'SAR':
        return 'ر.س';
      case 'CNY':
        return '¥';
      case 'EUR':
        return '€';
      default:
        return currency;
    }
  }

  /// Check if this is a bank treasury
  bool get isBankTreasury => treasuryType == TreasuryType.bank;

  /// Check if this is a cash treasury
  bool get isCashTreasury => treasuryType == TreasuryType.cash;

  /// Get bank icon for bank treasuries
  String get bankIcon {
    if (!isBankTreasury) return '💰';

    final bankNameLower = bankName?.toLowerCase() ?? '';
    if (bankNameLower.contains('cib') || bankNameLower.contains('commercial international')) {
      return '🏦'; // CIB
    } else if (bankNameLower.contains('مصر') || bankNameLower.contains('egypt')) {
      return '🇪🇬'; // Bank of Egypt
    } else if (bankNameLower.contains('قاهرة') || bankNameLower.contains('cairo')) {
      return '🏛️'; // Bank of Cairo
    } else if (bankNameLower.contains('أهلي') || bankNameLower.contains('ahli')) {
      return '🏪'; // National Bank of Egypt
    } else if (bankNameLower.contains('مشرق') || bankNameLower.contains('mashreq')) {
      return '🌅'; // Mashreq Bank
    } else {
      return '🏦'; // Generic bank icon
    }
  }

  /// Get masked account number for display
  String get maskedAccountNumber {
    if (!isBankTreasury || accountNumber == null || accountNumber!.isEmpty) {
      return '';
    }

    final account = accountNumber!;
    if (account.length <= 4) {
      return account;
    }

    // Show first 2 and last 4 digits, mask the middle
    final start = account.substring(0, 2);
    final end = account.substring(account.length - 4);
    final middle = '*' * (account.length - 6).clamp(2, 8);

    return '$start$middle$end';
  }

  /// Get display name for treasury (includes bank name for bank treasuries)
  String get displayName {
    if (isBankTreasury && bankName != null) {
      return '$name - $bankName';
    }
    return name;
  }
}

/// Treasury Connection Model
class TreasuryConnection {
  final String id;
  final String sourceTreasuryId;
  final String targetTreasuryId;
  final double connectionAmount;
  final double exchangeRateUsed;
  final DateTime createdAt;
  final String? createdBy;
  final ConnectionPoint sourceConnectionPoint;
  final ConnectionPoint targetConnectionPoint;

  const TreasuryConnection({
    required this.id,
    required this.sourceTreasuryId,
    required this.targetTreasuryId,
    required this.connectionAmount,
    required this.exchangeRateUsed,
    required this.createdAt,
    this.createdBy,
    this.sourceConnectionPoint = ConnectionPoint.center,
    this.targetConnectionPoint = ConnectionPoint.center,
  });

  factory TreasuryConnection.fromJson(Map<String, dynamic> json) {
    return TreasuryConnection(
      id: json['id'] as String,
      sourceTreasuryId: json['source_treasury_id'] as String,
      targetTreasuryId: json['target_treasury_id'] as String,
      connectionAmount: (json['connection_amount'] as num).toDouble(),
      exchangeRateUsed: (json['exchange_rate_used'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      createdBy: json['created_by'] as String?,
      sourceConnectionPoint: ConnectionPoint.fromString(
        json['source_connection_point'] as String? ?? 'center',
      ),
      targetConnectionPoint: ConnectionPoint.fromString(
        json['target_connection_point'] as String? ?? 'center',
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'source_treasury_id': sourceTreasuryId,
      'target_treasury_id': targetTreasuryId,
      'connection_amount': connectionAmount,
      'exchange_rate_used': exchangeRateUsed,
      'created_at': createdAt.toIso8601String(),
      'created_by': createdBy,
      'source_connection_point': sourceConnectionPoint.name,
      'target_connection_point': targetConnectionPoint.name,
    };
  }
}

/// Treasury Transaction Type Enumeration
enum TreasuryTransactionType {
  credit,
  debit,
  connection,
  disconnection,
  exchangeRateUpdate,
  transferIn,
  transferOut,
  balanceAdjustment;

  String get code {
    switch (this) {
      case TreasuryTransactionType.credit:
        return 'credit';
      case TreasuryTransactionType.debit:
        return 'debit';
      case TreasuryTransactionType.connection:
        return 'connection';
      case TreasuryTransactionType.disconnection:
        return 'disconnection';
      case TreasuryTransactionType.exchangeRateUpdate:
        return 'exchange_rate_update';
      case TreasuryTransactionType.transferIn:
        return 'transfer_in';
      case TreasuryTransactionType.transferOut:
        return 'transfer_out';
      case TreasuryTransactionType.balanceAdjustment:
        return 'balance_adjustment';
    }
  }

  String get displayName {
    switch (this) {
      case TreasuryTransactionType.credit:
        return 'إيداع';
      case TreasuryTransactionType.debit:
        return 'سحب';
      case TreasuryTransactionType.connection:
        return 'ربط خزنة';
      case TreasuryTransactionType.disconnection:
        return 'إلغاء ربط خزنة';
      case TreasuryTransactionType.exchangeRateUpdate:
        return 'تحديث سعر الصرف';
      case TreasuryTransactionType.transferIn:
        return 'تحويل وارد';
      case TreasuryTransactionType.transferOut:
        return 'تحويل صادر';
      case TreasuryTransactionType.balanceAdjustment:
        return 'تعديل الرصيد';
    }
  }

  static TreasuryTransactionType fromCode(String code) {
    return TreasuryTransactionType.values.firstWhere(
      (type) => type.code == code,
      orElse: () => TreasuryTransactionType.balanceAdjustment,
    );
  }
}

/// Treasury Transaction Model
class TreasuryTransaction {
  final String id;
  final String treasuryId;
  final TreasuryTransactionType transactionType;
  final double amount;
  final double balanceBefore;
  final double balanceAfter;
  final String? description;
  final String? referenceId;
  final DateTime createdAt;
  final String? createdBy;

  const TreasuryTransaction({
    required this.id,
    required this.treasuryId,
    required this.transactionType,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    this.description,
    this.referenceId,
    required this.createdAt,
    this.createdBy,
  });

  factory TreasuryTransaction.fromJson(Map<String, dynamic> json) {
    return TreasuryTransaction(
      id: json['id'] as String,
      treasuryId: json['treasury_id'] as String,
      transactionType: TreasuryTransactionType.fromCode(json['transaction_type'] as String),
      amount: (json['amount'] as num).toDouble(),
      balanceBefore: (json['balance_before'] as num).toDouble(),
      balanceAfter: (json['balance_after'] as num).toDouble(),
      description: json['description'] as String?,
      referenceId: json['reference_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      createdBy: json['created_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'treasury_id': treasuryId,
      'transaction_type': transactionType.code,
      'amount': amount,
      'balance_before': balanceBefore,
      'balance_after': balanceAfter,
      'description': description,
      'reference_id': referenceId,
      'created_at': createdAt.toIso8601String(),
      'created_by': createdBy,
    };
  }

  /// Get formatted amount with currency symbol
  String getFormattedAmount(String currencySymbol) {
    final sign = transactionType == TreasuryTransactionType.credit ||
                 transactionType == TreasuryTransactionType.transferIn ? '+' : '-';
    return '$sign${amount.toStringAsFixed(2)} $currencySymbol';
  }

  /// Check if transaction is a credit type
  bool get isCredit {
    return transactionType == TreasuryTransactionType.credit ||
           transactionType == TreasuryTransactionType.transferIn;
  }

  /// Check if transaction is a debit type
  bool get isDebit {
    return transactionType == TreasuryTransactionType.debit ||
           transactionType == TreasuryTransactionType.transferOut;
  }

  /// Get transaction icon based on type
  String get iconName {
    switch (transactionType) {
      case TreasuryTransactionType.credit:
        return 'add_circle';
      case TreasuryTransactionType.debit:
        return 'remove_circle';
      case TreasuryTransactionType.connection:
        return 'link';
      case TreasuryTransactionType.disconnection:
        return 'link_off';
      case TreasuryTransactionType.exchangeRateUpdate:
        return 'currency_exchange';
      case TreasuryTransactionType.transferIn:
        return 'call_received';
      case TreasuryTransactionType.transferOut:
        return 'call_made';
      case TreasuryTransactionType.balanceAdjustment:
        return 'tune';
    }
  }

  TreasuryTransaction copyWith({
    String? id,
    String? treasuryId,
    TreasuryTransactionType? transactionType,
    double? amount,
    double? balanceBefore,
    double? balanceAfter,
    String? description,
    String? referenceId,
    DateTime? createdAt,
    String? createdBy,
  }) {
    return TreasuryTransaction(
      id: id ?? this.id,
      treasuryId: treasuryId ?? this.treasuryId,
      transactionType: transactionType ?? this.transactionType,
      amount: amount ?? this.amount,
      balanceBefore: balanceBefore ?? this.balanceBefore,
      balanceAfter: balanceAfter ?? this.balanceAfter,
      description: description ?? this.description,
      referenceId: referenceId ?? this.referenceId,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  @override
  String toString() {
    return 'TreasuryTransaction(id: $id, treasuryId: $treasuryId, type: ${transactionType.code}, amount: $amount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TreasuryTransaction && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Treasury Statistics Model
class TreasuryStatistics {
  final int totalVaults;
  final double totalBalanceEgp;
  final double mainTreasuryBalance;
  final int currenciesCount;
  final int connectionsCount;
  final DateTime? lastUpdated;

  const TreasuryStatistics({
    required this.totalVaults,
    required this.totalBalanceEgp,
    required this.mainTreasuryBalance,
    required this.currenciesCount,
    required this.connectionsCount,
    this.lastUpdated,
  });

  factory TreasuryStatistics.fromJson(Map<String, dynamic> json) {
    return TreasuryStatistics(
      totalVaults: json['total_vaults'] as int,
      totalBalanceEgp: (json['total_balance_egp'] as num).toDouble(),
      mainTreasuryBalance: (json['main_treasury_balance'] as num).toDouble(),
      currenciesCount: json['currencies_count'] as int,
      connectionsCount: json['connections_count'] as int,
      lastUpdated: json['last_updated'] != null 
          ? DateTime.parse(json['last_updated'] as String)
          : null,
    );
  }
}

/// Supported currencies enum
enum SupportedCurrency {
  egp('EGP', 'جنيه مصري', '🇪🇬'),
  usd('USD', 'دولار أمريكي', '🇺🇸'),
  sar('SAR', 'ريال سعودي', '🇸🇦'),
  cny('CNY', 'يوان صيني', '🇨🇳'),
  eur('EUR', 'يورو', '🇪🇺');

  const SupportedCurrency(this.code, this.nameAr, this.flag);

  final String code;
  final String nameAr;
  final String flag;
}

/// Transfer Validation Result Model
class TransferValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
  final TransferDetailsPreview? transferDetails;

  const TransferValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
    this.transferDetails,
  });

  factory TransferValidationResult.fromJson(Map<String, dynamic> json) {
    return TransferValidationResult(
      isValid: json['is_valid'] as bool? ?? false,
      errors: List<String>.from(json['errors'] as List? ?? []),
      warnings: List<String>.from(json['warnings'] as List? ?? []),
      transferDetails: json['transfer_details'] != null
          ? TransferDetailsPreview.fromJson(json['transfer_details'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Transfer Details Preview Model
class TransferDetailsPreview {
  final double sourceAmount;
  final double targetAmount;
  final double exchangeRate;
  final double sourceBalanceAfter;
  final double targetBalanceAfter;

  const TransferDetailsPreview({
    required this.sourceAmount,
    required this.targetAmount,
    required this.exchangeRate,
    required this.sourceBalanceAfter,
    required this.targetBalanceAfter,
  });

  factory TransferDetailsPreview.fromJson(Map<String, dynamic> json) {
    return TransferDetailsPreview(
      sourceAmount: (json['source_amount'] as num).toDouble(),
      targetAmount: (json['target_amount'] as num).toDouble(),
      exchangeRate: (json['exchange_rate'] as num).toDouble(),
      sourceBalanceAfter: (json['source_balance_after'] as num).toDouble(),
      targetBalanceAfter: (json['target_balance_after'] as num).toDouble(),
    );
  }
}

/// Transfer Details Model
class TransferDetails {
  final String transferId;
  final String sourceTreasuryId;
  final String sourceTreasuryName;
  final String targetTreasuryId;
  final String targetTreasuryName;
  final double sourceAmount;
  final double targetAmount;
  final double exchangeRateUsed;
  final String description;
  final DateTime createdAt;
  final String? createdBy;

  const TransferDetails({
    required this.transferId,
    required this.sourceTreasuryId,
    required this.sourceTreasuryName,
    required this.targetTreasuryId,
    required this.targetTreasuryName,
    required this.sourceAmount,
    required this.targetAmount,
    required this.exchangeRateUsed,
    required this.description,
    required this.createdAt,
    this.createdBy,
  });

  factory TransferDetails.fromJson(Map<String, dynamic> json) {
    return TransferDetails(
      transferId: json['transfer_id'] as String,
      sourceTreasuryId: json['source_treasury_id'] as String,
      sourceTreasuryName: json['source_treasury_name'] as String,
      targetTreasuryId: json['target_treasury_id'] as String,
      targetTreasuryName: json['target_treasury_name'] as String,
      sourceAmount: (json['source_amount'] as num).toDouble(),
      targetAmount: (json['target_amount'] as num).toDouble(),
      exchangeRateUsed: (json['exchange_rate_used'] as num).toDouble(),
      description: json['description'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      createdBy: json['created_by'] as String?,
    );
  }
}

/// Transfer Statistics Model
class TransferStatistics {
  final double totalTransfersIn;
  final double totalTransfersOut;
  final int transfersInCount;
  final int transfersOutCount;
  final double netTransferAmount;
  final int totalTransfers;

  const TransferStatistics({
    required this.totalTransfersIn,
    required this.totalTransfersOut,
    required this.transfersInCount,
    required this.transfersOutCount,
    required this.netTransferAmount,
    required this.totalTransfers,
  });

  factory TransferStatistics.fromJson(Map<String, dynamic> json) {
    return TransferStatistics(
      totalTransfersIn: (json['total_transfers_in'] as num?)?.toDouble() ?? 0.0,
      totalTransfersOut: (json['total_transfers_out'] as num?)?.toDouble() ?? 0.0,
      transfersInCount: json['transfers_in_count'] as int? ?? 0,
      transfersOutCount: json['transfers_out_count'] as int? ?? 0,
      netTransferAmount: (json['net_transfer_amount'] as num?)?.toDouble() ?? 0.0,
      totalTransfers: json['total_transfers'] as int? ?? 0,
    );
  }
}

/// Treasury Limit Type Enum
enum TreasuryLimitType {
  minBalance('min_balance', 'الحد الأدنى للرصيد'),
  maxBalance('max_balance', 'الحد الأقصى للرصيد'),
  dailyTransaction('daily_transaction', 'حد المعاملات اليومية'),
  monthlyTransaction('monthly_transaction', 'حد المعاملات الشهرية');

  const TreasuryLimitType(this.code, this.nameAr);

  final String code;
  final String nameAr;

  static TreasuryLimitType fromCode(String code) {
    return TreasuryLimitType.values.firstWhere(
      (type) => type.code == code,
      orElse: () => TreasuryLimitType.minBalance,
    );
  }
}

/// Treasury Limit Model
class TreasuryLimit {
  final String id;
  final String treasuryId;
  final TreasuryLimitType limitType;
  final double limitValue;
  final double warningThreshold;
  final double criticalThreshold;
  final bool isEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;

  const TreasuryLimit({
    required this.id,
    required this.treasuryId,
    required this.limitType,
    required this.limitValue,
    required this.warningThreshold,
    required this.criticalThreshold,
    required this.isEnabled,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
  });

  factory TreasuryLimit.fromJson(Map<String, dynamic> json) {
    return TreasuryLimit(
      id: json['id'] as String,
      treasuryId: json['treasury_id'] as String,
      limitType: TreasuryLimitType.fromCode(json['limit_type'] as String),
      limitValue: (json['limit_value'] as num).toDouble(),
      warningThreshold: (json['warning_threshold'] as num).toDouble(),
      criticalThreshold: (json['critical_threshold'] as num).toDouble(),
      isEnabled: json['is_enabled'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      createdBy: json['created_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'treasury_id': treasuryId,
      'limit_type': limitType.code,
      'limit_value': limitValue,
      'warning_threshold': warningThreshold,
      'critical_threshold': criticalThreshold,
      'is_enabled': isEnabled,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'created_by': createdBy,
    };
  }

  TreasuryLimit copyWith({
    String? id,
    String? treasuryId,
    TreasuryLimitType? limitType,
    double? limitValue,
    double? warningThreshold,
    double? criticalThreshold,
    bool? isEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return TreasuryLimit(
      id: id ?? this.id,
      treasuryId: treasuryId ?? this.treasuryId,
      limitType: limitType ?? this.limitType,
      limitValue: limitValue ?? this.limitValue,
      warningThreshold: warningThreshold ?? this.warningThreshold,
      criticalThreshold: criticalThreshold ?? this.criticalThreshold,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}

/// Treasury Alert Type Enum
enum TreasuryAlertType {
  balanceLow('balance_low', 'رصيد منخفض'),
  balanceHigh('balance_high', 'رصيد مرتفع'),
  transactionLimit('transaction_limit', 'حد المعاملات'),
  exchangeRateChange('exchange_rate_change', 'تغيير سعر الصرف');

  const TreasuryAlertType(this.code, this.nameAr);

  final String code;
  final String nameAr;

  static TreasuryAlertType fromCode(String code) {
    return TreasuryAlertType.values.firstWhere(
      (type) => type.code == code,
      orElse: () => TreasuryAlertType.balanceLow,
    );
  }
}

/// Treasury Alert Severity Enum
enum TreasuryAlertSeverity {
  info('info', 'معلومات'),
  warning('warning', 'تحذير'),
  critical('critical', 'حرج'),
  error('error', 'خطأ');

  const TreasuryAlertSeverity(this.code, this.nameAr);

  final String code;
  final String nameAr;

  static TreasuryAlertSeverity fromCode(String code) {
    return TreasuryAlertSeverity.values.firstWhere(
      (severity) => severity.code == code,
      orElse: () => TreasuryAlertSeverity.warning,
    );
  }
}

/// Treasury Alert Model
class TreasuryAlert {
  final String id;
  final String treasuryId;
  final String? treasuryName;
  final TreasuryAlertType alertType;
  final TreasuryAlertSeverity severity;
  final String title;
  final String message;
  final double? currentValue;
  final double? limitValue;
  final double? thresholdPercentage;
  final bool isAcknowledged;
  final DateTime? acknowledgedAt;
  final String? acknowledgedBy;
  final DateTime createdAt;

  const TreasuryAlert({
    required this.id,
    required this.treasuryId,
    this.treasuryName,
    required this.alertType,
    required this.severity,
    required this.title,
    required this.message,
    this.currentValue,
    this.limitValue,
    this.thresholdPercentage,
    required this.isAcknowledged,
    this.acknowledgedAt,
    this.acknowledgedBy,
    required this.createdAt,
  });

  factory TreasuryAlert.fromJson(Map<String, dynamic> json) {
    return TreasuryAlert(
      id: json['id'] as String,
      treasuryId: json['treasury_id'] as String,
      treasuryName: json['treasury_name'] as String?,
      alertType: TreasuryAlertType.fromCode(json['alert_type'] as String),
      severity: TreasuryAlertSeverity.fromCode(json['severity'] as String),
      title: json['title'] as String,
      message: json['message'] as String,
      currentValue: (json['current_value'] as num?)?.toDouble(),
      limitValue: (json['limit_value'] as num?)?.toDouble(),
      thresholdPercentage: (json['threshold_percentage'] as num?)?.toDouble(),
      isAcknowledged: json['is_acknowledged'] as bool,
      acknowledgedAt: json['acknowledged_at'] != null
          ? DateTime.parse(json['acknowledged_at'] as String)
          : null,
      acknowledgedBy: json['acknowledged_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'treasury_id': treasuryId,
      'treasury_name': treasuryName,
      'alert_type': alertType.code,
      'severity': severity.code,
      'title': title,
      'message': message,
      'current_value': currentValue,
      'limit_value': limitValue,
      'threshold_percentage': thresholdPercentage,
      'is_acknowledged': isAcknowledged,
      'acknowledged_at': acknowledgedAt?.toIso8601String(),
      'acknowledged_by': acknowledgedBy,
      'created_at': createdAt.toIso8601String(),
    };
  }

  TreasuryAlert copyWith({
    String? id,
    String? treasuryId,
    String? treasuryName,
    TreasuryAlertType? alertType,
    TreasuryAlertSeverity? severity,
    String? title,
    String? message,
    double? currentValue,
    double? limitValue,
    double? thresholdPercentage,
    bool? isAcknowledged,
    DateTime? acknowledgedAt,
    String? acknowledgedBy,
    DateTime? createdAt,
  }) {
    return TreasuryAlert(
      id: id ?? this.id,
      treasuryId: treasuryId ?? this.treasuryId,
      treasuryName: treasuryName ?? this.treasuryName,
      alertType: alertType ?? this.alertType,
      severity: severity ?? this.severity,
      title: title ?? this.title,
      message: message ?? this.message,
      currentValue: currentValue ?? this.currentValue,
      limitValue: limitValue ?? this.limitValue,
      thresholdPercentage: thresholdPercentage ?? this.thresholdPercentage,
      isAcknowledged: isAcknowledged ?? this.isAcknowledged,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      acknowledgedBy: acknowledgedBy ?? this.acknowledgedBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Get color based on severity
  Color get severityColor {
    switch (severity) {
      case TreasuryAlertSeverity.info:
        return const Color(0xFF3B82F6); // Blue
      case TreasuryAlertSeverity.warning:
        return const Color(0xFFF59E0B); // Orange
      case TreasuryAlertSeverity.critical:
        return const Color(0xFFEF4444); // Red
      case TreasuryAlertSeverity.error:
        return const Color(0xFFDC2626); // Dark Red
    }
  }

  /// Get icon based on alert type
  IconData get alertIcon {
    switch (alertType) {
      case TreasuryAlertType.balanceLow:
        return Icons.trending_down_rounded;
      case TreasuryAlertType.balanceHigh:
        return Icons.trending_up_rounded;
      case TreasuryAlertType.transactionLimit:
        return Icons.block_rounded;
      case TreasuryAlertType.exchangeRateChange:
        return Icons.currency_exchange_rounded;
    }
  }
}

/// Treasury Backup Type Enum
enum TreasuryBackupType {
  full('full', 'نسخة احتياطية كاملة'),
  incremental('incremental', 'نسخة احتياطية تزايدية'),
  differential('differential', 'نسخة احتياطية تفاضلية');

  const TreasuryBackupType(this.code, this.nameAr);

  final String code;
  final String nameAr;

  static TreasuryBackupType fromCode(String code) {
    return TreasuryBackupType.values.firstWhere(
      (type) => type.code == code,
      orElse: () => TreasuryBackupType.full,
    );
  }
}

/// Treasury Backup Schedule Type Enum
enum TreasuryBackupScheduleType {
  manual('manual', 'يدوي'),
  scheduled('scheduled', 'مجدول');

  const TreasuryBackupScheduleType(this.code, this.nameAr);

  final String code;
  final String nameAr;

  static TreasuryBackupScheduleType fromCode(String code) {
    return TreasuryBackupScheduleType.values.firstWhere(
      (type) => type.code == code,
      orElse: () => TreasuryBackupScheduleType.manual,
    );
  }
}

/// Treasury Backup Frequency Enum
enum TreasuryBackupFrequency {
  daily('daily', 'يومي'),
  weekly('weekly', 'أسبوعي'),
  monthly('monthly', 'شهري');

  const TreasuryBackupFrequency(this.code, this.nameAr);

  final String code;
  final String nameAr;

  static TreasuryBackupFrequency fromCode(String code) {
    return TreasuryBackupFrequency.values.firstWhere(
      (frequency) => frequency.code == code,
      orElse: () => TreasuryBackupFrequency.daily,
    );
  }
}

/// Treasury Backup Status Enum
enum TreasuryBackupStatus {
  pending('pending', 'في الانتظار'),
  inProgress('in_progress', 'قيد التنفيذ'),
  completed('completed', 'مكتمل'),
  failed('failed', 'فشل'),
  expired('expired', 'منتهي الصلاحية');

  const TreasuryBackupStatus(this.code, this.nameAr);

  final String code;
  final String nameAr;

  static TreasuryBackupStatus fromCode(String code) {
    return TreasuryBackupStatus.values.firstWhere(
      (status) => status.code == code,
      orElse: () => TreasuryBackupStatus.pending,
    );
  }

  /// Get color based on status
  Color get statusColor {
    switch (this) {
      case TreasuryBackupStatus.pending:
        return const Color(0xFF6B7280); // Gray
      case TreasuryBackupStatus.inProgress:
        return const Color(0xFF3B82F6); // Blue
      case TreasuryBackupStatus.completed:
        return const Color(0xFF10B981); // Green
      case TreasuryBackupStatus.failed:
        return const Color(0xFFEF4444); // Red
      case TreasuryBackupStatus.expired:
        return const Color(0xFF6B7280); // Gray
    }
  }

  /// Get icon based on status
  IconData get statusIcon {
    switch (this) {
      case TreasuryBackupStatus.pending:
        return Icons.schedule_rounded;
      case TreasuryBackupStatus.inProgress:
        return Icons.sync_rounded;
      case TreasuryBackupStatus.completed:
        return Icons.check_circle_rounded;
      case TreasuryBackupStatus.failed:
        return Icons.error_rounded;
      case TreasuryBackupStatus.expired:
        return Icons.history_rounded;
    }
  }
}

/// Treasury Backup Config Model
class TreasuryBackupConfig {
  final String id;
  final String name;
  final String? description;
  final TreasuryBackupType backupType;
  final TreasuryBackupScheduleType scheduleType;
  final TreasuryBackupFrequency? scheduleFrequency;
  final TimeOfDay? scheduleTime;
  final int? scheduleDayOfWeek;
  final int? scheduleDayOfMonth;
  final bool includeTreasuryVaults;
  final bool includeTransactions;
  final bool includeConnections;
  final bool includeLimits;
  final bool includeAlerts;
  final int retentionDays;
  final bool isEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;

  const TreasuryBackupConfig({
    required this.id,
    required this.name,
    this.description,
    required this.backupType,
    required this.scheduleType,
    this.scheduleFrequency,
    this.scheduleTime,
    this.scheduleDayOfWeek,
    this.scheduleDayOfMonth,
    required this.includeTreasuryVaults,
    required this.includeTransactions,
    required this.includeConnections,
    required this.includeLimits,
    required this.includeAlerts,
    required this.retentionDays,
    required this.isEnabled,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
  });

  factory TreasuryBackupConfig.fromJson(Map<String, dynamic> json) {
    return TreasuryBackupConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      backupType: TreasuryBackupType.fromCode(json['backup_type'] as String),
      scheduleType: TreasuryBackupScheduleType.fromCode(json['schedule_type'] as String),
      scheduleFrequency: json['schedule_frequency'] != null
          ? TreasuryBackupFrequency.fromCode(json['schedule_frequency'] as String)
          : null,
      scheduleTime: json['schedule_time'] != null
          ? _parseTimeOfDay(json['schedule_time'] as String)
          : null,
      scheduleDayOfWeek: json['schedule_day_of_week'] as int?,
      scheduleDayOfMonth: json['schedule_day_of_month'] as int?,
      includeTreasuryVaults: json['include_treasury_vaults'] as bool,
      includeTransactions: json['include_transactions'] as bool,
      includeConnections: json['include_connections'] as bool,
      includeLimits: json['include_limits'] as bool,
      includeAlerts: json['include_alerts'] as bool,
      retentionDays: json['retention_days'] as int,
      isEnabled: json['is_enabled'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      createdBy: json['created_by'] as String?,
    );
  }

  static TimeOfDay _parseTimeOfDay(String timeString) {
    final parts = timeString.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'backup_type': backupType.code,
      'schedule_type': scheduleType.code,
      'schedule_frequency': scheduleFrequency?.code,
      'schedule_time': scheduleTime != null
          ? '${scheduleTime!.hour.toString().padLeft(2, '0')}:${scheduleTime!.minute.toString().padLeft(2, '0')}'
          : null,
      'schedule_day_of_week': scheduleDayOfWeek,
      'schedule_day_of_month': scheduleDayOfMonth,
      'include_treasury_vaults': includeTreasuryVaults,
      'include_transactions': includeTransactions,
      'include_connections': includeConnections,
      'include_limits': includeLimits,
      'include_alerts': includeAlerts,
      'retention_days': retentionDays,
      'is_enabled': isEnabled,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'created_by': createdBy,
    };
  }

  TreasuryBackupConfig copyWith({
    String? id,
    String? name,
    String? description,
    TreasuryBackupType? backupType,
    TreasuryBackupScheduleType? scheduleType,
    TreasuryBackupFrequency? scheduleFrequency,
    TimeOfDay? scheduleTime,
    int? scheduleDayOfWeek,
    int? scheduleDayOfMonth,
    bool? includeTreasuryVaults,
    bool? includeTransactions,
    bool? includeConnections,
    bool? includeLimits,
    bool? includeAlerts,
    int? retentionDays,
    bool? isEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return TreasuryBackupConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      backupType: backupType ?? this.backupType,
      scheduleType: scheduleType ?? this.scheduleType,
      scheduleFrequency: scheduleFrequency ?? this.scheduleFrequency,
      scheduleTime: scheduleTime ?? this.scheduleTime,
      scheduleDayOfWeek: scheduleDayOfWeek ?? this.scheduleDayOfWeek,
      scheduleDayOfMonth: scheduleDayOfMonth ?? this.scheduleDayOfMonth,
      includeTreasuryVaults: includeTreasuryVaults ?? this.includeTreasuryVaults,
      includeTransactions: includeTransactions ?? this.includeTransactions,
      includeConnections: includeConnections ?? this.includeConnections,
      includeLimits: includeLimits ?? this.includeLimits,
      includeAlerts: includeAlerts ?? this.includeAlerts,
      retentionDays: retentionDays ?? this.retentionDays,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  /// Get next scheduled backup time
  DateTime? getNextScheduledTime() {
    if (scheduleType != TreasuryBackupScheduleType.scheduled || scheduleFrequency == null) {
      return null;
    }

    final now = DateTime.now();
    DateTime nextTime;

    switch (scheduleFrequency!) {
      case TreasuryBackupFrequency.daily:
        nextTime = DateTime(
          now.year,
          now.month,
          now.day,
          scheduleTime?.hour ?? 0,
          scheduleTime?.minute ?? 0,
        );
        if (nextTime.isBefore(now)) {
          nextTime = nextTime.add(const Duration(days: 1));
        }
        break;

      case TreasuryBackupFrequency.weekly:
        final targetDayOfWeek = scheduleDayOfWeek ?? 0;
        final currentDayOfWeek = now.weekday % 7; // Convert to 0-6 format
        int daysUntilTarget = (targetDayOfWeek - currentDayOfWeek) % 7;
        if (daysUntilTarget == 0 && now.hour >= (scheduleTime?.hour ?? 0)) {
          daysUntilTarget = 7; // Next week
        }
        nextTime = DateTime(
          now.year,
          now.month,
          now.day + daysUntilTarget,
          scheduleTime?.hour ?? 0,
          scheduleTime?.minute ?? 0,
        );
        break;

      case TreasuryBackupFrequency.monthly:
        final targetDay = scheduleDayOfMonth ?? 1;
        nextTime = DateTime(
          now.year,
          now.month,
          targetDay,
          scheduleTime?.hour ?? 0,
          scheduleTime?.minute ?? 0,
        );
        if (nextTime.isBefore(now)) {
          nextTime = DateTime(
            now.year,
            now.month + 1,
            targetDay,
            scheduleTime?.hour ?? 0,
            scheduleTime?.minute ?? 0,
          );
        }
        break;
    }

    return nextTime;
  }
}

/// Treasury Backup Model
class TreasuryBackup {
  final String id;
  final String? configId;
  final String backupName;
  final TreasuryBackupType backupType;
  final String? filePath;
  final int? fileSize;
  final TreasuryBackupStatus backupStatus;
  final Map<String, dynamic>? backupData;
  final String? compressionType;
  final String? checksum;
  final DateTime startedAt;
  final DateTime? completedAt;
  final String? errorMessage;
  final String? createdBy;

  const TreasuryBackup({
    required this.id,
    this.configId,
    required this.backupName,
    required this.backupType,
    this.filePath,
    this.fileSize,
    required this.backupStatus,
    this.backupData,
    this.compressionType,
    this.checksum,
    required this.startedAt,
    this.completedAt,
    this.errorMessage,
    this.createdBy,
  });

  factory TreasuryBackup.fromJson(Map<String, dynamic> json) {
    return TreasuryBackup(
      id: json['id'] as String,
      configId: json['config_id'] as String?,
      backupName: json['backup_name'] as String,
      backupType: TreasuryBackupType.fromCode(json['backup_type'] as String),
      filePath: json['file_path'] as String?,
      fileSize: json['file_size'] as int?,
      backupStatus: TreasuryBackupStatus.fromCode(json['backup_status'] as String),
      backupData: json['backup_data'] as Map<String, dynamic>?,
      compressionType: json['compression_type'] as String?,
      checksum: json['checksum'] as String?,
      startedAt: DateTime.parse(json['started_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      errorMessage: json['error_message'] as String?,
      createdBy: json['created_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'config_id': configId,
      'backup_name': backupName,
      'backup_type': backupType.code,
      'file_path': filePath,
      'file_size': fileSize,
      'backup_status': backupStatus.code,
      'backup_data': backupData,
      'compression_type': compressionType,
      'checksum': checksum,
      'started_at': startedAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'error_message': errorMessage,
      'created_by': createdBy,
    };
  }

  TreasuryBackup copyWith({
    String? id,
    String? configId,
    String? backupName,
    TreasuryBackupType? backupType,
    String? filePath,
    int? fileSize,
    TreasuryBackupStatus? backupStatus,
    Map<String, dynamic>? backupData,
    String? compressionType,
    String? checksum,
    DateTime? startedAt,
    DateTime? completedAt,
    String? errorMessage,
    String? createdBy,
  }) {
    return TreasuryBackup(
      id: id ?? this.id,
      configId: configId ?? this.configId,
      backupName: backupName ?? this.backupName,
      backupType: backupType ?? this.backupType,
      filePath: filePath ?? this.filePath,
      fileSize: fileSize ?? this.fileSize,
      backupStatus: backupStatus ?? this.backupStatus,
      backupData: backupData ?? this.backupData,
      compressionType: compressionType ?? this.compressionType,
      checksum: checksum ?? this.checksum,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      errorMessage: errorMessage ?? this.errorMessage,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  /// Get formatted file size
  String get formattedFileSize {
    if (fileSize == null) return 'غير محدد';

    const units = ['B', 'KB', 'MB', 'GB'];
    double size = fileSize!.toDouble();
    int unitIndex = 0;

    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }

    return '${size.toStringAsFixed(1)} ${units[unitIndex]}';
  }

  /// Get backup duration
  Duration? get backupDuration {
    if (completedAt == null) return null;
    return completedAt!.difference(startedAt);
  }

  /// Get formatted backup duration
  String get formattedDuration {
    final duration = backupDuration;
    if (duration == null) return 'غير مكتمل';

    if (duration.inHours > 0) {
      return '${duration.inHours}س ${duration.inMinutes % 60}د';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}د ${duration.inSeconds % 60}ث';
    } else {
      return '${duration.inSeconds}ث';
    }
  }

  /// Check if backup is restorable
  bool get isRestorable {
    return backupStatus == TreasuryBackupStatus.completed &&
           (backupData != null || filePath != null);
  }
}

/// Treasury Audit Entity Type Enum
enum TreasuryAuditEntityType {
  treasuryVault('treasury_vault', 'خزنة'),
  treasuryTransaction('treasury_transaction', 'معاملة'),
  treasuryConnection('treasury_connection', 'اتصال'),
  treasuryLimit('treasury_limit', 'حد'),
  treasuryAlert('treasury_alert', 'تنبيه'),
  treasuryBackup('treasury_backup', 'نسخة احتياطية'),
  fundTransfer('fund_transfer', 'تحويل أموال'),
  userSession('user_session', 'جلسة مستخدم'),
  systemEvent('system_event', 'حدث نظام');

  const TreasuryAuditEntityType(this.code, this.nameAr);

  final String code;
  final String nameAr;

  static TreasuryAuditEntityType fromCode(String code) {
    return TreasuryAuditEntityType.values.firstWhere(
      (type) => type.code == code,
      orElse: () => TreasuryAuditEntityType.systemEvent,
    );
  }
}

/// Treasury Audit Action Type Enum
enum TreasuryAuditActionType {
  create('create', 'إنشاء'),
  update('update', 'تحديث'),
  delete('delete', 'حذف'),
  view('view', 'عرض'),
  export('export', 'تصدير'),
  import('import', 'استيراد'),
  transfer('transfer', 'تحويل'),
  backup('backup', 'نسخ احتياطي'),
  restore('restore', 'استعادة'),
  login('login', 'تسجيل دخول'),
  logout('logout', 'تسجيل خروج'),
  error('error', 'خطأ');

  const TreasuryAuditActionType(this.code, this.nameAr);

  final String code;
  final String nameAr;

  static TreasuryAuditActionType fromCode(String code) {
    return TreasuryAuditActionType.values.firstWhere(
      (type) => type.code == code,
      orElse: () => TreasuryAuditActionType.view,
    );
  }
}

/// Treasury Audit Severity Enum
enum TreasuryAuditSeverity {
  debug('debug', 'تصحيح'),
  info('info', 'معلومات'),
  warning('warning', 'تحذير'),
  error('error', 'خطأ'),
  critical('critical', 'حرج');

  const TreasuryAuditSeverity(this.code, this.nameAr);

  final String code;
  final String nameAr;

  static TreasuryAuditSeverity fromCode(String code) {
    return TreasuryAuditSeverity.values.firstWhere(
      (severity) => severity.code == code,
      orElse: () => TreasuryAuditSeverity.info,
    );
  }

  /// Get color based on severity
  Color get severityColor {
    switch (this) {
      case TreasuryAuditSeverity.debug:
        return const Color(0xFF6B7280); // Gray
      case TreasuryAuditSeverity.info:
        return const Color(0xFF3B82F6); // Blue
      case TreasuryAuditSeverity.warning:
        return const Color(0xFFF59E0B); // Orange
      case TreasuryAuditSeverity.error:
        return const Color(0xFFEF4444); // Red
      case TreasuryAuditSeverity.critical:
        return const Color(0xFFDC2626); // Dark Red
    }
  }

  /// Get icon based on severity
  IconData get severityIcon {
    switch (this) {
      case TreasuryAuditSeverity.debug:
        return Icons.bug_report_rounded;
      case TreasuryAuditSeverity.info:
        return Icons.info_rounded;
      case TreasuryAuditSeverity.warning:
        return Icons.warning_rounded;
      case TreasuryAuditSeverity.error:
        return Icons.error_rounded;
      case TreasuryAuditSeverity.critical:
        return Icons.dangerous_rounded;
    }
  }
}

/// Treasury Audit Log Model
class TreasuryAuditLog {
  final String id;
  final TreasuryAuditEntityType entityType;
  final String? entityId;
  final TreasuryAuditActionType actionType;
  final String actionDescription;
  final String? userId;
  final String? userEmail;
  final String? userRole;
  final String? ipAddress;
  final String? userAgent;
  final String? sessionId;
  final Map<String, dynamic>? oldValues;
  final Map<String, dynamic>? newValues;
  final Map<String, dynamic>? changesSummary;
  final Map<String, dynamic>? metadata;
  final TreasuryAuditSeverity severity;
  final List<String> tags;
  final DateTime createdAt;

  const TreasuryAuditLog({
    required this.id,
    required this.entityType,
    this.entityId,
    required this.actionType,
    required this.actionDescription,
    this.userId,
    this.userEmail,
    this.userRole,
    this.ipAddress,
    this.userAgent,
    this.sessionId,
    this.oldValues,
    this.newValues,
    this.changesSummary,
    this.metadata,
    required this.severity,
    required this.tags,
    required this.createdAt,
  });

  factory TreasuryAuditLog.fromJson(Map<String, dynamic> json) {
    return TreasuryAuditLog(
      id: json['id'] as String,
      entityType: TreasuryAuditEntityType.fromCode(json['entity_type'] as String),
      entityId: json['entity_id'] as String?,
      actionType: TreasuryAuditActionType.fromCode(json['action_type'] as String),
      actionDescription: json['action_description'] as String,
      userId: json['user_id'] as String?,
      userEmail: json['user_email'] as String?,
      userRole: json['user_role'] as String?,
      ipAddress: json['ip_address'] as String?,
      userAgent: json['user_agent'] as String?,
      sessionId: json['session_id'] as String?,
      oldValues: json['old_values'] as Map<String, dynamic>?,
      newValues: json['new_values'] as Map<String, dynamic>?,
      changesSummary: json['changes_summary'] as Map<String, dynamic>?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      severity: TreasuryAuditSeverity.fromCode(json['severity'] as String),
      tags: List<String>.from(json['tags'] as List? ?? []),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entity_type': entityType.code,
      'entity_id': entityId,
      'action_type': actionType.code,
      'action_description': actionDescription,
      'user_id': userId,
      'user_email': userEmail,
      'user_role': userRole,
      'ip_address': ipAddress,
      'user_agent': userAgent,
      'session_id': sessionId,
      'old_values': oldValues,
      'new_values': newValues,
      'changes_summary': changesSummary,
      'metadata': metadata,
      'severity': severity.code,
      'tags': tags,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Get formatted time ago
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return 'منذ ${difference.inDays} يوم';
    } else if (difference.inHours > 0) {
      return 'منذ ${difference.inHours} ساعة';
    } else if (difference.inMinutes > 0) {
      return 'منذ ${difference.inMinutes} دقيقة';
    } else {
      return 'الآن';
    }
  }

  /// Get changes count
  int get changesCount {
    return changesSummary?.length ?? 0;
  }

  /// Check if has changes
  bool get hasChanges {
    return changesSummary != null && changesSummary!.isNotEmpty;
  }

  /// Get action icon
  IconData get actionIcon {
    switch (actionType) {
      case TreasuryAuditActionType.create:
        return Icons.add_circle_rounded;
      case TreasuryAuditActionType.update:
        return Icons.edit_rounded;
      case TreasuryAuditActionType.delete:
        return Icons.delete_rounded;
      case TreasuryAuditActionType.view:
        return Icons.visibility_rounded;
      case TreasuryAuditActionType.export:
        return Icons.download_rounded;
      case TreasuryAuditActionType.import:
        return Icons.upload_rounded;
      case TreasuryAuditActionType.transfer:
        return Icons.swap_horiz_rounded;
      case TreasuryAuditActionType.backup:
        return Icons.backup_rounded;
      case TreasuryAuditActionType.restore:
        return Icons.restore_rounded;
      case TreasuryAuditActionType.login:
        return Icons.login_rounded;
      case TreasuryAuditActionType.logout:
        return Icons.logout_rounded;
      case TreasuryAuditActionType.error:
        return Icons.error_rounded;
    }
  }
}
