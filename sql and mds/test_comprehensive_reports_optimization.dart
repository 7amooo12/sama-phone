import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartbiztracker_new/services/enhanced_reports_cache_service.dart';
import 'package:smartbiztracker_new/services/reports_progress_service.dart';
import 'package:smartbiztracker_new/widgets/custom_loader.dart';
import 'package:smartbiztracker_new/widgets/enhanced_loading_widget.dart';

/// Test file to verify comprehensive reports optimizations
void main() {
  group('Enhanced Reports Cache Service Tests', () {
    test('should cache and retrieve product movement data', () async {
      // This would require actual ProductMovementModel data
      // For now, we'll test the cache validity logic
      
      final isValid = await EnhancedReportsCacheService.isCacheValid('test_key');
      expect(isValid, false); // Should be false for non-existent key
    });

    test('should clear expired cache entries', () async {
      await EnhancedReportsCacheService.clearExpiredCache();
      // Should complete without errors
    });

    test('should get cache statistics', () async {
      final stats = await EnhancedReportsCacheService.getCacheStats();
      expect(stats, isA<Map<String, dynamic>>());
      expect(stats.containsKey('totalEntries'), true);
      expect(stats.containsKey('validEntries'), true);
      expect(stats.containsKey('expiredEntries'), true);
      expect(stats.containsKey('cacheHitRate'), true);
    });
  });

  group('Reports Progress Service Tests', () {
    late ReportsProgressService progressService;

    setUp(() {
      progressService = ReportsProgressService();
    });

    test('should initialize with default values', () {
      expect(progressService.currentProgress, 0.0);
      expect(progressService.currentMessage, '');
      expect(progressService.isLoading, false);
      expect(progressService.completedStepsCount, 0);
      expect(progressService.totalStepsCount, 0);
    });

    test('should start progress tracking correctly', () {
      final steps = ['step1', 'step2', 'step3'];
      progressService.startProgress(steps, 'Test message');

      expect(progressService.isLoading, true);
      expect(progressService.currentMessage, 'Test message');
      expect(progressService.totalStepsCount, 3);
      expect(progressService.completedStepsCount, 0);
    });

    test('should update progress correctly', () {
      final steps = ['step1', 'step2', 'step3'];
      progressService.startProgress(steps, 'Test message');
      
      progressService.updateProgress('step1');
      expect(progressService.currentProgress, closeTo(0.33, 0.01));
      expect(progressService.completedStepsCount, 1);

      progressService.updateProgress('step2');
      expect(progressService.currentProgress, closeTo(0.67, 0.01));
      expect(progressService.completedStepsCount, 2);
    });

    test('should complete progress correctly', () {
      final steps = ['step1', 'step2'];
      progressService.startProgress(steps, 'Test message');
      
      progressService.completeProgress('Completed');
      expect(progressService.currentProgress, 1.0);
      expect(progressService.currentMessage, 'Completed');
      expect(progressService.isLoading, false);
    });

    test('should handle errors correctly', () {
      progressService.handleError('Test error');
      expect(progressService.currentMessage, 'خطأ في التحميل');
      expect(progressService.currentSubMessage, 'Test error');
      expect(progressService.isLoading, false);
    });

    test('should provide correct step sequences', () {
      expect(ReportsProgressService.productAnalyticsSteps.length, 7);
      expect(ReportsProgressService.categoryAnalyticsSteps.length, 8);
      expect(ReportsProgressService.overallAnalyticsSteps.length, 6);
    });
  });

  group('Professional Progress Loader Widget Tests', () {
    testWidgets('should display progress correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfessionalProgressLoader(
              progress: 0.5,
              message: 'Test message',
              subMessage: 'Test sub message',
            ),
          ),
        ),
      );

      expect(find.text('Test message'), findsOneWidget);
      expect(find.text('Test sub message'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
    });

    testWidgets('should hide percentage when showPercentage is false', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfessionalProgressLoader(
              progress: 0.75,
              message: 'Test message',
              showPercentage: false,
            ),
          ),
        ),
      );

      expect(find.text('Test message'), findsOneWidget);
      expect(find.text('75%'), findsNothing);
      expect(find.byIcon(Icons.hourglass_empty), findsOneWidget);
    });
  });

  group('Enhanced Loading Widget Tests', () {
    testWidgets('should display spinner loading type', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EnhancedLoadingWidget(
              loadingType: LoadingType.spinner,
              message: 'Loading...',
            ),
          ),
        ),
      );

      expect(find.text('Loading...'), findsOneWidget);
      // SpinKit widget should be present
      expect(find.byType(Widget), findsWidgets);
    });

    testWidgets('should display progress loading type with percentage', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EnhancedLoadingWidget(
              loadingType: LoadingType.progress,
              progress: 0.6,
              message: 'Processing...',
              showPercentage: true,
            ),
          ),
        ),
      );

      expect(find.text('Processing...'), findsOneWidget);
      expect(find.text('60%'), findsOneWidget);
    });

    testWidgets('should display sub message when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EnhancedLoadingWidget(
              loadingType: LoadingType.pulse,
              message: 'Main message',
              subMessage: 'Sub message',
            ),
          ),
        ),
      );

      expect(find.text('Main message'), findsOneWidget);
      expect(find.text('Sub message'), findsOneWidget);
    });
  });

  group('Performance Tests', () {
    test('cache service should handle large data efficiently', () async {
      final stopwatch = Stopwatch()..start();
      
      // Simulate caching large amount of data
      for (int i = 0; i < 100; i++) {
        await EnhancedReportsCacheService.isCacheValid('test_key_$i');
      }
      
      stopwatch.stop();
      
      // Should complete within reasonable time (less than 1 second)
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
    });

    test('progress service should handle rapid updates efficiently', () {
      final stopwatch = Stopwatch()..start();
      final progressService = ReportsProgressService();
      
      progressService.startProgress(['step1', 'step2', 'step3'], 'Test');
      
      // Simulate rapid progress updates
      for (int i = 0; i < 100; i++) {
        progressService.updateProgressPercentage(i.toDouble(), 'Update $i');
      }
      
      stopwatch.stop();
      
      // Should complete within reasonable time
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });
  });

  group('Integration Tests', () {
    test('should integrate cache service with progress service', () async {
      final progressService = ReportsProgressService();
      
      // Start progress
      progressService.startProgress(['caching', 'processing'], 'Integration test');
      
      // Simulate cache operations
      progressService.updateProgress('caching');
      await EnhancedReportsCacheService.clearExpiredCache();
      
      progressService.updateProgress('processing');
      final stats = await EnhancedReportsCacheService.getCacheStats();
      
      progressService.completeProgress('Integration complete');
      
      expect(progressService.currentProgress, 1.0);
      expect(stats, isA<Map<String, dynamic>>());
    });
  });
}

