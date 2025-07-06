import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_logger.dart';

/// أداة إصلاح مشاكل المصادقة المتقدمة
class AuthFixUtility {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// إصلاح حالة المصادقة للمستخدم المحدد
  static Future<bool> fixAuthConfirmation(String email) async {
    try {
      AppLogger.info('Fixing auth confirmation for: $email');
      
      // محاولة إصلاح حالة المصادقة باستخدام RPC
      await _supabase.rpc('fix_user_auth_status', params: {
        'user_email': email,
      });

      AppLogger.info('Auth confirmation fixed for: $email');
      return true;
    } catch (e) {
      AppLogger.error('Error fixing auth confirmation: $e');
      return false;
    }
  }

  /// إصلاح شامل للمستخدم (قاعدة البيانات + مصادقة)
  static Future<AuthFixResult> comprehensiveUserFix(String email) async {
    final result = AuthFixResult();
    
    try {
      AppLogger.info('Starting comprehensive fix for: $email');
      
      // 1. فحص الحالة الحالية
      result.initialStatus = await getUserStatus(email);
      
      // 2. إصلاح قاعدة البيانات
      final dbFixed = await fixDatabaseStatus(email);
      result.databaseFixed = dbFixed;
      
      // 3. إصلاح المصادقة
      final authFixed = await fixAuthConfirmation(email);
      result.authFixed = authFixed;
      
      // 4. فحص الحالة النهائية
      result.finalStatus = await getUserStatus(email);
      
      result.success = dbFixed && authFixed;
      AppLogger.info('Comprehensive fix completed for: $email');
      
    } catch (e) {
      result.success = false;
      result.error = e.toString();
      AppLogger.error('Comprehensive fix failed for $email: $e');
    }
    
    return result;
  }

  /// إصلاح حالة قاعدة البيانات
  static Future<bool> fixDatabaseStatus(String email) async {
    try {
      await _supabase
          .from('user_profiles')
          .update({
            'status': 'active',
            'email_confirmed': true,
            'email_confirmed_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('email', email);

      return true;
    } catch (e) {
      AppLogger.error('Error fixing database status: $e');
      return false;
    }
  }

  /// الحصول على حالة المستخدم الشاملة
  static Future<UserStatusInfo> getUserStatus(String email) async {
    try {
      // فحص قاعدة البيانات
      final userProfile = await _supabase
          .from('user_profiles')
          .select('*')
          .eq('email', email)
          .maybeSingle();

      return UserStatusInfo(
        email: email,
        exists: userProfile != null,
        status: userProfile?['status'] as String?,
        emailConfirmed: (userProfile?['email_confirmed'] as bool?) ?? false,
        emailConfirmedAt: userProfile?['email_confirmed_at'] as String?,
        updatedAt: userProfile?['updated_at'] as String?,
      );
    } catch (e) {
      AppLogger.error('Error getting user status: $e');
      return UserStatusInfo(email: email, exists: false);
    }
  }

  /// محاولة تسجيل دخول تجريبي
  static Future<bool> testLogin(String email, String password) async {
    try {
      AppLogger.info('Testing login for: $email');
      
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        AppLogger.info('Login test successful for: $email');
        
        // تسجيل الخروج فوراً
        await _supabase.auth.signOut();
        return true;
      }
      
      return false;
    } catch (e) {
      AppLogger.error('Login test failed for $email: $e');
      return false;
    }
  }

  /// إعادة تعيين كلمة المرور للمستخدم
  static Future<bool> resetUserPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
      AppLogger.info('Password reset email sent to: $email');
      return true;
    } catch (e) {
      AppLogger.error('Error sending password reset: $e');
      return false;
    }
  }

  /// فحص شامل لجميع المستخدمين العالقين
  static Future<List<UserStatusInfo>> findStuckUsers() async {
    try {
      final users = await _supabase
          .from('user_profiles')
          .select('*')
          .eq('status', 'approved');

      final List<UserStatusInfo> stuckUsers = [];
      
      for (final user in users) {
        final email = user['email'] as String;
        final status = await getUserStatus(email);
        if (!status.emailConfirmed || status.status != 'active') {
          stuckUsers.add(status);
        }
      }

      return stuckUsers;
    } catch (e) {
      AppLogger.error('Error finding stuck users: $e');
      return [];
    }
  }

  /// إصلاح جميع المستخدمين العالقين
  static Future<List<AuthFixResult>> fixAllStuckUsers() async {
    try {
      final stuckUsers = await findStuckUsers();
      final List<AuthFixResult> results = [];

      for (final user in stuckUsers) {
        final result = await comprehensiveUserFix(user.email);
        results.add(result);
      }

      return results;
    } catch (e) {
      AppLogger.error('Error fixing all stuck users: $e');
      return [];
    }
  }
}

/// معلومات حالة المستخدم
class UserStatusInfo {

  UserStatusInfo({
    required this.email,
    required this.exists,
    this.status,
    this.emailConfirmed = false,
    this.emailConfirmedAt,
    this.updatedAt,
  });
  final String email;
  final bool exists;
  final String? status;
  final bool emailConfirmed;
  final String? emailConfirmedAt;
  final String? updatedAt;

  @override
  String toString() {
    return '''
معلومات المستخدم: $email
- موجود: $exists
- الحالة: ${status ?? 'غير محدد'}
- البريد مؤكد: $emailConfirmed
- تاريخ التأكيد: ${emailConfirmedAt ?? 'غير محدد'}
- آخر تحديث: ${updatedAt ?? 'غير محدد'}
''';
  }
}

/// نتيجة إصلاح المصادقة
class AuthFixResult {
  bool success = false;
  String? error;
  UserStatusInfo? initialStatus;
  UserStatusInfo? finalStatus;
  bool databaseFixed = false;
  bool authFixed = false;

  @override
  String toString() {
    return '''
نتيجة الإصلاح:
- النجاح: $success
- إصلاح قاعدة البيانات: $databaseFixed
- إصلاح المصادقة: $authFixed
- الخطأ: ${error ?? 'لا يوجد'}

الحالة الأولية:
${initialStatus?.toString() ?? 'غير متوفر'}

الحالة النهائية:
${finalStatus?.toString() ?? 'غير متوفر'}
''';
  }
}
