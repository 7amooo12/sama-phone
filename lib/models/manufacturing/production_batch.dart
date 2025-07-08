import 'package:flutter/material.dart';

/// نموذج دفعة الإنتاج
class ProductionBatch {
  final int id;
  final int productId;
  final double unitsProduced;
  final DateTime completionDate;
  final String? warehouseManagerName;
  final String status;
  final String? notes;
  final DateTime createdAt;

  const ProductionBatch({
    required this.id,
    required this.productId,
    required this.unitsProduced,
    required this.completionDate,
    this.warehouseManagerName,
    required this.status,
    this.notes,
    required this.createdAt,
  });

  /// إنشاء من JSON
  factory ProductionBatch.fromJson(Map<String, dynamic> json) {
    return ProductionBatch(
      id: json['id'] as int,
      productId: json['product_id'] as int,
      unitsProduced: (json['units_produced'] as num).toDouble(),
      completionDate: DateTime.parse(json['completion_date'] as String),
      warehouseManagerName: json['warehouse_manager_name'] as String?,
      status: json['status'] as String,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// تحويل إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'units_produced': unitsProduced,
      'completion_date': completionDate.toIso8601String(),
      'warehouse_manager_name': warehouseManagerName,
      'status': status,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// إنشاء نسخة محدثة
  ProductionBatch copyWith({
    int? id,
    int? productId,
    double? unitsProduced,
    DateTime? completionDate,
    String? warehouseManagerName,
    String? status,
    String? notes,
    DateTime? createdAt,
  }) {
    return ProductionBatch(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      unitsProduced: unitsProduced ?? this.unitsProduced,
      completionDate: completionDate ?? this.completionDate,
      warehouseManagerName: warehouseManagerName ?? this.warehouseManagerName,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// الحصول على نص الحالة بالعربية
  String get statusText {
    switch (status) {
      case 'pending':
        return 'في الانتظار';
      case 'in_progress':
        return 'قيد التنفيذ';
      case 'completed':
        return 'مكتمل';
      case 'cancelled':
        return 'ملغي';
      default:
        return 'غير محدد';
    }
  }

  /// الحصول على لون الحالة
  String get statusColor {
    switch (status) {
      case 'pending':
        return 'orange';
      case 'in_progress':
        return 'blue';
      case 'completed':
        return 'green';
      case 'cancelled':
        return 'red';
      default:
        return 'grey';
    }
  }

  /// التحقق من إمكانية التعديل
  bool get canEdit {
    return status == 'pending' || status == 'in_progress';
  }

  /// التحقق من إمكانية الإلغاء
  bool get canCancel {
    return status == 'pending' || status == 'in_progress';
  }

  /// التحقق من إمكانية الإكمال
  bool get canComplete {
    return status == 'in_progress';
  }

  /// التحقق من كون الدفعة مكتملة
  bool get isCompleted {
    return status == 'completed';
  }

  /// التحقق من كون الدفعة قيد التنفيذ
  bool get isInProgress {
    return status == 'in_progress';
  }

  /// التحقق من كون الدفعة في الانتظار
  bool get isPending {
    return status == 'pending';
  }

  /// التحقق من كون الدفعة ملغية
  bool get isCancelled {
    return status == 'cancelled';
  }

  /// الحصول على تاريخ الإنتاج منسق
  String get formattedCompletionDate {
    return '${completionDate.day}/${completionDate.month}/${completionDate.year}';
  }

  /// الحصول على وقت الإنتاج منسق
  String get formattedCompletionTime {
    return '${completionDate.hour.toString().padLeft(2, '0')}:${completionDate.minute.toString().padLeft(2, '0')}';
  }

  @override
  String toString() {
    return 'ProductionBatch(id: $id, productId: $productId, unitsProduced: $unitsProduced, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProductionBatch && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// نموذج إنشاء دفعة إنتاج جديدة
class CreateProductionBatchRequest {
  final int productId;
  final double unitsProduced;
  final String? notes;

  const CreateProductionBatchRequest({
    required this.productId,
    required this.unitsProduced,
    this.notes,
  });

  /// تحويل إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'units_produced': unitsProduced,
      'notes': notes,
    };
  }

  /// التحقق من صحة البيانات
  bool get isValid {
    return productId > 0 && unitsProduced > 0;
  }

  /// الحصول على رسائل الخطأ
  List<String> get validationErrors {
    final errors = <String>[];
    
    if (productId <= 0) {
      errors.add('معرف المنتج غير صحيح');
    }
    
    if (unitsProduced <= 0) {
      errors.add('عدد الوحدات المنتجة يجب أن يكون أكبر من صفر');
    }
    
    return errors;
  }
}

/// نموذج تاريخ استخدام الأداة
class ToolUsageHistory {
  final int id;
  final int toolId;
  final String toolName;
  final int? batchId;
  final int? productId;
  final String? productName;
  final double quantityUsed;
  final double remainingStock;
  final DateTime usageDate;
  final String? warehouseManagerName;
  final String operationType;
  final String? notes;

  const ToolUsageHistory({
    required this.id,
    required this.toolId,
    required this.toolName,
    this.batchId,
    this.productId,
    this.productName,
    required this.quantityUsed,
    required this.remainingStock,
    required this.usageDate,
    this.warehouseManagerName,
    required this.operationType,
    this.notes,
  });

  /// إنشاء من JSON
  factory ToolUsageHistory.fromJson(Map<String, dynamic> json) {
    return ToolUsageHistory(
      id: json['id'] as int,
      toolId: json['tool_id'] as int,
      toolName: json['tool_name'] as String,
      batchId: json['batch_id'] as int?,
      productId: json['product_id'] as int?,
      productName: json['product_name'] as String?,
      quantityUsed: (json['quantity_used'] as num).toDouble(),
      remainingStock: (json['remaining_stock'] as num).toDouble(),
      usageDate: DateTime.parse(json['usage_date'] as String),
      warehouseManagerName: json['warehouse_manager_name'] as String?,
      operationType: json['operation_type'] as String,
      notes: json['notes'] as String?,
    );
  }

  /// تحويل إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tool_id': toolId,
      'tool_name': toolName,
      'batch_id': batchId,
      'product_id': productId,
      'product_name': productName,
      'quantity_used': quantityUsed,
      'remaining_stock': remainingStock,
      'usage_date': usageDate.toIso8601String(),
      'warehouse_manager_name': warehouseManagerName,
      'operation_type': operationType,
      'notes': notes,
    };
  }

  /// الحصول على نص نوع العملية بالعربية
  String get operationTypeText {
    switch (operationType) {
      case 'production':
        return 'إنتاج';
      case 'adjustment':
        return 'تعديل';
      case 'import':
        return 'استيراد';
      case 'export':
        return 'تصدير';
      default:
        return 'غير محدد';
    }
  }

  /// الحصول على تاريخ الاستخدام منسق
  String get formattedUsageDate {
    return '${usageDate.day}/${usageDate.month}/${usageDate.year}';
  }

  /// الحصول على وقت الاستخدام منسق
  String get formattedUsageTime {
    return '${usageDate.hour.toString().padLeft(2, '0')}:${usageDate.minute.toString().padLeft(2, '0')}';
  }

  /// الحصول على تاريخ ووقت الاستخدام منسق
  String get formattedUsageDateTime {
    return '$formattedUsageDate $formattedUsageTime';
  }

  /// الحصول على اسم وصفي للعملية يتضمن اسم المنتج
  String get descriptiveOperationName {
    if (operationType == 'production' && productName != null && productName!.isNotEmpty) {
      return 'إنتاج: $productName';
    } else if (operationType == 'production' && batchId != null) {
      return 'إنتاج: دفعة رقم $batchId';
    } else {
      return operationTypeText;
    }
  }

  /// الحصول على تفاصيل العملية مع الكمية
  String get operationDetails {
    if (operationType == 'production' && productName != null && productName!.isNotEmpty) {
      return 'إنتاج: $productName - ${quantityUsed.toStringAsFixed(1)} وحدة';
    } else if (operationType == 'production' && batchId != null) {
      return 'إنتاج: دفعة رقم $batchId - ${quantityUsed.toStringAsFixed(1)} وحدة';
    } else {
      return '$operationTypeText - ${quantityUsed.toStringAsFixed(1)} وحدة';
    }
  }

  @override
  String toString() {
    return 'ToolUsageHistory(id: $id, toolName: $toolName, quantityUsed: $quantityUsed, operationType: $operationType)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ToolUsageHistory && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// حالات دفعة الإنتاج
enum ProductionBatchStatus {
  pending,
  inProgress,
  completed,
  cancelled;

  /// الحصول على النص بالعربية
  String get arabicText {
    switch (this) {
      case ProductionBatchStatus.pending:
        return 'في الانتظار';
      case ProductionBatchStatus.inProgress:
        return 'قيد التنفيذ';
      case ProductionBatchStatus.completed:
        return 'مكتمل';
      case ProductionBatchStatus.cancelled:
        return 'ملغي';
    }
  }

  /// الحصول على اللون
  String get colorName {
    switch (this) {
      case ProductionBatchStatus.pending:
        return 'orange';
      case ProductionBatchStatus.inProgress:
        return 'blue';
      case ProductionBatchStatus.completed:
        return 'green';
      case ProductionBatchStatus.cancelled:
        return 'red';
    }
  }

  /// إنشاء من النص
  static ProductionBatchStatus fromString(String status) {
    switch (status) {
      case 'pending':
        return ProductionBatchStatus.pending;
      case 'in_progress':
        return ProductionBatchStatus.inProgress;
      case 'completed':
        return ProductionBatchStatus.completed;
      case 'cancelled':
        return ProductionBatchStatus.cancelled;
      default:
        return ProductionBatchStatus.pending;
    }
  }
}

/// أنواع عمليات استخدام الأدوات
enum ToolOperationType {
  production,
  adjustment,
  import,
  export;

  /// الحصول على النص بالعربية
  String get arabicText {
    switch (this) {
      case ToolOperationType.production:
        return 'إنتاج';
      case ToolOperationType.adjustment:
        return 'تعديل';
      case ToolOperationType.import:
        return 'استيراد';
      case ToolOperationType.export:
        return 'تصدير';
    }
  }

  /// إنشاء من النص
  static ToolOperationType fromString(String type) {
    switch (type) {
      case 'production':
        return ToolOperationType.production;
      case 'adjustment':
        return ToolOperationType.adjustment;
      case 'import':
        return ToolOperationType.import;
      case 'export':
        return ToolOperationType.export;
      default:
        return ToolOperationType.adjustment;
    }
  }
}

/// نموذج تحليلات استخدام أدوات التصنيع
class ToolUsageAnalytics {
  final int toolId;
  final String toolName;
  final String unit;
  final double quantityUsedPerUnit;
  final double totalQuantityUsed;
  final double remainingStock;
  final double initialStock;
  final double usagePercentage;
  final String stockStatus;
  final List<ToolUsageEntry> usageHistory;

  const ToolUsageAnalytics({
    required this.toolId,
    required this.toolName,
    required this.unit,
    required this.quantityUsedPerUnit,
    required this.totalQuantityUsed,
    required this.remainingStock,
    required this.initialStock,
    required this.usagePercentage,
    required this.stockStatus,
    required this.usageHistory,
  });

  /// إنشاء من JSON
  factory ToolUsageAnalytics.fromJson(Map<String, dynamic> json) {
    final usageHistoryList = json['usage_history'] as List<dynamic>? ?? [];
    final usageHistory = usageHistoryList
        .map((item) => ToolUsageEntry.fromJson(item as Map<String, dynamic>))
        .toList();

    return ToolUsageAnalytics(
      toolId: json['tool_id'] as int,
      toolName: json['tool_name'] as String,
      unit: json['unit'] as String,
      quantityUsedPerUnit: (json['quantity_used_per_unit'] as num).toDouble(),
      totalQuantityUsed: (json['total_quantity_used'] as num).toDouble(),
      remainingStock: (json['remaining_stock'] as num).toDouble(),
      initialStock: (json['initial_stock'] as num).toDouble(),
      usagePercentage: (json['usage_percentage'] as num).toDouble(),
      stockStatus: json['stock_status'] as String,
      usageHistory: usageHistory,
    );
  }

  /// تحويل إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'tool_id': toolId,
      'tool_name': toolName,
      'unit': unit,
      'quantity_used_per_unit': quantityUsedPerUnit,
      'total_quantity_used': totalQuantityUsed,
      'remaining_stock': remainingStock,
      'initial_stock': initialStock,
      'usage_percentage': usagePercentage,
      'stock_status': stockStatus,
      'usage_history': usageHistory.map((entry) => entry.toJson()).toList(),
    };
  }

  /// الحصول على لون حالة المخزون
  Color get stockStatusColor {
    switch (stockStatus.toLowerCase()) {
      case 'high':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.red;
      case 'critical':
        return Colors.red.shade800;
      default:
        return Colors.grey;
    }
  }

  /// الحصول على نص حالة المخزون بالعربية
  String get stockStatusText {
    switch (stockStatus.toLowerCase()) {
      case 'high':
        return 'مخزون عالي';
      case 'medium':
        return 'مخزون متوسط';
      case 'low':
        return 'مخزون منخفض';
      case 'critical':
        return 'مخزون حرج';
      default:
        return 'غير محدد';
    }
  }
}

/// نموذج إدخال استخدام الأداة
class ToolUsageEntry {
  final int id;
  final int batchId;
  final double quantityUsed;
  final DateTime usageDate;
  final String? notes;

  const ToolUsageEntry({
    required this.id,
    required this.batchId,
    required this.quantityUsed,
    required this.usageDate,
    this.notes,
  });

  /// إنشاء من JSON
  factory ToolUsageEntry.fromJson(Map<String, dynamic> json) {
    return ToolUsageEntry(
      id: json['id'] as int,
      batchId: json['batch_id'] as int,
      quantityUsed: (json['quantity_used'] as num).toDouble(),
      usageDate: DateTime.parse(json['usage_date'] as String),
      notes: json['notes'] as String?,
    );
  }

  /// تحويل إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'batch_id': batchId,
      'quantity_used': quantityUsed,
      'usage_date': usageDate.toIso8601String(),
      'notes': notes,
    };
  }

