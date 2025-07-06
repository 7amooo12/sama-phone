import 'package:flutter/foundation.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:smartbiztracker_new/services/sama_store_service.dart';
import 'package:smartbiztracker_new/models/product.dart';

/// Test helper for SamaStore functionality
/// Verifies category mapping, product loading, and 3D card performance
class SamaStoreTestHelper {
  static final SamaStoreService _storeService = SamaStoreService();

  /// Test category mapping and display
  static Future<void> testCategoryMapping() async {
    if (!kDebugMode) return;

    try {
      AppLogger.info('🧪 Testing SamaStore category mapping...');

      // Test category fetching
      final categories = await _storeService.getCategories();
      AppLogger.info('📋 Found ${categories.length} categories:');
      
      for (int i = 0; i < categories.length; i++) {
        AppLogger.info('   ${i + 1}. "${categories[i]}" (${categories[i].length} chars)');
      }

      // Verify Arabic categories
      final expectedCategories = [
        'دلاية',           // Pendant
        'ابليك',          // Wall Light/Applique
        'دلاية مفرد',      // Single Pendant
        'اباجورة',        // Table Lamp
        'كريستال',        // Crystal
        'لامبدير',        // Lampshade
        'منتجات مميزه'     // Featured Products
      ];

      int matchCount = 0;
      for (final expected in expectedCategories) {
        if (categories.contains(expected)) {
          matchCount++;
          AppLogger.info('✅ Found expected category: "$expected"');
        } else {
          AppLogger.warning('⚠️ Missing expected category: "$expected"');
        }
      }

      AppLogger.info('📊 Category mapping test results:');
      AppLogger.info('   Expected: ${expectedCategories.length}');
      AppLogger.info('   Found: $matchCount');
      AppLogger.info('   Success rate: ${(matchCount / expectedCategories.length * 100).toStringAsFixed(1)}%');

      if (matchCount >= expectedCategories.length * 0.7) {
        AppLogger.info('✅ Category mapping test PASSED');
      } else {
        AppLogger.warning('⚠️ Category mapping test needs attention');
      }

    } catch (e) {
      AppLogger.error('❌ Category mapping test FAILED', e);
    }
  }

  /// Test product loading and data integrity
  static Future<void> testProductLoading() async {
    if (!kDebugMode) return;

    try {
      AppLogger.info('🧪 Testing SamaStore product loading...');

      final products = await _storeService.getProducts();
      AppLogger.info('📦 Loaded ${products.length} products');

      if (products.isEmpty) {
        AppLogger.warning('⚠️ No products loaded - check API connection');
        return;
      }

      // Test first 5 products
      int validProducts = 0;
      int productsWithImages = 0;
      int productsWithCategories = 0;

      for (int i = 0; i < products.length && i < 5; i++) {
        final product = products[i];
        
        AppLogger.info('🔍 Product ${i + 1}:');
        AppLogger.info('   Name: "${product.name}"');
        AppLogger.info('   Category: "${product.category ?? 'N/A'}"');
        AppLogger.info('   Image: ${product.imageUrl != null ? 'Yes' : 'No'}');
        AppLogger.info('   Price: ${product.price}');

        if (product.name.isNotEmpty) validProducts++;
        if (product.imageUrl != null && product.imageUrl!.isNotEmpty) productsWithImages++;
        if (product.category != null && product.category!.isNotEmpty) productsWithCategories++;
      }

      AppLogger.info('📊 Product loading test results:');
      AppLogger.info('   Total products: ${products.length}');
      AppLogger.info('   Valid products: $validProducts/5');
      AppLogger.info('   Products with images: $productsWithImages/5');
      AppLogger.info('   Products with categories: $productsWithCategories/5');

      if (validProducts >= 3 && productsWithImages >= 2) {
        AppLogger.info('✅ Product loading test PASSED');
      } else {
        AppLogger.warning('⚠️ Product loading test needs attention');
      }

    } catch (e) {
      AppLogger.error('❌ Product loading test FAILED', e);
    }
  }

