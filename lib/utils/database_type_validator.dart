/// مساعد التحقق من أنواع البيانات في قاعدة البيانات
/// Database Type Validation Helper
/// 
/// يوفر وظائف التحقق من صحة أنواع البيانات المختلطة في قاعدة البيانات
/// لحل مشاكل "operator does not exist: text = uuid"

import 'package:smartbiztracker_new/utils/app_logger.dart';

class DatabaseTypeValidator {
  /// التحقق من صحة معرف المخزن (UUID)
  static bool isValidWarehouseId(String warehouseId) {
    if (warehouseId.isEmpty) return false;
    try {
      // نمط UUID القياسي
      final uuid = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        caseSensitive: false,
      );
      return uuid.hasMatch(warehouseId);
    } catch (e) {
      AppLogger.error('❌ خطأ في التحقق من معرف المخزن: $e');
      return false;
    }
  }

  /// التحقق من صحة معرف المنتج (TEXT)
  static bool isValidProductId(String productId) {
    return productId.isNotEmpty && productId.trim().isNotEmpty;
  }

  /// التحقق من صحة معرف المستخدم (UUID)
  static bool isValidUserId(String userId) {
    return isValidWarehouseId(userId); // نفس تنسيق UUID
  }

  /// تحويل معرف المخزن إلى تنسيق UUID آمن
  static String ensureWarehouseIdFormat(String warehouseId) {
    if (!isValidWarehouseId(warehouseId)) {
      final error = 'معرف المخزن غير صحيح: $warehouseId. يجب أن يكون UUID صحيح.';
      AppLogger.error('❌ $error');
      throw DatabaseTypeValidationException(error, 'warehouse_id', warehouseId);
    }
    return warehouseId.toLowerCase();
  }

  /// تحويل معرف المنتج إلى تنسيق TEXT آمن
  static String ensureProductIdFormat(String productId) {
    if (!isValidProductId(productId)) {
      final error = 'معرف المنتج غير صحيح: $productId. لا يمكن أن يكون فارغاً.';
      AppLogger.error('❌ $error');
      throw DatabaseTypeValidationException(error, 'product_id', productId);
    }
    return productId.trim();
  }

  /// تحويل معرف المستخدم إلى تنسيق UUID آمن
  static String ensureUserIdFormat(String userId) {
    if (!isValidUserId(userId)) {
      final error = 'معرف المستخدم غير صحيح: $userId. يجب أن يكون UUID صحيح.';
      AppLogger.error('❌ $error');
      throw DatabaseTypeValidationException(error, 'user_id', userId);
    }
    return userId.toLowerCase();
  }

  /// التحقق من قائمة معرفات المخازن
  static List<String> validateWarehouseIds(List<String> warehouseIds) {
    final validIds = <String>[];
    final invalidIds = <String>[];

    for (final id in warehouseIds) {
      if (isValidWarehouseId(id)) {
        validIds.add(ensureWarehouseIdFormat(id));
      } else {
        invalidIds.add(id);
      }
    }

    if (invalidIds.isNotEmpty) {
      final error = 'معرفات مخازن غير صحيحة: ${invalidIds.join(', ')}';
      AppLogger.error('❌ $error');
      throw DatabaseTypeValidationException(error, 'warehouse_ids', invalidIds.toString());
    }

    return validIds;
  }

  /// التحقق من قائمة معرفات المنتجات
  static List<String> validateProductIds(List<String> productIds) {
    final validIds = <String>[];
    final invalidIds = <String>[];

    for (final id in productIds) {
      if (isValidProductId(id)) {
        validIds.add(ensureProductIdFormat(id));
      } else {
        invalidIds.add(id);
      }
    }

    if (invalidIds.isNotEmpty) {
      final error = 'معرفات منتجات غير صحيحة: ${invalidIds.join(', ')}';
      AppLogger.error('❌ $error');
      throw DatabaseTypeValidationException(error, 'product_ids', invalidIds.toString());
    }

    return validIds;
  }

  /// تحليل خطأ قاعدة البيانات وتحديد إذا كان مرتبطاً بأنواع البيانات
  static bool isTypeRelatedError(String error) {
    final typeErrorPatterns = [
      'operator does not exist: text = uuid',
      'operator does not exist: uuid = text',
      'invalid input syntax for type uuid',
      'cannot cast type text to uuid',
      'cannot cast type uuid to text',
      'column ".*" is of type uuid but expression is of type text',
      'column ".*" is of type text but expression is of type uuid',
    ];

    final errorLower = error.toLowerCase();
    return typeErrorPatterns.any((pattern) => 
      RegExp(pattern, caseSensitive: false).hasMatch(errorLower)
    );
  }

  /// إنشاء رسالة خطأ مفصلة لأخطاء أنواع البيانات
  static String createTypeErrorMessage(String originalError, String fieldName, String value) {
    if (isTypeRelatedError(originalError)) {
      if (fieldName.contains('warehouse')) {
        return 'خطأ في نوع البيانات: معرف المخزن "$value" يجب أن يكون UUID صحيح. '
               'الخطأ الأصلي: $originalError';
      } else if (fieldName.contains('product')) {
        return 'خطأ في نوع البيانات: معرف المنتج "$value" يجب أن يكون نص صحيح. '
               'الخطأ الأصلي: $originalError';
      } else if (fieldName.contains('user')) {
        return 'خطأ في نوع البيانات: معرف المستخدم "$value" يجب أن يكون UUID صحيح. '
               'الخطأ الأصلي: $originalError';
      }
    }
    
    return 'خطأ في قاعدة البيانات: $originalError';
  }

  /// تسجيل معلومات التحقق للتشخيص
  static void logValidationInfo(String operation, Map<String, String> ids) {
    AppLogger.info('🔍 التحقق من أنواع البيانات للعملية: $operation');
    
    for (final entry in ids.entries) {
      final fieldName = entry.key;
      final value = entry.value;
      
      if (fieldName.contains('warehouse')) {
        final isValid = isValidWarehouseId(value);
        AppLogger.info('   $fieldName: $value (UUID صحيح: ${isValid ? "نعم" : "لا"})');
      } else if (fieldName.contains('product')) {
        final isValid = isValidProductId(value);
        AppLogger.info('   $fieldName: $value (TEXT صحيح: ${isValid ? "نعم" : "لا"})');
      } else {
        AppLogger.info('   $fieldName: $value');
      }
    }
  }
}

