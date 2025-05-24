import 'package:flutter/foundation.dart';

class ProductModel {
  final String id;
  final String name;
  final String description;
  final double price;
  final int quantity;
  final String category;
  final String? imageUrl;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? metadata;
  final bool isActive;
  final String sku;
  final double? discountPrice;
  final int reorderPoint;
  final List<String> images;
  final double? purchasePrice;
  final double? manufacturingCost;
  final String? supplier;
  final double? originalPrice;
  final List<String>? tags;
  final int minimumStock;

  static const String STATUS_ACTIVE = 'active';
  static const String STATUS_INACTIVE = 'inactive';
  static const String STATUS_OUT_OF_STOCK = 'out_of_stock';
  static const String STATUS_DISCONTINUED = 'discontinued';
  static const String STATUS_PENDING = 'pending';

  ProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.quantity,
    required this.category,
    this.imageUrl,
    this.status = STATUS_ACTIVE,
    required this.createdAt,
    this.updatedAt,
    this.metadata,
    required this.isActive,
    required this.sku,
    this.discountPrice,
    required this.reorderPoint,
    required this.images,
    this.purchasePrice,
    this.manufacturingCost,
    this.supplier,
    this.originalPrice,
    this.tags,
    this.minimumStock = 10,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      price: (json['price'] as num).toDouble(),
      quantity: json['quantity'] as int,
      category: json['category'] as String,
      imageUrl: json['image_url'] as String?,
      status: json['status'] as String? ?? STATUS_ACTIVE,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
      isActive: json['is_active'] as bool? ?? true,
      sku: json['sku'] as String,
      discountPrice: json['discount_price'] != null ? (json['discount_price'] as num).toDouble() : null,
      reorderPoint: json['reorder_point'] as int? ?? 10,
      images: List<String>.from(json['images'] as List? ?? []),
      purchasePrice: json['purchase_price'] != null ? (json['purchase_price'] as num).toDouble() : null,
      manufacturingCost: json['manufacturing_cost'] != null ? (json['manufacturing_cost'] as num).toDouble() : null,
      supplier: json['supplier'] as String?,
      originalPrice: json['original_price'] != null ? (json['original_price'] as num).toDouble() : null,
      tags: json['tags'] != null ? List<String>.from(json['tags'] as List) : null,
      minimumStock: json['minimum_stock'] as int? ?? 10,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'quantity': quantity,
      'category': category,
      'image_url': imageUrl,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'metadata': metadata,
      'is_active': isActive,
      'sku': sku,
      'discount_price': discountPrice,
      'reorder_point': reorderPoint,
      'images': images,
      'purchase_price': purchasePrice,
      'manufacturing_cost': manufacturingCost,
      'supplier': supplier,
      'original_price': originalPrice,
      'tags': tags,
      'minimum_stock': minimumStock,
    };
  }

  ProductModel copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    int? quantity,
    String? category,
    String? imageUrl,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
    bool? isActive,
    String? sku,
    double? discountPrice,
    int? reorderPoint,
    List<String>? images,
    double? purchasePrice,
    double? manufacturingCost,
    String? supplier,
    double? originalPrice,
    List<String>? tags,
    int? minimumStock,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
      isActive: isActive ?? this.isActive,
      sku: sku ?? this.sku,
      discountPrice: discountPrice ?? this.discountPrice,
      reorderPoint: reorderPoint ?? this.reorderPoint,
      images: images ?? this.images,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      manufacturingCost: manufacturingCost ?? this.manufacturingCost,
      supplier: supplier ?? this.supplier,
      originalPrice: originalPrice ?? this.originalPrice,
      tags: tags ?? this.tags,
      minimumStock: minimumStock ?? this.minimumStock,
    );
  }

  // Getter for best image URL
  String get bestImageUrl {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return imageUrl!;
    }
    if (images.isNotEmpty) {
      return images.first;
    }
    return 'assets/images/placeholder.png';
  }

  // Compatibility methods
  Map<String, dynamic> toMap() => toJson();
  static ProductModel fromMap(Map<String, dynamic> map) => ProductModel.fromJson(map);
  
  // Additional getters
  String get itemName => name;
  String get productName => name;
  String get clientName => '';
  String get details => description;
  String get productCategory => category;
  double get cost => price;
  int get stock => quantity;
  String get productSku => sku;
  String get productUnit => '';
  bool get inStock => quantity > 0;
  bool get needsRestock => quantity <= reorderPoint;
  
  String getImageUrl({String baseUrl = '', String uploadsPath = ''}) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return _fixImageUrl(imageUrl!, baseUrl: baseUrl, uploadsPath: uploadsPath);
    }
    
    // Return a placeholder as last resort
    return 'assets/images/placeholder.png';
  }

  String _fixImageUrl(String url, {String baseUrl = '', String uploadsPath = ''}) {
    if (url.startsWith('http')) {
      return url;
    }
    
    // If it contains a filename without path, add the complete uploads path
    if (!url.contains('/')) {
      return '$baseUrl$uploadsPath$url';
    }
    
    // If it's a relative URL with path
    if (!url.startsWith('http')) {
      if (url.startsWith('/')) {
        return '$baseUrl$url';
      } else {
        return '$baseUrl/$url';
      }
    }
    
    return url;
  }
}

class ProductCategory {
  static const String rawMaterials = 'RAW_MATERIALS';
  static const String finishedGoods = 'FINISHED_GOODS';
  static const String packaging = 'PACKAGING';
  static const String spareParts = 'SPARE_PARTS';
  static const String consumables = 'CONSUMABLES';
  static const String other = 'OTHER';

  static const List<String> values = [
    rawMaterials,
    finishedGoods,
    packaging,
    spareParts,
    consumables,
    other
  ];
}

class ProductUnit {
  static const String piece = 'PIECE';
  static const String kilogram = 'KILOGRAM';
  static const String meter = 'METER';
  static const String liter = 'LITER';
  static const String box = 'BOX';
  static const String roll = 'ROLL';
  static const String set = 'SET';

  static const List<String> values = [
    piece,
    kilogram,
    meter,
    liter,
    box,
    roll,
    set
  ];
}
