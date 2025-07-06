import 'package:flutter/foundation.dart';
import 'voucher_model.dart';

/// Enum for client voucher status
enum ClientVoucherStatus {
  active,
  used,
  expired;

  String get value {
    switch (this) {
      case ClientVoucherStatus.active:
        return 'active';
      case ClientVoucherStatus.used:
        return 'used';
      case ClientVoucherStatus.expired:
        return 'expired';
    }
  }

  static ClientVoucherStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'active':
        return ClientVoucherStatus.active;
      case 'used':
        return ClientVoucherStatus.used;
      case 'expired':
        return ClientVoucherStatus.expired;
      default:
        throw ArgumentError('Invalid client voucher status: $value');
    }
  }

  String get displayName {
    switch (this) {
      case ClientVoucherStatus.active:
        return 'نشط';
      case ClientVoucherStatus.used:
        return 'مستخدم';
      case ClientVoucherStatus.expired:
        return 'منتهي الصلاحية';
    }
  }

  String get color {
    switch (this) {
      case ClientVoucherStatus.active:
        return 'green';
      case ClientVoucherStatus.used:
        return 'blue';
      case ClientVoucherStatus.expired:
        return 'red';
    }
  }
}

/// Model class for client voucher assignments
class ClientVoucherModel {

  const ClientVoucherModel({
    required this.id,
    required this.voucherId,
    required this.clientId,
    required this.status,
    this.usedAt,
    this.orderId,
    required this.discountAmount,
    required this.assignedBy,
    required this.assignedAt,
    required this.createdAt,
    required this.updatedAt,
    this.metadata,
    this.voucher,
    this.clientName,
    this.clientEmail,
    this.assignedByName,
  });