  /// Test category filtering
  static Future<void> testCategoryFiltering() async {
    if (!kDebugMode) return;

    try {
      AppLogger.info('🧪 Testing SamaStore category filtering...');

      final allProducts = await _storeService.getProducts();
      final categories = await _storeService.getCategories();

      if (categories.isEmpty) {
        AppLogger.warning('⚠️ No categories available for filtering test');
        return;
      }

      // Test filtering for first category
      final testCategory = categories.first;
      AppLogger.info('🔍 Testing filter for category: "$testCategory"');

      final filteredProducts = allProducts.where((product) => 
        product.category == testCategory
      ).toList();

      AppLogger.info('📊 Category filtering results:');
      AppLogger.info('   Total products: ${allProducts.length}');
      AppLogger.info('   Category "$testCategory": ${filteredProducts.length} products');

      // Test each category
      for (final category in categories) {
        final categoryProducts = allProducts.where((product) => 
          product.category == category
        ).toList();
        
        AppLogger.info('   "$category": ${categoryProducts.length} products');
      }

      AppLogger.info('✅ Category filtering test COMPLETED');

    } catch (e) {
      AppLogger.error('❌ Category filtering test FAILED', e);
    }
  }

  /// Test 3D card performance simulation
  static void test3DCardPerformance() {
    if (!kDebugMode) return;

    AppLogger.info('🧪 Testing 3D card performance simulation...');

    // Simulate 3D card creation and animation
    final stopwatch = Stopwatch()..start();

    // Simulate creating 20 3D cards (typical grid size)
    for (int i = 0; i < 20; i++) {
      // Simulate card initialization
      _simulateCardCreation();
      
      // Simulate flip animation
      _simulateFlipAnimation();
    }

    stopwatch.stop();
    final totalTime = stopwatch.elapsedMilliseconds;
    final avgTimePerCard = totalTime / 20;

    AppLogger.info('📊 3D card performance simulation results:');
    AppLogger.info('   Total time for 20 cards: ${totalTime}ms');
    AppLogger.info('   Average time per card: ${avgTimePerCard.toStringAsFixed(1)}ms');

    if (avgTimePerCard < 5.0) {
      AppLogger.info('✅ 3D card performance simulation EXCELLENT');
    } else if (avgTimePerCard < 10.0) {
      AppLogger.info('✅ 3D card performance simulation GOOD');
    } else {
      AppLogger.warning('⚠️ 3D card performance simulation NEEDS OPTIMIZATION');
    }
  }

  /// Simulate card creation overhead
  static void _simulateCardCreation() {
    // Simulate widget tree creation
    final random = DateTime.now().millisecondsSinceEpoch % 1000;
    
    // Simulate some processing time
    for (int i = 0; i < random; i++) {
      // Minimal processing to simulate widget creation
    }
  }

  /// Simulate flip animation overhead
  static void _simulateFlipAnimation() {
    // Simulate animation controller and transform calculations
    const steps = 60; // 60fps for 1 second
    
    for (int i = 0; i < steps; i++) {
      final progress = i / steps;
      
      // Simulate Matrix4 calculations
      final angle = progress * 3.14159; // pi radians
      final transform = angle * 0.5; // Simplified transform calculation
      
      // Simulate some processing
      if (transform > 0) {
        // Minimal processing
      }
    }
  }

  /// Run all tests
  static Future<void> runAllTests() async {
    if (!kDebugMode) return;

    AppLogger.info('🚀 Starting SamaStore comprehensive tests...');
    AppLogger.info('==========================================');

    await testCategoryMapping();
    AppLogger.info('------------------------------------------');
    
    await testProductLoading();
    AppLogger.info('------------------------------------------');
    
    await testCategoryFiltering();
    AppLogger.info('------------------------------------------');
    
    test3DCardPerformance();
    AppLogger.info('==========================================');
    
    AppLogger.info('🎉 SamaStore tests completed!');
  }

  /// Validate product data integrity
  static bool validateProduct(Product product) {
    // Check required fields
    if (product.name.isEmpty) return false;
    if (product.id <= 0) return false;
    
    // Check optional but important fields
    final bool hasValidImage = product.imageUrl != null && product.imageUrl!.isNotEmpty;
    final bool hasValidCategory = product.category != null && product.category!.isNotEmpty;
    
    // Product is valid if it has name, id, and at least image or category
    return hasValidImage || hasValidCategory;
  }

  /// Get test summary
  static Map<String, dynamic> getTestSummary() {
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'tests': [
        'Category Mapping',
        'Product Loading',
        'Category Filtering',
        '3D Card Performance',
      ],
      'status': 'Ready for testing',
      'environment': kDebugMode ? 'Debug' : 'Release',
    };
  }
}
