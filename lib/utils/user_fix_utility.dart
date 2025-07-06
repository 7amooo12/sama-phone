import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/email_confirmation_service.dart';
import '../utils/app_logger.dart';

/// أداة إصلاح المستخدمين العالقين في حالة تأكيد البريد الإلكتروني
class UserFixUtility {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// إصلاح المستخدم المحدد (6a9eb412-d07a-4c65-ae26-2f9d5a4b63af)
  static Future<bool> fixSpecificUser() async {
    const userId = '6a9eb412-d07a-4c65-ae26-2f9d5a4b63af';
    
    try {
      AppLogger.info('Starting fix for user: $userId');
      
      // 1. فحص حالة المستخدم الحالية
      final userProfile = await _supabase
          .from('user_profiles')
          .select('*')
          .eq('id', userId)
          .maybeSingle();

      if (userProfile == null) {
        AppLogger.error('User not found: $userId');
        return false;
      }

      AppLogger.info('Current user status: ${userProfile['status']}');
      AppLogger.info('Current email confirmed: ${userProfile['email_confirmed']}');

      // 2. إصلاح حالة تأكيد البريد الإلكتروني
      final success = await EmailConfirmationService.fixStuckConfirmation(userId);
      
      if (success) {
        AppLogger.info('Successfully fixed user: $userId');
        
        // 3. التحقق من النتيجة
        final updatedProfile = await _supabase
            .from('user_profiles')
            .select('*')
            .eq('id', userId)
            .single();
            
        AppLogger.info('Updated user status: ${updatedProfile['status']}');
        AppLogger.info('Updated email confirmed: ${updatedProfile['email_confirmed']}');
        
        return true;
      } else {
        AppLogger.error('Failed to fix user: $userId');
        return false;
      }
    } catch (e) {
      AppLogger.error('Error fixing user $userId: $e');
      return false;
    }
  }

  /// إصلاح جميع المستخدمين العالقين
  static Future<List<String>> fixAllStuckUsers() async {
    final List<String> fixedUsers = [];
    
    try {
      AppLogger.info('Starting fix for all stuck users');
      
      // البحث عن المستخدمين العالقين
      final stuckUsers = await _supabase
          .from('user_profiles')
          .select('*')
          .eq('status', 'approved')
          .neq('email_confirmed', true);

      AppLogger.info('Found ${stuckUsers.length} stuck users');

      for (final user in stuckUsers) {
        final userId = user['id'] as String;
        final email = user['email'] as String;
        
        try {
          final success = await EmailConfirmationService.fixStuckConfirmation(userId);
          if (success) {
            fixedUsers.add(email);
            AppLogger.info('Fixed user: $email');
          } else {
            AppLogger.warning('Failed to fix user: $email');
          }
        } catch (e) {
          AppLogger.error('Error fixing user $email: $e');
        }
      }

      AppLogger.info('Fixed ${fixedUsers.length} users');
      return fixedUsers;
    } catch (e) {
      AppLogger.error('Error in fixAllStuckUsers: $e');
      return fixedUsers;
    }
  }

  /// تشغيل فحص شامل وإصلاح للمستخدمين
  static Future<FixReport> runComprehensiveCheck() async {
    final report = FixReport();
    
    try {
      AppLogger.info('Starting comprehensive user check');
      
      // 1. فحص جميع المستخدمين
      final allUsers = await _supabase
          .from('user_profiles')
          .select('*');

      report.totalUsers = allUsers.length;

      for (final user in allUsers) {
        final userId = user['id'] as String;
        final email = user['email'] as String;
        final status = user['status'] as String;
        final emailConfirmed = user['email_confirmed'] ?? false;

        // تصنيف المستخدمين
        if (status == 'pending') {
          report.pendingUsers.add(email);
        } else if (status == 'approved' && !emailConfirmed) {
          report.stuckUsers.add(email);
        } else if (status == 'active' && emailConfirmed) {
          report.activeUsers.add(email);
        } else {
          report.otherUsers.add(email);
        }
      }

      // 2. إصلاح المستخدمين العالقين
      for (final email in report.stuckUsers) {
        final userProfile = await _supabase
            .from('user_profiles')
            .select('id')
            .eq('email', email)
            .single();
            
        final userId = userProfile['id'] as String;
        
        try {
          final success = await EmailConfirmationService.fixStuckConfirmation(userId);
          if (success) {
            report.fixedUsers.add(email);
          } else {
            report.failedFixes.add(email);
          }
        } catch (e) {
          report.failedFixes.add(email);
          AppLogger.error('Failed to fix $email: $e');
        }
      }

      AppLogger.info('Comprehensive check completed');
      return report;
    } catch (e) {
      AppLogger.error('Error in comprehensive check: $e');
      return report;
    }
  }

  /// إضافة عمود email_confirmed إلى جدول user_profiles إذا لم يكن موجوداً
  static Future<bool> ensureEmailConfirmedColumn() async {
    try {
      // محاولة إضافة العمود (سيفشل إذا كان موجوداً بالفعل)
      await _supabase.rpc('add_email_confirmed_column');
      AppLogger.info('Added email_confirmed column to user_profiles');
      return true;
    } catch (e) {
      // إذا فشل، فالعمود موجود بالفعل أو هناك خطأ آخر
      AppLogger.info('email_confirmed column already exists or error: $e');
      return false;
    }
  }
}

/// تقرير شامل عن حالة المستخدمين
class FixReport {
  int totalUsers = 0;
  List<String> pendingUsers = [];
  List<String> stuckUsers = [];
  List<String> activeUsers = [];
  List<String> otherUsers = [];
  List<String> fixedUsers = [];
  List<String> failedFixes = [];

  @override
  String toString() {
    return '''
تقرير شامل عن حالة المستخدمين:
- إجمالي المستخدمين: $totalUsers
- في انتظار الموافقة: ${pendingUsers.length}
- عالقين (موافق عليهم لكن البريد غير مؤكد): ${stuckUsers.length}
- نشطين: ${activeUsers.length}
- آخرين: ${otherUsers.length}
- تم إصلاحهم: ${fixedUsers.length}
- فشل إصلاحهم: ${failedFixes.length}

المستخدمين العالقين:
${stuckUsers.join('\n')}

المستخدمين المُصلحين:
${fixedUsers.join('\n')}

المستخدمين الذين فشل إصلاحهم:
${failedFixes.join('\n')}
''';
  }
}
