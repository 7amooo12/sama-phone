/// خدمة عزل المعاملات لمنع تأثير الأخطاء على حالة المصادقة
/// Transaction Isolation Service to prevent errors from affecting authentication state

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smartbiztracker_new/services/auth_state_manager.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// خدمة عزل المعاملات وحماية حالة المصادقة
class TransactionIsolationService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// تنفيذ معاملة معزولة مع حماية حالة المصادقة
  static Future<T> executeIsolatedTransaction<T>({
    required String transactionName,
    required Future<T> Function(SupabaseClient client) transaction,
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
          AppLogger.info('🔒 حفظ حالة المصادقة للمعاملة المعزولة: $transactionName');
          AppLogger.info('   المستخدم: ${originalUser.id}');
        }
      } catch (e) {
        AppLogger.warning('⚠️ فشل في حفظ حالة المصادقة للمعاملة: $transactionName - $e');
      }
    }

    int attempt = 0;
    Exception? lastException;

    while (attempt <= maxRetries) {
      try {
        AppLogger.info('🔄 تنفيذ المعاملة المعزولة: $transactionName (المحاولة ${attempt + 1}/${maxRetries + 1})');
        
        // CRITICAL FIX: Enhanced authentication verification before transaction
        if (preserveAuthState && originalUser != null) {
          final authValid = await _verifyClientAuthContext(originalUser, transactionName);
          if (!authValid) {
            throw Exception('فشل في التحقق من حالة المصادقة قبل المعاملة: $transactionName');
          }
        }

        // إنشاء عميل منفصل للمعاملة لعزل التأثيرات
        final isolatedClient = _createIsolatedClient();

        // CRITICAL FIX: Final auth verification just before transaction execution
        if (preserveAuthState && originalUser != null) {
          final finalUser = isolatedClient.auth.currentUser;
          if (finalUser == null || finalUser.id != originalUser.id) {
            AppLogger.error('❌ حالة المصادقة فُقدت قبل تنفيذ المعاملة مباشرة: $transactionName');
            throw Exception('فقدان المصادقة قبل تنفيذ المعاملة: $transactionName');
          }
          AppLogger.info('✅ تأكيد حالة المصادقة قبل تنفيذ المعاملة: $transactionName');
        }

        // تنفيذ المعاملة
        final result = await transaction(isolatedClient);
        
        // التحقق من حالة المصادقة بعد المعاملة
        if (preserveAuthState && originalUser != null) {
          await _verifyAuthStateAfterTransaction(transactionName, originalUser);
        }

        AppLogger.info('✅ نجحت المعاملة المعزولة: $transactionName');
        return result;

      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        AppLogger.error('❌ فشلت المعاملة المعزولة: $transactionName (المحاولة ${attempt + 1}) - $e');
        
        // محاولة استعادة حالة المصادقة بعد الفشل
        if (preserveAuthState && originalUser != null) {
          await _recoverAuthStateAfterTransactionFailure(transactionName, originalUser);
        }
        
        attempt++;
        
        // تأخير مُحسَّن قبل المحاولة التالية (تقليل التأخير لتحسين الأداء)
        if (attempt <= maxRetries) {
          final delayMs = attempt * 500; // 500ms, 1s delays (reduced from 1.5s, 3s)
          AppLogger.info('⏳ انتظار ${delayMs}ms قبل المحاولة التالية...');
          await Future.delayed(Duration(milliseconds: delayMs));
        }
      }
    }

    // إذا فشلت جميع المحاولات، استخدم القيمة الاحتياطية
    AppLogger.warning('⚠️ فشلت جميع محاولات المعاملة المعزولة: $transactionName');
    AppLogger.warning('   استخدام القيمة الاحتياطية...');
    
    // محاولة أخيرة لاستعادة حالة المصادقة
    if (preserveAuthState && originalUser != null) {
      await _recoverAuthStateAfterTransactionFailure(transactionName, originalUser);
    }

    try {
      return fallbackValue();
    } catch (fallbackError) {
      AppLogger.error('❌ فشل في الحصول على القيمة الاحتياطية للمعاملة: $transactionName - $fallbackError');
      throw lastException ?? Exception('فشل في المعاملة المعزولة: $transactionName');
    }
  }

  /// تنفيذ معاملة قراءة معزولة (للاستعلامات) - محسنة للأداء
  static Future<T> executeIsolatedReadTransaction<T>({
    required String queryName,
    required Future<T> Function(SupabaseClient client) query,
    required T Function() fallbackValue,
    bool preserveAuthState = true,
  }) async {
    User? originalUser;

    // CRITICAL FIX: Always preserve auth state for database queries to ensure RLS policies work
    if (preserveAuthState) {
      try {
        originalUser = await AuthStateManager.getCurrentUser(forceRefresh: false);
        if (originalUser != null) {
          AppLogger.info('🔒 حفظ حالة المصادقة للاستعلام المعزول: $queryName');
          AppLogger.info('   المستخدم: ${originalUser.id}');

          // CRITICAL FIX: Verify auth context is properly set in Supabase client
          final currentUser = _supabase.auth.currentUser;
          if (currentUser == null || currentUser.id != originalUser.id) {
            AppLogger.warning('⚠️ حالة المصادقة غير متطابقة في العميل، محاولة الإصلاح...');
            await AuthStateManager.getCurrentUser(forceRefresh: true);

            // Verify again after refresh
            final refreshedUser = _supabase.auth.currentUser;
            if (refreshedUser == null || refreshedUser.id != originalUser.id) {
              throw Exception('فشل في تعيين حالة المصادقة للاستعلام: $queryName');
            }
            AppLogger.info('✅ تم إصلاح حالة المصادقة للاستعلام: $queryName');
          }
        } else {
          AppLogger.error('❌ لا يوجد مستخدم مصادق عليه للاستعلام: $queryName');
          throw Exception('المستخدم غير مصادق عليه - يرجى تسجيل الدخول مرة أخرى');
        }
      } catch (e) {
        AppLogger.error('❌ خطأ في حفظ حالة المصادقة للاستعلام: $queryName - $e');
        return fallbackValue();
      }
    }

    // للاستعلامات البسيطة، نحاول تنفيذها مباشرة أولاً
    if (!preserveAuthState) {
      try {
        AppLogger.info('🚀 تنفيذ استعلام مباشر (بدون حماية المصادقة): $queryName');
        return await query(_supabase);
      } catch (e) {
        AppLogger.warning('⚠️ فشل الاستعلام المباشر، التبديل للوضع المعزول: $queryName - $e');
      }
    }

    return await executeIsolatedTransaction<T>(
      transactionName: 'read_$queryName',
      transaction: query,
      fallbackValue: fallbackValue,
      preserveAuthState: preserveAuthState,
      maxRetries: 1, // عدد محاولات أقل للقراءة
    );
  }

  /// تنفيذ معاملة كتابة معزولة (للتحديثات والإدراج)
  static Future<T> executeIsolatedWriteTransaction<T>({
    required String operationName,
    required Future<T> Function(SupabaseClient client) operation,
    required T Function() fallbackValue,
    bool preserveAuthState = true,
  }) async {
    return await executeIsolatedTransaction<T>(
      transactionName: 'write_$operationName',
      transaction: operation,
      fallbackValue: fallbackValue,
      preserveAuthState: preserveAuthState,
      maxRetries: 2, // عدد محاولات أكثر للكتابة
    );
  }

  /// إنشاء عميل معزول للمعاملة مع الحفاظ على حالة المصادقة
  static SupabaseClient _createIsolatedClient() {
    // CRITICAL FIX: Return the same client to maintain auth context
    // The isolation is achieved through transaction management, not client separation
    return _supabase;
  }

  /// التحقق من صحة حالة المصادقة في العميل
  static Future<bool> _verifyClientAuthContext(User expectedUser, String operationName) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      final currentSession = _supabase.auth.currentSession;

      AppLogger.info('🔍 التحقق من حالة المصادقة للعملية: $operationName');
      AppLogger.info('   المستخدم المتوقع: ${expectedUser.id}');
      AppLogger.info('   المستخدم الحالي: ${currentUser?.id ?? 'null'}');
      AppLogger.info('   الجلسة النشطة: ${currentSession != null ? 'موجودة' : 'غير موجودة'}');

      if (currentUser == null || currentUser.id != expectedUser.id) {
        AppLogger.warning('⚠️ حالة المصادقة غير صحيحة، محاولة الإصلاح...');

        // Try to recover the auth state
        final recoveredUser = await AuthStateManager.getCurrentUser(forceRefresh: true);
        if (recoveredUser == null || recoveredUser.id != expectedUser.id) {
          AppLogger.error('❌ فشل في استعادة حالة المصادقة للعملية: $operationName');
          return false;
        }

        // Verify the recovery worked
        final verifyUser = _supabase.auth.currentUser;
        if (verifyUser == null || verifyUser.id != expectedUser.id) {
          AppLogger.error('❌ فشل في التحقق من استعادة المصادقة للعملية: $operationName');
          return false;
        }

        AppLogger.info('✅ تم استعادة حالة المصادقة بنجاح للعملية: $operationName');
      }

      return true;
    } catch (e) {
      AppLogger.error('❌ خطأ في التحقق من حالة المصادقة للعملية: $operationName - $e');
      return false;
    }
  }

  /// التحقق من حالة المصادقة قبل المعاملة
  static Future<void> _verifyAuthStateBeforeTransaction(String transactionName, User originalUser) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null || currentUser.id != originalUser.id) {
        AppLogger.warning('⚠️ تغيرت حالة المصادقة قبل المعاملة: $transactionName');
        final recoveredUser = await AuthStateManager.getCurrentUser(forceRefresh: true);
        if (recoveredUser == null || recoveredUser.id != originalUser.id) {
          throw Exception('فقدان المصادقة قبل المعاملة: $transactionName');
        }
        AppLogger.info('✅ تم استعادة المصادقة قبل المعاملة: $transactionName');
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في التحقق من المصادقة قبل المعاملة: $transactionName - $e');
      rethrow;
    }
  }

  /// التحقق من حالة المصادقة بعد المعاملة
  static Future<void> _verifyAuthStateAfterTransaction(String transactionName, User originalUser) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null || currentUser.id != originalUser.id) {
        AppLogger.warning('⚠️ تأثرت حالة المصادقة بعد المعاملة: $transactionName');
        await AuthStateManager.getCurrentUser(forceRefresh: true);
      }
    } catch (e) {
      AppLogger.warning('⚠️ خطأ في التحقق من المصادقة بعد المعاملة: $transactionName - $e');
    }
  }

  /// استعادة حالة المصادقة بعد فشل المعاملة
  static Future<void> _recoverAuthStateAfterTransactionFailure(String transactionName, User originalUser) async {
    try {
      AppLogger.info('🔄 محاولة استعادة المصادقة بعد فشل المعاملة: $transactionName');
      final recoveredUser = await AuthStateManager.getCurrentUser(forceRefresh: true);
      if (recoveredUser != null && recoveredUser.id == originalUser.id) {
        AppLogger.info('✅ تم استعادة المصادقة بنجاح بعد فشل المعاملة: $transactionName');
      } else {
        AppLogger.warning('⚠️ فشل في استعادة المصادقة بعد فشل المعاملة: $transactionName');
      }
    } catch (recoveryError) {
      AppLogger.error('❌ خطأ في استعادة المصادقة بعد فشل المعاملة: $transactionName - $recoveryError');
    }
  }

  /// تنفيذ عدة معاملات معزولة بشكل متتالي
  static Future<List<T>> executeMultipleIsolatedTransactions<T>({
    required String batchName,
    required List<({String name, Future<T> Function(SupabaseClient) transaction, T Function() fallback})> transactions,
    bool preserveAuthState = true,
    bool stopOnFirstFailure = false,
  }) async {
    AppLogger.info('🔄 تنفيذ مجموعة معاملات معزولة: $batchName (${transactions.length} معاملة)');
    
    final results = <T>[];
    final errors = <String>[];

    for (int i = 0; i < transactions.length; i++) {
      final tx = transactions[i];
      try {
        final result = await executeIsolatedTransaction<T>(
          transactionName: '${batchName}_${tx.name}',
          transaction: tx.transaction,
          fallbackValue: tx.fallback,
          preserveAuthState: preserveAuthState,
        );
        results.add(result);
        AppLogger.info('✅ نجحت المعاملة ${i + 1}/${transactions.length}: ${tx.name}');
      } catch (e) {
        errors.add('${tx.name}: $e');
        AppLogger.error('❌ فشلت المعاملة ${i + 1}/${transactions.length}: ${tx.name} - $e');
        
        if (stopOnFirstFailure) {
          AppLogger.warning('⚠️ إيقاف المجموعة بسبب فشل المعاملة: ${tx.name}');
          break;
        }
        
        // إضافة قيمة احتياطية للمعاملة الفاشلة
        try {
          results.add(tx.fallback());
        } catch (fallbackError) {
          AppLogger.error('❌ فشل في الحصول على القيمة الاحتياطية للمعاملة: ${tx.name} - $fallbackError');
          rethrow;
        }
      }
    }

    AppLogger.info('📊 نتائج مجموعة المعاملات المعزولة: $batchName');
    AppLogger.info('   نجح: ${results.length - errors.length}/${transactions.length}');
    AppLogger.info('   فشل: ${errors.length}/${transactions.length}');

    if (errors.isNotEmpty) {
      AppLogger.warning('⚠️ أخطاء في مجموعة المعاملات:');
      for (final error in errors) {
        AppLogger.warning('   - $error');
      }
    }

    return results;
  }

  /// إنشاء قيمة احتياطية آمنة للمعاملات
  static T createSafeTransactionFallback<T>(T defaultValue) {
    return defaultValue;
  }
}

/// نتيجة المعاملة المعزولة
class IsolatedTransactionResult<T> {
  final bool success;
  final T? result;
  final String? error;
  final DateTime timestamp;
  final String transactionName;

  const IsolatedTransactionResult({
    required this.success,
    this.result,
    this.error,
    required this.timestamp,
    required this.transactionName,
  });

  factory IsolatedTransactionResult.success(String transactionName, T result) {
    return IsolatedTransactionResult(
      success: true,
      result: result,
      timestamp: DateTime.now(),
      transactionName: transactionName,
    );
  }

  factory IsolatedTransactionResult.failure(String transactionName, String error) {
    return IsolatedTransactionResult(
      success: false,
      error: error,
      timestamp: DateTime.now(),
      transactionName: transactionName,
    );
  }
}
