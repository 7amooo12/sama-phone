import 'package:flutter/foundation.dart';

/// Enum for voucher types
enum VoucherType {
  category,
  product,
  multipleProducts;

  String get value {
    switch (this) {
      case VoucherType.category:
        return 'category';
      case VoucherType.product:
        return 'product';
      case VoucherType.multipleProducts:
        return 'multiple_products';
    }
  }

  static VoucherType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'category':
        return VoucherType.category;
      case 'product':
        return VoucherType.product;
      case 'multiple_products':
        return VoucherType.multipleProducts;
      default:
        throw ArgumentError('Invalid voucher type: $value');
    }
  }

  String get displayName {
    switch (this) {
      case VoucherType.category:
        return 'فئة المنتجات';
      case VoucherType.product:
        return 'منتج محدد';
      case VoucherType.multipleProducts:
        return 'منتجات متعددة';
    }
  }

  /// Check if this voucher type supports multiple products
  bool get supportsMultipleProducts {
    return this == VoucherType.multipleProducts;
  }

  /// Get icon for voucher type
  String get icon {
    switch (this) {
      case VoucherType.category:
        return 'category';
      case VoucherType.product:
        return 'inventory';
      case VoucherType.multipleProducts:
        return 'inventory_2';
    }
  }
}

/// Enum for discount types
enum DiscountType {
  percentage,
  fixedAmount;

  String get value {
    switch (this) {
      case DiscountType.percentage:
        return 'percentage';
      case DiscountType.fixedAmount:
        return 'fixed_amount';
    }
  }

  static DiscountType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'percentage':
        return DiscountType.percentage;
      case 'fixed_amount':
        return DiscountType.fixedAmount;
      default:
        return DiscountType.percentage;
    }
  }

  String get displayName {
    switch (this) {
      case DiscountType.percentage:
        return 'نسبة مئوية';
      case DiscountType.fixedAmount:
        return 'مبلغ ثابت';
    }
  }

  String get symbol {
    switch (this) {
      case DiscountType.percentage:
        return '%';
      case DiscountType.fixedAmount:
        return 'جنيه';
    }
  }
}

/// Model class for vouchers
class VoucherModel {

  const VoucherModel({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    required this.type,
    required this.targetId,
    required this.targetName,
    required this.discountPercentage,
    this.discountType = DiscountType.percentage,
    this.discountAmount,
    required this.expirationDate,
    required this.isActive,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.metadata,
  });

  /// Create voucher from JSON response with null safety
  factory VoucherModel.fromJson(Map<String, dynamic> json) {
    try {
      final discountType = DiscountType.fromString(json['discount_type']?.toString() ?? 'percentage');

      return VoucherModel(
        id: json['id']?.toString() ?? '',
        code: json['code']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString(),
        type: VoucherType.fromString(json['type']?.toString() ?? 'category'),
        targetId: json['target_id']?.toString() ?? '',
        targetName: json['target_name']?.toString() ?? '',
        // For fixed_amount vouchers, discount_percentage should be 0 (null in DB)
        // For percentage vouchers, use the actual percentage value
        discountPercentage: discountType == DiscountType.fixedAmount
            ? 0
            : (json['discount_percentage'] as num?)?.toInt() ?? 0,
        discountType: discountType,
        discountAmount: (json['discount_amount'] as num?)?.toDouble(),
        expirationDate: json['expiration_date'] != null
            ? DateTime.tryParse(json['expiration_date'].toString()) ?? DateTime.now().add(const Duration(days: 30))
            : DateTime.now().add(const Duration(days: 30)),
        isActive: json['is_active'] as bool? ?? true,
        createdBy: json['created_by']?.toString() ?? '',
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
        updatedAt: json['updated_at'] != null
            ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
        metadata: json['metadata'] as Map<String, dynamic>?,
      );
    } catch (e) {
      // Log the error and provide fallback values
      debugPrint('Error parsing VoucherModel from JSON: $e');
      debugPrint('JSON data: $json');

      // Return a minimal valid object with fallback values
      return VoucherModel(
        id: json['id']?.toString() ?? 'unknown',
        code: json['code']?.toString() ?? 'UNKNOWN',
        name: json['name']?.toString() ?? 'Unknown Voucher',
        description: null,
        type: VoucherType.category,
        targetId: '',
        targetName: '',
        discountPercentage: 0,
        discountType: DiscountType.percentage,
        discountAmount: null,
        expirationDate: DateTime.now().add(const Duration(days: 30)),
        isActive: false,
        createdBy: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: null,
      );
    }
  }
  final String id;
  final String code;
  final String name;
  final String? description;
  final VoucherType type;
  final String targetId;
  final String targetName;
  final int discountPercentage;
  final DiscountType discountType;
  final double? discountAmount;
  final DateTime expirationDate;
  final bool isActive;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? metadata;

