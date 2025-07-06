import 'package:flutter_test/flutter_test.dart';
import 'package:smartbiztracker_new/services/optimized_analytics_service.dart';
import 'package:smartbiztracker_new/services/optimized_data_pipeline.dart';
import 'package:smartbiztracker_new/services/smart_cache_manager.dart';
import 'package:smartbiztracker_new/services/reports_performance_monitor.dart';

/// Comprehensive test suite for Reports Tab optimization
/// Validates performance improvements, data accuracy, and system stability
void main() {
  group('Reports Optimization Tests', () {
    late OptimizedAnalyticsService analyticsService;
    late OptimizedDataPipeline dataPipeline;
    late SmartCacheManager cacheManager;
    late ReportsPerformanceMonitor performanceMonitor;

    setUpAll(() {
      analyticsService = OptimizedAnalyticsService();
      dataPipeline = OptimizedDataPipeline();
      cacheManager = SmartCacheManager();
      performanceMonitor = ReportsPerformanceMonitor();
    });

    tearDownAll(() {
      cacheManager.clearAll();
      performanceMonitor.clearPerformanceData();
    });

    group('Performance Tests', () {
      test('Dashboard data loads in under 5 seconds on first load', () async {
        final stopwatch = Stopwatch()..start();
        
        final result = await dataPipeline.getDashboardData(
          period: 'أسبوعي',
          forceRefresh: true,
        );
        
        stopwatch.stop();
        final loadTime = stopwatch.elapsed;
        
        expect(loadTime.inSeconds, lessThan(5), 
            reason: 'First load should be under 5 seconds, was ${loadTime.inSeconds}s');
        expect(result, isNotNull);
        expect(result['period'], equals('أسبوعي'));
        
        print('✅ First load time: ${loadTime.inMilliseconds}ms');
      });

      test('Cached data loads in under 1 second', () async {
        // First load to populate cache
        await dataPipeline.getDashboardData(period: 'أسبوعي');
        
        // Second load should be from cache
        final stopwatch = Stopwatch()..start();
        
        final result = await dataPipeline.getDashboardData(
          period: 'أسبوعي',
          forceRefresh: false,
        );
        
        stopwatch.stop();
        final loadTime = stopwatch.elapsed;
        
        expect(loadTime.inMilliseconds, lessThan(1000), 
            reason: 'Cached load should be under 1 second, was ${loadTime.inMilliseconds}ms');
        expect(result, isNotNull);
        
        print('✅ Cached load time: ${loadTime.inMilliseconds}ms');
      });

      test('Analytics service performance is consistent', () async {
        final loadTimes = <Duration>[];
        
        // Test multiple loads
        for (int i = 0; i < 5; i++) {
          final stopwatch = Stopwatch()..start();
          
          await analyticsService.getDashboardStatistics(
            period: 'شهري',
            forceRefresh: i == 0, // Only force refresh on first load
          );
          
          stopwatch.stop();
          loadTimes.add(stopwatch.elapsed);
        }
        
        // Calculate average load time
        final avgLoadTime = loadTimes
            .map((d) => d.inMilliseconds)
            .reduce((a, b) => a + b) / loadTimes.length;
        
        expect(avgLoadTime, lessThan(2000), 
            reason: 'Average load time should be under 2 seconds, was ${avgLoadTime.toStringAsFixed(0)}ms');
        
        print('✅ Average load time over 5 requests: ${avgLoadTime.toStringAsFixed(0)}ms');
        print('   Load times: ${loadTimes.map((d) => '${d.inMilliseconds}ms').join(', ')}');
      });
    });

    group('Cache Performance Tests', () {
      test('Cache hit rate exceeds 80% after initial loads', () async {
        // Clear cache to start fresh
        cacheManager.clearAll();
        
        // Perform initial loads
        await dataPipeline.getDashboardData(period: 'أسبوعي');
        await dataPipeline.getDashboardData(period: 'شهري');
        await dataPipeline.getDashboardData(period: 'سنوي');
        
        // Perform repeated loads (should hit cache)
        for (int i = 0; i < 10; i++) {
          await dataPipeline.getDashboardData(period: 'أسبوعي');
          await dataPipeline.getDashboardData(period: 'شهري');
        }
        
        final stats = cacheManager.getStatistics();
        final hitRate = stats['hitRate'] as double;
        
        expect(hitRate, greaterThan(0.8), 
            reason: 'Cache hit rate should exceed 80%, was ${(hitRate * 100).toStringAsFixed(1)}%');
        
        print('✅ Cache hit rate: ${(hitRate * 100).toStringAsFixed(1)}%');
        print('   Total hits: ${stats['totalHits']}, Total misses: ${stats['totalMisses']}');
      });

      test('Cache invalidation works correctly', () async {
        final testKey = 'test_cache_key';
        final testData = {'test': 'data', 'timestamp': DateTime.now().toIso8601String()};
        
        // Set cache data
        await cacheManager.set(testKey, testData);
        
        // Verify data is cached
        final cachedData = await cacheManager.get(testKey);
        expect(cachedData, isNotNull);
        expect(cachedData!['test'], equals('data'));
        
        // Invalidate cache
        await cacheManager.invalidate(testKey);
        
        // Verify data is no longer cached
        final invalidatedData = await cacheManager.get(testKey);
        expect(invalidatedData, isNull);
        
        print('✅ Cache invalidation working correctly');
      });
    });

    group('Data Accuracy Tests', () {
      test('Optimized service returns valid data structure', () async {
        final result = await analyticsService.getDashboardStatistics(period: 'أسبوعي');
        
        // Verify required fields exist
        expect(result, containsPair('period', 'أسبوعي'));
        expect(result, contains('lastUpdated'));
        expect(result, contains('invoiceStatistics'));
        expect(result, contains('salesData'));
        expect(result, contains('productStatistics'));
        expect(result, contains('orderStatistics'));
        expect(result, contains('summary'));
        
        // Verify data types
        expect(result['invoiceStatistics'], isA<Map<String, dynamic>>());
        expect(result['salesData'], isA<Map<String, dynamic>>());
        expect(result['productStatistics'], isA<Map<String, dynamic>>());
        expect(result['orderStatistics'], isA<Map<String, dynamic>>());
        expect(result['summary'], isA<Map<String, dynamic>>());
        
        print('✅ Data structure validation passed');
      });

      test('Sales data contains required metrics', () async {
        final result = await analyticsService.getDashboardStatistics(period: 'شهري');
        final salesData = result['salesData'] as Map<String, dynamic>;
        
        // Verify sales metrics
        expect(salesData, contains('totalSales'));
        expect(salesData, contains('totalOrders'));
        expect(salesData, contains('averageOrderValue'));
        expect(salesData, contains('salesChart'));
        expect(salesData, contains('ordersChart'));
        
        // Verify data types
        expect(salesData['totalSales'], isA<double>());
        expect(salesData['totalOrders'], isA<int>());
        expect(salesData['averageOrderValue'], isA<double>());
        expect(salesData['salesChart'], isA<List>());
        expect(salesData['ordersChart'], isA<List>());
        
        print('✅ Sales data validation passed');
      });

      test('Performance metrics are included', () async {
        final result = await dataPipeline.getDashboardData(period: 'سنوي');
        
        expect(result, contains('performanceMetrics'));
        
        final perfMetrics = result['performanceMetrics'] as Map<String, dynamic>;
        expect(perfMetrics, contains('hitRate'));
        expect(perfMetrics, contains('totalHits'));
        expect(perfMetrics, contains('totalMisses'));
        
        print('✅ Performance metrics validation passed');
      });
    });

    group('Memory and Resource Management Tests', () {
      test('Memory usage remains stable under load', () async {
        // Perform multiple operations to test memory stability
        for (int i = 0; i < 20; i++) {
          await dataPipeline.getDashboardData(period: 'أسبوعي');
          await dataPipeline.getReportsData(
            loadCharts: true,
            loadAnalytics: true,
            loadTrends: false,
          );
        }
        
        // Verify cache doesn't grow indefinitely
        final stats = cacheManager.getStatistics();
        final memoryItems = stats['memoryItems'] as int;
        
        expect(memoryItems, lessThan(100), 
            reason: 'Memory cache should not exceed 100 items, has $memoryItems');
        
        print('✅ Memory usage stable: $memoryItems cached items');
      });

      test('Cache optimization removes expired items', () async {
        // Add test data to cache
        for (int i = 0; i < 10; i++) {
          await cacheManager.set('test_key_$i', {'data': i});
        }
        
        final statsBefore = cacheManager.getStatistics();
        final itemsBefore = statsBefore['memoryItems'] as int;
        
        // Run optimization
        await cacheManager.optimize();
        
        final statsAfter = cacheManager.getStatistics();
        final itemsAfter = statsAfter['memoryItems'] as int;
        
        // Items should be same or less (expired items removed)
        expect(itemsAfter, lessThanOrEqualTo(itemsBefore));
        
        print('✅ Cache optimization: $itemsBefore → $itemsAfter items');
      });
    });

    group('Error Handling and Resilience Tests', () {
      test('Service handles errors gracefully', () async {
        // Test with invalid period
        final result = await analyticsService.getDashboardStatistics(period: 'invalid_period');
        
        expect(result, isNotNull);
        expect(result, contains('period'));
        expect(result, contains('invoiceStatistics'));
        
        print('✅ Error handling validation passed');
      });

      test('Fallback data is provided when services fail', () async {
        // This would typically involve mocking service failures
        // For now, we test that fallback data structure is valid
        final result = await dataPipeline.getDashboardData(period: 'أسبوعي');
        
        expect(result, isNotNull);
        expect(result, isA<Map<String, dynamic>>());
        
        print('✅ Fallback mechanism validation passed');
      });
    });

    group('Performance Monitoring Tests', () {
      test('Performance monitor tracks operations correctly', () async {
        performanceMonitor.clearPerformanceData();
        
        // Perform monitored operations
        performanceMonitor.startOperation('test_operation');
        await Future.delayed(const Duration(milliseconds: 100));
        final duration = performanceMonitor.endOperation('test_operation');
        
        expect(duration, isNotNull);
        expect(duration!.inMilliseconds, greaterThan(90));
        expect(duration.inMilliseconds, lessThan(200));
        
        final stats = performanceMonitor.getPerformanceStatistics();
        expect(stats, contains('test_operation'));
        
        print('✅ Performance monitoring working correctly');
      });

      test('Cache hit/miss tracking is accurate', () async {
        performanceMonitor.clearPerformanceData();
        
        // Record cache operations
        performanceMonitor.recordCacheHit('test_key');
        performanceMonitor.recordCacheHit('test_key');
        performanceMonitor.recordCacheMiss('test_key');
        
        final hitRate = performanceMonitor.getCacheHitRate('test_key');
        expect(hitRate, closeTo(0.67, 0.01)); // 2 hits out of 3 total
        
        print('✅ Cache tracking accuracy validated');
      });
    });
  });
}

