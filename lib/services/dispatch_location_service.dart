/// خدمة الكشف الذكي عن مواقع المنتجات في طلبات الصرف
/// Service for intelligent product location detection in dispatch requests

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smartbiztracker_new/models/dispatch_product_processing_model.dart';
import 'package:smartbiztracker_new/models/global_inventory_models.dart';
import 'package:smartbiztracker_new/services/global_inventory_service.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

class DispatchLocationService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final GlobalInventoryService _globalInventoryService = GlobalInventoryService();

  /// البحث عن مواقع جميع المنتجات في طلب الصرف
  Future<List<DispatchProductProcessingModel>> detectProductLocations({
    required List<DispatchProductProcessingModel> products,
    WarehouseSelectionStrategy strategy = WarehouseSelectionStrategy.balanced,
  }) async {
    try {
      AppLogger.info('🔍 بدء الكشف عن مواقع ${products.length} منتج في طلب الصرف');

      final updatedProducts = <DispatchProductProcessingModel>[];

      for (final product in products) {
        try {
          final updatedProduct = await _detectSingleProductLocation(
            product: product,
            strategy: strategy,
          );
          updatedProducts.add(updatedProduct);
        } catch (e) {
          AppLogger.error('❌ خطأ في الكشف عن موقع المنتج ${product.productName}: $e');
          // إضافة المنتج مع معلومات الخطأ
          updatedProducts.add(product.copyWith(
            hasLocationData: true,
            locationSearchError: 'خطأ في البحث: $e',
          ));
        }
      }

      final successfulSearches = updatedProducts.where((p) => p.hasLocationData && p.locationSearchError == null).length;
      AppLogger.info('✅ تم الكشف عن مواقع $successfulSearches من ${products.length} منتج بنجاح');

      return updatedProducts;
    } catch (e) {
      AppLogger.error('❌ خطأ عام في الكشف عن مواقع المنتجات: $e');
      throw Exception('فشل في الكشف عن مواقع المنتجات: $e');
    }
  }

  /// البحث عن موقع منتج واحد
  Future<DispatchProductProcessingModel> _detectSingleProductLocation({
    required DispatchProductProcessingModel product,
    required WarehouseSelectionStrategy strategy,
  }) async {
    try {
      AppLogger.info('🔍 البحث عن موقع المنتج: ${product.productName} (ID: ${product.productId})');

      // البحث العالمي عن المنتج
      final searchResult = await _globalInventoryService.searchProductGlobally(
        productId: product.productId,
        requestedQuantity: product.requestedQuantity,
        strategy: strategy,
      );

      // تحويل نتائج البحث إلى معلومات المواقع
      final warehouseLocations = searchResult.availableWarehouses.map((warehouse) {
        return WarehouseLocationInfo(
          warehouseId: warehouse.warehouseId,
          warehouseName: warehouse.warehouseName,
          warehouseAddress: warehouse.warehouseAddress,
          availableQuantity: warehouse.availableQuantity,
          minimumStock: warehouse.minimumStock,
          maximumStock: warehouse.maximumStock,
          lastUpdated: warehouse.lastUpdated,
          stockStatus: _calculateStockStatus(warehouse.availableQuantity, warehouse.minimumStock),
        );
      }).toList();

      AppLogger.info('📦 تم العثور على المنتج في ${warehouseLocations.length} مخزن');
      AppLogger.info('📊 إجمالي الكمية المتاحة: ${searchResult.totalAvailableQuantity}');
      AppLogger.info('✅ يمكن تلبية الطلب: ${searchResult.canFulfill ? "نعم" : "لا"}');

      return product.withLocationData(
        locations: warehouseLocations,
        totalAvailable: searchResult.totalAvailableQuantity,
        searchError: searchResult.error,
      );
    } catch (e) {
      AppLogger.error('❌ خطأ في البحث عن موقع المنتج ${product.productName}: $e');
      throw Exception('فشل في البحث عن موقع المنتج: $e');
    }
  }

  /// حساب حالة المخزون
  String _calculateStockStatus(int quantity, int? minimumStock) {
    if (quantity == 0) return 'out_of_stock';
    if (minimumStock != null && quantity <= minimumStock) return 'low_stock';
    return 'in_stock';
  }

  /// الحصول على تفاصيل المنتج من قاعدة البيانات
  Future<Map<String, dynamic>?> _getProductDetails(String productId) async {
    try {
      final response = await _supabase
          .from('products')
          .select('id, name, sku, category, image_url, price')
          .eq('id', productId)
          .maybeSingle();

      return response;
    } catch (e) {
      AppLogger.error('❌ خطأ في الحصول على تفاصيل المنتج $productId: $e');
      return null;
    }
  }

  /// تحديث معلومات المنتج مع التفاصيل الإضافية
  Future<DispatchProductProcessingModel> enrichProductWithDetails({
    required DispatchProductProcessingModel product,
  }) async {
    try {
      final productDetails = await _getProductDetails(product.productId);
      
      if (productDetails != null) {
        return product.copyWith(
          productName: productDetails['name'] as String? ?? product.productName,
          productImageUrl: productDetails['image_url'] as String? ?? product.productImageUrl,
        );
      }

      return product;
    } catch (e) {
      AppLogger.error('❌ خطأ في إثراء تفاصيل المنتج: $e');
      return product;
    }
  }

  /// البحث المتقدم مع إعدادات مخصصة
  Future<List<DispatchProductProcessingModel>> detectProductLocationsAdvanced({
    required List<DispatchProductProcessingModel> products,
    WarehouseSelectionStrategy strategy = WarehouseSelectionStrategy.balanced,
    bool enrichWithDetails = true,
    bool respectMinimumStock = true,
    int maxWarehousesPerProduct = 5,
  }) async {
    try {
      AppLogger.info('🔍 بدء البحث المتقدم عن مواقع ${products.length} منتج');

      final updatedProducts = <DispatchProductProcessingModel>[];

      for (final product in products) {
        try {
          var updatedProduct = product;

          // إثراء تفاصيل المنتج إذا كان مطلوباً
          if (enrichWithDetails) {
            updatedProduct = await enrichProductWithDetails(product: updatedProduct);
          }

          // البحث عن المواقع
          updatedProduct = await _detectSingleProductLocation(
            product: updatedProduct,
            strategy: strategy,
          );

          // تطبيق قيود إضافية
          if (updatedProduct.warehouseLocations != null) {
            var filteredLocations = updatedProduct.warehouseLocations!;

            // احترام الحد الأدنى للمخزون
            if (respectMinimumStock) {
              filteredLocations = filteredLocations.where((location) {
                final availableForAllocation = location.minimumStock != null
                    ? (location.availableQuantity - location.minimumStock!).clamp(0, location.availableQuantity)
                    : location.availableQuantity;
                return availableForAllocation > 0;
              }).toList();
            }

            // تحديد عدد المخازن
            if (filteredLocations.length > maxWarehousesPerProduct) {
              filteredLocations = filteredLocations.take(maxWarehousesPerProduct).toList();
            }

            // إعادة حساب الكمية المتاحة الإجمالية
            final totalAvailable = filteredLocations.fold<int>(
              0, (sum, location) => sum + location.availableQuantity,
            );

            updatedProduct = updatedProduct.copyWith(
              warehouseLocations: filteredLocations,
              totalAvailableQuantity: totalAvailable,
              canFulfillRequest: totalAvailable >= updatedProduct.requestedQuantity,
            );
          }

          updatedProducts.add(updatedProduct);
        } catch (e) {
          AppLogger.error('❌ خطأ في المعالجة المتقدمة للمنتج ${product.productName}: $e');
          updatedProducts.add(product.copyWith(
            hasLocationData: true,
            locationSearchError: 'خطأ في المعالجة المتقدمة: $e',
          ));
        }
      }

      final successfulSearches = updatedProducts.where((p) => 
        p.hasLocationData && p.locationSearchError == null && p.canFulfillRequest
      ).length;
      
      AppLogger.info('✅ تم العثور على مواقع مناسبة لـ $successfulSearches من ${products.length} منتج');

      return updatedProducts;
    } catch (e) {
      AppLogger.error('❌ خطأ عام في البحث المتقدم: $e');
      throw Exception('فشل في البحث المتقدم عن مواقع المنتجات: $e');
    }
  }

  /// إنشاء ملخص مواقع المنتجات
  DispatchLocationSummary createLocationSummary(List<DispatchProductProcessingModel> products) {
    final totalProducts = products.length;
    final productsWithLocations = products.where((p) => p.hasLocationData && p.locationSearchError == null).length;
    final fulfillableProducts = products.where((p) => p.canFulfillRequest).length;
    final productsWithErrors = products.where((p) => p.locationSearchError != null).length;

    final allWarehouses = <String, int>{};
    for (final product in products) {
      if (product.warehouseLocations != null) {
        for (final location in product.warehouseLocations!) {
          allWarehouses[location.warehouseName] = (allWarehouses[location.warehouseName] ?? 0) + 1;
        }
      }
    }

    return DispatchLocationSummary(
      totalProducts: totalProducts,
      productsWithLocations: productsWithLocations,
      fulfillableProducts: fulfillableProducts,
      productsWithErrors: productsWithErrors,
      uniqueWarehouses: allWarehouses.keys.toList(),
      warehouseProductCounts: allWarehouses,
      searchTimestamp: DateTime.now(),
    );
  }
}

/// ملخص نتائج البحث عن مواقع المنتجات
class DispatchLocationSummary {
  final int totalProducts;
  final int productsWithLocations;
  final int fulfillableProducts;
  final int productsWithErrors;
  final List<String> uniqueWarehouses;
  final Map<String, int> warehouseProductCounts;
  final DateTime searchTimestamp;

  const DispatchLocationSummary({
    required this.totalProducts,
    required this.productsWithLocations,
    required this.fulfillableProducts,
    required this.productsWithErrors,
    required this.uniqueWarehouses,
    required this.warehouseProductCounts,
    required this.searchTimestamp,
  });

  /// نسبة النجاح في العثور على المواقع
  double get locationSuccessRate => totalProducts > 0 ? (productsWithLocations / totalProducts * 100) : 0;

  /// نسبة المنتجات القابلة للتلبية
  double get fulfillmentRate => totalProducts > 0 ? (fulfillableProducts / totalProducts * 100) : 0;

  /// نص ملخص النتائج
  String get summaryText {
    return 'تم العثور على مواقع $productsWithLocations من $totalProducts منتج '
           '($fulfillableProducts قابل للتلبية) في ${uniqueWarehouses.length} مخزن';
  }
}
