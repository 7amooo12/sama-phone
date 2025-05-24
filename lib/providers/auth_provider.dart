import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';
import '../services/database_service.dart';
import '../utils/app_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import 'package:flutter/material.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final DatabaseService _databaseService;
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;
  List<UserModel> _pendingUsers = [];
  List<UserModel> _allUsers = [];

  AuthProvider({
    required AuthService authService,
    required DatabaseService databaseService,
  })  : _authService = authService,
        _databaseService = databaseService;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoggedIn => _currentUser != null;
  List<UserModel> get pendingUsers => _pendingUsers;
  List<UserModel> get allUsers => _allUsers;
  
  String get userRole => _currentUser?.role.value ?? 'guest';

  factory AuthProvider.forTest() {
    return AuthProvider(
      authService: AuthService(),
      databaseService: DatabaseService(),
    );
  }

  Future<void> _initAuthState() async {
    _authService.onAuthStateChange.listen((AuthState data) async {
      final Session? session = data.session;
      if (session != null) {
        try {
          await getUserFromSupabase(session.user.id);
        } catch (e) {
          AppLogger.error('Error getting user data: $e');
          _currentUser = null;
        }
      } else {
        _currentUser = null;
      }
      notifyListeners();
    });
  }

  Future<void> checkAuthState() async {
    try {
      _isLoading = true;
      notifyListeners();

      final session = _authService.currentSession;
      if (session != null) {
        await getUserFromSupabase(session.user.id);
      } else {
        _currentUser = null;
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      AppLogger.error('Error checking auth state: $e');
      _isLoading = false;
      _error = _handleAuthError(e);
      _currentUser = null;
      notifyListeners();
    }
  }

  Future<void> getUserFromSupabase(String uid) async {
    try {
      final user = await _databaseService.getUser(uid);
      if (user != null) {
        _currentUser = user;
        notifyListeners();
      } else {
        _currentUser = null;
        notifyListeners();
      }
    } catch (e) {
      AppLogger.error('Error getting user from Supabase: $e');
      _currentUser = null;
      notifyListeners();
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final user = await _authService.signIn(
        email: email,
        password: password,
      );

      if (user != null) {
        _currentUser = user;
        _error = null;
      } else {
        _error = 'Invalid email or password';
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to sign in';
      _isLoading = false;
      AppLogger.error('Error signing in', e);
      notifyListeners();
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final user = await _authService.signUp(
        email: email,
        password: password,
        name: name,
        phone: phone,
      );

      if (user != null) {
        await _databaseService.createUserProfile(user);
        _currentUser = user;
        _error = null;
      } else {
        _error = 'Failed to create account';
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to sign up';
      _isLoading = false;
      AppLogger.error('Error signing up', e);
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      await _authService.signOut();
      _currentUser = null;
      notifyListeners();
    } catch (e) {
      AppLogger.error('Error signing out', e);
      rethrow;
    }
  }

  Future<void> loadCurrentUser() async {
    try {
      _isLoading = true;
      notifyListeners();

      final user = await _authService.getCurrentUser();
      _currentUser = user;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load user';
      _isLoading = false;
      AppLogger.error('Error loading current user', e);
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> fetchPendingApprovalUsers() async {
    try {
      _isLoading = true;
      notifyListeners();

      _pendingUsers = await _databaseService.getPendingUsers();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      AppLogger().e('Error fetching pending users: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> approveUserAndSetRole(String userId, String role) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _databaseService.updateUserRoleAndStatus(userId, role, 'active');

      await fetchPendingApprovalUsers();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      AppLogger().e('Error approving user: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> rejectUser(String userId) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _databaseService.updateUserRoleAndStatus(userId, 'rejected', 'rejected');

      await fetchPendingApprovalUsers();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      AppLogger().e('Error rejecting user: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> resetPassword(String email) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _authService.resetPasswordForEmail(email);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      AppLogger().e('Error resetting password: $e');
      _error = _handleAuthError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> updateUserProfile(UserModel user) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _databaseService.updateUser(user);
      _currentUser = user;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      AppLogger().e('Error updating user profile: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  String _handleAuthError(dynamic error) {
    if (error is AuthException) {
      switch (error.message) {
        case 'Invalid login credentials':
          return 'بيانات تسجيل الدخول غير صحيحة';
        case 'Email not confirmed':
          return 'يرجى تأكيد البريد الإلكتروني';
        case 'User not found':
          return 'لم يتم العثور على المستخدم';
        case 'Email already in use':
          return 'البريد الإلكتروني مستخدم بالفعل';
        default:
          return 'حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى';
      }
    }
    return 'حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى';
  }

  Future<bool> login(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _currentUser = await _authService.login(email, password);
      
      AppLogger.info('User logged in successfully: ${_currentUser?.email}');
      return true;
    } catch (e) {
      _error = e.toString();
      AppLogger.error('Login error: $_error');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register(String email, String password, String name) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _currentUser = await _authService.register(email, password, name);
      
      AppLogger.info('User registered successfully: ${_currentUser?.email}');
      return true;
    } catch (e) {
      _error = e.toString();
      AppLogger.error('Registration error: $_error');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      await _authService.logout();
      _currentUser = null;
      AppLogger.info('User logged out successfully');
    } catch (e) {
      _error = e.toString();
      AppLogger.error('Logout error: $_error');
    } finally {
      notifyListeners();
    }
  }
}
