import '../models/product_model.dart';
import '../services/api_product_sync_service.dart';
import 'app_logger.dart';

/// مساعد لتحسين عرض المنتجات وضمان عرض البيانات الصحيحة
class ProductDisplayHelper {
  static final ApiProductSyncService _apiService = ApiProductSyncService();

  /// تحسين عرض المنتج بالحصول على البيانات الحقيقية من API
  static Future<ProductModel> enhanceProductDisplay(ProductModel product) async {
    try {
      AppLogger.info('🔄 تحسين عرض المنتج: ${product.id}');

      // إذا كان المنتج يحتوي على بيانات عامة، حاول الحصول على البيانات الحقيقية
      if (_isGenericProduct(product)) {
        AppLogger.info('📥 المنتج يحتوي على بيانات عامة، جاري تحميل البيانات الحقيقية من API...');

        final apiProduct = await _apiService.getProductFromApi(product.id);
        if (apiProduct != null) {
          // التحقق من أن البيانات المستلمة ليست عامة
          final apiProductName = apiProduct['name']?.toString() ?? '';
          if (!_isGenericProductName(apiProductName)) {
            // دمج البيانات الحقيقية مع البيانات الموجودة
            final enhancedProduct = _mergeProductData(product, apiProduct);
            AppLogger.info('✅ تم تحسين عرض المنتج بالبيانات الحقيقية: ${enhancedProduct.name}');
            return enhancedProduct;
          } else {
            AppLogger.warning('⚠️ البيانات المستلمة من API لا تزال عامة: $apiProductName');
          }
        }
      } else {
        AppLogger.info('✅ المنتج يحتوي على بيانات حقيقية بالفعل: ${product.name}');
      }

      return product;
    } catch (e) {
      AppLogger.error('❌ خطأ في تحسين عرض المنتج: $e');
      return product;
    }
  }

  /// تحسين عرض قائمة من المنتجات
  static Future<List<ProductModel>> enhanceProductListDisplay(List<ProductModel> products) async {
    try {
      AppLogger.info('🔄 تحسين عرض ${products.length} منتج...');

      final enhancedProducts = <ProductModel>[];
      
      for (final product in products) {
        final enhancedProduct = await enhanceProductDisplay(product);
        enhancedProducts.add(enhancedProduct);
      }

      AppLogger.info('✅ تم تحسين عرض ${enhancedProducts.length} منتج');
      return enhancedProducts;
    } catch (e) {
      AppLogger.error('❌ خطأ في تحسين عرض قائمة المنتجات: $e');
      return products;
    }
  }

  /// التحقق من كون المنتج يحتوي على بيانات عامة
  static bool _isGenericProduct(ProductModel product) {
    // التحقق من الأنماط التي تشير إلى منتج عام
    final genericPatterns = [
      'منتج تجريبي',
      'منتج افتراضي',
      RegExp(r'^منتج \d+$'), // منتج + رقم
      RegExp(r'^منتج \d+ من API$'), // منتج + رقم + من API
      'DEFAULT-',
      'API-SKU-',
      'مورد API',
    ];

    for (final pattern in genericPatterns) {
      if (pattern is String) {
        if (product.name.contains(pattern) ||
            product.sku.contains(pattern) ||
            (product.supplier != null && product.supplier!.contains(pattern))) {
          return true;
        }
      } else if (pattern is RegExp) {
        if (pattern.hasMatch(product.name)) {
          return true;
        }
      }
    }

    // التحقق من الأوصاف العامة
    final genericDescriptions = [
      'تم إنشاؤه تلقائياً',
      'من API الخارجي',
      'منتج محمل من API',
      'وصف المنتج',
    ];

    for (final desc in genericDescriptions) {
      if (product.description.contains(desc)) {
        return true;
      }
    }

    // التحقق من الفئات العامة
    final genericCategories = ['عام', 'مستورد', 'غير محدد'];
    if (genericCategories.contains(product.category)) {
      return true;
    }

    // التحقق من عدم وجود صورة حقيقية
    if (product.imageUrl == null ||
        product.imageUrl!.isEmpty ||
        product.imageUrl!.contains('placeholder') ||
        product.imageUrl!.contains('via.placeholder.com')) {
      return true;
    }

    return false;
  }

