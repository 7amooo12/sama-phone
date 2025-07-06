/// نماذج البيانات للتوزيع الذكي متعدد المخازن
/// Data models for intelligent multi-warehouse dispatch

import 'package:smartbiztracker_new/models/warehouse_dispatch_model.dart';
import 'package:smartbiztracker_new/models/dispatch_product_processing_model.dart';
import 'package:smartbiztracker_new/models/global_inventory_models.dart';

/// عنصر التوزيع في المخزن
class DistributionItem {
  final String productId;
  final String productName;
  final int requestedQuantity;
  final int allocatedQuantity;
  final String warehouseId;
  final String warehouseName;
  final double unitPrice;

  const DistributionItem({
    required this.productId,
    required this.productName,
    required this.requestedQuantity,
    required this.allocatedQuantity,
    required this.warehouseId,
    required this.warehouseName,
    required this.unitPrice,
  });

  /// نسبة التلبية
  double get fulfillmentPercentage => requestedQuantity > 0 ? (allocatedQuantity / requestedQuantity * 100) : 0;

  /// هل تم تلبية الطلب بالكامل
  bool get isFullyFulfilled => allocatedQuantity >= requestedQuantity;

  /// الكمية المتبقية
  int get remainingQuantity => (requestedQuantity - allocatedQuantity).clamp(0, requestedQuantity);

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'product_name': productName,
      'requested_quantity': requestedQuantity,
      'allocated_quantity': allocatedQuantity,
      'warehouse_id': warehouseId,
      'warehouse_name': warehouseName,
      'unit_price': unitPrice,
    };
  }

  factory DistributionItem.fromJson(Map<String, dynamic> json) {
    return DistributionItem(
      productId: json['product_id'] as String,
      productName: json['product_name'] as String,
      requestedQuantity: json['requested_quantity'] as int,
      allocatedQuantity: json['allocated_quantity'] as int,
      warehouseId: json['warehouse_id'] as String,
      warehouseName: json['warehouse_name'] as String,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
    );
  }

  DistributionItem copyWith({
    String? productId,
    String? productName,
    int? requestedQuantity,
    int? allocatedQuantity,
    String? warehouseId,
    String? warehouseName,
    double? unitPrice,
  }) {
    return DistributionItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      requestedQuantity: requestedQuantity ?? this.requestedQuantity,
      allocatedQuantity: allocatedQuantity ?? this.allocatedQuantity,
      warehouseId: warehouseId ?? this.warehouseId,
      warehouseName: warehouseName ?? this.warehouseName,
      unitPrice: unitPrice ?? this.unitPrice,
    );
  }
}

/// خطة طلب صرف لمخزن واحد
class WarehouseDispatchPlan {
  final String warehouseId;
  final String warehouseName;
  final List<DistributionItem> items;
  final double totalAmount;
  final String reason;
  final String? notes;

  const WarehouseDispatchPlan({
    required this.warehouseId,
    required this.warehouseName,
    required this.items,
    required this.totalAmount,
    required this.reason,
    this.notes,
  });

  /// عدد المنتجات
  int get productCount => items.length;

  /// إجمالي الكمية المخصصة
  int get totalAllocatedQuantity => items.fold(0, (sum, item) => sum + item.allocatedQuantity);

  /// إجمالي الكمية المطلوبة
  int get totalRequestedQuantity => items.fold(0, (sum, item) => sum + item.requestedQuantity);

  /// نسبة التلبية
  double get fulfillmentPercentage => totalRequestedQuantity > 0 ? (totalAllocatedQuantity / totalRequestedQuantity * 100) : 0;

  Map<String, dynamic> toJson() {
    return {
      'warehouse_id': warehouseId,
      'warehouse_name': warehouseName,
      'items': items.map((item) => item.toJson()).toList(),
      'total_amount': totalAmount,
      'reason': reason,
      'notes': notes,
    };
  }

  factory WarehouseDispatchPlan.fromJson(Map<String, dynamic> json) {
    return WarehouseDispatchPlan(
      warehouseId: json['warehouse_id'] as String,
      warehouseName: json['warehouse_name'] as String,
      items: (json['items'] as List<dynamic>)
          .map((item) => DistributionItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      reason: json['reason'] as String,
      notes: json['notes'] as String?,
    );
  }
}

/// خطة التوزيع الكاملة
class DistributionPlan {
  final String invoiceId;
  final String customerName;
  final double totalAmount;
  final String requestedBy;
  final List<WarehouseDispatchPlan> warehouseDispatches;
  final List<DispatchProductProcessingModel> unfulfillableProducts;
  final List<DispatchProductProcessingModel> partiallyFulfillableProducts;
  final WarehouseSelectionStrategy distributionStrategy;
  final DateTime createdAt;

  const DistributionPlan({
    required this.invoiceId,
    required this.customerName,
    required this.totalAmount,
    required this.requestedBy,
    required this.warehouseDispatches,
    required this.unfulfillableProducts,
    required this.partiallyFulfillableProducts,
    required this.distributionStrategy,
    required this.createdAt,
  });

  /// عدد المخازن المشاركة
  int get warehousesCount => warehouseDispatches.length;

  /// إجمالي المنتجات
  int get totalProducts => warehouseDispatches.fold(0, (sum, plan) => sum + plan.productCount);

  /// هل يمكن تنفيذ الخطة
  bool get canExecute => warehouseDispatches.isNotEmpty && unfulfillableProducts.isEmpty;

