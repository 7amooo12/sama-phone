import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_logger.dart';
import 'auth_state_manager.dart';
import 'session_recovery_service.dart';

/// Comprehensive authentication diagnostic service
class AuthDiagnosticService {
  static final _supabase = Supabase.instance.client;

  /// Run comprehensive authentication diagnostics
  static Future<Map<String, dynamic>> runFullDiagnostics() async {
    AppLogger.info('🔍 Starting comprehensive authentication diagnostics...');
    
    final diagnostics = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'supabase_status': {},
      'auth_state_manager': {},
      'session_recovery': {},
      'storage_status': {},
      'recommendations': [],
    };

    try {
      // Test 1: Supabase client status
      diagnostics['supabase_status'] = await _testSupabaseStatus();
      
      // Test 2: AuthStateManager functionality
      diagnostics['auth_state_manager'] = await _testAuthStateManager();
      
      // Test 3: Session recovery mechanisms
      diagnostics['session_recovery'] = await _testSessionRecovery();
      
      // Test 4: Storage mechanisms
      diagnostics['storage_status'] = await _testStorageStatus();
      
      // Generate recommendations
      diagnostics['recommendations'] = _generateRecommendations(diagnostics);
      
      AppLogger.info('✅ Authentication diagnostics completed');
      
    } catch (e) {
      AppLogger.error('❌ Diagnostics failed: $e');
      diagnostics['error'] = e.toString();
    }

