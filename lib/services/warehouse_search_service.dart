/// خدمة البحث في المخازن
/// Service for warehouse search functionality

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smartbiztracker_new/models/warehouse_search_models.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

class WarehouseSearchService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// البحث في المنتجات والفئات
  Future<WarehouseSearchResults> searchProductsAndCategories({
    required String query,
    required List<String> accessibleWarehouseIds,
    int page = 1,
    int limit = 20,
  }) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      AppLogger.info('🔍 بدء البحث في المخازن: "$query"');
      AppLogger.info('📦 المخازن المتاحة: ${accessibleWarehouseIds.length}');

      if (query.length < 2) {
        AppLogger.info('⚠️ استعلام البحث قصير جداً: ${query.length} أحرف');
        return WarehouseSearchResults.empty(query);
      }

      if (accessibleWarehouseIds.isEmpty) {
        AppLogger.warning('⚠️ لا توجد مخازن متاحة للبحث');
        return WarehouseSearchResults.empty(query);
      }

      // البحث في المنتجات
      final productResults = await _searchProducts(
        query: query,
        accessibleWarehouseIds: accessibleWarehouseIds,
        page: page,
        limit: limit,
      );

      // البحث في الفئات
      final categoryResults = await _searchCategories(
        query: query,
        accessibleWarehouseIds: accessibleWarehouseIds,
        page: page,
        limit: limit,
      );

      stopwatch.stop();
      final searchDuration = stopwatch.elapsed;

      AppLogger.info('✅ اكتمل البحث في ${searchDuration.inMilliseconds}ms');
      AppLogger.info('📊 النتائج: ${productResults.length} منتج، ${categoryResults.length} فئة');

      return WarehouseSearchResults(
        searchQuery: query,
        productResults: productResults,
        categoryResults: categoryResults,
        totalResults: productResults.length + categoryResults.length,
        searchDuration: searchDuration,
        searchTime: DateTime.now(),
        hasMore: productResults.length >= limit || categoryResults.length >= limit,
        currentPage: page,
      );
    } catch (e) {
      stopwatch.stop();
      AppLogger.error('❌ خطأ في البحث: $e');
      return WarehouseSearchResults.empty(query);
    }
  }

  /// البحث في المنتجات
  Future<List<ProductSearchResult>> _searchProducts({
    required String query,
    required List<String> accessibleWarehouseIds,
    required int page,
    required int limit,
  }) async {
    try {
      final offset = (page - 1) * limit;

      AppLogger.info('🔍 البحث في المنتجات بالاستعلام: "$query"');

      // استعلام معقد للبحث في المنتجات مع تجميع البيانات من المخازن
      // نرسل الاستعلام الخام بدون wildcards لأن دالة قاعدة البيانات تتعامل مع ذلك
      final response = await _supabase.rpc('search_warehouse_products', params: {
        'search_query': query.trim(),
        'warehouse_ids': accessibleWarehouseIds,
        'page_limit': limit,
        'page_offset': offset,
      });

      if (response == null) {
        AppLogger.warning('⚠️ لا توجد استجابة من البحث في المنتجات');
        return [];
      }

      final results = <ProductSearchResult>[];
      final responseList = response as List<dynamic>;

      for (final item in responseList) {
        try {
          final result = ProductSearchResult.fromJson(item as Map<String, dynamic>);
          results.add(result);
        } catch (e) {
          AppLogger.error('❌ خطأ في تحليل نتيجة المنتج: $e');
        }
      }

      AppLogger.info('✅ تم العثور على ${results.length} منتج');
      return results;
    } catch (e) {
      AppLogger.error('❌ خطأ في البحث عن المنتجات: $e');
      
      // Fallback to simple search if RPC fails
      return await _fallbackProductSearch(query, accessibleWarehouseIds, limit, (page - 1) * limit);
    }
  }

  /// البحث البديل في المنتجات (في حالة فشل RPC)
  Future<List<ProductSearchResult>> _fallbackProductSearch(
    String query,
    List<String> accessibleWarehouseIds,
    int limit,
    int offset,
  ) async {
    try {
      AppLogger.info('🔄 استخدام البحث البديل للمنتجات');

      // البحث في جدول warehouse_inventory مع JOIN للمخازن والمنتجات
      final response = await _supabase
          .from('warehouse_inventory')
          .select('''
            product_id,
            quantity,
            last_updated,
            warehouse_id,
            warehouses!inner(id, name, address),
            minimum_stock,
            maximum_stock
          ''')
          .inFilter('warehouse_id', accessibleWarehouseIds)
          .gt('quantity', 0)
          .order('last_updated', ascending: false);

      final results = <ProductSearchResult>[];
      final productGroups = <String, List<Map<String, dynamic>>>{};

      // تجميع النتائج حسب product_id
      for (final item in response as List<dynamic>) {
        final data = item as Map<String, dynamic>;
        final productId = data['product_id'] as String;
        
        if (!productGroups.containsKey(productId)) {
          productGroups[productId] = [];
        }
        productGroups[productId]!.add(data);
      }

      // إنشاء نتائج البحث مع جلب بيانات المنتجات الحقيقية
      for (final entry in productGroups.entries) {
        final productId = entry.key;
        final inventoryItems = entry.value;

        // جلب بيانات المنتج من جدول products
        Map<String, dynamic>? productData;
        try {
          final productResponse = await _supabase
              .from('products')
              .select('id, name, sku, description, category, main_image_url, price')
              .eq('id', productId)
              .maybeSingle();

          productData = productResponse;
        } catch (e) {
          AppLogger.warning('⚠️ لا يمكن جلب بيانات المنتج $productId: $e');
        }

        // تطبيق فلترة البحث على البيانات المجلبة
        final productName = productData?['name'] as String? ?? 'منتج $productId';
        final productSku = productData?['sku'] as String? ?? productId;
        final productDescription = productData?['description'] as String? ?? '';
        final categoryName = productData?['category'] as String? ?? 'غير محدد';

        // فحص ما إذا كان المنتج يطابق استعلام البحث
        final queryLower = query.toLowerCase();
        final matchesSearch = query.isEmpty ||
            productId.toLowerCase().contains(queryLower) ||
            productName.toLowerCase().contains(queryLower) ||
            productSku.toLowerCase().contains(queryLower) ||
            productDescription.toLowerCase().contains(queryLower) ||
            categoryName.toLowerCase().contains(queryLower);

        // إضافة المنتج فقط إذا كان يطابق البحث
        if (matchesSearch) {
          final warehouseBreakdown = inventoryItems.map((item) {
            final warehouse = item['warehouses'] as Map<String, dynamic>;
            return WarehouseInventory(
              warehouseId: item['warehouse_id'] as String,
              warehouseName: warehouse['name'] as String,
              warehouseLocation: warehouse['address'] as String?,
              quantity: item['quantity'] as int,
              stockStatus: _calculateStockStatus(
                item['quantity'] as int,
                item['minimum_stock'] as int?,
              ),
              lastUpdated: DateTime.parse(item['last_updated'] as String),
              minimumStock: item['minimum_stock'] as int?,
              maximumStock: item['maximum_stock'] as int?,
            );
          }).toList();

          final totalQuantity = warehouseBreakdown.fold<int>(
            0, (sum, w) => sum + w.quantity,
          );

          final result = ProductSearchResult(
            productId: productId,
            productName: productName,
            productSku: productSku,
            productDescription: productDescription.isNotEmpty ? productDescription : null,
            categoryName: categoryName,
            totalQuantity: totalQuantity,
            warehouseBreakdown: warehouseBreakdown,
            lastUpdated: warehouseBreakdown.isNotEmpty
                ? warehouseBreakdown.first.lastUpdated
                : DateTime.now(),
            imageUrl: productData?['main_image_url'] as String?,
            price: (productData?['price'] as num?)?.toDouble(),
          );

          results.add(result);
        }
      }

      AppLogger.info('✅ البحث البديل: تم العثور على ${results.length} منتج');
      return results;
    } catch (e) {
      AppLogger.error('❌ خطأ في البحث البديل: $e');
      return [];
    }
  }

  /// البحث في الفئات
  Future<List<CategorySearchResult>> _searchCategories({
    required String query,
    required List<String> accessibleWarehouseIds,
    required int page,
    required int limit,
  }) async {
    try {
      AppLogger.info('🔍 البحث في الفئات');

      // للآن، سنعيد قائمة فارغة حيث أن نظام الفئات يحتاج إلى تطوير إضافي
      // يمكن تطوير هذا لاحقاً عندما يتم تحديد هيكل الفئات في قاعدة البيانات
      
      return [];
    } catch (e) {
      AppLogger.error('❌ خطأ في البحث عن الفئات: $e');
      return [];
    }
  }

  /// حساب حالة المخزون
  String _calculateStockStatus(int quantity, int? minimumStock) {
    if (quantity == 0) return 'out_of_stock';
    if (minimumStock != null && quantity <= minimumStock) return 'low_stock';
    return 'in_stock';
  }

  /// الحصول على المخازن المتاحة للمستخدم
  Future<List<String>> getAccessibleWarehouseIds(String userId) async {
    try {
      AppLogger.info('🔍 جلب المخازن المتاحة للمستخدم: $userId');

      // التحقق من دور المستخدم
      final userProfile = await _supabase
          .from('user_profiles')
          .select('role')
          .eq('id', userId)
          .single();

      final userRole = userProfile['role'] as String;

      List<String> warehouseIds = [];

      if (userRole == 'admin' || userRole == 'owner' || userRole == 'accountant') {
        // المدير والمالك والمحاسب يمكنهم الوصول لجميع المخازن
        final warehouses = await _supabase
            .from('warehouses')
            .select('id')
            .eq('is_active', true);

        warehouseIds = (warehouses as List<dynamic>)
            .map((w) => w['id'] as String)
            .toList();
      } else if (userRole == 'warehouseManager') {
        // مدير المخزن يمكنه الوصول للمخازن المخصصة له فقط
        // هذا يحتاج إلى جدول warehouse_managers أو علاقة مشابهة
        final warehouses = await _supabase
            .from('warehouses')
            .select('id')
            .eq('is_active', true);

        warehouseIds = (warehouses as List<dynamic>)
            .map((w) => w['id'] as String)
            .toList();
      }

      AppLogger.info('✅ تم العثور على ${warehouseIds.length} مخزن متاح');
      return warehouseIds;
    } catch (e) {
      AppLogger.error('❌ خطأ في جلب المخازن المتاحة: $e');
      return [];
    }
  }

  /// مسح ذاكرة التخزين المؤقت للبحث
  void clearSearchCache() {
    AppLogger.info('🧹 مسح ذاكرة التخزين المؤقت للبحث');
    // يمكن إضافة منطق مسح الذاكرة المؤقتة هنا
  }
}
