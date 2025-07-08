import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:smartbiztracker_new/models/manufacturing/production_batch.dart';
import 'package:smartbiztracker_new/services/manufacturing/production_service.dart';
import 'package:smartbiztracker_new/services/manufacturing/manufacturing_tools_validation_service.dart';

/// Integration tests for the Enhanced Required Tools Forecast functionality
/// Tests the complete end-to-end flow from database to UI
class MockProductionService extends Mock implements ProductionService {}

void main() {
  group('Required Tools Forecast Integration Tests', () {
    late MockProductionService mockProductionService;
    late ManufacturingToolsValidationService validationService;

    setUp(() {
      mockProductionService = MockProductionService();
      validationService = ManufacturingToolsValidationService();
    });

    group('Enhanced Database Function Integration', () {
      test('should handle complete forecast data structure', () async {
        // Arrange - Mock enhanced database response
        final mockDatabaseResponse = {
          'success': true,
          'product_id': 1,
          'remaining_pieces': 25.0,
          'required_tools': [
            {
              'tool_id': 1,
              'tool_name': 'مسامير حديد',
              'unit': 'كيلو',
              'quantity_per_unit': 0.5,
              'total_quantity_needed': 12.5,
              'available_stock': 10.0,
              'shortfall': 2.5,
              'is_available': false,
              'availability_status': 'partial',
              'estimated_cost': 25.0,
            },
            {
              'tool_id': 2,
              'tool_name': 'غراء خشب',
              'unit': 'لتر',
              'quantity_per_unit': 0.2,
              'total_quantity_needed': 5.0,
              'available_stock': 8.0,
              'shortfall': 0.0,
              'is_available': true,
              'availability_status': 'available',
              'estimated_cost': null,
            },
          ],
          'can_complete_production': false,
          'unavailable_tools': ['مسامير حديد'],
          'total_cost': 25.0,
        };

        when(mockProductionService.getRequiredToolsForecast(1, 25.0))
            .thenAnswer((_) async => RequiredToolsForecast.fromJson(mockDatabaseResponse));

        // Act
        final result = await mockProductionService.getRequiredToolsForecast(1, 25.0);

        // Assert
        expect(result, isNotNull);
        expect(result!.productId, equals(1));
        expect(result.remainingPieces, equals(25.0));
        expect(result.requiredTools.length, equals(2));
        expect(result.canCompleteProduction, isFalse);
        expect(result.totalCost, equals(25.0));
        expect(result.hasUnavailableTools, isTrue);
        expect(result.unavailableToolsCount, equals(1));
      });

      test('should handle zero remaining pieces correctly', () async {
        // Arrange
        final mockResponse = {
          'success': true,
          'product_id': 1,
          'remaining_pieces': 0.0,
          'required_tools': [],
          'can_complete_production': true,
          'unavailable_tools': [],
          'total_cost': 0.0,
        };

        when(mockProductionService.getRequiredToolsForecast(1, 0.0))
            .thenAnswer((_) async => RequiredToolsForecast.fromJson(mockResponse));

        // Act
        final result = await mockProductionService.getRequiredToolsForecast(1, 0.0);

        // Assert
        expect(result, isNotNull);
        expect(result!.remainingPieces, equals(0.0));
        expect(result.requiredTools, isEmpty);
        expect(result.canCompleteProduction, isTrue);
        expect(result.totalCost, equals(0.0));
      });

      test('should handle missing production recipes', () async {
        // Arrange
        when(mockProductionService.getRequiredToolsForecast(999, 10.0))
            .thenAnswer((_) async => null);

        // Act
        final result = await mockProductionService.getRequiredToolsForecast(999, 10.0);

        // Assert
        expect(result, isNull);
      });
    });

    group('Professional Features Integration', () {
      test('should calculate professional insights correctly', () {
        // Arrange
        final forecast = RequiredToolsForecast(
          productId: 1,
          remainingPieces: 20.0,
          requiredTools: [
            RequiredToolItem(
              toolId: 1,
              toolName: 'أداة حرجة',
              unit: 'قطعة',
              quantityPerUnit: 1.0,
              totalQuantityNeeded: 20.0,
              availableStock: 0.0,
              shortfall: 20.0,
              isAvailable: false,
              availabilityStatus: 'critical',
              estimatedCost: 200.0,
            ),
            RequiredToolItem(
              toolId: 2,
              toolName: 'أداة متوفرة جزئياً',
              unit: 'كيلو',
              quantityPerUnit: 0.5,
              totalQuantityNeeded: 10.0,
              availableStock: 5.0,
              shortfall: 5.0,
              isAvailable: false,
              availabilityStatus: 'partial',
              estimatedCost: 50.0,
            ),
          ],
          canCompleteProduction: false,
          unavailableTools: ['أداة حرجة', 'أداة متوفرة جزئياً'],
          totalCost: 250.0,
        );

        // Act & Assert
        expect(forecast.toolsCount, equals(2));
        expect(forecast.availableToolsCount, equals(0));
        expect(forecast.partiallyAvailableToolsCount, equals(1));
        expect(forecast.totalShortfall, equals(25.0));
        expect(forecast.hasCriticalShortage, isTrue);
        expect(forecast.highPriorityTools.length, equals(1));
        expect(forecast.estimatedProcurementDays, equals(14)); // Critical tools take 14 days
        expect(forecast.statusSummary, contains('يحتاج 2 أداة'));
      });

      test('should generate accurate procurement recommendations', () {
        // Arrange
        final forecast = RequiredToolsForecast(
          productId: 1,
          remainingPieces: 15.0,
          requiredTools: [
            RequiredToolItem(
              toolId: 1,
              toolName: 'أداة غير متوفرة',
              unit: 'قطعة',
              quantityPerUnit: 2.0,
              totalQuantityNeeded: 30.0,
              availableStock: 0.0,
              shortfall: 30.0,
              isAvailable: false,
              availabilityStatus: 'unavailable',
              estimatedCost: 300.0,
            ),
          ],
          canCompleteProduction: false,
          unavailableTools: ['أداة غير متوفرة'],
          totalCost: 300.0,
        );

        // Act
        final recommendations = forecast.procurementRecommendations;

        // Assert
        expect(recommendations, isNotEmpty);
        expect(recommendations.any((r) => r.contains('التكلفة الإجمالية المتوقعة: 300.00 ريال')), isTrue);
        expect(recommendations.any((r) => r.contains('الوقت المتوقع للحصول على الأدوات: 7 أيام')), isTrue);
      });

      test('should validate tool item professional features', () {
        // Arrange
        final tool = RequiredToolItem(
          toolId: 1,
          toolName: 'أداة اختبار',
          unit: 'كيلو',
          quantityPerUnit: 0.5,
          totalQuantityNeeded: 10.0,
          availableStock: 3.0,
          shortfall: 7.0,
          isAvailable: false,
          availabilityStatus: 'partial',
          estimatedCost: 70.0,
        );

        // Act & Assert
        expect(tool.availabilityPercentage, equals(30.0)); // 3/10 * 100
        expect(tool.isHighPriority, isFalse); // partial is not high priority
        expect(tool.riskLevel, equals(3)); // partial = level 3
        expect(tool.actionRecommendation, contains('شراء 7.0 كيلو إضافية'));
        expect(tool.estimatedProcurementDays, equals(2)); // partial = 2 days
      });
    });

    group('Data Validation Integration', () {
      test('should validate complete forecast data integrity', () {
        // Arrange
        final validForecast = RequiredToolsForecast(
          productId: 1,
          remainingPieces: 10.0,
          requiredTools: [
            RequiredToolItem(
              toolId: 1,
              toolName: 'أداة صحيحة',
              unit: 'قطعة',
              quantityPerUnit: 1.0,
              totalQuantityNeeded: 10.0,
              availableStock: 15.0,
              shortfall: 0.0,
              isAvailable: true,
              availabilityStatus: 'available',
            ),
          ],
          canCompleteProduction: true,
          unavailableTools: [],
          totalCost: 0.0,
        );

        // Act
        final result = validationService.validateRequiredToolsForecast(validForecast);

        // Assert
        expect(result.isValid, isTrue);
        expect(result.errors, isEmpty);
      });

      test('should detect data inconsistencies', () {
        // Arrange - Inconsistent forecast (says can complete but has unavailable tools)
        final inconsistentForecast = RequiredToolsForecast(
          productId: 1,
          remainingPieces: 10.0,
          requiredTools: [
            RequiredToolItem(
              toolId: 1,
              toolName: 'أداة غير متوفرة',
              unit: 'قطعة',
              quantityPerUnit: 1.0,
              totalQuantityNeeded: 10.0,
              availableStock: 5.0,
              shortfall: 5.0,
              isAvailable: false,
              availabilityStatus: 'unavailable',
            ),
          ],
          canCompleteProduction: true, // Inconsistent!
          unavailableTools: ['أداة غير متوفرة'],
          totalCost: 50.0,
        );

        // Act
        final result = validationService.validateRequiredToolsForecast(inconsistentForecast);

        // Assert
        expect(result.isValid, isFalse);
        expect(result.errors.any((error) => error.contains('تناقض')), isTrue);
      });
    });

    group('Error Handling Integration', () {
      test('should handle network errors gracefully', () async {
        // Arrange
        when(mockProductionService.getRequiredToolsForecast(1, 10.0))
            .thenThrow(Exception('Network error'));

        // Act & Assert
        expect(
          () async => await mockProductionService.getRequiredToolsForecast(1, 10.0),
          throwsException,
        );
      });

      test('should handle invalid input parameters', () async {
        // Arrange
        when(mockProductionService.getRequiredToolsForecast(-1, -5.0))
            .thenAnswer((_) async => null);

        // Act
        final result = await mockProductionService.getRequiredToolsForecast(-1, -5.0);

        // Assert
        expect(result, isNull);
      });
    });
  });
}
