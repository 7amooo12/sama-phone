

class FlaskInvoiceItemModel {

  const FlaskInvoiceItemModel({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    required this.total,
    this.category,
    this.imageUrl,
  });

  factory FlaskInvoiceItemModel.fromJson(Map<String, dynamic> json) {
    return FlaskInvoiceItemModel(
      productId: json['product_id'] as int,
      productName: json['product_name'] as String,
      quantity: json['quantity'] as int,
      price: (json['price'] as num).toDouble(),
      total: (json['total'] as num).toDouble(),
      category: json['category'] as String?,
      imageUrl: json['image_url'] as String?,
    );
  }
  final int productId;
  final String productName;
  final int quantity;
  final double price;
  final double total;
  final String? category;
  final String? imageUrl;

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'price': price,
      'total': total,
      'category': category,
      'image_url': imageUrl,
    };
  }
}

class FlaskInvoiceModel {

  const FlaskInvoiceModel({
    required this.id,
    required this.customerName,
    this.customerPhone,
    this.customerEmail,
    required this.totalAmount,
    required this.discount,
    required this.finalAmount,
    required this.status,
    required this.createdAt,
    this.items,
    this.itemsCount,
    this.matchingProducts,
  }); // Add getter for date that returns createdAt

  factory FlaskInvoiceModel.fromJson(Map<String, dynamic> json) {
    // Parse items with better error handling
    List<FlaskInvoiceItemModel>? items;
    try {
      if (json['items'] != null) {
        final itemsData = json['items'];
        if (itemsData is List) {
          items = itemsData
              .where((item) => item != null) // Filter out null items
              .map((item) {
                try {
                  return FlaskInvoiceItemModel.fromJson(item as Map<String, dynamic>);
                } catch (e) {
                  print('⚠️ Error parsing invoice item: $e');
                  print('📄 Item data: $item');
                  return null;
                }
              })
              .where((item) => item != null) // Filter out failed parsing attempts
              .cast<FlaskInvoiceItemModel>()
              .toList();
        } else {
          print('⚠️ Items data is not a List: ${itemsData.runtimeType}');
          items = null;
        }
      }
    } catch (e) {
      print('❌ Error parsing items for invoice ${json['id']}: $e');
      items = null;
    }

    // Parse matching products with better error handling
    List<FlaskInvoiceItemModel>? matchingProducts;
    try {
      if (json['matching_products'] != null) {
        final matchingData = json['matching_products'];
        if (matchingData is List) {
          matchingProducts = matchingData
              .where((item) => item != null)
              .map((item) {
                try {
                  return FlaskInvoiceItemModel.fromJson(item as Map<String, dynamic>);
                } catch (e) {
                  print('⚠️ Error parsing matching product: $e');
                  return null;
                }
              })
              .where((item) => item != null)
              .cast<FlaskInvoiceItemModel>()
              .toList();
        }
      }
    } catch (e) {
      print('❌ Error parsing matching products for invoice ${json['id']}: $e');
      matchingProducts = null;
    }

    return FlaskInvoiceModel(
      id: json['id'] as int,
      customerName: json['customer_name'] as String? ?? 'Unknown',
      customerPhone: json['customer_phone'] as String?,
      customerEmail: json['customer_email'] as String?,
      totalAmount: (json['total_amount'] as num).toDouble(),
      discount: (json['discount'] as num).toDouble(),
      finalAmount: (json['final_amount'] as num).toDouble(),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      items: items,
      itemsCount: json['items_count'] as int?,
      matchingProducts: matchingProducts,
    );
  }
  final int id;
  final String customerName;
  final String? customerPhone;
  final String? customerEmail;
  final double totalAmount;
  final double discount;
  final double finalAmount;
  final String status;
  final DateTime createdAt;
  final List<FlaskInvoiceItemModel>? items;
  final int? itemsCount;
  final List<FlaskInvoiceItemModel>? matchingProducts;

  String get invoiceNumber => id.toString();
  double get taxAmount => 0.0; // Assuming no tax or it's included in the total
  double get discountAmount => discount;
  String? get notes => null; // Assuming no notes available
  DateTime get date => createdAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_email': customerEmail,
      'total_amount': totalAmount,
      'discount': discount,
      'final_amount': finalAmount,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'items': items?.map((item) => item.toJson()).toList(),
      'items_count': itemsCount ?? items?.length,
      'matching_products': matchingProducts?.map((item) => item.toJson()).toList(),
    };
  }

  @override
  String toString() => 'FlaskInvoiceModel(id: $id, customerName: $customerName, finalAmount: $finalAmount)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FlaskInvoiceModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}