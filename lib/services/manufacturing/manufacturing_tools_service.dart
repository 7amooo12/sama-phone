import 'package:smartbiztracker_new/models/manufacturing/manufacturing_tool.dart';
import 'package:smartbiztracker_new/models/manufacturing/tool_deletion_info.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// خدمة إدارة أدوات التصنيع مع تتبع المخزون والأداء المحسن
class ManufacturingToolsService {
  // Cache للأدوات مع مدة انتهاء صلاحية 15 دقيقة
  static final Map<String, dynamic> _cache = {};
  static const Duration _cacheDuration = Duration(minutes: 15);

  // Lazy initialization to avoid accessing Supabase.instance before initialization
  SupabaseClient get _supabase {
    try {
      return Supabase.instance.client;
    } catch (e) {
      AppLogger.error('❌ Supabase not initialized yet in ManufacturingToolsService: $e');
      throw Exception('Supabase must be initialized before using ManufacturingToolsService');
    }
  }

  /// الحصول على جميع أدوات التصنيع مع المخزون الحالي
  Future<List<ManufacturingTool>> getAllTools({bool useCache = true}) async {
    try {
      AppLogger.info('🔧 Fetching all manufacturing tools...');
      
      // التحقق من الكاش
      if (useCache && _isCacheValid('all_tools')) {
        AppLogger.info('📦 Using cached manufacturing tools data');
        final cachedData = _cache['all_tools']['data'] as List<dynamic>;
        return cachedData.map((json) => ManufacturingTool.fromJson(json)).toList();
      }

      // استدعاء دالة قاعدة البيانات
      final data = await _supabase.rpc('get_manufacturing_tools') as List<dynamic>;
      AppLogger.info('✅ Fetched ${data.length} manufacturing tools');

      // حفظ في الكاش
      _cache['all_tools'] = {
        'data': data,
        'timestamp': DateTime.now(),
      };

      return data.map((json) => ManufacturingTool.fromJson(json)).toList();
    } catch (e) {
      AppLogger.error('❌ Error fetching manufacturing tools: $e');
      throw Exception('فشل في جلب أدوات التصنيع: $e');
    }
  }

  /// إضافة أداة تصنيع جديدة
  Future<int> addTool(CreateManufacturingToolRequest request) async {
    try {
      AppLogger.info('🔧 Adding new manufacturing tool: ${request.name}');

      // التحقق من صحة البيانات
      if (!request.isValid) {
        final errors = request.validationErrors.join(', ');
        throw Exception('بيانات غير صحيحة: $errors');
      }

      // استدعاء دالة قاعدة البيانات
      final toolId = await _supabase.rpc('add_manufacturing_tool', params: {
        'p_name': request.name.trim(),
        'p_quantity': request.quantity,
        'p_unit': request.unit.trim(),
        'p_color': request.color,
        'p_size': request.size,
        'p_image_url': request.imageUrl,
      }) as int;
      AppLogger.info('✅ Manufacturing tool added successfully with ID: $toolId');

      // مسح الكاش
      _clearCache();

      return toolId;
    } catch (e) {
      AppLogger.error('❌ Error adding manufacturing tool: $e');
      throw Exception('فشل في إضافة أداة التصنيع: $e');
    }
  }

  /// تحديث كمية الأداة
  Future<bool> updateToolQuantity(UpdateToolQuantityRequest request) async {
    try {
      AppLogger.info('🔧 Updating tool quantity: ${request.toolId} -> ${request.newQuantity}');

      // التحقق من صحة البيانات
      if (!request.isValid) {
        throw Exception('بيانات غير صحيحة');
      }

      // استدعاء دالة قاعدة البيانات
      final success = await _supabase.rpc('update_tool_quantity', params: {
        'p_tool_id': request.toolId,
        'p_new_quantity': request.newQuantity,
        'p_operation_type': request.operationType,
        'p_notes': request.notes,
        'p_batch_id': request.batchId,
      }) as bool;
      AppLogger.info('✅ Tool quantity updated successfully');

      // مسح الكاش
      _clearCache();

      return success;
    } catch (e) {
      AppLogger.error('❌ Error updating tool quantity: $e');
      throw Exception('فشل في تحديث كمية الأداة: $e');
    }
  }

