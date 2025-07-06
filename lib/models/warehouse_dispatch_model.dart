/// نموذج طلب صرف المخزون
/// يمثل طلب صرف منتجات من المخزن سواء من فاتورة أو طلب يدوي
class WarehouseDispatchModel {
  final String id;
  final String requestNumber;
  final String type; // 'withdrawal', 'transfer', 'adjustment', 'return'
  final String status; // 'pending', 'approved', 'rejected', 'executed', 'cancelled'
  final String reason; // سبب الطلب (يحل محل invoiceId و customerName)
  final String requestedBy;
  final String? approvedBy;
  final String? executedBy;
  final DateTime requestedAt;
  final DateTime? approvedAt;
  final DateTime? executedAt;
  final String? notes;
  final String? warehouseId;
  final String? targetWarehouseId;
  final List<WarehouseDispatchItemModel> items;

  const WarehouseDispatchModel({
    required this.id,
    required this.requestNumber,
    required this.type,
    required this.status,
    required this.reason,
    required this.requestedBy,
    this.approvedBy,
    this.executedBy,
    required this.requestedAt,
    this.approvedAt,
    this.executedAt,
    this.notes,
    this.warehouseId,
    this.targetWarehouseId,
    required this.items,
  });

  /// إنشاء من JSON
  factory WarehouseDispatchModel.fromJson(Map<String, dynamic> json) {
    return WarehouseDispatchModel(
      id: json['id']?.toString() ?? '',
      requestNumber: json['request_number']?.toString() ?? '',
      type: json['type']?.toString() ?? 'withdrawal',
      status: json['status']?.toString() ?? 'pending',
      reason: json['reason']?.toString() ?? '',
      requestedBy: json['requested_by']?.toString() ?? '',
      approvedBy: json['approved_by']?.toString(),
      executedBy: json['executed_by']?.toString(),
      requestedAt: _parseDateTime(json['requested_at']) ?? DateTime.now(),
      approvedAt: _parseDateTime(json['approved_at']),
      executedAt: _parseDateTime(json['executed_at']),
      notes: json['notes']?.toString(),
      warehouseId: json['warehouse_id']?.toString(),
      targetWarehouseId: json['target_warehouse_id']?.toString(),
      items: _parseItems(json['warehouse_request_items']),
    );
  }

