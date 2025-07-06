import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_logger.dart';
import 'auth_state_manager.dart';
import 'test_session_service.dart';

/// Service to synchronize authentication state after login
class AuthSyncService {
  static final _supabase = Supabase.instance.client;
  static bool _isInitialized = false;
  static bool _isCriticalOperationInProgress = false;

  /// Initialize authentication synchronization
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      AppLogger.info('🔄 AuthSyncService: Initializing...');
      
      // Listen to auth state changes
      _supabase.auth.onAuthStateChange.listen((data) {
        _handleAuthStateChange(data.event, data.session);
      });
      
      _isInitialized = true;
      AppLogger.info('✅ AuthSyncService: Initialized successfully');
    } catch (e) {
      AppLogger.error('❌ AuthSyncService: Initialization failed: $e');
    }
  }

  /// Handle authentication state changes
  static void _handleAuthStateChange(AuthChangeEvent event, Session? session) {
    AppLogger.info('🔄 AuthSyncService: Auth state changed: $event');
    
    switch (event) {
      case AuthChangeEvent.signedIn:
        _handleSignedIn(session);
        break;
      case AuthChangeEvent.signedOut:
        _handleSignedOut();
        break;
      case AuthChangeEvent.tokenRefreshed:
        _handleTokenRefreshed(session);
        break;
      case AuthChangeEvent.userUpdated:
        _handleUserUpdated(session);
        break;
      default:
        AppLogger.info('ℹ️ AuthSyncService: Unhandled auth event: $event');
    }
  }

  /// Handle user signed in
  static void _handleSignedIn(Session? session) {
    AppLogger.info('✅ AuthSyncService: User signed in');
    if (session?.user != null) {
      AppLogger.info('👤 User ID: ${session!.user.id}');
      AppLogger.info('📧 Email: ${session.user.email}');
      
      // Trigger a validation to ensure AuthStateManager can detect the session
      _validateAuthState();
    }
  }

  /// Handle user signed out
  static void _handleSignedOut() {
    AppLogger.info('🚪 AuthSyncService: User signed out');

    // Clear stored session information
    try {
      AuthStateManager.clearSessionInfo();
      AppLogger.info('🗑️ Session info cleared on sign out');
    } catch (e) {
      AppLogger.error('❌ Failed to clear session info on sign out: $e');
    }
  }

  /// Handle token refreshed
  static void _handleTokenRefreshed(Session? session) {
    // Reduce logging frequency during critical operations
    if (!_isCriticalOperationInProgress) {
      AppLogger.info('🔄 AuthSyncService: Token refreshed');
      if (session?.user != null) {
        AppLogger.info('✅ Session refreshed for user: ${session!.user.id}');
      }
    }
  }

  /// Set critical operation flag to reduce interference
  static void setCriticalOperationInProgress(bool inProgress) {
    _isCriticalOperationInProgress = inProgress;
  }

  /// Handle user updated
  static void _handleUserUpdated(Session? session) {
    AppLogger.info('👤 AuthSyncService: User updated');
  }

  /// Validate authentication state after login
  static Future<void> _validateAuthState() async {
    try {
      AppLogger.info('🔍 AuthSyncService: Validating auth state...');
      
      // Wait a moment for the session to fully establish
      await Future.delayed(const Duration(milliseconds: 1000));
      
      // Test AuthStateManager
      final currentUser = await AuthStateManager.getCurrentUser();
      if (currentUser != null) {
        AppLogger.info('✅ AuthStateManager validation successful: ${currentUser.id}');
      } else {
        AppLogger.warning('⚠️ AuthStateManager validation failed - user is null');
        
        // Try to force refresh
        final refreshedUser = await AuthStateManager.getCurrentUser(forceRefresh: true);
        if (refreshedUser != null) {
          AppLogger.info('✅ AuthStateManager force refresh successful: ${refreshedUser.id}');
        } else {
          AppLogger.error('❌ AuthStateManager force refresh failed');
        }
      }
      
      // Test user profile access
      final userProfile = await AuthStateManager.getCurrentUserProfile();
      if (userProfile != null) {
        AppLogger.info('✅ User profile access successful: ${userProfile['role']}');
      } else {
        AppLogger.warning('⚠️ User profile access failed');
      }
      
      // Test warehouse access
      final hasWarehouseAccess = await AuthStateManager.hasWarehouseAccess();
      AppLogger.info('🏢 Warehouse access: ${hasWarehouseAccess ? 'GRANTED' : 'DENIED'}');
      
    } catch (e) {
      AppLogger.error('❌ AuthSyncService: Auth state validation failed: $e');
    }
  }

  /// Manually trigger authentication state synchronization
  static Future<bool> syncAuthState() async {
    try {
      AppLogger.info('🔄 AuthSyncService: Manual auth state sync...');

      // CRITICAL FIX: Multiple attempts with progressive delays to handle session propagation timing
      for (int attempt = 1; attempt <= 3; attempt++) {
        AppLogger.info('🔄 Sync attempt $attempt/3...');

        final currentUser = _supabase.auth.currentUser;
        final currentSession = _supabase.auth.currentSession;

        AppLogger.info('🔍 Session check - User: ${currentUser?.id ?? 'null'}, Session: ${currentSession != null ? 'exists' : 'null'}');

        if (currentUser != null && currentSession != null) {
          if (currentSession.isExpired) {
            AppLogger.info('🔄 Session expired, attempting refresh...');
            try {
              await _supabase.auth.refreshSession();
              AppLogger.info('✅ Session refreshed successfully');
            } catch (e) {
              AppLogger.error('❌ Session refresh failed: $e');
              if (attempt == 3) return false;
              continue;
            }
          }

          // Session found and valid, proceed with validation
          AppLogger.info('✅ Valid session found, proceeding with auth state validation...');
          await _validateAuthState();
          return true;
        }

        // CRITICAL FIX: Check if this might be a test account scenario
        if (currentUser != null && currentSession == null) {
          AppLogger.info('🧪 User exists but no session - possible test account scenario');

          // Check if this is a test session
          if (TestSessionService.isTestSession()) {
            AppLogger.info('✅ Confirmed test session, validating test session state...');

            final testSessionValid = await TestSessionService.validateTestSession();
            if (testSessionValid) {
              AppLogger.info('✅ Test session is valid, proceeding with auth state validation...');
              try {
                await _validateAuthState();
                AppLogger.info('✅ Auth state validation successful for test session');
                return true;
              } catch (e) {
                AppLogger.warning('⚠️ Auth state validation failed for test session: $e');
              }
            } else {
              AppLogger.warning('⚠️ Test session validation failed, attempting refresh...');
              if (await TestSessionService.refreshTestSession()) {
                AppLogger.info('✅ Test session refreshed, retrying validation...');
                try {
                  await _validateAuthState();
                  return true;
                } catch (e) {
                  AppLogger.warning('⚠️ Auth state validation failed after test session refresh: $e');
                }
              }
            }
          } else {
            AppLogger.info('🔄 Not a test session, attempting regular auth state validation...');
            try {
              await _validateAuthState();
              AppLogger.info('✅ Auth state validation successful despite missing session');
              return true;
            } catch (e) {
              AppLogger.warning('⚠️ Auth state validation failed: $e');
            }
          }
        }

        // If no session found, wait before next attempt (except last one)
        if (attempt < 3) {
          final delayMs = attempt * 750; // 750ms, 1.5s delays
          AppLogger.info('⏳ No session found, waiting ${delayMs}ms before retry...');
          await Future.delayed(Duration(milliseconds: delayMs));
        }
      }

      AppLogger.warning('⚠️ No user or session found for sync after all attempts');
      AppLogger.info('💡 This may be normal if user hasn\'t authenticated yet or is using test account');
      return false;

    } catch (e) {
      AppLogger.error('❌ AuthSyncService: Manual sync failed: $e');
      return false;
    }
  }

  /// Force authentication state recovery
  static Future<bool> forceAuthRecovery() async {
    try {
      AppLogger.info('🔄 AuthSyncService: Force auth recovery...');
      
      // Try session initialization
      final sessionInitialized = await AuthStateManager.initializeSession();
      if (sessionInitialized) {
        AppLogger.info('✅ Session initialization successful');
        await _validateAuthState();
        return true;
      }
      
      // Try session validation
      final sessionValid = await AuthStateManager.validateSession();
      if (sessionValid) {
        AppLogger.info('✅ Session validation successful');
        await _validateAuthState();
        return true;
      }
      
      AppLogger.warning('⚠️ Auth recovery failed - no valid session found');
      return false;
    } catch (e) {
      AppLogger.error('❌ AuthSyncService: Force recovery failed: $e');
      return false;
    }
  }

  /// Get current authentication status
  static Future<Map<String, dynamic>> getAuthStatus() async {
    try {
      final currentUser = _supabase.auth.currentUser;
      final currentSession = _supabase.auth.currentSession;
      final authStateUser = await AuthStateManager.getCurrentUser();
      final userProfile = await AuthStateManager.getCurrentUserProfile();
      final hasWarehouseAccess = await AuthStateManager.hasWarehouseAccess();
      
      return {
        'supabase_user_exists': currentUser != null,
        'supabase_session_exists': currentSession != null,
        'session_expired': currentSession?.isExpired ?? true,
        'auth_state_manager_user_exists': authStateUser != null,
        'user_profile_accessible': userProfile != null,
        'warehouse_access': hasWarehouseAccess,
        'user_id': currentUser?.id,
        'user_email': currentUser?.email,
        'user_role': userProfile?['role'],
        'user_status': userProfile?['status'],
        'session_expires_at': currentSession?.expiresAt != null
            ? DateTime.fromMillisecondsSinceEpoch(currentSession!.expiresAt! * 1000).toIso8601String()
            : null,
      };
    } catch (e) {
      return {
        'error': e.toString(),
      };
    }
  }
}
