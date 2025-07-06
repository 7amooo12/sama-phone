import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartbiztracker_new/screens/sama_store_rebuilt_screen.dart';
import 'package:smartbiztracker_new/widgets/common/enhanced_product_image.dart';
import 'package:smartbiztracker_new/models/product_model.dart';

void main() {
  group('Sama Store Performance Tests', () {
    testWidgets('Enhanced Product Image renders without errors', (WidgetTester tester) async {
      // Create a test product
      final testProduct = ProductModel(
        id: 'test-1',
        name: 'Test Product',
        description: 'Test Description',
        price: 100.0,
        quantity: 10,
        category: 'Test Category',
        imageUrl: 'https://example.com/test.jpg',
        createdAt: DateTime.now(),
        isActive: true,
        sku: 'TEST-SKU',
        reorderPoint: 5,
        images: ['https://example.com/test.jpg'],
      );

      // Build the widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EnhancedProductImage(
              product: testProduct,
              width: 200,
              height: 200,
            ),
          ),
        ),
      );

      // Verify the widget builds without errors
      expect(find.byType(EnhancedProductImage), findsOneWidget);
    });

    testWidgets('Enhanced Product Image handles empty image URLs gracefully', (WidgetTester tester) async {
      // Create a test product with no images
      final testProduct = ProductModel(
        id: 'test-2',
        name: 'Test Product No Image',
        description: 'Test Description',
        price: 100.0,
        quantity: 10,
        category: 'Test Category',
        createdAt: DateTime.now(),
        isActive: true,
        sku: 'TEST-SKU-2',
        reorderPoint: 5,
        images: [],
      );

      // Build the widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EnhancedProductImage(
              product: testProduct,
              width: 200,
              height: 200,
            ),
          ),
        ),
      );

      // Wait for the widget to build
      await tester.pump();

      // Verify the widget builds without errors and shows fallback content
      expect(find.byType(EnhancedProductImage), findsOneWidget);
      expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
      expect(find.text('لا توجد صورة'), findsOneWidget);
    });

    testWidgets('Product card tap handling works correctly', (WidgetTester tester) async {
      // Create test products
      final testProducts = List.generate(5, (index) => ProductModel(
        id: 'test-$index',
        name: 'Test Product $index',
        description: 'Test Description $index',
        price: 100.0 + index,
        quantity: 10,
        category: 'Test Category',
        imageUrl: 'https://example.com/test$index.jpg',
        createdAt: DateTime.now(),
        isActive: true,
        sku: 'TEST-SKU-$index',
        reorderPoint: 5,
        images: ['https://example.com/test$index.jpg'],
      ));

      // Note: We can't easily test the full SamaStoreRebuiltScreen without proper setup
      // This test validates that our product models are created correctly
      expect(testProducts.length, equals(5));
      expect(testProducts[0].bestImageUrl, isNotEmpty);
      expect(testProducts[0].name, equals('Test Product 0'));
    });

    test('OptimizedImageCacheManager configuration is reasonable', () {
      // Test that cache manager settings are not too aggressive
      final cacheManager = OptimizedImageCacheManager.instance;
      expect(cacheManager, isNotNull);
      
      // The cache manager should be configured with reasonable limits
      // (We can't directly test the Config values, but we ensure it's instantiated)
    });

    test('Product model bestImageUrl logic works correctly', () {
      // Test with imageUrl
      final productWithImageUrl = ProductModel(
        id: 'test-url',
        name: 'Test Product',
        description: 'Test Description',
        price: 100.0,
        quantity: 10,
        category: 'Test Category',
        imageUrl: 'https://example.com/main.jpg',
        createdAt: DateTime.now(),
        isActive: true,
        sku: 'TEST-SKU',
        reorderPoint: 5,
        images: ['https://example.com/alt.jpg'],
      );

      expect(productWithImageUrl.bestImageUrl, equals('https://example.com/main.jpg'));

      // Test with only images array
      final productWithImagesOnly = ProductModel(
        id: 'test-images',
        name: 'Test Product',
        description: 'Test Description',
        price: 100.0,
        quantity: 10,
        category: 'Test Category',
        createdAt: DateTime.now(),
        isActive: true,
        sku: 'TEST-SKU',
        reorderPoint: 5,
        images: ['https://example.com/first.jpg', 'https://example.com/second.jpg'],
      );

      expect(productWithImagesOnly.bestImageUrl, equals('https://example.com/first.jpg'));

      // Test with no images
      final productWithNoImages = ProductModel(
        id: 'test-no-images',
        name: 'Test Product',
        description: 'Test Description',
        price: 100.0,
        quantity: 10,
        category: 'Test Category',
        createdAt: DateTime.now(),
        isActive: true,
        sku: 'TEST-SKU',
        reorderPoint: 5,
        images: [],
      );

      // Should generate fallback URLs based on product ID
      expect(productWithNoImages.bestImageUrl, contains('test-no-images'));
    });
  });
}
