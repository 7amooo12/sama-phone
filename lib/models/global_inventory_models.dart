/// نماذج البيانات لنظام المخزون العالمي والخصم التلقائي

/// نتيجة البحث العالمي في المخزون
class GlobalInventorySearchResult {
  final String productId;
  final int requestedQuantity;
  final int totalAvailableQuantity;
  final bool canFulfill;
  final List<WarehouseInventoryAvailability> availableWarehouses;
  final List<InventoryAllocation> allocationPlan;
  final WarehouseSelectionStrategy searchStrategy;
  final DateTime searchTimestamp;
  final String? error;

  const GlobalInventorySearchResult({
    required this.productId,
    required this.requestedQuantity,
    required this.totalAvailableQuantity,
    required this.canFulfill,
    required this.availableWarehouses,
    required this.allocationPlan,
    required this.searchStrategy,
    required this.searchTimestamp,
    this.error,
  });

  /// هل يمكن تلبية الطلب بالكامل
  bool get canFulfillCompletely => canFulfill && totalAllocatedQuantity >= requestedQuantity;

  /// إجمالي الكمية المخصصة
  int get totalAllocatedQuantity => allocationPlan.fold(0, (sum, allocation) => sum + allocation.allocatedQuantity);

  /// عدد المخازن المطلوبة للتلبية
  int get requiredWarehousesCount => allocationPlan.length;

  /// الكمية المتبقية غير المتاحة
  int get shortfallQuantity => (requestedQuantity - totalAvailableQuantity).clamp(0, requestedQuantity);

  /// نسبة التلبية
  double get fulfillmentPercentage => requestedQuantity > 0 ? (totalAvailableQuantity / requestedQuantity * 100).clamp(0, 100) : 0;

  /// ملخص النتيجة
  String get summaryText {
    if (canFulfillCompletely) {
      return 'يمكن تلبية الطلب بالكامل من ${requiredWarehousesCount} مخزن';
    } else if (canFulfill) {
      return 'يمكن تلبية ${fulfillmentPercentage.toStringAsFixed(1)}% من الطلب';
    } else {
      return 'لا يمكن تلبية الطلب - نقص ${shortfallQuantity} قطعة';
    }
  }
}

/// توفر المخزون في مخزن معين
class WarehouseInventoryAvailability {
  final String warehouseId;
  final String warehouseName;
  final String warehouseAddress;
  final int warehousePriority;
  final String productId;
  final int availableQuantity;
  final int minimumStock;
  final int maximumStock;
  final String productName;
  final String productSku;
  final DateTime lastUpdated;

  const WarehouseInventoryAvailability({
    required this.warehouseId,
    required this.warehouseName,
    required this.warehouseAddress,
    required this.warehousePriority,
    required this.productId,
    required this.availableQuantity,
    required this.minimumStock,
    required this.maximumStock,
    required this.productName,
    required this.productSku,
    required this.lastUpdated,
  });

  /// هل المخزون منخفض
  bool get isLowStock => availableQuantity <= minimumStock;

  /// هل المخزون نافد
  bool get isOutOfStock => availableQuantity <= 0;

  /// الكمية الزائدة عن الحد الأدنى
  int get excessQuantity => (availableQuantity - minimumStock).clamp(0, availableQuantity);

  /// نسبة امتلاء المخزن
  double get stockPercentage => maximumStock > 0 ? (availableQuantity / maximumStock * 100).clamp(0, 100) : 0;

  /// حالة المخزون
  InventoryStatus get status {
    if (isOutOfStock) return InventoryStatus.outOfStock;
    if (isLowStock) return InventoryStatus.lowStock;
    if (stockPercentage >= 80) return InventoryStatus.highStock;
    return InventoryStatus.normalStock;
  }

  /// لون حالة المخزون
  String get statusColor {
    switch (status) {
      case InventoryStatus.outOfStock:
        return '#F44336'; // أحمر
      case InventoryStatus.lowStock:
        return '#FF9800'; // برتقالي
      case InventoryStatus.normalStock:
        return '#4CAF50'; // أخضر
      case InventoryStatus.highStock:
        return '#2196F3'; // أزرق
    }
  }

  /// نص حالة المخزون
  String get statusText {
    switch (status) {
      case InventoryStatus.outOfStock:
        return 'نافد';
      case InventoryStatus.lowStock:
        return 'منخفض';
      case InventoryStatus.normalStock:
        return 'طبيعي';
      case InventoryStatus.highStock:
        return 'مرتفع';
    }
  }
}

/// تخصيص المخزون لطلب معين
class InventoryAllocation {
  final String warehouseId;
  final String warehouseName;
  final String productId;
  final int allocatedQuantity;
  final int availableQuantity;
  final int minimumStock;
  final String allocationReason;
  final int allocationPriority;
  final DateTime estimatedDeductionTime;
  final bool isExecuted;
  final DateTime? executionTime;

