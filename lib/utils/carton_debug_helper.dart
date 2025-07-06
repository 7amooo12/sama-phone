import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:smartbiztracker_new/models/warehouse_inventory_model.dart';

/// مساعد تشخيص مشاكل حساب الكراتين
class CartonDebugHelper {
  
  /// تشخيص حساب الكراتين لعنصر مخزون معين
  static void debugCartonCalculation(WarehouseInventoryModel item) {
    AppLogger.info('🔍 === تشخيص حساب الكراتين ===');
    AppLogger.info('🔍 معرف المنتج: ${item.productId}');
    AppLogger.info('🔍 الكمية: ${item.quantity}');
    AppLogger.info('🔍 الكمية في الكرتونة: ${item.quantityPerCarton}');
    
    // حساب يدوي للتحقق
    if (item.quantity <= 0 || item.quantityPerCarton <= 0) {
      AppLogger.info('🔍 حساب يدوي: 0 (قيم غير صحيحة)');
    } else {
      final manualCalculation = (item.quantity / item.quantityPerCarton).ceil();
      AppLogger.info('🔍 حساب يدوي: ${item.quantity} ÷ ${item.quantityPerCarton} = ${item.quantity / item.quantityPerCarton} → ceil = $manualCalculation');
    }
    
    AppLogger.info('🔍 النتيجة من النموذج: ${item.cartonsCount}');
    AppLogger.info('🔍 النص الوصفي: ${item.cartonsDisplayText}');
    AppLogger.info('🔍 === نهاية التشخيص ===');
  }
  
  /// تشخيص قائمة من عناصر المخزون
  static void debugInventoryList(List<WarehouseInventoryModel> inventory) {
    AppLogger.info('🔍 === تشخيص قائمة المخزون ===');
    AppLogger.info('🔍 عدد العناصر: ${inventory.length}');
    
    for (int i = 0; i < inventory.length; i++) {
      final item = inventory[i];
      AppLogger.info('🔍 العنصر $i: ${item.productId} - ${item.quantity} قطعة، ${item.quantityPerCarton} في الكرتونة، ${item.cartonsCount} كرتونة');
    }
    
    AppLogger.info('🔍 === نهاية تشخيص القائمة ===');
  }
  
  /// اختبار حساب الكراتين مع قيم مختلفة
  static void testCartonCalculations() {
    AppLogger.info('🔍 === اختبار حسابات الكراتين ===');
    
    final testCases = [
      {'quantity': 10, 'quantityPerCarton': 2, 'expected': 5},
      {'quantity': 9, 'quantityPerCarton': 2, 'expected': 5},
      {'quantity': 8, 'quantityPerCarton': 2, 'expected': 4},
      {'quantity': 25, 'quantityPerCarton': 6, 'expected': 5},
      {'quantity': 24, 'quantityPerCarton': 6, 'expected': 4},
      {'quantity': 1, 'quantityPerCarton': 1, 'expected': 1},
      {'quantity': 0, 'quantityPerCarton': 1, 'expected': 0},
      {'quantity': 10, 'quantityPerCarton': 0, 'expected': 0},
    ];
    
    for (final testCase in testCases) {
      final quantity = testCase['quantity'] as int;
      final quantityPerCarton = testCase['quantityPerCarton'] as int;
      final expected = testCase['expected'] as int;
      
      // إنشاء عنصر مخزون للاختبار
      final testItem = WarehouseInventoryModel(
        id: 'test-id',
        warehouseId: 'test-warehouse',
        productId: 'test-product',
        quantity: quantity,
        quantityPerCarton: quantityPerCarton,
        lastUpdated: DateTime.now(),
        updatedBy: 'test-user',
      );
      
      final actual = testItem.cartonsCount;
      final passed = actual == expected;
      
      AppLogger.info('🔍 اختبار: $quantity ÷ $quantityPerCarton = $expected (متوقع) vs $actual (فعلي) ${passed ? "✅" : "❌"}');
    }
    
    AppLogger.info('🔍 === نهاية اختبار الحسابات ===');
  }
  
  /// مقارنة قيم الكراتين قبل وبعد التحديث
  static void compareCartonValues({
    required WarehouseInventoryModel before,
    required WarehouseInventoryModel after,
    required String operation,
  }) {
    AppLogger.info('🔍 === مقارنة قيم الكراتين - $operation ===');
    AppLogger.info('🔍 المنتج: ${before.productId}');
    
    AppLogger.info('🔍 قبل $operation:');
    AppLogger.info('  - الكمية: ${before.quantity}');
    AppLogger.info('  - الكمية في الكرتونة: ${before.quantityPerCarton}');
    AppLogger.info('  - عدد الكراتين: ${before.cartonsCount}');
    
    AppLogger.info('🔍 بعد $operation:');
    AppLogger.info('  - الكمية: ${after.quantity}');
    AppLogger.info('  - الكمية في الكرتونة: ${after.quantityPerCarton}');
    AppLogger.info('  - عدد الكراتين: ${after.cartonsCount}');
    
    // تحليل التغييرات
    final quantityChanged = before.quantity != after.quantity;
    final cartonQtyChanged = before.quantityPerCarton != after.quantityPerCarton;
    final cartonsChanged = before.cartonsCount != after.cartonsCount;
    
    AppLogger.info('🔍 التغييرات:');
    AppLogger.info('  - الكمية تغيرت: $quantityChanged');
    AppLogger.info('  - الكمية في الكرتونة تغيرت: $cartonQtyChanged');
    AppLogger.info('  - عدد الكراتين تغير: $cartonsChanged');
    
    // التحقق من صحة الحساب
    final expectedCartons = after.quantity <= 0 || after.quantityPerCarton <= 0 
        ? 0 
        : (after.quantity / after.quantityPerCarton).ceil();
    final calculationCorrect = after.cartonsCount == expectedCartons;
    
    AppLogger.info('🔍 صحة الحساب: ${calculationCorrect ? "✅ صحيح" : "❌ خطأ"} (متوقع: $expectedCartons، فعلي: ${after.cartonsCount})');
    
    AppLogger.info('🔍 === نهاية المقارنة ===');
  }
}