  /// الحصول على التاريخ المنسق
  String get formattedDate {
    return '${usageDate.day}/${usageDate.month}/${usageDate.year}';
  }
}

/// نموذج تحليل فجوة الإنتاج
class ProductionGapAnalysis {
  final int productId;
  final String productName;
  final double currentProduction;
  final double targetQuantity;
  final double remainingPieces;
  final double completionPercentage;
  final bool isOverProduced;
  final bool isCompleted;
  final DateTime? estimatedCompletionDate;

  const ProductionGapAnalysis({
    required this.productId,
    required this.productName,
    required this.currentProduction,
    required this.targetQuantity,
    required this.remainingPieces,
    required this.completionPercentage,
    required this.isOverProduced,
    required this.isCompleted,
    this.estimatedCompletionDate,
  });

  /// إنشاء من JSON
  factory ProductionGapAnalysis.fromJson(Map<String, dynamic> json) {
    return ProductionGapAnalysis(
      productId: json['product_id'] as int,
      productName: json['product_name'] as String,
      currentProduction: (json['current_production'] as num).toDouble(),
      targetQuantity: (json['target_quantity'] as num).toDouble(),
      remainingPieces: (json['remaining_pieces'] as num).toDouble(),
      completionPercentage: (json['completion_percentage'] as num).toDouble(),
      isOverProduced: json['is_over_produced'] as bool,
      isCompleted: json['is_completed'] as bool,
      estimatedCompletionDate: json['estimated_completion_date'] != null
          ? DateTime.parse(json['estimated_completion_date'] as String)
          : null,
    );
  }