  /// Check if voucher is currently valid (not expired and active)
  bool get isValid {
    return isActive && expirationDate.isAfter(DateTime.now());
  }

  /// Check if voucher is expired
  bool get isExpired {
    return expirationDate.isBefore(DateTime.now());
  }

  /// Get voucher status as string
  String get status {
    if (!isActive) return 'معطل';
    if (isExpired) return 'منتهي الصلاحية';
    return 'نشط';
  }

  /// Get status color for UI
  String get statusColor {
    if (!isActive) return 'red';
    if (isExpired) return 'orange';
    return 'green';
  }

  /// Get formatted expiration date
  String get formattedExpirationDate {
    return '${expirationDate.day}/${expirationDate.month}/${expirationDate.year}';
  }

  /// Get days until expiration
  int get daysUntilExpiration {
    final now = DateTime.now();
    if (expirationDate.isBefore(now)) return 0;
    return expirationDate.difference(now).inDays;
  }

  /// Check if voucher expires soon (within 7 days)
  bool get expiresSoon {
    return daysUntilExpiration <= 7 && daysUntilExpiration > 0;
  }

  /// Get the effective discount value based on discount type
  double getDiscountValue() {
    switch (discountType) {
      case DiscountType.percentage:
        return discountPercentage.toDouble();
      case DiscountType.fixedAmount:
        return discountAmount ?? 0.0;
    }
  }

  /// Get formatted discount display text
  String get formattedDiscount {
    switch (discountType) {
      case DiscountType.percentage:
        return '$discountPercentage%';
      case DiscountType.fixedAmount:
        return '${discountAmount?.toStringAsFixed(2) ?? '0.00'} جنيه';
    }
  }

  /// Check if this voucher supports multiple products
  bool get supportsMultipleProducts {
    return type == VoucherType.multipleProducts;
  }