  /// Create client voucher from JSON response with null safety
  factory ClientVoucherModel.fromJson(Map<String, dynamic> json) {
    try {
      // Validate essential fields
      final id = json['id']?.toString();
      final voucherId = json['voucher_id']?.toString();
      final clientId = json['client_id']?.toString();

      if (id == null || id.isEmpty) {
        throw Exception('Client voucher ID is required but was null or empty');
      }
      if (voucherId == null || voucherId.isEmpty) {
        throw Exception('Voucher ID is required but was null or empty');
      }
      if (clientId == null || clientId.isEmpty) {
        throw Exception('Client ID is required but was null or empty');
      }

      // Safely parse voucher data
      VoucherModel? voucher;
      if (json['vouchers'] != null) {
        try {
          final voucherData = json['vouchers'];
          if (voucherData is Map<String, dynamic>) {
            voucher = VoucherModel.fromJson(voucherData);
          }
        } catch (e) {
          // Log warning for failed voucher data parsing
          voucher = null;
        }
      }

      return ClientVoucherModel(
        id: id,
        voucherId: voucherId,
        clientId: clientId,
        status: ClientVoucherStatus.fromString(json['status']?.toString() ?? 'active'),
        usedAt: json['used_at'] != null ? DateTime.tryParse(json['used_at'].toString()) : null,
        orderId: json['order_id']?.toString(),
        discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0.0,
        assignedBy: json['assigned_by']?.toString() ?? '',
        assignedAt: json['assigned_at'] != null
            ? DateTime.tryParse(json['assigned_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
        updatedAt: json['updated_at'] != null
            ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
        metadata: json['metadata'] as Map<String, dynamic>?,
        voucher: voucher,
        clientName: json['client_name']?.toString(),
        clientEmail: json['client_email']?.toString(),
        assignedByName: json['assigned_by_name']?.toString(),
      );
    } catch (e) {
      // Log the error and provide fallback values
      // Error parsing ClientVoucherModel from JSON - using fallback values

      // Return a minimal valid object with fallback values
      return ClientVoucherModel(
        id: json['id']?.toString() ?? 'unknown',
        voucherId: json['voucher_id']?.toString() ?? '',
        clientId: json['client_id']?.toString() ?? '',
        status: ClientVoucherStatus.active,
        usedAt: null,
        orderId: null,
        discountAmount: 0.0,
        assignedBy: json['assigned_by']?.toString() ?? '',
        assignedAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: null,
        voucher: null,
        clientName: null,
        clientEmail: null,
        assignedByName: null,
      );
    }
  }
  final String id;
  final String voucherId;
  final String clientId;
  final ClientVoucherStatus status;
  final DateTime? usedAt;
  final String? orderId;
  final double discountAmount;
  final String assignedBy;
  final DateTime assignedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? metadata;

  // Related voucher data (populated when fetched with joins)
  final VoucherModel? voucher;
  final String? clientName;
  final String? clientEmail;
  final String? assignedByName;

  /// Check if voucher can be used
  bool get canBeUsed {
    return status == ClientVoucherStatus.active && 
           (voucher?.isValid ?? true);
  }

  /// Check if voucher is expired
  bool get isExpired {
    return status == ClientVoucherStatus.expired || 
           (voucher?.isExpired ?? false);
  }

  /// Get formatted used date
  String? get formattedUsedDate {
    if (usedAt == null) return null;
    return '${usedAt!.day}/${usedAt!.month}/${usedAt!.year}';
  }

  /// Get formatted assigned date
  String get formattedAssignedDate {
    return '${assignedAt.day}/${assignedAt.month}/${assignedAt.year}';
  }

  /// Get voucher code (from related voucher or safe fallback)
  String get voucherCode {
    if (voucher?.code != null && voucher!.code.isNotEmpty) {
      return voucher!.code;
    }
    // Return a safe fallback for UI rendering
    return 'INVALID-${id.substring(0, 8)}';
  }

  /// Get voucher name (from related voucher or safe fallback)
  String get voucherName {
    if (voucher?.name != null && voucher!.name.isNotEmpty) {
      return voucher!.name;
    }
    // Return a safe fallback for UI rendering
    return 'قسيمة غير صالحة';
  }

  /// Get discount percentage (from related voucher or 0)
  int get discountPercentage {
    return voucher?.discountPercentage ?? 0;
  }

  /// Get voucher type display name
  String get voucherTypeDisplayName {
    return voucher?.type.displayName ?? '';
  }

  /// Get target name (product or category name)
  String get targetName {
    return voucher?.targetName ?? '';
  }

  /// Get expiration date from voucher
  DateTime? get expirationDate {
    return voucher?.expirationDate;
  }

  /// Get formatted expiration date
  String get formattedExpirationDate {
    if (expirationDate == null) return '';
    return '${expirationDate!.day}/${expirationDate!.month}/${expirationDate!.year}';
  }

  /// Check if voucher data is valid and safe for UI rendering
  bool get isVoucherDataValid {
    if (voucher == null) return false;

    // Check basic required fields
    if (voucher!.id.isEmpty ||
        voucher!.code.isEmpty ||
        voucher!.name.isEmpty ||
        voucher!.targetId.isEmpty) {
      return false;
    }

    // Check discount validity based on discount type
    switch (voucher!.discountType) {
      case DiscountType.percentage:
        // For percentage vouchers, discount percentage must be > 0
        return voucher!.discountPercentage > 0;
      case DiscountType.fixedAmount:
        // For fixed amount vouchers, discount amount must be > 0
        // (discount percentage is intentionally 0 for fixed amount vouchers)
        return voucher!.discountAmount != null && voucher!.discountAmount! > 0;
    }
  }

  /// Check if this client voucher is safe to display in UI
  bool get isSafeForUI {
    // Always safe if voucher data is valid
    if (isVoucherDataValid) return true;

    // Safe if it's used/expired (historical data)
    if (status == ClientVoucherStatus.used || status == ClientVoucherStatus.expired) {
      return true;
    }

    // Not safe for active vouchers with invalid data
    return false;
  }

  /// Get display status text with null safety
  String get displayStatus {
    switch (status) {
      case ClientVoucherStatus.active:
        return isVoucherDataValid ? 'نشطة' : 'نشطة (بيانات غير صالحة)';
      case ClientVoucherStatus.used:
        return 'مستخدمة';
      case ClientVoucherStatus.expired:
        return 'منتهية الصلاحية';
    }
  }

  /// Get safe voucher description for UI
  String get safeDescription {
    if (isVoucherDataValid) {
      return '${voucher!.name} - ${voucher!.formattedDiscount}';
    }
    return 'قسيمة غير صالحة - يرجى الاتصال بالدعم';
  }

  /// Create a copy of this client voucher with updated fields
  ClientVoucherModel copyWith({
    String? id,
    String? voucherId,
    String? clientId,
    ClientVoucherStatus? status,
    DateTime? usedAt,
    String? orderId,
    double? discountAmount,
    String? assignedBy,
    DateTime? assignedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
    VoucherModel? voucher,
    String? clientName,
    String? clientEmail,
    String? assignedByName,
  }) {
    return ClientVoucherModel(
      id: id ?? this.id,
      voucherId: voucherId ?? this.voucherId,
      clientId: clientId ?? this.clientId,
      status: status ?? this.status,
      usedAt: usedAt ?? this.usedAt,
      orderId: orderId ?? this.orderId,
      discountAmount: discountAmount ?? this.discountAmount,
      assignedBy: assignedBy ?? this.assignedBy,
      assignedAt: assignedAt ?? this.assignedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
      voucher: voucher ?? this.voucher,
      clientName: clientName ?? this.clientName,
      clientEmail: clientEmail ?? this.clientEmail,
      assignedByName: assignedByName ?? this.assignedByName,
    );
  }

  /// Convert client voucher to JSON for API calls
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'voucher_id': voucherId,
      'client_id': clientId,
      'status': status.value,
      'used_at': usedAt?.toIso8601String(),
      'order_id': orderId,
      'discount_amount': discountAmount,
      'assigned_by': assignedBy,
      'assigned_at': assignedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  /// Create client voucher for assignment (without generated fields)
  Map<String, dynamic> toCreateJson() {
    return {
      'voucher_id': voucherId,
      'client_id': clientId,
      'status': ClientVoucherStatus.active.value,
      'discount_amount': 0.0,
      'metadata': metadata ?? {},
    };
  }

  /// Create client voucher for usage updates
  Map<String, dynamic> toUsageUpdateJson() {
    return {
      'status': status.value,
      'used_at': usedAt?.toIso8601String(),
      'order_id': orderId,
      'discount_amount': discountAmount,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ClientVoucherModel &&
        other.id == id &&
        other.voucherId == voucherId &&
        other.clientId == clientId &&
        other.status == status &&
        other.usedAt == usedAt &&
        other.orderId == orderId &&
        other.discountAmount == discountAmount &&
        other.assignedBy == assignedBy &&
        other.assignedAt == assignedAt &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        mapEquals(other.metadata, metadata);
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      voucherId,
      clientId,
      status,
      usedAt,
      orderId,
      discountAmount,
      assignedBy,
      assignedAt,
      createdAt,
      updatedAt,
      metadata,
    );
  }

  @override
  String toString() {
    return 'ClientVoucherModel(id: $id, voucherId: $voucherId, clientId: $clientId, '
        'status: $status, discountAmount: $discountAmount, assignedAt: $assignedAt)';
  }
}

/// Helper class for client voucher assignment
class ClientVoucherAssignRequest {

  const ClientVoucherAssignRequest({
    required this.voucherId,
    required this.clientIds,
    this.metadata,
  });
  final String voucherId;
  final List<String> clientIds;
  final Map<String, dynamic>? metadata;

  List<Map<String, dynamic>> toJsonList() {
    return clientIds.map((clientId) => {
      'voucher_id': voucherId,
      'client_id': clientId,
      'status': ClientVoucherStatus.active.value,
      'discount_amount': 0.0,
      'metadata': metadata ?? {},
    }).toList();
  }

  /// Convert to JSON list with assigned_by field for database insertion
  List<Map<String, dynamic>> toJsonListWithAssignedBy(String assignedBy) {
    return clientIds.map((clientId) => {
      'voucher_id': voucherId,
      'client_id': clientId,
      'status': ClientVoucherStatus.active.value,
      'discount_amount': 0.0,
      'assigned_by': assignedBy,
      'metadata': metadata ?? {},
    }).toList();
  }
}

/// Helper class for voucher usage
class VoucherUsageRequest {

  const VoucherUsageRequest({
    required this.clientVoucherId,
    required this.orderId,
    required this.discountAmount,
    this.metadata,
  });
  final String clientVoucherId;
  final String orderId;
  final double discountAmount;
  final Map<String, dynamic>? metadata;

  Map<String, dynamic> toJson() {
    return {
      'status': ClientVoucherStatus.used.value,
      'used_at': DateTime.now().toIso8601String(),
      'order_id': orderId,
      'discount_amount': discountAmount,
      'metadata': metadata ?? {},
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
}