  /// تحويل إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'product_name': productName,
      'current_production': currentProduction,
      'target_quantity': targetQuantity,
      'remaining_pieces': remainingPieces,
      'completion_percentage': completionPercentage,
      'is_over_produced': isOverProduced,
      'is_completed': isCompleted,
      'estimated_completion_date': estimatedCompletionDate?.toIso8601String(),
    };
  }

  /// الحصول على لون حالة الإنتاج
  Color get statusColor {
    if (isCompleted) return Colors.green;
    if (isOverProduced) return Colors.blue;
    if (completionPercentage >= 80) return Colors.orange;
    if (completionPercentage >= 50) return Colors.yellow.shade700;
    return Colors.red;
  }

  /// الحصول على نص حالة الإنتاج
  String get statusText {
    if (isCompleted) return 'مكتمل';
    if (isOverProduced) return 'إنتاج زائد';
    if (completionPercentage >= 80) return 'قريب من الإكمال';
    if (completionPercentage >= 50) return 'في المسار الصحيح';
    return 'يحتاج متابعة';
  }

  /// الحصول على النص الوصفي للقطع المتبقية
  String get remainingPiecesText {
    if (isCompleted) return 'تم إكمال الإنتاج';
    if (isOverProduced) return 'إنتاج زائد: ${remainingPieces.abs().toStringAsFixed(0)} قطعة';
    return 'متبقي: ${remainingPieces.toStringAsFixed(0)} قطعة';
  }
}

