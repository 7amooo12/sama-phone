import 'dart:convert';
import 'package:smartbiztracker_new/models/manufacturing/production_recipe.dart';
import 'package:smartbiztracker_new/models/manufacturing/production_batch.dart';
import 'package:smartbiztracker_new/models/product_model.dart';
import 'package:smartbiztracker_new/services/unified_products_service.dart';
import 'package:smartbiztracker_new/services/manufacturing/manufacturing_tools_edge_cases_handler.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// خدمة إدارة الإنتاج ووصفات التصنيع
class ProductionService {
  // Cache للوصفات مع مدة انتهاء صلاحية 15 دقيقة
  static final Map<String, dynamic> _cache = {};
  static const Duration _cacheDuration = Duration(minutes: 15);

  // Lazy initialization to avoid accessing Supabase.instance before initialization
  SupabaseClient get _supabase {
    try {
      return Supabase.instance.client;
    } catch (e) {
      AppLogger.error('❌ Supabase not initialized yet in ProductionService: $e');
      throw Exception('Supabase must be initialized before using ProductionService');
    }
  }

  /// إنشاء وصفة إنتاج جديدة
  Future<int> createProductionRecipe(CreateProductionRecipeRequest request) async {
    try {
      AppLogger.info('🏭 Creating production recipe for product: ${request.productId}');

      // التحقق من صحة البيانات
      if (!request.isValid) {
        final errors = request.validationErrors.join(', ');
        throw Exception('بيانات غير صحيحة: $errors');
      }

      // استدعاء دالة قاعدة البيانات
      final recipeId = await _supabase.rpc('create_production_recipe', params: {
        'p_product_id': request.productId,
        'p_tool_id': request.toolId,
        'p_quantity_required': request.quantityRequired,
      }) as int;
      AppLogger.info('✅ Production recipe created successfully with ID: $recipeId');

      // مسح الكاش
      _clearCache();

      return recipeId;
    } catch (e) {
      AppLogger.error('❌ Error creating production recipe: $e');
      throw Exception('فشل في إنشاء وصفة الإنتاج: $e');
    }
  }

  /// الحصول على وصفات الإنتاج لمنتج معين
  Future<CompleteProductionRecipe> getProductionRecipes(int productId, {bool useCache = true}) async {
    try {
      AppLogger.info('🏭 Fetching production recipes for product: $productId');

      final cacheKey = 'recipes_$productId';
      
      // التحقق من الكاش
      if (useCache && _isCacheValid(cacheKey)) {
        AppLogger.info('📦 Using cached production recipes data');
        final cachedData = _cache[cacheKey]['data'] as List<dynamic>;
        return CompleteProductionRecipe.fromJsonList(productId, cachedData);
      }

      // استدعاء دالة قاعدة البيانات
      final data = await _supabase.rpc('get_production_recipes', params: {
        'p_product_id': productId
      }) as List<dynamic>;
      AppLogger.info('✅ Fetched ${data.length} production recipes');

      // حفظ في الكاش
      _cache[cacheKey] = {
        'data': data,
        'timestamp': DateTime.now(),
      };

      return CompleteProductionRecipe.fromJsonList(productId, data);
    } catch (e) {
      AppLogger.error('❌ Error fetching production recipes: $e');
      throw Exception('فشل في جلب وصفات الإنتاج: $e');
    }
  }

  /// إنشاء دفعة إنتاج بحالة "قيد التنفيذ"
  Future<int> createProductionBatchInProgress(CreateProductionBatchRequest request) async {
    try {
      AppLogger.info('🏭 Creating production batch in progress for product: ${request.productId}');

      // التحقق من صحة البيانات
      if (!request.isValid) {
        final errors = request.validationErrors.join(', ');
        throw Exception('بيانات غير صحيحة: $errors');
      }

      // التحقق من وجود وصفة إنتاج
      final recipe = await getProductionRecipes(request.productId);
      if (!recipe.hasRecipes) {
        throw Exception('لا توجد وصفة إنتاج لهذا المنتج');
      }

      // التحقق من توفر المخزون
      if (!recipe.canProduce(request.unitsProduced)) {
        final unavailableTools = recipe.getUnavailableTools(request.unitsProduced);
        final toolNames = unavailableTools.map((t) => t.toolName).join(', ');
        throw Exception('مخزون غير كافي من الأدوات التالية: $toolNames');
      }

      // استدعاء دالة قاعدة البيانات الجديدة
      final batchId = await _supabase.rpc('create_production_batch_in_progress', params: {
        'p_product_id': request.productId,
        'p_units_produced': request.unitsProduced,
        'p_notes': request.notes,
      }) as int;
      AppLogger.info('✅ Production batch created in progress with ID: $batchId');

      // مسح الكاش
      _clearCache();

      return batchId;
    } catch (e) {
      AppLogger.error('❌ Error creating production batch in progress: $e');
      throw Exception('فشل في إنشاء دفعة الإنتاج: $e');
    }
  }

