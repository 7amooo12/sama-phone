import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_logger.dart';

/// Service dedicated to session recovery and persistence
class SessionRecoveryService {
  static final _supabase = Supabase.instance.client;
  static const String _lastUserIdKey = 'last_user_id';
  static const String _lastSessionKey = 'last_session_timestamp';

  /// Initialize session recovery on app startup
  static Future<bool> initializeSessionRecovery() async {
    try {
      AppLogger.info('🔄 SessionRecoveryService: Starting enhanced session recovery...');

      // Step 1: Multiple attempts with progressive delays
      for (int attempt = 1; attempt <= 4; attempt++) {
        AppLogger.info('🔄 Recovery attempt $attempt/4...');

        final currentSession = _supabase.auth.currentSession;
        final currentUser = _supabase.auth.currentUser;

        if (currentSession != null && currentUser != null) {
          if (!currentSession.isExpired) {
            AppLogger.info('✅ Active session found: ${currentUser.id}');
            await _saveSessionInfo(currentUser.id);
            return true;
          } else {
            AppLogger.info('🔄 Session is expired, attempting refresh...');
            if (await _refreshExpiredSession()) {
              return true;
            }
          }
        }

        // Check stored user info for recovery
        final lastUserId = await _getLastUserId();
        if (lastUserId != null) {
          AppLogger.info('🔍 Found last user ID: $lastUserId, checking for session...');

          // Progressive delay for session establishment
          final delayMs = attempt * 750; // 750ms, 1.5s, 2.25s, 3s
          await Future.delayed(Duration(milliseconds: delayMs));

          final retrySession = _supabase.auth.currentSession;
          final retryUser = _supabase.auth.currentUser;

          if (retrySession != null && retryUser != null && retryUser.id == lastUserId) {
            if (!retrySession.isExpired) {
              AppLogger.info('✅ Session found on retry: ${retryUser.id}');
              return true;
            } else {
              if (await _refreshExpiredSession()) {
                return true;
              }
            }
          }
        }

        // Wait before next attempt (except last one)
        if (attempt < 4) {
          await Future.delayed(Duration(milliseconds: attempt * 500));
        }
      }

      AppLogger.info('ℹ️ No recoverable session found after all attempts');
      return false;
    } catch (e) {
      AppLogger.error('❌ Session recovery failed: $e');
      return false;
    }
  }

  /// Refresh an expired session
  static Future<bool> _refreshExpiredSession() async {
    try {
      AppLogger.info('🔄 Attempting to refresh expired session...');
      
      final refreshResult = await _supabase.auth.refreshSession();
      if (refreshResult.user != null) {
        AppLogger.info('✅ Expired session refreshed successfully: ${refreshResult.user!.id}');
        await _saveSessionInfo(refreshResult.user!.id);
        return true;
      } else {
        AppLogger.warning('⚠️ Session refresh returned null user');
        return false;
      }
    } catch (e) {
      AppLogger.error('❌ Failed to refresh expired session: $e');
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

  /// Check if session is healthy
  static Future<bool> isSessionHealthy() async {
    try {
      final session = _supabase.auth.currentSession;
      final user = _supabase.auth.currentUser;

      if (session == null || user == null) {
        return false;
      }

      if (session.isExpired) {
        AppLogger.info('🔄 Session expired, attempting refresh...');
        try {
          await _supabase.auth.refreshSession();
          final refreshedUser = _supabase.auth.currentUser;
          if (refreshedUser != null) {
            await _saveSessionInfo(refreshedUser.id);
            return true;
          }
        } catch (e) {
          AppLogger.error('❌ Failed to refresh session: $e');
          return false;
        }
      }

      return true;
    } catch (e) {
      AppLogger.error('❌ Session health check failed: $e');
      return false;
    }
  }

  /// Force session recovery with multiple attempts
  static Future<bool> forceSessionRecovery() async {
    try {
      AppLogger.info('🔄 Force session recovery initiated...');

      // Attempt 1: Standard recovery
      if (await initializeSessionRecovery()) {
        return true;
      }

      // Attempt 2: Wait and retry (sometimes sessions need time to initialize)
      AppLogger.info('🔄 First attempt failed, waiting and retrying...');
      await Future.delayed(const Duration(milliseconds: 2000));

      if (await initializeSessionRecovery()) {
        return true;
      }

      // Attempt 3: Manual session check
      AppLogger.info('🔄 Second attempt failed, manual session check...');
      try {
        // For Supabase Flutter 2.3.4, we use currentSession
        final session = _supabase.auth.currentSession;
        if (session != null && session.user != null) {
          if (!session.isExpired) {
            AppLogger.info('✅ Manual session check successful: ${session.user!.id}');
            await _saveSessionInfo(session.user!.id);
            return true;
          } else {
            // Try to refresh expired session
            try {
              await _supabase.auth.refreshSession();
              final refreshedUser = _supabase.auth.currentUser;
              if (refreshedUser != null) {
                AppLogger.info('✅ Session refreshed in manual check: ${refreshedUser.id}');
                await _saveSessionInfo(refreshedUser.id);
                return true;
              }
            } catch (refreshError) {
              AppLogger.error('❌ Failed to refresh session in manual check: $refreshError');
            }
          }
        }
      } catch (e) {
        AppLogger.error('❌ Manual session check failed: $e');
      }

      AppLogger.warning('❌ All force recovery attempts failed');
      return false;
    } catch (e) {
      AppLogger.error('❌ Force session recovery failed: $e');
      return false;
    }
  }

  /// Get session diagnostics
  static Future<Map<String, dynamic>> getSessionDiagnostics() async {
    final diagnostics = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'session_exists': false,
      'session_expired': true,
      'user_exists': false,
      'last_user_id': null,
      'recovery_possible': false,
    };

    try {
      final session = _supabase.auth.currentSession;
      final user = _supabase.auth.currentUser;
      final lastUserId = await _getLastUserId();

      diagnostics['session_exists'] = session != null;
      diagnostics['session_expired'] = session?.isExpired ?? true;
      diagnostics['user_exists'] = user != null;
      diagnostics['user_id'] = user?.id;
      diagnostics['last_user_id'] = lastUserId;
      diagnostics['recovery_possible'] = lastUserId != null || session != null;

      if (session != null) {
        diagnostics['session_expires_at'] = session.expiresAt;
        diagnostics['session_refresh_token'] = session.refreshToken != null;
      }

    } catch (e) {
      diagnostics['error'] = e.toString();
    }

    return diagnostics;
  }
}