/// نموذج توقعات الأدوات المطلوبة
class RequiredToolsForecast {
  final int productId;
  final double remainingPieces;
  final List<RequiredToolItem> requiredTools;
  final bool canCompleteProduction;
  final List<String> unavailableTools;
  final double totalCost;

  const RequiredToolsForecast({
    required this.productId,
    required this.remainingPieces,
    required this.requiredTools,
    required this.canCompleteProduction,
    required this.unavailableTools,
    required this.totalCost,
  });

  /// إنشاء من JSON
  factory RequiredToolsForecast.fromJson(Map<String, dynamic> json) {
    final toolsList = json['required_tools'] as List<dynamic>? ?? [];
    final requiredTools = toolsList
        .map((item) => RequiredToolItem.fromJson(item as Map<String, dynamic>))
        .toList();

    final unavailableToolsList = json['unavailable_tools'] as List<dynamic>? ?? [];
    final unavailableTools = unavailableToolsList.cast<String>();

    return RequiredToolsForecast(
      productId: json['product_id'] as int,
      remainingPieces: (json['remaining_pieces'] as num).toDouble(),
      requiredTools: requiredTools,
      canCompleteProduction: json['can_complete_production'] as bool,
      unavailableTools: unavailableTools,
      totalCost: (json['total_cost'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// تحويل إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'remaining_pieces': remainingPieces,
      'required_tools': requiredTools.map((tool) => tool.toJson()).toList(),
      'can_complete_production': canCompleteProduction,
      'unavailable_tools': unavailableTools,
      'total_cost': totalCost,
    };
  }

  /// الحصول على عدد الأدوات المطلوبة
  int get toolsCount => requiredTools.length;

  /// الحصول على عدد الأدوات غير المتوفرة
  int get unavailableToolsCount => unavailableTools.length;

  /// التحقق من وجود أدوات غير متوفرة
  bool get hasUnavailableTools => unavailableTools.isNotEmpty;

  /// الحصول على عدد الأدوات المتوفرة
  int get availableToolsCount => requiredTools.where((tool) => tool.isAvailable).length;

  /// الحصول على عدد الأدوات المتوفرة جزئياً
  int get partiallyAvailableToolsCount => requiredTools.where((tool) => tool.availabilityStatus == 'partial').length;

  /// الحصول على إجمالي النقص في الأدوات
  double get totalShortfall => requiredTools.fold(0.0, (sum, tool) => sum + tool.shortfall);

  /// التحقق من وجود نقص حرج في الأدوات
  bool get hasCriticalShortage => requiredTools.any((tool) => tool.availabilityStatus == 'critical');

  /// الحصول على الأدوات ذات الأولوية العالية (نقص حرج أو غير متوفرة)
  List<RequiredToolItem> get highPriorityTools => requiredTools
      .where((tool) => tool.availabilityStatus == 'critical' || tool.availabilityStatus == 'unavailable')
      .toList();

  /// الحصول على تقدير الوقت المطلوب للحصول على الأدوات (بالأيام)
  int get estimatedProcurementDays {
    if (canCompleteProduction) return 0;

    // تقدير بناءً على حالة الأدوات
    int maxDays = 0;
    for (final tool in requiredTools) {
      if (!tool.isAvailable) {
        switch (tool.availabilityStatus) {
          case 'unavailable':
            maxDays = maxDays > 7 ? maxDays : 7; // أسبوع للأدوات غير المتوفرة
            break;
          case 'critical':
            maxDays = maxDays > 14 ? maxDays : 14; // أسبوعين للأدوات الحرجة
            break;
          case 'partial':
            maxDays = maxDays > 3 ? maxDays : 3; // 3 أيام للأدوات المتوفرة جزئياً
            break;
        }
      }
    }
    return maxDays;
  }

  /// الحصول على تاريخ الإكمال المتوقع
  DateTime get estimatedCompletionDate => DateTime.now().add(Duration(days: estimatedProcurementDays));

  /// الحصول على توصيات الشراء
  List<String> get procurementRecommendations {
    final recommendations = <String>[];

    if (canCompleteProduction) {
      recommendations.add('جميع الأدوات متوفرة - يمكن البدء في الإنتاج فوراً');
      return recommendations;
    }

    if (hasCriticalShortage) {
      recommendations.add('يوجد نقص حرج في بعض الأدوات - يتطلب شراء عاجل');
    }

    if (partiallyAvailableToolsCount > 0) {
      recommendations.add('بعض الأدوات متوفرة جزئياً - يُنصح بشراء الكمية المتبقية');
    }

    if (totalCost > 0) {
      recommendations.add('التكلفة الإجمالية المتوقعة: ${totalCost.toStringAsFixed(2)} ريال');
    }

    if (estimatedProcurementDays > 0) {
      recommendations.add('الوقت المتوقع للحصول على الأدوات: $estimatedProcurementDays أيام');
    }

    return recommendations;
  }

  /// الحصول على ملخص حالة الأدوات
  String get statusSummary {
    if (canCompleteProduction) {
      return 'جميع الأدوات متوفرة (${toolsCount} أداة)';
    }

    return 'يحتاج ${unavailableToolsCount} أداة من أصل ${toolsCount} أداة';
  }
}

/// نموذج عنصر الأداة المطلوبة
class RequiredToolItem {
  final int toolId;
  final String toolName;
  final String unit;
  final double quantityPerUnit;
  final double totalQuantityNeeded;
  final double availableStock;
  final double shortfall;
  final bool isAvailable;
  final String availabilityStatus;
  final double? estimatedCost;

  const RequiredToolItem({
    required this.toolId,
    required this.toolName,
    required this.unit,
    required this.quantityPerUnit,
    required this.totalQuantityNeeded,
    required this.availableStock,
    required this.shortfall,
    required this.isAvailable,
    required this.availabilityStatus,
    this.estimatedCost,
  });

  /// إنشاء من JSON
  factory RequiredToolItem.fromJson(Map<String, dynamic> json) {
    return RequiredToolItem(
      toolId: json['tool_id'] as int,
      toolName: json['tool_name'] as String,
      unit: json['unit'] as String,
      quantityPerUnit: (json['quantity_per_unit'] as num).toDouble(),
      totalQuantityNeeded: (json['total_quantity_needed'] as num).toDouble(),
      availableStock: (json['available_stock'] as num).toDouble(),
      shortfall: (json['shortfall'] as num).toDouble(),
      isAvailable: json['is_available'] as bool,
      availabilityStatus: json['availability_status'] as String,
      estimatedCost: (json['estimated_cost'] as num?)?.toDouble(),
    );
  }

  /// تحويل إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'tool_id': toolId,
      'tool_name': toolName,
      'unit': unit,
      'quantity_per_unit': quantityPerUnit,
      'total_quantity_needed': totalQuantityNeeded,
      'available_stock': availableStock,
      'shortfall': shortfall,
      'is_available': isAvailable,
      'availability_status': availabilityStatus,
      'estimated_cost': estimatedCost,
    };
  }

