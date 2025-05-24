import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../utils/app_logger.dart';

class AuthService {
  final _supabase = Supabase.instance.client;

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
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user != null) {
        final user = UserModel(
          id: response.user!.id,
          email: email,
          name: name,
          phone: phone,
          role: 'client',
          status: 'pending',
          createdAt: DateTime.now(),
        );

        await _supabase
            .from('user_profiles')
            .insert(user.toJson());

        return user;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error signing up', e);
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
} 