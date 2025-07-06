import 'package:smartbiztracker_new/models/product_model.dart';
import 'package:smartbiztracker_new/models/warehouse_inventory_model.dart';
import 'package:smartbiztracker_new/models/warehouse_model.dart';

/// نموذج تقرير تحليل المعرض
class ExhibitionAnalysisReport {
  final List<WarehouseInventoryModel> exhibitionProducts;
  final List<ApiProductModel> missingProducts;
  final List<ApiProductModel> allApiProducts;
  final DateTime generatedAt;
  final String exhibitionWarehouseId;
  final String exhibitionWarehouseName;

  const ExhibitionAnalysisReport({
    required this.exhibitionProducts,
    required this.missingProducts,
    required this.allApiProducts,
    required this.generatedAt,
    required this.exhibitionWarehouseId,
    required this.exhibitionWarehouseName,
  });

  /// إحصائيات التقرير
  Map<String, dynamic> get statistics => {
    'total_api_products': allApiProducts.length,
    'exhibition_products': exhibitionProducts.length,
    'missing_products': missingProducts.length,
    'coverage_percentage': allApiProducts.isEmpty ? 0.0 : 
        (exhibitionProducts.length / allApiProducts.length * 100),
    'total_exhibition_quantity': exhibitionProducts.fold(0, (sum, item) => sum + item.quantity),
    'total_exhibition_cartons': exhibitionProducts.fold(0, (sum, item) => sum + item.cartonsCount),
  };
}

/// نموذج منتج من API خارجي
class ApiProductModel {
  final String id;
  final String name;
  final String description;
  final double price;
  final String category;
  final String? imageUrl;
  final String? sku;
  final bool isActive;
  final int quantity; // كمية المنتج في API
  final Map<String, dynamic>? metadata;

  const ApiProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    this.imageUrl,
    this.sku,
    this.isActive = true,
    this.quantity = 0,
    this.metadata,
  });

  factory ApiProductModel.fromJson(Map<String, dynamic> json) {
    return ApiProductModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'منتج غير محدد',
      description: json['description']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      category: json['category']?.toString() ?? 'عام',
      imageUrl: json['image_url']?.toString() ?? json['imageUrl']?.toString(),
      sku: json['sku']?.toString(),
      isActive: json['is_active'] as bool? ?? json['isActive'] as bool? ?? true,
      quantity: (json['quantity'] as num?)?.toInt() ??
                (json['stock_quantity'] as num?)?.toInt() ??
                (json['stockQuantity'] as num?)?.toInt() ?? 0,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'category': category,
      'image_url': imageUrl,
      'sku': sku,
      'is_active': isActive,
      'quantity': quantity,
      'metadata': metadata,
    };
  }
}

/// نموذج تغطية المخزون الذكية
class InventoryCoverageReport {
  final List<ProductCoverageAnalysis> productAnalyses;
  final List<WarehouseModel> warehouses;
  final int totalApiProducts;
  final DateTime generatedAt;
  final Map<String, dynamic> globalStatistics;

  const InventoryCoverageReport({
    required this.productAnalyses,
    required this.warehouses,
    required this.totalApiProducts,
    required this.generatedAt,
    required this.globalStatistics,
  });

  /// إحصائيات التغطية العامة
  Map<String, dynamic> get coverageStatistics {
    final totalWarehouseQuantity = productAnalyses.fold(0, (sum, analysis) => 
        sum + analysis.totalWarehouseQuantity);
    
    final productsWithStock = productAnalyses.where((analysis) => 
        analysis.totalWarehouseQuantity > 0).length;
    
    final averageCoverage = productAnalyses.isEmpty ? 0.0 :
        productAnalyses.fold(0.0, (sum, analysis) => sum + analysis.coveragePercentage) / 
        productAnalyses.length;

    return {
      'total_products_analyzed': productAnalyses.length,
      'products_with_stock': productsWithStock,
      'products_without_stock': productAnalyses.length - productsWithStock,
      'total_warehouse_quantity': totalWarehouseQuantity,
      'average_coverage_percentage': averageCoverage,
      'coverage_distribution': _calculateCoverageDistribution(),
    };
  }

  Map<String, int> _calculateCoverageDistribution() {
    final distribution = <String, int>{
      'excellent': 0,  // 100% (Full Coverage)
      'good': 0,       // 80-99% (Good Coverage)
      'moderate': 0,   // 50-79% (Partial Coverage)
      'low': 0,        // 1-49% (Low Coverage)
      'critical': 0,   // 0% (Missing)
      'exception': 0,  // N/A (API quantity = 0)
    };

    for (final analysis in productAnalyses) {
      final status = analysis.status;
      switch (status) {
        case CoverageStatus.excellent:
          distribution['excellent'] = distribution['excellent']! + 1;
          break;
        case CoverageStatus.good:
          distribution['good'] = distribution['good']! + 1;
          break;
        case CoverageStatus.moderate:
          distribution['moderate'] = distribution['moderate']! + 1;
          break;
        case CoverageStatus.low:
          distribution['low'] = distribution['low']! + 1;
          break;
        case CoverageStatus.critical:
        case CoverageStatus.missing:
          distribution['critical'] = distribution['critical']! + 1;
          break;
        case CoverageStatus.exception:
          distribution['exception'] = distribution['exception']! + 1;
          break;
      }
    }

    return distribution;
  }
}

