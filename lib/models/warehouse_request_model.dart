import 'package:smartbiztracker_new/models/product_model.dart';
import 'package:smartbiztracker_new/models/user_model.dart';

/// حالة طلب السحب من المخزن
enum WarehouseRequestStatus {
  pending,
  approved,
  rejected,
  executed,
  cancelled;

  String get displayName {
    switch (this) {
      case WarehouseRequestStatus.pending:
        return 'قيد الانتظار';
      case WarehouseRequestStatus.approved:
        return 'موافق عليه';
      case WarehouseRequestStatus.rejected:
        return 'مرفوض';
      case WarehouseRequestStatus.executed:
        return 'تم التنفيذ';
      case WarehouseRequestStatus.cancelled:
        return 'ملغي';
    }
  }

  String get value {
    return toString().split('.').last;
  }

  static WarehouseRequestStatus fromString(String value) {
    return WarehouseRequestStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => WarehouseRequestStatus.pending,
    );
  }
}

/// نوع طلب السحب
enum WarehouseRequestType {
  withdrawal,
  transfer,
  adjustment,
  return_;

  String get displayName {
    switch (this) {
      case WarehouseRequestType.withdrawal:
        return 'سحب';
      case WarehouseRequestType.transfer:
        return 'نقل';
      case WarehouseRequestType.adjustment:
        return 'تعديل';
      case WarehouseRequestType.return_:
        return 'إرجاع';
    }
  }

  String get value {
    return toString().split('.').last;
  }

  static WarehouseRequestType fromString(String value) {
    return WarehouseRequestType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => WarehouseRequestType.withdrawal,
    );
  }
}

/// نموذج طلب السحب من المخزن
class WarehouseRequestModel {
  final String id;
  final String requestNumber;
  final WarehouseRequestType type;
  final WarehouseRequestStatus status;
  final String requestedBy;
  final String? approvedBy;
  final String? executedBy;
  final String warehouseId;
  final String? targetWarehouseId; // للنقل بين المخازن
  final String reason;
  final String? notes;
  final DateTime requestedAt;
  final DateTime? approvedAt;
  final DateTime? executedAt;
  final List<WarehouseRequestItemModel> items;
  final Map<String, dynamic>? metadata;

  // معلومات إضافية للعرض
  final UserModel? requester;
  final UserModel? approver;
  final UserModel? executor;
  final String? warehouseName;
  final String? targetWarehouseName;

  const WarehouseRequestModel({
    required this.id,
    required this.requestNumber,
    required this.type,
    required this.status,
    required this.requestedBy,
    this.approvedBy,
    this.executedBy,
    required this.warehouseId,
    this.targetWarehouseId,
    required this.reason,
    this.notes,
    required this.requestedAt,
    this.approvedAt,
    this.executedAt,
    required this.items,
    this.metadata,
    this.requester,
    this.approver,
    this.executor,
    this.warehouseName,
    this.targetWarehouseName,
  });

