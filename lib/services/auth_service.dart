import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';
import '../utils/app_logger.dart';

class AuthService {
  // Lazy initialization to avoid accessing Supabase.instance before initialization
  SupabaseClient get _supabase {
    try {
      return Supabase.instance.client;
    } catch (e) {
      AppLogger.error('❌ Supabase not initialized yet in AuthService: $e');
      throw Exception('Supabase must be initialized before using AuthService');
    }
  }

  Stream<AuthState> get onAuthStateChange => _supabase.auth.onAuthStateChange;
  Session? get currentSession => _supabase.auth.currentSession;
  User? get currentUser => _supabase.auth.currentUser;

  Future<UserModel?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        final userData = await _supabase
            .from('user_profiles')
            .select()
            .eq('id', response.user!.id)
            .single();

        return userData != null ? UserModel.fromJson(userData) : null;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error signing in', e);
      rethrow;
    }
  }

  Future<UserModel?> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    try {
      AppLogger.info('AuthService: Starting signup for: $email');

      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          'phone': phone,
        },
      );

      if (response.user != null) {
        final userId = response.user!.id;
        AppLogger.info('AuthService: Auth user created: $userId');

        // Wait for potential trigger to create profile
        await Future.delayed(const Duration(milliseconds: 1000));

        // Check if profile was created by trigger
        final existingProfile = await _supabase
            .from('user_profiles')
            .select()
            .eq('id', userId)
            .maybeSingle();

        if (existingProfile != null) {
          AppLogger.info('AuthService: Profile found (created by trigger)');
          return UserModel.fromJson(existingProfile);
        }

        // If no profile exists, create it manually
        AppLogger.warning('AuthService: No profile found, creating manually');
        final user = UserModel(
          id: userId,
          email: email,
          name: name,
          phone: phone,
          role: UserRole.client,
          status: 'pending',
          createdAt: DateTime.now(),
        );

        try {
          await _supabase
              .from('user_profiles')
              .insert(user.toJson());

          AppLogger.info('AuthService: Profile created manually');
          return user;
        } catch (insertError) {
          AppLogger.error('AuthService: Failed to create profile manually: $insertError');

          // Clean up auth user
          try {
            await _supabase.auth.admin.deleteUser(userId);
          } catch (deleteError) {
            AppLogger.error('AuthService: Failed to cleanup auth user: $deleteError');
          }

          throw Exception('فشل في إنشاء ملف المستخدم');
        }
      }

      AppLogger.error('AuthService: Auth user creation failed');
      return null;
    } catch (e) {
      AppLogger.error('AuthService: Error signing up: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      AppLogger.error('Error signing out', e);
      rethrow;
    }
  }

  Future<UserModel?> getCurrentUser() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final userData = await _supabase
            .from('user_profiles')
            .select()
            .eq('id', user.id)
            .single();

        return userData != null ? UserModel.fromJson(userData) : null;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error getting current user', e);
      return null;
    }
  }

  Future<void> resetPasswordForEmail(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      AppLogger.error('Error resetting password', e);
      rethrow;
    }
  }

  Future<void> updatePassword(String newPassword) async {
    try {
      await _supabase.auth.updateUser(
        UserAttributes(
          password: newPassword,
        ),
      );
    } catch (e) {
      AppLogger.error('Error updating password', e);
      rethrow;
    }
  }

  // Additional methods for compatibility
  Future<UserModel?> login(String email, String password) async {
    return await signIn(email: email, password: password);
  }

  Future<UserModel?> register(String email, String password, String name) async {
    return await signUp(
      email: email,
      password: password,
      name: name,
      phone: '', // Default empty phone
    );
  }

  Future<void> logout() async {
    return await signOut();
  }
}