import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_logger.dart';

const int SESSION_REFRESH_THRESHOLD_MINUTES = 5; // Refresh session if expiring within 5 minutes
const int SESSION_CHECK_INTERVAL_SECONDS = 30; // Check session every 30 seconds
const List<String> WAREHOUSE_ACCESS_ROLES = ['admin', 'owner', 'accountant', 'warehouseManager', 'warehouse_manager'];
const List<String> ALLOWED_STATUSES = ['approved', 'active'];

/// Service to manage authentication state and provide reliable user information
class AuthStateManager {
  static final _supabase = Supabase.instance.client;
  static const String _lastUserIdKey = 'auth_last_user_id';
  static const String _lastSessionKey = 'auth_last_session_timestamp';

  /// Get current user with enhanced session management and recovery
  static Future<User?> getCurrentUser({bool forceRefresh = false}) async {
    try {
      AppLogger.info('🔍 AuthStateManager: Getting current user...');

      // CRITICAL FIX: Multiple retry attempts with progressive delays
      for (int attempt = 1; attempt <= 3; attempt++) {
        AppLogger.info('🔄 Attempt $attempt/3: Checking for session...');

        // Check current user and session directly
        var currentUser = _supabase.auth.currentUser;
        var currentSession = _supabase.auth.currentSession;

        // Enhanced logging with session details
        AppLogger.info('👤 Current user: ${currentUser?.id ?? 'null'}');
        AppLogger.info('🔐 Current session: ${currentSession != null ? 'exists (expires: ${currentSession.expiresAt})' : 'null'}');

        // Check if session is expired
        final isSessionExpired = currentSession?.isExpired ?? true;
        AppLogger.info('⏰ Session expired: $isSessionExpired');

        // CRITICAL FIX: If we have a valid user and session, return immediately unless force refresh is requested
        if (currentUser != null && currentSession != null && !isSessionExpired && !forceRefresh) {
          AppLogger.info('✅ Valid user and session found: ${currentUser.id}');
          // Save session info for future recovery
          await _saveSessionInfo(currentUser.id);
          return currentUser;
        }

        // If session exists but is expired, try to refresh it
        if (currentSession != null && isSessionExpired && !forceRefresh) {
          AppLogger.info('🔄 Session expired, attempting refresh...');
          try {
            final refreshResult = await _supabase.auth.refreshSession();
            if (refreshResult.user != null) {
              AppLogger.info('✅ Session refreshed successfully: ${refreshResult.user!.id}');
              await _saveSessionInfo(refreshResult.user!.id);
              return refreshResult.user;
            }
          } catch (refreshError) {
            AppLogger.warning('⚠️ Session refresh failed: $refreshError');
          }
        }

        // Progressive delay between attempts
        if (attempt < 3) {
          final delayMs = attempt * 1000; // 1s, 2s delays
          AppLogger.info('🔄 Waiting ${delayMs}ms before next attempt...');
          await Future.delayed(Duration(milliseconds: delayMs));
        }
      }

      // If all direct attempts failed, try comprehensive recovery
      AppLogger.warning('⚠️ No authenticated user found, attempting comprehensive recovery...');

      try {
        final recoveredUser = await _attemptUserRecovery();
        if (recoveredUser != null) {
          AppLogger.info('✅ User recovered from alternative method: ${recoveredUser.id}');
          await _saveSessionInfo(recoveredUser.id);
          return recoveredUser;
        }
      } catch (recoveryError) {
        AppLogger.error('❌ User recovery failed: $recoveryError');
      }

      // Final validation
      AppLogger.warning('⚠️ No authenticated user found after all recovery attempts');
      AppLogger.warning('💡 User may need to re-authenticate');

      return null;
    } catch (e) {
      AppLogger.error('❌ AuthStateManager: Critical error getting current user: $e');
      return null;
    }
  }

