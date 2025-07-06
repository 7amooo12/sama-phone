/// نماذج البيانات لنظام السحب العالمي المحسن

/// طلب سحب عالمي (بدون ربط بمخزن محدد)
class GlobalWithdrawalRequest {
  final String id;
  final String type;
  final String status;
  final String reason;
  final String requestedBy;
  final String? requesterName;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isGlobalRequest;
  final Map<String, dynamic>? processingMetadata;
  final List<WithdrawalRequestItem> items;

  const GlobalWithdrawalRequest({
    required this.id,
    required this.type,
    required this.status,
    required this.reason,
    required this.requestedBy,
    this.requesterName,
    required this.createdAt,
    this.updatedAt,
    required this.isGlobalRequest,
    this.processingMetadata,
    required this.items,
  });

  factory GlobalWithdrawalRequest.fromJson(Map<String, dynamic> json) {
    return GlobalWithdrawalRequest(
      id: json['id'],
      type: json['type'],
      status: json['status'],
      reason: json['reason'] ?? '',
      requestedBy: json['requested_by'],
      requesterName: json['requester_name'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      isGlobalRequest: json['is_global_request'] ?? false,
      processingMetadata: json['processing_metadata'],
      items: [], // Will be loaded separately
    );
  }

  /// هل تم معالجة الطلب تلقائياً
  bool get isAutoProcessed => processingMetadata?['processing_completed_at'] != null;

  /// هل نجحت المعالجة
  bool get processingSuccess => processingMetadata?['processing_success'] == true;

  /// عدد العناصر المعالجة
  int get itemsProcessed => processingMetadata?['items_processed'] ?? 0;

  /// عدد العناصر الناجحة
  int get itemsSuccessful => processingMetadata?['items_successful'] ?? 0;

  /// إجمالي الكمية المطلوبة
  int get totalRequested => processingMetadata?['total_requested'] ?? 0;

  /// إجمالي الكمية المعالجة
  int get totalProcessed => processingMetadata?['total_processed'] ?? 0;

  /// المخازن المشاركة في التنفيذ
  List<String> get warehousesInvolved => 
      List<String>.from(processingMetadata?['warehouses_involved'] ?? []);

  /// استراتيجية التخصيص المستخدمة
  String get allocationStrategy => processingMetadata?['allocation_strategy'] ?? 'balanced';

  /// نسبة المعالجة
  double get processingPercentage => totalRequested > 0 ? (totalProcessed / totalRequested * 100) : 0;

  /// أخطاء المعالجة
  List<String> get processingErrors => 
      List<String>.from(processingMetadata?['processing_errors'] ?? []);

  /// حالة المعالجة
  GlobalProcessingStatus get processingStatus {
    if (!isGlobalRequest) return GlobalProcessingStatus.notGlobal;
    if (!isAutoProcessed) return GlobalProcessingStatus.pending;
    if (processingSuccess) return GlobalProcessingStatus.completed;
    return GlobalProcessingStatus.failed;
  }

  /// نص حالة المعالجة
  String get processingStatusText {
    switch (processingStatus) {
      case GlobalProcessingStatus.notGlobal:
        return 'طلب تقليدي';
      case GlobalProcessingStatus.pending:
        return 'في انتظار المعالجة';
      case GlobalProcessingStatus.processing:
        return 'قيد المعالجة';
      case GlobalProcessingStatus.completed:
        return 'تم المعالجة بنجاح';
      case GlobalProcessingStatus.failed:
        return 'فشل في المعالجة';
    }
  }

  /// لون حالة المعالجة
  String get processingStatusColor {
    switch (processingStatus) {
      case GlobalProcessingStatus.notGlobal:
        return '#757575'; // رمادي
      case GlobalProcessingStatus.pending:
        return '#FF9800'; // برتقالي
      case GlobalProcessingStatus.processing:
        return '#2196F3'; // أزرق
      case GlobalProcessingStatus.completed:
        return '#4CAF50'; // أخضر
      case GlobalProcessingStatus.failed:
        return '#F44336'; // أحمر
    }
  }
}

/// تخصيص مخزن لطلب سحب عالمي
class WarehouseRequestAllocation {
  final String id;
  final String requestId;
  final String warehouseId;
  final String warehouseName;
  final String productId;
  final String? productName;
  final int allocatedQuantity;
  final int deductedQuantity;
  final String allocationStrategy;
  final int allocationPriority;
  final String? allocationReason;
  final AllocationStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? processedAt;
  final String? processedBy;