    return diagnostics;
  }

  /// Test Supabase client status
  static Future<Map<String, dynamic>> _testSupabaseStatus() async {
    final status = <String, dynamic>{};
    
    try {
      // Check current session
      final session = _supabase.auth.currentSession;
      final user = _supabase.auth.currentUser;
      
      status['session_exists'] = session != null;
      status['user_exists'] = user != null;
      status['session_expired'] = session?.isExpired ?? true;
      
      if (session != null) {
        status['session_expires_at'] = session.expiresAt;
        status['has_refresh_token'] = session.refreshToken != null;
        status['has_access_token'] = session.accessToken != null;
      }
      
      if (user != null) {
        status['user_id'] = user.id;
        status['user_email'] = user.email;
      }
      
      // Test session refresh capability
      if (session != null && session.isExpired) {
        try {
          await _supabase.auth.refreshSession();
          status['refresh_test'] = 'success';
        } catch (e) {
          status['refresh_test'] = 'failed: $e';
        }
      }
      
    } catch (e) {
      status['error'] = e.toString();
    }
    
    return status;
  }

  /// Test AuthStateManager functionality
  static Future<Map<String, dynamic>> _testAuthStateManager() async {
    final status = <String, dynamic>{};
    
    try {
      // Test getCurrentUser
      final startTime = DateTime.now();
      final currentUser = await AuthStateManager.getCurrentUser();
      final endTime = DateTime.now();
      
      status['get_current_user'] = {
        'success': currentUser != null,
        'user_id': currentUser?.id,
        'duration_ms': endTime.difference(startTime).inMilliseconds,
      };
      
      // Test getCurrentUserProfile
      if (currentUser != null) {
        final profileStartTime = DateTime.now();
        final userProfile = await AuthStateManager.getCurrentUserProfile();
        final profileEndTime = DateTime.now();
        
        status['get_user_profile'] = {
          'success': userProfile != null,
          'profile_data': userProfile,
          'duration_ms': profileEndTime.difference(profileStartTime).inMilliseconds,
        };
        
        // Test warehouse access
        final accessStartTime = DateTime.now();
        final hasAccess = await AuthStateManager.hasWarehouseAccess();
        final accessEndTime = DateTime.now();
        
        status['warehouse_access'] = {
          'has_access': hasAccess,
          'duration_ms': accessEndTime.difference(accessStartTime).inMilliseconds,
        };
      }
      
      // Test session validation
      final validationStartTime = DateTime.now();
      final sessionValid = await AuthStateManager.validateSession();
      final validationEndTime = DateTime.now();
      
      status['session_validation'] = {
        'is_valid': sessionValid,
        'duration_ms': validationEndTime.difference(validationStartTime).inMilliseconds,
      };
      
    } catch (e) {
      status['error'] = e.toString();
    }
    
    return status;
  }

  /// Test session recovery mechanisms
  static Future<Map<String, dynamic>> _testSessionRecovery() async {
    final status = <String, dynamic>{};
    
    try {
      // Test session recovery service
      final recoveryStartTime = DateTime.now();
      final recoveryResult = await SessionRecoveryService.initializeSessionRecovery();
      final recoveryEndTime = DateTime.now();
      
      status['recovery_test'] = {
        'success': recoveryResult,
        'duration_ms': recoveryEndTime.difference(recoveryStartTime).inMilliseconds,
      };
      
      // Test session health check
      final healthResult = await SessionRecoveryService.isSessionHealthy();
      status['session_health'] = healthResult;
      
      // Get recovery diagnostics
      final recoveryDiagnostics = await SessionRecoveryService.getDiagnostics();
      status['recovery_diagnostics'] = recoveryDiagnostics;
      
    } catch (e) {
      status['error'] = e.toString();
    }
    
    return status;
  }

  /// Test storage mechanisms
  static Future<Map<String, dynamic>> _testStorageStatus() async {
    final status = <String, dynamic>{};
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check for stored session info
      final lastUserId = prefs.getString('auth_last_user_id');
      final lastSessionTimestamp = prefs.getInt('auth_last_session_timestamp');
      
      status['stored_user_id'] = lastUserId;
      status['stored_session_timestamp'] = lastSessionTimestamp;
      status['has_stored_session_info'] = lastUserId != null && lastSessionTimestamp != null;
      
      if (lastSessionTimestamp != null) {
        final sessionTime = DateTime.fromMillisecondsSinceEpoch(lastSessionTimestamp);
        final timeSinceLastSession = DateTime.now().difference(sessionTime);
        status['time_since_last_session_hours'] = timeSinceLastSession.inHours;
      }
      
      // Test storage write capability
      try {
        await prefs.setString('auth_diagnostic_test', DateTime.now().toIso8601String());
        await prefs.remove('auth_diagnostic_test');
        status['storage_write_test'] = 'success';
      } catch (e) {
        status['storage_write_test'] = 'failed: $e';
      }
      
    } catch (e) {
      status['error'] = e.toString();
    }
    
    return status;
  }

  /// Generate recommendations based on diagnostic results
  static List<String> _generateRecommendations(Map<String, dynamic> diagnostics) {
    final recommendations = <String>[];
    
    try {
      final supabaseStatus = diagnostics['supabase_status'] as Map<String, dynamic>?;
      final authManagerStatus = diagnostics['auth_state_manager'] as Map<String, dynamic>?;
      final recoveryStatus = diagnostics['session_recovery'] as Map<String, dynamic>?;
      final storageStatus = diagnostics['storage_status'] as Map<String, dynamic>?;
      
      // Check for common issues and provide recommendations
      if (supabaseStatus?['session_exists'] != true) {
        recommendations.add('No active session found - user needs to authenticate');
      }
      
      if (supabaseStatus?['session_expired'] == true) {
        recommendations.add('Session is expired - implement automatic refresh on app startup');
      }
      
      if (authManagerStatus?['get_current_user']?['success'] != true) {
        recommendations.add('AuthStateManager.getCurrentUser() is failing - check session recovery logic');
      }
      
      if (recoveryStatus?['recovery_test']?['success'] != true) {
        recommendations.add('Session recovery is failing - check SessionRecoveryService implementation');
      }
      
      if (storageStatus?['has_stored_session_info'] != true) {
        recommendations.add('No stored session info found - session persistence may not be working');
      }
      
      // Performance recommendations
      final getUserDuration = authManagerStatus?['get_current_user']?['duration_ms'] as int?;
      if (getUserDuration != null && getUserDuration > 5000) {
        recommendations.add('getCurrentUser() is taking too long (${getUserDuration}ms) - optimize session checks');
      }
      
      if (recommendations.isEmpty) {
        recommendations.add('Authentication system appears to be working correctly');
      }
      
    } catch (e) {
      recommendations.add('Error generating recommendations: $e');
    }
    
    return recommendations;
  }

  /// Quick authentication status check
  static Future<String> getQuickStatus() async {
    try {
      final user = await AuthStateManager.getCurrentUser();
      if (user != null) {
        final profile = await AuthStateManager.getCurrentUserProfile();
        final role = profile?['role'] ?? 'unknown';
        return 'Authenticated as $role (${user.id})';
      } else {
        return 'Not authenticated';
      }
    } catch (e) {
      return 'Authentication check failed: $e';
    }
  }
}
