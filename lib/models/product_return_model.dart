import 'package:smartbiztracker_new/utils/uuid_validator.dart';

class ProductReturn {

  ProductReturn({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.productName,
    this.orderNumber, // Made optional
    required this.reason,
    required this.status,
    this.phone,
    this.datePurchased,
    required this.hasReceipt,
    required this.termsAccepted,
    required this.productImages,
    required this.createdAt,
    this.processedAt,
    this.adminNotes,
    this.adminResponse,
    this.adminResponseDate,
    this.refundAmount,
  });

  factory ProductReturn.fromJson(Map<String, dynamic> json) {
    return ProductReturn(
      id: json['id'] as String? ?? '',
      customerId: json['customer_id'] as String? ?? '',
      customerName: json['customer_name'] as String? ?? '',
      productName: json['product_name'] as String? ?? '',
      orderNumber: json['order_number'] as String?, // Can be null
      reason: json['reason'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      phone: json['phone'] as String?,
      datePurchased: json['date_purchased'] != null
          ? DateTime.parse(json['date_purchased'] as String)
          : null,
      hasReceipt: json['has_receipt'] as bool? ?? false,
      termsAccepted: json['terms_accepted'] as bool? ?? false,
      productImages: json['product_images'] != null
          ? List<String>.from(json['product_images'] as List<dynamic>)
          : [],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      processedAt: json['processed_at'] != null
          ? DateTime.parse(json['processed_at'] as String)
          : null,
      adminNotes: json['admin_notes'] as String?,
      adminResponse: json['admin_response'] as String?,
      adminResponseDate: json['admin_response_date'] != null
          ? DateTime.parse(json['admin_response_date'] as String)
          : null,
      refundAmount: (json['refund_amount'] as num?)?.toDouble(),
    );
  }
  final String id;
  final String customerId;
  final String customerName;
  final String productName;
  final String? orderNumber;
  final String reason;
  final String status;
  final String? phone;
  final DateTime? datePurchased;
  final bool hasReceipt;
  final bool termsAccepted;
  final List<String> productImages;
  final DateTime createdAt;
  final DateTime? processedAt;
  final String? adminNotes;
  final String? adminResponse;
  final DateTime? adminResponseDate;
  final double? refundAmount;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'customer_id': customerId,
      'customer_name': customerName,
      'product_name': productName,
      'order_number': orderNumber,
      'reason': reason,
      'status': status,
      'phone': phone,
      'date_purchased': datePurchased?.toIso8601String(),
      'has_receipt': hasReceipt,
      'terms_accepted': termsAccepted,
      'product_images': productImages,
      'created_at': createdAt.toIso8601String(),
      'processed_at': processedAt?.toIso8601String(),
      'admin_notes': adminNotes,
      'admin_response': adminResponse,
      'admin_response_date': adminResponseDate?.toIso8601String(),
      'refund_amount': refundAmount,
    };

    // Only include 'id' if it's a valid UUID (not empty)
    UuidValidator.addUuidToJson(json, 'id', id);

    return json;
  }

  ProductReturn copyWith({
    String? id,
    String? customerId,
    String? customerName,
    String? productName,
    String? orderNumber,
    String? reason,
    String? status,
    String? phone,
    DateTime? datePurchased,
    bool? hasReceipt,
    bool? termsAccepted,
    List<String>? productImages,
    DateTime? createdAt,
    DateTime? processedAt,
    String? adminNotes,
    String? adminResponse,
    DateTime? adminResponseDate,
    double? refundAmount,
  }) {
    return ProductReturn(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      productName: productName ?? this.productName,
      orderNumber: orderNumber ?? this.orderNumber,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      phone: phone ?? this.phone,
      datePurchased: datePurchased ?? this.datePurchased,
      hasReceipt: hasReceipt ?? this.hasReceipt,
      termsAccepted: termsAccepted ?? this.termsAccepted,
      productImages: productImages ?? this.productImages,
      createdAt: createdAt ?? this.createdAt,
      processedAt: processedAt ?? this.processedAt,
      adminNotes: adminNotes ?? this.adminNotes,
      adminResponse: adminResponse ?? this.adminResponse,
      adminResponseDate: adminResponseDate ?? this.adminResponseDate,
      refundAmount: refundAmount ?? this.refundAmount,
    );
  }

  @override
  String toString() {
    return 'ProductReturn(id: $id, productName: $productName, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProductReturn && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// Enum for product return status
enum ProductReturnStatus {
  pending,
  approved,
  rejected,
  processing,
  completed,
}

// Extension methods for enum
extension ProductReturnStatusExtension on ProductReturnStatus {
  String get value {
    switch (this) {
      case ProductReturnStatus.pending:
        return 'pending';
      case ProductReturnStatus.approved:
        return 'approved';
      case ProductReturnStatus.rejected:
        return 'rejected';
      case ProductReturnStatus.processing:
        return 'processing';
      case ProductReturnStatus.completed:
        return 'completed';
    }
  }

  String get arabicText {
    switch (this) {
      case ProductReturnStatus.pending:
        return 'قيد المراجعة';
      case ProductReturnStatus.approved:
        return 'موافق عليه';
      case ProductReturnStatus.rejected:
        return 'مرفوض';
      case ProductReturnStatus.processing:
        return 'قيد المعالجة';
      case ProductReturnStatus.completed:
        return 'مكتمل';
    }
  }
}