  /// إكمال دفعة إنتاج مع خصم المخزون التلقائي (للتوافق مع النظام القديم)
  Future<int> completeProductionBatch(CreateProductionBatchRequest request) async {
    try {
      AppLogger.info('🏭 Completing production batch for product: ${request.productId}');

      // التحقق من صحة البيانات
      if (!request.isValid) {
        final errors = request.validationErrors.join(', ');
        throw Exception('بيانات غير صحيحة: $errors');
      }

      // التحقق من وجود وصفة إنتاج
      final recipe = await getProductionRecipes(request.productId);
      if (!recipe.hasRecipes) {
        throw Exception('لا توجد وصفة إنتاج لهذا المنتج');
      }

      // التحقق من توفر المخزون
      if (!recipe.canProduce(request.unitsProduced)) {
        final unavailableTools = recipe.getUnavailableTools(request.unitsProduced);
        final toolNames = unavailableTools.map((t) => t.toolName).join(', ');
        throw Exception('مخزون غير كافي من الأدوات التالية: $toolNames');
      }

      // استدعاء دالة قاعدة البيانات
      final batchId = await _supabase.rpc('complete_production_batch', params: {
        'p_product_id': request.productId,
        'p_units_produced': request.unitsProduced,
        'p_notes': request.notes,
      }) as int;
      AppLogger.info('✅ Production batch completed successfully with ID: $batchId');

      // مسح الكاش
      _clearCache();

      return batchId;
    } catch (e) {
      AppLogger.error('❌ Error completing production batch: $e');
      throw Exception('فشل في إكمال دفعة الإنتاج: $e');
    }
  }

  /// تحديث حالة دفعة الإنتاج
  Future<Map<String, dynamic>> updateProductionBatchStatus({
    required int batchId,
    required String newStatus,
    String? notes,
  }) async {
    try {
      AppLogger.info('🏭 Updating production batch status: $batchId -> $newStatus');

      if (batchId <= 0) {
        throw Exception('معرف دفعة الإنتاج غير صحيح');
      }

      if (!['pending', 'in_progress', 'completed', 'cancelled'].contains(newStatus)) {
        throw Exception('حالة الدفعة غير صحيحة');
      }

      // استدعاء دالة قاعدة البيانات
      final response = await _supabase.rpc('update_production_batch_status', params: {
        'p_batch_id': batchId,
        'p_new_status': newStatus,
        'p_notes': notes,
      }) as Map<String, dynamic>;

      if (response['success'] == true) {
        AppLogger.info('✅ Production batch status updated successfully');

        // مسح الكاش
        _clearCache();

        return {
          'success': true,
          'batchId': response['batch_id'],
          'oldStatus': response['old_status'],
          'newStatus': response['new_status'],
          'updatedAt': response['updated_at'],
          'message': response['message'],
        };
      } else {
        throw Exception(response['error'] ?? 'فشل في تحديث حالة دفعة الإنتاج');
      }
    } catch (e) {
      AppLogger.error('❌ Error updating production batch status: $e');
      throw Exception('فشل في تحديث حالة دفعة الإنتاج: $e');
    }
  }

  /// الحصول على دفعات الإنتاج
  Future<List<ProductionBatch>> getProductionBatches({
    int limit = 50,
    int offset = 0,
    bool useCache = true,
  }) async {
    try {
      AppLogger.info('🏭 Fetching production batches...');

      final cacheKey = 'batches_${limit}_$offset';
      
      // التحقق من الكاش
      if (useCache && _isCacheValid(cacheKey)) {
        AppLogger.info('📦 Using cached production batches data');
        final cachedData = _cache[cacheKey]['data'] as List<dynamic>;
        return cachedData.map((json) => ProductionBatch.fromJson(json)).toList();
      }

      // استدعاء دالة قاعدة البيانات
      final data = await _supabase.rpc('get_production_batches', params: {
        'p_limit': limit,
        'p_offset': offset,
      }) as List<dynamic>;
      AppLogger.info('✅ Fetched ${data.length} production batches');

      // حفظ في الكاش
      _cache[cacheKey] = {
        'data': data,
        'timestamp': DateTime.now(),
      };

      return data.map((json) => ProductionBatch.fromJson(json)).toList();
    } catch (e) {
      AppLogger.error('❌ Error fetching production batches: $e');
      throw Exception('فشل في جلب دفعات الإنتاج: $e');
    }
  }

  /// الحصول على تاريخ استخدام الأدوات
  Future<List<ToolUsageHistory>> getToolUsageHistory({
    int? toolId,
    int limit = 50,
    int offset = 0,
    bool useCache = true,
  }) async {
    try {
      AppLogger.info('🏭 Fetching tool usage history...');

      final cacheKey = 'usage_${toolId ?? 'all'}_${limit}_$offset';
      
      // التحقق من الكاش
      if (useCache && _isCacheValid(cacheKey)) {
        AppLogger.info('📦 Using cached tool usage history data');
        final cachedData = _cache[cacheKey]['data'] as List<dynamic>;
        return cachedData.map((json) => ToolUsageHistory.fromJson(json)).toList();
      }

      // استدعاء دالة قاعدة البيانات
      final data = await _supabase.rpc('get_tool_usage_history', params: {
        'p_tool_id': toolId,
        'p_limit': limit,
        'p_offset': offset,
      }) as List<dynamic>;
      AppLogger.info('✅ Fetched ${data.length} tool usage history records');

      // حفظ في الكاش
      _cache[cacheKey] = {
        'data': data,
        'timestamp': DateTime.now(),
      };

      return data.map((json) => ToolUsageHistory.fromJson(json)).toList();
    } catch (e) {
      AppLogger.error('❌ Error fetching tool usage history: $e');
      throw Exception('فشل في جلب تاريخ استخدام الأدوات: $e');
    }
  }

