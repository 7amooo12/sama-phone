import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product_model.dart';
import '../utils/app_logger.dart';

/// خدمة ضمان سلامة بيانات المنتجات ومنع التعديلات غير المرغوب فيها
class ProductDataIntegrityService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// التحقق من سلامة بيانات المنتج قبل العمليات
  Future<ProductIntegrityResult> validateProductIntegrity(String productId) async {
    try {
      AppLogger.info('🔍 التحقق من سلامة بيانات المنتج: $productId');

      final response = await _supabase
          .from('products')
          .select('*')
          .eq('id', productId)
          .maybeSingle();

      if (response == null) {
        return ProductIntegrityResult(
          exists: false,
          isValid: false,
          product: null,
          issues: ['المنتج غير موجود في قاعدة البيانات'],
          recommendation: ProductIntegrityRecommendation.createProduct,
        );
      }

      final product = ProductModel.fromJson(response);
      final issues = <String>[];
      bool isValid = true;

      // التحقق من جودة البيانات
      if (_isGenericProductName(product.name)) {
        issues.add('اسم المنتج عام أو مولد: ${product.name}');
        isValid = false;
      }

      if (_isGenericCategory(product.category)) {
        issues.add('فئة المنتج عامة: ${product.category}');
        isValid = false;
      }

      if (_isGenericDescription(product.description)) {
        issues.add('وصف المنتج عام أو مولد');
        isValid = false;
      }

      final recommendation = _getRecommendation(isValid, issues);

      AppLogger.info('✅ تم التحقق من سلامة المنتج: ${isValid ? "صالح" : "يحتاج تحسين"}');

      return ProductIntegrityResult(
        exists: true,
        isValid: isValid,
        product: product,
        issues: issues,
        recommendation: recommendation,
      );
    } catch (e) {
      AppLogger.error('❌ خطأ في التحقق من سلامة المنتج: $e');
      return ProductIntegrityResult(
        exists: false,
        isValid: false,
        product: null,
        issues: ['خطأ في التحقق من البيانات: $e'],
        recommendation: ProductIntegrityRecommendation.error,
      );
    }
  }

  /// منع تعديل بيانات المنتج أثناء عمليات القراءة
  Future<ProductModel?> getProductSafely(String productId, {bool allowCreation = false}) async {
    try {
      AppLogger.info('📖 قراءة آمنة لبيانات المنتج: $productId');

      final response = await _supabase
          .from('products')
          .select('*')
          .eq('id', productId)
          .maybeSingle();

      if (response != null) {
        final product = ProductModel.fromJson(response);
        AppLogger.info('✅ تم تحميل المنتج بأمان: ${product.name}');
        return product;
      } else if (allowCreation) {
        AppLogger.warning('⚠️ المنتج غير موجود، إنشاء منتج مؤقت للعرض: $productId');
        return _createTemporaryProduct(productId);
      } else {
        AppLogger.warning('⚠️ المنتج غير موجود ولا يُسمح بالإنشاء: $productId');
        return null;
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في القراءة الآمنة للمنتج: $e');
      return allowCreation ? _createTemporaryProduct(productId) : null;
    }
  }

  /// تسجيل محاولات التعديل غير المصرح بها
  Future<void> logUnauthorizedModificationAttempt({
    required String productId,
    required String operation,
    required String context,
    String? userId,
  }) async {
    try {
      AppLogger.warning('🚨 محاولة تعديل غير مصرح بها: $operation على المنتج $productId في السياق: $context');

      // تسجيل المحاولة في قاعدة البيانات للمراجعة
      await _supabase.from('product_integrity_logs').insert({
        'product_id': productId,
        'operation': operation,
        'context': context,
        'user_id': userId,
        'timestamp': DateTime.now().toIso8601String(),
        'severity': 'warning',
        'message': 'محاولة تعديل بيانات منتج أثناء عملية قراءة',
      });
    } catch (e) {
      AppLogger.error('❌ خطأ في تسجيل محاولة التعديل: $e');
    }
  }

  /// إنشاء منتج مؤقت للعرض فقط
  ProductModel _createTemporaryProduct(String productId) {
    return ProductModel(
      id: productId,
      name: 'منتج مؤقت - معرف: $productId (يحتاج تحديث)',
      description: 'منتج مؤقت للعرض - يحتاج إضافة بيانات حقيقية',
      price: 0.0,
      quantity: 0,
      category: 'غير محدد',
      isActive: true,
      sku: 'TEMP-$productId',
      reorderPoint: 10,
      images: [],
      createdAt: DateTime.now(),
      minimumStock: 10,
    );
  }

  /// التحقق من كون اسم المنتج عام
  bool _isGenericProductName(String name) {
    final genericPatterns = [
      'منتج تجريبي',
      'منتج افتراضي',
      'منتج غير معروف',
      'منتج غير محدد',
      'منتج مؤقت',
      RegExp(r'^منتج \d+$'),
      RegExp(r'^منتج \d+ من API$'),
      RegExp(r'^منتج رقم \d+$'),
      RegExp(r'^Product \d+$'),
    ];

    for (final pattern in genericPatterns) {
      if (pattern is String) {
        if (name.contains(pattern)) return true;
      } else if (pattern is RegExp) {
        if (pattern.hasMatch(name)) return true;
      }
    }
    return false;
  }

  /// التحقق من كون فئة المنتج عامة
  bool _isGenericCategory(String category) {
    final genericCategories = [
      'عام',
      'مستورد',
      'غير محدد',
      'غير معروف',
      'افتراضي',
    ];
    return genericCategories.contains(category);
  }

  /// التحقق من كون وصف المنتج عام
  bool _isGenericDescription(String description) {
    final genericDescriptions = [
      'تم إنشاؤه تلقائياً',
      'من API الخارجي',
      'منتج محمل من API',
      'وصف المنتج',
      'منتج تم إنشاؤه تلقائياً',
      'منتج مؤقت للعرض',
    ];

    for (final desc in genericDescriptions) {
      if (description.contains(desc)) return true;
    }
    return false;
  }

  /// الحصول على التوصية بناءً على حالة المنتج
  ProductIntegrityRecommendation _getRecommendation(bool isValid, List<String> issues) {
    if (isValid) {
      return ProductIntegrityRecommendation.noAction;
    }

    if (issues.any((issue) => issue.contains('اسم المنتج عام'))) {
      return ProductIntegrityRecommendation.enhanceFromApi;
    }

    if (issues.any((issue) => issue.contains('فئة المنتج عامة'))) {
      return ProductIntegrityRecommendation.updateCategory;
    }

    return ProductIntegrityRecommendation.generalImprovement;
  }

  /// إحصائيات سلامة البيانات
  Future<DataIntegrityStats> getIntegrityStats() async {
    try {
      final response = await _supabase
          .from('products')
          .select('id, name, category, description')
          .eq('active', true);

      int totalProducts = response.length;
      int validProducts = 0;
      int genericNames = 0;
      int genericCategories = 0;
      int genericDescriptions = 0;

      for (final item in response) {
        final name = item['name']?.toString() ?? '';
        final category = item['category']?.toString() ?? '';
        final description = item['description']?.toString() ?? '';

        bool isValid = true;

        if (_isGenericProductName(name)) {
          genericNames++;
          isValid = false;
        }

        if (_isGenericCategory(category)) {
          genericCategories++;
          isValid = false;
        }

        if (_isGenericDescription(description)) {
          genericDescriptions++;
          isValid = false;
        }

        if (isValid) {
          validProducts++;
        }
      }

      return DataIntegrityStats(
        totalProducts: totalProducts,
        validProducts: validProducts,
        genericNames: genericNames,
        genericCategories: genericCategories,
        genericDescriptions: genericDescriptions,
        integrityPercentage: totalProducts > 0 ? (validProducts / totalProducts) * 100 : 0,
      );
    } catch (e) {
      AppLogger.error('❌ خطأ في الحصول على إحصائيات السلامة: $e');
      return DataIntegrityStats(
        totalProducts: 0,
        validProducts: 0,
        genericNames: 0,
        genericCategories: 0,
        genericDescriptions: 0,
        integrityPercentage: 0,
      );
    }
  }
}

