/// Electronic payment status enumeration
enum ElectronicPaymentStatus {
  pending,
  approved,
  rejected,
}

/// Electronic payment method enumeration
enum ElectronicPaymentMethod {
  vodafoneCash,
  instaPay,
}

/// Electronic payment model for tracking payment requests
class ElectronicPaymentModel {

  const ElectronicPaymentModel({
    required this.id,
    required this.clientId,
    required this.paymentMethod,
    required this.amount,
    this.proofImageUrl,
    required this.recipientAccountId,
    this.status = ElectronicPaymentStatus.pending,
    this.adminNotes,
    required this.createdAt,
    required this.updatedAt,
    this.approvedBy,
    this.approvedAt,
    this.metadata,
    this.clientName,
    this.clientEmail,
    this.clientPhone,
    this.approvedByName,
    this.recipientAccountNumber,
    this.recipientAccountHolderName,
  });

  /// Create from database JSON
  factory ElectronicPaymentModel.fromDatabase(Map<String, dynamic> json) {
    return ElectronicPaymentModel(
      id: json['id'] as String,
      clientId: json['client_id'] as String,
      paymentMethod: _parsePaymentMethod(json['payment_method'] as String),
      amount: (json['amount'] as num).toDouble(),
      proofImageUrl: json['proof_image_url'] as String?,
      recipientAccountId: json['recipient_account_id'] as String,
      status: _parseStatus(json['status'] as String? ?? 'pending'),
      adminNotes: json['admin_notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      approvedBy: json['approved_by'] as String?,
      approvedAt: json['approved_at'] != null 
          ? DateTime.parse(json['approved_at'] as String)
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
      clientName: json['client_name'] as String?,
      clientEmail: json['client_email'] as String?,
      clientPhone: json['client_phone'] as String?,
      approvedByName: json['approved_by_name'] as String?,
      recipientAccountNumber: json['recipient_account_number'] as String?,
      recipientAccountHolderName: json['recipient_account_holder_name'] as String?,
    );
  }

  /// Create from JSON
  factory ElectronicPaymentModel.fromJson(Map<String, dynamic> json) {
    return ElectronicPaymentModel.fromDatabase(json);
  }
  final String id;
  final String clientId;
  final ElectronicPaymentMethod paymentMethod;
  final double amount;
  final String? proofImageUrl;
  final String recipientAccountId;
  final ElectronicPaymentStatus status;
  final String? adminNotes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? approvedBy;
  final DateTime? approvedAt;
  final Map<String, dynamic>? metadata;

  // Additional fields from joins
  final String? clientName;
  final String? clientEmail;
  final String? clientPhone;
  final String? approvedByName;
  final String? recipientAccountNumber;
  final String? recipientAccountHolderName;

  /// Convert to database JSON
  Map<String, dynamic> toDatabase() {
    return {
      'id': id,
      'client_id': clientId,
      'payment_method': _paymentMethodToString(paymentMethod),
      'amount': amount,
      'proof_image_url': proofImageUrl,
      'recipient_account_id': recipientAccountId,
      'status': _statusToString(status),
      'admin_notes': adminNotes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'approved_by': approvedBy,
      'approved_at': approvedAt?.toIso8601String(),
      'metadata': metadata,
    };
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() => toDatabase();

  /// Parse payment method from string
  static ElectronicPaymentMethod _parsePaymentMethod(String method) {
    switch (method) {
      case 'vodafone_cash':
        return ElectronicPaymentMethod.vodafoneCash;
      case 'instapay':
        return ElectronicPaymentMethod.instaPay;
      default:
        throw ArgumentError('Unknown payment method: $method');
    }
  }

  /// Convert payment method to string
  static String _paymentMethodToString(ElectronicPaymentMethod method) {
    switch (method) {
      case ElectronicPaymentMethod.vodafoneCash:
        return 'vodafone_cash';
      case ElectronicPaymentMethod.instaPay:
        return 'instapay';
    }
  }

  /// Parse status from string
  static ElectronicPaymentStatus _parseStatus(String status) {
    switch (status) {
      case 'pending':
        return ElectronicPaymentStatus.pending;
      case 'approved':
        return ElectronicPaymentStatus.approved;
      case 'rejected':
        return ElectronicPaymentStatus.rejected;
      default:
        return ElectronicPaymentStatus.pending;
    }
  }

  /// Convert status to string
  static String _statusToString(ElectronicPaymentStatus status) {
    switch (status) {
      case ElectronicPaymentStatus.pending:
        return 'pending';
      case ElectronicPaymentStatus.approved:
        return 'approved';
      case ElectronicPaymentStatus.rejected:
        return 'rejected';
    }
  }

  /// Get display name for payment method
  String get paymentMethodDisplayName {
    switch (paymentMethod) {
      case ElectronicPaymentMethod.vodafoneCash:
        return 'فودافون كاش';
      case ElectronicPaymentMethod.instaPay:
        return 'إنستاباي';
    }
  }

  /// Get display name for status
  String get statusDisplayName {
    switch (status) {
      case ElectronicPaymentStatus.pending:
        return 'قيد المراجعة';
      case ElectronicPaymentStatus.approved:
        return 'مقبول';
      case ElectronicPaymentStatus.rejected:
        return 'مرفوض';
    }
  }

  /// Get icon for payment method
  String get paymentMethodIcon {
    switch (paymentMethod) {
      case ElectronicPaymentMethod.vodafoneCash:
        return '🟥';
      case ElectronicPaymentMethod.instaPay:
        return '🟦';
    }
  }

  /// Get color for status
  String get statusColor {
    switch (status) {
      case ElectronicPaymentStatus.pending:
        return '#F59E0B'; // Yellow
      case ElectronicPaymentStatus.approved:
        return '#10B981'; // Green
      case ElectronicPaymentStatus.rejected:
        return '#EF4444'; // Red
    }
  }

  /// Get formatted amount with currency
  String get formattedAmount {
    return '${amount.toStringAsFixed(2)} ج.م';
  }

  /// Get payment account ID (alias for recipientAccountId)
  String get paymentAccountId => recipientAccountId;

  /// Get description (alias for adminNotes)
  String? get description => adminNotes;

  /// Create a copy with updated fields
  ElectronicPaymentModel copyWith({
    String? id,
    String? clientId,
    ElectronicPaymentMethod? paymentMethod,
    double? amount,
    String? proofImageUrl,
    String? recipientAccountId,
    ElectronicPaymentStatus? status,
    String? adminNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? approvedBy,
    DateTime? approvedAt,
    Map<String, dynamic>? metadata,
    String? clientName,
    String? clientEmail,
    String? clientPhone,
    String? approvedByName,
    String? recipientAccountNumber,
    String? recipientAccountHolderName,
  }) {
    return ElectronicPaymentModel(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      amount: amount ?? this.amount,
      proofImageUrl: proofImageUrl ?? this.proofImageUrl,
      recipientAccountId: recipientAccountId ?? this.recipientAccountId,
      status: status ?? this.status,
      adminNotes: adminNotes ?? this.adminNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      metadata: metadata ?? this.metadata,
      clientName: clientName ?? this.clientName,
      clientEmail: clientEmail ?? this.clientEmail,
      clientPhone: clientPhone ?? this.clientPhone,
      approvedByName: approvedByName ?? this.approvedByName,
      recipientAccountNumber: recipientAccountNumber ?? this.recipientAccountNumber,
      recipientAccountHolderName: recipientAccountHolderName ?? this.recipientAccountHolderName,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ElectronicPaymentModel &&
        other.id == id &&
        other.clientId == clientId &&
        other.paymentMethod == paymentMethod &&
        other.amount == amount &&
        other.proofImageUrl == proofImageUrl &&
        other.recipientAccountId == recipientAccountId &&
        other.status == status &&
        other.adminNotes == adminNotes &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.approvedBy == approvedBy &&
        other.approvedAt == approvedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      clientId,
      paymentMethod,
      amount,
      proofImageUrl,
      recipientAccountId,
      status,
      adminNotes,
      createdAt,
      updatedAt,
      approvedBy,
      approvedAt,
    );
  }

  @override
  String toString() {
    return 'ElectronicPaymentModel(id: $id, clientId: $clientId, paymentMethod: $paymentMethod, amount: $amount, status: $status)';
  }
}