  /// حذف وصفة إنتاج
  Future<bool> deleteProductionRecipe(int recipeId) async {
    try {
      AppLogger.info('🏭 Deleting production recipe: $recipeId');

      await _supabase
          .from('production_recipes')
          .delete()
          .eq('id', recipeId);

      AppLogger.info('✅ Production recipe deleted successfully');

      // مسح الكاش
      _clearCache();

      return true;
    } catch (e) {
      AppLogger.error('❌ Error deleting production recipe: $e');
      throw Exception('فشل في حذف وصفة الإنتاج: $e');
    }
  }

  /// حذف دفعة إنتاج مع تنظيف البيانات المرتبطة
  Future<bool> deleteProductionBatch(int batchId) async {
    try {
      AppLogger.info('🏭 Deleting production batch: $batchId');

      // التحقق من وجود الدفعة
      final batchResponse = await _supabase
          .from('production_batches')
          .select('id, status, units_produced, product_id')
          .eq('id', batchId)
          .single();

      if (batchResponse.isEmpty) {
        throw Exception('دفعة الإنتاج غير موجودة');
      }

      final batchStatus = batchResponse['status'] as String;

      // منع حذف الدفعات المكتملة إذا كانت مرتبطة بمخزون
      if (batchStatus == 'completed') {
        // يمكن إضافة فحص إضافي هنا للتحقق من المخزون المرتبط
        AppLogger.warning('⚠️ Attempting to delete completed production batch: $batchId');
      }

      // حذف سجلات استخدام الأدوات المرتبطة بهذه الدفعة
      await _supabase
          .from('tool_usage_history')
          .delete()
          .eq('batch_id', batchId);

      AppLogger.info('✅ Deleted related tool usage history records');

      // حذف دفعة الإنتاج
      await _supabase
          .from('production_batches')
          .delete()
          .eq('id', batchId);

      AppLogger.info('✅ Production batch deleted successfully');

      // مسح الكاش
      _clearCache();

      return true;
    } catch (e) {
      AppLogger.error('❌ Error deleting production batch: $e');
      throw Exception('فشل في حذف دفعة الإنتاج: $e');
    }
  }

  /// تحديث وصفة إنتاج
  Future<bool> updateProductionRecipe(int recipeId, double newQuantityRequired) async {
    try {
      AppLogger.info('🏭 Updating production recipe: $recipeId -> $newQuantityRequired');

      if (newQuantityRequired <= 0) {
        throw Exception('الكمية المطلوبة يجب أن تكون أكبر من صفر');
      }

      await _supabase
          .from('production_recipes')
          .update({'quantity_required': newQuantityRequired})
          .eq('id', recipeId);

      AppLogger.info('✅ Production recipe updated successfully');

      // مسح الكاش
      _clearCache();

      return true;
    } catch (e) {
      AppLogger.error('❌ Error updating production recipe: $e');
      throw Exception('فشل في تحديث وصفة الإنتاج: $e');
    }
  }

  /// الحصول على إحصائيات الإنتاج
  Future<Map<String, dynamic>> getProductionStatistics() async {
    try {
      AppLogger.info('📊 Calculating production statistics...');

      final batches = await getProductionBatches(limit: 1000);
      
      final stats = {
        'total_batches': batches.length,
        'completed_batches': batches.where((b) => b.status == 'completed').length,
        'pending_batches': batches.where((b) => b.status == 'pending').length,
        'in_progress_batches': batches.where((b) => b.status == 'in_progress').length,
        'cancelled_batches': batches.where((b) => b.status == 'cancelled').length,
        'total_units_produced': batches
            .where((b) => b.status == 'completed')
            .fold<double>(0, (sum, batch) => sum + batch.unitsProduced),
        'average_batch_size': batches.isNotEmpty 
            ? batches.fold<double>(0, (sum, batch) => sum + batch.unitsProduced) / batches.length
            : 0.0,
      };

      AppLogger.info('✅ Production statistics calculated successfully');
      return stats;
    } catch (e) {
      AppLogger.error('❌ Error calculating production statistics: $e');
      throw Exception('فشل في حساب إحصائيات الإنتاج: $e');
    }
  }