  /// الحصول على لون حالة التوفر
  Color get availabilityColor {
    switch (availabilityStatus.toLowerCase()) {
      case 'available':
        return Colors.green;
      case 'partial':
        return Colors.orange;
      case 'unavailable':
        return Colors.red;
      case 'critical':
        return Colors.red.shade800;
      default:
        return Colors.grey;
    }
  }

  /// الحصول على نص حالة التوفر بالعربية
  String get availabilityText {
    switch (availabilityStatus.toLowerCase()) {
      case 'available':
        return 'متوفر';
      case 'partial':
        return 'متوفر جزئياً';
      case 'unavailable':
        return 'غير متوفر';
      case 'critical':
        return 'نقص حرج';
      default:
        return 'غير محدد';
    }
  }

  /// الحصول على النص الوصفي للكمية المطلوبة
  String get quantityText {
    return '${totalQuantityNeeded.toStringAsFixed(1)} $unit';
  }

  /// الحصول على النص الوصفي للكمية المتوفرة
  String get availableStockText {
    return '${availableStock.toStringAsFixed(1)} $unit';
  }

  /// الحصول على النص الوصفي للنقص
  String get shortfallText {
    if (shortfall <= 0) return 'لا يوجد نقص';
    return 'نقص: ${shortfall.toStringAsFixed(1)} $unit';
  }

