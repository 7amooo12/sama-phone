/// نماذج البيانات لتحليل حذف المخازن
/// 
/// تحتوي على جميع النماذج المطلوبة لتحليل وإدارة عملية حذف المخازن
/// مع التعامل مع الطلبات النشطة والمخزون والمعاملات

/// تحليل شامل لإمكانية حذف المخزن
class WarehouseDeletionAnalysis {
  final String warehouseId;
  final String warehouseName;
  final bool canDelete;
  final List<String> blockingFactors;
  final List<WarehouseDeletionAction> requiredActions;
  final List<WarehouseRequestSummary> activeRequests;
  final InventoryAnalysis inventoryAnalysis;
  final TransactionAnalysis transactionAnalysis;
  final String estimatedCleanupTime;
  final DeletionRiskLevel riskLevel;

  const WarehouseDeletionAnalysis({
    required this.warehouseId,
    required this.warehouseName,
    required this.canDelete,
    required this.blockingFactors,
    required this.requiredActions,
    required this.activeRequests,
    required this.inventoryAnalysis,
    required this.transactionAnalysis,
    required this.estimatedCleanupTime,
    required this.riskLevel,
  });

  /// عدد العوامل المانعة للحذف
  int get blockingFactorCount => blockingFactors.length;

  /// هل يحتاج إجراءات عالية الأولوية
  bool get hasHighPriorityActions => requiredActions.any((action) => action.priority == DeletionActionPriority.high);

  /// إجمالي العناصر المتأثرة
  int get totalAffectedItems => requiredActions.fold(0, (sum, action) => sum + action.affectedItems);

  /// رسالة الحالة
  String get statusMessage {
    if (canDelete) {
      return 'يمكن حذف المخزن بأمان';
    } else {
      return 'يتطلب حذف المخزن ${blockingFactors.length} إجراء تنظيف';
    }
  }

  /// لون مستوى المخاطر
  String get riskLevelColor {
    switch (riskLevel) {
      case DeletionRiskLevel.none:
        return '#4CAF50'; // أخضر
      case DeletionRiskLevel.low:
        return '#FF9800'; // برتقالي
      case DeletionRiskLevel.medium:
        return '#FF5722'; // برتقالي محمر
      case DeletionRiskLevel.high:
        return '#F44336'; // أحمر
    }
  }

  /// نص مستوى المخاطر
  String get riskLevelText {
    switch (riskLevel) {
      case DeletionRiskLevel.none:
        return 'لا توجد مخاطر';
      case DeletionRiskLevel.low:
        return 'مخاطر منخفضة';
      case DeletionRiskLevel.medium:
        return 'مخاطر متوسطة';
      case DeletionRiskLevel.high:
        return 'مخاطر عالية';
    }
  }
}

/// إجراء مطلوب لحذف المخزن
class WarehouseDeletionAction {
  final DeletionActionType type;
  final String title;
  final String description;
  final DeletionActionPriority priority;
  final String estimatedTime;
  final int affectedItems;
  final bool isCompleted;

  const WarehouseDeletionAction({
    required this.type,
    required this.title,
    required this.description,
    required this.priority,
    required this.estimatedTime,
    required this.affectedItems,
    this.isCompleted = false,
  });

  /// أيقونة الإجراء
  String get icon {
    switch (type) {
      case DeletionActionType.manageRequests:
        return '📋';
      case DeletionActionType.manageInventory:
        return '📦';
      case DeletionActionType.archiveTransactions:
        return '📊';
      case DeletionActionType.exportData:
        return '💾';
      case DeletionActionType.notifyUsers:
        return '📢';
    }
  }

  /// لون الأولوية
  String get priorityColor {
    switch (priority) {
      case DeletionActionPriority.high:
        return '#F44336'; // أحمر
      case DeletionActionPriority.medium:
        return '#FF9800'; // برتقالي
      case DeletionActionPriority.low:
        return '#4CAF50'; // أخضر
    }
  }

  /// نص الأولوية
  String get priorityText {
    switch (priority) {
      case DeletionActionPriority.high:
        return 'عالية';
      case DeletionActionPriority.medium:
        return 'متوسطة';
      case DeletionActionPriority.low:
        return 'منخفضة';
    }
  }

