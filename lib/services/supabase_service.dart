import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import '../models/user_model.dart';
import '../models/user_role.dart';
import '../utils/app_logger.dart';
import '../config/supabase_config.dart';

/// Service to handle Supabase operations: auth, storage, database
class SupabaseService {
  final _supabase = Supabase.instance.client;
  
  // Singleton pattern
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  // Get current session
  Session? get currentSession => _supabase.auth.currentSession;
  
  // Get current user
  User? get currentUser => _supabase.auth.currentUser;
  
  // Get user ID
  String? get currentUserId => _supabase.auth.currentUser?.id;

  // Auth Methods
  
  /// Sign up with email and password
  Future<User?> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
    String? role, // Optional role, defaults to 'user'
  }) async {
    try {
      AppLogger.info('Starting signup for: $email');
      
      // Create auth user
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );
      
      if (response.user != null) {
        // Create user profile
        await _supabase.from('user_profiles').insert({
          'id': response.user!.id,
          'email': email,
          'name': name,
          'phone': phone,
          'role': role ?? 'user',
          'status': 'pending',
          'created_at': DateTime.now().toIso8601String(),
        });
        
        AppLogger.info('User profile created for: ${response.user!.id}');
        return response.user;
      }
      
      return null;
    } catch (e) {
      AppLogger.error('Error during signup: $e');
      throw Exception('فشل في إنشاء الحساب: $e');
    }
  }

  /// Sign in with email and password
  Future<User?> signIn(String email, String password) async {
    try {
      // First check if user exists in the database
      try {
        final userProfile = await _supabase
            .from('user_profiles')
            .select()
            .eq('email', email)
            .maybeSingle();
        
        if (userProfile == null) {
          AppLogger.warning('No user profile found for email: $email');
          throw Exception('بريد إلكتروني أو كلمة مرور غير صحيحة');
        }
        
        final status = userProfile['status'] as String;
  
        if (status != 'active' && status != 'approved') {
          AppLogger.warning('User account not approved: $email');
          throw Exception('لم يتم الموافقة على حسابك بعد');
        }
      } catch (e) {
        if (e is PostgrestException) {
          AppLogger.error('PostgrestException when checking user: ${e.message}');
          // Continue with signin attempt even if profile check fails
        } else {
          rethrow;
        }
      }

      // Attempt to sign in
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      AppLogger.info('Login successful for: $email');
      return response.user;
    } catch (e) {
      AppLogger.error('Error during sign in: $e');
      if (e is AuthException) {
        if (e.message.contains('Invalid login credentials')) {
          throw Exception('بريد إلكتروني أو كلمة مرور غير صحيحة');
        }
      }
      throw Exception(e.toString());
    }
  }

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

  /// Get user data based on email
  Future<UserModel?> getUserData(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
      
      return UserModel.fromMap(response);
    } catch (e) {
      AppLogger.error('Error getting user data: $e');
      return null;
    }
  }
  
  /// Get all users with a specific role
  Future<List<UserModel>> getUsersByRole(String role) async {
    try {
      AppLogger.info('Fetching users with role: $role');
      
      final response = await _supabase
          .from('user_profiles')
          .select()
          .eq('role', role)
          .eq('status', 'active')
          .order('name');
      
      final users = response.map<UserModel>((json) => UserModel.fromJson(json)).toList();
      
      AppLogger.info('Found ${users.length} users with role: $role');
      return users;
    } catch (e) {
      AppLogger.error('Error fetching users by role: $e');
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
          .uploadBinary(path, fileBytes);
      
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

  /// Sign in with previous session (for biometric auth)
  Future<UserModel?> signInWithSession(String email) async {
    try {
      AppLogger.info('Signing in with session for email: $email');
      
      // Check if we have an active session
      if (_supabase.auth.currentSession != null) {
        final userId = _supabase.auth.currentUser?.id;
        
        if (userId != null) {
          // We already have a valid session, just get the user data
          return await getUserData(userId);
        }
      }
      
      // If no active session, we need to fetch the user by email
      final userData = await _supabase.from('user_profiles')
          .select()
          .eq('email', email)
          .maybeSingle();
      
      if (userData == null) {
        AppLogger.warning('No user profile found for email: $email');
        return null;
      }
      
      // For testing purposes, simulate a successful login
      // In a real app with proper biometric auth, you would use a refresh token or passwordless auth
      AppLogger.info('User signed in via biometric: ${userData['name']}');
      return UserModel.fromJson(userData);
    } catch (e) {
      AppLogger.error('Error during session sign in: $e');
      return null;
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

  /// Update user role and status
  Future<void> updateUserRoleAndStatus(
    String userId,
    String role,
    String status,
  ) async {
    try {
      await _supabase.from('profiles').update({
        'role': role,
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);
    } catch (e) {
      AppLogger.error('Error updating user role and status: $e');
      throw Exception('فشل في تحديث بيانات المستخدم');
    }
  }

  /// Get pending users
  Future<List<UserModel>> getPendingUsers() async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('status', 'pending')
          .order('created_at');
      
      return (response as List)
          .map((data) => UserModel.fromMap(data))
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
      await _supabase
          .from('user_profiles')
          .update({
            'status': 'approved',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);
    } catch (e) {
      AppLogger.error('Error approving user: $e');
      rethrow;
    }
  }

  // Initialize Supabase
  Future<void> initialize() async {
    try {
      await Supabase.initialize(
        url: const String.fromEnvironment('SUPABASE_URL'),
        anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
      );
      AppLogger.info('Supabase initialized successfully');
    } catch (e) {
      AppLogger.error('Error initializing Supabase: $e');
      rethrow;
    }
  }

  Future<bool> createUserProfile({
    required String userId,
    required String email,
    required String name,
    required String phone,
    required String role,
  }) async {
    try {
      await _supabase.from('profiles').insert({
        'id': userId,
        'email': email,
        'name': name,
        'phone': phone,
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

  Future<UserModel?> getUserProfile(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
      return UserModel.fromMap(response);
    } catch (e) {
      AppLogger.error('Error getting user profile: $e');
      return null;
    }
  }

  Future<UserModel?> getUserByEmail(String email) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('email', email)
          .single();
      return UserModel.fromMap(response);
    } catch (e) {
      AppLogger.error('Error getting user by email: $e');
      return null;
    }
  }

  Future<void> updateUser(UserModel user) async {
    try {
      await _supabase
          .from('profiles')
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
          .from('profiles')
          .select()
          .eq('status', 'pending');
      
      return (response as List)
          .map((data) => UserModel.fromJson(data))
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
          .from('profiles')
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
    } catch (e) {
      AppLogger.error('Error fetching user data: $e');
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
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
      
      return UserModel.fromMap(response);
    } catch (e) {
      AppLogger.error('Error getting user by ID: $e');
      return null;
    }
  }

  Future<String> uploadProfileImage(String userId, Uint8List fileBytes) async {
    try {
      final path = 'profiles/$userId/avatar.jpg';
      await _supabase.storage
          .from('avatars')
          .uploadBinary(path, fileBytes);
      
      final url = _supabase.storage
          .from('avatars')
          .getPublicUrl(path);
          
      await _supabase
          .from('profiles')
          .update({'profile_image': url})
          .eq('id', userId);
          
      return url;
    } catch (e) {
      AppLogger.error('Error uploading profile image: $e');
      throw Exception('Failed to upload profile image');
    }
  }
} 