  /// التحقق من كون اسم المنتج عام أو مولد
  static bool _isGenericProductName(String productName) {
    if (productName.isEmpty) return true;

    final genericPatterns = [
      'منتج تجريبي',
      'منتج افتراضي',
      'منتج غير معروف',
      'منتج غير محدد',
      RegExp(r'^منتج \d+$'), // منتج + رقم
      RegExp(r'^منتج \d+ من API$'), // منتج + رقم + من API
      RegExp(r'^منتج رقم \d+$'), // منتج رقم + رقم
      RegExp(r'^Product \d+$'), // Product + number
      RegExp(r'^Product \d+ from API$'), // Product + number + from API
    ];

    for (final pattern in genericPatterns) {
      if (pattern is String) {
        if (productName.contains(pattern)) {
          return true;
        }
      } else if (pattern is RegExp) {
        if (pattern.hasMatch(productName)) {
          return true;
        }
      }
    }

    return false;
  }

  /// دمج بيانات المنتج من API مع البيانات الموجودة
  static ProductModel _mergeProductData(ProductModel existingProduct, Map<String, dynamic> apiData) {
    try {
      // إنشاء منتج محسن بدمج البيانات
      return existingProduct.copyWith(
        name: apiData['name']?.toString() ?? existingProduct.name,
        description: apiData['description']?.toString() ?? existingProduct.description,
        price: (apiData['price'] as num?)?.toDouble() ?? existingProduct.price,
        imageUrl: apiData['image_url']?.toString() ?? existingProduct.imageUrl,
        category: apiData['category']?.toString() ?? existingProduct.category,
        images: _extractImages(apiData, existingProduct.images),
        purchasePrice: (apiData['purchase_price'] as num?)?.toDouble() ?? existingProduct.purchasePrice,
        originalPrice: (apiData['original_price'] as num?)?.toDouble() ?? existingProduct.originalPrice,
        supplier: apiData['supplier']?.toString() ?? existingProduct.supplier,
        tags: _extractTags(apiData, existingProduct.tags),
        metadata: _mergeMetadata(existingProduct.metadata, apiData),
      );
    } catch (e) {
      AppLogger.error('❌ خطأ في دمج بيانات المنتج: $e');
      return existingProduct;
    }
  }

  /// استخراج الصور من بيانات API
  static List<String> _extractImages(Map<String, dynamic> apiData, List<String> existingImages) {
    final images = <String>[];
    
    // إضافة الصورة الرئيسية
    if (apiData['image_url'] != null && apiData['image_url'].toString().isNotEmpty) {
      images.add(apiData['image_url'].toString());
    }
    
    // إضافة الصور الإضافية
    if (apiData['images'] is List) {
      for (final img in apiData['images']) {
        if (img != null && img.toString().isNotEmpty && !images.contains(img.toString())) {
          images.add(img.toString());
        }
      }
    }
    
    // إضافة الصور الموجودة إذا لم تكن موجودة
    for (final img in existingImages) {
      if (!images.contains(img)) {
        images.add(img);
      }
    }
    
    return images;
  }

  /// استخراج العلامات من بيانات API
  static List<String>? _extractTags(Map<String, dynamic> apiData, List<String>? existingTags) {
    final tags = <String>[];
    
    // إضافة العلامات من API
    if (apiData['tags'] is List) {
      for (final tag in apiData['tags']) {
        if (tag != null && tag.toString().isNotEmpty) {
          tags.add(tag.toString());
        }
      }
    }
    
    // إضافة العلامات الموجودة
    if (existingTags != null) {
      for (final tag in existingTags) {
        if (!tags.contains(tag)) {
          tags.add(tag);
        }
      }
    }
    
    return tags.isNotEmpty ? tags : existingTags;
  }