/// نتيجة التحقق من سلامة المنتج
class ProductIntegrityResult {
  final bool exists;
  final bool isValid;
  final ProductModel? product;
  final List<String> issues;
  final ProductIntegrityRecommendation recommendation;

  const ProductIntegrityResult({
    required this.exists,
    required this.isValid,
    required this.product,
    required this.issues,
    required this.recommendation,
  });
}

/// توصيات لتحسين سلامة البيانات
enum ProductIntegrityRecommendation {
  noAction,
  createProduct,
  enhanceFromApi,
  updateCategory,
  generalImprovement,
  error,
}

/// إحصائيات سلامة البيانات
class DataIntegrityStats {
  final int totalProducts;
  final int validProducts;
  final int genericNames;
  final int genericCategories;
  final int genericDescriptions;
  final double integrityPercentage;

  const DataIntegrityStats({
    required this.totalProducts,
    required this.validProducts,
    required this.genericNames,
    required this.genericCategories,
    required this.genericDescriptions,
    required this.integrityPercentage,
  });

  int get invalidProducts => totalProducts - validProducts;
  double get validPercentage => totalProducts > 0 ? (validProducts / totalProducts) * 100 : 0;
  double get invalidPercentage => totalProducts > 0 ? (invalidProducts / totalProducts) * 100 : 0;
}