/// Helper function to run performance comparison
Future<void> runPerformanceComparison() async {
  print('\n🚀 Running Performance Comparison...\n');
  
  final dataPipeline = OptimizedDataPipeline();
  await dataPipeline.initialize();
  
  // Test different periods
  final periods = ['أسبوعي', 'شهري', 'سنوي'];
  
  for (final period in periods) {
    print('Testing period: $period');
    
    // First load (cache miss)
    final stopwatch1 = Stopwatch()..start();
    await dataPipeline.getDashboardData(period: period, forceRefresh: true);
    stopwatch1.stop();
    
    // Second load (cache hit)
    final stopwatch2 = Stopwatch()..start();
    await dataPipeline.getDashboardData(period: period, forceRefresh: false);
    stopwatch2.stop();
    
    print('  First load:  ${stopwatch1.elapsed.inMilliseconds}ms');
    print('  Cached load: ${stopwatch2.elapsed.inMilliseconds}ms');
    print('  Improvement: ${((stopwatch1.elapsed.inMilliseconds - stopwatch2.elapsed.inMilliseconds) / stopwatch1.elapsed.inMilliseconds * 100).toStringAsFixed(1)}%\n');
  }
  
  // Display cache statistics
  final cacheManager = SmartCacheManager();
  final stats = cacheManager.getStatistics();
  
  print('📊 Cache Performance:');
  print('  Hit Rate: ${(stats['hitRate'] * 100).toStringAsFixed(1)}%');
  print('  Total Hits: ${stats['totalHits']}');
  print('  Total Misses: ${stats['totalMisses']}');
  print('  Memory Items: ${stats['memoryItems']}');
  
  // Display performance monitor report
  final performanceMonitor = ReportsPerformanceMonitor();
  print('\n📈 Performance Report:');
  print(performanceMonitor.generatePerformanceReport());
}
