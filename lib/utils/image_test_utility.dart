import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/product_model.dart';
import 'app_logger.dart';

/// Utility class for testing and debugging image loading issues
class ImageTestUtility {
  
  /// Test if a single image URL is accessible
  static Future<ImageTestResult> testImageUrl(String url) async {
    if (url.isEmpty || url == 'null' || url == 'undefined') {
      return ImageTestResult(
        url: url,
        isAccessible: false,
        statusCode: 0,
        error: 'URL is empty or invalid',
      );
    }

    try {
      final uri = Uri.tryParse(url);
      if (uri == null) {
        return ImageTestResult(
          url: url,
          isAccessible: false,
          statusCode: 0,
          error: 'Invalid URL format',
        );
      }

      AppLogger.info('🔍 Testing image URL: $url');
      
      final response = await http.head(uri).timeout(
        const Duration(seconds: 10),
      );

      final isAccessible = response.statusCode >= 200 && response.statusCode < 300;
      
      return ImageTestResult(
        url: url,
        isAccessible: isAccessible,
        statusCode: response.statusCode,
        contentType: response.headers['content-type'],
        contentLength: response.headers['content-length'],
        error: isAccessible ? null : 'HTTP ${response.statusCode}',
      );
    } catch (e) {
      AppLogger.error('❌ Error testing image URL: $url - $e');
      return ImageTestResult(
        url: url,
        isAccessible: false,
        statusCode: 0,
        error: e.toString(),
      );
    }
  }

  /// Test all image URLs for a product
  static Future<ProductImageTestResult> testProductImages(ProductModel product) async {
    AppLogger.info('🧪 Testing images for product: ${product.name}');
    
    final results = <ImageTestResult>[];
    
    // Test main imageUrl
    if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
      final result = await testImageUrl(product.imageUrl!);
      results.add(result);
    }
    
    // Test images list
    for (final imageUrl in product.images) {
      if (imageUrl.isNotEmpty) {
        final result = await testImageUrl(imageUrl);
        results.add(result);
      }
    }
    
    // Test bestImageUrl
    if (product.bestImageUrl.isNotEmpty) {
      final result = await testImageUrl(product.bestImageUrl);
      results.add(result);
    }
    
    final accessibleCount = results.where((r) => r.isAccessible).length;
    
    return ProductImageTestResult(
      product: product,
      imageTests: results,
      hasAccessibleImages: accessibleCount > 0,
      accessibleImageCount: accessibleCount,
      totalImageCount: results.length,
    );
  }

  /// Test images for multiple products
  static Future<List<ProductImageTestResult>> testMultipleProducts(
    List<ProductModel> products, {
    int maxProducts = 10,
  }) async {
    AppLogger.info('🧪 Testing images for ${products.length} products (max: $maxProducts)');
    
    final results = <ProductImageTestResult>[];
    final productsToTest = products.take(maxProducts).toList();
    
    for (final product in productsToTest) {
      final result = await testProductImages(product);
      results.add(result);
      
      // Small delay to avoid overwhelming the server
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    return results;
  }

  /// Generate a summary report of image test results
  static String generateTestReport(List<ProductImageTestResult> results) {
    final buffer = StringBuffer();
    buffer.writeln('📊 Image Test Report');
    buffer.writeln('==================');
    buffer.writeln();
    
    final totalProducts = results.length;
    final productsWithImages = results.where((r) => r.hasAccessibleImages).length;
    final productsWithoutImages = totalProducts - productsWithImages;
    
    buffer.writeln('Summary:');
    buffer.writeln('- Total products tested: $totalProducts');
    buffer.writeln('- Products with accessible images: $productsWithImages');
    buffer.writeln('- Products without accessible images: $productsWithoutImages');
    buffer.writeln();
    
    if (productsWithoutImages > 0) {
      buffer.writeln('Products without accessible images:');
      for (final result in results.where((r) => !r.hasAccessibleImages)) {
        buffer.writeln('- ${result.product.name} (ID: ${result.product.id})');
        for (final imageTest in result.imageTests) {
          buffer.writeln('  - ${imageTest.url}: ${imageTest.error ?? 'Unknown error'}');
        }
      }
      buffer.writeln();
    }
    
    return buffer.toString();
  }
}

/// Result of testing a single image URL
class ImageTestResult {
  final String url;
  final bool isAccessible;
  final int statusCode;
  final String? contentType;
  final String? contentLength;
  final String? error;

  ImageTestResult({
    required this.url,
    required this.isAccessible,
    required this.statusCode,
    this.contentType,
    this.contentLength,
    this.error,
  });

  @override
  String toString() {
    return 'ImageTestResult(url: $url, accessible: $isAccessible, status: $statusCode, error: $error)';
  }
}

/// Result of testing all images for a product
class ProductImageTestResult {
  final ProductModel product;
  final List<ImageTestResult> imageTests;
  final bool hasAccessibleImages;
  final int accessibleImageCount;
  final int totalImageCount;

  ProductImageTestResult({
    required this.product,
    required this.imageTests,
    required this.hasAccessibleImages,
    required this.accessibleImageCount,
    required this.totalImageCount,
  });

  @override
  String toString() {
    return 'ProductImageTestResult(product: ${product.name}, accessible: $accessibleImageCount/$totalImageCount)';
  }
}
