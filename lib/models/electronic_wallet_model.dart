/// Electronic wallet type enumeration
enum ElectronicWalletType {
  vodafoneCash,
  instaPay,
}

/// Electronic wallet status enumeration
enum ElectronicWalletStatus {
  active,
  inactive,
  suspended,
}

/// Electronic wallet model for managing company wallets
class ElectronicWalletModel {

  const ElectronicWalletModel({
    required this.id,
    required this.walletType,
    required this.phoneNumber,
    required this.walletName,
    this.currentBalance = 0.0,
    this.status = ElectronicWalletStatus.active,
    this.description,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.metadata,
  });

  /// Create from database JSON
  factory ElectronicWalletModel.fromDatabase(Map<String, dynamic> json) {
    return ElectronicWalletModel(
      id: json['id'] as String,
      walletType: _parseWalletType(json['wallet_type'] as String),
      phoneNumber: json['phone_number'] as String,
      walletName: json['wallet_name'] as String,
      currentBalance: (json['current_balance'] as num?)?.toDouble() ?? 0.0,
      status: _parseStatus(json['status'] as String? ?? 'active'),
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      createdBy: json['created_by'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Create from JSON
  factory ElectronicWalletModel.fromJson(Map<String, dynamic> json) {
    return ElectronicWalletModel.fromDatabase(json);
  }
  final String id;
  final ElectronicWalletType walletType;
  final String phoneNumber;
  final String walletName;
  final double currentBalance;
  final ElectronicWalletStatus status;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final Map<String, dynamic>? metadata;

  /// Convert to database JSON
  Map<String, dynamic> toDatabase() {
    return {
      'id': id,
      'wallet_type': _walletTypeToString(walletType),
      'phone_number': phoneNumber,
      'wallet_name': walletName,
      'current_balance': currentBalance,
      'status': _statusToString(status),
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'created_by': createdBy,
      'metadata': metadata,
    };
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() => toDatabase();

  /// Parse wallet type from string
  static ElectronicWalletType _parseWalletType(String type) {
    switch (type) {
      case 'vodafone_cash':
        return ElectronicWalletType.vodafoneCash;
      case 'instapay':
        return ElectronicWalletType.instaPay;
      default:
        throw ArgumentError('Unknown wallet type: $type');
    }
  }

  /// Convert wallet type to string
  static String _walletTypeToString(ElectronicWalletType type) {
    switch (type) {
      case ElectronicWalletType.vodafoneCash:
        return 'vodafone_cash';
      case ElectronicWalletType.instaPay:
        return 'instapay';
    }
  }

  /// Parse status from string
  static ElectronicWalletStatus _parseStatus(String status) {
    switch (status) {
      case 'active':
        return ElectronicWalletStatus.active;
      case 'inactive':
        return ElectronicWalletStatus.inactive;
      case 'suspended':
        return ElectronicWalletStatus.suspended;
      default:
        return ElectronicWalletStatus.active;
    }
  }

  /// Convert status to string
  static String _statusToString(ElectronicWalletStatus status) {
    switch (status) {
      case ElectronicWalletStatus.active:
        return 'active';
      case ElectronicWalletStatus.inactive:
        return 'inactive';
      case ElectronicWalletStatus.suspended:
        return 'suspended';
    }
  }

  /// Get display name for wallet type
  String get walletTypeDisplayName {
    switch (walletType) {
      case ElectronicWalletType.vodafoneCash:
        return 'فودافون كاش';
      case ElectronicWalletType.instaPay:
        return 'إنستاباي';
    }
  }

  /// Get display name for status
  String get statusDisplayName {
    switch (status) {
      case ElectronicWalletStatus.active:
        return 'نشط';
      case ElectronicWalletStatus.inactive:
        return 'غير نشط';
      case ElectronicWalletStatus.suspended:
        return 'معلق';
    }
  }

  /// Get icon for wallet type
  String get walletTypeIcon {
    switch (walletType) {
      case ElectronicWalletType.vodafoneCash:
        return '📱';
      case ElectronicWalletType.instaPay:
        return '💳';
    }
  }

  /// Get color for wallet type
  int get walletTypeColor {
    switch (walletType) {
      case ElectronicWalletType.vodafoneCash:
        return 0xFFE60012; // Vodafone Red
      case ElectronicWalletType.instaPay:
        return 0xFF1E88E5; // InstaPay Blue
    }
  }

  /// Get formatted balance
  String get formattedBalance {
    return '${currentBalance.toStringAsFixed(2)} ج.م';
  }

  /// Get formatted phone number with proper RTL support
  String get formattedPhoneNumber {
    if (phoneNumber.length == 11 && phoneNumber.startsWith('01')) {
      // Format: 0123 456 7890 (proper RTL reading order)
      return '${phoneNumber.substring(0, 4)} ${phoneNumber.substring(4, 7)} ${phoneNumber.substring(7)}';
    }
    return phoneNumber;
  }

  /// Get formatted phone number with RTL text direction marker
  String get formattedPhoneNumberRTL {
    // Add RTL mark to ensure proper display direction
    const String rtlMark = '\u202B'; // Right-to-Left Mark
    const String ltrMark = '\u202A'; // Left-to-Right Mark
    const String popMark = '\u202C'; // Pop Directional Formatting

    if (phoneNumber.length == 11 && phoneNumber.startsWith('01')) {
      // Format with proper RTL markers for Arabic interfaces
      final formatted = '${phoneNumber.substring(0, 4)} ${phoneNumber.substring(4, 7)} ${phoneNumber.substring(7)}';
      return '$ltrMark$formatted$popMark';
    }
    return '$ltrMark$phoneNumber$popMark';
  }

  /// Check if wallet is active
  bool get isActive => status == ElectronicWalletStatus.active;

  /// Check if wallet can receive payments
  bool get canReceivePayments => status == ElectronicWalletStatus.active;

  /// Validate Egyptian phone number
  static bool isValidEgyptianPhoneNumber(String phoneNumber) {
    // Remove any spaces or special characters
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    // Check if it's a valid Egyptian mobile number
    if (cleanNumber.length == 11 && cleanNumber.startsWith('01')) {
      final prefix = cleanNumber.substring(0, 3);
      return ['010', '011', '012', '015'].contains(prefix);
    }
    
    return false;
  }

  /// Create a copy with updated fields
  ElectronicWalletModel copyWith({
    String? id,
    ElectronicWalletType? walletType,
    String? phoneNumber,
    String? walletName,
    double? currentBalance,
    ElectronicWalletStatus? status,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    Map<String, dynamic>? metadata,
  }) {
    return ElectronicWalletModel(
      id: id ?? this.id,
      walletType: walletType ?? this.walletType,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      walletName: walletName ?? this.walletName,
      currentBalance: currentBalance ?? this.currentBalance,
      status: status ?? this.status,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ElectronicWalletModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ElectronicWalletModel(id: $id, walletType: $walletType, phoneNumber: $phoneNumber, walletName: $walletName, currentBalance: $currentBalance, status: $status)';
  }
}