  /// تحويل إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'request_number': requestNumber,
      'type': type,
      'status': status,
      'reason': reason,
      'requested_by': requestedBy,
      'approved_by': approvedBy,
      'executed_by': executedBy,
      'requested_at': requestedAt.toIso8601String(),
      'approved_at': approvedAt?.toIso8601String(),
      'executed_at': executedAt?.toIso8601String(),
      'notes': notes,
      'warehouse_id': warehouseId,
      'target_warehouse_id': targetWarehouseId,
    };
  }

  /// نسخ مع تعديل
  WarehouseDispatchModel copyWith({
    String? id,
    String? requestNumber,
    String? type,
    String? status,
    String? reason,
    String? requestedBy,
    String? approvedBy,
    String? executedBy,
    DateTime? requestedAt,
    DateTime? approvedAt,
    DateTime? executedAt,
    DateTime? updatedAt, // للتوافق مع الكود الموجود
    String? notes,
    String? warehouseId,
    String? targetWarehouseId,
    List<WarehouseDispatchItemModel>? items,
  }) {
    return WarehouseDispatchModel(
      id: id ?? this.id,
      requestNumber: requestNumber ?? this.requestNumber,
      type: type ?? this.type,
      status: status ?? this.status,
      reason: reason ?? this.reason,
      requestedBy: requestedBy ?? this.requestedBy,
      approvedBy: approvedBy ?? this.approvedBy,
      executedBy: executedBy ?? this.executedBy,
      requestedAt: requestedAt ?? this.requestedAt,
      approvedAt: approvedAt ?? this.approvedAt,
      executedAt: executedAt ?? updatedAt ?? this.executedAt, // استخدام updatedAt كـ executedAt إذا تم توفيره
      notes: notes ?? this.notes,
      warehouseId: warehouseId ?? this.warehouseId,
      targetWarehouseId: targetWarehouseId ?? this.targetWarehouseId,
      items: items ?? this.items,
    );
  }

  /// الحصول على نص الحالة
  String get statusText {
    switch (status) {
      case 'pending':
        return 'في الانتظار';
      case 'approved':
        return 'موافق عليه';
      case 'rejected':
        return 'مرفوض';
      case 'executed':
        return 'منفذ';
      case 'cancelled':
        return 'ملغي';
      default:
        return status;
    }
  }

  /// الحصول على نص النوع
  String get typeText {
    switch (type) {
      case 'withdrawal':
        return 'سحب من المخزن';
      case 'transfer':
        return 'نقل بين المخازن';
      case 'adjustment':
        return 'تعديل مخزون';
      case 'return':
        return 'إرجاع للمخزن';
      default:
        return type;
    }
  }

  /// التحقق من إمكانية التعديل
  bool get canEdit => status == 'pending';

  /// التحقق من إمكانية الموافقة
  bool get canApprove => status == 'pending';

  /// التحقق من إمكانية التنفيذ
  bool get canExecute => status == 'approved';

  /// التحقق من إمكانية الإلغاء
  bool get canCancel => status == 'pending' || status == 'approved';

  /// الحصول على إجمالي الكمية
  int get totalQuantity {
    return items.fold(0, (sum, item) => sum + item.quantity);
  }

  /// الحصول على عدد المنتجات
  int get itemsCount => items.length;

  /// الحصول على اسم العميل (للتوافق مع الكود الموجود)
  String get customerName => reason;

  /// الحصول على المبلغ الإجمالي (للتوافق مع الكود الموجود)
  double get totalAmount => items.fold(0.0, (sum, item) => sum + item.totalPrice);

  /// الحصول على معرف الفاتورة (للتوافق مع الكود الموجود)
  String get invoiceId => reason.contains('فاتورة') ? reason.split(' ').last : '';

  /// الحصول على تاريخ الإنشاء (للتوافق مع الكود الموجود)
  DateTime get createdAt => requestedAt;

  /// الحصول على تاريخ التحديث (للتوافق مع الكود الموجود)
  DateTime get updatedAt => executedAt ?? approvedAt ?? requestedAt;

  /// التحقق من إمكانية المعالجة (للتوافق مع الكود الموجود)
  bool get canProcess => status == 'pending' || status == 'approved';

  /// دوال مساعدة لتحليل البيانات
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static List<WarehouseDispatchItemModel> _parseItems(dynamic value) {
    if (value == null) {
      // استخدام print بدلاً من AppLogger لتجنب المشاكل الدائرية
      print('⚠️ WarehouseDispatchModel: warehouse_request_items is null');
      return [];
    }

    if (value is! List) {
      print('⚠️ WarehouseDispatchModel: warehouse_request_items is not a List, type: ${value.runtimeType}');
      return [];
    }

    final itemsList = value as List;
    print('📦 WarehouseDispatchModel: parsing ${itemsList.length} items');

    final parsedItems = <WarehouseDispatchItemModel>[];

    for (int i = 0; i < itemsList.length; i++) {
      try {
        final itemData = itemsList[i];
        if (itemData is! Map<String, dynamic>) {
          print('⚠️ WarehouseDispatchModel: item $i is not a Map, type: ${itemData.runtimeType}');
          continue;
        }

        final item = WarehouseDispatchItemModel.fromJson(itemData);
        parsedItems.add(item);
        print('✅ WarehouseDispatchModel: parsed item $i - ID: ${item.id}, ProductID: ${item.productId}, Quantity: ${item.quantity}');
      } catch (e) {
        print('❌ WarehouseDispatchModel: error parsing item $i: $e');
        print('📄 WarehouseDispatchModel: problematic item data: ${itemsList[i]}');
      }
    }

    print('📊 WarehouseDispatchModel: successfully parsed ${parsedItems.length}/${itemsList.length} items');
    return parsedItems;
  }

  @override
  String toString() {
    return 'WarehouseDispatchModel(id: $id, requestNumber: $requestNumber, status: $status, reason: $reason)';
  }

  /// التحقق من كون هذا طلب توزيع ذكي متعدد المخازن
  bool get isMultiWarehouseDistribution {
    return reason.contains('توزيع ذكي') ||
           (notes?.contains('توزيع ذكي متعدد المخازن') ?? false);
  }

  /// الحصول على معرف الفاتورة الأصلية (للطلبات المحولة من فواتير)
  String? get originalInvoiceId {
    // البحث في السبب عن معرف الفاتورة
    final reasonMatch = RegExp(r'فاتورة رقم: ([\w-]+)').firstMatch(reason);
    if (reasonMatch != null) {
      return reasonMatch.group(1);
    }

    // البحث في الملاحظات
    if (notes != null) {
      final notesMatch = RegExp(r'الفاتورة ([\w-]+)').firstMatch(notes!);
      if (notesMatch != null) {
        return notesMatch.group(1);
      }
    }

    return null;
  }

  /// الحصول على اسم العميل من السبب
  String? get customerNameFromReason {
    final match = RegExp(r'صرف فاتورة: ([^-]+)').firstMatch(reason);
    return match?.group(1)?.trim();
  }

  /// الحصول على نوع المصدر
  String get sourceType {
    if (isMultiWarehouseDistribution) return 'multi_warehouse_distribution';
    if (originalInvoiceId != null) return 'invoice_conversion';
    return 'manual';
  }

  /// الحصول على نص وصفي للمصدر
  String get sourceDescription {
    switch (sourceType) {
      case 'multi_warehouse_distribution':
        return 'توزيع ذكي متعدد المخازن';
      case 'invoice_conversion':
        return 'تحويل من فاتورة';
      case 'manual':
      default:
        return 'إنشاء يدوي';
    }
  }

  /// إنشاء نسخة مع بيانات التوزيع الذكي
  WarehouseDispatchModel withMultiWarehouseMetadata({
    required String originalInvoiceId,
    required String customerName,
    required String warehouseName,
    String? distributionStrategy,
  }) {
    final enhancedReason = 'صرف فاتورة: $customerName - توزيع ذكي من $warehouseName';
    final enhancedNotes = '${notes ?? ''}\nتوزيع ذكي متعدد المخازن - جزء من الفاتورة $originalInvoiceId'
        '${distributionStrategy != null ? '\nاستراتيجية التوزيع: $distributionStrategy' : ''}';

    return copyWith(
      reason: enhancedReason,
      notes: enhancedNotes.trim(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WarehouseDispatchModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// نموذج عنصر طلب الصرف
class WarehouseDispatchItemModel {
  final String id;
  final String requestId;
  final String productId;
  final int quantity;
  final String? notes;

  const WarehouseDispatchItemModel({
    required this.id,
    required this.requestId,
    required this.productId,
    required this.quantity,
    this.notes,
  });

  /// إنشاء من JSON
  factory WarehouseDispatchItemModel.fromJson(Map<String, dynamic> json) {
    return WarehouseDispatchItemModel(
      id: json['id']?.toString() ?? '',
      requestId: json['request_id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      quantity: _parseInt(json['quantity']) ?? 0,
      notes: json['notes']?.toString(),
    );
  }

  /// تحويل إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'request_id': requestId,
      'product_id': productId,
      'quantity': quantity,
      'notes': notes,
    };
  }

  /// نسخ مع تعديل
  WarehouseDispatchItemModel copyWith({
    String? id,
    String? requestId,
    String? productId,
    int? quantity,
    String? notes,
  }) {
    return WarehouseDispatchItemModel(
      id: id ?? this.id,
      requestId: requestId ?? this.requestId,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      notes: notes ?? this.notes,
    );
  }

  /// خصائص للتوافق مع الكود الموجود
  String get productName => notes?.split(' - ').first ?? 'منتج غير معروف';
  double get unitPrice => 0.0; // سيتم حسابه من API المنتجات
  double get totalPrice => unitPrice * quantity;

  /// دوال مساعدة لتحليل البيانات
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  @override
  String toString() {
    return 'WarehouseDispatchItemModel(id: $id, productId: $productId, quantity: $quantity)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WarehouseDispatchItemModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
