/// نماذج البحث في المخازن
/// Models for warehouse search functionality

import 'package:smartbiztracker_new/models/product_model.dart';
import 'package:smartbiztracker_new/models/warehouse_model.dart';

/// نموذج نتيجة البحث عن المنتج
class ProductSearchResult {
  final String productId;
  final String productName;
  final String? productSku;
  final String? productDescription;
  final String categoryName;
  final int totalQuantity;
  final List<WarehouseInventory> warehouseBreakdown;
  final DateTime lastUpdated;
  final String? imageUrl;
  final double? price;

  const ProductSearchResult({
    required this.productId,
    required this.productName,
    this.productSku,
    this.productDescription,
    required this.categoryName,
    required this.totalQuantity,
    required this.warehouseBreakdown,
    required this.lastUpdated,
    this.imageUrl,
    this.price,
  });

  factory ProductSearchResult.fromJson(Map<String, dynamic> json) {
    return ProductSearchResult(
      productId: json['product_id'] as String,
      productName: json['product_name'] as String,
      productSku: json['product_sku'] as String?,
      productDescription: json['product_description'] as String?,
      categoryName: json['category_name'] as String? ?? 'غير محدد',
      totalQuantity: json['total_quantity'] as int? ?? 0,
      warehouseBreakdown: (json['warehouse_breakdown'] as List<dynamic>?)
          ?.map((item) => WarehouseInventory.fromJson(item as Map<String, dynamic>))
          .toList() ?? [],
      lastUpdated: DateTime.parse(json['last_updated'] as String),
      imageUrl: json['image_url'] as String?,
      price: (json['price'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'product_name': productName,
      'product_sku': productSku,
      'product_description': productDescription,
      'category_name': categoryName,
      'total_quantity': totalQuantity,
      'warehouse_breakdown': warehouseBreakdown.map((w) => w.toJson()).toList(),
      'last_updated': lastUpdated.toIso8601String(),
      'image_url': imageUrl,
      'price': price,
    };
  }

  /// الحصول على حالة المخزون الإجمالية
  String get overallStockStatus {
    if (totalQuantity == 0) return 'out_of_stock';
    if (totalQuantity <= 10) return 'low_stock';
    return 'in_stock';
  }

  /// الحصول على لون حالة المخزون
  String get stockStatusColor {
    switch (overallStockStatus) {
      case 'out_of_stock':
        return '#EF4444'; // أحمر
      case 'low_stock':
        return '#F59E0B'; // برتقالي
      case 'in_stock':
        return '#10B981'; // أخضر
      default:
        return '#6B7280'; // رمادي
    }
  }

  /// نص حالة المخزون
  String get stockStatusText {
    switch (overallStockStatus) {
      case 'out_of_stock':
        return 'نفد المخزون';
      case 'low_stock':
        return 'مخزون منخفض';
      case 'in_stock':
        return 'متوفر';
      default:
        return 'غير محدد';
    }
  }
}

/// نموذج مخزون المخزن
class WarehouseInventory {
  final String warehouseId;
  final String warehouseName;
  final String? warehouseLocation;
  final int quantity;
  final String stockStatus;
  final DateTime lastUpdated;
  final int? minimumStock;
  final int? maximumStock;

  const WarehouseInventory({
    required this.warehouseId,
    required this.warehouseName,
    this.warehouseLocation,
    required this.quantity,
    required this.stockStatus,
    required this.lastUpdated,
    this.minimumStock,
    this.maximumStock,
  });

  factory WarehouseInventory.fromJson(Map<String, dynamic> json) {
    return WarehouseInventory(
      warehouseId: json['warehouse_id'] as String,
      warehouseName: json['warehouse_name'] as String,
      warehouseLocation: json['warehouse_location'] as String?,
      quantity: json['quantity'] as int? ?? 0,
      stockStatus: json['stock_status'] as String? ?? 'unknown',
      lastUpdated: DateTime.parse(json['last_updated'] as String),
      minimumStock: json['minimum_stock'] as int?,
      maximumStock: json['maximum_stock'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'warehouse_id': warehouseId,
      'warehouse_name': warehouseName,
      'warehouse_location': warehouseLocation,
      'quantity': quantity,
      'stock_status': stockStatus,
      'last_updated': lastUpdated.toIso8601String(),
      'minimum_stock': minimumStock,
      'maximum_stock': maximumStock,
    };
  }

  /// الحصول على لون حالة المخزون
  String get stockStatusColor {
    switch (stockStatus) {
      case 'out_of_stock':
        return '#EF4444';
      case 'low_stock':
        return '#F59E0B';
      case 'in_stock':
        return '#10B981';
      default:
        return '#6B7280';
    }
  }

  /// نص حالة المخزون
  String get stockStatusText {
    switch (stockStatus) {
      case 'out_of_stock':
        return 'نفد';
      case 'low_stock':
        return 'منخفض';
      case 'in_stock':
        return 'متوفر';
      default:
        return 'غير محدد';
    }
  }
}

/// نموذج نتيجة البحث عن الفئة
class CategorySearchResult {
  final String categoryId;
  final String categoryName;
  final int productCount;
  final double? totalValue;
  final int totalQuantity;
  final List<ProductSearchResult> products;
  final DateTime lastUpdated;

  const CategorySearchResult({
    required this.categoryId,
    required this.categoryName,
    required this.productCount,
    this.totalValue,
    required this.totalQuantity,
    required this.products,
    required this.lastUpdated,
  });

  factory CategorySearchResult.fromJson(Map<String, dynamic> json) {
    return CategorySearchResult(
      categoryId: json['category_id'] as String,
      categoryName: json['category_name'] as String,
      productCount: json['product_count'] as int? ?? 0,
      totalValue: (json['total_value'] as num?)?.toDouble(),
      totalQuantity: json['total_quantity'] as int? ?? 0,
      products: (json['products'] as List<dynamic>?)
          ?.map((item) => ProductSearchResult.fromJson(item as Map<String, dynamic>))
          .toList() ?? [],
      lastUpdated: DateTime.parse(json['last_updated'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category_id': categoryId,
      'category_name': categoryName,
      'product_count': productCount,
      'total_value': totalValue,
      'total_quantity': totalQuantity,
      'products': products.map((p) => p.toJson()).toList(),
      'last_updated': lastUpdated.toIso8601String(),
    };
  }

  /// متوسط السعر للفئة
  double get averagePrice {
    if (products.isEmpty) return 0.0;
    final totalPrice = products
        .where((p) => p.price != null)
        .fold<double>(0.0, (sum, p) => sum + (p.price ?? 0.0));
    final countWithPrice = products.where((p) => p.price != null).length;
    return countWithPrice > 0 ? totalPrice / countWithPrice : 0.0;
  }

  /// عدد المنتجات المتوفرة
  int get availableProductsCount {
    return products.where((p) => p.totalQuantity > 0).length;
  }

  /// عدد المنتجات النافدة
  int get outOfStockProductsCount {
    return products.where((p) => p.totalQuantity == 0).length;
  }
}

/// نموذج نتائج البحث المجمعة
class WarehouseSearchResults {
  final String searchQuery;
  final List<ProductSearchResult> productResults;
  final List<CategorySearchResult> categoryResults;
  final int totalResults;
  final Duration searchDuration;
  final DateTime searchTime;
  final bool hasMore;
  final int currentPage;

  const WarehouseSearchResults({
    required this.searchQuery,
    required this.productResults,
    required this.categoryResults,
    required this.totalResults,
    required this.searchDuration,
    required this.searchTime,
    this.hasMore = false,
    this.currentPage = 1,
  });

  factory WarehouseSearchResults.empty(String query) {
    return WarehouseSearchResults(
      searchQuery: query,
      productResults: [],
      categoryResults: [],
      totalResults: 0,
      searchDuration: Duration.zero,
      searchTime: DateTime.now(),
    );
  }

  /// هل النتائج فارغة
  bool get isEmpty => productResults.isEmpty && categoryResults.isEmpty;

  /// هل النتائج غير فارغة
  bool get isNotEmpty => !isEmpty;

  /// إجمالي المنتجات الفريدة
  int get uniqueProductsCount {
    final productIds = <String>{};
    productIds.addAll(productResults.map((p) => p.productId));
    for (final category in categoryResults) {
      productIds.addAll(category.products.map((p) => p.productId));
    }
    return productIds.length;
  }

  /// إجمالي الكمية عبر جميع النتائج
  int get totalQuantityAcrossResults {
    int total = 0;
    total += productResults.fold<int>(0, (sum, p) => sum + p.totalQuantity);
    total += categoryResults.fold<int>(0, (sum, c) => sum + c.totalQuantity);
    return total;
  }
}
