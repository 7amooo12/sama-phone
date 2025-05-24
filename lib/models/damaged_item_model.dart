class DamagedItemModel {
  final int id;
  final String productName;
  final int quantity;
  final String reason;
  final DateTime createdAt;
  final String? imageUrl;
  final Map<String, dynamic>? warehouse;
  final Map<String, dynamic>? order;
  final Map<String, dynamic>? reportedBy;

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
      id: json['id'] ?? 0,
      productName: json['product_name'] ?? '',
      quantity: json['quantity'] ?? 0,
      reason: json['reason'] ?? 'غير معروف',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      imageUrl: json['image_url'],
      warehouse: json['warehouse'],
      order: json['order'],
      reportedBy: json['reported_by'],
    );
  }

  // Backward compatibility getters
  String get warehouseName => warehouse != null ? warehouse!['name'] ?? 'غير محدد' : 'غير محدد';
  int? get warehouseId => warehouse != null ? warehouse!['id'] : null;
  
  String get orderNumber => order != null ? order!['order_number'] ?? 'غير مرتبط بطلب' : 'غير مرتبط بطلب';
  int? get orderId => order != null ? order!['id'] : null;
  
  String get reporterName => reportedBy != null ? reportedBy!['name'] ?? 'غير محدد' : 'غير محدد';
  int? get reporterId => reportedBy != null ? reportedBy!['id'] : null;
  
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