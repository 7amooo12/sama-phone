import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';
import '../utils/app_logger.dart';
import 'test_session_service.dart';

/// استثناء مخصص لحالة انتظار الموافقة
class PendingApprovalException implements Exception {
  PendingApprovalException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Service to handle Supabase operations: auth, storage, database
class SupabaseService {
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  // Lazy initialization to avoid accessing Supabase.instance before initialization
  SupabaseClient get _supabase {
    try {
      return Supabase.instance.client;
    } catch (e) {
      AppLogger.error('❌ Supabase not initialized yet in SupabaseService: $e');
      throw Exception('Supabase must be initialized before using SupabaseService');
    }
  }

  // Singleton pattern
  static final SupabaseService _instance = SupabaseService._internal();

  // Get current session
  Session? get currentSession => _supabase.auth.currentSession;

  // Get current user
  User? get currentUser => _supabase.auth.currentUser;

  // Get user ID
  String? get currentUserId => _supabase.auth.currentUser?.id;

  // Auth Methods

  /// Check if user already exists by email using safe RPC function
  Future<bool> userExistsByEmail(String email) async {
    try {
      final result = await _supabase.rpc('user_exists_by_email', params: {
        'check_email': email,
      });
      return result as bool? ?? false;
    } catch (e) {
      AppLogger.error('Error checking if user exists: $e');
      return false;
    }
  }

  /// Check if auth user exists by email using safe RPC function
  Future<bool> authUserExistsByEmail(String email) async {
    try {
      final result = await _supabase.rpc('auth_user_exists_by_email', params: {
        'check_email': email,
      });
      return result as bool? ?? false;
    } catch (e) {
      AppLogger.error('Error checking auth user existence: $e');
      return false;
    }
  }

