import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartbiztracker_new/models/manufacturing/production_batch.dart';
import 'package:smartbiztracker_new/services/manufacturing/manufacturing_tools_edge_cases_handler.dart';

void main() {
  group('ManufacturingToolsEdgeCasesHandler', () {
    group('handleOverProduction', () {
      test('should handle over-production correctly', () {
        // Arrange
        final gapAnalysis = ProductionGapAnalysis(
          productId: 1,
          productName: 'منتج اختبار',
          currentProduction: 120.0,
          targetQuantity: 100.0,
          remainingPieces: 0.0,
          completionPercentage: 100.0,
          isOverProduced: false,
          isCompleted: true,
        );

        // Act
        final result = ManufacturingToolsEdgeCasesHandler.handleOverProduction(gapAnalysis);

        // Assert
        expect(result.isOverProduced, isTrue);
        expect(result.isCompleted, isTrue);
        expect(result.remainingPieces, equals(-20.0));
        expect(result.completionPercentage, equals(120.0));
      });

      test('should not modify normal production', () {
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
        final result = ManufacturingToolsEdgeCasesHandler.handleOverProduction(gapAnalysis);

        // Assert
        expect(result.isOverProduced, isFalse);
        expect(result.remainingPieces, equals(20.0));
        expect(result.completionPercentage, equals(80.0));
      });
    });

    group('handleZeroRemainingPieces', () {
      test('should return empty forecast for zero remaining pieces', () {
        // Act
        final result = ManufacturingToolsEdgeCasesHandler.handleZeroRemainingPieces(0.0);

        // Assert
        expect(result, isNotNull);
        expect(result!.remainingPieces, equals(0.0));
        expect(result.requiredTools, isEmpty);
        expect(result.canCompleteProduction, isTrue);
        expect(result.unavailableTools, isEmpty);
        expect(result.totalCost, equals(0.0));
      });

      test('should return empty forecast for negative remaining pieces', () {
        // Act
        final result = ManufacturingToolsEdgeCasesHandler.handleZeroRemainingPieces(-5.0);

        // Assert
        expect(result, isNotNull);
        expect(result!.remainingPieces, equals(0.0));
      });

      test('should return null for positive remaining pieces', () {
        // Act
        final result = ManufacturingToolsEdgeCasesHandler.handleZeroRemainingPieces(10.0);

        // Assert
        expect(result, isNull);
      });
    });

    group('handleMissingToolData', () {
      test('should return placeholder tool data', () {
        // Act
        final result = ManufacturingToolsEdgeCasesHandler.handleMissingToolData(123);

        // Assert
        expect(result.length, equals(1));
        expect(result.first.toolId, equals(-1));
        expect(result.first.toolName, equals('لا توجد بيانات أدوات'));
        expect(result.first.totalQuantityUsed, equals(0));
        expect(result.first.usagePercentage, equals(0));
      });
    });

    group('sanitizeToolAnalytics', () {
      test('should sanitize corrupted tool analytics', () {
        // Arrange
        final corruptedAnalytics = ToolUsageAnalytics(
          toolId: 1,
          toolName: '', // اسم فارغ
          unit: '', // وحدة فارغة
          quantityUsedPerUnit: double.nan, // قيمة غير صحيحة
          totalQuantityUsed: -10.0, // قيمة سالبة
          remainingStock: double.infinity, // قيمة لا نهائية
          initialStock: -5.0, // قيمة سالبة
          usagePercentage: 150.0, // نسبة خارج النطاق
          stockStatus: 'invalid_status',
          usageHistory: [],
        );

        // Act
        final result = ManufacturingToolsEdgeCasesHandler.sanitizeToolAnalytics(corruptedAnalytics);

        // Assert
        expect(result.toolName, equals('أداة غير محددة'));
        expect(result.unit, equals('وحدة'));
        expect(result.quantityUsedPerUnit, equals(0.0));
        expect(result.totalQuantityUsed, equals(0.0));
        expect(result.remainingStock, equals(0.0));
        expect(result.initialStock, equals(0.0)); // totalQuantityUsed + remainingStock
        expect(result.usagePercentage, equals(0.0));
        expect(result.stockStatus, equals('medium')); // default
      });

      test('should preserve valid data', () {
        // Arrange
        final validAnalytics = ToolUsageAnalytics(
          toolId: 1,
          toolName: 'أداة صحيحة',
          unit: 'قطعة',
          quantityUsedPerUnit: 2.0,
          totalQuantityUsed: 20.0,
          remainingStock: 10.0,
          initialStock: 30.0,
          usagePercentage: 66.7,
          stockStatus: 'medium',
          usageHistory: [],
        );

        // Act
        final result = ManufacturingToolsEdgeCasesHandler.sanitizeToolAnalytics(validAnalytics);

        // Assert
        expect(result.toolName, equals('أداة صحيحة'));
        expect(result.unit, equals('قطعة'));
        expect(result.quantityUsedPerUnit, equals(2.0));
        expect(result.totalQuantityUsed, equals(20.0));
        expect(result.remainingStock, equals(10.0));
        expect(result.initialStock, equals(30.0));
        expect(result.usagePercentage, equals(66.7));
        expect(result.stockStatus, equals('medium'));
      });
    });

    group('sanitizeNumericValue', () {
      test('should handle NaN values', () {
        // Act
        final result = ManufacturingToolsEdgeCasesHandler.sanitizeNumericValue(
          double.nan,
          defaultValue: 5.0,
        );

        // Assert
        expect(result, equals(5.0));
      });

      test('should handle infinite values', () {
        // Act
        final result = ManufacturingToolsEdgeCasesHandler.sanitizeNumericValue(
          double.infinity,
          defaultValue: 10.0,
        );

        // Assert
        expect(result, equals(10.0));
      });

      test('should clamp values to range', () {
        // Act
        final resultMin = ManufacturingToolsEdgeCasesHandler.sanitizeNumericValue(
          -5.0,
          min: 0.0,
          max: 100.0,
        );
        final resultMax = ManufacturingToolsEdgeCasesHandler.sanitizeNumericValue(
          150.0,
          min: 0.0,
          max: 100.0,
        );

        // Assert
        expect(resultMin, equals(0.0));
        expect(resultMax, equals(100.0));
      });

      test('should preserve valid values', () {
        // Act
        final result = ManufacturingToolsEdgeCasesHandler.sanitizeNumericValue(
          50.0,
          min: 0.0,
          max: 100.0,
        );

        // Assert
        expect(result, equals(50.0));
      });
    });

    group('sanitizeStringValue', () {
      test('should handle null values', () {
        // Act
        final result = ManufacturingToolsEdgeCasesHandler.sanitizeStringValue(
          null,
          defaultValue: 'افتراضي',
        );

        // Assert
        expect(result, equals('افتراضي'));
      });

      test('should handle empty strings', () {
        // Act
        final result = ManufacturingToolsEdgeCasesHandler.sanitizeStringValue(
          '',
          defaultValue: 'افتراضي',
        );

        // Assert
        expect(result, equals('افتراضي'));
      });

      test('should trim whitespace', () {
        // Act
        final result = ManufacturingToolsEdgeCasesHandler.sanitizeStringValue(
          '  نص مع مسافات  ',
          trimWhitespace: true,
        );

        // Assert
        expect(result, equals('نص مع مسافات'));
      });

      test('should preserve valid strings', () {
        // Act
        final result = ManufacturingToolsEdgeCasesHandler.sanitizeStringValue(
          'نص صحيح',
        );

        // Assert
        expect(result, equals('نص صحيح'));
      });
    });

    group('sanitizeDateValue', () {
      test('should handle null dates', () {
        // Arrange
        final defaultDate = DateTime(2024, 1, 1);

        // Act
        final result = ManufacturingToolsEdgeCasesHandler.sanitizeDateValue(
          null,
          defaultDate: defaultDate,
        );

        // Assert
        expect(result, equals(defaultDate));
      });

      test('should clamp dates to range', () {
        // Arrange
        final minDate = DateTime(2024, 1, 1);
        final maxDate = DateTime(2024, 12, 31);
        final tooEarly = DateTime(2023, 1, 1);
        final tooLate = DateTime(2025, 1, 1);

        // Act
        final resultMin = ManufacturingToolsEdgeCasesHandler.sanitizeDateValue(
          tooEarly,
          minDate: minDate,
          maxDate: maxDate,
        );
        final resultMax = ManufacturingToolsEdgeCasesHandler.sanitizeDateValue(
          tooLate,
          minDate: minDate,
          maxDate: maxDate,
        );

        // Assert
        expect(resultMin, equals(minDate));
        expect(resultMax, equals(maxDate));
      });

      test('should preserve valid dates', () {
        // Arrange
        final validDate = DateTime(2024, 6, 15);
        final minDate = DateTime(2024, 1, 1);
        final maxDate = DateTime(2024, 12, 31);

        // Act
        final result = ManufacturingToolsEdgeCasesHandler.sanitizeDateValue(
          validDate,
          minDate: minDate,
          maxDate: maxDate,
        );

        // Assert
        expect(result, equals(validDate));
      });
    });

    group('resolveDataConflicts', () {
      test('should use latest strategy correctly', () {
        // Arrange
        final data1 = {'key1': 'value1', 'key2': 'value2'};
        final data2 = {'key2': 'new_value2', 'key3': 'value3'};

        // Act
        final result = ManufacturingToolsEdgeCasesHandler.resolveDataConflicts(
          data1,
          data2,
          strategy: 'latest',
        );

        // Assert
        expect(result['key1'], equals('value1'));
        expect(result['key2'], equals('new_value2')); // من data2
        expect(result['key3'], equals('value3'));
      });

      test('should use merge strategy correctly', () {
        // Arrange
        final data1 = {'key1': 'value1', 'key2': null};
        final data2 = {'key2': 'value2', 'key3': null};

        // Act
        final result = ManufacturingToolsEdgeCasesHandler.resolveDataConflicts(
          data1,
          data2,
          strategy: 'merge',
        );

        // Assert
        expect(result['key1'], equals('value1'));
        expect(result['key2'], equals('value2')); // من data2 لأن data1 null
        expect(result.containsKey('key3'), isFalse); // null values excluded
      });

      test('should use conservative strategy correctly', () {
        // Arrange
        final data1 = {'key1': 'value1', 'key2': 'value2'};
        final data2 = {'key2': 'new_value2', 'key3': 'value3'};

        // Act
        final result = ManufacturingToolsEdgeCasesHandler.resolveDataConflicts(
          data1,
          data2,
          strategy: 'conservative',
        );

        // Assert
        expect(result['key1'], equals('value1'));
        expect(result['key2'], equals('value2')); // من data1 (محافظ)
        expect(result['key3'], equals('value3')); // جديد من data2
      });
    });
  });
}
