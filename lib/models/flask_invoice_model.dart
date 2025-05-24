import 'package:flutter/foundation.dart';

class FlaskInvoiceItemModel {
  final int productId;
  final String productName;
  final int quantity;
  final double price;
  final double total;
  final String? category;

  const FlaskInvoiceItemModel({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    required this.total,
    this.category,
  });

  factory FlaskInvoiceItemModel.fromJson(Map<String, dynamic> json) {
    return FlaskInvoiceItemModel(
      productId: json['product_id'] as int,
      productName: json['product_name'] as String,
      quantity: json['quantity'] as int,
      price: (json['price'] as num).toDouble(),
      total: (json['total'] as num).toDouble(),
      category: json['category'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'price': price,
      'total': total,
      'category': category,
    };
  }
}

class FlaskInvoiceModel {
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
  });

  String get invoiceNumber => id.toString();
  double get taxAmount => 0.0; // Assuming no tax or it's included in the total
  double get discountAmount => discount;
  String? get notes => null; // Assuming no notes available
  DateTime get date => createdAt; // Add getter for date that returns createdAt

  factory FlaskInvoiceModel.fromJson(Map<String, dynamic> json) {
    return FlaskInvoiceModel(
      id: json['id'] as int,
      customerName: json['customer_name'] as String? ?? 'Unknown',
      customerPhone: json['customer_phone'] as String?,
      customerEmail: json['customer_email'] as String?,
      totalAmount: (json['total_amount'] as num).toDouble(),
      discount: (json['discount'] as num).toDouble(),
      finalAmount: (json['final_amount'] as num).toDouble(),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at']),
      items: json['items'] != null
          ? (json['items'] as List<dynamic>)
              .map((item) => FlaskInvoiceItemModel.fromJson(item as Map<String, dynamic>))
              .toList()
          : null,
      itemsCount: json['items_count'] as int?,
      matchingProducts: json['matching_products'] != null
          ? (json['matching_products'] as List<dynamic>)
              .map((item) => FlaskInvoiceItemModel.fromJson(item as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

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