  const WarehouseRequestAllocation({
    required this.id,
    required this.requestId,
    required this.warehouseId,
    required this.warehouseName,
    required this.productId,
    this.productName,
    required this.allocatedQuantity,
    required this.deductedQuantity,
    required this.allocationStrategy,
    required this.allocationPriority,
    this.allocationReason,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.processedAt,
    this.processedBy,
  });

  factory WarehouseRequestAllocation.fromJson(Map<String, dynamic> json) {
    return WarehouseRequestAllocation(
      id: json['id'],
      requestId: json['request_id'],
      warehouseId: json['warehouse_id'],
      warehouseName: json['warehouse_name'] ?? 'غير معروف',
      productId: json['product_id'],
      productName: json['product_name'],
      allocatedQuantity: json['allocated_quantity'],
      deductedQuantity: json['deducted_quantity'] ?? 0,
      allocationStrategy: json['allocation_strategy'],
      allocationPriority: json['allocation_priority'] ?? 1,
      allocationReason: json['allocation_reason'],
      status: AllocationStatus.values.firstWhere(
        (s) => s.toString().split('.').last == json['status'],
        orElse: () => AllocationStatus.pending,
      ),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      processedAt: json['processed_at'] != null ? DateTime.parse(json['processed_at']) : null,
      processedBy: json['processed_by'],
    );
  }

  /// هل تم التخصيص بالكامل
  bool get isFullyDeducted => deductedQuantity >= allocatedQuantity;

  /// الكمية المتبقية للخصم
  int get remainingQuantity => allocatedQuantity - deductedQuantity;

  /// نسبة الإنجاز
  double get completionPercentage => allocatedQuantity > 0 ? (deductedQuantity / allocatedQuantity * 100) : 0;

  /// نص الحالة
  String get statusText {
    switch (status) {
      case AllocationStatus.pending:
        return 'في الانتظار';
      case AllocationStatus.processing:
        return 'قيد المعالجة';
      case AllocationStatus.completed:
        return 'مكتمل';
      case AllocationStatus.failed:
        return 'فشل';
      case AllocationStatus.cancelled:
        return 'ملغي';
    }
  }

  /// لون الحالة
  String get statusColor {
    switch (status) {
      case AllocationStatus.pending:
        return '#FF9800'; // برتقالي
      case AllocationStatus.processing:
        return '#2196F3'; // أزرق
      case AllocationStatus.completed:
        return '#4CAF50'; // أخضر
      case AllocationStatus.failed:
        return '#F44336'; // أحمر
      case AllocationStatus.cancelled:
        return '#757575'; // رمادي
    }
  }
}

/// نتيجة معالجة طلب سحب عالمي محسنة
class EnhancedWithdrawalProcessingResult {
  final String requestId;
  final bool success;
  final bool isGlobalRequest;
  final String allocationStrategy;
  final int itemsProcessed;
  final int itemsSuccessful;
  final int totalRequested;
  final int totalProcessed;
  final int allocationsCreated;
  final int deductionsSuccessful;
  final List<String> warehousesInvolved;
  final List<String> errors;
  final List<WarehouseRequestAllocation> allocations;
  final DateTime processingTime;
  final String performedBy;

  const EnhancedWithdrawalProcessingResult({
    required this.requestId,
    required this.success,
    required this.isGlobalRequest,
    required this.allocationStrategy,
    required this.itemsProcessed,
    required this.itemsSuccessful,
    required this.totalRequested,
    required this.totalProcessed,
    required this.allocationsCreated,
    required this.deductionsSuccessful,
    required this.warehousesInvolved,
    required this.errors,
    required this.allocations,
    required this.processingTime,
    required this.performedBy,
  });

  /// عدد العناصر الفاشلة
  int get itemsFailed => itemsProcessed - itemsSuccessful;

  /// عدد التخصيصات الفاشلة
  int get deductionsFailed => allocationsCreated - deductionsSuccessful;

  /// نسبة نجاح العناصر
  double get itemSuccessPercentage => itemsProcessed > 0 ? (itemsSuccessful / itemsProcessed * 100) : 0;

  /// نسبة نجاح التخصيصات
  double get allocationSuccessPercentage => allocationsCreated > 0 ? (deductionsSuccessful / allocationsCreated * 100) : 0;

