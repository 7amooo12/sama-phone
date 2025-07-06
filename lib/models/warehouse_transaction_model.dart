import 'package:smartbiztracker_new/models/product_model.dart';
import 'package:smartbiztracker_new/models/user_model.dart';

/// نوع معاملة المخزن
enum WarehouseTransactionType {
  stockIn,
  stockOut,
  transfer,
  adjustment,
  return_;

  String get displayName {
    switch (this) {
      case WarehouseTransactionType.stockIn:
        return 'إدخال مخزون';
      case WarehouseTransactionType.stockOut:
        return 'إخراج مخزون';
      case WarehouseTransactionType.transfer:
        return 'نقل';
      case WarehouseTransactionType.adjustment:
        return 'تعديل';
      case WarehouseTransactionType.return_:
        return 'إرجاع';
    }
  }

  String get value {
    return toString().split('.').last;
  }

  static WarehouseTransactionType fromString(String value) {
    return WarehouseTransactionType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => WarehouseTransactionType.stockIn,
    );
  }
}

/// نموذج معاملة المخزن
class WarehouseTransactionModel {
  final String id;
  final String transactionNumber;
  final WarehouseTransactionType type;
  final String warehouseId;
  final String? targetWarehouseId; // للنقل بين المخازن
  final String productId;
  final int quantity;
  final int quantityBefore;
  final int quantityAfter;
  final String reason;
  final String? notes;
  final String? referenceId; // مرجع الطلب أو الفاتورة
  final String? referenceType; // نوع المرجع (request, order, manual)
  final String performedBy;
  final DateTime performedAt;
  final Map<String, dynamic>? metadata;

  // معلومات إضافية للعرض
  final ProductModel? product;
  final UserModel? performer;
  final String? warehouseName;
  final String? targetWarehouseName;

  const WarehouseTransactionModel({
    required this.id,
    required this.transactionNumber,
    required this.type,
    required this.warehouseId,
    this.targetWarehouseId,
    required this.productId,
    required this.quantity,
    required this.quantityBefore,
    required this.quantityAfter,
    required this.reason,
    this.notes,
    this.referenceId,
    this.referenceType,
    required this.performedBy,
    required this.performedAt,
    this.metadata,
    this.product,
    this.performer,
    this.warehouseName,
    this.targetWarehouseName,
  });

  factory WarehouseTransactionModel.fromJson(Map<String, dynamic> json) {
    try {
      // Handle different schema variations
      final transactionNumber = json['transaction_number'] as String? ??
                               json['transaction_id'] as String? ??
                               json['id'] as String;

      // Handle quantity field variations
      final quantity = json['quantity'] as int? ??
                      (json['quantity_change'] as int?)?.abs() ??
                      0;

      // Handle type field variations
      final typeString = json['type'] as String? ??
                        json['transaction_type'] as String? ??
                        'withdrawal';

      // Map database type values to model enum values
      String normalizedType = typeString;
      switch (typeString.toLowerCase()) {
        case 'withdrawal':
        case 'stock_out':
        case 'out':
          normalizedType = 'stockOut';
          break;
        case 'addition':
        case 'stock_in':
        case 'in':
          normalizedType = 'stockIn';
          break;
        case 'adjustment':
          normalizedType = 'adjustment';
          break;
        case 'transfer':
          normalizedType = 'transfer';
          break;
        default:
          normalizedType = 'stockOut'; // Default for withdrawals
      }

      return WarehouseTransactionModel(
        id: json['id'] as String,
        transactionNumber: transactionNumber,
        type: WarehouseTransactionType.fromString(normalizedType),
        warehouseId: json['warehouse_id'] as String,
        targetWarehouseId: json['target_warehouse_id'] as String?,
        productId: json['product_id'] as String,
        quantity: quantity,
        quantityBefore: json['quantity_before'] as int? ?? 0,
        quantityAfter: json['quantity_after'] as int? ?? 0,
        reason: json['reason'] as String? ?? 'معاملة مخزن',
        notes: json['notes'] as String?,
        referenceId: json['reference_id'] as String?,
        referenceType: json['reference_type'] as String?,
        performedBy: json['performed_by'] as String? ?? json['created_by'] as String? ?? '',
        performedAt: _parseTimestamp(json['performed_at'] as String? ??
                                    json['created_at'] as String? ??
                                    DateTime.now().toIso8601String()),
        metadata: json['metadata'] as Map<String, dynamic>?,
        product: json['products'] != null
            ? ProductModel.fromJson(json['products'] as Map<String, dynamic>)
            : json['product'] != null
                ? ProductModel.fromJson(json['product'] as Map<String, dynamic>)
                : null,
        performer: json['performer'] != null
            ? UserModel.fromJson(json['performer'] as Map<String, dynamic>)
            : null,
        warehouseName: json['warehouses'] != null
            ? (json['warehouses'] as Map<String, dynamic>)['name'] as String?
            : json['warehouse_name'] as String?,
        targetWarehouseName: json['target_warehouse_name'] as String?,
      );
    } catch (e) {
      throw Exception('Failed to parse WarehouseTransactionModel from JSON: $e. Data: $json');
    }
  }