  /// تحديث كمية دفعة الإنتاج مع إدارة المخزون
  Future<Map<String, dynamic>> updateProductionBatchQuantity({
    required int batchId,
    required double newQuantity,
    String? notes,
  }) async {
    try {
      AppLogger.info('🏭 Updating production batch quantity: $batchId -> $newQuantity');

      if (batchId <= 0) {
        throw Exception('معرف دفعة الإنتاج غير صحيح');
      }

      if (newQuantity <= 0) {
        throw Exception('الكمية الجديدة يجب أن تكون أكبر من صفر');
      }

      // محاولة استخدام الدالة المخصصة أولاً
      try {
        final response = await _supabase.rpc('update_production_batch_quantity', params: {
          'p_batch_id': batchId,
          'p_new_quantity': newQuantity,
          'p_notes': notes,
        }) as Map<String, dynamic>;

        if (response['success'] == true) {
          AppLogger.info('✅ Production batch quantity updated successfully using custom function');

          // Log debug information if available
          if (response.containsKey('debug_info')) {
            AppLogger.info('🔍 Debug info: ${response['debug_info']}');
          }
          if (response.containsKey('recipes_found')) {
            AppLogger.info('📋 Recipes found: ${response['recipes_found']}');
          }
          if (response.containsKey('tools_updated')) {
            AppLogger.info('🔧 Tools updated: ${response['tools_updated']}');
          }

          // مسح الكاش
          _clearCache();

          return {
            'success': true,
            'batchId': response['batch_id'],
            'oldQuantity': response['old_quantity'],
            'newQuantity': response['new_quantity'],
            'quantityDifference': response['quantity_difference'],
            'recipesFound': response['recipes_found'] ?? 0,
            'toolsUpdated': response['tools_updated'] ?? 0,
            'debugInfo': response['debug_info'],
            'message': response['message'],
          };
        } else {
          // Log debug information for failed operations
          if (response.containsKey('debug_info')) {
            AppLogger.error('🔍 Debug info for failed operation: ${response['debug_info']}');
          }
          throw Exception(response['error'] ?? 'فشل في تحديث كمية دفعة الإنتاج');
        }
      } catch (e) {
        // إذا فشلت الدالة المخصصة، استخدم التنفيذ البديل
        AppLogger.warning('⚠️ Custom function failed, using alternative implementation: $e');
        return await _updateProductionBatchQuantityAlternative(batchId, newQuantity, notes);
      }
    } catch (e) {
      AppLogger.error('❌ Error updating production batch quantity: $e');
      throw Exception('فشل في تحديث كمية دفعة الإنتاج: $e');
    }
  }