  const InventoryAllocation({
    required this.warehouseId,
    required this.warehouseName,
    required this.productId,
    required this.allocatedQuantity,
    required this.availableQuantity,
    required this.minimumStock,
    required this.allocationReason,
    required this.allocationPriority,
    required this.estimatedDeductionTime,
    this.isExecuted = false,
    this.executionTime,
  });

  /// نسبة التخصيص من المخزون المتاح
  double get allocationPercentage => availableQuantity > 0 ? (allocatedQuantity / availableQuantity * 100) : 0;

  /// الكمية المتبقية بعد التخصيص
  int get remainingAfterAllocation => availableQuantity - allocatedQuantity;

  /// هل التخصيص سيؤدي إلى مخزون منخفض
  bool get willCauseLowStock => remainingAfterAllocation <= minimumStock;

  /// إنشاء نسخة محدثة
  InventoryAllocation copyWith({
    String? warehouseId,
    String? warehouseName,
    String? productId,
    int? allocatedQuantity,
    int? availableQuantity,
    int? minimumStock,
    String? allocationReason,
    int? allocationPriority,
    DateTime? estimatedDeductionTime,
    bool? isExecuted,
    DateTime? executionTime,
  }) {
    return InventoryAllocation(
      warehouseId: warehouseId ?? this.warehouseId,
      warehouseName: warehouseName ?? this.warehouseName,
      productId: productId ?? this.productId,
      allocatedQuantity: allocatedQuantity ?? this.allocatedQuantity,
      availableQuantity: availableQuantity ?? this.availableQuantity,
      minimumStock: minimumStock ?? this.minimumStock,
      allocationReason: allocationReason ?? this.allocationReason,
      allocationPriority: allocationPriority ?? this.allocationPriority,
      estimatedDeductionTime: estimatedDeductionTime ?? this.estimatedDeductionTime,
      isExecuted: isExecuted ?? this.isExecuted,
      executionTime: executionTime ?? this.executionTime,
    );
  }
}

/// نتيجة عملية الخصم من المخزون
class InventoryDeductionResult {
  final String requestId;
  final int totalRequestedQuantity;
  final int totalDeductedQuantity;
  final bool success;
  final List<WarehouseDeductionResult> warehouseResults;
  final List<String> errors;
  final DateTime executionTime;
  final String performedBy;

  const InventoryDeductionResult({
    required this.requestId,
    required this.totalRequestedQuantity,
    required this.totalDeductedQuantity,
    required this.success,
    required this.warehouseResults,
    required this.errors,
    required this.executionTime,
    required this.performedBy,
  });

  /// هل تم الخصم بالكامل
  bool get isCompleteDeduction => totalDeductedQuantity >= totalRequestedQuantity;

  /// نسبة الخصم المكتمل
  double get deductionPercentage => totalRequestedQuantity > 0 ? (totalDeductedQuantity / totalRequestedQuantity * 100) : 0;

  /// عدد المخازن التي تم الخصم منها بنجاح
  int get successfulWarehousesCount => warehouseResults.where((r) => r.success).length;

  /// عدد المخازن التي فشل الخصم منها
  int get failedWarehousesCount => warehouseResults.where((r) => !r.success).length;

  /// الكمية المتبقية غير المخصومة
  int get remainingQuantity => totalRequestedQuantity - totalDeductedQuantity;

  /// ملخص النتيجة
  String get summaryText {
    if (isCompleteDeduction) {
      return 'تم الخصم بالكامل من ${successfulWarehousesCount} مخزن';
    } else if (success) {
      return 'تم خصم ${deductionPercentage.toStringAsFixed(1)}% من ${successfulWarehousesCount} مخزن';
    } else {
      return 'فشل في الخصم - ${errors.length} خطأ';
    }
  }
}

/// نتيجة الخصم من مخزن واحد
class WarehouseDeductionResult {
  final String warehouseId;
  final String warehouseName;
  final String productId;
  final int requestedQuantity;
  final int deductedQuantity;
  final int remainingQuantity;
  final bool success;
  final String? transactionId;
  final String? error;
  final DateTime deductionTime;

  const WarehouseDeductionResult({
    required this.warehouseId,
    required this.warehouseName,
    required this.productId,
    required this.requestedQuantity,
    required this.deductedQuantity,
    required this.remainingQuantity,
    required this.success,
    this.transactionId,
    this.error,
    required this.deductionTime,
  });

  /// هل تم الخصم بالكامل من هذا المخزن
  bool get isCompleteDeduction => deductedQuantity >= requestedQuantity;

