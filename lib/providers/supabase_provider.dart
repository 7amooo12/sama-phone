import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';
import '../services/supabase_service.dart';
import '../utils/app_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseProvider extends ChangeNotifier {
  final _supabaseService = SupabaseService();
  final _supabase = Supabase.instance.client;
  UserModel? _user;
  bool _isLoading = false;
  String? _error;
  bool _offline = false;
  List<UserModel> _allUsers = []; // List of all users

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _supabase.auth.currentSession != null;
  bool get isOffline => _offline;
  List<UserModel> get allUsers => _allUsers; // Getter for all users
  List<UserModel> get users => _allUsers.where((user) => user.status == 'pending').toList(); // Getter for pending users

  SupabaseClient get client => _supabase;

  // Constructor - Fetch users on initialization
  SupabaseProvider() {
    // Fetch all users on initialization if user is admin
    checkAuthState().then((_) {
      if (_user?.role == UserRole.admin) {
        fetchAllUsers();
      }
    });
  }

  // Fetch all users
  Future<void> fetchAllUsers() async {
    try {
      _isLoading = true;
      notifyListeners();

      _allUsers = await _supabaseService.getAllUsers();
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      AppLogger.error('Error fetching all users: $e');
    }
  }
  
  // Fetch users by specific role
  Future<List<UserModel>> getUsersByRole(String role) async {
    try {
      final users = await _supabaseService.getUsersByRole(role);
      return users;
    } catch (e) {
      AppLogger.error('Error fetching users by role: $e');
      return [];
    }
  }

  // Check current auth state
  Future<void> checkAuthState() async {
    try {
      _isLoading = true;
      notifyListeners();

      final currentUserId = _supabaseService.currentUserId;
      
      if (currentUserId != null) {
        _user = await _supabaseService.getUserData(currentUserId);
      } else {
        _user = null;
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      _user = null;
      notifyListeners();
      AppLogger.error('Error checking auth state: $e');
    }
  }

  // Sign in
  Future<bool> signIn(String email, String password) async {
    try {
      _isLoading = true;
      notifyListeners();

      final response = await _supabaseService.signIn(email, password);
      if (response != null) {
        // Get user profile from Supabase
        final profile = await Supabase.instance.client
            .from('user_profiles')
            .select()
            .eq('id', response.id)
            .single();

        _user = UserModel.fromJson(profile);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Sign in with biometric authentication
  Future<bool> signInWithBiometric(String email) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      AppLogger.info('Attempting biometric login for: $email');
      
      // Get stored password from secure storage
      // For this implementation, we'll use a mock approach since actual biometric auth is already verified
      // In a real implementation, we would use secure storage to get the stored credentials
      final prefs = await SharedPreferences.getInstance();
      final hasSavedPassword = prefs.getBool('has_saved_password') ?? false;
      
      if (!hasSavedPassword) {
        _isLoading = false;
        _error = 'لا توجد بيانات مخزنة للمصادقة البيومترية';
        notifyListeners();
        return false;
      }
      
      // Since biometric has already been verified, we can fetch the user data directly
      // This is a simplified approach - in production, we would use stored refresh token
      // or other secure methods to re-authenticate
      
      // Call a special method in supabase service
      final result = await _supabaseService.signInWithSession(email);
      
      if (result != null) {
        _user = result;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _isLoading = false;
        _error = 'فشل تسجيل الدخول باستخدام البصمة. يرجى تسجيل الدخول باستخدام كلمة المرور';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _error = 'خطأ في تسجيل الدخول البيومتري: ${e.toString()}';
      notifyListeners();
      AppLogger.error('Biometric login error: $e');
      return false;
    }
  }

  // Sign up
  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
    String? avatarUrl,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      AppLogger.info('Starting signup process for: $email');

      final response = await _supabaseService.signUp(
        email: email,
        password: password,
        name: name,
        phone: phone,
        role: UserRole.user.value, // Default role for new users
      );

      if (response != null) {
        // User profile is already created in the service layer
        _user = UserModel(
          id: response.id,
          email: email,
          name: name,
          phone: phone,
          role: UserRole.user,
          status: 'pending',
          profileImage: avatarUrl,
          createdAt: DateTime.now(),
        );
        
        AppLogger.info('User signed up successfully: ${response.id}');
        notifyListeners();
        return true;
      }
      
      _error = 'فشل في إنشاء الحساب';
      return false;
    } catch (e) {
      AppLogger.error('Error during signup: $e');
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _supabase.auth.signOut();
    _user = null;
    notifyListeners();
  }

  // Set offline mode
  void setOfflineMode(bool value) {
    _offline = value;
    notifyListeners();
    AppLogger.info('Offline mode set to: $value');
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Refresh user data
  Future<void> refreshUserData() async {
    if (_user?.id != null) {
      try {
        final refreshedUser = await _supabaseService.getUserData(_user!.id);
        if (refreshedUser != null) {
          _user = refreshedUser;
          notifyListeners();
        }
      } catch (e) {
        AppLogger.error('Error refreshing user data: $e');
      }
    }
  }

  Future<List<UserModel>> getAllUsers() async {
    try {
      _isLoading = true;
      notifyListeners();

      final response = await _supabaseService.getAllUsers();
      return response;
    } catch (e) {
      AppLogger.error('Error getting all users: $e');
      _error = e.toString();
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateUserRole(String userId, UserRole newRole) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _supabaseService.updateUserRole(userId, newRole);
    } catch (e) {
      AppLogger.error('Error updating user role: $e');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> approveUser(String userId) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _supabaseService.approveUser(userId);
    } catch (e) {
      AppLogger.error('Error approving user: $e');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> approveUserAndSetRole({
    required String userId,
    required String roleStr,
    UserRole? role,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Convert string role to UserRole enum
      UserRole userRole;
      try {
        userRole = role ?? UserRoleExtension.fromString(roleStr);
      } catch (e) {
        AppLogger.warning('Invalid role: $roleStr, defaulting to client');
        userRole = UserRole.client;
      }

      // First update the role
      await updateUserRole(userId, userRole);
      
      // Then approve the user
      await approveUser(userId);
      
      // Refresh the users list
      await fetchAllUsers();
      
      AppLogger.info('User $userId approved with role: ${userRole.value}');
    } catch (e) {
      AppLogger.error('Error approving user and setting role: $e');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<UserModel?> createUserProfile(
    String userId,
    String name,
    String email,
    String role,
    String phone,
  ) async {
    try {
      final user = UserModel(
        id: userId,
        name: name,
        email: email,
        phone: phone,
        role: UserRole.fromString(role),
        status: 'pending',
        createdAt: DateTime.now(),
      );

      await _supabaseService.insertUserProfile(user.toJson());
      return user;
    } catch (e) {
      AppLogger.error('Error creating user profile: $e');
      return null;
    }
  }

  Future<void> refreshSession() async {
    try {
      final session = _supabase.auth.currentSession;
      if (session != null) {
        await _supabase.auth.refreshSession();
        await _loadUser();
      }
    } catch (e) {
      debugPrint('Error refreshing session: $e');
    }
  }

  Future<void> _loadUser() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        final response = await _supabase
            .from('users')
            .select()
            .eq('id', userId)
            .single();
        
        _user = UserModel.fromJson(response);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading user: $e');
    }
  }
} 