  /// إنشاء نسخة محدثة
  WarehouseDeletionAction copyWith({
    DeletionActionType? type,
    String? title,
    String? description,
    DeletionActionPriority? priority,
    String? estimatedTime,
    int? affectedItems,
    bool? isCompleted,
  }) {
    return WarehouseDeletionAction(
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      estimatedTime: estimatedTime ?? this.estimatedTime,
      affectedItems: affectedItems ?? this.affectedItems,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

/// ملخص طلب المخزن
class WarehouseRequestSummary {
  final String id;
  final String type;
  final String status;
  final String reason;
  final String requestedBy;
  final String requesterName;
  final DateTime createdAt;

  const WarehouseRequestSummary({
    required this.id,
    required this.type,
    required this.status,
    required this.reason,
    required this.requestedBy,
    required this.requesterName,
    required this.createdAt,
  });

  /// نص نوع الطلب
  String get typeText {
    switch (type) {
      case 'withdrawal':
        return 'طلب سحب';
      case 'transfer':
        return 'طلب نقل';
      case 'adjustment':
        return 'طلب تعديل';
      default:
        return type;
    }
  }

  /// نص حالة الطلب
  String get statusText {
    switch (status) {
      case 'pending':
        return 'في الانتظار';
      case 'approved':
        return 'موافق عليه';
      case 'in_progress':
        return 'قيد التنفيذ';
      case 'completed':
        return 'مكتمل';
      case 'cancelled':
        return 'ملغي';
      default:
        return status;
    }
  }

  /// لون حالة الطلب
  String get statusColor {
    switch (status) {
      case 'pending':
        return '#FF9800'; // برتقالي
      case 'approved':
        return '#2196F3'; // أزرق
      case 'in_progress':
        return '#9C27B0'; // بنفسجي
      case 'completed':
        return '#4CAF50'; // أخضر
      case 'cancelled':
        return '#757575'; // رمادي
      default:
        return '#757575';
    }
  }

  /// عمر الطلب بالأيام
  int get ageInDays => DateTime.now().difference(createdAt).inDays;

  /// هل الطلب قديم (أكثر من 7 أيام)
  bool get isOld => ageInDays > 7;
}

/// تحليل المخزون
class InventoryAnalysis {
  final int totalItems;
  final int totalQuantity;
  final int lowStockItems;
  final int highValueItems;

  const InventoryAnalysis({
    required this.totalItems,
    required this.totalQuantity,
    required this.lowStockItems,
    required this.highValueItems,
  });

  /// هل المخزون فارغ
  bool get isEmpty => totalItems == 0;

  /// هل يحتوي على مخزون كبير
  bool get hasSignificantInventory => totalQuantity > 100;

  /// نسبة المنتجات منخفضة المخزون
  double get lowStockPercentage => totalItems > 0 ? (lowStockItems / totalItems) * 100 : 0;
}

/// تحليل المعاملات
class TransactionAnalysis {
  final int totalTransactions;
  final int recentTransactions;

  const TransactionAnalysis({
    required this.totalTransactions,
    required this.recentTransactions,
  });

  /// هل توجد معاملات حديثة
  bool get hasRecentActivity => recentTransactions > 0;

  /// نسبة المعاملات الحديثة
  double get recentActivityPercentage => totalTransactions > 0 ? (recentTransactions / totalTransactions) * 100 : 0;
}

/// أنواع الإجراءات المطلوبة للحذف
enum DeletionActionType {
  manageRequests,
  manageInventory,
  archiveTransactions,
  exportData,
  notifyUsers,
}

/// أولوية الإجراءات
enum DeletionActionPriority {
  high,
  medium,
  low,
}

/// مستوى مخاطر الحذف
enum DeletionRiskLevel {
  none,
  low,
  medium,
  high,
}

/// نتيجة عملية تنظيف المخزن
class WarehouseCleanupResult {
  final bool success;
  final String message;
  final int processedRequests;
  final int processedInventoryItems;
  final int archivedTransactions;
  final List<String> errors;
  final Duration processingTime;

  const WarehouseCleanupResult({
    required this.success,
    required this.message,
    required this.processedRequests,
    required this.processedInventoryItems,
    required this.archivedTransactions,
    required this.errors,
    required this.processingTime,
  });

  /// هل العملية نجحت بالكامل
  bool get isCompleteSuccess => success && errors.isEmpty;

  /// هل العملية نجحت جزئياً
  bool get isPartialSuccess => success && errors.isNotEmpty;

  /// إجمالي العناصر المعالجة
  int get totalProcessedItems => processedRequests + processedInventoryItems + archivedTransactions;
}
