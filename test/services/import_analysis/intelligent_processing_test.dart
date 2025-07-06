import 'package:flutter_test/flutter_test.dart';
import 'package:smartbiztracker_new/models/import_analysis_models.dart';
import 'package:smartbiztracker_new/services/import_analysis/product_grouping_service.dart';
import 'package:smartbiztracker_new/services/import_analysis/material_aggregation_service.dart';
import 'package:smartbiztracker_new/services/import_analysis/intelligent_validation_service.dart';
import 'package:smartbiztracker_new/services/import_analysis/enhanced_summary_generator.dart';
import 'package:smartbiztracker_new/services/import_analysis/advanced_cell_processor.dart';
import 'package:smartbiztracker_new/services/import_analysis/performance_optimizer.dart';

void main() {
  group('Intelligent Processing System Tests', () {
    late List<Map<String, dynamic>> testData;

    setUp(() {
      testData = [
        {
          'item_number': '2333/1GD',
          'total_quantity': 100,
          'carton_count': 5,
          'remarks_a': 'طوق الالمينيوم بليد و بخرطوم (50) شبوه البلاستكية و قطعه غياره معدن (50)',
        },
        {
          'item_number': '2333/1GD',
          'total_quantity': 150,
          'carton_count': 7,
          'remarks_a': 'كرستاله شفافة (75) طوق الالمينيوم (75)',
        },
        {
          'item_number': 'YH0916-3 YH0917-3',
          'total_quantity': 200,
          'carton_count': 10,
          'remarks_a': 'مواد بلاستيكية متنوعة',
        },
        {
          'item_number': 'ABC123',
          'total_quantity': 50,
          'carton_count': 2,
          'remarks_a': 'قطع غيار معدنية',
        },
      ];
    });

    group('Advanced Cell Processor Tests', () {
      test('should extract multiple product IDs from single cell', () {
        final result = AdvancedCellProcessor.extractMultipleProductIds('YH0916-3 YH0917-3 YH0918-1');
        expect(result, hasLength(3));
        expect(result, contains('YH0916-3'));
        expect(result, contains('YH0917-3'));
        expect(result, contains('YH0918-1'));
      });

      test('should parse remarks cell with structured data', () {
        final result = AdvancedCellProcessor.parseRemarksCell(
          'طوق الالمينيوم بليد و بخرطوم (50) شبوه البلاستكية (30)',
          80,
        );
        
        expect(result['parsed_successfully'], isTrue);
        expect(result['materials'], hasLength(2));
        
        final materials = result['materials'] as List<Map<String, dynamic>>;
        expect(materials[0]['material_name'], contains('طوق الالمينيوم'));
        expect(materials[0]['quantity'], equals(50));
        expect(materials[1]['material_name'], contains('شبوه البلاستكية'));
        expect(materials[1]['quantity'], equals(30));
      });

      test('should normalize product IDs correctly', () {
        expect(AdvancedCellProcessor.normalizeProductId('  YH0916-3  '), equals('YH0916-3'));
        expect(AdvancedCellProcessor.normalizeProductId('yh0916-3'), equals('YH0916-3'));
        expect(AdvancedCellProcessor.normalizeProductId('YH 0916-3'), equals('YH0916-3'));
      });
    });

    group('Product Grouping Service Tests', () {
      test('should group products by item number', () async {
        final result = await ProductGroupingService.groupProducts(testData);
        
        expect(result, hasLength(3)); // 2333/1GD, YH0916-3, YH0917-3, ABC123 -> 3 unique after expansion
        
        // Find the grouped 2333/1GD product
        final groupedProduct = result.firstWhere((group) => group.itemNumber == '2333/1GD');
        expect(groupedProduct.totalQuantity, equals(250)); // 100 + 150
        expect(groupedProduct.totalCartonCount, equals(12)); // 5 + 7
        expect(groupedProduct.materials.length, greaterThan(0));
      });

      test('should handle multi-product cells correctly', () async {
        final result = await ProductGroupingService.groupProducts(testData);
        
        // Should have separate groups for YH0916-3 and YH0917-3
        final yh0916 = result.where((group) => group.itemNumber == 'YH0916-3');
        final yh0917 = result.where((group) => group.itemNumber == 'YH0917-3');
        
        expect(yh0916, hasLength(1));
        expect(yh0917, hasLength(1));
        
        // Each should have half the original quantity
        expect(yh0916.first.totalQuantity, equals(100)); // 200 / 2
        expect(yh0917.first.totalQuantity, equals(100)); // 200 / 2
      });

      test('should aggregate materials correctly', () async {
        final result = await ProductGroupingService.groupProducts(testData);
        
        final groupedProduct = result.firstWhere((group) => group.itemNumber == '2333/1GD');
        
        // Should have materials from both rows aggregated
        expect(groupedProduct.materials.length, greaterThan(1));
        
        // Check if aluminum ring materials are aggregated
        final aluminumMaterials = groupedProduct.materials.where(
          (material) => material.materialName.contains('طوق') || material.materialName.contains('الالمينيوم')
        );
        expect(aluminumMaterials, isNotEmpty);
      });
    });

    group('Material Aggregation Service Tests', () {
      test('should aggregate similar materials', () async {
        final productGroups = await ProductGroupingService.groupProducts(testData);
        final result = await MaterialAggregationService.aggregateMaterialsInGroups(productGroups);
        
        expect(result, hasLength(productGroups.length));
        
        // Check that materials are properly aggregated
        for (final group in result) {
          if (group.materials.isNotEmpty) {
            // Materials should be sorted by quantity (descending)
            for (int i = 0; i < group.materials.length - 1; i++) {
              expect(group.materials[i].quantity, greaterThanOrEqualTo(group.materials[i + 1].quantity));
            }
          }
        }
      });

      test('should generate aggregation report', () {
        final originalGroups = <ProductGroup>[];
        final aggregatedGroups = <ProductGroup>[];
        
        final report = MaterialAggregationService.generateAggregationReport(originalGroups, aggregatedGroups);
        
        expect(report, containsPair('total_products', 0));
        expect(report, containsPair('original_materials_count', 0));
        expect(report, containsPair('aggregated_materials_count', 0));
        expect(report, containsKey('generated_at'));
      });
    });

    group('Intelligent Validation Service Tests', () {
      test('should validate product groups', () async {
        final productGroups = await ProductGroupingService.groupProducts(testData);
        final result = await IntelligentValidationService.validateProductGroups(productGroups);
        
        expect(result.totalGroups, equals(productGroups.length));
        expect(result.validatedAt, isA<DateTime>());
        expect(result.groupResults, hasLength(productGroups.length));
        
        // Most groups should be valid with test data
        expect(result.validGroups, greaterThan(0));
      });

      test('should detect validation issues', () async {
        // Create invalid test data
        final invalidData = [
          {
            'item_number': '', // Empty item number
            'total_quantity': -10, // Negative quantity
            'carton_count': 5,
            'remarks_a': 'Invalid product',
          },
        ];
        
        final productGroups = await ProductGroupingService.groupProducts(invalidData);
        final result = await IntelligentValidationService.validateProductGroups(productGroups);
        
        expect(result.invalidGroups, greaterThan(0));
        expect(result.isOverallValid, isFalse);
      });
    });

    group('Enhanced Summary Generator Tests', () {
      test('should generate comprehensive report', () async {
        final productGroups = await ProductGroupingService.groupProducts(testData);
        final result = EnhancedSummaryGenerator.generateComprehensiveReport(productGroups);
        
        expect(result, containsKey('metadata'));
        expect(result, containsKey('overview'));
        expect(result, containsKey('product_analysis'));
        expect(result, containsKey('material_analysis'));
        expect(result, containsKey('quality_metrics'));
        expect(result, containsKey('recommendations'));
        
        final overview = result['overview'] as Map<String, dynamic>;
        expect(overview['total_unique_products'], equals(productGroups.length));
        expect(overview['total_quantity'], greaterThan(0));
      });

      test('should provide meaningful recommendations', () async {
        final productGroups = await ProductGroupingService.groupProducts(testData);
        final result = EnhancedSummaryGenerator.generateComprehensiveReport(productGroups);
        
        final recommendations = result['recommendations'] as List<dynamic>;
        expect(recommendations, isA<List>());
        
        // Should have recommendations for improvement
        if (recommendations.isNotEmpty) {
          final firstRec = recommendations.first as Map<String, dynamic>;
          expect(firstRec, containsKey('type'));
          expect(firstRec, containsKey('title'));
          expect(firstRec, containsKey('description'));
          expect(firstRec, containsKey('priority'));
        }
      });
    });

    group('Performance Optimizer Tests', () {
      test('should process within time limit', () async {
        final result = await PerformanceOptimizer.processWithTimeLimit(
          operation: () async {
            await Future.delayed(const Duration(milliseconds: 100));
            return 'completed';
          },
          operationName: 'test_operation',
          timeLimit: const Duration(seconds: 1),
        );
        
        expect(result, equals('completed'));
      });

      test('should throw timeout exception for long operations', () async {
        expect(
          () => PerformanceOptimizer.processWithTimeLimit(
            operation: () async {
              await Future.delayed(const Duration(seconds: 2));
              return 'completed';
            },
            operationName: 'slow_operation',
            timeLimit: const Duration(milliseconds: 500),
          ),
          throwsA(isA<PerformanceException>()),
        );
      });

      test('should cache results correctly', () async {
        int callCount = 0;
        
        final operation = () async {
          callCount++;
          return 'result_$callCount';
        };
        
        // First call
        final result1 = await PerformanceOptimizer.cacheResult(
          key: 'test_key',
          operation: operation,
        );
        
        // Second call should use cache
        final result2 = await PerformanceOptimizer.cacheResult(
          key: 'test_key',
          operation: operation,
        );
        
        expect(result1, equals('result_1'));
        expect(result2, equals('result_1')); // Same result from cache
        expect(callCount, equals(1)); // Operation called only once
      });

      test('should process batches efficiently', () async {
        final data = List.generate(100, (index) => index);
        
        final result = await PerformanceOptimizer.processBatches(
          data: data,
          processor: (item) async => item * 2,
          operationName: 'multiply_test',
          batchSize: 10,
        );
        
        expect(result, hasLength(100));
        expect(result.first, equals(0));
        expect(result.last, equals(198)); // 99 * 2
      });
    });

    group('Integration Tests', () {
      test('should complete full intelligent processing workflow', () async {
        // Test the complete workflow
        final productGroups = await ProductGroupingService.groupProducts(testData);
        expect(productGroups, isNotEmpty);
        
        final aggregatedGroups = await MaterialAggregationService.aggregateMaterialsInGroups(productGroups);
        expect(aggregatedGroups, hasLength(productGroups.length));
        
        final validationReport = await IntelligentValidationService.validateProductGroups(aggregatedGroups);
        expect(validationReport.totalGroups, equals(aggregatedGroups.length));
        
        final enhancedSummary = EnhancedSummaryGenerator.generateComprehensiveReport(aggregatedGroups);
        expect(enhancedSummary, containsKey('overview'));
        
        // Verify data consistency
        final overview = enhancedSummary['overview'] as Map<String, dynamic>;
        expect(overview['total_unique_products'], equals(aggregatedGroups.length));
      });

      test('should handle large datasets efficiently', () async {
        // Generate large test dataset
        final largeData = List.generate(500, (index) => {
          'item_number': 'ITEM_${index % 50}', // 50 unique products with duplicates
          'total_quantity': 10 + (index % 100),
          'carton_count': 1 + (index % 10),
          'remarks_a': 'Material ${index % 20} (${10 + (index % 50)})',
        });
        
        final stopwatch = Stopwatch()..start();
        
        final result = await PerformanceOptimizer.processWithTimeLimit(
          operation: () => ProductGroupingService.groupProducts(largeData),
          operationName: 'large_dataset_test',
          timeLimit: const Duration(seconds: 30),
        );
        
        stopwatch.stop();
        
        expect(result, isNotEmpty);
        expect(result.length, lessThanOrEqualTo(50)); // Should be grouped
        expect(stopwatch.elapsedMilliseconds, lessThan(30000)); // Under 30 seconds
      });
    });
  });
}
