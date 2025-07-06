import 'package:smartbiztracker_new/models/client_order_model.dart';

/// نموذج أذون صرف المخزون
/// يمثل طلب صرف منتجات من المخزن بعد موافقة الطلب
/// يعمل كجسر بين الطلبات المعتمدة وإدارة المخزون
class WarehouseReleaseOrderModel {
  final String id;
  final String releaseOrderNumber;
  final String originalOrderId;
  final String clientId;
  final String clientName;
  final String clientEmail;
  final String clientPhone;
  final List<WarehouseReleaseOrderItem> items;
  final double totalAmount;
  final double discount;
  final double finalAmount;
  final WarehouseReleaseOrderStatus status;
  final DateTime createdAt;
  final DateTime? approvedAt;
  final DateTime? completedAt;
  final DateTime? deliveredAt; // Delivery confirmation timestamp
  final String? notes;
  final String? shippingAddress;
  final String? assignedTo; // Accountant who created the release order
  final String? warehouseManagerId; // Warehouse manager who will approve
  final String? warehouseManagerName;
  final String? deliveredBy; // Warehouse manager who confirmed delivery
  final String? deliveredByName; // Name of warehouse manager who confirmed delivery
  final String? deliveryNotes; // Delivery confirmation notes
  final String? rejectionReason;
  final Map<String, dynamic>? metadata;

  const WarehouseReleaseOrderModel({
    required this.id,
    required this.releaseOrderNumber,
    required this.originalOrderId,
    required this.clientId,
    required this.clientName,
    required this.clientEmail,
    required this.clientPhone,
    required this.items,
    required this.totalAmount,
    required this.discount,
    required this.finalAmount,
    required this.status,
    required this.createdAt,
    this.approvedAt,
    this.completedAt,
    this.deliveredAt,
    this.notes,
    this.shippingAddress,
    this.assignedTo,
    this.warehouseManagerId,
    this.warehouseManagerName,
    this.deliveredBy,
    this.deliveredByName,
    this.deliveryNotes,
    this.rejectionReason,
    this.metadata,
  });

  /// إنشاء أذن صرف من طلب عميل معتمد
  factory WarehouseReleaseOrderModel.fromClientOrder(
    ClientOrder clientOrder,
    String assignedTo,
  ) {
    final releaseOrderNumber = 'WRO-${DateTime.now().millisecondsSinceEpoch}';
    
    final releaseItems = clientOrder.items.map((item) => 
      WarehouseReleaseOrderItem.fromOrderItem(item)
    ).toList();

    return WarehouseReleaseOrderModel(
      id: '', // Will be set by database
      releaseOrderNumber: releaseOrderNumber,
      originalOrderId: clientOrder.id,
      clientId: clientOrder.clientId,
      clientName: clientOrder.clientName,
      clientEmail: clientOrder.clientEmail,
      clientPhone: clientOrder.clientPhone,
      items: releaseItems,
      totalAmount: clientOrder.total,
      discount: 0.0, // Can be set later if needed
      finalAmount: clientOrder.total,
      status: WarehouseReleaseOrderStatus.pendingWarehouseApproval,
      createdAt: DateTime.now(),
      notes: clientOrder.notes,
      shippingAddress: clientOrder.shippingAddress,
      assignedTo: assignedTo,
      metadata: {
        'original_order_status': clientOrder.status.toString(),
        'created_from': 'pending_orders_approval',
        'items_count': clientOrder.items.length,
      },
    );
  }