  /// FIXED: Enhanced timestamp parsing with timezone handling
  static DateTime _parseTimestamp(String timestampString) {
    try {
      // Parse the timestamp string
      DateTime parsedDate = DateTime.parse(timestampString);

      // If the parsed date is in UTC, convert to local time
      if (parsedDate.isUtc) {
        parsedDate = parsedDate.toLocal();
      }

      return parsedDate;
    } catch (e) {
      // If parsing fails, return current time as fallback
      return DateTime.now();
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'transaction_number': transactionNumber,
      'type': type.value,
      'warehouse_id': warehouseId,
      'target_warehouse_id': targetWarehouseId,
      'product_id': productId,
      'quantity': quantity,
      'quantity_before': quantityBefore,
      'quantity_after': quantityAfter,
      'reason': reason,
      'notes': notes,
      'reference_id': referenceId,
      'reference_type': referenceType,
      'performed_by': performedBy,
      'performed_at': performedAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  /// التحقق من كون المعاملة إدخال مخزون
  bool get isStockIn {
    return type == WarehouseTransactionType.stockIn ||
           (type == WarehouseTransactionType.transfer && targetWarehouseId == warehouseId);
  }

  /// التحقق من كون المعاملة إخراج مخزون
  bool get isStockOut {
    return type == WarehouseTransactionType.stockOut ||
           (type == WarehouseTransactionType.transfer && targetWarehouseId != warehouseId);
  }

  /// التحقق من كون المعاملة تعديل
  bool get isAdjustment {
    return type == WarehouseTransactionType.adjustment;
  }

  /// الحصول على التغيير في الكمية (موجب للإدخال، سالب للإخراج)
  int get quantityChange {
    return quantityAfter - quantityBefore;
  }

  /// الحصول على وصف المعاملة
  String get description {
    switch (type) {
      case WarehouseTransactionType.stockIn:
        return 'إدخال $quantity قطعة';
      case WarehouseTransactionType.stockOut:
        return 'إخراج $quantity قطعة';
      case WarehouseTransactionType.transfer:
        if (targetWarehouseId == warehouseId) {
          return 'استلام $quantity قطعة من مخزن آخر';
        } else {
          return 'نقل $quantity قطعة إلى مخزن آخر';
        }
      case WarehouseTransactionType.adjustment:
        final change = quantityChange;
        if (change > 0) {
          return 'تعديل: زيادة $change قطعة';
        } else if (change < 0) {
          return 'تعديل: نقص ${change.abs()} قطعة';
        } else {
          return 'تعديل: لا يوجد تغيير في الكمية';
        }
      case WarehouseTransactionType.return_:
        return 'إرجاع $quantity قطعة';
    }
  }

  WarehouseTransactionModel copyWith({
    String? id,
    String? transactionNumber,
    WarehouseTransactionType? type,
    String? warehouseId,
    String? targetWarehouseId,
    String? productId,
    int? quantity,
    int? quantityBefore,
    int? quantityAfter,
    String? reason,
    String? notes,
    String? referenceId,
    String? referenceType,
    String? performedBy,
    DateTime? performedAt,
    Map<String, dynamic>? metadata,
    ProductModel? product,
    UserModel? performer,
    String? warehouseName,
    String? targetWarehouseName,
  }) {
    return WarehouseTransactionModel(
      id: id ?? this.id,
      transactionNumber: transactionNumber ?? this.transactionNumber,
      type: type ?? this.type,
      warehouseId: warehouseId ?? this.warehouseId,
      targetWarehouseId: targetWarehouseId ?? this.targetWarehouseId,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      quantityBefore: quantityBefore ?? this.quantityBefore,
      quantityAfter: quantityAfter ?? this.quantityAfter,
      reason: reason ?? this.reason,
      notes: notes ?? this.notes,
      referenceId: referenceId ?? this.referenceId,
      referenceType: referenceType ?? this.referenceType,
      performedBy: performedBy ?? this.performedBy,
      performedAt: performedAt ?? this.performedAt,
      metadata: metadata ?? this.metadata,
      product: product ?? this.product,
      performer: performer ?? this.performer,
      warehouseName: warehouseName ?? this.warehouseName,
      targetWarehouseName: targetWarehouseName ?? this.targetWarehouseName,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WarehouseTransactionModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'WarehouseTransactionModel(id: $id, transactionNumber: $transactionNumber, type: $type, quantity: $quantity)';
  }
}

/// نموذج ملخص معاملات المخزن
class WarehouseTransactionSummary {
  final String warehouseId;
  final String? productId;
  final DateTime fromDate;
  final DateTime toDate;
  final int totalStockIn;
  final int totalStockOut;
  final int totalAdjustments;
  final int totalTransfers;
  final int netChange;
  final int transactionCount;

  const WarehouseTransactionSummary({
    required this.warehouseId,
    this.productId,
    required this.fromDate,
    required this.toDate,
    required this.totalStockIn,
    required this.totalStockOut,
    required this.totalAdjustments,
    required this.totalTransfers,
    required this.netChange,
    required this.transactionCount,
  });

  factory WarehouseTransactionSummary.fromJson(Map<String, dynamic> json) {
    return WarehouseTransactionSummary(
      warehouseId: json['warehouse_id'] as String,
      productId: json['product_id'] as String?,
      fromDate: DateTime.parse(json['from_date'] as String),
      toDate: DateTime.parse(json['to_date'] as String),
      totalStockIn: json['total_stock_in'] as int,
      totalStockOut: json['total_stock_out'] as int,
      totalAdjustments: json['total_adjustments'] as int,
      totalTransfers: json['total_transfers'] as int,
      netChange: json['net_change'] as int,
      transactionCount: json['transaction_count'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'warehouse_id': warehouseId,
      'product_id': productId,
      'from_date': fromDate.toIso8601String(),
      'to_date': toDate.toIso8601String(),
      'total_stock_in': totalStockIn,
      'total_stock_out': totalStockOut,
      'total_adjustments': totalAdjustments,
      'total_transfers': totalTransfers,
      'net_change': netChange,
      'transaction_count': transactionCount,
    };
  }
}