  /// دمج البيانات الوصفية
  static Map<String, dynamic>? _mergeMetadata(Map<String, dynamic>? existingMetadata, Map<String, dynamic> apiData) {
    final metadata = <String, dynamic>{};
    
    // إضافة البيانات الوصفية الموجودة
    if (existingMetadata != null) {
      metadata.addAll(existingMetadata);
    }
    
    // إضافة معلومات التحسين
    metadata['enhanced_at'] = DateTime.now().toIso8601String();
    metadata['enhanced_from_api'] = true;
    metadata['original_api_data'] = apiData;
    
    return metadata;
  }

  /// إنشاء اسم منتج محسن بناءً على البيانات المتاحة
  static String generateEnhancedProductName(String productId, Map<String, dynamic>? apiData) {
    // أولاً، التحقق من وجود اسم حقيقي في بيانات API
    if (apiData != null && apiData['name'] != null) {
      final apiName = apiData['name'].toString();
      if (apiName.isNotEmpty && !_isGenericProductName(apiName)) {
        return apiName;
      }
    }

    // إذا لم يوجد اسم حقيقي، استخدم معرف المنتج مع تحذير
    AppLogger.warning('⚠️ لم يتم العثور على اسم حقيقي للمنتج $productId، استخدام معرف المنتج');

    // إنشاء اسم مؤقت واضح أنه يحتاج تحديث
    if (productId.isNotEmpty) {
      return 'منتج مؤقت - معرف: $productId (يحتاج تحديث)';
    }

    return 'منتج غير محدد (يحتاج تحديث)';
  }

  /// التحقق من جودة بيانات المنتج
  static ProductQuality assessProductQuality(ProductModel product) {
    int score = 0;
    final issues = <String>[];
    
    // فحص الاسم
    if (product.name.isNotEmpty && !_isGenericProduct(product)) {
      score += 20;
    } else {
      issues.add('اسم المنتج عام أو فارغ');
    }
    
    // فحص الوصف
    if (product.description.isNotEmpty && !product.description.contains('تم إنشاؤه تلقائياً')) {
      score += 15;
    } else {
      issues.add('وصف المنتج فارغ أو عام');
    }
    
    // فحص الصورة
    if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
      score += 20;
    } else {
      issues.add('لا توجد صورة للمنتج');
    }
    
    // فحص السعر
    if (product.price > 0) {
      score += 15;
    } else {
      issues.add('سعر المنتج غير محدد');
    }
    
    // فحص الفئة
    if (product.category.isNotEmpty && product.category != 'عام') {
      score += 10;
    } else {
      issues.add('فئة المنتج عامة أو فارغة');
    }
    
    // فحص SKU
    if (product.sku.isNotEmpty && !product.sku.startsWith('DEFAULT-')) {
      score += 10;
    } else {
      issues.add('رمز المنتج عام أو فارغ');
    }
    
    // فحص الصور الإضافية
    if (product.images.length > 1) {
      score += 10;
    }
    
    // تحديد مستوى الجودة
    ProductQualityLevel level;
    if (score >= 80) {
      level = ProductQualityLevel.excellent;
    } else if (score >= 60) {
      level = ProductQualityLevel.good;
    } else if (score >= 40) {
      level = ProductQualityLevel.fair;
    } else {
      level = ProductQualityLevel.poor;
    }
    
    return ProductQuality(
      score: score,
      level: level,
      issues: issues,
    );
  }
}

/// تقييم جودة بيانات المنتج
class ProductQuality {
  final int score;
  final ProductQualityLevel level;
  final List<String> issues;

  const ProductQuality({
    required this.score,
    required this.level,
    required this.issues,
  });

  bool get isGoodQuality => level == ProductQualityLevel.good || level == ProductQualityLevel.excellent;
  bool get needsImprovement => level == ProductQualityLevel.fair || level == ProductQualityLevel.poor;
}

enum ProductQualityLevel {
  excellent,
  good,
  fair,
  poor,
}

extension ProductQualityLevelExtension on ProductQualityLevel {
  String get arabicName {
    switch (this) {
      case ProductQualityLevel.excellent:
        return 'ممتاز';
      case ProductQualityLevel.good:
        return 'جيد';
      case ProductQualityLevel.fair:
        return 'مقبول';
      case ProductQualityLevel.poor:
        return 'ضعيف';
    }
  }
}