/// استثناء خاص بأخطاء التحقق من أنواع البيانات
class DatabaseTypeValidationException implements Exception {
  final String message;
  final String fieldName;
  final String invalidValue;

  const DatabaseTypeValidationException(this.message, this.fieldName, this.invalidValue);

  @override
  String toString() => 'DatabaseTypeValidationException: $message';

  /// معلومات مفصلة عن الخطأ
  Map<String, dynamic> toMap() => {
    'error_type': 'database_type_validation',
    'message': message,
    'field_name': fieldName,
    'invalid_value': invalidValue,
    'timestamp': DateTime.now().toIso8601String(),
  };
}

/// مساعد لتحويل أخطاء قاعدة البيانات إلى رسائل مفهومة
class DatabaseErrorTranslator {
  static const Map<String, String> _errorTranslations = {
    'operator does not exist: text = uuid': 'خطأ في مقارنة أنواع البيانات: لا يمكن مقارنة نص مع UUID',
    'operator does not exist: uuid = text': 'خطأ في مقارنة أنواع البيانات: لا يمكن مقارنة UUID مع نص',
    'invalid input syntax for type uuid': 'تنسيق UUID غير صحيح',
    'cannot cast type text to uuid': 'لا يمكن تحويل النص إلى UUID',
    'cannot cast type uuid to text': 'لا يمكن تحويل UUID إلى نص',
    'row-level security policy': 'ليس لديك صلاحية للوصول لهذه البيانات',
    'duplicate key value': 'القيمة موجودة بالفعل',
    'foreign key constraint': 'انتهاك قيد المفتاح الخارجي',
    'not null constraint': 'الحقل مطلوب ولا يمكن أن يكون فارغاً',
  };

  /// ترجمة خطأ قاعدة البيانات إلى رسالة مفهومة
  static String translate(String error) {
    final errorLower = error.toLowerCase();
    
    for (final entry in _errorTranslations.entries) {
      if (errorLower.contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    
    return error; // إرجاع الخطأ الأصلي إذا لم توجد ترجمة
  }

  /// إنشاء رسالة خطأ شاملة مع اقتراحات الحل
  static String createUserFriendlyMessage(String error, {String? context}) {
    final translatedError = translate(error);
    final contextInfo = context != null ? ' في $context' : '';
    
    if (DatabaseTypeValidator.isTypeRelatedError(error)) {
      return 'حدث خطأ في أنواع البيانات$contextInfo. '
             '$translatedError. '
             'يرجى التأكد من صحة المعرفات المستخدمة.';
    }
    
    return 'حدث خطأ$contextInfo: $translatedError';
  }
}