  /// نسبة النجاح المتوقعة
  double get expectedSuccessRate {
    final totalRequestedProducts = totalProducts + unfulfillableProducts.length + partiallyFulfillableProducts.length;
    return totalRequestedProducts > 0 ? (totalProducts / totalRequestedProducts * 100) : 0;
  }

  /// نص ملخص الخطة
  String get summaryText {
    return 'توزيع على ${warehousesCount} مخزن - ${totalProducts} منتج قابل للتلبية';
  }

  Map<String, dynamic> toJson() {
    return {
      'invoice_id': invoiceId,
      'customer_name': customerName,
      'total_amount': totalAmount,
      'requested_by': requestedBy,
      'warehouse_dispatches': warehouseDispatches.map((plan) => plan.toJson()).toList(),
      'unfulfillable_products': unfulfillableProducts.map((p) => p.toJson()).toList(),
      'partially_fulfillable_products': partiallyFulfillableProducts.map((p) => p.toJson()).toList(),
      'distribution_strategy': distributionStrategy.toString(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// نتيجة التوزيع متعدد المخازن
class MultiWarehouseDispatchResult {
  final bool success;
  final List<WarehouseDispatchModel> createdDispatches;
  final DistributionPlan distributionPlan;
  final List<String> errors;
  final int totalDispatchesCreated;
  final int totalWarehousesInvolved;
  final double completionPercentage;

  const MultiWarehouseDispatchResult({
    required this.success,
    required this.createdDispatches,
    required this.distributionPlan,
    required this.errors,
    required this.totalDispatchesCreated,
    required this.totalWarehousesInvolved,
    required this.completionPercentage,
  });

  /// هل تم التنفيذ بنجاح كامل
  bool get isCompleteSuccess => success && errors.isEmpty;

  /// هل تم التنفيذ جزئياً
  bool get isPartialSuccess => !success && createdDispatches.isNotEmpty;

  /// نص النتيجة
  String get resultText {
    if (isCompleteSuccess) return 'تم التوزيع بنجاح على جميع المخازن';
    if (isPartialSuccess) return 'تم التوزيع جزئياً على ${createdDispatches.length} من ${totalWarehousesInvolved} مخزن';
    return 'فشل في التوزيع';
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'created_dispatches': createdDispatches.map((d) => d.toJson()).toList(),
      'distribution_plan': distributionPlan.toJson(),
      'errors': errors,
      'total_dispatches_created': totalDispatchesCreated,
      'total_warehouses_involved': totalWarehousesInvolved,
      'completion_percentage': completionPercentage,
    };
  }
}

/// ملخص توزيع المخزن
class WarehouseDistributionSummary {
  final String warehouseId;
  final String warehouseName;
  final int productCount;
  final int totalQuantity;
  final bool canFulfillCompletely;

  const WarehouseDistributionSummary({
    required this.warehouseId,
    required this.warehouseName,
    required this.productCount,
    required this.totalQuantity,
    required this.canFulfillCompletely,
  });

  WarehouseDistributionSummary copyWith({
    String? warehouseId,
    String? warehouseName,
    int? productCount,
    int? totalQuantity,
    bool? canFulfillCompletely,
  }) {
    return WarehouseDistributionSummary(
      warehouseId: warehouseId ?? this.warehouseId,
      warehouseName: warehouseName ?? this.warehouseName,
      productCount: productCount ?? this.productCount,
      totalQuantity: totalQuantity ?? this.totalQuantity,
      canFulfillCompletely: canFulfillCompletely ?? this.canFulfillCompletely,
    );
  }
}

/// معاينة التوزيع
class DistributionPreview {
  final int totalProducts;
  final int fulfillableProducts;
  final int partiallyFulfillableProducts;
  final int unfulfillableProducts;
  final List<WarehouseDistributionSummary> warehouseSummaries;
  final bool canProceed;
  final WarehouseSelectionStrategy recommendedStrategy;
  final DateTime previewTimestamp;

  const DistributionPreview({
    required this.totalProducts,
    required this.fulfillableProducts,
    required this.partiallyFulfillableProducts,
    required this.unfulfillableProducts,
    required this.warehouseSummaries,
    required this.canProceed,
    required this.recommendedStrategy,
    required this.previewTimestamp,
  });

  /// نسبة التلبية
  double get fulfillmentRate => totalProducts > 0 ? (fulfillableProducts / totalProducts * 100) : 0;

  /// عدد المخازن المشاركة
  int get warehousesCount => warehouseSummaries.length;

  /// نص ملخص المعاينة
  String get summaryText {
    return 'يمكن تلبية ${fulfillableProducts} من ${totalProducts} منتج من ${warehousesCount} مخزن';
  }

  Map<String, dynamic> toJson() {
    return {
      'total_products': totalProducts,
      'fulfillable_products': fulfillableProducts,
      'partially_fulfillable_products': partiallyFulfillableProducts,
      'unfulfillable_products': unfulfillableProducts,
      'warehouse_summaries': warehouseSummaries.map((s) => {
        'warehouse_id': s.warehouseId,
        'warehouse_name': s.warehouseName,
        'product_count': s.productCount,
        'total_quantity': s.totalQuantity,
        'can_fulfill_completely': s.canFulfillCompletely,
      }).toList(),
      'can_proceed': canProceed,
      'recommended_strategy': recommendedStrategy.toString(),
      'preview_timestamp': previewTimestamp.toIso8601String(),
    };
  }
}
