import 'package:flutter_test/flutter_test.dart';
import 'package:smartbiztracker_new/models/manufacturing/manufacturing_tool.dart';
import 'package:smartbiztracker_new/models/manufacturing/production_recipe.dart';
import 'package:smartbiztracker_new/models/manufacturing/production_batch.dart';

void main() {
  group('Manufacturing Tools Models Tests', () {
    test('ManufacturingTool model should create and serialize correctly', () {
      final tool = ManufacturingTool(
        id: 1,
        name: 'مفك براغي',
        quantity: 25.0,
        initialStock: 30.0,
        unit: 'قطعة',
        color: 'أحمر',
        size: 'متوسط',
        imageUrl: null,
        stockPercentage: 83.33,
        stockStatus: 'green',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: 'test-uuid',
      );

      expect(tool.name, 'مفك براغي');
      expect(tool.quantity, 25.0);
      expect(tool.stockStatus, 'green');
      expect(tool.hasEnoughStock(20.0), true);
      expect(tool.hasEnoughStock(30.0), false);
      expect(tool.isValid, true);
    });

    test('ManufacturingTool model should handle image URLs correctly', () {
      // Test with null image URL
      final toolWithoutImage = ManufacturingTool(
        id: 1,
        name: 'أداة بدون صورة',
        quantity: 10.0,
        initialStock: 10.0,
        unit: 'قطعة',
        imageUrl: null,
        stockPercentage: 100.0,
        stockStatus: 'green',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(toolWithoutImage.imageUrl, isNull);

      // Test with relative image URL
      final toolWithRelativeImage = ManufacturingTool(
        id: 2,
        name: 'أداة مع صورة نسبية',
        quantity: 15.0,
        initialStock: 15.0,
        unit: 'قطعة',
        imageUrl: 'tools/screwdriver.jpg',
        stockPercentage: 100.0,
        stockStatus: 'green',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(toolWithRelativeImage.imageUrl, 'tools/screwdriver.jpg');

      // Test with absolute image URL
      final toolWithAbsoluteImage = ManufacturingTool(
        id: 3,
        name: 'أداة مع صورة مطلقة',
        quantity: 20.0,
        initialStock: 20.0,
        unit: 'قطعة',
        imageUrl: 'https://example.com/tools/hammer.jpg',
        stockPercentage: 100.0,
        stockStatus: 'green',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(toolWithAbsoluteImage.imageUrl, 'https://example.com/tools/hammer.jpg');
    });

    test('ToolUsageHistory should display descriptive operation names', () {
      // Test with product name available
      final usageWithProduct = ToolUsageHistory(
        id: 1,
        toolId: 1,
        toolName: 'مفك براغي',
        batchId: 1,
        productId: 1,
        productName: 'كرسي خشبي',
        quantityUsed: 2.5,
        remainingStock: 22.5,
        usageDate: DateTime.now(),
        operationType: 'production',
      );

      expect(usageWithProduct.descriptiveOperationName, 'إنتاج: كرسي خشبي');
      expect(usageWithProduct.operationDetails, 'إنتاج: كرسي خشبي - 2.5 وحدة');

      // Test without product name but with batch ID
      final usageWithoutProduct = ToolUsageHistory(
        id: 2,
        toolId: 1,
        toolName: 'مفك براغي',
        batchId: 2,
        quantityUsed: 1.0,
        remainingStock: 21.5,
        usageDate: DateTime.now(),
        operationType: 'production',
      );

      expect(usageWithoutProduct.descriptiveOperationName, 'إنتاج: دفعة رقم 2');
      expect(usageWithoutProduct.operationDetails, 'إنتاج: دفعة رقم 2 - 1.0 وحدة');

      // Test non-production operation
      final adjustmentUsage = ToolUsageHistory(
        id: 3,
        toolId: 1,
        toolName: 'مفك براغي',
        quantityUsed: 5.0,
        remainingStock: 16.5,
        usageDate: DateTime.now(),
        operationType: 'adjustment',
      );

      expect(adjustmentUsage.descriptiveOperationName, 'تعديل');
      expect(adjustmentUsage.operationDetails, 'تعديل - 5.0 وحدة');
    });

    test('CreateManufacturingToolRequest should validate correctly', () {
      final validRequest = CreateManufacturingToolRequest(
        name: 'أداة اختبار',
        quantity: 10.0,
        unit: 'قطعة',
        color: 'أزرق',
        size: 'كبير',
      );

      expect(validRequest.isValid, true);
      expect(validRequest.validationErrors, isEmpty);

      final invalidRequest = CreateManufacturingToolRequest(
        name: '',
        quantity: -5.0,
        unit: '',
      );

      expect(invalidRequest.isValid, false);
      expect(invalidRequest.validationErrors.length, greaterThan(0));
    });

    test('ProductionRecipe model should calculate requirements correctly', () {
      final recipe = ProductionRecipe(
        id: 1,
        productId: 1,
        toolId: 1,
        toolName: 'مفك براغي',
        quantityRequired: 2.5,
        unit: 'قطعة',
        currentStock: 25.0,
        stockStatus: 'green',
        createdAt: DateTime.now(),
      );

      expect(recipe.canProduce(5.0), true); // needs 12.5, has 25.0
      expect(recipe.canProduce(15.0), false); // needs 37.5, has 25.0
      expect(recipe.calculateRequiredQuantity(4.0), 10.0);
    });

    test('ProductionBatch model should format dates correctly', () {
      final batch = ProductionBatch(
        id: 1,
        productId: 1,
        unitsProduced: 10.0,
        completionDate: DateTime(2024, 1, 15, 14, 30),
        warehouseManagerName: 'أحمد محمد',
        status: 'completed',
        notes: 'إنتاج ناجح',
        createdAt: DateTime.now(),
      );

      expect(batch.statusText, 'مكتمل');
      expect(batch.statusColor, 'green');
      expect(batch.formattedCompletionDate, '15/1/2024');
      expect(batch.formattedCompletionTime, '14:30');
      expect(batch.canEdit, false);
      expect(batch.canCancel, false);
    });

    test('ToolUnits should validate units correctly', () {
      expect(ToolUnits.isValidUnit('قطعة'), true);
      expect(ToolUnits.isValidUnit('لتر'), true);
      expect(ToolUnits.isValidUnit('invalid_unit'), false);
      expect(ToolUnits.availableUnits.length, greaterThan(0));
    });

    test('ToolColors should validate colors correctly', () {
      expect(ToolColors.isValidColor('أحمر'), true);
      expect(ToolColors.isValidColor('أزرق'), true);
      expect(ToolColors.isValidColor('invalid_color'), false);
      expect(ToolColors.availableColors.length, greaterThan(0));
    });

    test('CompleteProductionRecipe should calculate production feasibility', () {
      final recipes = [
        ProductionRecipe(
          id: 1,
          productId: 1,
          toolId: 1,
          toolName: 'أداة 1',
          quantityRequired: 2.0,
          unit: 'قطعة',
          currentStock: 10.0,
          stockStatus: 'green',
          createdAt: DateTime.now(),
        ),
        ProductionRecipe(
          id: 2,
          productId: 1,
          toolId: 2,
          toolName: 'أداة 2',
          quantityRequired: 1.5,
          unit: 'لتر',
          currentStock: 5.0,
          stockStatus: 'yellow',
          createdAt: DateTime.now(),
        ),
      ];

      final completeRecipe = CompleteProductionRecipe(
        productId: 1,
        recipes: recipes,
      );

      expect(completeRecipe.hasRecipes, true);
      expect(completeRecipe.toolsCount, 2);
      expect(completeRecipe.canProduce(2.0), true); // needs 4.0 + 3.0, has 10.0 + 5.0
      expect(completeRecipe.canProduce(5.0), false); // needs 10.0 + 7.5, has 10.0 + 5.0

      final unavailable = completeRecipe.getUnavailableTools(5.0);
      expect(unavailable.length, 1);
      expect(unavailable.first.toolName, 'أداة 2');
    });

    test('UpdateToolQuantityRequest should validate correctly', () {
      final validRequest = UpdateToolQuantityRequest(
        toolId: 1,
        newQuantity: 15.0,
        operationType: 'adjustment',
        notes: 'تعديل المخزون',
      );

      expect(validRequest.isValid, true);

      final invalidRequest = UpdateToolQuantityRequest(
        toolId: 0,
        newQuantity: -5.0,
      );

      expect(invalidRequest.isValid, false);
    });
  });

  group('Manufacturing Tools Enums Tests', () {
    test('ProductionBatchStatus should convert correctly', () {
      expect(ProductionBatchStatus.completed.arabicText, 'مكتمل');
      expect(ProductionBatchStatus.pending.arabicText, 'في الانتظار');
      expect(ProductionBatchStatus.inProgress.arabicText, 'قيد التنفيذ');
      expect(ProductionBatchStatus.cancelled.arabicText, 'ملغي');

      expect(ProductionBatchStatus.fromString('completed'), ProductionBatchStatus.completed);
      expect(ProductionBatchStatus.fromString('pending'), ProductionBatchStatus.pending);
      expect(ProductionBatchStatus.fromString('invalid'), ProductionBatchStatus.pending);
    });

    test('ToolOperationType should convert correctly', () {
      expect(ToolOperationType.production.arabicText, 'إنتاج');
      expect(ToolOperationType.adjustment.arabicText, 'تعديل');
      expect(ToolOperationType.import.arabicText, 'استيراد');
      expect(ToolOperationType.export.arabicText, 'تصدير');

      expect(ToolOperationType.fromString('production'), ToolOperationType.production);
      expect(ToolOperationType.fromString('adjustment'), ToolOperationType.adjustment);
      expect(ToolOperationType.fromString('invalid'), ToolOperationType.adjustment);
    });
  });
}
