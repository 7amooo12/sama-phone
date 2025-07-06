import 'package:smartbiztracker_new/services/supabase_service.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// فئة لإعداد حساب الأدمن الرئيسي
class AdminSetup {
  static const String adminEmail = 'admin@samastore.com';
  static const String adminPassword = 'mn402729';
  static const String adminName = 'مدير النظام';

  /// التحقق من وجود حساب الأدمن وإنشاؤه إذا لم يكن موجوداً
  static Future<void> ensureAdminExists() async {
    try {
      AppLogger.info('Checking if admin user exists...');

      final supabase = Supabase.instance.client;

      // البحث عن حساب الأدمن في قاعدة البيانات
      final response = await supabase
          .from('user_profiles')
          .select()
          .eq('email', adminEmail)
          .maybeSingle();

      if (response != null) {
        AppLogger.info('Admin user found, checking status...');

        // التأكد من أن حساب الأدمن له الصلاحيات الصحيحة
        await _updateAdminStatus(response['id'] as String);

        AppLogger.info('Admin user status updated successfully');
      } else {
        AppLogger.info('Admin user not found, creating...');
        await _createAdminUser();
      }
    } catch (e) {
      AppLogger.error('Error ensuring admin exists: $e');
    }
  }

  /// إنشاء حساب الأدمن الرئيسي
  static Future<void> _createAdminUser() async {
    try {
      final supabase = Supabase.instance.client;

      AppLogger.info('Attempting to create admin user in Auth...');

      // First check if auth user already exists
      try {
        final existingAuthResponse = await supabase.auth.signInWithPassword(
          email: adminEmail,
          password: adminPassword,
        );

        if (existingAuthResponse.user != null) {
          AppLogger.info('Admin auth user already exists with ID: ${existingAuthResponse.user!.id}');

          // Create or update profile for existing auth user
          await _createUserProfile(existingAuthResponse.user!.id);

          // Sign out after profile creation
          await supabase.auth.signOut();
          AppLogger.info('Admin profile created/updated for existing auth user');
          return;
        }
      } catch (signInError) {
        // If sign in fails, user might not exist or password is wrong
        if (signInError.toString().contains('Invalid login credentials')) {
          AppLogger.info('Admin auth user exists but password might be different');
          // Continue with profile creation attempt
          try {
            await _createAdminProfile();
            return;
          } catch (profileError) {
            AppLogger.warning('Failed to create profile for existing auth user: $profileError');
          }
        }
        // User doesn't exist, continue with creation
        AppLogger.info('Admin auth user does not exist, creating new one...');
      }

      // إنشاء المستخدم في Auth
      final authResponse = await supabase.auth.signUp(
        email: adminEmail,
        password: adminPassword,
      );

      if (authResponse.user != null) {
        AppLogger.info('Admin user created in Auth with ID: ${authResponse.user!.id}');

        // إنشاء البروفايل في قاعدة البيانات
        await _createUserProfile(authResponse.user!.id);

        AppLogger.info('Admin user created successfully');
      } else {
        AppLogger.error('Failed to create admin user in Auth');
      }
    } catch (e) {
      AppLogger.error('Error creating admin user: $e');

      // إذا فشل إنشاء المستخدم، قد يكون موجوداً بالفعل في Auth
      // نحاول إنشاء البروفايل فقط
      try {
        AppLogger.info('Attempting to create admin profile for existing user...');
        await _createAdminProfile();
      } catch (e2) {
        AppLogger.error('Error creating admin profile: $e2');
      }
    }
  }