  /// نسبة المعالجة الإجمالية
  double get overallProcessingPercentage => totalRequested > 0 ? (totalProcessed / totalRequested * 100) : 0;

  /// هل تم الإنجاز بالكامل
  bool get isCompleteSuccess => success && errors.isEmpty && totalProcessed >= totalRequested;

  /// هل تم الإنجاز جزئياً
  bool get isPartialSuccess => success && (errors.isNotEmpty || totalProcessed < totalRequested);

  /// ملخص النتيجة
  String get summaryText {
    if (isCompleteSuccess) {
      return 'تم المعالجة بالكامل من ${warehousesInvolved.length} مخزن';
    } else if (isPartialSuccess) {
      return 'تم معالجة ${overallProcessingPercentage.toStringAsFixed(1)}% من ${warehousesInvolved.length} مخزن';
    } else {
      return 'فشل في المعالجة - ${errors.length} خطأ';
    }
  }

  /// تفاصيل التوزيع
  String get distributionDetails {
    if (warehousesInvolved.length == 1) {
      return 'تم التنفيذ من مخزن واحد';
    } else {
      return 'تم التوزيع على ${warehousesInvolved.length} مخزن';
    }
  }
}

/// حالات معالجة الطلبات العالمية
enum GlobalProcessingStatus {
  notGlobal,    // ليس طلب عالمي
  pending,      // في انتظار المعالجة
  processing,   // قيد المعالجة
  completed,    // تم المعالجة
  failed,       // فشل في المعالجة
}

/// حالات تخصيص المخازن
enum AllocationStatus {
  pending,      // في الانتظار
  processing,   // قيد المعالجة
  completed,    // مكتمل
  failed,       // فشل
  cancelled,    // ملغي
}

/// إعدادات المعالجة العالمية
class GlobalProcessingSettings {
  final String defaultAllocationStrategy;
  final bool autoProcessOnCompletion;
  final bool respectMinimumStock;
  final bool allowPartialFulfillment;
  final int maxWarehousesPerRequest;
  final Duration processingTimeout;
  final bool enableAuditLogging;

  const GlobalProcessingSettings({
    this.defaultAllocationStrategy = 'balanced',
    this.autoProcessOnCompletion = true,
    this.respectMinimumStock = true,
    this.allowPartialFulfillment = true,
    this.maxWarehousesPerRequest = 5,
    this.processingTimeout = const Duration(minutes: 5),
    this.enableAuditLogging = true,
  });
}

/// ملخص أداء المعالجة العالمية
class GlobalProcessingPerformance {
  final int totalRequestsProcessed;
  final int successfulRequests;
  final int failedRequests;
  final double averageProcessingTime;
  final double averageWarehousesPerRequest;
  final double averageAllocationEfficiency;
  final DateTime periodStart;
  final DateTime periodEnd;

  const GlobalProcessingPerformance({
    required this.totalRequestsProcessed,
    required this.successfulRequests,
    required this.failedRequests,
    required this.averageProcessingTime,
    required this.averageWarehousesPerRequest,
    required this.averageAllocationEfficiency,
    required this.periodStart,
    required this.periodEnd,
  });

  /// نسبة النجاح
  double get successRate => totalRequestsProcessed > 0 ? (successfulRequests / totalRequestsProcessed * 100) : 0;

  /// نسبة الفشل
  double get failureRate => totalRequestsProcessed > 0 ? (failedRequests / totalRequestsProcessed * 100) : 0;

  /// مدة الفترة
  Duration get periodDuration => periodEnd.difference(periodStart);
}

/// تفاصيل تخصيص المنتج
class ProductAllocationDetail {
  final String productId;
  final String productName;
  final int totalRequested;
  final int totalAllocated;
  final int totalDeducted;
  final List<WarehouseRequestAllocation> warehouseAllocations;

  const ProductAllocationDetail({
    required this.productId,
    required this.productName,
    required this.totalRequested,
    required this.totalAllocated,
    required this.totalDeducted,
    required this.warehouseAllocations,
  });

  /// هل تم تلبية الطلب بالكامل
  bool get isFullyFulfilled => totalDeducted >= totalRequested;

  /// نسبة التلبية
  double get fulfillmentPercentage => totalRequested > 0 ? (totalDeducted / totalRequested * 100) : 0;

  /// عدد المخازن المستخدمة
  int get warehousesUsed => warehouseAllocations.length;

  /// الكمية المتبقية
  int get remainingQuantity => totalRequested - totalDeducted;
}