  /// Attempt to recover user from alternative methods
  static Future<User?> _attemptUserRecovery() async {
    try {
      AppLogger.info('🔄 Attempting comprehensive user recovery...');

      // Method 1: Direct session check with multiple attempts
      for (int attempt = 1; attempt <= 3; attempt++) {
        AppLogger.info('🔍 Recovery attempt $attempt/3: Direct session check...');

        try {
          final currentSession = _supabase.auth.currentSession;
          final currentUser = _supabase.auth.currentUser;

          if (currentSession != null && currentUser != null) {
            if (!currentSession.isExpired) {
              AppLogger.info('✅ Found valid session in recovery attempt $attempt');
              await _saveSessionInfo(currentUser.id);
              return currentUser;
            } else {
              AppLogger.info('🔄 Session expired in attempt $attempt, trying refresh...');
              try {
                final refreshResult = await _supabase.auth.refreshSession();
                if (refreshResult.user != null) {
                  AppLogger.info('✅ Session refreshed successfully in attempt $attempt');
                  await _saveSessionInfo(refreshResult.user!.id);
                  return refreshResult.user;
                }
              } catch (refreshError) {
                AppLogger.warning('⚠️ Session refresh failed in attempt $attempt: $refreshError');
              }
            }
          }

          // Progressive delay between attempts
          if (attempt < 3) {
            final delayMs = attempt * 800; // 800ms, 1600ms
            await Future.delayed(Duration(milliseconds: delayMs));
          }
        } catch (e) {
          AppLogger.warning('⚠️ Recovery attempt $attempt failed: $e');
        }
      }

      // Method 2: Check stored session info and attempt recovery
      try {
        final lastUserId = await _getLastUserId();
        if (lastUserId != null) {
          AppLogger.info('🔍 Found stored user ID: $lastUserId, attempting session recovery...');

          // Shorter wait time to reduce overall delay
          await Future.delayed(const Duration(milliseconds: 500));

          final recoveredSession = _supabase.auth.currentSession;
          final recoveredUser = _supabase.auth.currentUser;

          if (recoveredSession != null && recoveredUser != null && recoveredUser.id == lastUserId) {
            if (!recoveredSession.isExpired) {
              AppLogger.info('✅ Valid session recovered for stored user');
              return recoveredUser;
            } else {
              AppLogger.info('🔄 Stored user session expired, attempting refresh...');
              try {
                final refreshResult = await _supabase.auth.refreshSession();
                if (refreshResult.user != null && refreshResult.user!.id == lastUserId) {
                  AppLogger.info('✅ Stored user session refreshed successfully');
                  return refreshResult.user;
                }
              } catch (refreshError) {
                AppLogger.warning('⚠️ Failed to refresh stored user session: $refreshError');
              }
            }
          }
        }
      } catch (e) {
        AppLogger.warning('⚠️ Stored session recovery failed: $e');
      }

      // Method 2: Force session check with longer delay
      try {
        AppLogger.info('🔄 Force session check with extended delay...');
        await Future.delayed(const Duration(milliseconds: 2000));

        final recoveredSession = _supabase.auth.currentSession;
        final recoveredUser = _supabase.auth.currentUser;

        if (recoveredSession != null && recoveredUser != null) {
          if (!recoveredSession.isExpired) {
            AppLogger.info('✅ Valid session found on force check');
            return recoveredUser;
          } else {
            AppLogger.info('🔄 Force check found expired session, attempting refresh...');
            try {
              final refreshResult = await _supabase.auth.refreshSession();
              if (refreshResult.user != null) {
                AppLogger.info('✅ Force check session refreshed successfully');
                return refreshResult.user;
              }
            } catch (refreshError) {
              AppLogger.warning('⚠️ Failed to refresh force check session: $refreshError');
            }
          }
        }
      } catch (e) {
        AppLogger.warning('⚠️ Force session check failed: $e');
      }

      // Method 3: Force session initialization if all else fails
      AppLogger.info('🔄 Final recovery attempt: Force session initialization...');
      try {
        // Wait for any pending auth state changes
        await Future.delayed(const Duration(milliseconds: 1000));

        // Check one more time after delay
        final finalSession = _supabase.auth.currentSession;
        final finalUser = _supabase.auth.currentUser;

        if (finalSession != null && finalUser != null && !finalSession.isExpired) {
          AppLogger.info('✅ Session found in final recovery attempt');
          await _saveSessionInfo(finalUser.id);
          return finalUser;
        }
      } catch (e) {
        AppLogger.warning('⚠️ Final recovery attempt failed: $e');
      }

      AppLogger.warning('❌ All recovery methods failed');
      return null;
    } catch (e) {
      AppLogger.error('❌ User recovery attempt failed: $e');
      return null;
    }
  }