  factory WarehouseRequestModel.fromJson(Map<String, dynamic> json) {
    return WarehouseRequestModel(
      id: json['id'] as String,
      requestNumber: json['request_number'] as String,
      type: WarehouseRequestType.fromString(json['type'] as String),
      status: WarehouseRequestStatus.fromString(json['status'] as String),
      requestedBy: json['requested_by'] as String,
      approvedBy: json['approved_by'] as String?,
      executedBy: json['executed_by'] as String?,
      warehouseId: json['warehouse_id'] as String,
      targetWarehouseId: json['target_warehouse_id'] as String?,
      reason: json['reason'] as String,
      notes: json['notes'] as String?,
      requestedAt: DateTime.parse(json['requested_at'] as String),
      approvedAt: json['approved_at'] != null 
          ? DateTime.parse(json['approved_at'] as String) 
          : null,
      executedAt: json['executed_at'] != null 
          ? DateTime.parse(json['executed_at'] as String) 
          : null,
      items: (json['items'] as List<dynamic>?)
          ?.map((item) => WarehouseRequestItemModel.fromJson(item as Map<String, dynamic>))
          .toList() ?? [],
      metadata: json['metadata'] as Map<String, dynamic>?,
      requester: json['requester'] != null 
          ? UserModel.fromJson(json['requester'] as Map<String, dynamic>)
          : null,
      approver: json['approver'] != null 
          ? UserModel.fromJson(json['approver'] as Map<String, dynamic>)
          : null,
      executor: json['executor'] != null 
          ? UserModel.fromJson(json['executor'] as Map<String, dynamic>)
          : null,
      warehouseName: json['warehouse_name'] as String?,
      targetWarehouseName: json['target_warehouse_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'request_number': requestNumber,
      'type': type.value,
      'status': status.value,
      'requested_by': requestedBy,
      'approved_by': approvedBy,
      'executed_by': executedBy,
      'warehouse_id': warehouseId,
      'target_warehouse_id': targetWarehouseId,
      'reason': reason,
      'notes': notes,
      'requested_at': requestedAt.toIso8601String(),
      'approved_at': approvedAt?.toIso8601String(),
      'executed_at': executedAt?.toIso8601String(),
      'items': items.map((item) => item.toJson()).toList(),
      'metadata': metadata,
    };
  }

  /// إجمالي عدد القطع المطلوبة
  int get totalQuantity {
    return items.fold(0, (sum, item) => sum + item.quantity);
  }

  /// التحقق من إمكانية الموافقة على الطلب
  bool get canBeApproved {
    return status == WarehouseRequestStatus.pending;
  }

  /// التحقق من إمكانية تنفيذ الطلب
  bool get canBeExecuted {
    return status == WarehouseRequestStatus.approved;
  }

  /// التحقق من إمكانية إلغاء الطلب
  bool get canBeCancelled {
    return status == WarehouseRequestStatus.pending || 
           status == WarehouseRequestStatus.approved;
  }

  WarehouseRequestModel copyWith({
    String? id,
    String? requestNumber,
    WarehouseRequestType? type,
    WarehouseRequestStatus? status,
    String? requestedBy,
    String? approvedBy,
    String? executedBy,
    String? warehouseId,
    String? targetWarehouseId,
    String? reason,
    String? notes,
    DateTime? requestedAt,
    DateTime? approvedAt,
    DateTime? executedAt,
    List<WarehouseRequestItemModel>? items,
    Map<String, dynamic>? metadata,
    UserModel? requester,
    UserModel? approver,
    UserModel? executor,
    String? warehouseName,
    String? targetWarehouseName,
  }) {
    return WarehouseRequestModel(
      id: id ?? this.id,
      requestNumber: requestNumber ?? this.requestNumber,
      type: type ?? this.type,
      status: status ?? this.status,
      requestedBy: requestedBy ?? this.requestedBy,
      approvedBy: approvedBy ?? this.approvedBy,
      executedBy: executedBy ?? this.executedBy,
      warehouseId: warehouseId ?? this.warehouseId,
      targetWarehouseId: targetWarehouseId ?? this.targetWarehouseId,
      reason: reason ?? this.reason,
      notes: notes ?? this.notes,
      requestedAt: requestedAt ?? this.requestedAt,
      approvedAt: approvedAt ?? this.approvedAt,
      executedAt: executedAt ?? this.executedAt,
      items: items ?? this.items,
      metadata: metadata ?? this.metadata,
      requester: requester ?? this.requester,
      approver: approver ?? this.approver,
      executor: executor ?? this.executor,
      warehouseName: warehouseName ?? this.warehouseName,
      targetWarehouseName: targetWarehouseName ?? this.targetWarehouseName,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WarehouseRequestModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'WarehouseRequestModel(id: $id, requestNumber: $requestNumber, status: $status)';
  }
}

/// نموذج عنصر طلب السحب
class WarehouseRequestItemModel {
  final String id;
  final String requestId;
  final String productId;
  final int quantity;
  final String? notes;
  final Map<String, dynamic>? metadata;

  // معلومات المنتج للعرض
  final ProductModel? product;

  const WarehouseRequestItemModel({
    required this.id,
    required this.requestId,
    required this.productId,
    required this.quantity,
    this.notes,
    this.metadata,
    this.product,
  });

  factory WarehouseRequestItemModel.fromJson(Map<String, dynamic> json) {
    return WarehouseRequestItemModel(
      id: json['id'] as String,
      requestId: json['request_id'] as String,
      productId: json['product_id'] as String,
      quantity: json['quantity'] as int,
      notes: json['notes'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      product: json['product'] != null 
          ? ProductModel.fromJson(json['product'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'request_id': requestId,
      'product_id': productId,
      'quantity': quantity,
      'notes': notes,
      'metadata': metadata,
    };
  }

  WarehouseRequestItemModel copyWith({
    String? id,
    String? requestId,
    String? productId,
    int? quantity,
    String? notes,
    Map<String, dynamic>? metadata,
    ProductModel? product,
  }) {
    return WarehouseRequestItemModel(
      id: id ?? this.id,
      requestId: requestId ?? this.requestId,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      notes: notes ?? this.notes,
      metadata: metadata ?? this.metadata,
      product: product ?? this.product,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WarehouseRequestItemModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'WarehouseRequestItemModel(id: $id, productId: $productId, quantity: $quantity)';
  }
}
