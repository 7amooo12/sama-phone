import 'package:smartbiztracker_new/models/manufacturing/manufacturing_tool.dart';
import 'package:smartbiztracker_new/models/manufacturing/production_recipe.dart';
import 'package:smartbiztracker_new/models/manufacturing/production_batch.dart';
import 'package:smartbiztracker_new/services/manufacturing/manufacturing_tools_service.dart';
import 'package:smartbiztracker_new/services/manufacturing/production_service.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// خدمة خصم المخزون التلقائي مع حسابات دقيقة ومراجعة شاملة
class InventoryDeductionService {
  final ManufacturingToolsService _toolsService = ManufacturingToolsService();
  final ProductionService _productionService = ProductionService();

  /// حساب متطلبات الإنتاج مع التحقق من توفر المخزون
  Future<ProductionDetails> calculateProductionRequirements(
    int productId,
    double unitsToProduceCount,
  ) async {
    try {
      AppLogger.info('🧮 Calculating production requirements for product: $productId, units: $unitsToProduceCount');

      // الحصول على وصفة الإنتاج
      final recipe = await _productionService.getProductionRecipes(productId);
      
      if (!recipe.hasRecipes) {
        throw Exception('لا توجد وصفة إنتاج لهذا المنتج');
      }

      // إنشاء تفاصيل الإنتاج
      final productionDetails = ProductionDetails.fromRecipe(recipe, unitsToProduceCount);
      
      AppLogger.info('✅ Production requirements calculated: ${productionDetails.canProduce ? "Can produce" : "Cannot produce"}');
      
      if (!productionDetails.canProduce) {
        AppLogger.warning('⚠️ Production issues found: ${productionDetails.issues.length}');
        for (final issue in productionDetails.issues) {
          AppLogger.warning('  - $issue');
        }
      }

      return productionDetails;
    } catch (e) {
      AppLogger.error('❌ Error calculating production requirements: $e');
      throw Exception('فشل في حساب متطلبات الإنتاج: $e');
    }
  }

  /// محاكاة خصم المخزون (للمراجعة قبل التنفيذ)
  Future<Map<String, dynamic>> simulateInventoryDeduction(
    int productId,
    double unitsToProduceCount,
  ) async {
    try {
      AppLogger.info('🎭 Simulating inventory deduction for product: $productId, units: $unitsToProduceCount');

      final productionDetails = await calculateProductionRequirements(productId, unitsToProduceCount);
      
      final simulation = <String, dynamic>{
        'product_id': productId,
        'units_to_produce': unitsToProduceCount,
        'can_produce': productionDetails.canProduce,
        'tools_required': productionDetails.recipes.length,
        'deductions': <Map<String, dynamic>>[],
        'issues': productionDetails.issues,
        'total_cost': 0.0, // يمكن إضافة حساب التكلفة لاحقاً
      };

      // حساب الخصومات المطلوبة
      for (final recipe in productionDetails.recipes) {
        final requiredQuantity = productionDetails.getCalculatedQuantity(recipe.toolId);
        final newStock = recipe.currentStock - requiredQuantity;
        
        final deduction = {
          'tool_id': recipe.toolId,
          'tool_name': recipe.toolName,
          'unit': recipe.unit,
          'current_stock': recipe.currentStock,
          'required_quantity': requiredQuantity,
          'new_stock': newStock,
          'stock_status_before': recipe.stockStatus,
          'stock_status_after': _calculateNewStockStatus(newStock, recipe.toolId),
          'sufficient_stock': recipe.currentStock >= requiredQuantity,
        };
        
        simulation['deductions'].add(deduction);
      }

      AppLogger.info('✅ Inventory deduction simulation completed');
      return simulation;
    } catch (e) {
      AppLogger.error('❌ Error simulating inventory deduction: $e');
      throw Exception('فشل في محاكاة خصم المخزون: $e');
    }
  }