/// تحليل تغطية منتج واحد
class ProductCoverageAnalysis {
  final ApiProductModel apiProduct;
  final List<WarehouseInventoryModel> warehouseInventories;
  final int totalWarehouseQuantity;
  final double coveragePercentage;
  final CoverageStatus status;
  final List<String> recommendations;

  const ProductCoverageAnalysis({
    required this.apiProduct,
    required this.warehouseInventories,
    required this.totalWarehouseQuantity,
    required this.coveragePercentage,
    required this.status,
    required this.recommendations,
  });

  /// توزيع المنتج عبر المخازن
  Map<String, int> get warehouseDistribution {
    final distribution = <String, int>{};
    for (final inventory in warehouseInventories) {
      distribution[inventory.warehouseName ?? inventory.warehouseId] = inventory.quantity;
    }
    return distribution;
  }

  /// إجمالي عدد الكراتين
  int get totalCartons => warehouseInventories.fold(0, (sum, inventory) => 
      sum + inventory.cartonsCount);

  /// متوسط الكمية لكل مخزن
  double get averageQuantityPerWarehouse => warehouseInventories.isEmpty ? 0.0 :
      totalWarehouseQuantity / warehouseInventories.length;
}

/// حالة التغطية
enum CoverageStatus {
  excellent,  // 100% (Full Coverage)
  good,       // 80-99% (Good Coverage)
  moderate,   // 50-79% (Partial Coverage)
  low,        // 1-49% (Low Coverage)
  critical,   // 0% (Critical/Missing)
  missing,    // 0% (Missing - alias for critical)
  exception,  // N/A (API product has zero stock quantity)
}

extension CoverageStatusExtension on CoverageStatus {
  String get displayName {
    switch (this) {
      case CoverageStatus.excellent:
        return 'تغطية كاملة (100%)';
      case CoverageStatus.good:
        return 'تغطية جيدة (80-99%)';
      case CoverageStatus.moderate:
        return 'تغطية جزئية (50-79%)';
      case CoverageStatus.low:
        return 'تغطية منخفضة (1-49%)';
      case CoverageStatus.critical:
        return 'حرجة (0%)';
      case CoverageStatus.missing:
        return 'مفقودة (0%)';
      case CoverageStatus.exception:
        return 'غير قابل للحساب (API: 0)';
    }
  }

  String get colorCode {
    switch (this) {
      case CoverageStatus.excellent:
        return '#10B981'; // Green
      case CoverageStatus.good:
        return '#3B82F6'; // Blue
      case CoverageStatus.moderate:
        return '#F59E0B'; // Yellow
      case CoverageStatus.low:
        return '#EF4444'; // Red
      case CoverageStatus.critical:
        return '#DC2626'; // Dark Red
      case CoverageStatus.missing:
        return '#6B7280'; // Gray
      case CoverageStatus.exception:
        return '#8B5CF6'; // Purple - for exception status
    }
  }
}

/// نموذج مطابقة المنتجات الذكية
class SmartProductMatch {
  final ApiProductModel apiProduct;
  final WarehouseInventoryModel? warehouseProduct;
  final double matchScore;
  final MatchType matchType;
  final List<String> matchReasons;

  const SmartProductMatch({
    required this.apiProduct,
    this.warehouseProduct,
    required this.matchScore,
    required this.matchType,
    required this.matchReasons,
  });

  /// هل يوجد مطابقة (بغض النظر عن الكمية)
  bool get isMatched => warehouseProduct != null && matchScore >= 0.7;

  /// هل المنتج مفقود (لا توجد مطابقة أو الكمية صفر)
  bool get isMissing => warehouseProduct == null || (warehouseProduct?.quantity ?? 0) <= 0;

  /// هل المنتج متوفر (يوجد مطابقة والكمية > 0)
  bool get isAvailable => warehouseProduct != null && (warehouseProduct?.quantity ?? 0) > 0;
}

/// نوع المطابقة
enum MatchType {
  exact,      // مطابقة تامة
  similar,    // مطابقة مشابهة
  partial,    // مطابقة جزئية
  none,       // لا توجد مطابقة
}

extension MatchTypeExtension on MatchType {
  String get displayName {
    switch (this) {
      case MatchType.exact:
        return 'مطابقة تامة';
      case MatchType.similar:
        return 'مطابقة مشابهة';
      case MatchType.partial:
        return 'مطابقة جزئية';
      case MatchType.none:
        return 'لا توجد مطابقة';
    }
  }
}