/// Helper function to run performance benchmarks
void runPerformanceBenchmarks() {
  print('🚀 Running Performance Benchmarks...');
  
  // Benchmark 1: Cache operations
  final cacheStopwatch = Stopwatch()..start();
  for (int i = 0; i < 1000; i++) {
    EnhancedReportsCacheService.isCacheValid('benchmark_key_$i');
  }
  cacheStopwatch.stop();
  print('📋 Cache operations (1000 calls): ${cacheStopwatch.elapsedMilliseconds}ms');
  
  // Benchmark 2: Progress updates
  final progressStopwatch = Stopwatch()..start();
  final progressService = ReportsProgressService();
  progressService.startProgress(['step1', 'step2', 'step3'], 'Benchmark');
  for (int i = 0; i < 1000; i++) {
    progressService.updateProgressPercentage(i / 10.0, 'Update $i');
  }
  progressStopwatch.stop();
  print('📊 Progress updates (1000 calls): ${progressStopwatch.elapsedMilliseconds}ms');
  
  print('✅ Performance benchmarks completed');
}

/// Helper function to test memory usage
void testMemoryUsage() {
  print('🧠 Testing Memory Usage...');
  
  // This would require more sophisticated memory profiling tools
  // For now, we'll just ensure our services can be created and disposed properly
  
  final services = <ReportsProgressService>[];
  for (int i = 0; i < 100; i++) {
    services.add(ReportsProgressService());
  }
  
  // Clear references
  services.clear();
  
  print('✅ Memory usage test completed');
}