  /// الحصول على أداة واحدة بالمعرف
  Future<ManufacturingTool?> getToolById(int toolId) async {
    try {
      AppLogger.info('🔧 Fetching tool by ID: $toolId');

      final tools = await getAllTools();
      final tool = tools.where((t) => t.id == toolId).firstOrNull;

      if (tool != null) {
        AppLogger.info('✅ Tool found: ${tool.name}');
      } else {
        AppLogger.warning('⚠️ Tool not found with ID: $toolId');
      }

      return tool;
    } catch (e) {
      AppLogger.error('❌ Error fetching tool by ID: $e');
      throw Exception('فشل في جلب الأداة: $e');
    }
  }

  /// البحث في الأدوات
  Future<List<ManufacturingTool>> searchTools(String query) async {
    try {
      AppLogger.info('🔍 Searching tools with query: $query');

      if (query.trim().isEmpty) {
        return await getAllTools();
      }

      final tools = await getAllTools();
      final searchQuery = query.trim().toLowerCase();

      final filteredTools = tools.where((tool) {
        return tool.name.toLowerCase().contains(searchQuery) ||
               tool.unit.toLowerCase().contains(searchQuery) ||
               (tool.color?.toLowerCase().contains(searchQuery) ?? false) ||
               (tool.size?.toLowerCase().contains(searchQuery) ?? false);
      }).toList();

      AppLogger.info('✅ Found ${filteredTools.length} tools matching query');
      return filteredTools;
    } catch (e) {
      AppLogger.error('❌ Error searching tools: $e');
      throw Exception('فشل في البحث عن الأدوات: $e');
    }
  }

  /// الحصول على الأدوات حسب حالة المخزون
  Future<List<ManufacturingTool>> getToolsByStockStatus(String status) async {
    try {
      AppLogger.info('🔧 Fetching tools by stock status: $status');

      final tools = await getAllTools();
      final filteredTools = tools.where((tool) => tool.stockStatus == status).toList();

      AppLogger.info('✅ Found ${filteredTools.length} tools with status: $status');
      return filteredTools;
    } catch (e) {
      AppLogger.error('❌ Error fetching tools by stock status: $e');
      throw Exception('فشل في جلب الأدوات حسب حالة المخزون: $e');
    }
  }

  /// الحصول على الأدوات منخفضة المخزون
  Future<List<ManufacturingTool>> getLowStockTools() async {
    try {
      AppLogger.info('🔧 Fetching low stock tools...');

      final tools = await getAllTools();
      final lowStockTools = tools.where((tool) {
        return tool.stockStatus == 'orange' || tool.stockStatus == 'red';
      }).toList();

      AppLogger.info('✅ Found ${lowStockTools.length} low stock tools');
      return lowStockTools;
    } catch (e) {
      AppLogger.error('❌ Error fetching low stock tools: $e');
      throw Exception('فشل في جلب الأدوات منخفضة المخزون: $e');
    }
  }

