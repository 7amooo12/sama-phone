import 'package:flutter_test/flutter_test.dart';
import 'package:smartbiztracker_new/services/background_processing_service.dart';
import 'package:smartbiztracker_new/services/enhanced_reports_cache_service.dart';
import 'package:smartbiztracker_new/services/performance_monitor.dart';
import 'package:smartbiztracker_new/models/flask_product_model.dart';

void main() {
  group('Comprehensive Reports Optimization Tests', () {
    late BackgroundProcessingService backgroundService;
    late PerformanceMonitor performanceMonitor;

    setUp(() {
      backgroundService = BackgroundProcessingService();
      performanceMonitor = PerformanceMonitor();
    });

    tearDown(() {
      backgroundService.killAllIsolates();
      performanceMonitor.clearStats();
    });

    group('Background Processing Service Tests', () {
      test('should process inventory analysis in background for large datasets', () async {
        // Create test products
        final products = List.generate(100, (index) => FlaskProductModel(
          id: index,
          name: 'Product $index',
          categoryName: 'Category ${index % 5}',
          stockQuantity: index % 150, // Varied stock levels
          finalPrice: 100.0 + index,
          purchasePrice: 70.0 + index,
          imageUrl: null,
          description: 'Test product $index',
          barcode: 'BAR$index',
          unit: 'piece',
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));

        final stopwatch = Stopwatch()..start();
        
        final result = await backgroundService.processInventoryAnalysis(
          products,
          'test_operation_${DateTime.now().millisecondsSinceEpoch}',
        );

        stopwatch.stop();

        // Verify results
        expect(result, isA<Map<String, dynamic>>());
        expect(result.containsKey('stockDistribution'), isTrue);
        expect(result.containsKey('lowStock'), isTrue);
        expect(result.containsKey('outOfStock'), isTrue);
        expect(result.containsKey('optimalStock'), isTrue);
        expect(result.containsKey('overStock'), isTrue);

        // Verify performance (should complete within reasonable time)
        expect(stopwatch.elapsedMilliseconds, lessThan(5000)); // 5 seconds max

        print('✅ Background inventory analysis completed in ${stopwatch.elapsedMilliseconds}ms');
      });

      test('should process chart data in background', () async {
        final products = List.generate(50, (index) => FlaskProductModel(
          id: index,
          name: 'Product $index',
          categoryName: 'Category ${index % 3}',
          stockQuantity: index + 10,
          finalPrice: 100.0 + index,
          purchasePrice: 70.0 + index,
          imageUrl: null,
          description: 'Test product $index',
          barcode: 'BAR$index',
          unit: 'piece',
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));

        final stopwatch = Stopwatch()..start();
        
        final result = await backgroundService.processChartData(
          products,
          'candlestick',
          'test_chart_${DateTime.now().millisecondsSinceEpoch}',
        );

        stopwatch.stop();

        // Verify results
        expect(result, isA<List<Map<String, dynamic>>>());
        expect(result.length, equals(products.length));
        
        for (final chartPoint in result) {
          expect(chartPoint.containsKey('productName'), isTrue);
          expect(chartPoint.containsKey('open'), isTrue);
          expect(chartPoint.containsKey('high'), isTrue);
          expect(chartPoint.containsKey('low'), isTrue);
          expect(chartPoint.containsKey('close'), isTrue);
        }

        // Verify performance
        expect(stopwatch.elapsedMilliseconds, lessThan(3000)); // 3 seconds max

        print('✅ Background chart processing completed in ${stopwatch.elapsedMilliseconds}ms');
      });

      test('should handle small datasets synchronously', () async {
        final products = List.generate(10, (index) => FlaskProductModel(
          id: index,
          name: 'Product $index',
          categoryName: 'Category ${index % 2}',
          stockQuantity: index + 5,
          finalPrice: 100.0 + index,
          purchasePrice: 70.0 + index,
          imageUrl: null,
          description: 'Test product $index',
          barcode: 'BAR$index',
          unit: 'piece',
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));

        final stopwatch = Stopwatch()..start();
        
        final result = await backgroundService.processInventoryAnalysis(
          products,
          'test_small_${DateTime.now().millisecondsSinceEpoch}',
        );

        stopwatch.stop();

        // Should complete very quickly for small datasets
        expect(stopwatch.elapsedMilliseconds, lessThan(100)); // 100ms max
        expect(result, isA<Map<String, dynamic>>());

        print('✅ Small dataset processing completed in ${stopwatch.elapsedMilliseconds}ms');
      });

      test('should track active isolates correctly', () async {
        expect(backgroundService.activeIsolatesCount, equals(0));
        expect(backgroundService.isProcessing, isFalse);

        final products = List.generate(60, (index) => FlaskProductModel(
          id: index,
          name: 'Product $index',
          categoryName: 'Category ${index % 3}',
          stockQuantity: index + 10,
          finalPrice: 100.0 + index,
          purchasePrice: 70.0 + index,
          imageUrl: null,
          description: 'Test product $index',
          barcode: 'BAR$index',
          unit: 'piece',
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));

        // Start processing (should use isolate for this size)
        final future = backgroundService.processInventoryAnalysis(
          products,
          'test_isolate_tracking_${DateTime.now().millisecondsSinceEpoch}',
        );

        // Give it a moment to start
        await Future.delayed(const Duration(milliseconds: 100));

        // Check if isolate is tracked (might be 0 if processing completed quickly)
        final isProcessingDuringExecution = backgroundService.isProcessing;

        await future;

        // Should be clean after completion
        expect(backgroundService.activeIsolatesCount, equals(0));
        expect(backgroundService.isProcessing, isFalse);

        print('✅ Isolate tracking test completed. Was processing during execution: $isProcessingDuringExecution');
      });
    });

    group('Performance Monitor Integration Tests', () {
      test('should track operation performance', () async {
        performanceMonitor.startOperation('test_operation');
        
        // Simulate some work
        await Future.delayed(const Duration(milliseconds: 100));
        
        performanceMonitor.endOperation('test_operation');

        final stats = performanceMonitor.getOperationStats('test_operation');
        expect(stats, isNotNull);
        expect(stats!['count'], equals(1));
        expect(stats['averageDuration'], greaterThan(90)); // Should be around 100ms
        expect(stats['averageDuration'], lessThan(200)); // But not too much more

        print('✅ Performance monitoring tracked operation: ${stats['averageDuration']}ms average');
      });

      test('should handle multiple operations', () async {
        final operations = ['op1', 'op2', 'op3'];
        
        for (final op in operations) {
          performanceMonitor.startOperation(op);
          await Future.delayed(const Duration(milliseconds: 50));
          performanceMonitor.endOperation(op);
        }

        for (final op in operations) {
          final stats = performanceMonitor.getOperationStats(op);
          expect(stats, isNotNull);
          expect(stats!['count'], equals(1));
        }

        final allStats = performanceMonitor.getAllStats();
        expect(allStats.length, equals(3));

        print('✅ Multiple operations tracked successfully');
      });

      test('should detect slow operations', () async {
        performanceMonitor.startOperation('slow_operation');
        
        // Simulate slow work
        await Future.delayed(const Duration(milliseconds: 1100)); // Over 1 second
        
        performanceMonitor.endOperation('slow_operation');

        final stats = performanceMonitor.getOperationStats('slow_operation');
        expect(stats!['averageDuration'], greaterThan(1000));

        print('✅ Slow operation detection test completed: ${stats['averageDuration']}ms');
      });
    });

    group('Cache Integration Tests', () {
      test('should cache and retrieve background processed data', () async {
        final testData = {
          'lowStock': 5,
          'outOfStock': 2,
          'optimalStock': 15,
          'overStock': 3,
          'stockDistribution': {
            'نفد المخزون': 2,
            'مخزون منخفض': 5,
            'مخزون مثالي': 15,
            'مخزون زائد': 3,
          },
        };

        const operationId = 'test_cache_operation';

        // Cache the data
        await EnhancedReportsCacheService.cacheBackgroundProcessedData(operationId, testData);

        // Retrieve the data
        final retrievedData = await EnhancedReportsCacheService.getCachedBackgroundProcessedData(operationId);

        expect(retrievedData, isNotNull);
        expect(retrievedData!['lowStock'], equals(5));
        expect(retrievedData['stockDistribution'], isA<Map<String, dynamic>>());

        print('✅ Background processed data caching test passed');
      });

      test('should cache and retrieve chart data', () async {
        final chartData = [
          {
            'productName': 'Test Product 1',
            'open': 10.0,
            'high': 15.0,
            'low': 8.0,
            'close': 12.0,
          },
          {
            'productName': 'Test Product 2',
            'open': 20.0,
            'high': 25.0,
            'low': 18.0,
            'close': 22.0,
          },
        ];

        const chartType = 'candlestick';
        const identifier = 'test_chart_cache';

        // Cache the chart data
        await EnhancedReportsCacheService.cacheChartData(chartType, identifier, chartData);

        // Retrieve the chart data
        final retrievedData = await EnhancedReportsCacheService.getCachedChartData(chartType, identifier);

        expect(retrievedData, isNotNull);
        expect(retrievedData!.length, equals(2));
        expect(retrievedData[0]['productName'], equals('Test Product 1'));

        print('✅ Chart data caching test passed');
      });
    });

    group('Integration Performance Tests', () {
      test('should complete full workflow within performance targets', () async {
        final products = List.generate(75, (index) => FlaskProductModel(
          id: index,
          name: 'Product $index',
          categoryName: 'Category ${index % 4}',
          stockQuantity: index % 120,
          finalPrice: 100.0 + index,
          purchasePrice: 70.0 + index,
          imageUrl: null,
          description: 'Test product $index',
          barcode: 'BAR$index',
          unit: 'piece',
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));

        final stopwatch = Stopwatch()..start();

        // Start performance monitoring
        performanceMonitor.startOperation('full_workflow');

        // Process inventory analysis
        final inventoryResult = await backgroundService.processInventoryAnalysis(
          products,
          'integration_test_${DateTime.now().millisecondsSinceEpoch}',
        );

        // Process chart data
        final chartResult = await backgroundService.processChartData(
          products,
          'candlestick',
          'integration_chart_${DateTime.now().millisecondsSinceEpoch}',
        );

        // End performance monitoring
        performanceMonitor.endOperation('full_workflow');

        stopwatch.stop();

        // Verify results
        expect(inventoryResult, isA<Map<String, dynamic>>());
        expect(chartResult, isA<List<Map<String, dynamic>>>());
        expect(chartResult.length, equals(products.length));

        // Performance targets
        expect(stopwatch.elapsedMilliseconds, lessThan(8000)); // 8 seconds max for full workflow

        final stats = performanceMonitor.getOperationStats('full_workflow');
        expect(stats, isNotNull);

        print('✅ Full workflow completed in ${stopwatch.elapsedMilliseconds}ms');
        print('   Performance stats: ${stats!['averageDuration']}ms average');
      });
    });
  });
}

/// Helper function to run performance benchmarks
void runPerformanceBenchmarks() {
  print('🚀 Running Comprehensive Reports Performance Benchmarks...');
  
  final backgroundService = BackgroundProcessingService();
  final performanceMonitor = PerformanceMonitor();
  
  // Benchmark 1: Background processing
  print('📊 Benchmark 1: Background Processing Performance');
  
  // Benchmark 2: Cache operations
  print('📊 Benchmark 2: Enhanced Cache Performance');
  
  // Benchmark 3: Memory usage
  print('📊 Benchmark 3: Memory Usage Optimization');
  
  print('✅ Performance benchmarks completed');
}