  factory WarehouseReleaseOrderModel.fromJson(Map<String, dynamic> json) {
    return WarehouseReleaseOrderModel(
      id: json['id'] as String? ?? '',
      releaseOrderNumber: json['release_order_number'] as String? ?? '',
      originalOrderId: json['original_order_id'] as String? ?? '',
      clientId: json['client_id'] as String? ?? '',
      clientName: json['client_name'] as String? ?? '',
      clientEmail: json['client_email'] as String? ?? '',
      clientPhone: json['client_phone'] as String? ?? '',
      items: (json['items'] as List<dynamic>?)
          ?.map((item) => WarehouseReleaseOrderItem.fromJson(item as Map<String, dynamic>))
          .toList() ?? [],
      totalAmount: ((json['total_amount'] as num?) ?? 0).toDouble(),
      discount: ((json['discount'] as num?) ?? 0).toDouble(),
      finalAmount: ((json['final_amount'] as num?) ?? 0).toDouble(),
      status: WarehouseReleaseOrderStatus.values.firstWhere(
        (e) => e.toString().split('.').last == ((json['status'] as String?) ?? 'pendingWarehouseApproval'),
        orElse: () => WarehouseReleaseOrderStatus.pendingWarehouseApproval,
      ),
      createdAt: DateTime.parse((json['created_at'] as String?) ?? DateTime.now().toIso8601String()),
      approvedAt: json['approved_at'] != null ? DateTime.parse(json['approved_at'] as String) : null,
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at'] as String) : null,
      deliveredAt: json['delivered_at'] != null ? DateTime.parse(json['delivered_at'] as String) : null,
      notes: json['notes'] as String?,
      shippingAddress: json['shipping_address'] as String?,
      assignedTo: json['assigned_to'] as String?,
      warehouseManagerId: json['warehouse_manager_id'] as String?,
      warehouseManagerName: json['warehouse_manager_name'] as String?,
      deliveredBy: json['delivered_by'] as String?,
      deliveredByName: json['delivered_by_name'] as String?,
      deliveryNotes: json['delivery_notes'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'release_order_number': releaseOrderNumber,
      'original_order_id': originalOrderId,
      'client_id': clientId,
      'client_name': clientName,
      'client_email': clientEmail,
      'client_phone': clientPhone,
      'items': items.map((item) => item.toJson()).toList(),
      'total_amount': totalAmount,
      'discount': discount,
      'final_amount': finalAmount,
      'status': status.toString().split('.').last,
      'created_at': createdAt.toIso8601String(),
      'approved_at': approvedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'delivered_at': deliveredAt?.toIso8601String(),
      'notes': notes,
      'shipping_address': shippingAddress,
      'assigned_to': assignedTo,
      'warehouse_manager_id': warehouseManagerId,
      'warehouse_manager_name': warehouseManagerName,
      'delivered_by': deliveredBy,
      'delivered_by_name': deliveredByName,
      'delivery_notes': deliveryNotes,
      'rejection_reason': rejectionReason,
      'metadata': metadata,
    };
  }

  /// نسخ النموذج مع تحديث بعض الحقول
  WarehouseReleaseOrderModel copyWith({
    String? id,
    String? releaseOrderNumber,
    String? originalOrderId,
    String? clientId,
    String? clientName,
    String? clientEmail,
    String? clientPhone,
    List<WarehouseReleaseOrderItem>? items,
    double? totalAmount,
    double? discount,
    double? finalAmount,
    WarehouseReleaseOrderStatus? status,
    DateTime? createdAt,
    DateTime? approvedAt,
    DateTime? completedAt,
    DateTime? deliveredAt,
    String? notes,
    String? shippingAddress,
    String? assignedTo,
    String? warehouseManagerId,
    String? warehouseManagerName,
    String? deliveredBy,
    String? deliveredByName,
    String? deliveryNotes,
    String? rejectionReason,
    Map<String, dynamic>? metadata,
  }) {
    return WarehouseReleaseOrderModel(
      id: id ?? this.id,
      releaseOrderNumber: releaseOrderNumber ?? this.releaseOrderNumber,
      originalOrderId: originalOrderId ?? this.originalOrderId,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      clientEmail: clientEmail ?? this.clientEmail,
      clientPhone: clientPhone ?? this.clientPhone,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      discount: discount ?? this.discount,
      finalAmount: finalAmount ?? this.finalAmount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      approvedAt: approvedAt ?? this.approvedAt,
      completedAt: completedAt ?? this.completedAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      notes: notes ?? this.notes,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      assignedTo: assignedTo ?? this.assignedTo,
      warehouseManagerId: warehouseManagerId ?? this.warehouseManagerId,
      warehouseManagerName: warehouseManagerName ?? this.warehouseManagerName,
      deliveredBy: deliveredBy ?? this.deliveredBy,
      deliveredByName: deliveredByName ?? this.deliveredByName,
      deliveryNotes: deliveryNotes ?? this.deliveryNotes,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      metadata: metadata ?? this.metadata,
    );
  }

  /// نص الحالة بالعربية
  String get statusText {
    switch (status) {
      case WarehouseReleaseOrderStatus.pendingWarehouseApproval:
        return 'في انتظار موافقة مدير المخزن';
      case WarehouseReleaseOrderStatus.approvedByWarehouse:
        return 'تم الموافقة من مدير المخزن';
      case WarehouseReleaseOrderStatus.readyForDelivery:
        return 'جاهز للتسليم';
      case WarehouseReleaseOrderStatus.completed:
        return 'مكتمل';
      case WarehouseReleaseOrderStatus.rejected:
        return 'مرفوض';
      case WarehouseReleaseOrderStatus.cancelled:
        return 'ملغي';
    }
  }

  /// لون الحالة
  String get statusColor {
    switch (status) {
      case WarehouseReleaseOrderStatus.pendingWarehouseApproval:
        return '#F59E0B'; // Orange
      case WarehouseReleaseOrderStatus.approvedByWarehouse:
        return '#10B981'; // Green
      case WarehouseReleaseOrderStatus.readyForDelivery:
        return '#3B82F6'; // Blue
      case WarehouseReleaseOrderStatus.completed:
        return '#059669'; // Dark Green
      case WarehouseReleaseOrderStatus.rejected:
        return '#EF4444'; // Red
      case WarehouseReleaseOrderStatus.cancelled:
        return '#6B7280'; // Gray
    }
  }

  /// التحقق من إمكانية الموافقة
  bool get canApprove => status == WarehouseReleaseOrderStatus.pendingWarehouseApproval;

  /// التحقق من إمكانية الرفض
  bool get canReject => status == WarehouseReleaseOrderStatus.pendingWarehouseApproval;

  /// التحقق من إمكانية الإلغاء
  bool get canCancel => status == WarehouseReleaseOrderStatus.pendingWarehouseApproval;

  /// إجمالي عدد القطع
  int get totalQuantity {
    return items.fold(0, (sum, item) => sum + item.quantity);
  }

  /// إجمالي عدد الأصناف
  int get totalItems => items.length;

  @override
  String toString() => 'WarehouseReleaseOrderModel(id: $id, releaseOrderNumber: $releaseOrderNumber, status: $status)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WarehouseReleaseOrderModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// حالات أذون صرف المخزون
enum WarehouseReleaseOrderStatus {
  pendingWarehouseApproval, // في انتظار موافقة مدير المخزن
  approvedByWarehouse,      // تم الموافقة من مدير المخزن
  readyForDelivery,         // جاهز للتسليم (تم المعالجة)
  completed,                // مكتمل (تم التسليم للعميل)
  rejected,                 // مرفوض
  cancelled,                // ملغي
}

/// عنصر في أذن صرف المخزون
class WarehouseReleaseOrderItem {
  final String id;
  final String productId;
  final String productName;
  final String? productImage;
  final String? productCategory;
  final int quantity;
  final double unitPrice;
  final double subtotal;
  final String? notes;
  final Map<String, dynamic>? metadata;

  // Processing-related fields
  final DateTime? processedAt;
  final String? processedBy;
  final String? processingNotes;
  final Map<String, dynamic>? deductionResult;

  const WarehouseReleaseOrderItem({
    required this.id,
    required this.productId,
    required this.productName,
    this.productImage,
    this.productCategory,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    this.notes,
    this.metadata,
    this.processedAt,
    this.processedBy,
    this.processingNotes,
    this.deductionResult,
  });

  /// إنشاء عنصر أذن صرف من عنصر طلب
  factory WarehouseReleaseOrderItem.fromOrderItem(OrderItem orderItem) {
    return WarehouseReleaseOrderItem(
      id: '', // Will be set by database
      productId: orderItem.productId,
      productName: orderItem.productName,
      productImage: orderItem.productImage,
      productCategory: null, // OrderItem doesn't have category field
      quantity: orderItem.quantity,
      unitPrice: orderItem.price, // OrderItem uses 'price' instead of 'unitPrice'
      subtotal: orderItem.total, // OrderItem uses 'total' instead of 'subtotal'
      notes: null, // OrderItem doesn't have notes field
      metadata: null, // OrderItem doesn't have metadata field
    );
  }

  factory WarehouseReleaseOrderItem.fromJson(Map<String, dynamic> json) {
    return WarehouseReleaseOrderItem(
      id: json['id'] as String? ?? '',
      productId: json['product_id'] as String? ?? '',
      productName: json['product_name'] as String? ?? '',
      productImage: json['product_image'] as String?,
      productCategory: json['product_category'] as String?,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      unitPrice: ((json['unit_price'] as num?) ?? 0).toDouble(),
      subtotal: ((json['subtotal'] as num?) ?? 0).toDouble(),
      notes: json['notes'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      processedAt: json['processed_at'] != null
          ? DateTime.tryParse(json['processed_at'] as String)
          : null,
      processedBy: json['processed_by'] as String?,
      processingNotes: json['processing_notes'] as String?,
      deductionResult: json['deduction_result'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'product_name': productName,
      'product_image': productImage,
      'product_category': productCategory,
      'quantity': quantity,
      'unit_price': unitPrice,
      'subtotal': subtotal,
      'notes': notes,
      'metadata': metadata,
      'processed_at': processedAt?.toIso8601String(),
      'processed_by': processedBy,
      'processing_notes': processingNotes,
      'deduction_result': deductionResult,
    };
  }

  WarehouseReleaseOrderItem copyWith({
    String? id,
    String? productId,
    String? productName,
    String? productImage,
    String? productCategory,
    int? quantity,
    double? unitPrice,
    double? subtotal,
    String? notes,
    Map<String, dynamic>? metadata,
  }) {
    return WarehouseReleaseOrderItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productImage: productImage ?? this.productImage,
      productCategory: productCategory ?? this.productCategory,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      subtotal: subtotal ?? this.subtotal,
      notes: notes ?? this.notes,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() => 'WarehouseReleaseOrderItem(id: $id, productName: $productName, quantity: $quantity)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WarehouseReleaseOrderItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