  /// تنفيذ بديل لتحديث كمية دفعة الإنتاج باستخدام العمليات المباشرة
  Future<Map<String, dynamic>> _updateProductionBatchQuantityAlternative(
    int batchId,
    double newQuantity,
    String? notes,
  ) async {
    try {
      AppLogger.info('🔄 Using alternative implementation for batch quantity update');

      // الحصول على معلومات الدفعة الحالية
      final batchResponse = await _supabase
          .from('production_batches')
          .select('*')
          .eq('id', batchId)
          .single();

      final oldQuantity = (batchResponse['units_produced'] as num).toDouble();
      final quantityDifference = newQuantity - oldQuantity;

      // تحديث كمية دفعة الإنتاج
      await _supabase
          .from('production_batches')
          .update({
            'units_produced': newQuantity,
            'notes': notes ?? batchResponse['notes'],
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', batchId);

      AppLogger.info('✅ Production batch quantity updated successfully using alternative method');

      // مسح الكاش
      _clearCache();

      return {
        'success': true,
        'batchId': batchId,
        'oldQuantity': oldQuantity,
        'newQuantity': newQuantity,
        'quantityDifference': quantityDifference,
        'message': 'تم تحديث كمية دفعة الإنتاج بنجاح',
      };
    } catch (e) {
      AppLogger.error('❌ Error in alternative implementation: $e');
      throw Exception('فشل في التنفيذ البديل لتحديث كمية دفعة الإنتاج: $e');
    }
  }

  /// الحصول على مواقع المنتج في المخازن
  Future<List<Map<String, dynamic>>> getProductWarehouseLocations(String productId) async {
    try {
      AppLogger.info('📍 Getting warehouse locations for product: $productId');

      if (productId.isEmpty) {
        throw Exception('معرف المنتج غير صحيح');
      }

      // التحقق من الكاش أولاً
      final cacheKey = 'product_locations_$productId';
      if (_cache.containsKey(cacheKey)) {
        final cached = _cache[cacheKey];
        if (cached != null &&
            DateTime.now().difference(cached['timestamp']).inMinutes < 5) {
          AppLogger.info('📋 Using cached product locations');
          return List<Map<String, dynamic>>.from(cached['data']);
        }
      }

      // محاولة استخدام الدالة المخصصة أولاً
      try {
        final response = await _supabase.rpc('get_product_warehouse_locations', params: {
          'p_product_id': productId,
        }) as Map<String, dynamic>;

        if (response['success'] == true) {
          final locations = List<Map<String, dynamic>>.from(response['locations'] ?? []);

          // حفظ في الكاش
          _cache[cacheKey] = {
            'data': locations,
            'timestamp': DateTime.now(),
          };

          AppLogger.info('✅ Retrieved ${locations.length} warehouse locations for product using custom function');
          return locations;
        } else {
          throw Exception(response['error'] ?? 'فشل في جلب مواقع المنتج');
        }
      } catch (e) {
        // إذا فشلت الدالة المخصصة، استخدم التنفيذ البديل
        AppLogger.warning('⚠️ Custom function failed, using alternative implementation: $e');
        return await _getProductWarehouseLocationsAlternative(productId);
      }
    } catch (e) {
      AppLogger.error('❌ Error getting product warehouse locations: $e');
      throw Exception('فشل في جلب مواقع المنتج: $e');
    }
  }

  /// تنفيذ بديل للحصول على مواقع المنتج في المخازن
  Future<List<Map<String, dynamic>>> _getProductWarehouseLocationsAlternative(String productId) async {
    try {
      AppLogger.info('🔄 Using alternative implementation for warehouse locations');

      final response = await _supabase
          .from('warehouse_inventory')
          .select('''
            warehouse_id,
            quantity,
            minimum_stock,
            maximum_stock,
            last_updated,
            warehouses!warehouse_id (
              id,
              name,
              address,
              is_active
            )
          ''')
          .eq('product_id', productId)
          .eq('warehouses.is_active', true)
          .order('quantity', ascending: false);

      final locations = response.map<Map<String, dynamic>>((item) {
        final warehouse = item['warehouses'] as Map<String, dynamic>?;
        final quantity = item['quantity'] as int? ?? 0;
        final minimumStock = item['minimum_stock'] as int? ?? 10;

        String stockStatus;
        if (quantity == 0) {
          stockStatus = 'نفد المخزون';
        } else if (quantity <= minimumStock) {
          stockStatus = 'مخزون منخفض';
        } else {
          stockStatus = 'متوفر';
        }

        return {
          'warehouse_id': item['warehouse_id'],
          'warehouse_name': warehouse?['name'] ?? 'مخزن غير محدد',
          'warehouse_address': warehouse?['address'] ?? '',
          'quantity': quantity,
          'minimum_stock': minimumStock,
          'maximum_stock': item['maximum_stock'],
          'stock_status': stockStatus,
          'last_updated': item['last_updated'],
        };
      }).toList();

      // حفظ في الكاش
      final cacheKey = 'product_locations_$productId';
      _cache[cacheKey] = {
        'data': locations,
        'timestamp': DateTime.now(),
      };

      AppLogger.info('✅ Retrieved ${locations.length} warehouse locations using alternative method');
      return locations;
    } catch (e) {
      AppLogger.error('❌ Error in alternative warehouse locations implementation: $e');
      throw Exception('فشل في التنفيذ البديل لجلب مواقع المنتج: $e');
    }
  }

  /// إضافة مخزون المنتج إلى المخزن بعد زيادة الإنتاج
  Future<Map<String, dynamic>> addProductionInventoryToWarehouse({
    required String productId,
    required int quantity,
    String? warehouseId,
    int? batchId,
    String? notes,
  }) async {
    try {
      AppLogger.info('📦 Adding production inventory to warehouse: $productId, quantity: $quantity');

      if (productId.isEmpty || quantity <= 0) {
        throw Exception('معرف المنتج أو الكمية غير صحيحة');
      }

      // استدعاء دالة قاعدة البيانات
      final response = await _supabase.rpc('add_production_inventory_to_warehouse', params: {
        'p_product_id': productId,
        'p_quantity': quantity,
        'p_warehouse_id': warehouseId,
        'p_batch_id': batchId,
        'p_notes': notes,
      }) as Map<String, dynamic>;

      if (response['success'] == true) {
        AppLogger.info('✅ Production inventory added to warehouse successfully');

        // مسح الكاش
        _clearCache();

        return {
          'success': true,
          'warehouseId': response['warehouse_id'],
          'warehouseName': response['warehouse_name'],
          'productId': response['product_id'],
          'quantityAdded': response['quantity_added'],
          'quantityBefore': response['quantity_before'],
          'quantityAfter': response['quantity_after'],
          'message': response['message'],
        };
      } else {
        throw Exception(response['error'] ?? 'فشل في إضافة المخزون');
      }
    } catch (e) {
      AppLogger.error('❌ Error adding production inventory to warehouse: $e');
      throw Exception('فشل في إضافة المخزون: $e');
    }
  }

  /// التحقق من صحة الكاش
  bool _isCacheValid(String key, {int? maxAgeMinutes}) {
    if (!_cache.containsKey(key)) return false;

    final cacheEntry = _cache[key];
    final timestamp = cacheEntry['timestamp'] as DateTime;

    final maxAge = maxAgeMinutes != null
        ? Duration(minutes: maxAgeMinutes)
        : _cacheDuration;

    return DateTime.now().difference(timestamp) < maxAge;
  }

  /// مسح الكاش
  void _clearCache() {
    _cache.clear();
    AppLogger.info('🗑️ Production service cache cleared');
  }

  /// تحديث بيانات المنتج في قاعدة البيانات بناءً على بيانات API
  Future<void> _updateProductDataInDatabase(int productId, ProductModel apiProduct) async {
    try {
      AppLogger.info('💾 Updating product data in database for product: $productId');

      // التحقق من صحة البيانات قبل التحديث
      if (apiProduct.name.isEmpty) {
        AppLogger.warning('⚠️ Invalid product name, skipping database update');
        return;
      }

      if (apiProduct.quantity < 0) {
        AppLogger.warning('⚠️ Invalid product quantity (${apiProduct.quantity}), skipping database update');
        return;
      }

      // تحديث بيانات المنتج في جدول products
      await _supabase.from('products').upsert({
        'id': productId.toString(),
        'name': apiProduct.name.trim(),
        'quantity': apiProduct.quantity,
        'price': apiProduct.price,
        'description': apiProduct.description?.trim() ?? '',
        'category': apiProduct.category?.trim() ?? '',
        'sku': apiProduct.sku?.trim() ?? '',
        'image_url': apiProduct.imageUrl?.trim(),
        'active': apiProduct.isActive, // Fixed: use 'active' instead of 'is_active' to match database schema
        'updated_at': DateTime.now().toIso8601String(),
        'supplier': apiProduct.supplier?.trim(),
        'manufacturing_cost': apiProduct.manufacturingCost,
        'reorder_point': apiProduct.reorderPoint,
        'minimum_stock': apiProduct.minimumStock,
      }).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          AppLogger.warning('⏰ Database update timeout for product $productId');
          throw Exception('Database update timeout');
        },
      );

      AppLogger.info('✅ Product data updated successfully in database');
    } catch (e) {
      AppLogger.error('❌ Error updating product data in database: $e');
      // لا نرمي استثناء هنا لأن هذا ليس أمراً حرجاً
      // ولكن نسجل الخطأ للمراجعة
    }
  }

