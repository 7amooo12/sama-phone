import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_logger.dart';

/// خدمة إدارة تأكيد البريد الإلكتروني
class EmailConfirmationService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// فحص حالة تأكيد البريد الإلكتروني للمستخدم
  static Future<EmailConfirmationStatus> checkEmailConfirmationStatus(String userId) async {
    try {
      // فحص حالة المستخدم في auth.users
      final response = await _supabase
          .from('user_profiles')
          .select('id, email, status, created_at')
          .eq('id', userId)
          .single();

      // فحص حالة المستخدم في جدول المصادقة
      final authUser = _supabase.auth.currentUser;
      if (authUser != null && authUser.id == userId) {
        if (authUser.emailConfirmedAt != null) {
          return EmailConfirmationStatus.confirmed;
        } else {
          return EmailConfirmationStatus.pending;
        }
      }

      // إذا لم نتمكن من الوصول لبيانات المصادقة، نفحص التوقيت
      final createdAt = DateTime.parse(response['created_at']);
      final hoursSinceCreation = DateTime.now().difference(createdAt).inHours;

      if (hoursSinceCreation > 24) {
        return EmailConfirmationStatus.expired;
      }

      return EmailConfirmationStatus.pending;
    } catch (e) {
      AppLogger.error('Error checking email confirmation status: $e');
      return EmailConfirmationStatus.error;
    }
  }

  /// إعادة إرسال بريد التأكيد
  static Future<bool> resendConfirmationEmail(String email) async {
    try {
      AppLogger.info('Resending confirmation email to: $email');
      
      await _supabase.auth.resend(
        type: OtpType.signup,
        email: email,
      );

      AppLogger.info('Confirmation email resent successfully to: $email');
      return true;
    } catch (e) {
      AppLogger.error('Error resending confirmation email: $e');
      return false;
    }
  }

  /// تأكيد البريد الإلكتروني يدوياً (للأدمن فقط)
  static Future<bool> manuallyConfirmEmail(String userId) async {
    try {
      AppLogger.info('Manually confirming email for user: $userId');

      // تحديث حالة المستخدم في قاعدة البيانات
      await _supabase
          .from('user_profiles')
          .update({
            'email_confirmed': true,
            'email_confirmed_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);

      AppLogger.info('Email manually confirmed for user: $userId');
      return true;
    } catch (e) {
      AppLogger.error('Error manually confirming email: $e');
      return false;
    }
  }

  /// فحص ما إذا كان المستخدم بحاجة لتأكيد البريد الإلكتروني
  static Future<bool> needsEmailConfirmation(String email) async {
    try {
      final userProfile = await _supabase
          .from('user_profiles')
          .select('id, email_confirmed, status')
          .eq('email', email)
          .maybeSingle();

      if (userProfile == null) {
        return false;
      }

      // إذا كان المستخدم موافق عليه من الأدمن لكن البريد غير مؤكد - FIXED: Accept both statuses
      final isApproved = userProfile['status'] == 'approved' || userProfile['status'] == 'active';
      final isEmailConfirmed = userProfile['email_confirmed'] == true;

      return isApproved && !isEmailConfirmed;
    } catch (e) {
      AppLogger.error('Error checking if user needs email confirmation: $e');
      return false;
    }
  }

  /// الحصول على معلومات تفصيلية عن حالة التأكيد
  static Future<EmailConfirmationInfo> getConfirmationInfo(String userId) async {
    try {
      final userProfile = await _supabase
          .from('user_profiles')
          .select('*')
          .eq('id', userId)
          .single();

      final authUser = _supabase.auth.currentUser;
      
      return EmailConfirmationInfo(
        userId: userId,
        email: userProfile['email'],
        isEmailConfirmed: userProfile['email_confirmed'] ?? false,
        emailConfirmedAt: userProfile['email_confirmed_at'] != null 
            ? DateTime.parse(userProfile['email_confirmed_at']) 
            : null,
        isApproved: userProfile['status'] == 'approved',
        createdAt: DateTime.parse(userProfile['created_at']),
        authEmailConfirmed: authUser?.emailConfirmedAt != null,
      );
    } catch (e) {
      AppLogger.error('Error getting confirmation info: $e');
      rethrow;
    }
  }

  /// إصلاح حالة التأكيد للمستخدمين المعلقين
  static Future<bool> fixStuckConfirmation(String userId) async {
    try {
      AppLogger.info('Fixing stuck confirmation for user: $userId');

      final info = await getConfirmationInfo(userId);
      
      // إذا كان المستخدم موافق عليه من الأدمن، نؤكد البريد تلقائياً
      if (info.isApproved && !info.isEmailConfirmed) {
        await manuallyConfirmEmail(userId);
        
        // تحديث حالة المستخدم لتكون نشطة
        await _supabase
            .from('user_profiles')
            .update({
              'status': 'active',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', userId);

        AppLogger.info('Fixed stuck confirmation for user: $userId');
        return true;
      }

      return false;
    } catch (e) {
      AppLogger.error('Error fixing stuck confirmation: $e');
      return false;
    }
  }
}

/// حالات تأكيد البريد الإلكتروني
enum EmailConfirmationStatus {
  confirmed,
  pending,
  expired,
  userNotFound,
  error,
}

/// معلومات تفصيلية عن حالة التأكيد
class EmailConfirmationInfo {

  EmailConfirmationInfo({
    required this.userId,
    required this.email,
    required this.isEmailConfirmed,
    this.emailConfirmedAt,
    required this.isApproved,
    required this.createdAt,
    required this.authEmailConfirmed,
  });
  final String userId;
  final String email;
  final bool isEmailConfirmed;
  final DateTime? emailConfirmedAt;
  final bool isApproved;
  final DateTime createdAt;
  final bool authEmailConfirmed;

  /// هل المستخدم عالق في حالة انتظار التأكيد؟
  bool get isStuck => isApproved && !isEmailConfirmed && !authEmailConfirmed;

  /// هل انتهت صلاحية رابط التأكيد؟
  bool get isExpired => DateTime.now().difference(createdAt).inHours > 24;

  /// هل يحتاج المستخدم لإعادة إرسال بريد التأكيد؟
  bool get needsResend => !isEmailConfirmed && !authEmailConfirmed;
}