  /// تحديث المخزون الأولي للأداة
  Future<bool> updateInitialStock(int toolId, double initialStock) async {
    try {
      AppLogger.info('🔧 Updating initial stock for tool: $toolId -> $initialStock');

      await _supabase
          .from('manufacturing_tools')
          .update({'initial_stock': initialStock, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', toolId);

      AppLogger.info('✅ Initial stock updated successfully');

      // مسح الكاش
      _clearCache();

      return true;
    } catch (e) {
      AppLogger.error('❌ Error updating initial stock: $e');
      throw Exception('فشل في تحديث المخزون الأولي: $e');
    }
  }

  /// التحقق من إمكانية حذف أداة التصنيع (للاستخدام الداخلي فقط)
  Future<ToolDeletionInfo> checkToolDeletionConstraints(int toolId) async {
    try {
      AppLogger.info('🔧 Checking tool deletion constraints for: $toolId');

      // استخدام دالة قاعدة البيانات المحسنة
      final constraintsResult = await _supabase.rpc(
        'check_manufacturing_tool_deletion_constraints',
        params: {'p_tool_id': toolId},
      ) as List<dynamic>;

      if (constraintsResult.isEmpty) {
        throw Exception('لم يتم إرجاع نتائج من فحص قيود الحذف');
      }

      final constraints = constraintsResult.first as Map<String, dynamic>;

      // الحصول على معلومات الأداة
      final toolData = await _supabase
          .from('manufacturing_tools')
          .select('id, name')
          .eq('id', toolId)
          .single() as Map<String, dynamic>;

      final canDelete = constraints['can_delete'] as bool;
      final productionRecipes = constraints['production_recipes'] as int;
      final usageHistory = constraints['usage_history'] as int;
      final activeBatches = constraints['active_batches'] as int;
      final blockingReason = constraints['blocking_reason'] as String? ?? '';

      List<String> warnings = [];

      if (productionRecipes > 0) {
        warnings.add('سيتم حذف $productionRecipes وصفة إنتاج مرتبطة بهذه الأداة');
      }

      if (usageHistory > 0) {
        warnings.add('سيتم حذف $usageHistory سجل من تاريخ الاستخدام');
      }

      if (activeBatches > 0) {
        warnings.add('سيتم إلغاء $activeBatches دفعة إنتاج نشطة');
      }

      return ToolDeletionInfo(
        toolId: toolId,
        toolName: toolData['name'] as String,
        canDelete: canDelete,
        hasProductionRecipes: productionRecipes > 0,
        hasUsageHistory: usageHistory > 0,
        productionRecipesCount: productionRecipes,
        usageHistoryCount: usageHistory,
        blockingReason: blockingReason,
        warnings: warnings,
      );
    } catch (e) {
      AppLogger.error('❌ Error checking tool deletion constraints: $e');
      throw Exception('فشل في التحقق من قيود حذف الأداة: $e');
    }
  }

  /// حذف أداة التصنيع بالقوة (الطريقة الأساسية)
  Future<bool> deleteTool(int toolId, {bool forceDelete = true}) async {
    try {
      AppLogger.info('🔥 Force deleting manufacturing tool: $toolId');

      // استخدام دالة الحذف القسري مع التنظيف التلقائي
      final result = await _supabase.rpc(
        'force_delete_manufacturing_tool',
        params: {
          'p_tool_id': toolId,
          'p_performed_by': null, // سيستخدم المستخدم الحالي
          'p_force_options': {
            'force_delete': true,
            'auto_cleanup': true,
          },
        },
      ) as Map<String, dynamic>;

      if (result['success'] != true) {
        final errorMessage = result['message'] as String? ?? 'فشل في حذف أداة التصنيع';
        throw Exception(errorMessage);
      }

      final executionTime = result['execution_time_seconds'] as double? ?? 0.0;
      final cleanupSummary = result['cleanup_summary'] as Map<String, dynamic>? ?? {};

      AppLogger.info('✅ Manufacturing tool force deleted successfully in ${executionTime.toStringAsFixed(2)}s');
      AppLogger.info('🧹 Cleanup summary: ${cleanupSummary.toString()}');

      // مسح الكاش
      _clearCache();

      return true;
    } catch (e) {
      AppLogger.error('❌ Error force deleting manufacturing tool: $e');
      throw Exception('فشل في حذف أداة التصنيع: $e');
    }
  }

  /// حذف أداة التصنيع مع التحقق من القيود (للاستخدام الداخلي فقط)
  @deprecated
  Future<bool> deleteToolWithConstraints(int toolId, {bool forceDelete = false}) async {
    try {
      AppLogger.info('🔧 Deleting manufacturing tool with constraints: $toolId (force: $forceDelete)');

      // التحقق من القيود أولاً
      final constraints = await checkToolDeletionConstraints(toolId);

      if (!forceDelete && !constraints.canDelete) {
        throw ToolDeletionException(
          'لا يمكن حذف الأداة: ${constraints.blockingReason}',
          constraints,
        );
      }

      // تسجيل ما سيتم حذفه
      if (constraints.hasProductionRecipes) {
        AppLogger.info('🗑️ Will cascade delete ${constraints.productionRecipesCount} production recipes');
      }
      if (constraints.hasUsageHistory) {
        AppLogger.info('🗑️ Will cascade delete ${constraints.usageHistoryCount} usage history records');
      }

      // حذف الأداة (سيتم حذف الوصفات والسجلات تلقائياً بسبب CASCADE)
      final result = await _supabase
          .from('manufacturing_tools')
          .delete()
          .eq('id', toolId);

      AppLogger.info('✅ Manufacturing tool deleted successfully with cascade deletion');

      // مسح الكاش
      _clearCache();

      return true;
    } catch (e) {
      if (e is ToolDeletionException) {
        rethrow;
      }
      AppLogger.error('❌ Error deleting manufacturing tool: $e');
      throw Exception('فشل في حذف أداة التصنيع: $e');
    }
  }

  /// إعادة تسمية أداة التصنيع
  Future<bool> renameTool(int toolId, String newName) async {
    try {
      AppLogger.info('🔧 Renaming manufacturing tool: $toolId -> $newName');

      // التحقق من صحة الاسم الجديد
      if (newName.trim().isEmpty) {
        throw Exception('اسم الأداة لا يمكن أن يكون فارغاً');
      }

      // التحقق من عدم وجود أداة أخرى بنفس الاسم
      final existingTools = await _supabase
          .from('manufacturing_tools')
          .select('id')
          .eq('name', newName.trim())
          .neq('id', toolId) as List<dynamic>;

      if (existingTools.isNotEmpty) {
        throw Exception('يوجد أداة أخرى بنفس الاسم');
      }

      // تحديث اسم الأداة
      await _supabase
          .from('manufacturing_tools')
          .update({
            'name': newName.trim(),
            'updated_at': DateTime.now().toIso8601String()
          })
          .eq('id', toolId);

      AppLogger.info('✅ Manufacturing tool renamed successfully');

      // مسح الكاش
      _clearCache();

      return true;
    } catch (e) {
      AppLogger.error('❌ Error renaming manufacturing tool: $e');
      throw Exception('فشل في إعادة تسمية أداة التصنيع: $e');
    }
  }

  /// الحصول على إحصائيات الأدوات
  Future<Map<String, dynamic>> getToolsStatistics() async {
    try {
      AppLogger.info('📊 Calculating tools statistics...');

      final tools = await getAllTools();
      
      final stats = {
        'total_tools': tools.length,
        'green_stock': tools.where((t) => t.stockStatus == 'green').length,
        'yellow_stock': tools.where((t) => t.stockStatus == 'yellow').length,
        'orange_stock': tools.where((t) => t.stockStatus == 'orange').length,
        'red_stock': tools.where((t) => t.stockStatus == 'red').length,
        'total_quantity': tools.fold<double>(0, (sum, tool) => sum + tool.quantity),
        'average_stock_percentage': tools.isNotEmpty 
            ? tools.fold<double>(0, (sum, tool) => sum + tool.stockPercentage) / tools.length
            : 0.0,
      };

      AppLogger.info('✅ Tools statistics calculated successfully');
      return stats;
    } catch (e) {
      AppLogger.error('❌ Error calculating tools statistics: $e');
      throw Exception('فشل في حساب إحصائيات الأدوات: $e');
    }
  }

  /// التحقق من صحة الكاش
  bool _isCacheValid(String key) {
    if (!_cache.containsKey(key)) return false;
    
    final cacheEntry = _cache[key];
    final timestamp = cacheEntry['timestamp'] as DateTime;
    
    return DateTime.now().difference(timestamp) < _cacheDuration;
  }

  /// مسح الكاش
  void _clearCache() {
    _cache.clear();
    AppLogger.info('🗑️ Manufacturing tools cache cleared');
  }

  /// مسح الكاش يدوياً
  void clearCache() {
    _clearCache();
  }
}