  /// تنفيذ خصم المخزون الفعلي
  Future<int> executeInventoryDeduction(
    int productId,
    double unitsToProduceCount,
    String? notes,
  ) async {
    try {
      AppLogger.info('⚡ Executing inventory deduction for product: $productId, units: $unitsToProduceCount');

      // التحقق من إمكانية الإنتاج
      final productionDetails = await calculateProductionRequirements(productId, unitsToProduceCount);
      
      if (!productionDetails.canProduce) {
        throw Exception('لا يمكن تنفيذ الإنتاج: ${productionDetails.issues.join(', ')}');
      }

      // إنشاء طلب دفعة الإنتاج
      final batchRequest = CreateProductionBatchRequest(
        productId: productId,
        unitsProduced: unitsToProduceCount,
        notes: notes,
      );

      // إنشاء دفعة الإنتاج بحالة "قيد التنفيذ" (سيتم خصم المخزون تلقائياً في قاعدة البيانات)
      final batchId = await _productionService.createProductionBatchInProgress(batchRequest);

      AppLogger.info('✅ Inventory deduction executed successfully, batch ID: $batchId');
      
      // مسح الكاش لضمان الحصول على البيانات المحدثة
      _toolsService.clearCache();
      _productionService.clearCache();

      return batchId;
    } catch (e) {
      AppLogger.error('❌ Error executing inventory deduction: $e');
      throw Exception('فشل في تنفيذ خصم المخزون: $e');
    }
  }

  /// التحقق من توفر المخزون لعدة منتجات
  Future<Map<int, bool>> checkMultipleProductsAvailability(
    Map<int, double> productsAndQuantities,
  ) async {
    try {
      AppLogger.info('🔍 Checking availability for ${productsAndQuantities.length} products');

      final availability = <int, bool>{};
      
      for (final entry in productsAndQuantities.entries) {
        final productId = entry.key;
        final quantity = entry.value;
        
        try {
          final productionDetails = await calculateProductionRequirements(productId, quantity);
          availability[productId] = productionDetails.canProduce;
        } catch (e) {
          AppLogger.warning('⚠️ Error checking availability for product $productId: $e');
          availability[productId] = false;
        }
      }

      AppLogger.info('✅ Availability check completed');
      return availability;
    } catch (e) {
      AppLogger.error('❌ Error checking multiple products availability: $e');
      throw Exception('فشل في التحقق من توفر المخزون للمنتجات: $e');
    }
  }

  /// الحصول على تقرير استهلاك المخزون
  Future<Map<String, dynamic>> getInventoryConsumptionReport({
    DateTime? startDate,
    DateTime? endDate,
    int? toolId,
  }) async {
    try {
      AppLogger.info('📊 Generating inventory consumption report...');

      // الحصول على تاريخ استخدام الأدوات
      final usageHistory = await _productionService.getToolUsageHistory(
        toolId: toolId,
        limit: 1000,
      );

      // تصفية حسب التاريخ إذا تم تحديده
      var filteredHistory = usageHistory;
      if (startDate != null || endDate != null) {
        filteredHistory = usageHistory.where((usage) {
          final usageDate = usage.usageDate;
          if (startDate != null && usageDate.isBefore(startDate)) return false;
          if (endDate != null && usageDate.isAfter(endDate)) return false;
          return true;
        }).toList();
      }

      // حساب الإحصائيات
      final operationsByType = <String, int>{};
      final consumptionByTool = <String, double>{};
      final consumptionByDate = <String, double>{};
      final topConsumedTools = <Map<String, dynamic>>[];

      final report = <String, dynamic>{
        'period': <String, String?>{
          'start_date': startDate?.toIso8601String(),
          'end_date': endDate?.toIso8601String(),
        },
        'total_operations': filteredHistory.length,
        'total_quantity_consumed': filteredHistory
            .where((h) => h.operationType == 'production')
            .fold<double>(0, (sum, usage) => sum + usage.quantityUsed),
        'operations_by_type': operationsByType,
        'consumption_by_tool': consumptionByTool,
        'consumption_by_date': consumptionByDate,
        'top_consumed_tools': topConsumedTools,
      };

      // تجميع العمليات حسب النوع
      for (final usage in filteredHistory) {
        final type = usage.operationType;
        operationsByType[type] = (operationsByType[type] ?? 0) + 1;
      }

      // تجميع الاستهلاك حسب الأداة
      for (final usage in filteredHistory.where((h) => h.operationType == 'production')) {
        final toolName = usage.toolName;
        consumptionByTool[toolName] = (consumptionByTool[toolName] ?? 0.0) + usage.quantityUsed;
      }

      // تجميع الاستهلاك حسب التاريخ
      for (final usage in filteredHistory.where((h) => h.operationType == 'production')) {
        final dateKey = '${usage.usageDate.year}-${usage.usageDate.month.toString().padLeft(2, '0')}-${usage.usageDate.day.toString().padLeft(2, '0')}';
        consumptionByDate[dateKey] = (consumptionByDate[dateKey] ?? 0.0) + usage.quantityUsed;
      }

      // ترتيب الأدوات الأكثر استهلاكاً
      final sortedTools = consumptionByTool.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      topConsumedTools.addAll(sortedTools.take(10).map((entry) => <String, dynamic>{
        'tool_name': entry.key,
        'total_consumed': entry.value,
      }));

      AppLogger.info('✅ Inventory consumption report generated successfully');
      return report;
    } catch (e) {
      AppLogger.error('❌ Error generating inventory consumption report: $e');
      throw Exception('فشل في إنشاء تقرير استهلاك المخزون: $e');
    }
  }

