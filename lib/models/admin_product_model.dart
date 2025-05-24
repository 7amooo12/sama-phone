import 'package:flutter/foundation.dart';

class AdminProductModel {
  final int id;
  final String name;
  final String description;
  final String? imageUrl;
  final double purchasePrice;
  final double sellingPrice;
  final double finalPrice;
  final int stockQuantity;
  final double discountPercent;
  final double discountFixed;
  final String? categoryName;
  final bool featured;
  final bool isVisible;

  const AdminProductModel({
    required this.id,
    required this.name,
    required this.description,
    this.imageUrl,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.finalPrice,
    required this.stockQuantity,
    required this.discountPercent,
    required this.discountFixed,
    this.categoryName,
    required this.featured,
    required this.isVisible,
  });

  factory AdminProductModel.fromJson(Map<String, dynamic> json) {
    // Handle the image URL - API returns "image_url" but our model has "imageUrl"
    String? imageUrl = json['image_url'] as String?;
    
    return AdminProductModel(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      imageUrl: imageUrl,
      purchasePrice: json['purchase_price'] != null ? (json['purchase_price'] as num).toDouble() : 0.0,
      sellingPrice: json['selling_price'] != null ? (json['selling_price'] as num).toDouble() : 0.0,
      finalPrice: json['final_price'] != null ? (json['final_price'] as num).toDouble() : 0.0,
      stockQuantity: json['stock_quantity'] as int? ?? 0,
      discountPercent: json['discount_percent'] != null ? (json['discount_percent'] as num).toDouble() : 0.0,
      discountFixed: json['discount_fixed'] != null ? (json['discount_fixed'] as num).toDouble() : 0.0,
      categoryName: json['category_name'] as String?,
      featured: json['featured'] as bool? ?? false,
      isVisible: json['is_visible'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'image_url': imageUrl,
      'purchase_price': purchasePrice,
      'selling_price': sellingPrice,
      'final_price': finalPrice, 
      'stock_quantity': stockQuantity,
      'discount_percent': discountPercent,
      'discount_fixed': discountFixed,
      'category_name': categoryName,
      'featured': featured,
      'is_visible': isVisible,
    };
  }

  // Helper getters
  bool get isOnSale => discountPercent > 0 || discountFixed > 0;
  bool get isInStock => stockQuantity > 0;
  String get displayPurchasePrice => purchasePrice.toStringAsFixed(2);
  String get displaySellingPrice => sellingPrice.toStringAsFixed(2);
  String get displayFinalPrice => finalPrice.toStringAsFixed(2);
  
  @override
  String toString() => 'AdminProductModel(id: $id, name: $name, price: $finalPrice)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AdminProductModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
} 