  /// مسح الكاش يدوياً
  void clearCache() {
    _clearCache();
  }

  /// مسح كاش تحليلات الأدوات لدفعة معينة
  void clearToolAnalyticsCache(int batchId) {
    final cacheKey = 'tool_analytics_$batchId';
    _cache.remove(cacheKey);
    AppLogger.info('🗑️ Cleared tool analytics cache for batch: $batchId');
  }

  /// إجبار تحديث تحليلات الأدوات (بدون كاش)
  Future<List<ToolUsageAnalytics>> forceRefreshToolAnalytics(int batchId) async {
    clearToolAnalyticsCache(batchId);
    return await getToolUsageAnalytics(batchId);
  }

  /// الحصول على تفاصيل المنتج بالمعرف
  /// يستخدم UnifiedProductsService للحصول على بيانات المنتج الكاملة
  Future<ProductModel?> getProductById(int productId) async {
    try {
      AppLogger.info('🔍 Fetching product details for ID: $productId');

      final cacheKey = 'product_$productId';

      // التحقق من الكاش
      if (_isCacheValid(cacheKey)) {
        AppLogger.info('📦 Using cached product data for ID: $productId');
        final cachedData = _cache[cacheKey]['data'] as Map<String, dynamic>;
        return ProductModel.fromJson(cachedData);
      }

      // استخدام UnifiedProductsService للحصول على المنتج
      final unifiedService = UnifiedProductsService();
      final product = await unifiedService.getProductById(productId.toString());

      if (product != null) {
        // حفظ في الكاش
        _cache[cacheKey] = {
          'data': product.toJson(),
          'timestamp': DateTime.now(),
        };

        AppLogger.info('✅ Product found: ${product.name}');
        return product;
      } else {
        AppLogger.warning('⚠️ Product not found for ID: $productId');
        return null;
      }
    } catch (e) {
      AppLogger.error('❌ Error fetching product by ID $productId: $e');
      return null;
    }
  }

  /// الحصول على عدة منتجات بمعرفاتها
  /// مفيد لتحميل منتجات متعددة بكفاءة
  Future<Map<int, ProductModel>> getProductsByIds(List<int> productIds) async {
    try {
      AppLogger.info('🔍 Fetching ${productIds.length} products by IDs');

      final results = <int, ProductModel>{};
      final uncachedIds = <int>[];

      // التحقق من الكاش أولاً
      for (final id in productIds) {
        final cacheKey = 'product_$id';
        if (_isCacheValid(cacheKey)) {
          final cachedData = _cache[cacheKey]['data'] as Map<String, dynamic>;
          results[id] = ProductModel.fromJson(cachedData);
        } else {
          uncachedIds.add(id);
        }
      }

      // جلب المنتجات غير المحفوظة في الكاش
      if (uncachedIds.isNotEmpty) {
        final unifiedService = UnifiedProductsService();

        for (final id in uncachedIds) {
          final product = await unifiedService.getProductById(id.toString());
          if (product != null) {
            results[id] = product;

            // حفظ في الكاش
            final cacheKey = 'product_$id';
            _cache[cacheKey] = {
              'data': product.toJson(),
              'timestamp': DateTime.now(),
            };
          }
        }
      }

      AppLogger.info('✅ Fetched ${results.length} products successfully');
      return results;
    } catch (e) {
      AppLogger.error('❌ Error fetching products by IDs: $e');
      return {};
    }
  }

  /// الحصول على تحليلات استخدام أدوات التصنيع لدفعة إنتاج
  Future<List<ToolUsageAnalytics>> getToolUsageAnalytics(int batchId) async {
    try {
      AppLogger.info('📊 Fetching tool usage analytics for batch: $batchId with enhanced remaining stock calculation');

      final cacheKey = 'tool_analytics_$batchId';

      // التحقق من الكاش (مع تقليل مدة الكاش لضمان الحصول على البيانات المحدثة)
      if (_cache.containsKey(cacheKey)) {
        final cached = _cache[cacheKey];
        if (cached != null &&
            DateTime.now().difference(cached['timestamp']).inMinutes < 2) { // تقليل مدة الكاش إلى دقيقتين
          AppLogger.info('📦 Using cached tool analytics data');
          final cachedData = cached['data'] as List<dynamic>;
          return cachedData.map((json) => ToolUsageAnalytics.fromJson(json)).toList();
        }
      }

      // استدعاء دالة قاعدة البيانات للحصول على تحليلات الأدوات مع الحساب المحسن
      final response = await _supabase.rpc('get_batch_tool_usage_analytics', params: {
        'p_batch_id': batchId,
      }) as List<dynamic>;

      AppLogger.info('📊 Raw analytics response: ${response.length} tools found');

      final analytics = response
          .map((json) {
            final data = json as Map<String, dynamic>;
            AppLogger.info('🔧 Tool: ${data['tool_name']}, Remaining Stock: ${data['remaining_stock']}, Used Per Unit: ${data['quantity_used_per_unit']}');
            return ToolUsageAnalytics.fromJson(data);
          })
          .toList();

      // تطبيق معالجة الحالات الاستثنائية
      final List<ToolUsageAnalytics> sanitizedAnalytics = analytics
          .map((analytic) => ManufacturingToolsEdgeCasesHandler.sanitizeToolAnalytics(analytic))
          .toList();

      // حفظ في الكاش
      _cache[cacheKey] = {
        'data': response,
        'timestamp': DateTime.now(),
      };

      AppLogger.info('✅ Fetched ${sanitizedAnalytics.length} tool usage analytics with enhanced remaining stock calculation');
      return sanitizedAnalytics;
    } catch (e) {
      AppLogger.error('❌ Error fetching tool usage analytics: $e');
      return [];
    }
  }