  /// Validate current authentication state
  static Future<bool> validateAuthenticationState() async {
    try {
      final currentUser = await getCurrentUser(forceRefresh: false);
      if (currentUser == null) {
        AppLogger.warning('⚠️ Authentication validation failed: No user found');
        return false;
      }

      final currentSession = _supabase.auth.currentSession;
      if (currentSession == null || currentSession.isExpired) {
        AppLogger.warning('⚠️ Authentication validation failed: Invalid session');
        return false;
      }

      AppLogger.info('✅ Authentication state validated successfully');
      return true;
    } catch (e) {
      AppLogger.error('❌ Authentication validation error: $e');
      return false;
    }
  }

  /// Get current user profile with role and status information
  static Future<Map<String, dynamic>?> getCurrentUserProfile({bool forceRefresh = false}) async {
    try {
      final currentUser = await getCurrentUser(forceRefresh: forceRefresh);

      if (currentUser == null) {
        AppLogger.error('❌ AuthStateManager: No authenticated user found');
        return null;
      }

      AppLogger.info('👤 AuthStateManager: Fetching user profile for: ${currentUser.id}');

      final userProfile = await _supabase
          .from('user_profiles')
          .select('id, name, email, role, status')
          .eq('id', currentUser.id)
          .single();

      AppLogger.info('✅ AuthStateManager: User profile loaded successfully');
      AppLogger.info('🎭 Role: ${userProfile['role']}');
      AppLogger.info('📊 Status: ${userProfile['status']}');

      return userProfile;
    } catch (e) {
      AppLogger.error('❌ AuthStateManager: Error getting user profile: $e');
      return null;
    }
  }

  /// Check if current user has warehouse access - ENHANCED VERSION
  static Future<bool> hasWarehouseAccess() async {
    try {
      AppLogger.info('🔐 AuthStateManager: Starting warehouse access check...');

      // CRITICAL FIX: Try multiple methods to get user profile
      Map<String, dynamic>? userProfile;

      // Method 1: Try getCurrentUserProfile
      try {
        userProfile = await getCurrentUserProfile();
        if (userProfile != null) {
          AppLogger.info('✅ Got user profile via getCurrentUserProfile');
        }
      } catch (e) {
        AppLogger.warning('⚠️ getCurrentUserProfile failed: $e');
      }

      // Method 2: If that fails, try direct query
      if (userProfile == null) {
        try {
          final currentUser = _supabase.auth.currentUser;
          if (currentUser != null) {
            AppLogger.info('🔄 Trying direct user profile query...');
            userProfile = await _supabase
                .from('user_profiles')
                .select('id, name, email, role, status')
                .eq('id', currentUser.id)
                .single();
            AppLogger.info('✅ Got user profile via direct query');
          }
        } catch (e) {
          AppLogger.warning('⚠️ Direct user profile query failed: $e');
        }
      }

      if (userProfile == null) {
        AppLogger.error('❌ AuthStateManager: No user profile found for warehouse access check');
        return false;
      }

      final role = userProfile['role'] as String?;
      final status = userProfile['status'] as String?;

      // ENHANCED: Support both camelCase and snake_case role formats
      final allowedRoles = ['admin', 'owner', 'accountant', 'warehouseManager', 'warehouse_manager'];
      final allowedStatuses = ['approved', 'active'];

      final hasRoleAccess = role != null && allowedRoles.contains(role);
      final hasStatusAccess = status != null && allowedStatuses.contains(status);

      AppLogger.info('🔐 AuthStateManager: Warehouse access check results:');
      AppLogger.info('   User ID: ${userProfile['id']}');
      AppLogger.info('   Email: ${userProfile['email']}');
      AppLogger.info('   Role: $role (${hasRoleAccess ? 'ALLOWED' : 'DENIED'})');
      AppLogger.info('   Status: $status (${hasStatusAccess ? 'ALLOWED' : 'DENIED'})');
      AppLogger.info('   Overall Access: ${hasRoleAccess && hasStatusAccess}');

      final hasAccess = hasRoleAccess && hasStatusAccess;

      // CRITICAL FIX: If access is denied, provide detailed explanation
      if (!hasAccess) {
        if (!hasRoleAccess) {
          AppLogger.warning('❌ Access denied: Role "$role" not in allowed roles: $allowedRoles');
        }
        if (!hasStatusAccess) {
          AppLogger.warning('❌ Access denied: Status "$status" not in allowed statuses: $allowedStatuses');
        }
      }

      return hasAccess;
    } catch (e) {
      AppLogger.error('❌ AuthStateManager: Error checking warehouse access: $e');
      return false;
    }
  }

