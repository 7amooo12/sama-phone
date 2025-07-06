/// خدمة عزل العمليات لمنع تأثير الأخطاء على النظام بأكمله
/// Operation Isolation Service to prevent errors from affecting the entire system

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smartbiztracker_new/services/auth_state_manager.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// خدمة عزل العمليات والتعافي من الأخطاء
class OperationIsolationService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// تنفيذ عملية معزولة مع حماية حالة المصادقة
  static Future<T> executeIsolatedOperation<T>({
    required String operationName,
    required Future<T> Function() operation,
    required T Function() fallbackValue,
    bool preserveAuthState = true,
    int maxRetries = 2,
  }) async {
    User? originalUser;
    
    // حفظ حالة المصادقة الأصلية
    if (preserveAuthState) {
      try {
        originalUser = await AuthStateManager.getCurrentUser(forceRefresh: false);
        if (originalUser != null) {
          AppLogger.info('🔒 حفظ حالة المصادقة للعملية المعزولة: $operationName');
          AppLogger.info('   المستخدم: ${originalUser.id}');
        }
      } catch (e) {
        AppLogger.warning('⚠️ فشل في حفظ حالة المصادقة للعملية: $operationName - $e');
      }
    }

    int attempt = 0;
    Exception? lastException;

    while (attempt <= maxRetries) {
      try {
        AppLogger.info('🔄 تنفيذ العملية المعزولة: $operationName (المحاولة ${attempt + 1}/${maxRetries + 1})');
        
        // التحقق من حالة المصادقة قبل التنفيذ
        if (preserveAuthState && originalUser != null) {
          final currentUser = _supabase.auth.currentUser;
          if (currentUser == null || currentUser.id != originalUser.id) {
            AppLogger.warning('⚠️ تغيرت حالة المصادقة، محاولة الاستعادة...');
            final recoveredUser = await AuthStateManager.getCurrentUser(forceRefresh: true);
            if (recoveredUser == null || recoveredUser.id != originalUser.id) {
              throw Exception('فقدان المصادقة أثناء العملية المعزولة: $operationName');
            }
          }
        }

        // تنفيذ العملية
        final result = await operation();
        
        // التحقق من حالة المصادقة بعد التنفيذ
        if (preserveAuthState && originalUser != null) {
          await _verifyAuthStateAfterOperation(operationName, originalUser);
        }

        AppLogger.info('✅ نجحت العملية المعزولة: $operationName');
        return result;

      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        AppLogger.error('❌ فشلت العملية المعزولة: $operationName (المحاولة ${attempt + 1}) - $e');
        
        // محاولة استعادة حالة المصادقة بعد الفشل
        if (preserveAuthState && originalUser != null) {
          await _recoverAuthStateAfterFailure(operationName, originalUser);
        }
        
        attempt++;
        
        // تأخير مُحسَّن قبل المحاولة التالية (تقليل التأخير لتحسين الأداء)
        if (attempt <= maxRetries) {
          final delayMs = attempt * 300; // 300ms, 600ms delays (reduced from 1s, 2s)
          AppLogger.info('⏳ انتظار ${delayMs}ms قبل المحاولة التالية...');
          await Future.delayed(Duration(milliseconds: delayMs));
        }
      }
    }

    // إذا فشلت جميع المحاولات، استخدم القيمة الاحتياطية
    AppLogger.warning('⚠️ فشلت جميع محاولات العملية المعزولة: $operationName');
    AppLogger.warning('   استخدام القيمة الاحتياطية...');
    
    // محاولة أخيرة لاستعادة حالة المصادقة
    if (preserveAuthState && originalUser != null) {
      await _recoverAuthStateAfterFailure(operationName, originalUser);
    }

    try {
      return fallbackValue();
    } catch (fallbackError) {
      AppLogger.error('❌ فشل في الحصول على القيمة الاحتياطية للعملية: $operationName - $fallbackError');
      throw lastException ?? Exception('فشل في العملية المعزولة: $operationName');
    }
  }

  /// تنفيذ عملية معزولة بدون قيمة إرجاع
  static Future<bool> executeIsolatedVoidOperation({
    required String operationName,
    required Future<void> Function() operation,
    bool preserveAuthState = true,
    int maxRetries = 2,
  }) async {
    return await executeIsolatedOperation<bool>(
      operationName: operationName,
      operation: () async {
        await operation();
        return true;
      },
      fallbackValue: () => false,
      preserveAuthState: preserveAuthState,
      maxRetries: maxRetries,
    );
  }

  /// تنفيذ عدة عمليات معزولة بشكل متتالي
  static Future<List<T>> executeMultipleIsolatedOperations<T>({
    required String batchName,
    required List<({String name, Future<T> Function() operation, T Function() fallback})> operations,
    bool preserveAuthState = true,
    bool stopOnFirstFailure = false,
  }) async {
    AppLogger.info('🔄 تنفيذ مجموعة عمليات معزولة: $batchName (${operations.length} عملية)');
    
    final results = <T>[];
    final errors = <String>[];

    for (int i = 0; i < operations.length; i++) {
      final op = operations[i];
      try {
        final result = await executeIsolatedOperation<T>(
          operationName: '${batchName}_${op.name}',
          operation: op.operation,
          fallbackValue: op.fallback,
          preserveAuthState: preserveAuthState,
        );
        results.add(result);
        AppLogger.info('✅ نجحت العملية ${i + 1}/${operations.length}: ${op.name}');
      } catch (e) {
        errors.add('${op.name}: $e');
        AppLogger.error('❌ فشلت العملية ${i + 1}/${operations.length}: ${op.name} - $e');
        
        if (stopOnFirstFailure) {
          AppLogger.warning('⚠️ إيقاف المجموعة بسبب فشل العملية: ${op.name}');
          break;
        }
        
        // إضافة قيمة احتياطية للعملية الفاشلة
        try {
          results.add(op.fallback());
        } catch (fallbackError) {
          AppLogger.error('❌ فشل في الحصول على القيمة الاحتياطية للعملية: ${op.name} - $fallbackError');
          rethrow;
        }
      }
    }

    AppLogger.info('📊 نتائج مجموعة العمليات المعزولة: $batchName');
    AppLogger.info('   نجح: ${results.length - errors.length}/${operations.length}');
    AppLogger.info('   فشل: ${errors.length}/${operations.length}');

    if (errors.isNotEmpty) {
      AppLogger.warning('⚠️ أخطاء في مجموعة العمليات:');
      for (final error in errors) {
        AppLogger.warning('   - $error');
      }
    }

    return results;
  }

  /// التحقق من حالة المصادقة بعد العملية
  static Future<void> _verifyAuthStateAfterOperation(String operationName, User originalUser) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null || currentUser.id != originalUser.id) {
        AppLogger.warning('⚠️ تأثرت حالة المصادقة بعد العملية: $operationName');
        await AuthStateManager.getCurrentUser(forceRefresh: true);
      }
    } catch (e) {
      AppLogger.warning('⚠️ خطأ في التحقق من المصادقة بعد العملية: $operationName - $e');
    }
  }

  /// استعادة حالة المصادقة بعد الفشل
  static Future<void> _recoverAuthStateAfterFailure(String operationName, User originalUser) async {
    try {
      AppLogger.info('🔄 محاولة استعادة المصادقة بعد فشل العملية: $operationName');
      final recoveredUser = await AuthStateManager.getCurrentUser(forceRefresh: true);
      if (recoveredUser != null && recoveredUser.id == originalUser.id) {
        AppLogger.info('✅ تم استعادة المصادقة بنجاح بعد فشل العملية: $operationName');
      } else {
        AppLogger.warning('⚠️ فشل في استعادة المصادقة بعد فشل العملية: $operationName');
      }
    } catch (recoveryError) {
      AppLogger.error('❌ خطأ في استعادة المصادقة بعد فشل العملية: $operationName - $recoveryError');
    }
  }

  /// إنشاء قيمة احتياطية آمنة
  static T createSafeFallback<T>(T defaultValue) {
    return defaultValue;
  }

  /// إنشاء قائمة احتياطية فارغة
  static List<T> createEmptyListFallback<T>() {
    return <T>[];
  }

  /// إنشاء خريطة احتياطية فارغة
  static Map<K, V> createEmptyMapFallback<K, V>() {
    return <K, V>{};
  }
}

/// نتيجة العملية المعزولة
class IsolatedOperationResult<T> {
  final bool success;
  final T? result;
  final String? error;
  final DateTime timestamp;

  const IsolatedOperationResult({
    required this.success,
    this.result,
    this.error,
    required this.timestamp,
  });

  factory IsolatedOperationResult.success(T result) {
    return IsolatedOperationResult(
      success: true,
      result: result,
      timestamp: DateTime.now(),
    );
  }

  factory IsolatedOperationResult.failure(String error) {
    return IsolatedOperationResult(
      success: false,
      error: error,
      timestamp: DateTime.now(),
    );
  }
}
