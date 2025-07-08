import 'package:flutter_test/flutter_test.dart';
import 'package:smartbiztracker_new/models/manufacturing/production_batch.dart';
import 'package:smartbiztracker_new/services/manufacturing/manufacturing_tools_validation_service.dart';

void main() {
  group('ManufacturingToolsValidationService', () {
    late ManufacturingToolsValidationService validationService;

    setUp(() {
      validationService = ManufacturingToolsValidationService();
    });

    group('validateToolUsageAnalytics', () {
      test('should return valid result for correct data', () {
        // Arrange
        final analytics = [
          ToolUsageAnalytics(
            toolId: 1,
            toolName: 'أداة اختبار',
            unit: 'قطعة',
            quantityUsedPerUnit: 2.0,
            totalQuantityUsed: 20.0,
            remainingStock: 30.0,
            initialStock: 50.0,
            usagePercentage: 40.0,
            stockStatus: 'medium',
            usageHistory: [],
          ),
        ];

        // Act
        final result = validationService.validateToolUsageAnalytics(analytics);

        // Assert
        expect(result.isValid, isTrue);
        expect(result.errors, isEmpty);
      });

      test('should return invalid result for negative values', () {
        // Arrange
        final analytics = [
          ToolUsageAnalytics(
            toolId: 1,
            toolName: 'أداة اختبار',
            unit: 'قطعة',
            quantityUsedPerUnit: -1.0, // قيمة سالبة
            totalQuantityUsed: 20.0,
            remainingStock: -5.0, // قيمة سالبة
            initialStock: 50.0,
            usagePercentage: 40.0,
            stockStatus: 'medium',
            usageHistory: [],
          ),
        ];

        // Act
        final result = validationService.validateToolUsageAnalytics(analytics);

        // Assert
        expect(result.isValid, isFalse);
        expect(result.errors.length, greaterThan(0));
        expect(result.errors.any((error) => error.contains('سالبة')), isTrue);
      });

      test('should return invalid result for empty tool name', () {
        // Arrange
        final analytics = [
          ToolUsageAnalytics(
            toolId: 1,
            toolName: '', // اسم فارغ
            unit: 'قطعة',
            quantityUsedPerUnit: 2.0,
            totalQuantityUsed: 20.0,
            remainingStock: 30.0,
            initialStock: 50.0,
            usagePercentage: 40.0,
            stockStatus: 'medium',
            usageHistory: [],
          ),
        ];

        // Act
        final result = validationService.validateToolUsageAnalytics(analytics);

        // Assert
        expect(result.isValid, isFalse);
        expect(result.errors.any((error) => error.contains('فارغ')), isTrue);
      });

      test('should detect duplicate tools', () {
        // Arrange
        final analytics = [
          ToolUsageAnalytics(
            toolId: 1,
            toolName: 'أداة اختبار',
            unit: 'قطعة',
            quantityUsedPerUnit: 2.0,
            totalQuantityUsed: 20.0,
            remainingStock: 30.0,
            initialStock: 50.0,
            usagePercentage: 40.0,
            stockStatus: 'medium',
            usageHistory: [],
          ),
          ToolUsageAnalytics(
            toolId: 1, // نفس المعرف
            toolName: 'أداة اختبار مكررة',
            unit: 'قطعة',
            quantityUsedPerUnit: 1.0,
            totalQuantityUsed: 10.0,
            remainingStock: 20.0,
            initialStock: 30.0,
            usagePercentage: 33.0,
            stockStatus: 'high',
            usageHistory: [],
          ),
        ];

        // Act
        final result = validationService.validateToolUsageAnalytics(analytics);

        // Assert
        expect(result.isValid, isFalse);
        expect(result.errors.any((error) => error.contains('مكررة')), isTrue);
      });

      test('should return warnings for unusual usage percentages', () {
        // Arrange
        final analytics = [
          ToolUsageAnalytics(
            toolId: 1,
            toolName: 'أداة اختبار 1',
            unit: 'قطعة',
            quantityUsedPerUnit: 2.0,
            totalQuantityUsed: 20.0,
            remainingStock: 30.0,
            initialStock: 50.0,
            usagePercentage: 5.0, // نسبة منخفضة جداً
            stockStatus: 'high',
            usageHistory: [],
          ),
          ToolUsageAnalytics(
            toolId: 2,
            toolName: 'أداة اختبار 2',
            unit: 'قطعة',
            quantityUsedPerUnit: 2.0,
            totalQuantityUsed: 20.0,
            remainingStock: 30.0,
            initialStock: 50.0,
            usagePercentage: 95.0, // نسبة عالية جداً
            stockStatus: 'low',
            usageHistory: [],
          ),
        ];

        // Act
        final result = validationService.validateToolUsageAnalytics(analytics);

        // Assert
        expect(result.isValid, isTrue);
        expect(result.warnings.isNotEmpty, isTrue);
      });
    });

    group('validateProductionGapAnalysis', () {
      test('should return valid result for correct gap analysis', () {
        // Arrange
        final gapAnalysis = ProductionGapAnalysis(
          productId: 1,
          productName: 'منتج اختبار',
          currentProduction: 80.0,
          targetQuantity: 100.0,
          remainingPieces: 20.0,
          completionPercentage: 80.0,
          isOverProduced: false,
          isCompleted: false,
        );

        // Act
        final result = validationService.validateProductionGapAnalysis(gapAnalysis);

        // Assert
        expect(result.isValid, isTrue);
        expect(result.errors, isEmpty);
      });

      test('should return invalid result for zero target quantity', () {
        // Arrange
        final gapAnalysis = ProductionGapAnalysis(
          productId: 1,
          productName: 'منتج اختبار',
          currentProduction: 80.0,
          targetQuantity: 0.0, // هدف صفر
          remainingPieces: 20.0,
          completionPercentage: 80.0,
          isOverProduced: false,
          isCompleted: false,
        );

        // Act
        final result = validationService.validateProductionGapAnalysis(gapAnalysis);

        // Assert
        expect(result.isValid, isFalse);
        expect(result.errors.any((error) => error.contains('أكبر من صفر')), isTrue);
      });

      test('should return invalid result for negative current production', () {
        // Arrange
        final gapAnalysis = ProductionGapAnalysis(
          productId: 1,
          productName: 'منتج اختبار',
          currentProduction: -10.0, // إنتاج سالب
          targetQuantity: 100.0,
          remainingPieces: 20.0,
          completionPercentage: 80.0,
          isOverProduced: false,
          isCompleted: false,
        );

        // Act
        final result = validationService.validateProductionGapAnalysis(gapAnalysis);

        // Assert
        expect(result.isValid, isFalse);
        expect(result.errors.any((error) => error.contains('سالباً')), isTrue);
      });

      test('should detect inconsistency in completion percentage', () {
        // Arrange
        final gapAnalysis = ProductionGapAnalysis(
          productId: 1,
          productName: 'منتج اختبار',
          currentProduction: 80.0,
          targetQuantity: 100.0,
          remainingPieces: 20.0,
          completionPercentage: 90.0, // نسبة خاطئة (يجب أن تكون 80%)
          isOverProduced: false,
          isCompleted: false,
        );

        // Act
        final result = validationService.validateProductionGapAnalysis(gapAnalysis);

        // Assert
        expect(result.isValid, isTrue);
        expect(result.warnings.any((warning) => warning.contains('عدم تطابق')), isTrue);
      });

      test('should detect contradiction in over-production status', () {
        // Arrange
        final gapAnalysis = ProductionGapAnalysis(
          productId: 1,
          productName: 'منتج اختبار',
          currentProduction: 80.0,
          targetQuantity: 100.0,
          remainingPieces: 20.0, // قطع متبقية موجبة
          completionPercentage: 80.0,
          isOverProduced: true, // لكن مُعلم كإنتاج زائد
          isCompleted: false,
        );

        // Act
        final result = validationService.validateProductionGapAnalysis(gapAnalysis);

        // Assert
        expect(result.isValid, isFalse);
        expect(result.errors.any((error) => error.contains('تناقض')), isTrue);
      });
    });

    group('validateRequiredToolsForecast', () {
      test('should return valid result for correct forecast', () {
        // Arrange
        final forecast = RequiredToolsForecast(
          productId: 1,
          remainingPieces: 20.0,
          requiredTools: [
            RequiredToolItem(
              toolId: 1,
              toolName: 'أداة اختبار',
              unit: 'قطعة',
              quantityPerUnit: 2.0,
              totalQuantityNeeded: 40.0,
              availableStock: 50.0,
              shortfall: 0.0,
              isAvailable: true,
              availabilityStatus: 'available',
            ),
          ],
          canCompleteProduction: true,
          unavailableTools: [],
          totalCost: 100.0,
        );

        // Act
        final result = validationService.validateRequiredToolsForecast(forecast);

        // Assert
        expect(result.isValid, isTrue);
        expect(result.errors, isEmpty);
      });

      test('should return invalid result for negative remaining pieces', () {
        // Arrange
        final forecast = RequiredToolsForecast(
          productId: 1,
          remainingPieces: -5.0, // قطع متبقية سالبة
          requiredTools: [],
          canCompleteProduction: true,
          unavailableTools: [],
          totalCost: 0.0,
        );

        // Act
        final result = validationService.validateRequiredToolsForecast(forecast);

        // Assert
        expect(result.isValid, isFalse);
        expect(result.errors.any((error) => error.contains('سالبة')), isTrue);
      });

      test('should detect contradiction in completion capability', () {
        // Arrange
        final forecast = RequiredToolsForecast(
          productId: 1,
          remainingPieces: 20.0,
          requiredTools: [
            RequiredToolItem(
              toolId: 1,
              toolName: 'أداة غير متوفرة',
              unit: 'قطعة',
              quantityPerUnit: 2.0,
              totalQuantityNeeded: 40.0,
              availableStock: 10.0,
              shortfall: 30.0,
              isAvailable: false, // غير متوفرة
              availabilityStatus: 'unavailable',
            ),
          ],
          canCompleteProduction: true, // لكن يقول أنه يمكن الإكمال
          unavailableTools: ['أداة غير متوفرة'],
          totalCost: 100.0,
        );

        // Act
        final result = validationService.validateRequiredToolsForecast(forecast);

        // Assert
        expect(result.isValid, isFalse);
        expect(result.errors.any((error) => error.contains('تناقض')), isTrue);
      });
    });

    group('ValidationResult', () {
      test('should merge multiple validation results correctly', () {
        // Arrange
        final result1 = ValidationResult.valid(warnings: ['تحذير 1']);
        final result2 = ValidationResult.invalid(errors: ['خطأ 1'], warnings: ['تحذير 2']);
        final result3 = ValidationResult.valid();

        // Act
        final merged = ValidationResult.merge([result1, result2, result3]);

        // Assert
        expect(merged.isValid, isFalse);
        expect(merged.errors, contains('خطأ 1'));
        expect(merged.warnings, contains('تحذير 1'));
        expect(merged.warnings, contains('تحذير 2'));
        expect(merged.totalIssues, equals(3));
      });

      test('should identify warnings-only result', () {
        // Arrange
        final result = ValidationResult.valid(warnings: ['تحذير']);

        // Assert
        expect(result.hasWarningsOnly, isTrue);
        expect(result.isValid, isTrue);
      });
    });
  });
}
