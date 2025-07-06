import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/product_model.dart';
import 'app_logger.dart';

/// مساعد تشخيص مشاكل الصور
/// يساعد في اختبار وتشخيص مشاكل تحميل صور المنتجات
class ImageDebugHelper {
  
  /// اختبار إمكانية الوصول لرابط الصورة
  static Future<ImageTestResult> testImageUrl(String url) async {
    if (url.isEmpty || url == 'null') {
      return ImageTestResult(
        url: url,
        isValid: false,
        error: 'URL فارغ أو null',
      );
    }

    try {
      final uri = Uri.tryParse(url);
      if (uri == null) {
        return ImageTestResult(
          url: url,
          isValid: false,
          error: 'URL غير صالح',
        );
      }

      AppLogger.info('🔍 اختبار رابط الصورة: $url');
      
      final response = await http.head(uri).timeout(
        const Duration(seconds: 10),
      );

      final isValid = response.statusCode == 200;
      final contentType = response.headers['content-type'] ?? '';
      final contentLength = response.headers['content-length'] ?? '0';
      
      AppLogger.info('📊 نتيجة اختبار الصورة: $url - Status: ${response.statusCode} - Type: $contentType - Size: $contentLength');

      return ImageTestResult(
        url: url,
        isValid: isValid,
        statusCode: response.statusCode,
        contentType: contentType,
        contentLength: int.tryParse(contentLength) ?? 0,
        error: isValid ? null : 'HTTP ${response.statusCode}',
      );
    } catch (e) {
      AppLogger.error('❌ خطأ في اختبار رابط الصورة: $url - $e');
      return ImageTestResult(
        url: url,
        isValid: false,
        error: e.toString(),
      );
    }
  }

  /// اختبار جميع روابط الصور للمنتج
  static Future<ProductImageTestResult> testProductImages(ProductModel product) async {
    AppLogger.info('🔍 اختبار صور المنتج: ${product.name}');

    final results = <ImageTestResult>[];
    
    // اختبار bestImageUrl
    if (product.bestImageUrl.isNotEmpty) {
      final result = await testImageUrl(product.bestImageUrl);
      results.add(result.copyWith(source: 'bestImageUrl'));
    }

    // اختبار imageUrl الأساسي
    if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
      final result = await testImageUrl(product.imageUrl!);
      results.add(result.copyWith(source: 'imageUrl'));
    }

    // اختبار قائمة الصور
    for (int i = 0; i < product.images.length; i++) {
      final imageUrl = product.images[i];
      if (imageUrl.isNotEmpty) {
        final result = await testImageUrl(imageUrl);
        results.add(result.copyWith(source: 'images[$i]'));
      }
    }

    final validResults = results.where((r) => r.isValid).toList();
    final bestResult = validResults.isNotEmpty ? validResults.first : null;

    AppLogger.info('📊 نتائج اختبار صور المنتج ${product.name}: ${validResults.length}/${results.length} صالحة');

    return ProductImageTestResult(
      product: product,
      allResults: results,
      validResults: validResults,
      bestResult: bestResult,
    );
  }

  /// اختبار مجموعة من المنتجات
  static Future<List<ProductImageTestResult>> testMultipleProducts(
    List<ProductModel> products, {
    int maxConcurrent = 5,
  }) async {
    AppLogger.info('🔍 اختبار صور ${products.length} منتج...');

    final results = <ProductImageTestResult>[];
    
    // معالجة المنتجات في مجموعات لتجنب الحمل الزائد
    for (int i = 0; i < products.length; i += maxConcurrent) {
      final batch = products.skip(i).take(maxConcurrent).toList();
      final batchResults = await Future.wait(
        batch.map((product) => testProductImages(product)),
      );
      results.addAll(batchResults);
      
      AppLogger.info('✅ تم اختبار ${results.length}/${products.length} منتج');
    }

    return results;
  }

  /// إنشاء تقرير مفصل عن حالة الصور
  static String generateImageReport(List<ProductImageTestResult> results) {
    final buffer = StringBuffer();
    buffer.writeln('📊 تقرير حالة صور المنتجات');
    buffer.writeln('=' * 50);
    
    final totalProducts = results.length;
    final productsWithValidImages = results.where((r) => r.hasValidImages).length;
    final productsWithoutImages = totalProducts - productsWithValidImages;
    
    buffer.writeln('إجمالي المنتجات: $totalProducts');
    buffer.writeln('منتجات بصور صالحة: $productsWithValidImages');
    buffer.writeln('منتجات بدون صور: $productsWithoutImages');
    buffer.writeln('نسبة النجاح: ${(productsWithValidImages / totalProducts * 100).toStringAsFixed(1)}%');
    buffer.writeln();

    // تفاصيل المنتجات بدون صور
    if (productsWithoutImages > 0) {
      buffer.writeln('❌ منتجات بدون صور صالحة:');
      for (final result in results.where((r) => !r.hasValidImages)) {
        buffer.writeln('- ${result.product.name} (${result.product.id})');
        for (final imageResult in result.allResults) {
          buffer.writeln('  • ${imageResult.source}: ${imageResult.error}');
        }
      }
      buffer.writeln();
    }

    // إحصائيات أنواع الأخطاء
    final errorCounts = <String, int>{};
    for (final result in results) {
      for (final imageResult in result.allResults.where((r) => !r.isValid)) {
        final error = imageResult.error ?? 'خطأ غير معروف';
        errorCounts[error] = (errorCounts[error] ?? 0) + 1;
      }
    }

    if (errorCounts.isNotEmpty) {
      buffer.writeln('📈 إحصائيات الأخطاء:');
      errorCounts.entries.forEach((entry) {
        buffer.writeln('- ${entry.key}: ${entry.value}');
      });
    }

    return buffer.toString();
  }
}

/// نتيجة اختبار رابط صورة واحد
class ImageTestResult {
  final String url;
  final bool isValid;
  final int? statusCode;
  final String? contentType;
  final int? contentLength;
  final String? error;
  final String? source;

  const ImageTestResult({
    required this.url,
    required this.isValid,
    this.statusCode,
    this.contentType,
    this.contentLength,
    this.error,
    this.source,
  });

  ImageTestResult copyWith({
    String? url,
    bool? isValid,
    int? statusCode,
    String? contentType,
    int? contentLength,
    String? error,
    String? source,
  }) {
    return ImageTestResult(
      url: url ?? this.url,
      isValid: isValid ?? this.isValid,
      statusCode: statusCode ?? this.statusCode,
      contentType: contentType ?? this.contentType,
      contentLength: contentLength ?? this.contentLength,
      error: error ?? this.error,
      source: source ?? this.source,
    );
  }

  @override
  String toString() {
    return 'ImageTestResult(url: $url, isValid: $isValid, source: $source, error: $error)';
  }
}

/// نتيجة اختبار صور منتج كامل
class ProductImageTestResult {
  final ProductModel product;
  final List<ImageTestResult> allResults;
  final List<ImageTestResult> validResults;
  final ImageTestResult? bestResult;

  const ProductImageTestResult({
    required this.product,
    required this.allResults,
    required this.validResults,
    this.bestResult,
  });

  bool get hasValidImages => validResults.isNotEmpty;
  
  String? get bestImageUrl => bestResult?.url;

  @override
  String toString() {
    return 'ProductImageTestResult(product: ${product.name}, valid: ${validResults.length}/${allResults.length})';
  }
}
