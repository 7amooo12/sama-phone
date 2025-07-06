import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';
import '../services/supabase_service.dart';
import '../services/wallet_service.dart';
import '../services/voucher_service.dart';
import '../services/invoice_creation_service.dart';
import '../services/auth_state_manager.dart';
import '../services/auth_sync_service.dart';
import '../utils/app_logger.dart';
import '../models/voucher_model.dart';
import '../models/client_voucher_model.dart';
import '../models/invoice_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseProvider extends ChangeNotifier {
  StreamSubscription<AuthState>? _authSubscription;
  bool _disposed = false; // Track disposal state to prevent memory leaks

  // Constructor - Fetch users on initialization
  SupabaseProvider() {
    _initializeAuthListener();
    // Fetch all users on initialization if user is admin
    checkAuthState().then((_) {
      if (_user?.role == UserRole.admin) {
        fetchAllUsers();
      }
    });
  }

  void _initializeAuthListener() {
    // Cancel existing subscription first to prevent memory leaks
    _authSubscription?.cancel();

    _authSubscription = _supabase.auth.onAuthStateChange.listen(
      (data) {
        if (_disposed) {
          AppLogger.warning('⚠️ Auth event received on disposed provider, ignoring');
          return; // Prevent operations on disposed provider
        }

        final event = data.event;
        final session = data.session;

        AppLogger.info('🔄 Auth state changed: $event');

      switch (event) {
        case AuthChangeEvent.signedIn:
          AppLogger.info('✅ User signed in');
          _handleSignedIn(session);
          break;
        case AuthChangeEvent.signedOut:
          AppLogger.info('🚪 User signed out');
          _handleSignedOut();
          break;
        case AuthChangeEvent.tokenRefreshed:
          AppLogger.info('🔄 Token refreshed');
          _handleTokenRefreshed(session);
          break;
        case AuthChangeEvent.userUpdated:
          AppLogger.info('👤 User updated');
          _handleUserUpdated(session);
          break;
        case AuthChangeEvent.passwordRecovery:
          AppLogger.info('🔑 Password recovery');
          break;
        default:
          AppLogger.info('🔄 Auth event: $event');
      }
    });
  }

  void _handleSignedIn(Session? session) async {
    if (session?.user != null) {
      try {
        _user = await _supabaseService.getUserData(session!.user.id);
        notifyListeners();
      } catch (e) {
        AppLogger.error('Error loading user data after sign in: $e');
      }
    }
  }

  void _handleSignedOut() {
    _user = null;
    _allUsers.clear();
    clearRoleCache();
    notifyListeners();
  }

  void _handleTokenRefreshed(Session? session) async {
    if (session?.user != null && _user != null) {
      // Optionally refresh user data
      try {
        final refreshedUser = await _supabaseService.getUserData(session!.user.id);
        if (refreshedUser != null) {
          _user = refreshedUser;
          notifyListeners();
        }
      } catch (e) {
        AppLogger.error('Error refreshing user data after token refresh: $e');
      }
    }
  }

  void _handleUserUpdated(Session? session) async {
    if (session?.user != null && _user != null) {
      await refreshUserData();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _authSubscription?.cancel();
    _authSubscription = null;
    AppLogger.info('🗑️ SupabaseProvider disposed, auth listener cancelled');
    super.dispose();
  }
  // Lazy initialization to avoid accessing Supabase.instance before initialization
  SupabaseService? _supabaseServiceInstance;
  SupabaseService get _supabaseService {
    _supabaseServiceInstance ??= SupabaseService();
    return _supabaseServiceInstance!;
  }

  WalletService? _walletServiceInstance;
  WalletService get _walletService {
    _walletServiceInstance ??= WalletService();
    return _walletServiceInstance!;
  }

  VoucherService? _voucherServiceInstance;
  VoucherService get _voucherService {
    _voucherServiceInstance ??= VoucherService();
    return _voucherServiceInstance!;
  }

  InvoiceCreationService? _invoiceServiceInstance;
  InvoiceCreationService get _invoiceService {
    _invoiceServiceInstance ??= InvoiceCreationService();
    return _invoiceServiceInstance!;
  }

  SupabaseClient get _supabase {
    try {
      return Supabase.instance.client;
    } catch (e) {
      AppLogger.error('❌ Supabase not initialized yet in SupabaseProvider: $e');
      throw Exception('Supabase must be initialized before using SupabaseProvider');
    }
  }
  UserModel? _user;
  bool _isLoading = false;
  String? _error;
  bool _offline = false;
  List<UserModel> _allUsers = []; // List of all users
  List<Invoice> _invoices = []; // List of invoices

  // Enhanced cache and loop prevention system
  final Map<String, List<UserModel>> _roleCache = {};
  final Map<String, DateTime> _lastFetchTime = {};
  final Map<String, Future<List<UserModel>>> _ongoingRequests = {};
  final Set<String> _activeFetches = {}; // Track active fetches to prevent loops
  static const Duration _cacheTimeout = Duration(minutes: 5);
  static const Duration _debounceTimeout = Duration(seconds: 2);
  static const Duration _loopPreventionTimeout = Duration(milliseconds: 500);

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _supabase.auth.currentSession != null;
  bool get isOffline => _offline;
  List<UserModel> get allUsers => _allUsers; // Getter for all users
  List<UserModel> get users => _allUsers.where((user) => user.status == 'pending').toList(); // Getter for pending users
  List<UserModel> get workers => _allUsers.where((user) =>
    user.role == UserRole.worker &&
    (user.status == 'approved' || user.status == 'active') &&
    user.isApproved
  ).toList(); // Getter for approved/active workers
  List<Invoice> get invoices => _invoices; // Getter for invoices

  SupabaseClient get client => _supabase;
  SupabaseClient get supabase => _supabase;

  // Fetch all users
  Future<void> fetchAllUsers() async {
    try {
      _isLoading = true;
      notifyListeners();

      AppLogger.info('Fetching all users from database...');
      _allUsers = await _supabaseService.getAllUsers();
      AppLogger.info('Successfully fetched ${_allUsers.length} users');

      // Debug: Log user roles and statuses
      final roleCount = <String, int>{};
      final statusCount = <String, int>{};
      for (final user in _allUsers) {
        final role = user.role.value;
        final status = user.status;
        roleCount[role] = (roleCount[role] ?? 0) + 1;
        statusCount[status] = (statusCount[status] ?? 0) + 1;
      }
      AppLogger.info('User roles: ${roleCount.entries.map((e) => '${e.key}: ${e.value}').join(', ')}');
      AppLogger.info('User statuses: ${statusCount.entries.map((e) => '${e.key}: ${e.value}').join(', ')}');

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      AppLogger.error('Error fetching all users: $e');
    }
  }

  // Enhanced fetch users by role with comprehensive loop prevention
  Future<List<UserModel>> getUsersByRole(String role) async {
    final startTime = DateTime.now();

    try {
      // STEP 1: Infinite loop prevention check
      if (_activeFetches.contains(role)) {
        AppLogger.warning('🚫 Provider: Preventing infinite loop for role: $role - fetch already active');
        return _roleCache[role] ?? [];
      }

      // STEP 2: Check cache validity
      final lastFetch = _lastFetchTime[role];
      final cachedUsers = _roleCache[role];

      if (lastFetch != null && cachedUsers != null) {
        final timeSinceLastFetch = DateTime.now().difference(lastFetch);
        if (timeSinceLastFetch < _cacheTimeout) {
          AppLogger.info('📋 Provider: Using cached users for role: $role (${cachedUsers.length} users, cached ${timeSinceLastFetch.inSeconds}s ago)');
          return cachedUsers;
        } else {
          AppLogger.info('⏰ Provider: Cache expired for role: $role (${timeSinceLastFetch.inMinutes} minutes old)');
        }
      }

      // STEP 3: Check for ongoing requests
      if (_ongoingRequests.containsKey(role)) {
        AppLogger.info('⏳ Provider: Request already in progress for role: $role, waiting...');
        return await _ongoingRequests[role]!;
      }

      // STEP 4: Start new request with loop prevention
      AppLogger.info('🔍 Provider: Starting fresh fetch for users with role: $role');
      _activeFetches.add(role); // Mark as active to prevent loops

      final requestFuture = _fetchUsersFromService(role);
      _ongoingRequests[role] = requestFuture;

      try {
        final users = await requestFuture;
        final fetchDuration = DateTime.now().difference(startTime);

        // Cache the results
        _roleCache[role] = users;
        _lastFetchTime[role] = DateTime.now();

        // Update _allUsers only if we got new data
        _updateAllUsersCache(users);

        AppLogger.info('✅ Provider: Successfully fetched and cached ${users.length} users for role: $role (took ${fetchDuration.inMilliseconds}ms)');
        return users;
      } finally {
        // Always clean up tracking
        _ongoingRequests.remove(role);
        _activeFetches.remove(role);
      }
    } catch (e) {
      final fetchDuration = DateTime.now().difference(startTime);
      AppLogger.error('❌ Provider: Error fetching users by role "$role" (took ${fetchDuration.inMilliseconds}ms): $e');

      // Clean up on error
      _ongoingRequests.remove(role);
      _activeFetches.remove(role);

      // Return cached data if available
      return _roleCache[role] ?? [];
    }
  }

  // Helper method to fetch users from service
  Future<List<UserModel>> _fetchUsersFromService(String role) async {
    // Ensure all users are loaded first to populate _allUsers
    if (_allUsers.isEmpty) {
      AppLogger.info('📥 Provider: _allUsers is empty, fetching all users first...');
      await fetchAllUsers();
    }

    // Get users from service
    final users = await _supabaseService.getUsersByRole(role);
    return users;
  }

  // Helper method to update _allUsers cache without excessive logging
  void _updateAllUsersCache(List<UserModel> users) {
    bool hasChanges = false;

    for (final user in users) {
      final existingIndex = _allUsers.indexWhere((u) => u.id == user.id);
      if (existingIndex == -1) {
        _allUsers.add(user);
        hasChanges = true;
      } else if (_allUsers[existingIndex] != user) {
        _allUsers[existingIndex] = user;
        hasChanges = true;
      }
    }

    // Only notify listeners and log if there were actual changes
    if (hasChanges) {
      notifyListeners();
      AppLogger.info('🔄 Provider: Updated _allUsers cache (${_allUsers.length} total users)');
    }
  }

  // Get approved clients specifically for voucher assignment
  Future<List<UserModel>> getApprovedClients() async {
    try {
      AppLogger.info('Getting approved clients for voucher assignment...');

      // Ensure users are loaded
      if (_allUsers.isEmpty) {
        await fetchAllUsers();
      }

      final clients = _allUsers.where((user) {
        final isClient = user.role.value.toLowerCase() == 'client';
        final isApproved = user.status.toLowerCase() == 'approved' ||
                          user.status.toLowerCase() == 'active' ||
                          user.isApproved;
        return isClient && isApproved;
      }).toList();

      AppLogger.info('Found ${clients.length} approved clients');
      return clients;
    } catch (e) {
      AppLogger.error('Error getting approved clients: $e');
      return [];
    }
  }

  // Check current auth state with enhanced session management
  Future<void> checkAuthState() async {
    try {
      _isLoading = true;
      notifyListeners();

      AppLogger.info('🔍 SupabaseProvider: Checking auth state...');

      // First validate/recover session
      final sessionValid = await AuthStateManager.validateSession();
      if (!sessionValid) {
        AppLogger.info('🔄 Session invalid, attempting initialization...');
        await AuthStateManager.initializeSession();
      }

      final currentUserId = _supabaseService.currentUserId;

      if (currentUserId != null) {
        AppLogger.info('👤 Found user ID: $currentUserId');
        _user = await _supabaseService.getUserData(currentUserId);
        if (_user != null) {
          AppLogger.info('✅ User data loaded: ${_user!.email} (${_user!.role.value})');
        } else {
          AppLogger.warning('⚠️ User ID found but no user data');
        }
      } else {
        AppLogger.info('ℹ️ No current user ID found');
        _user = null;
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      _user = null;
      notifyListeners();
      AppLogger.error('❌ Error checking auth state: $e');
    }
  }

  // Sign in
  Future<bool> signIn(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      AppLogger.info('🔄 SupabaseProvider: Starting sign-in for: $email');

      final response = await _supabaseService.signIn(email, password);
      if (response != null) {
        AppLogger.info('✅ SupabaseProvider: Authentication successful, fetching user profile...');

        try {
          // Get user profile using SECURITY DEFINER function to avoid infinite recursion
          final userProfile = await _supabaseService.getUserData(response.id);

          if (userProfile == null) {
            throw Exception('User profile not found after authentication');
          }

          _user = userProfile;
          AppLogger.info('✅ SupabaseProvider: User profile loaded successfully');

          // 🔒 SECURITY: Log user authentication
          AppLogger.info('🔒 USER AUTH: ${_user!.email} -> Role: "${_user!.role}" -> ${_user!.role}');

          // إذا كان المستخدم أدمن، تأكد من أنه موافق عليه
          if (_user!.isAdmin() && !_user!.isApproved) {
            AppLogger.info('🔧 SupabaseProvider: Updating admin approval status...');
            // تحديث حالة الموافقة للأدمن في قاعدة البيانات
            try {
              await Supabase.instance.client
                  .from('user_profiles')
                  .update({
                    'status': 'active',
                    'email_confirmed': true,
                    'updated_at': DateTime.now().toIso8601String(),
                  })
                  .eq('id', _user!.id);

              // إعادة تحميل بيانات المستخدم باستخدام SECURITY DEFINER function
              final updatedProfile = await _supabaseService.getUserData(response.id);
              if (updatedProfile != null) {
                _user = updatedProfile;
                AppLogger.info('✅ SupabaseProvider: Admin status updated successfully');
              }
            } catch (e) {
              AppLogger.error('❌ SupabaseProvider: Error updating admin status: $e');
            }
          }

          AppLogger.info('🎉 SupabaseProvider: Sign-in completed successfully for: $email');

          // CRITICAL FIX: Wait for session to fully propagate before synchronization
          AppLogger.info('⏳ SupabaseProvider: Waiting for session propagation...');
          await Future.delayed(const Duration(milliseconds: 500));

          // CRITICAL FIX: Trigger authentication state synchronization
          try {
            AppLogger.info('🔄 SupabaseProvider: Triggering auth state synchronization...');
            final syncResult = await AuthSyncService.syncAuthState();
            if (syncResult) {
              AppLogger.info('✅ SupabaseProvider: Auth state synchronization completed successfully');
            } else {
              AppLogger.warning('⚠️ SupabaseProvider: Auth sync returned false but login was successful');
            }
          } catch (syncError) {
            AppLogger.warning('⚠️ SupabaseProvider: Auth sync failed but login successful: $syncError');
          }

          notifyListeners();
          return true;
        } catch (profileError) {
          AppLogger.error('❌ SupabaseProvider: Failed to fetch user profile: $profileError');
          _error = 'فشل في تحميل بيانات المستخدم. يرجى المحاولة مرة أخرى.';
          notifyListeners();
          return false;
        }
      } else {
        AppLogger.error('❌ SupabaseProvider: Authentication failed - no response from service');
        _error = 'فشل في المصادقة. يرجى التحقق من بيانات الدخول.';
        notifyListeners();
        return false;
      }
    } catch (e) {
      AppLogger.error('❌ SupabaseProvider: Sign-in error: $e');
      _error = 'حدث خطأ أثناء تسجيل الدخول: ${e.toString()}';
      notifyListeners();
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

      // SECURITY FIX: Secure biometric authentication
      // Only allow biometric login if user has a valid existing session
      try {
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
      } catch (securityError) {
        _isLoading = false;
        _error = securityError.toString();
        notifyListeners();
        AppLogger.error('Secure biometric authentication failed: $securityError');
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
        role: UserRole.client.value, // Default role for new users
      );

      if (response != null) {
        // Verify user profile was created and get the data
        final userProfile = await _supabaseService.getUserData(response.id);
        if (userProfile != null) {
          _user = userProfile;
          AppLogger.info('User signed up successfully: ${response.id} - Profile created');
        } else {
          // Fallback: create user model manually
          _user = UserModel(
            id: response.id,
            email: email,
            name: name,
            phone: phone,
            role: UserRole.client,
            status: 'pending',
            profileImage: avatarUrl,
            createdAt: DateTime.now(),
          );
          AppLogger.warning('User profile not found, using fallback model');
        }

        // Create wallet for the new user
        try {
          AppLogger.info('Creating wallet for new user: ${response.id}');
          await _walletService.createWallet(
            userId: response.id,
            role: UserRole.client.value,
            initialBalance: 0.0,
          );
          AppLogger.info('Wallet created successfully for user: ${response.id}');
        } catch (walletError) {
          AppLogger.error('Failed to create wallet for user ${response.id}: $walletError');
          // Don't fail the registration if wallet creation fails
          // The wallet can be created later when the user is approved
        }

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

  // Enhanced cache clearing with loop prevention cleanup
  void clearRoleCache([String? role]) {
    if (role != null) {
      _roleCache.remove(role);
      _lastFetchTime.remove(role);
      _ongoingRequests.remove(role);
      _activeFetches.remove(role); // Clear active fetch tracking
      AppLogger.info('🗑️ Provider: Cleared cache for role: $role');
    } else {
      _roleCache.clear();
      _lastFetchTime.clear();
      _ongoingRequests.clear();
      _activeFetches.clear(); // Clear all active fetch tracking
      AppLogger.info('🗑️ Provider: Cleared all role caches');
    }
  }

  // Force refresh users by role (bypasses cache)
  Future<List<UserModel>> forceRefreshUsersByRole(String role) async {
    clearRoleCache(role);
    return await getUsersByRole(role);
  }

  // Refresh user data
  Future<void> refreshUserData() async {
    if (_user?.id != null) {
      try {
        AppLogger.info('🔄 SupabaseProvider: Refreshing user data for: ${_user!.email}');

        final refreshedUser = await _supabaseService.getUserData(_user!.id);
        if (refreshedUser != null) {
          final oldName = _user!.name;
          final oldPhone = _user!.phoneNumber;
          _user = refreshedUser;

          AppLogger.info('✅ SupabaseProvider: User data refreshed successfully - Name: ${_user!.name} (was: $oldName)');
          AppLogger.info('📱 SupabaseProvider: Phone number refreshed - phoneNumber: "${_user!.phoneNumber}" (was: "$oldPhone"), phone: "${_user!.phone}"');
          notifyListeners();
        } else {
          AppLogger.warning('⚠️ SupabaseProvider: No user data returned during refresh');
        }
      } catch (e) {
        AppLogger.error('❌ SupabaseProvider: Error refreshing user data: $e');
      }
    } else {
      AppLogger.warning('⚠️ SupabaseProvider: Cannot refresh - no user ID available');
    }
  }

  // Force refresh user data from database (clears cache)
  Future<void> forceRefreshUserData() async {
    if (_user?.id != null) {
      try {
        _isLoading = true;
        notifyListeners();

        // Get fresh data using SECURITY DEFINER function to avoid infinite recursion
        final freshUser = await _supabaseService.getUserData(_user!.id);

        if (freshUser != null) {
          _user = freshUser;
          AppLogger.info('✅ SupabaseProvider: Force refreshed user data - Name: ${_user!.name}, Email: ${_user!.email}, Status: ${_user!.status}');
        } else {
          AppLogger.warning('⚠️ SupabaseProvider: Failed to refresh user data - user not found');
        }
        notifyListeners();
      } catch (e) {
        AppLogger.error('❌ SupabaseProvider: Error force refreshing user data: $e');
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  // Update password
  Future<bool> updatePassword(String newPassword) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      AppLogger.info('Password updated successfully for user: ${_user?.email}');
      return true;
    } catch (e) {
      AppLogger.error('Error updating password: $e');
      _error = 'فشل في تغيير كلمة المرور: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get user data by email
  Future<UserModel?> getUserDataByEmail(String email) async {
    try {
      return await _supabaseService.getUserByEmail(email);
    } catch (e) {
      AppLogger.error('Error getting user data by email: $e');
      return null;
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

  Future<bool> approveUser(String userId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _supabaseService.approveUser(userId);

      // Create wallet for approved user if it doesn't exist
      try {
        AppLogger.info('Checking/creating wallet for approved user: $userId');

        // Get user data to determine role
        final userData = await _supabaseService.getUserData(userId);
        if (userData != null) {
          // Check if wallet already exists
          final existingWallet = await _walletService.getUserWallet(userId);
          if (existingWallet == null) {
            // Create wallet with appropriate initial balance based on role
            double initialBalance = 0.0;
            switch (userData.role) {
              case UserRole.admin:
                initialBalance = 10000.0;
                break;
              case UserRole.owner:
                initialBalance = 5000.0;
                break;
              case UserRole.accountant:
                initialBalance = 1000.0;
                break;
              case UserRole.worker:
                initialBalance = 500.0;
                break;
              case UserRole.client:
                initialBalance = 100.0;
                break;
              case UserRole.employee:
                initialBalance = 500.0;
                break;
              case UserRole.manager:
                initialBalance = 2000.0;
                break;
              case UserRole.user:
                initialBalance = 100.0;
                break;
              case UserRole.guest:
                initialBalance = 0.0;
                break;
              case UserRole.pending:
                initialBalance = 0.0;
                break;
              case UserRole.warehouseManager:
                initialBalance = 1500.0;
                break;
            }

            await _walletService.createWallet(
              userId: userId,
              role: userData.role.value,
              initialBalance: initialBalance,
            );
            AppLogger.info('Wallet created for approved user: $userId with balance: $initialBalance');
          } else {
            AppLogger.info('Wallet already exists for user: $userId');
          }
        }
      } catch (walletError) {
        AppLogger.error('Failed to create wallet for approved user $userId: $walletError');
        // Don't fail the approval if wallet creation fails
      }

      return true;
    } catch (e) {
      AppLogger.error('Error approving user: $e');
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createUser({
    required String email,
    required String name,
    String? phone,
    required UserRole role,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final result = await _supabaseService.signUp(
        email: email,
        password: 'temp123', // Temporary password - user should change it
        name: name,
        phone: phone ?? '',
        role: role.value,
      );

      if (result != null) {
        await fetchAllUsers(); // Refresh the list
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.error('Error creating user: $e');
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateUser({
    required String userId,
    required String name,
    required String email,
    String? phone,
    required UserRole role,
    required bool isApproved,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _supabaseService.updateRecord('user_profiles', userId, {
        'name': name,
        'email': email,
        'phone_number': phone, // Fixed: Use phone_number to match database schema
        'role': role.value,
        'status': isApproved ? 'approved' : 'pending', // Fixed: Use status instead of is_approved
        'updated_at': DateTime.now().toIso8601String(),
      });

      await fetchAllUsers(); // Refresh the list
      return true;
    } catch (e) {
      AppLogger.error('Error updating user: $e');
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteUser(String userId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _supabaseService.deleteUser(userId);
      await fetchAllUsers(); // Refresh the list
      return true;
    } catch (e) {
      AppLogger.error('Error deleting user: $e');
      _error = e.toString();
      return false;
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

      // Send approval notification
      await _sendAccountApprovalNotification(userId);

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
        // Use SECURITY DEFINER function to avoid infinite recursion
        final userProfile = await _supabaseService.getUserData(userId);

        if (userProfile != null) {
          _user = userProfile;
          notifyListeners();
        } else {
          AppLogger.warning('User profile not found for ID: $userId');
        }
      }
    } catch (e) {
      AppLogger.error('Error loading user: $e');
    }
  }

  // Send account approval notification
  Future<void> _sendAccountApprovalNotification(String userId) async {
    try {
      await _supabase.from('notifications').insert({
        'user_id': userId,
        'title': 'تم قبول حسابك',
        'body': 'تم قبول حسابك بنجاح. يمكنك الآن استخدام التطبيق.',
        'type': 'SYSTEM',
        'read': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      AppLogger.info('✅ Account approval notification sent to user: $userId');
    } catch (e) {
      AppLogger.error('❌ Error sending account approval notification: $e');
    }
  }

  /// إنشاء profile للمستخدم الموجود في Supabase Dashboard
  Future<bool> createProfileForExistingUser(String userId, String email, {
    String? name,
    String? phone,
    String role = 'client',
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final success = await _supabaseService.createMissingUserProfile(
        userId,
        email,
        name: name,
        phone: phone,
        role: role,
      );

      if (success) {
        await fetchAllUsers(); // تحديث قائمة المستخدمين
        AppLogger.info('Profile created for existing user: $userId');
      }

      return success;
    } catch (e) {
      AppLogger.error('Error creating profile for existing user: $e');
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ============================================================================
  // INVOICE MANAGEMENT METHODS
  // ============================================================================

  /// Load all invoices from Supabase
  Future<void> loadInvoices() async {
    try {
      _isLoading = true;
      notifyListeners();

      AppLogger.info('Loading invoices from Supabase...');
      _invoices = await _invoiceService.getStoredInvoices();
      AppLogger.info('Successfully loaded ${_invoices.length} invoices');

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = 'Error loading invoices: $e';
      notifyListeners();
      AppLogger.error('Error loading invoices: $e');
    }
  }

  /// Get pending invoices
  Future<List<Invoice>> getPendingInvoices() async {
    try {
      AppLogger.info('Getting pending invoices...');
      return await _invoiceService.getPendingInvoices();
    } catch (e) {
      AppLogger.error('Error getting pending invoices: $e');
      return [];
    }
  }

  /// Get invoice by ID
  Future<Invoice?> getInvoice(String invoiceId) async {
    try {
      AppLogger.info('Getting invoice: $invoiceId');
      return await _invoiceService.getInvoice(invoiceId);
    } catch (e) {
      AppLogger.error('Error getting invoice: $e');
      return null;
    }
  }

  /// Refresh invoices data
  Future<void> refreshInvoices() async {
    await loadInvoices();
  }

  // ============================================================================
  // VOUCHER MANAGEMENT METHODS
  // ============================================================================

  /// Get client vouchers for a specific client
  Future<List<ClientVoucherModel>> getClientVouchers(String clientId) async {
    try {
      AppLogger.info('Getting vouchers for client: $clientId');
      return await _voucherService.getClientVouchers(clientId);
    } catch (e) {
      AppLogger.error('Error getting client vouchers: $e');
      return [];
    }
  }

  /// Get applicable vouchers for cart items
  Future<List<ClientVoucherModel>> getApplicableVouchers(String clientId, List<Map<String, dynamic>> cartItems) async {
    try {
      AppLogger.info('Getting applicable vouchers for client: $clientId');
      return await _voucherService.getApplicableVouchers(clientId, cartItems);
    } catch (e) {
      AppLogger.error('Error getting applicable vouchers: $e');
      return [];
    }
  }

  /// Use voucher (mark as used)
  Future<bool> useVoucher(String clientVoucherId, String orderId, double discountAmount) async {
    try {
      AppLogger.info('Using voucher: $clientVoucherId for order: $orderId');

      final request = VoucherUsageRequest(
        clientVoucherId: clientVoucherId,
        orderId: orderId,
        discountAmount: discountAmount,
      );

      final usedVoucher = await _voucherService.useVoucher(request);

      if (usedVoucher != null) {
        AppLogger.info('Voucher used successfully');
        return true;
      } else {
        AppLogger.error('Failed to use voucher');
        return false;
      }
    } catch (e) {
      AppLogger.error('Error using voucher: $e');
      return false;
    }
  }

  /// Check if voucher is valid for client
  Future<bool> isVoucherValidForClient(String voucherCode, String clientId) async {
    try {
      return await _voucherService.isVoucherValidForClient(voucherCode, clientId);
    } catch (e) {
      AppLogger.error('Error checking voucher validity: $e');
      return false;
    }
  }

  /// Calculate voucher discount for cart items
  Map<String, dynamic> calculateVoucherDiscount(VoucherModel voucher, List<Map<String, dynamic>> cartItems) {
    return _voucherService.calculateVoucherDiscount(voucher, cartItems);
  }

  /// Safe notifyListeners that checks disposal state
  void _safeNotifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }
}