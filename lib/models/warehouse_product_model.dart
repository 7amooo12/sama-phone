import 'package:smartbiztracker_new/models/product_model.dart';
import 'package:smartbiztracker_new/models/warehouse_model.dart';
import 'package:uuid/uuid.dart';

/// نموذج العلاقة بين المخزن والمنتج
/// يمثل منتج محدد في مخزن محدد مع الكمية المتاحة
class WarehouseProductModel {
  final String id;
  final String warehouseId;
  final String productId;
  final int quantity;
  final int minimumStock;
  final int maximumStock;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String updatedBy;
  final Map<String, dynamic>? metadata;

  // معلومات إضافية للعرض
  final ProductModel? product;
  final WarehouseModel? warehouse;
  final String? productName;
  final String? productImageUrl;
  final String? productCategory;
  final String? productSku;
  final String? warehouseName;

  const WarehouseProductModel({
    required this.id,
    required this.warehouseId,
    required this.productId,
    required this.quantity,
    this.minimumStock = 10,
    this.maximumStock = 1000,
    required this.createdAt,
    required this.updatedAt,
    required this.updatedBy,
    this.metadata,
    this.product,
    this.warehouse,
    this.productName,
    this.productImageUrl,
    this.productCategory,
    this.productSku,
    this.warehouseName,
  });

