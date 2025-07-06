import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product_model.dart';
import '../utils/app_logger.dart';
import 'api_product_sync_service.dart';

/// خدمة تنظيف وإصلاح بيانات المنتجات العامة في قاعدة البيانات
class ProductDataCleanupService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ApiProductSyncService _apiService = ApiProductSyncService();

  /// تنظيف وإصلاح جميع المنتجات العامة في قاعدة البيانات
  Future<CleanupResult> cleanupGenericProducts() async {
    try {
      AppLogger.info('🧹 بدء عملية تنظيف المنتجات العامة...');

      // الحصول على جميع المنتجات من قاعدة البيانات
      final response = await _supabase
          .from('products')
          .select('*')
          .eq('active', true);

      final products = (response as List<dynamic>)
          .map((json) => ProductModel.fromJson(json as Map<String, dynamic>))
          .toList();

      AppLogger.info('📦 تم العثور على ${products.length} منتج للفحص');

      int fixedCount = 0;
      int failedCount = 0;
      final List<String> fixedProducts = [];
      final List<String> failedProducts = [];

      for (final product in products) {
        if (_isGenericProduct(product)) {
          AppLogger.info('🔄 إصلاح المنتج العام: ${product.id} - ${product.name}');
          
          final success = await _fixGenericProduct(product);
          if (success) {
            fixedCount++;
            fixedProducts.add('${product.id}: ${product.name}');
            AppLogger.info('✅ تم إصلاح المنتج: ${product.id}');
          } else {
            failedCount++;
            failedProducts.add('${product.id}: ${product.name}');
            AppLogger.error('❌ فشل في إصلاح المنتج: ${product.id}');
          }
        }
      }

      final result = CleanupResult(
        totalProducts: products.length,
        genericProductsFound: fixedCount + failedCount,
        fixedProducts: fixedCount,
        failedProducts: failedCount,
        fixedProductsList: fixedProducts,
        failedProductsList: failedProducts,
      );

      AppLogger.info('🎉 انتهت عملية التنظيف:');
      AppLogger.info('   إجمالي المنتجات: ${result.totalProducts}');
      AppLogger.info('   المنتجات العامة: ${result.genericProductsFound}');
      AppLogger.info('   تم إصلاحها: ${result.fixedProducts}');
      AppLogger.info('   فشل في إصلاحها: ${result.failedProducts}');

      return result;
    } catch (e) {
      AppLogger.error('❌ خطأ في عملية تنظيف المنتجات: $e');
      throw Exception('فشل في عملية تنظيف المنتجات: $e');
    }
  }

  /// إصلاح منتج عام واحد
  Future<bool> _fixGenericProduct(ProductModel product) async {
    try {
      // محاولة الحصول على بيانات حقيقية من API
      final apiProduct = await _apiService.getProductFromApi(product.id);
      
      if (apiProduct == null) {
        AppLogger.warning('⚠️ لم يتم العثور على بيانات API للمنتج: ${product.id}');
        return false;
      }

      // التحقق من أن البيانات المستلمة ليست عامة
      final apiProductName = apiProduct['name']?.toString() ?? '';
      if (_isGenericProductName(apiProductName)) {
        AppLogger.warning('⚠️ البيانات المستلمة من API لا تزال عامة: $apiProductName');
        return false;
      }

      // تحديث المنتج في قاعدة البيانات
      final updateData = {
        'name': apiProduct['name'],
        'description': apiProduct['description'] ?? product.description,
        'price': apiProduct['price'] ?? product.price,
        'category': apiProduct['category'] ?? product.category,
        'image_url': apiProduct['image_url'] ?? product.imageUrl,
        'images': apiProduct['images'] ?? product.images,
        'sku': apiProduct['sku'] ?? product.sku,
        'supplier': apiProduct['supplier'] ?? product.supplier,
        'manufacturer': apiProduct['manufacturer'] ?? product.manufacturer,
        'purchase_price': apiProduct['purchase_price'] ?? product.purchasePrice,
        'original_price': apiProduct['original_price'] ?? product.originalPrice,
        'tags': apiProduct['tags'] ?? product.tags,
        'metadata': {
          ...product.metadata ?? {},
          'fixed_at': DateTime.now().toIso8601String(),
          'fixed_from_api': true,
          'api_source': apiProduct['metadata']?['api_source'] ?? 'unknown',
          'data_quality': 'fixed_real_data',
        },
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabase
          .from('products')
          .update(updateData)
          .eq('id', product.id);

      AppLogger.info('✅ تم تحديث المنتج بالبيانات الحقيقية: ${apiProduct['name']}');
      return true;
    } catch (e) {
      AppLogger.error('❌ خطأ في إصلاح المنتج ${product.id}: $e');
      return false;
    }
  }

  /// التحقق من كون المنتج عام
  bool _isGenericProduct(ProductModel product) {
    // التحقق من الأنماط التي تشير إلى منتج عام
    final genericPatterns = [
      'منتج تجريبي',
      'منتج افتراضي',
      RegExp(r'^منتج \d+$'), // منتج + رقم
      RegExp(r'^منتج \d+ من API$'), // منتج + رقم + من API
      RegExp(r'^منتج رقم \d+$'), // منتج رقم + رقم
      'DEFAULT-',
      'API-SKU-',
      'مورد API',
    ];

    for (final pattern in genericPatterns) {
      if (pattern is String) {
        if (product.name.contains(pattern) ||
            product.sku.contains(pattern) ||
            (product.supplier != null && product.supplier!.contains(pattern))) {
          return true;
        }
      } else if (pattern is RegExp) {
        if (pattern.hasMatch(product.name)) {
          return true;
        }
      }
    }

    // التحقق من الأوصاف العامة
    final genericDescriptions = [
      'تم إنشاؤه تلقائياً',
      'من API الخارجي',
      'منتج محمل من API',
      'وصف المنتج',
      'منتج تم إنشاؤه تلقائياً من نظام المخازن',
    ];

    for (final desc in genericDescriptions) {
      if (product.description.contains(desc)) {
        return true;
      }
    }

    // التحقق من الفئات العامة
    final genericCategories = ['عام', 'مستورد', 'غير محدد'];
    if (genericCategories.contains(product.category)) {
      return true;
    }

    return false;
  }

  /// التحقق من كون اسم المنتج عام
  bool _isGenericProductName(String productName) {
    if (productName.isEmpty) return true;
    
    final genericPatterns = [
      'منتج تجريبي',
      'منتج افتراضي',
      'منتج غير معروف',
      'منتج غير محدد',
      RegExp(r'^منتج \d+$'), // منتج + رقم
      RegExp(r'^منتج \d+ من API$'), // منتج + رقم + من API
      RegExp(r'^منتج رقم \d+$'), // منتج رقم + رقم
      RegExp(r'^Product \d+$'), // Product + number
      RegExp(r'^Product \d+ from API$'), // Product + number + from API
    ];

    for (final pattern in genericPatterns) {
      if (pattern is String) {
        if (productName.contains(pattern)) {
          return true;
        }
      } else if (pattern is RegExp) {
        if (pattern.hasMatch(productName)) {
          return true;
        }
      }
    }

    return false;
  }

  /// إحصائيات المنتجات العامة
  Future<GenericProductStats> getGenericProductStats() async {
    try {
      final response = await _supabase
          .from('products')
          .select('*')
          .eq('active', true);

      final products = (response as List<dynamic>)
          .map((json) => ProductModel.fromJson(json as Map<String, dynamic>))
          .toList();

      int genericCount = 0;
      final List<String> genericProducts = [];

      for (final product in products) {
        if (_isGenericProduct(product)) {
          genericCount++;
          genericProducts.add('${product.id}: ${product.name}');
        }
      }

      return GenericProductStats(
        totalProducts: products.length,
        genericProducts: genericCount,
        realProducts: products.length - genericCount,
        genericProductsList: genericProducts,
      );
    } catch (e) {
      AppLogger.error('❌ خطأ في الحصول على إحصائيات المنتجات: $e');
      throw Exception('فشل في الحصول على إحصائيات المنتجات: $e');
    }
  }
}

/// نتيجة عملية التنظيف
class CleanupResult {
  final int totalProducts;
  final int genericProductsFound;
  final int fixedProducts;
  final int failedProducts;
  final List<String> fixedProductsList;
  final List<String> failedProductsList;

  const CleanupResult({
    required this.totalProducts,
    required this.genericProductsFound,
    required this.fixedProducts,
    required this.failedProducts,
    required this.fixedProductsList,
    required this.failedProductsList,
  });

  double get successRate => genericProductsFound > 0 ? (fixedProducts / genericProductsFound) * 100 : 0;
}

/// إحصائيات المنتجات العامة
class GenericProductStats {
  final int totalProducts;
  final int genericProducts;
  final int realProducts;
  final List<String> genericProductsList;

  const GenericProductStats({
    required this.totalProducts,
    required this.genericProducts,
    required this.realProducts,
    required this.genericProductsList,
  });

  double get genericPercentage => totalProducts > 0 ? (genericProducts / totalProducts) * 100 : 0;
  double get realPercentage => totalProducts > 0 ? (realProducts / totalProducts) * 100 : 0;
}
