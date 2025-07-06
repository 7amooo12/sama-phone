import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_logger.dart';

/// أداة إصلاح طارئ للمستخدمين العالقين
class EmergencyFix {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// إصلاح المستخدم المحدد (testo@sama.com)
  static Future<bool> fixSpecificUser() async {
    try {
      AppLogger.info('Starting emergency fix for testo@sama.com');
      
      // إصلاح المستخدم مباشرة
      await _supabase
          .from('user_profiles')
          .update({
            'status': 'active',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('email', 'testo@sama.com');

      AppLogger.info('Emergency fix completed for testo@sama.com');
      return true;
    } catch (e) {
      AppLogger.error('Emergency fix failed: $e');
      return false;
    }
  }

  /// إصلاح جميع المستخدمين الموافق عليهم
  static Future<List<String>> fixAllApprovedUsers() async {
    final List<String> fixedUsers = [];
    
    try {
      AppLogger.info('Starting emergency fix for all approved users');
      
      // البحث عن المستخدمين الموافق عليهم
      final approvedUsers = await _supabase
          .from('user_profiles')
          .select('id, email, status')
          .eq('status', 'approved');

      AppLogger.info('Found ${approvedUsers.length} approved users');

      for (final user in approvedUsers) {
        try {
          await _supabase
              .from('user_profiles')
              .update({
                'status': 'active',
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', user['id'] as String);

          fixedUsers.add(user['email'] as String);
          AppLogger.info('Fixed user: ${user['email']}');
        } catch (e) {
          AppLogger.error('Failed to fix user ${user['email']}: $e');
        }
      }

      AppLogger.info('Emergency fix completed. Fixed ${fixedUsers.length} users');
      return fixedUsers;
    } catch (e) {
      AppLogger.error('Emergency fix failed: $e');
      return fixedUsers;
    }
  }

  /// فحص حالة المستخدم
  static Future<Map<String, dynamic>?> checkUserStatus(String email) async {
    try {
      final user = await _supabase
          .from('user_profiles')
          .select('*')
          .eq('email', email)
          .maybeSingle();

      if (user != null) {
        AppLogger.info('User status for $email: ${user['status']}');
        return user;
      } else {
        AppLogger.warning('User not found: $email');
        return null;
      }
    } catch (e) {
      AppLogger.error('Error checking user status: $e');
      return null;
    }
  }

  /// تقرير سريع عن حالة المستخدمين
  static Future<Map<String, int>> getQuickReport() async {
    try {
      final allUsers = await _supabase
          .from('user_profiles')
          .select('status');

      final Map<String, int> report = {
        'pending': 0,
        'approved': 0,
        'active': 0,
        'rejected': 0,
        'other': 0,
      };

      for (final user in allUsers) {
        final status = user['status'] as String;
        if (report.containsKey(status)) {
          report[status] = report[status]! + 1;
        } else {
          report['other'] = report['other']! + 1;
        }
      }

      AppLogger.info('Quick report: $report');
      return report;
    } catch (e) {
      AppLogger.error('Error generating quick report: $e');
      return {};
    }
  }

  /// إصلاح شامل للمشكلة
  static Future<EmergencyFixResult> runComprehensiveFix() async {
    final result = EmergencyFixResult();
    
    try {
      AppLogger.info('Starting comprehensive emergency fix');
      
      // 1. فحص الوضع الحالي
      result.initialReport = await getQuickReport();
      
      // 2. إصلاح المستخدم المحدد
      final specificFixed = await fixSpecificUser();
      if (specificFixed) {
        result.fixedSpecificUser = true;
      }
      
      // 3. إصلاح جميع المستخدمين الموافق عليهم
      result.fixedUsers = await fixAllApprovedUsers();
      
      // 4. فحص الوضع بعد الإصلاح
      result.finalReport = await getQuickReport();
      
      result.success = true;
      AppLogger.info('Comprehensive emergency fix completed successfully');
      
    } catch (e) {
      result.success = false;
      result.error = e.toString();
      AppLogger.error('Comprehensive emergency fix failed: $e');
    }
    
    return result;
  }

  /// تشغيل اختبار سريع لتسجيل الدخول
  static Future<bool> testLogin(String email, String password) async {
    try {
      AppLogger.info('Testing login for: $email');
      
      // محاولة تسجيل الدخول
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        AppLogger.info('Login test successful for: $email');
        
        // تسجيل الخروج فوراً
        await _supabase.auth.signOut();
        
        return true;
      } else {
        AppLogger.warning('Login test failed for: $email');
        return false;
      }
    } catch (e) {
      AppLogger.error('Login test error for $email: $e');
      return false;
    }
  }
}

/// نتيجة الإصلاح الطارئ
class EmergencyFixResult {
  bool success = false;
  String? error;
  Map<String, int> initialReport = {};
  Map<String, int> finalReport = {};
  bool fixedSpecificUser = false;
  List<String> fixedUsers = [];

  @override
  String toString() {
    return '''
نتيجة الإصلاح الطارئ:
- النجاح: $success
- الخطأ: ${error ?? 'لا يوجد'}
- إصلاح المستخدم المحدد: $fixedSpecificUser
- المستخدمين المُصلحين: ${fixedUsers.length}
- التقرير الأولي: $initialReport
- التقرير النهائي: $finalReport

المستخدمين المُصلحين:
${fixedUsers.join('\n')}
''';
  }
}