  /// Initialize session on app startup
  static Future<bool> initializeSession() async {
    try {
      AppLogger.info('🚀 AuthStateManager: Initializing session...');

      // Check for existing session (Supabase handles automatic recovery)
      final session = _supabase.auth.currentSession;
      final user = _supabase.auth.currentUser;

      if (session != null && user != null) {
        if (!session.isExpired) {
          AppLogger.info('✅ Session initialized successfully: ${user.id}');
          return true;
        } else {
          AppLogger.info('🔄 Session expired, attempting refresh...');
          try {
            await _supabase.auth.refreshSession();
            final refreshedUser = _supabase.auth.currentUser;
            if (refreshedUser != null) {
              AppLogger.info('✅ Session refreshed during initialization: ${refreshedUser.id}');
              return true;
            }
          } catch (e) {
            AppLogger.error('❌ Failed to refresh session during initialization: $e');
          }
        }
      }

      AppLogger.info('ℹ️ No valid session found during initialization');
      return false;
    } catch (e) {
      AppLogger.error('❌ AuthStateManager: Session initialization failed: $e');
      return false;
    }
  }

  /// Validate current session
  static Future<bool> validateSession() async {
    try {
      final session = _supabase.auth.currentSession;
      final user = _supabase.auth.currentUser;

      if (session == null || user == null) {
        AppLogger.warning('⚠️ No session or user found');
        return false;
      }

      if (session.isExpired) {
        AppLogger.warning('⚠️ Session is expired');
        try {
          await _supabase.auth.refreshSession();
          final refreshedUser = _supabase.auth.currentUser;
          if (refreshedUser != null) {
            AppLogger.info('✅ Session refreshed successfully');
            return true;
          }
        } catch (e) {
          AppLogger.error('❌ Failed to refresh expired session: $e');
          return false;
        }
      }

      AppLogger.info('✅ Session is valid');
      return true;
    } catch (e) {
      AppLogger.error('❌ Session validation failed: $e');
      return false;
    }
  }

  /// Save session information for recovery
  static Future<void> _saveSessionInfo(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastUserIdKey, userId);
      await prefs.setInt(_lastSessionKey, DateTime.now().millisecondsSinceEpoch);
      AppLogger.info('💾 Session info saved for user: $userId');
    } catch (e) {
      AppLogger.error('❌ Failed to save session info: $e');
    }
  }

  /// Get last user ID from storage
  static Future<String?> _getLastUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_lastUserIdKey);
    } catch (e) {
      AppLogger.error('❌ Failed to get last user ID: $e');
      return null;
    }
  }

  /// Clear stored session information
  static Future<void> clearSessionInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastUserIdKey);
      await prefs.remove(_lastSessionKey);
      AppLogger.info('🗑️ Session info cleared');
    } catch (e) {
      AppLogger.error('❌ Failed to clear session info: $e');
    }
  }
}