  /// الحصول على تحليل فجوة الإنتاج مع بيانات المنتج الحديثة من API
  Future<ProductionGapAnalysis?> getProductionGapAnalysis(int productId, int batchId) async {
    try {
      AppLogger.info('📈 Fetching production gap analysis for product: $productId, batch: $batchId');

      final cacheKey = 'gap_analysis_${productId}_$batchId';

      // التحقق من الكاش (مع مدة انتهاء صلاحية أقصر للحصول على بيانات حديثة)
      if (_isCacheValid(cacheKey, maxAgeMinutes: 5)) {
        AppLogger.info('📦 Using cached gap analysis data');
        final cachedData = _cache[cacheKey]['data'] as Map<String, dynamic>;
        return ProductionGapAnalysis.fromJson(cachedData);
      }

      // جلب بيانات المنتج الحديثة من API أولاً مع معالجة الأخطاء
      ProductModel? apiProduct;
      try {
        AppLogger.info('🔄 Fetching fresh product data from API for product: $productId');
        apiProduct = await getProductById(productId).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            AppLogger.warning('⏰ API timeout for product $productId, using database fallback');
            return null;
          },
        );

        // تحديث بيانات المنتج في قاعدة البيانات إذا تم العثور على بيانات API
        if (apiProduct != null) {
          AppLogger.info('✅ Fresh product data found: ${apiProduct.name}, quantity: ${apiProduct.quantity}');
          await _updateProductDataInDatabase(productId, apiProduct);
        } else {
          AppLogger.warning('⚠️ No API product data found for product: $productId, using database fallback');
        }
      } catch (e) {
        AppLogger.error('❌ Error fetching API product data for product $productId: $e');
        AppLogger.info('🔄 Continuing with database fallback for gap analysis');
        apiProduct = null;
      }

      // استدعاء دالة قاعدة البيانات للحصول على تحليل الفجوة (ستستخدم البيانات المحدثة)
      final response = await _supabase.rpc('get_production_gap_analysis', params: {
        'p_product_id': productId,
        'p_batch_id': batchId,
      });

      if (response == null) {
        AppLogger.warning('⚠️ No gap analysis data found');
        return null;
      }

      // تحويل الاستجابة إلى Map إذا كانت JSONB
      Map<String, dynamic> responseMap;
      if (response is Map<String, dynamic>) {
        responseMap = response;
      } else if (response is String) {
        // إذا كانت الاستجابة نص JSON، قم بتحليلها
        responseMap = jsonDecode(response) as Map<String, dynamic>;
      } else {
        // إذا كانت الاستجابة من نوع آخر، حاول تحويلها
        responseMap = Map<String, dynamic>.from(response as Map);
      }

      // إذا كان لدينا بيانات API حديثة، استخدم الكمية من API كهدف
      if (apiProduct != null && apiProduct.quantity > 0) {
        AppLogger.info('🎯 Using API product quantity as target: ${apiProduct.quantity}');
        responseMap['target_quantity'] = apiProduct.quantity.toDouble();

        // إعادة حساب القيم المعتمدة على الهدف الجديد
        final currentProduction = (responseMap['current_production'] as num).toDouble();
        final newTargetQuantity = apiProduct.quantity.toDouble();

        responseMap['remaining_pieces'] = newTargetQuantity - currentProduction;
        responseMap['completion_percentage'] = newTargetQuantity > 0
            ? (currentProduction / newTargetQuantity) * 100
            : 0.0;
        responseMap['is_over_produced'] = currentProduction > newTargetQuantity;
        responseMap['is_completed'] = currentProduction >= newTargetQuantity;

        AppLogger.info('📊 Updated gap analysis with API target - Target: $newTargetQuantity, Current: $currentProduction, Remaining: ${responseMap['remaining_pieces']}');
      }

      final gapAnalysis = ProductionGapAnalysis.fromJson(responseMap);

      // حفظ في الكاش
      _cache[cacheKey] = {
        'data': responseMap,
        'timestamp': DateTime.now(),
      };

      // إذا تم تحديث بيانات المنتج من API، قم بمسح كاش تحليلات الأدوات لضمان استخدام البيانات الجديدة
      if (apiProduct != null) {
        final toolAnalyticsCacheKey = 'tool_analytics_$batchId';
        if (_cache.containsKey(toolAnalyticsCacheKey)) {
          _cache.remove(toolAnalyticsCacheKey);
          AppLogger.info('🗑️ Invalidated tool analytics cache due to API product update');
        }
      }