  /// إنشاء بروفايل المستخدم في قاعدة البيانات
  static Future<void> _createUserProfile(String userId) async {
    try {
      final supabase = Supabase.instance.client;

      AppLogger.info('Creating user profile for admin with ID: $userId');

      await supabase.from('user_profiles').upsert({
        'id': userId,
        'name': adminName,
        'email': adminEmail,
        'role': 'admin',
        'status': 'approved',
        'phone_number': '+966500000000',
        'email_confirmed': true,
        'email_confirmed_at': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      AppLogger.info('Admin user profile created successfully');

      // التحقق من إنشاء البروفايل
      await _verifyAdminProfile(userId);

    } catch (e) {
      AppLogger.error('Error creating user profile: $e');
      rethrow;
    }
  }

  /// التحقق من إنشاء بروفايل الأدمن
  static Future<void> _verifyAdminProfile(String userId) async {
    try {
      final supabase = Supabase.instance.client;

      final profile = await supabase
          .from('user_profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (profile != null) {
        AppLogger.info('✅ Admin profile verified: ${profile['email']} | Role: ${profile['role']} | Status: ${profile['status']}');
      } else {
        AppLogger.error('❌ Admin profile not found after creation!');
      }
    } catch (e) {
      AppLogger.error('Error verifying admin profile: $e');
    }
  }

  /// إنشاء بروفايل الأدمن إذا كان موجوداً في Auth فقط
  static Future<void> _createAdminProfile() async {
    try {
      final supabase = Supabase.instance.client;

      AppLogger.info('Attempting to sign in to get admin user ID...');

      // محاولة تسجيل الدخول للحصول على ID المستخدم
      final authResponse = await supabase.auth.signInWithPassword(
        email: adminEmail,
        password: adminPassword,
      );

      if (authResponse.user != null) {
        AppLogger.info('Successfully signed in admin, creating profile...');

        // إنشاء البروفايل
        await _createUserProfile(authResponse.user!.id);

        AppLogger.info('Admin profile created successfully');

        // تسجيل الخروج بعد الإنشاء
        await supabase.auth.signOut();
        AppLogger.info('Signed out after profile creation');
      } else {
        AppLogger.error('Failed to sign in admin user to create profile');
      }
    } catch (e) {
      AppLogger.error('Error creating admin profile: $e');
    }
  }

  /// تحديث حالة حساب الأدمن للتأكد من الصلاحيات الصحيحة
  static Future<void> _updateAdminStatus(String userId) async {
    try {
      final supabase = Supabase.instance.client;

      await supabase.from('user_profiles').update({
        'role': 'admin',
        'status': 'approved',
        'email_confirmed': true,
        'email_confirmed_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      AppLogger.info('Admin status updated successfully');
    } catch (e) {
      AppLogger.error('Error updating admin status: $e');
    }
  }

  /// التحقق من صحة بيانات تسجيل دخول الأدمن
  static Future<bool> validateAdminLogin() async {
    try {
      final supabaseService = SupabaseService();
      final user = await supabaseService.signIn(adminEmail, adminPassword);

      if (user != null) {
        AppLogger.info('Admin login validation successful');
        // تسجيل الخروج بعد التحقق
        await supabaseService.signOut();
        return true;
      } else {
        AppLogger.warning('Admin login validation failed');
        return false;
      }
    } catch (e) {
      AppLogger.error('Error validating admin login: $e');
      return false;
    }
  }

  /// إعادة تعيين كلمة مرور الأدمن
  static Future<bool> resetAdminPassword() async {
    try {
      final supabase = Supabase.instance.client;

      await supabase.auth.resetPasswordForEmail(adminEmail);
      AppLogger.info('Admin password reset email sent');
      return true;
    } catch (e) {
      AppLogger.error('Error resetting admin password: $e');
      return false;
    }
  }

  /// عرض جميع الحسابات الموجودة في النظام (للتطوير فقط)
  static Future<void> listAllAccounts() async {
    try {
      final supabase = Supabase.instance.client;

      AppLogger.info('=== LISTING ALL ACCOUNTS IN SYSTEM ===');

      // البحث عن جميع المستخدمين
      final response = await supabase
          .from('user_profiles')
          .select('id, email, name, role, status, created_at')
          .order('created_at');

      if (response.isEmpty) {
        AppLogger.warning('No accounts found in the system');
      } else {
        AppLogger.info('Found ${response.length} accounts:');
        for (int i = 0; i < response.length; i++) {
          final user = response[i];
          AppLogger.info('${i + 1}. Email: ${user['email']} | Role: ${user['role']} | Status: ${user['status']} | Name: ${user['name']}');
        }
      }

      AppLogger.info('=== MAIN ADMIN CREDENTIALS ===');
      AppLogger.info('Email: $adminEmail');
      AppLogger.info('Password: $adminPassword');
      AppLogger.info('================================');

    } catch (e) {
      AppLogger.error('Error listing accounts: $e');
    }
  }

  /// التحقق من وجود حساب معين
  static Future<bool> checkAccountExists(String email) async {
    try {
      final supabase = Supabase.instance.client;

      final response = await supabase
          .from('user_profiles')
          .select('email, role, status')
          .eq('email', email)
          .maybeSingle();

      if (response != null) {
        AppLogger.info('Account found: $email | Role: ${response['role']} | Status: ${response['status']}');
        return true;
      } else {
        AppLogger.warning('Account NOT found: $email');
        return false;
      }
    } catch (e) {
      AppLogger.error('Error checking account $email: $e');
      return false;
    }
  }

  /// إعادة إنشاء حساب الأدمن بالقوة (للاستكشاف والإصلاح)
  static Future<void> forceRecreateAdmin() async {
    try {
      AppLogger.info('=== FORCE RECREATING ADMIN ACCOUNT ===');

      final supabase = Supabase.instance.client;

      // محاولة تسجيل الدخول أولاً للتحقق من وجود المستخدم في Auth
      try {
        final authResponse = await supabase.auth.signInWithPassword(
          email: adminEmail,
          password: adminPassword,
        );

        if (authResponse.user != null) {
          AppLogger.info('Admin exists in Auth with ID: ${authResponse.user!.id}');

          // حذف البروفايل الموجود إن وجد
          await supabase.from('user_profiles').delete().eq('id', authResponse.user!.id);
          AppLogger.info('Deleted existing profile');

          // إنشاء بروفايل جديد
          await _createUserProfile(authResponse.user!.id);

          // تسجيل الخروج
          await supabase.auth.signOut();
          AppLogger.info('Admin profile recreated successfully');
        }
      } catch (e) {
        AppLogger.info('Admin not found in Auth, creating new account...');
        await _createAdminUser();
      }

      AppLogger.info('=== ADMIN RECREATION COMPLETED ===');
    } catch (e) {
      AppLogger.error('Error force recreating admin: $e');
    }
  }
}