  /// Sign up with email and password
  Future<User?> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
    String? role, // Optional role, defaults to 'client'
  }) async {
    try {
      AppLogger.info('Starting signup for: $email');

      // Simplified existence check - let Supabase handle duplicates
      try {
        final userExists = await userExistsByEmail(email);
        if (userExists) {
          AppLogger.warning('User profile already exists for: $email');
          throw Exception('المستخدم موجود بالفعل');
        }
      } catch (e) {
        AppLogger.warning('Could not check user existence, proceeding with signup: $e');
        // Continue with signup - let Supabase handle any conflicts
      }

      // SECURITY FIX: Validate name is not empty
      if (name.trim().isEmpty) {
        throw Exception('الاسم مطلوب ولا يمكن أن يكون فارغاً');
      }

      // Try to create auth user directly
      AppLogger.info('Creating auth user for: $email with name: $name');

      // Create auth user first with metadata
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name.trim(),
          'phone': phone?.trim(),
          'full_name': name.trim(), // Additional field for better compatibility
        },
        emailRedirectTo: null, // Disable email confirmation for test accounts
      );

      if (response.user != null) {
        final userId = response.user!.id;
        AppLogger.info('Auth user created successfully: $userId with metadata');

        // Wait a moment for auth user to be fully created
        await Future.delayed(const Duration(milliseconds: 500));

        try {
          // Create user profile using the safe RPC function
          await _supabase.rpc('create_user_profile_safe', params: {
            'user_id': userId,
            'user_email': email,
            'user_name': name.trim(), // Ensure name is trimmed and not null
            'user_phone': phone?.trim(),
            'user_role': role ?? 'client',
            'user_status': 'pending',
          });

          AppLogger.info('✅ User profile created successfully for: $email with name: $name');
          return response.user;
        } catch (profileError) {
          AppLogger.error('Error creating user profile: $profileError');

          // Don't fail the signup if profile creation fails
          // The user can still sign in and we'll create the profile then
          AppLogger.warning('Continuing with signup despite profile creation error');
          return response.user;
        }
      } else {
        throw Exception('فشل في إنشاء المستخدم');
      }
    } catch (e) {
      AppLogger.error('Error during signup: $e');
      rethrow;
    }
  }

  /// Sign in with email and password
  Future<User?> signIn(String email, String password) async {
    try {
      AppLogger.info('Attempting sign-in for: $email');

      // Validate Supabase client is properly initialized
      if (_supabase.auth.currentSession == null && _supabase.auth.currentUser == null) {
        AppLogger.info('No existing session found, proceeding with sign-in');
      }

      // SECURITY FIX: Validate input parameters
      if (email.isEmpty || password.isEmpty) {
        throw Exception('البريد الإلكتروني وكلمة المرور مطلوبان');
      }

      // SECURITY FIX: Remove test account bypass - all accounts must use proper authentication

      // Skip pre-authentication profile checks to avoid RLS recursion
      // We'll validate the user after successful authentication

      // Attempt to sign in first
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      // After successful authentication, minimal profile handling
      if (response.user != null) {
        try {
          // SECURITY FIX: Check if user profile already exists before creating/updating
          final existingProfile = await getUserData(response.user!.id);

          if (existingProfile == null) {
            // Only create profile if it doesn't exist
            AppLogger.info('Creating new profile for authenticated user: ${response.user!.email}');

            // Get name from metadata, but don't use null values
            final nameFromMetadata = response.user!.userMetadata?['name'] as String?;
            final nameToUse = nameFromMetadata?.isNotEmpty == true ? nameFromMetadata : null;

            await _supabase.rpc('create_user_profile_safe', params: {
              'user_id': response.user!.id,
              'user_email': response.user!.email ?? email,
              'user_name': nameToUse, // Only pass name if it's not null/empty
              'user_phone': null,
              'user_role': 'client',
              'user_status': 'pending',
            });

            AppLogger.info('✅ New profile created for authenticated user');
          } else {
            AppLogger.info('✅ Existing profile found for user: ${existingProfile.name}');
            // Don't overwrite existing profile data
          }
        } catch (profileError) {
          AppLogger.warning('Profile creation skipped: $profileError');
          // Continue with successful authentication - profile issues won't block login
        }
      }

      AppLogger.info('Login successful for: $email');
      return response.user;
    } catch (e) {
      AppLogger.error('Error during sign in: $e');

      // Handle specific error types with better error messages
      if (e is AuthException) {
        if (e.message.contains('Invalid login credentials')) {
          AppLogger.error('🔐 Invalid credentials error for: $email');
          // SECURITY FIX: Remove test account bypass - proper error message for all invalid credentials
          throw Exception('بريد إلكتروني أو كلمة مرور غير صحيحة');
        } else if (e.message.contains('Email not confirmed')) {
          AppLogger.info('Email not confirmed error for: $email');
          // SECURITY FIX: All users must confirm their email - no bypasses allowed
          throw Exception('يرجى تأكيد البريد الإلكتروني أولاً');
        } else if (e.message.contains('Project not specified')) {
          throw Exception('خطأ في إعداد الخادم. يرجى المحاولة لاحقاً');
        } else {
          throw Exception('خطأ في المصادقة: ${e.message}');
        }
      } else if (e is FormatException) {
        AppLogger.error('Format exception during sign in - possible configuration issue: $e');
        throw Exception('خطأ في إعداد الاتصال. يرجى التحقق من الإعدادات');
      } else {
        throw Exception('خطأ غير متوقع: ${e.toString()}');
      }
    }
  }

  /// SECURITY FIX: Removed _checkAdminApprovedUser method
  /// This method was part of the authentication bypass logic

  /// Confirm email for admin-approved users programmatically
  Future<bool> _confirmEmailForApprovedUser(String email) async {
    try {
      AppLogger.info('Attempting to confirm email for admin-approved user: $email');

      // Try to use admin API to confirm email
      // Note: This requires admin privileges in Supabase
      final response = await _supabase.auth.admin.updateUserById(
        await _getUserIdByEmail(email),
        attributes: AdminUserAttributes(
          emailConfirm: true,
        ),
      );

      if (response.user != null) {
        AppLogger.info('Email confirmed successfully for: $email');
        return true;
      }

      return false;
    } catch (e) {
      AppLogger.warning('Could not confirm email programmatically: $e');
      return false;
    }
  }

  /// Get user ID by email from auth.users table
  Future<String> _getUserIdByEmail(String email) async {
    try {
      // This is a simplified approach - in production you'd need proper admin access
      final userProfile = await getUserDataByEmail(email);
      if (userProfile != null) {
        return userProfile.id;
      }
      throw Exception('User not found');
    } catch (e) {
      AppLogger.error('Error getting user ID by email: $e');
      rethrow;
    }
  }

  /// SECURITY FIX: Removed _signInApprovedUser method
  /// This method was creating mock User objects without proper password validation
  /// All users must now authenticate through proper Supabase authentication

  /// SECURITY FIX: Removed _signInTestAccount method
  /// This method was allowing login with only email verification for @sama.com accounts
  /// bypassing password validation entirely. All users must now authenticate properly.

  /// Sign out current user
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
      AppLogger.info('User signed out');
    } catch (e) {
      AppLogger.error('Error signing out: $e');
      throw Exception('حدث خطأ أثناء تسجيل الخروج: $e');
    }
  }

  /// Get user data based on user ID
  Future<UserModel?> getUserData(String userId) async {
    try {
      // Use SECURITY DEFINER function to bypass RLS and avoid infinite recursion
      final response = await _supabase
          .rpc('get_user_by_id_safe', params: {'user_id': userId});

      if (response == null || response.isEmpty) {
        AppLogger.warning('⚠️ No user found for ID: $userId');
        return null;
      }

      // The RPC function returns a list, get the first item
      final userData = response is List ? response.first : response;

      return UserModel.fromJson(userData);
    } catch (e) {
      AppLogger.error('Error getting user data: $e');

      // Handle function not found errors with fallback
      if (e.toString().contains('function') && e.toString().contains('does not exist')) {
        AppLogger.warning('Database function missing - falling back to direct query');
        try {
          final fallbackResponse = await _supabase
              .from('user_profiles')
              .select()
              .eq('id', userId)
              .single();
          return UserModel.fromJson(fallbackResponse);
        } catch (fallbackError) {
          AppLogger.error('Fallback query also failed: $fallbackError');
          return null;
        }
      }

      return null;
    }
  }

  /// Get user data based on email with RLS error handling
  Future<UserModel?> getUserDataByEmail(String email) async {
    try {
      AppLogger.info('🔍 Attempting to fetch user data for email: $email');

      // Use SECURITY DEFINER function to bypass RLS and avoid infinite recursion
      final response = await _supabase
          .rpc('get_user_by_email_safe', params: {'user_email': email});

      if (response == null || response.isEmpty) {
        AppLogger.warning('⚠️ No user found for email: $email');
        return null;
      }

      // The RPC function returns a list, get the first item
      final userData = response is List ? response.first : response;

      AppLogger.info('✅ Successfully fetched user data for: $email');
      return UserModel.fromJson(userData);
    } catch (e) {
      AppLogger.error('❌ Error getting user data by email: $e');

      // Handle specific RLS infinite recursion error
      if (e.toString().contains('infinite recursion') ||
          e.toString().contains('42P17')) {
        AppLogger.error('🔄 RLS infinite recursion detected - this indicates a policy configuration issue');
        throw Exception('خطأ في إعدادات الأمان. يرجى التواصل مع الإدارة لحل هذه المشكلة.');
      }

      // Handle function not found errors
      if (e.toString().contains('function') && e.toString().contains('does not exist')) {
        AppLogger.error('🔧 Database function missing - falling back to direct query');
        // Fallback to direct query if function doesn't exist
        try {
          final fallbackResponse = await _supabase
              .from('user_profiles')
              .select()
              .eq('email', email)
              .maybeSingle();

          if (fallbackResponse == null) {
            return null;
          }
          return UserModel.fromJson(fallbackResponse);
        } catch (fallbackError) {
          AppLogger.error('❌ Fallback query also failed: $fallbackError');
          throw Exception('خطأ في الاتصال بقاعدة البيانات.');
        }
      }

      // Handle other RLS policy errors
      if (e.toString().contains('row-level security policy') ||
          e.toString().contains('permission denied')) {
        AppLogger.error('🔒 RLS policy violation detected');
        throw Exception('ليس لديك صلاحية للوصول إلى هذه البيانات.');
      }

      // Handle general database errors
      if (e.toString().contains('relation') && e.toString().contains('does not exist')) {
        AppLogger.error('🗄️ Database table missing');
        throw Exception('خطأ في قاعدة البيانات. يرجى التواصل مع الدعم الفني.');
      }

      // Generic error handling
      throw Exception('خطأ في الاتصال بقاعدة البيانات: ${e.toString()}');
    }
  }

  /// Get all users with a specific role with enhanced debugging
  Future<List<UserModel>> getUsersByRole(String role) async {
    try {
      AppLogger.info('🔍 Fetching users with role: $role');

      // First, check authentication status
      final currentUser = _supabase.auth.currentUser;
      AppLogger.info('🔐 Current authenticated user: ${currentUser?.id} (${currentUser?.email})');

      // Check total users in database for debugging
      try {
        final totalUsersResponse = await _supabase
            .from('user_profiles')
            .select('id, role, status')
            .count();
        AppLogger.info('📊 Total users in database: ${totalUsersResponse.count}');
      } catch (countError) {
        AppLogger.warning('⚠️ Could not count total users: $countError');
      }

      // Check users with the specific role (without status filter first)
      try {
        final roleUsersResponse = await _supabase
            .from('user_profiles')
            .select('id, name, email, role, status')
            .eq('role', role);

        AppLogger.info('📋 Users with role "$role": ${roleUsersResponse.length}');
        for (final user in roleUsersResponse) {
          AppLogger.info('   👤 ${user['name']} (${user['email']}) - Status: ${user['status']}');
        }
      } catch (roleError) {
        AppLogger.error('❌ Error checking users by role: $roleError');
      }

      // Now perform the actual query with status filtering
      AppLogger.info('🔄 Executing main query with status filtering...');
      final response = await _supabase
          .from('user_profiles')
          .select()
          .eq('role', role)
          .or('status.eq.approved,status.eq.active')
          .order('name');

      AppLogger.info('📦 Raw response received: ${response.length} records');

      final users = response.map<UserModel>((json) => UserModel.fromJson(json)).toList();

      AppLogger.info('✅ Successfully parsed ${users.length} users with role: $role');

      // Log user details for debugging
      for (final user in users) {
        AppLogger.info('   ✓ ${user.name} (${user.email}) - Status: ${user.status}');
      }

      return users;
    } catch (e) {
      AppLogger.error('❌ Error fetching users by role "$role": $e');

      // Enhanced error analysis
      if (e.toString().contains('row-level security policy')) {
        AppLogger.error('🔒 RLS Policy Violation: The user may not have permission to access user_profiles table');
        AppLogger.error('💡 Suggestion: Check RLS policies for user_profiles table');
      } else if (e.toString().contains('relation') && e.toString().contains('does not exist')) {
        AppLogger.error('🗄️ Table Missing: user_profiles table may not exist');
      } else if (e.toString().contains('permission denied')) {
        AppLogger.error('🚫 Permission Denied: User lacks database access permissions');
      }

      return [];
    }
  }

  /// Get all users
  Future<List<UserModel>> getAllUsers() async {
    try {
      final response = await _supabase
          .from('user_profiles')
          .select()
          .order('name');

      return response.map<UserModel>((json) => UserModel.fromJson(json)).toList();
    } catch (e) {
      AppLogger.error('Error fetching all users: $e');
      return [];
    }
  }

  // Storage Methods

  /// Upload a file to Supabase Storage
  Future<String?> uploadFile(String bucket, String path, List<int> fileBytes) async {
    try {
      await _supabase
          .storage
          .from(bucket)
          .uploadBinary(path, Uint8List.fromList(fileBytes));

      return _supabase
          .storage
          .from(bucket)
          .getPublicUrl(path);
    } catch (e) {
      AppLogger.error('Error uploading file: $e');
      return null;
    }
  }

  /// Delete file from storage
  Future<bool> deleteFile(String bucket, String path) async {
    try {
      await _supabase
          .storage
          .from(bucket)
          .remove([path]);
      return true;
    } catch (e) {
      AppLogger.error('Error deleting file: $e');
      return false;
    }
  }

  /// Get all files in a folder
  Future<List<String>> listFiles(String bucket, String path) async {
    try {
      final response = await _supabase
          .storage
          .from(bucket)
          .list(path: path);

      return response.map((file) => file.name).toList();
    } catch (e) {
      AppLogger.error('Error listing files: $e');
      return [];
    }
  }



  // Database Methods

  /// Create a record in a table
  Future<Map<String, dynamic>> createRecord(String table, Map<String, dynamic> data) async {
    try {
      final response = await _supabase.from(table).insert(data).select();
      return response[0];
    } catch (e) {
      AppLogger.error('Error creating record in $table: $e');
      throw Exception('فشل في إنشاء السجل: $e');
    }
  }

  /// Update a record in a table
  Future<Map<String, dynamic>> updateRecord(String table, String id, Map<String, dynamic> data) async {
    try {
      final response = await _supabase.from(table).update(data).eq('id', id).select();
      return response[0];
    } catch (e) {
      AppLogger.error('Error updating record in $table: $e');
      throw Exception('فشل في تحديث السجل: $e');
    }
  }

  /// Delete a record from a table
  Future<void> deleteRecord(String table, String id) async {
    try {
      await _supabase.from(table).delete().eq('id', id);
    } catch (e) {
      AppLogger.error('Error deleting record from $table: $e');
      throw Exception('فشل في حذف السجل: $e');
    }
  }

  /// Get a record by ID
  Future<Map<String, dynamic>?> getRecord(String table, String id) async {
    try {
      final response = await _supabase.from(table).select().eq('id', id).single();
      return response;
    } catch (e) {
      AppLogger.error('Error fetching record from $table: $e');
      return null;
    }
  }

  /// Get all records from a table
  Future<List<Map<String, dynamic>>> getAllRecords(String table) async {
    try {
      final response = await _supabase.from(table).select();
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      AppLogger.error('Error fetching records from $table: $e');
      return [];
    }
  }

  /// Get records with a filter
  Future<List<Map<String, dynamic>>> getRecordsByFilter(
      String table, String field, dynamic value) async {
    try {
      final response = await _supabase.from(table).select().eq(field, value);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      AppLogger.error('Error fetching filtered records from $table: $e');
      return [];
    }
  }

  /// Subscribe to realtime changes on a table
  Stream<List<Map<String, dynamic>>> streamTable(String table) {
    return _supabase
        .from(table)
        .stream(primaryKey: ['id'])
        .map((data) => data);
  }

  /// Update user role and status with automatic email confirmation for approved users
  Future<void> updateUserRoleAndStatus(
    String userId,
    String role,
    String status,
  ) async {
    try {
      AppLogger.info('🔄 Updating user $userId: role=$role, status=$status');

      // Prepare update data
      final updateData = <String, dynamic>{
        'role': role,
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // If user is being approved/activated, also confirm email
      if (status == 'active' || status == 'approved') {
        updateData['email_confirmed'] = true;
        updateData['email_confirmed_at'] = DateTime.now().toIso8601String();
        AppLogger.info('📧 Auto-confirming email for approved user: $userId');
      }

      // Update user_profiles table
      await _supabase.from('user_profiles').update(updateData).eq('id', userId);

      // If user is being approved, also try to confirm email in auth system
      if (status == 'active' || status == 'approved') {
        try {
          final userProfile = await getUserData(userId);
          if (userProfile != null) {
            await _confirmEmailInAuthSystem(userId, userProfile.email);
          }
        } catch (authError) {
          AppLogger.warning('⚠️ Could not confirm email in auth system: $authError');
          // Don't fail the update if auth confirmation fails
        }
      }

      AppLogger.info('✅ Updated user $userId: role=$role, status=$status');
    } catch (e) {
      AppLogger.error('❌ Error updating user role and status: $e');
      throw Exception('فشل في تحديث بيانات المستخدم');
    }
  }

  /// Get pending users
  Future<List<UserModel>> getPendingUsers() async {
    try {
      final response = await _supabase
          .from('user_profiles')
          .select()
          .eq('status', 'pending')
          .order('created_at');

      return (response as List)
          .map((data) => UserModel.fromJson(data as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.error('Error getting pending users: $e');
      return [];
    }
  }

  // This method is now handled by the one above

  Future<bool> updateUserRole(String userId, UserRole newRole) async {
    try {
      await _supabase
          .from('user_profiles')
          .update({
            'role': newRole.value,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);
      return true;
    } catch (e) {
      AppLogger.error('Error updating user role: $e');
      return false;
    }
  }

  Future<void> approveUser(String userId) async {
    try {
      AppLogger.info('🔄 Starting user approval process for: $userId');

      // First, get user data to get email
      final userProfile = await getUserData(userId);
      if (userProfile == null) {
        throw Exception('User not found: $userId');
      }

      AppLogger.info('📧 User email: ${userProfile.email}');

      // Update user_profiles table
      await _supabase
          .from('user_profiles')
          .update({
            'status': 'active',
            'email_confirmed': true, // تأكيد البريد تلقائياً عند الموافقة
            'email_confirmed_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);

      AppLogger.info('✅ Updated user_profiles table for: $userId');

      // Try to confirm email in Supabase auth system
      try {
        await _confirmEmailInAuthSystem(userId, userProfile.email);
        AppLogger.info('✅ Email confirmed in auth system for: ${userProfile.email}');
      } catch (authError) {
        AppLogger.warning('⚠️ Could not confirm email in auth system (user can still login): $authError');
        // Don't fail the approval process if auth confirmation fails
      }

      AppLogger.info('🎉 User approval completed successfully for: $userId');
    } catch (e) {
      AppLogger.error('❌ Error approving user: $e');
      rethrow;
    }
  }

  /// Confirm email in Supabase auth system for admin-approved users
  Future<void> _confirmEmailInAuthSystem(String userId, String email) async {
    try {
      AppLogger.info('🔄 Attempting to confirm email in auth system for: $email');

      // Method 1: Try using admin API if available
      try {
        final response = await _supabase.auth.admin.updateUserById(
          userId,
          attributes: AdminUserAttributes(
            emailConfirm: true,
          ),
        );

        if (response.user != null) {
          AppLogger.info('✅ Email confirmed via admin API for: $email');
          return;
        }
      } catch (adminError) {
        AppLogger.warning('⚠️ Admin API not available: $adminError');
      }

      // Method 2: Try using RPC function if admin API is not available
      try {
        await _supabase.rpc('confirm_user_email', params: {
          'user_id': userId,
          'user_email': email,
        });
        AppLogger.info('✅ Email confirmed via RPC function for: $email');
        return;
      } catch (rpcError) {
        AppLogger.warning('⚠️ RPC function not available: $rpcError');
      }

      // Method 3: Update auth.users table directly (requires service role)
      try {
        await _supabase
            .from('auth.users')
            .update({
              'email_confirmed_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', userId);
        AppLogger.info('✅ Email confirmed via direct table update for: $email');
        return;
      } catch (directError) {
        AppLogger.warning('⚠️ Direct table update not available: $directError');
      }

      AppLogger.warning('⚠️ All email confirmation methods failed, but user approval will continue');
    } catch (e) {
      AppLogger.error('❌ Error confirming email in auth system: $e');
      // Don't rethrow - we don't want to fail user approval if email confirmation fails
    }
  }

  /// إصلاح حالة تأكيد البريد الإلكتروني للمستخدمين المعلقين
  Future<void> _fixEmailConfirmationStatus(String userId) async {
    try {
      await _supabase
          .from('user_profiles')
          .update({
            'email_confirmed': true,
            'email_confirmed_at': DateTime.now().toIso8601String(),
            'status': 'active', // تفعيل الحساب
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);

      AppLogger.info('Fixed email confirmation status for user: $userId');
    } catch (e) {
      AppLogger.error('Error fixing email confirmation status: $e');
      // لا نرمي الخطأ هنا لأن هذا إصلاح اختياري
    }
  }

  /// إعادة إرسال بريد التأكيد
  Future<bool> resendConfirmationEmail(String email) async {
    try {
      await _supabase.auth.resend(
        type: OtpType.signup,
        email: email,
      );
      return true;
    } catch (e) {
      AppLogger.error('Error resending confirmation email: $e');
      return false;
    }
  }

  /// Fix email confirmation for existing approved users (utility method)
  Future<void> fixApprovedUsersEmailConfirmation() async {
    try {
      AppLogger.info('🔄 Starting email confirmation fix for approved users...');

      // Get all approved/active users who might have email confirmation issues
      final response = await _supabase
          .from('user_profiles')
          .select('id, email, role, status')
          .or('status.eq.approved,status.eq.active')
          .neq('role', 'client'); // Focus on non-client users who are admin-approved

      AppLogger.info('📋 Found ${response.length} approved users to check');

      for (final user in response) {
        try {
          final userId = user['id'] as String;
          final email = user['email'] as String;
          final role = user['role'] as String;

          AppLogger.info('🔧 Fixing email confirmation for: $email ($role)');

          // Update user_profiles to ensure email is marked as confirmed
          await _supabase
              .from('user_profiles')
              .update({
                'email_confirmed': true,
                'email_confirmed_at': DateTime.now().toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', userId);

          // Try to confirm in auth system
          await _confirmEmailInAuthSystem(userId, email);

          AppLogger.info('✅ Fixed email confirmation for: $email');
        } catch (userError) {
          AppLogger.warning('⚠️ Could not fix user ${user['email']}: $userError');
          continue;
        }
      }

      AppLogger.info('🎉 Email confirmation fix completed');
    } catch (e) {
      AppLogger.error('❌ Error fixing email confirmation for approved users: $e');
    }
  }

  /// Manual email confirmation for specific user (admin utility)
  Future<bool> manuallyConfirmUserEmail(String email) async {
    try {
      AppLogger.info('🔧 Manually confirming email for: $email');

      final userProfile = await getUserDataByEmail(email);
      if (userProfile == null) {
        AppLogger.error('❌ User not found: $email');
        return false;
      }

      // Update user_profiles
      await _supabase
          .from('user_profiles')
          .update({
            'email_confirmed': true,
            'email_confirmed_at': DateTime.now().toIso8601String(),
            'status': 'active', // Ensure user is active
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userProfile.id);

      // Try to confirm in auth system
      await _confirmEmailInAuthSystem(userProfile.id, email);

      AppLogger.info('✅ Manually confirmed email for: $email');
      return true;
    } catch (e) {
      AppLogger.error('❌ Error manually confirming email: $e');
      return false;
    }
  }

  // Note: Supabase initialization is now handled in main.dart
  // This method is kept for backward compatibility but does nothing
  @Deprecated('Supabase initialization is now handled in main.dart')
  Future<void> initialize() async {
    AppLogger.info('Supabase is already initialized in main.dart');
  }

  Future<bool> createUserProfile({
    required String userId,
    required String email,
    required String name,
    required String phone,
    required String role,
  }) async {
    try {
      // استخدام user_profiles بدلاً من profiles للتوحيد
      await _supabase.from('user_profiles').insert({
        'id': userId,
        'email': email,
        'name': name,
        'phone_number': phone, // استخدام phone_number بدلاً من phone
        'role': role,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      AppLogger.error('Error creating user profile: $e');
      return false;
    }
  }

  /// إنشاء profile للمستخدمين الموجودين في auth.users بدون profile
  /// Uses the new safe RPC function to avoid RLS recursion issues
  Future<bool> createMissingUserProfile(String userId, String email, {
    String? name,
    String? phone,
    String role = 'client',
  }) async {
    try {
      AppLogger.info('Creating/updating user profile for: $email (ID: $userId)');

      // Use the new safe RPC function that avoids RLS recursion
      await _supabase.rpc('create_user_profile_safe', params: {
        'user_id': userId,
        'user_email': email,
        'user_name': name,
        'user_phone': phone,
        'user_role': role,
        'user_status': 'pending',
      });

      AppLogger.info('✅ User profile created/updated successfully for: $email');
      return true;
    } catch (e) {
      AppLogger.error('❌ Error creating user profile for $email: $e');

      // Handle specific error cases
      if (e.toString().contains('duplicate key') ||
          e.toString().contains('already exists') ||
          e.toString().contains('violates unique constraint')) {
        AppLogger.info('Profile already exists, considering this as success');
        return true;
      }

      // If RPC function fails, try fallback method with direct upsert
      try {
        AppLogger.info('Attempting fallback profile creation method...');

        await _supabase.from('user_profiles').upsert({
          'id': userId,
          'email': email,
          'name': name ?? email.split('@')[0],
          'phone_number': phone ?? '',
          'role': role,
          'status': 'pending',
          'email_confirmed': false,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        AppLogger.info('✅ Fallback profile creation successful for: $email');
        return true;
      } catch (fallbackError) {
        AppLogger.error('❌ Fallback profile creation also failed: $fallbackError');
        return false;
      }
    }
  }

  /// فحص وإصلاح المستخدمين المفقودين تلقائياً
  Future<void> fixMissingUserProfiles() async {
    try {
      AppLogger.info('Checking for users without profiles...');

      // البحث عن مستخدمين في auth.users بدون user_profiles
      final response = await _supabase.rpc('get_users_without_profiles');

      if (response != null && response is List && response.isNotEmpty) {
        AppLogger.info('Found ${response.length} users without profiles');

        for (final userData in response) {
          final userId = userData['id'] as String;
          final email = userData['email'] as String;
          final name = userData['name'] as String?;
          final phone = userData['phone'] as String?;

          await createMissingUserProfile(
            userId,
            email,
            name: name,
            phone: phone,
          );
        }

        AppLogger.info('Fixed all missing user profiles');
      } else {
        AppLogger.info('No users without profiles found');
      }
    } catch (e) {
      AppLogger.error('Error fixing missing user profiles: $e');
    }
  }

  Future<UserModel?> getUserProfile(String userId) async {
    try {
      // Use SECURITY DEFINER function to bypass RLS
      final response = await _supabase
          .rpc('get_user_by_id_safe', params: {'user_id': userId});

      if (response == null || response.isEmpty) {
        return null;
      }

      final userData = response is List ? response.first : response;
      return UserModel.fromMap(userData);
    } catch (e) {
      AppLogger.error('Error getting user profile: $e');

      // Fallback to direct query if function doesn't exist
      if (e.toString().contains('function') && e.toString().contains('does not exist')) {
        try {
          final fallbackResponse = await _supabase
              .from('user_profiles')
              .select()
              .eq('id', userId)
              .single();
          return UserModel.fromMap(fallbackResponse);
        } catch (fallbackError) {
          AppLogger.error('Fallback query failed: $fallbackError');
          return null;
        }
      }

      return null;
    }
  }

  Future<UserModel?> getUserByEmail(String email) async {
    try {
      // Use SECURITY DEFINER function to bypass RLS
      final response = await _supabase
          .rpc('get_user_by_email_safe', params: {'user_email': email});

      if (response == null || response.isEmpty) {
        return null;
      }

      final userData = response is List ? response.first : response;
      return UserModel.fromMap(userData);
    } catch (e) {
      AppLogger.error('Error getting user by email: $e');

      // Fallback to direct query if function doesn't exist
      if (e.toString().contains('function') && e.toString().contains('does not exist')) {
        try {
          final fallbackResponse = await _supabase
              .from('user_profiles')
              .select()
              .eq('email', email)
              .single();
          return UserModel.fromMap(fallbackResponse);
        } catch (fallbackError) {
          AppLogger.error('Fallback query failed: $fallbackError');
          return null;
        }
      }

      return null;
    }
  }

  Future<void> updateUser(UserModel user) async {
    try {
      await _supabase
          .from('user_profiles')
          .update(user.toMap())
          .eq('id', user.id);
    } catch (e) {
      AppLogger.error('Error updating user: $e');
      throw Exception('Failed to update user');
    }
  }

  Future<List<UserModel>> getPendingApprovalUsers() async {
    try {
      final response = await _supabase
          .from('user_profiles')
          .select()
          .eq('status', 'pending');

      return (response as List)
          .map((data) => UserModel.fromJson(data as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.error('Error getting pending users: $e');
      return [];
    }
  }

  Future<bool> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
      return true;
    } catch (e) {
      AppLogger.error('Error resetting password: $e');
      return false;
    }
  }

  Future<List<String>> fetchSignInMethodsForEmail(String email) async {
    try {
      final response = await _supabase
          .from('user_profiles')
          .select('provider_type')
          .eq('email', email);

      return (response as List).map((data) => data['provider_type'].toString()).toList();
    } catch (e) {
      AppLogger.error('Error fetching sign in methods: $e');
      return [];
    }
  }

  // Get user by ID
  Future<UserModel?> getUser(String userId) async {
    try {
      AppLogger.info('Fetching user data for ID: $userId');

      // Use SECURITY DEFINER function to bypass RLS
      final response = await _supabase
          .rpc('get_user_by_id_safe', params: {'user_id': userId});

      if (response == null || response.isEmpty) {
        AppLogger.warning('No user profile found for ID: $userId');
        return null;
      }

      final userData = response is List ? response.first : response;
      AppLogger.info('Successfully fetched user data for: ${userData['name']}');
      return UserModel.fromJson(userData);
    } catch (e) {
      AppLogger.error('Error fetching user data: $e');

      // Fallback to direct query if function doesn't exist
      if (e.toString().contains('function') && e.toString().contains('does not exist')) {
        try {
          final data = await _supabase
              .from('user_profiles')
              .select()
              .eq('id', userId)
              .maybeSingle();

          if (data == null) {
            AppLogger.warning('No user profile found for ID: $userId');
            return null;
          }

          AppLogger.info('Successfully fetched user data for: ${data['name']}');
          return UserModel.fromJson(data);
        } catch (fallbackError) {
          AppLogger.error('Fallback query failed: $fallbackError');
          return null;
        }
      }

      return null;
    }
  }

  Future<void> insertUserProfile(Map<String, dynamic> userData) async {
    try {
      await Supabase.instance.client
          .from('user_profiles')
          .insert(userData);
    } catch (e) {
      AppLogger.error('Error inserting user profile: $e');
      throw Exception('Failed to insert user profile');
    }
  }

  Future<bool> updateUserProfile(UserModel user) async {
    try {
      await _supabase
          .from('user_profiles')
          .update(user.toJson())
          .eq('id', user.id);
      return true;
    } catch (e) {
      AppLogger.error('Error updating user profile: $e');
      return false;
    }
  }

  Future<bool> updateUserStatus(String userId, String status) async {
    try {
      await _supabase
          .from('user_profiles')
          .update({'status': status})
          .eq('id', userId);
      return true;
    } catch (e) {
      AppLogger.error('Error updating user status: $e');
      return false;
    }
  }

  Future<bool> deleteUser(String userId) async {
    try {
      await _supabase
          .from('user_profiles')
          .delete()
          .eq('id', userId);
      return true;
    } catch (e) {
      AppLogger.error('Error deleting user: $e');
      return false;
    }
  }

  Future<UserModel?> getUserById(String userId) async {
    try {
      // Use SECURITY DEFINER function to bypass RLS
      final response = await _supabase
          .rpc('get_user_by_id_safe', params: {'user_id': userId});

      if (response == null || response.isEmpty) {
        return null;
      }

      final userData = response is List ? response.first : response;
      return UserModel.fromMap(userData);
    } catch (e) {
      AppLogger.error('Error getting user by ID: $e');

      // Fallback to direct query if function doesn't exist
      if (e.toString().contains('function') && e.toString().contains('does not exist')) {
        try {
          final fallbackResponse = await _supabase
              .from('user_profiles')
              .select()
              .eq('id', userId)
              .single();
          return UserModel.fromMap(fallbackResponse);
        } catch (fallbackError) {
          AppLogger.error('Fallback query failed: $fallbackError');
          return null;
        }
      }

      return null;
    }
  }

  Future<String> uploadProfileImage(String userId, Uint8List fileBytes) async {
    try {
      final path = 'users/$userId/profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _supabase.storage
          .from('profile-images')
          .uploadBinary(path, fileBytes);

      final url = _supabase.storage
          .from('profile-images')
          .getPublicUrl(path);

      await _supabase
          .from('user_profiles')
          .update({'profile_image': url})
          .eq('id', userId);

      return url;
    } catch (e) {
      AppLogger.error('Error uploading profile image: $e');
      throw Exception('Failed to upload profile image');
    }
  }
}