  /// Get selected product IDs for multiple products voucher
  List<String> get selectedProductIds {
    if (!supportsMultipleProducts) {
      return type == VoucherType.product ? [targetId] : [];
    }

    final selectedProducts = metadata?['selected_products'] as List<dynamic>?;
    if (selectedProducts == null) return [];

    return selectedProducts
        .map((product) => product['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
  }

  /// Get selected products information for multiple products voucher
  List<Map<String, dynamic>> get selectedProducts {
    if (!supportsMultipleProducts) {
      if (type == VoucherType.product) {
        return [
          {
            'id': targetId,
            'name': targetName,
          }
        ];
      }
      return [];
    }

    final selectedProducts = metadata?['selected_products'] as List<dynamic>?;
    if (selectedProducts == null) return [];

    return selectedProducts
        .map((product) => Map<String, dynamic>.from(product as Map))
        .toList();
  }

  /// Get count of selected products
  int get selectedProductsCount {
    if (type == VoucherType.category) return 0;
    if (type == VoucherType.product) return 1;
    return selectedProducts.length;
  }

  /// Get display text for selected products
  String get selectedProductsDisplayText {
    switch (type) {
      case VoucherType.category:
        return 'فئة: $targetName';
      case VoucherType.product:
        return 'منتج: $targetName';
      case VoucherType.multipleProducts:
        final count = selectedProductsCount;
        if (count == 0) return 'لم يتم اختيار منتجات';
        if (count == 1) return 'منتج واحد مختار';
        return '$count منتجات مختارة';
    }
  }

  /// Check if a product ID is applicable for this voucher
  bool isProductApplicable(String productId, String? productCategory) {
    switch (type) {
      case VoucherType.category:
        return productCategory == targetName || productCategory == targetId;
      case VoucherType.product:
        return productId == targetId;
      case VoucherType.multipleProducts:
        return selectedProductIds.contains(productId);
    }
  }

  /// Create a copy of this voucher with updated fields
  VoucherModel copyWith({
    String? id,
    String? code,
    String? name,
    String? description,
    VoucherType? type,
    String? targetId,
    String? targetName,
    int? discountPercentage,
    DiscountType? discountType,
    double? discountAmount,
    DateTime? expirationDate,
    bool? isActive,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return VoucherModel(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      targetId: targetId ?? this.targetId,
      targetName: targetName ?? this.targetName,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      discountType: discountType ?? this.discountType,
      discountAmount: discountAmount ?? this.discountAmount,
      expirationDate: expirationDate ?? this.expirationDate,
      isActive: isActive ?? this.isActive,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Convert voucher to JSON for API calls
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'description': description,
      'type': type.value,
      'target_id': targetId,
      'target_name': targetName,
      // Set discount_percentage to null for fixed_amount vouchers
      'discount_percentage': discountType == DiscountType.fixedAmount ? null : discountPercentage,
      'discount_type': discountType.value,
      'discount_amount': discountAmount,
      'expiration_date': expirationDate.toIso8601String(),
      'is_active': isActive,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  /// Create voucher for creation (without generated fields)
  Map<String, dynamic> toCreateJson() {
    return {
      'name': name,
      'description': description,
      'type': type.value,
      'target_id': targetId,
      'target_name': targetName,
      // Set discount_percentage to null for fixed_amount vouchers
      'discount_percentage': discountType == DiscountType.fixedAmount ? null : discountPercentage,
      'discount_type': discountType.value,
      'discount_amount': discountAmount,
      'expiration_date': expirationDate.toIso8601String(),
      'is_active': isActive,
      'metadata': metadata ?? {},
    };
  }

  /// Create voucher for updates (only updatable fields)
  Map<String, dynamic> toUpdateJson() {
    return {
      'name': name,
      'description': description,
      // Set discount_percentage to null for fixed_amount vouchers
      'discount_percentage': discountType == DiscountType.fixedAmount ? null : discountPercentage,
      'discount_type': discountType.value,
      'discount_amount': discountAmount,
      'expiration_date': expirationDate.toIso8601String(),
      'is_active': isActive,
      'metadata': metadata ?? {},
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VoucherModel &&
        other.id == id &&
        other.code == code &&
        other.name == name &&
        other.description == description &&
        other.type == type &&
        other.targetId == targetId &&
        other.targetName == targetName &&
        other.discountPercentage == discountPercentage &&
        other.discountType == discountType &&
        other.discountAmount == discountAmount &&
        other.expirationDate == expirationDate &&
        other.isActive == isActive &&
        other.createdBy == createdBy &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        mapEquals(other.metadata, metadata);
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      code,
      name,
      description,
      type,
      targetId,
      targetName,
      discountPercentage,
      discountType,
      discountAmount,
      expirationDate,
      isActive,
      createdBy,
      createdAt,
      updatedAt,
      metadata,
    );
  }

  @override
  String toString() {
    return 'VoucherModel(id: $id, code: $code, name: $name, type: $type, '
        'targetName: $targetName, discount: $formattedDiscount, '
        'expirationDate: $expirationDate, isActive: $isActive)';
  }
}

/// Helper class for voucher creation
class VoucherCreateRequest {

  const VoucherCreateRequest({
    required this.name,
    this.description,
    required this.type,
    required this.targetId,
    required this.targetName,
    required this.discountPercentage,
    this.discountType = DiscountType.percentage,
    this.discountAmount,
    required this.expirationDate,
    this.metadata,
    this.selectedProducts,
  });
  final String name;
  final String? description;
  final VoucherType type;
  final String targetId;
  final String targetName;
  final int discountPercentage;
  final DiscountType discountType;
  final double? discountAmount;
  final DateTime expirationDate;
  final Map<String, dynamic>? metadata;
  final List<Map<String, dynamic>>? selectedProducts;

  /// Create a voucher request for multiple products
  factory VoucherCreateRequest.forMultipleProducts({
    required String name,
    String? description,
    required List<Map<String, dynamic>> selectedProducts,
    required int discountPercentage,
    DiscountType discountType = DiscountType.percentage,
    double? discountAmount,
    required DateTime expirationDate,
    Map<String, dynamic>? additionalMetadata,
  }) {
    final metadata = <String, dynamic>{
      'selected_products': selectedProducts,
      'product_count': selectedProducts.length,
      'creation_type': 'multiple_products',
      ...?additionalMetadata,
    };

    return VoucherCreateRequest(
      name: name,
      description: description,
      type: VoucherType.multipleProducts,
      targetId: 'multiple_products',
      targetName: '${selectedProducts.length} منتجات مختارة',
      discountPercentage: discountPercentage,
      discountType: discountType,
      discountAmount: discountAmount,
      expirationDate: expirationDate,
      metadata: metadata,
      selectedProducts: selectedProducts,
    );
  }

  /// Get selected product IDs
  List<String> get selectedProductIds {
    if (type != VoucherType.multipleProducts) {
      return type == VoucherType.product ? [targetId] : [];
    }

    return selectedProducts
        ?.map((product) => product['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList() ?? [];
  }

  /// Get count of selected products
  int get selectedProductsCount {
    if (type == VoucherType.category) return 0;
    if (type == VoucherType.product) return 1;
    return selectedProducts?.length ?? 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'type': type.value,
      'target_id': targetId,
      'target_name': targetName,
      // Set discount_percentage to null for fixed_amount vouchers to avoid constraint violation
      'discount_percentage': discountType == DiscountType.fixedAmount ? null : discountPercentage,
      'discount_type': discountType.value,
      'discount_amount': discountAmount,
      'expiration_date': expirationDate.toIso8601String(),
      'is_active': true,
      'metadata': metadata ?? {},
    };
  }

  /// Convert to JSON with created_by field for database insertion
  Map<String, dynamic> toJsonWithCreatedBy(String createdBy) {
    final json = toJson();
    json['created_by'] = createdBy;
    return json;
  }
}

/// Helper class for voucher updates
class VoucherUpdateRequest {

  const VoucherUpdateRequest({
    this.name,
    this.description,
    this.discountPercentage,
    this.discountType,
    this.discountAmount,
    this.expirationDate,
    this.isActive,
    this.metadata,
  });
  final String? name;
  final String? description;
  final int? discountPercentage;
  final DiscountType? discountType;
  final double? discountAmount;
  final DateTime? expirationDate;
  final bool? isActive;
  final Map<String, dynamic>? metadata;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (name != null) json['name'] = name;
    if (description != null) json['description'] = description;
    if (discountPercentage != null) json['discount_percentage'] = discountPercentage;
    if (discountType != null) json['discount_type'] = discountType!.value;
    if (discountAmount != null) json['discount_amount'] = discountAmount;
    if (expirationDate != null) json['expiration_date'] = expirationDate!.toIso8601String();
    if (isActive != null) json['is_active'] = isActive;
    if (metadata != null) json['metadata'] = metadata;
    json['updated_at'] = DateTime.now().toIso8601String();
    return json;
  }
}