  /// نسبة الخصم من هذا المخزن
  double get deductionPercentage => requestedQuantity > 0 ? (deductedQuantity / requestedQuantity * 100) : 0;
}

/// ملخص المخزون العالمي لمنتج
class ProductGlobalInventorySummary {
  final String productId;
  final int totalAvailableQuantity;
  final int totalWarehouses;
  final int warehousesWithStock;
  final int warehousesLowStock;
  final int warehousesOutOfStock;
  final DateTime lastUpdated;
  final List<WarehouseInventoryAvailability> warehouseBreakdown;

  const ProductGlobalInventorySummary({
    required this.productId,
    required this.totalAvailableQuantity,
    required this.totalWarehouses,
    required this.warehousesWithStock,
    required this.warehousesLowStock,
    required this.warehousesOutOfStock,
    required this.lastUpdated,
    required this.warehouseBreakdown,
  });

  /// نسبة المخازن التي لديها مخزون
  double get stockAvailabilityPercentage => totalWarehouses > 0 ? (warehousesWithStock / totalWarehouses * 100) : 0;

  /// نسبة المخازن ذات المخزون المنخفض
  double get lowStockPercentage => totalWarehouses > 0 ? (warehousesLowStock / totalWarehouses * 100) : 0;

  /// متوسط المخزون لكل مخزن
  double get averageStockPerWarehouse => warehousesWithStock > 0 ? (totalAvailableQuantity / warehousesWithStock) : 0;

  /// حالة المخزون العامة
  GlobalInventoryStatus get overallStatus {
    if (warehousesOutOfStock == totalWarehouses) return GlobalInventoryStatus.criticallyLow;
    if (lowStockPercentage >= 50) return GlobalInventoryStatus.low;
    if (stockAvailabilityPercentage >= 80) return GlobalInventoryStatus.good;
    return GlobalInventoryStatus.moderate;
  }

  /// لون الحالة العامة
  String get statusColor {
    switch (overallStatus) {
      case GlobalInventoryStatus.criticallyLow:
        return '#F44336'; // أحمر
      case GlobalInventoryStatus.low:
        return '#FF9800'; // برتقالي
      case GlobalInventoryStatus.moderate:
        return '#FFC107'; // أصفر
      case GlobalInventoryStatus.good:
        return '#4CAF50'; // أخضر
    }
  }

  /// نص الحالة العامة
  String get statusText {
    switch (overallStatus) {
      case GlobalInventoryStatus.criticallyLow:
        return 'منخفض جداً';
      case GlobalInventoryStatus.low:
        return 'منخفض';
      case GlobalInventoryStatus.moderate:
        return 'متوسط';
      case GlobalInventoryStatus.good:
        return 'جيد';
    }
  }
}

/// استراتيجيات اختيار المخازن
enum WarehouseSelectionStrategy {
  priorityBased,    // حسب أولوية المخزن
  highestStock,     // أعلى مخزون أولاً
  lowestStock,      // أقل مخزون أولاً (لتفريغ المخازن)
  fifo,            // الأقدم أولاً
  balanced,        // توزيع متوازن
}

/// حالات المخزون
enum InventoryStatus {
  outOfStock,      // نافد
  lowStock,        // منخفض
  normalStock,     // طبيعي
  highStock,       // مرتفع
}

/// حالات المخزون العالمي
enum GlobalInventoryStatus {
  criticallyLow,   // منخفض جداً
  low,            // منخفض
  moderate,       // متوسط
  good,           // جيد
}

/// إعدادات البحث العالمي
class GlobalSearchSettings {
  final WarehouseSelectionStrategy defaultStrategy;
  final bool respectMinimumStock;
  final bool allowPartialFulfillment;
  final int maxWarehousesPerRequest;
  final Duration searchTimeout;

  const GlobalSearchSettings({
    this.defaultStrategy = WarehouseSelectionStrategy.balanced,
    this.respectMinimumStock = true,
    this.allowPartialFulfillment = true,
    this.maxWarehousesPerRequest = 5,
    this.searchTimeout = const Duration(seconds: 30),
  });
}

/// نتيجة التحقق من توفر المخزون
class InventoryAvailabilityCheck {
  final String productId;
  final int requestedQuantity;
  final bool isAvailable;
  final int availableQuantity;
  final int shortfall;
  final List<String> availableWarehouses;
  final DateTime checkTime;

  const InventoryAvailabilityCheck({
    required this.productId,
    required this.requestedQuantity,
    required this.isAvailable,
    required this.availableQuantity,
    required this.shortfall,
    required this.availableWarehouses,
    required this.checkTime,
  });

  /// نسبة التوفر
  double get availabilityPercentage => requestedQuantity > 0 ? (availableQuantity / requestedQuantity * 100).clamp(0, 100) : 0;
}
