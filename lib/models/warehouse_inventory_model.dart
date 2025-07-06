import 'package:smartbiztracker_new/models/product_model.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// نموذج مخزون المخزن مع تتبع الكراتين
class WarehouseInventoryModel {
  final String id;
  final String warehouseId;
  final String productId;
  final int quantity;
  final int? minimumStock;
  final int? maximumStock;
  final int quantityPerCarton; // الكمية في الكرتونة الواحدة
  final DateTime lastUpdated;
  final String updatedBy;
  final Map<String, dynamic>? metadata;

  // معلومات المنتج (للعرض)
  final ProductModel? product;
  final String? warehouseName;

  const WarehouseInventoryModel({
    required this.id,
    required this.warehouseId,
    required this.productId,
    required this.quantity,
    this.minimumStock,
    this.maximumStock,
    this.quantityPerCarton = 1, // القيمة الافتراضية
    required this.lastUpdated,
    required this.updatedBy,
    this.metadata,
    this.product,
    this.warehouseName,
  });

  factory WarehouseInventoryModel.fromJson(Map<String, dynamic> json) {
    return WarehouseInventoryModel(
      id: json['id'] as String,
      warehouseId: json['warehouse_id'] as String,
      productId: json['product_id'] as String,
      quantity: json['quantity'] as int,
      minimumStock: json['minimum_stock'] as int?,
      maximumStock: json['maximum_stock'] as int?,
      quantityPerCarton: json['quantity_per_carton'] as int? ?? 1,
      lastUpdated: DateTime.parse(json['last_updated'] as String),
      updatedBy: json['updated_by'] as String,
      metadata: json['metadata'] as Map<String, dynamic>?,
      product: json['product'] != null
          ? ProductModel.fromJson(json['product'] as Map<String, dynamic>)
          : null,
      warehouseName: json['warehouse_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'warehouse_id': warehouseId,
      'product_id': productId,
      'quantity': quantity,
      'minimum_stock': minimumStock,
      'maximum_stock': maximumStock,
      'quantity_per_carton': quantityPerCarton,
      'last_updated': lastUpdated.toIso8601String(),
      'updated_by': updatedBy,
      'metadata': metadata,
      'product': product?.toJson(),
      'warehouse_name': warehouseName,
    };
  }

  WarehouseInventoryModel copyWith({
    String? id,
    String? warehouseId,
    String? productId,
    int? quantity,
    int? minimumStock,
    int? maximumStock,
    int? quantityPerCarton,
    DateTime? lastUpdated,
    String? updatedBy,
    Map<String, dynamic>? metadata,
    ProductModel? product,
    String? warehouseName,
  }) {
    return WarehouseInventoryModel(
      id: id ?? this.id,
      warehouseId: warehouseId ?? this.warehouseId,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      minimumStock: minimumStock ?? this.minimumStock,
      maximumStock: maximumStock ?? this.maximumStock,
      quantityPerCarton: quantityPerCarton ?? this.quantityPerCarton,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      updatedBy: updatedBy ?? this.updatedBy,
      metadata: metadata ?? this.metadata,
      product: product ?? this.product,
      warehouseName: warehouseName ?? this.warehouseName,
    );
  }

  /// التحقق من انخفاض المخزون
  bool get isLowStock {
    if (minimumStock == null) return false;
    return quantity <= minimumStock!;
  }

  /// التحقق من نفاد المخزون
  bool get isOutOfStock => quantity <= 0;

  /// التحقق من امتلاء المخزون
  bool get isOverStock {
    if (maximumStock == null) return false;
    return quantity >= maximumStock!;
  }

  /// حساب عدد الكراتين المطلوبة
  int get cartonsCount {
    if (quantity <= 0 || quantityPerCarton <= 0) {
      AppLogger.info('🔍 cartonsCount: quantity=$quantity, quantityPerCarton=$quantityPerCarton, returning 0');
      return 0;
    }
    final result = (quantity / quantityPerCarton).ceil();
    AppLogger.info('🔍 cartonsCount: quantity=$quantity, quantityPerCarton=$quantityPerCarton, result=$result');
    return result;
  }

  /// حساب الكمية المتبقية في الكرتونة الأخيرة
  int get remainingInLastCarton {
    if (quantity <= 0 || quantityPerCarton <= 0) return 0;
    final remainder = quantity % quantityPerCarton;
    return remainder == 0 ? quantityPerCarton : remainder;
  }

  /// التحقق من امتلاء الكرتونة الأخيرة
  bool get isLastCartonFull {
    return remainingInLastCarton == quantityPerCarton;
  }

  /// نص وصفي لعدد الكراتين
  String get cartonsDisplayText {
    final cartons = cartonsCount;
    if (cartons == 0) return 'لا توجد كراتين';
    if (cartons == 1) return 'كرتونة واحدة';
    if (cartons == 2) return 'كرتونتان';
    if (cartons <= 10) return '$cartons كراتين';
    return '$cartons كرتونة';
  }

  /// نص وصفي للكمية في الكرتونة
  String get quantityPerCartonDisplayText {
    if (quantityPerCarton == 1) return 'قطعة واحدة في الكرتونة';
    if (quantityPerCarton == 2) return 'قطعتان في الكرتونة';
    if (quantityPerCarton <= 10) return '$quantityPerCarton قطع في الكرتونة';
    return '$quantityPerCarton قطعة في الكرتونة';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WarehouseInventoryModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'WarehouseInventoryModel(id: $id, warehouseId: $warehouseId, productId: $productId, quantity: $quantity)';
  }
}