  /// إنشاء من JSON
  factory WarehouseProductModel.fromJson(Map<String, dynamic> json) {
    return WarehouseProductModel(
      id: json['id']?.toString() ?? '',
      warehouseId: json['warehouse_id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      quantity: _parseInt(json['quantity']) ?? 0,
      minimumStock: _parseInt(json['minimum_stock']) ?? 10,
      maximumStock: _parseInt(json['maximum_stock']) ?? 1000,
      createdAt: _parseDateTime(json['created_at']) ?? DateTime.now(),
      updatedAt: _parseDateTime(json['updated_at']) ?? DateTime.now(),
      updatedBy: json['updated_by']?.toString() ?? '',
      metadata: json['metadata'] as Map<String, dynamic>?,
      productName: json['product_name']?.toString(),
      productImageUrl: json['product_image_url']?.toString(),
      productCategory: json['product_category']?.toString(),
      productSku: json['product_sku']?.toString(),
      warehouseName: json['warehouse_name']?.toString(),
    );
  }

  /// تحويل إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'warehouse_id': warehouseId,
      'product_id': productId,
      'quantity': quantity,
      'minimum_stock': minimumStock,
      'maximum_stock': maximumStock,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'updated_by': updatedBy,
      'metadata': metadata,
    };
  }

  /// نسخ مع تعديل
  WarehouseProductModel copyWith({
    String? id,
    String? warehouseId,
    String? productId,
    int? quantity,
    int? minimumStock,
    int? maximumStock,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? updatedBy,
    Map<String, dynamic>? metadata,
    ProductModel? product,
    WarehouseModel? warehouse,
    String? productName,
    String? productImageUrl,
    String? productCategory,
    String? productSku,
    String? warehouseName,
  }) {
    return WarehouseProductModel(
      id: id ?? this.id,
      warehouseId: warehouseId ?? this.warehouseId,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      minimumStock: minimumStock ?? this.minimumStock,
      maximumStock: maximumStock ?? this.maximumStock,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      metadata: metadata ?? this.metadata,
      product: product ?? this.product,
      warehouse: warehouse ?? this.warehouse,
      productName: productName ?? this.productName,
      productImageUrl: productImageUrl ?? this.productImageUrl,
      productCategory: productCategory ?? this.productCategory,
      productSku: productSku ?? this.productSku,
      warehouseName: warehouseName ?? this.warehouseName,
    );
  }

  /// التحقق من كون المخزون منخفض
  bool get isLowStock => quantity <= minimumStock;

  /// التحقق من كون المخزون نفد
  bool get isOutOfStock => quantity == 0;

  /// التحقق من كون المخزون ممتلئ
  bool get isFullStock => quantity >= maximumStock;

  /// النسبة المئوية للمخزون
  double get stockPercentage {
    if (maximumStock == 0) return 0.0;
    return (quantity / maximumStock).clamp(0.0, 1.0);
  }

  /// حالة المخزون كنص
  String get stockStatus {
    if (isOutOfStock) return 'نفد المخزون';
    if (isLowStock) return 'مخزون منخفض';
    if (isFullStock) return 'مخزون ممتلئ';
    return 'متوفر';
  }

  /// لون حالة المخزون
  String get stockStatusColor {
    if (isOutOfStock) return 'red';
    if (isLowStock) return 'orange';
    if (isFullStock) return 'blue';
    return 'green';
  }

  /// الكمية المتبقية قبل الوصول للحد الأدنى
  int get quantityUntilLowStock {
    return (quantity - minimumStock).clamp(0, quantity);
  }

  /// الكمية المطلوبة للوصول للحد الأقصى
  int get quantityToMaxStock {
    return (maximumStock - quantity).clamp(0, maximumStock);
  }

  /// معلومات المنتج الفعلية أو البديلة
  String get displayName => productName ?? product?.name ?? 'منتج غير معروف';
  String get displayImageUrl => productImageUrl ?? product?.imageUrl ?? '';
  String get displayCategory => productCategory ?? product?.category ?? '';
  String get displaySku => productSku ?? product?.sku ?? '';

  /// التحقق من صحة البيانات
  bool get isValid {
    return id.isNotEmpty &&
           warehouseId.isNotEmpty &&
           productId.isNotEmpty &&
           quantity >= 0 &&
           minimumStock >= 0 &&
           maximumStock >= minimumStock;
  }

  /// تحويل إلى خريطة للعرض
  Map<String, dynamic> toDisplayMap() {
    return {
      'id': id,
      'productName': displayName,
      'productImageUrl': displayImageUrl,
      'productCategory': displayCategory,
      'productSku': displaySku,
      'quantity': quantity,
      'minimumStock': minimumStock,
      'maximumStock': maximumStock,
      'stockStatus': stockStatus,
      'stockStatusColor': stockStatusColor,
      'stockPercentage': stockPercentage,
      'isLowStock': isLowStock,
      'isOutOfStock': isOutOfStock,
      'isFullStock': isFullStock,
      'warehouseName': warehouseName ?? warehouse?.name ?? 'مخزن غير معروف',
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'WarehouseProductModel(id: $id, productName: $displayName, quantity: $quantity, stockStatus: $stockStatus)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WarehouseProductModel &&
           other.id == id &&
           other.warehouseId == warehouseId &&
           other.productId == productId;
  }

  @override
  int get hashCode {
    return id.hashCode ^ warehouseId.hashCode ^ productId.hashCode;
  }

  /// دوال مساعدة لتحليل البيانات
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  /// إنشاء نموذج جديد من منتج ومخزن
  static WarehouseProductModel create({
    required String warehouseId,
    required String productId,
    required int quantity,
    required String updatedBy,
    int minimumStock = 10,
    int maximumStock = 1000,
    ProductModel? product,
    WarehouseModel? warehouse,
  }) {
    const uuid = Uuid();
    final now = DateTime.now();
    return WarehouseProductModel(
      id: uuid.v4(), // Generate proper UUID instead of composite timestamp ID
      warehouseId: warehouseId,
      productId: productId,
      quantity: quantity,
      minimumStock: minimumStock,
      maximumStock: maximumStock,
      createdAt: now,
      updatedAt: now,
      updatedBy: updatedBy,
      product: product,
      warehouse: warehouse,
      productName: product?.name,
      productImageUrl: product?.imageUrl,
      productCategory: product?.category,
      productSku: product?.sku,
      warehouseName: warehouse?.name,
    );
  }

  /// تحديث الكمية
  WarehouseProductModel updateQuantity(int newQuantity, String updatedBy) {
    return copyWith(
      quantity: newQuantity,
      updatedAt: DateTime.now(),
      updatedBy: updatedBy,
    );
  }

  /// تحديث حدود المخزون
  WarehouseProductModel updateStockLimits({
    int? minimumStock,
    int? maximumStock,
    required String updatedBy,
  }) {
    return copyWith(
      minimumStock: minimumStock ?? this.minimumStock,
      maximumStock: maximumStock ?? this.maximumStock,
      updatedAt: DateTime.now(),
      updatedBy: updatedBy,
    );
  }
}