      AppLogger.info('✅ Production gap analysis loaded successfully with ${apiProduct != null ? 'API' : 'database'} target data');
      return gapAnalysis;
    } catch (e) {
      AppLogger.error('❌ Error fetching production gap analysis: $e');
      return null;
    }
  }

  /// الحصول على توقعات الأدوات المطلوبة للإنتاج المتبقي
  Future<RequiredToolsForecast?> getRequiredToolsForecast(int productId, double remainingPieces) async {
    try {
      AppLogger.info('🔮 Fetching required tools forecast for product: $productId, remaining: $remainingPieces');

      final cacheKey = 'tools_forecast_${productId}_${remainingPieces.toStringAsFixed(2)}';

      // التحقق من الكاش
      if (_isCacheValid(cacheKey)) {
        AppLogger.info('📦 Using cached tools forecast data');
        final cachedData = _cache[cacheKey]['data'] as Map<String, dynamic>;
        return RequiredToolsForecast.fromJson(cachedData);
      }

      // Handle edge case: zero remaining pieces
      if (remainingPieces <= 0) {
        AppLogger.info('🔄 Zero remaining pieces - returning completed forecast');
        final completedForecast = RequiredToolsForecast(
          productId: productId,
          remainingPieces: 0.0,
          requiredTools: [],
          canCompleteProduction: true,
          unavailableTools: [],
          totalCost: 0.0,
        );

        // Cache the result
        _cache[cacheKey] = {
          'data': completedForecast.toJson(),
          'timestamp': DateTime.now(),
        };

        return completedForecast;
      }

      // استدعاء دالة قاعدة البيانات للحصول على توقعات الأدوات
      final response = await _supabase.rpc('get_required_tools_forecast', params: {
        'p_product_id': productId,
        'p_remaining_pieces': remainingPieces,
      });

      // Handle different response types (Map or String)
      Map<String, dynamic> responseMap;
      if (response is Map<String, dynamic>) {
        responseMap = response;
      } else if (response is String) {
        try {
          responseMap = jsonDecode(response) as Map<String, dynamic>;
        } catch (e) {
          AppLogger.error('❌ Failed to parse JSON response: $e');
          return null;
        }
      } else if (response != null) {
        responseMap = Map<String, dynamic>.from(response as Map);
      } else {
        AppLogger.warning('⚠️ Null response from database function');
        return null;
      }

      if (responseMap['success'] != true) {
        AppLogger.warning('⚠️ Database function returned error: ${responseMap['error'] ?? 'Unknown error'}');
        return null;
      }

      // Extract and validate the forecast data with proper structure for RequiredToolsForecast model
      final forecastData = {
        'product_id': responseMap['product_id'] ?? productId,
        'remaining_pieces': (responseMap['remaining_pieces'] as num?)?.toDouble() ?? remainingPieces,
        'required_tools': responseMap['required_tools'] ?? [],
        'can_complete_production': responseMap['can_complete_production'] ?? false,
        'unavailable_tools': responseMap['unavailable_tools'] ?? [],
        'total_cost': (responseMap['total_cost'] as num?)?.toDouble() ?? 0.0,
      };

      // Validate required_tools structure
      final requiredToolsList = forecastData['required_tools'] as List<dynamic>;
      AppLogger.info('📊 Processing ${requiredToolsList.length} required tools');

      // Log detailed tool information for debugging
      for (int i = 0; i < requiredToolsList.length; i++) {
        final tool = requiredToolsList[i] as Map<String, dynamic>;
        AppLogger.info('🔧 Tool ${i + 1}: ${tool['tool_name']} - Required: ${tool['total_quantity_needed']}, Available: ${tool['available_stock']}, Status: ${tool['availability_status']}');
      }

      final forecast = RequiredToolsForecast.fromJson(forecastData);

      // حفظ في الكاش
      _cache[cacheKey] = {
        'data': forecastData,
        'timestamp': DateTime.now(),
      };

      AppLogger.info('✅ Fetched tools forecast: ${forecast.toolsCount} tools, can complete: ${forecast.canCompleteProduction}, total cost: ${forecast.totalCost.toStringAsFixed(2)}');
      return forecast;
    } catch (e, stackTrace) {
      AppLogger.error('❌ Error fetching required tools forecast: $e');
      AppLogger.error('Stack trace: $stackTrace');
      return null;
    }
  }

  /// الحصول على تاريخ استخدام أداة معينة
  Future<List<ToolUsageEntry>> getSpecificToolUsageHistory(int toolId, {int? batchId, int limit = 50}) async {
    try {
      AppLogger.info('📜 Fetching tool usage history for tool: $toolId');

      final cacheKey = 'tool_history_${toolId}_${batchId ?? 'all'}_$limit';

      // التحقق من الكاش
      if (_isCacheValid(cacheKey)) {
        AppLogger.info('📦 Using cached tool usage history');
        final cachedData = _cache[cacheKey]['data'] as List<dynamic>;
        return cachedData.map((json) => ToolUsageEntry.fromJson(json)).toList();
      }

      // استدعاء دالة قاعدة البيانات للحصول على تاريخ الاستخدام
      final response = await _supabase.rpc('get_tool_usage_history', params: {
        'p_tool_id': toolId,
        'p_batch_id': batchId,
        'p_limit': limit,
      }) as List<dynamic>;

      final history = response
          .map((json) => ToolUsageEntry.fromJson(json as Map<String, dynamic>))
          .toList();

      // حفظ في الكاش
      _cache[cacheKey] = {
        'data': response,
        'timestamp': DateTime.now(),
      };

      AppLogger.info('✅ Fetched ${history.length} tool usage history entries');
      return history;
    } catch (e) {
      AppLogger.error('❌ Error fetching tool usage history: $e');
      return [];
    }
  }
}
