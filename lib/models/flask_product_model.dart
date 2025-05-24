import 'package:flutter/foundation.dart';

class FlaskProductModel {
  final int id;
  final String name;
  final String description;
  final double purchasePrice;
  final double sellingPrice;
  final double finalPrice;
  final int stockQuantity;
  final String? imageUrl;
  final double discountPercent;
  final double discountFixed;
  final String? categoryName;
  final bool featured;
  final bool isVisible;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const FlaskProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.finalPrice,
    required this.stockQuantity,
    this.imageUrl,
    required this.discountPercent,
    required this.discountFixed,
    this.categoryName,
    required this.featured,
    required this.isVisible,
    this.createdAt,
    this.updatedAt,
  });

  factory FlaskProductModel.fromJson(Map<String, dynamic> json) {
    // Debug print to check incoming JSON data
    print('DEBUG: Product JSON data: ${json['name']}');
    print('DEBUG: purchase_price in JSON: ${json['purchase_price']}');
    print('DEBUG: selling_price in JSON: ${json['selling_price']}');
    
    return FlaskProductModel(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      purchasePrice: (json['purchase_price'] as num).toDouble(),
      sellingPrice: (json['selling_price'] as num).toDouble(),
      finalPrice: (json['final_price'] as num).toDouble(),
      stockQuantity: json['stock_quantity'] as int? ?? 0,
      imageUrl: json['image_url'] as String?,
      discountPercent: (json['discount_percent'] as num?)?.toDouble() ?? 0.0,
      discountFixed: (json['discount_fixed'] as num?)?.toDouble() ?? 0.0,
      categoryName: json['category_name'] as String?,
      featured: json['featured'] as bool? ?? false,
      isVisible: json['is_visible'] as bool? ?? true,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'purchase_price': purchasePrice,
      'selling_price': sellingPrice,
      'final_price': finalPrice, 
      'stock_quantity': stockQuantity,
      'image_url': imageUrl,
      'discount_percent': discountPercent,
      'discount_fixed': discountFixed,
      'category_name': categoryName,
      'featured': featured,
      'is_visible': isVisible,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // Helper getters
  bool get isOnSale => discountPercent > 0 || discountFixed > 0;
  bool get isInStock => stockQuantity > 0;
  String get displayPrice => finalPrice.toStringAsFixed(2);
  String get displayOriginalPrice => sellingPrice.toStringAsFixed(2);
  String get displayDiscount {
    if (discountPercent > 0) {
      return '${discountPercent.toStringAsFixed(0)}%';
    } else if (discountFixed > 0) {
      return '\$${discountFixed.toStringAsFixed(2)}';
    } else {
      return '';
    }
  }
  
  // Conversion to generic product model if needed
  Map<String, dynamic> toGenericMap() {
    return {
      'id': id.toString(),
      'name': name,
      'description': description,
      'price': finalPrice,
      'quantity': stockQuantity,
      'category': categoryName ?? '',
      'images': imageUrl != null ? [imageUrl!] : <String>[],
      'sku': id.toString(),
      'isActive': isVisible,
      'createdAt': createdAt ?? DateTime.now(),
    };
  }

  @override
  String toString() => 'FlaskProductModel(id: $id, name: $name, price: $finalPrice)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FlaskProductModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
} 