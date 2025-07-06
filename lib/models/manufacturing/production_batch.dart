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