  /// حساب حالة المخزون الجديدة بعد الخصم
  String _calculateNewStockStatus(double newStock, int toolId) {
    // هذه دالة مساعدة لحساب حالة المخزون الجديدة
    // يمكن تحسينها بالحصول على المخزون الأولي من قاعدة البيانات
    if (newStock <= 0) return 'red';
    if (newStock <= 10) return 'orange';
    if (newStock <= 30) return 'yellow';
    return 'green';
  }

  /// التحقق من الحد الأدنى للمخزون
  Future<List<ManufacturingTool>> checkMinimumStockLevels() async {
    try {
      AppLogger.info('⚠️ Checking minimum stock levels...');

      final lowStockTools = await _toolsService.getLowStockTools();
      
      AppLogger.info('✅ Found ${lowStockTools.length} tools below minimum stock levels');
      return lowStockTools;
    } catch (e) {
      AppLogger.error('❌ Error checking minimum stock levels: $e');
      throw Exception('فشل في التحقق من الحد الأدنى للمخزون: $e');
    }
  }

  /// اقتراح إعادة التخزين
  Future<List<Map<String, dynamic>>> suggestRestocking() async {
    try {
      AppLogger.info('💡 Generating restocking suggestions...');

      final lowStockTools = await checkMinimumStockLevels();
      final suggestions = <Map<String, dynamic>>[];

      for (final tool in lowStockTools) {
        final suggestion = {
          'tool_id': tool.id,
          'tool_name': tool.name,
          'current_stock': tool.quantity,
          'initial_stock': tool.initialStock,
          'unit': tool.unit,
          'stock_percentage': tool.stockPercentage,
          'suggested_quantity': tool.initialStock - tool.quantity,
          'priority': _calculateRestockingPriority(tool.stockPercentage),
          'estimated_days_remaining': _estimateDaysRemaining(tool),
        };
        
        suggestions.add(suggestion);
      }

      // ترتيب حسب الأولوية
      suggestions.sort((a, b) => b['priority'].compareTo(a['priority']));

      AppLogger.info('✅ Generated ${suggestions.length} restocking suggestions');
      return suggestions;
    } catch (e) {
      AppLogger.error('❌ Error generating restocking suggestions: $e');
      throw Exception('فشل في إنشاء اقتراحات إعادة التخزين: $e');
    }
  }

  /// حساب أولوية إعادة التخزين
  int _calculateRestockingPriority(double stockPercentage) {
    if (stockPercentage <= 10) return 5; // أولوية عالية جداً
    if (stockPercentage <= 20) return 4; // أولوية عالية
    if (stockPercentage <= 30) return 3; // أولوية متوسطة
    if (stockPercentage <= 50) return 2; // أولوية منخفضة
    return 1; // أولوية منخفضة جداً
  }

  /// تقدير الأيام المتبقية (تقدير بسيط)
  int _estimateDaysRemaining(ManufacturingTool tool) {
    // هذا تقدير بسيط، يمكن تحسينه بناءً على معدل الاستهلاك التاريخي
    if (tool.stockPercentage <= 10) return 3;
    if (tool.stockPercentage <= 20) return 7;
    if (tool.stockPercentage <= 30) return 14;
    return 30;
  }
}
