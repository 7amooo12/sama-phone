import 'package:flutter/foundation.dart';

class Product {

  Product({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    this.imageUrl,
    this.availableQuantity,
    this.category,
    this.rating,
    required this.stock,
    required this.url,
    required this.brand,
    this.originalPrice,
    bool? inStock,
  }) : inStock = inStock ?? (stock > 0);

  // Factory constructor to create a Product from JSON
  factory Product.fromJson(Map<String, dynamic> json) {
    final int stockValue = json['stock'] is int
        ? json['stock'] as int
        : (json['quantity'] is int
            ? json['quantity'] as int
            : int.tryParse(json['stock']?.toString() ?? json['quantity']?.toString() ?? '0') ?? 0);

    return Product(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      price: json['price'] is double
          ? json['price'] as double
          : (json['price'] is int
              ? (json['price'] as int).toDouble()
              : double.tryParse(json['price'].toString()) ?? 0.0),
      imageUrl: json['imageUrl'] as String?,
      availableQuantity: json['availableQuantity'] is int
          ? json['availableQuantity'] as int?
          : int.tryParse(json['availableQuantity']?.toString() ?? ''),
      category: json['category'] as String?,
      rating: json['rating'] is double
          ? json['rating'] as double?
          : (json['rating'] is int
              ? (json['rating'] as int).toDouble()
              : double.tryParse(json['rating']?.toString() ?? '')),
      stock: stockValue,
      url: json['url'] as String? ?? '',
      brand: json['brand'] as String? ?? json['supplier'] as String? ?? '',
      originalPrice: json['originalPrice'] is double
          ? json['originalPrice'] as double?
          : (json['originalPrice'] is int
              ? (json['originalPrice'] as int).toDouble()
              : double.tryParse(json['originalPrice']?.toString() ?? '')),
      inStock: json['inStock'] is bool
          ? json['inStock'] as bool
          : stockValue > 0,
    );
  }

  // Factory constructor to create a Product from ProductModel
  factory Product.fromProductModel(dynamic productModel) {
    if (productModel == null) {
      return Product(
        id: 0,
        name: '',
        price: 0.0,
        stock: 0,
        url: '',
        brand: '',
        inStock: false,
      );
    }

    try {
      final int stockValue = (productModel.quantity as int?) ?? 0;

      return Product(
        id: int.tryParse(productModel.id?.toString() ?? '0') ?? 0,
        name: (productModel.name as String?) ?? '',
        description: productModel.description as String?,
        price: (productModel.price as double?) ?? 0.0,
        imageUrl: _getBestImageUrl(productModel),
        availableQuantity: stockValue,
        category: productModel.category as String?,
        rating: 0.0, // Assuming ProductModel doesn't have rating
        stock: stockValue,
        url: '', // Assuming ProductModel doesn't have URL
        brand: (productModel.supplier as String?) ?? '',
        originalPrice: productModel.originalPrice as double?,
        inStock: stockValue > 0,
      );
    } catch (e) {
      debugPrint('Error creating Product from ProductModel: $e');
      return Product(
        id: 0,
        name: 'Error Product',
        price: 0.0,
        stock: 0,
        url: '',
        brand: '',
        inStock: false,
      );
    }
  }
  final int id;
  final String name;
  final String? description;
  final double price;
  final String? imageUrl;
  final int? availableQuantity;
  final String? category;
  final double? rating;
  final int stock;
  final String url;
  final String brand;
  final double? originalPrice;
  final bool inStock;

  // Helper method to get the best image URL from ProductModel
  static String? _getBestImageUrl(dynamic productModel) {
    try {
      // First try the main imageUrl
      final imageUrl = productModel?.imageUrl;
      if (imageUrl != null && imageUrl is String && imageUrl.isNotEmpty) {
        debugPrint('Using main imageUrl: $imageUrl');
        return imageUrl;
      }

      // Then try the images array
      final images = productModel?.images;
      if (images != null && images is List && images.isNotEmpty) {
        final firstImage = images.first;
        if (firstImage != null && firstImage is String && firstImage.isNotEmpty) {
          debugPrint('Using first image from array: $firstImage');
          return firstImage;
        }
      }

      debugPrint('No valid image URL found for product: ${productModel?.name}');
      return null;
    } catch (e) {
      debugPrint('Error getting image URL: $e');
      return null;
    }
  }

  // Convert Product to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'imageUrl': imageUrl,
      'availableQuantity': availableQuantity,
      'category': category,
      'rating': rating,
      'stock': stock,
      'url': url,
      'brand': brand,
      'originalPrice': originalPrice,
      'inStock': inStock,
    };
  }

  // Convert to ProductModel for compatibility with the rest of the app
  Map<String, dynamic> toProductModelJson() {
    return {
      'id': id.toString(),
      'name': name,
      'description': description,
      'price': price,
      'quantity': stock,
      'category': category ?? '',
      'images': imageUrl != null ? [imageUrl!] : [],
      'sku': 'SAMA-$id',
      'isActive': inStock,
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
      'minimumStock': 5,
      'reorderPoint': 10,
      'supplier': brand,
      'imageUrl': imageUrl,
      'originalPrice': originalPrice,
    };
  }
}
