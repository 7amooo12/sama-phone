class DamagedItemModel {

  DamagedItemModel({
    required this.id,
    required this.productName,
    required this.quantity,
    required this.reason,
    required this.createdAt,
    this.imageUrl,
    this.warehouse,
    this.order,
    this.reportedBy,
  });

  factory DamagedItemModel.fromJson(Map<String, dynamic> json) {
    return DamagedItemModel(
      id: (json['id'] as int?) ?? 0,
      productName: (json['product_name'] as String?) ?? '',
      quantity: (json['quantity'] as int?) ?? 0,
      reason: (json['reason'] as String?) ?? 'غير معروف',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      imageUrl: json['image_url'] as String?,
      warehouse: json['warehouse'] as Map<String, dynamic>?,
      order: json['order'] as Map<String, dynamic>?,
      reportedBy: json['reported_by'] as Map<String, dynamic>?,
    );
  }
  final int id;
  final String productName;
  final int quantity;
  final String reason;
  final DateTime createdAt;
  final String? imageUrl;
  final Map<String, dynamic>? warehouse;
  final Map<String, dynamic>? order;
  final Map<String, dynamic>? reportedBy;

  // Backward compatibility getters
  String get warehouseName => warehouse != null ? (warehouse!['name'] as String?) ?? 'غير محدد' : 'غير محدد';
  int? get warehouseId => warehouse != null ? warehouse!['id'] as int? : null;

  String get orderNumber => order != null ? (order!['order_number'] as String?) ?? 'غير مرتبط بطلب' : 'غير مرتبط بطلب';
  int? get orderId => order != null ? order!['id'] as int? : null;

  String get reporterName => reportedBy != null ? (reportedBy!['name'] as String?) ?? 'غير محدد' : 'غير محدد';
  int? get reporterId => reportedBy != null ? reportedBy!['id'] as int? : null;

  // For backward compatibility with old code
  DateTime get reportedDate => createdAt;
  String? get notes => reason;
  String get status => 'تالف / هوالك';
  String get productId => id.toString();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_name': productName,
      'quantity': quantity,
      'reason': reason,
      'created_at': createdAt.toIso8601String(),
      'image_url': imageUrl,
      'warehouse': warehouse,
      'order': order,
      'reported_by': reportedBy,
    };
  }
}