  /// الحصول على نسبة التوفر
  double get availabilityPercentage {
    if (totalQuantityNeeded <= 0) return 100.0;
    return (availableStock / totalQuantityNeeded) * 100;
  }

  /// التحقق من كون الأداة ذات أولوية عالية
  bool get isHighPriority => availabilityStatus == 'critical' || availabilityStatus == 'unavailable';

  /// الحصول على مستوى الخطورة (1-5)
  int get riskLevel {
    switch (availabilityStatus.toLowerCase()) {
      case 'available':
        return 1;
      case 'partial':
        return 3;
      case 'unavailable':
        return 4;
      case 'critical':
        return 5;
      default:
        return 2;
    }
  }

  /// الحصول على توصية الإجراء
  String get actionRecommendation {
    switch (availabilityStatus.toLowerCase()) {
      case 'available':
        return 'متوفر - جاهز للاستخدام';
      case 'partial':
        return 'شراء ${shortfall.toStringAsFixed(1)} $unit إضافية';
      case 'unavailable':
        return 'شراء عاجل - ${totalQuantityNeeded.toStringAsFixed(1)} $unit';
      case 'critical':
        return 'شراء فوري - أولوية قصوى';
      default:
        return 'يتطلب مراجعة';
    }
  }

  /// الحصول على الوقت المتوقع للحصول على الأداة (بالأيام)
  int get estimatedProcurementDays {
    switch (availabilityStatus.toLowerCase()) {
      case 'available':
        return 0;
      case 'partial':
        return 2;
      case 'unavailable':
        return 7;
      case 'critical':
        return 14;
      default:
        return 5;
    }
  }

  /// الحصول على أيقونة حالة التوفر
  IconData get statusIcon {
    switch (availabilityStatus.toLowerCase()) {
      case 'available':
        return Icons.check_circle;
      case 'partial':
        return Icons.warning;
      case 'unavailable':
        return Icons.error;
      case 'critical':
        return Icons.dangerous;
      default:
        return Icons.help;
    }
  }
}
