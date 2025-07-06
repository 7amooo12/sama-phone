// 🔍 WAREHOUSE ACCESS DIAGNOSTIC SERVICE
// Comprehensive diagnostic tool for testing warehouse data access across different user roles

import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_logger.dart';
import 'auth_state_manager.dart';

class WarehouseAccessDiagnostic {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Run comprehensive warehouse access diagnostic
  static Future<Map<String, dynamic>> runFullDiagnostic() async {
    try {
      AppLogger.info('🔍 === بدء التشخيص الشامل لوصول المخازن ===');

      final results = <String, dynamic>{
        'timestamp': DateTime.now().toIso8601String(),
        'user_context': {},
        'authentication_tests': {},
        'warehouse_access_tests': {},
        'rls_policy_tests': {},
        'summary': {},
      };

      // Step 1: User Context Analysis
      results['user_context'] = await _analyzeUserContext();

      // Step 2: Authentication Tests
      results['authentication_tests'] = await _testAuthentication();

      // Step 3: Warehouse Access Tests
      results['warehouse_access_tests'] = await _testWarehouseAccess();

      // Step 4: RLS Policy Tests
      results['rls_policy_tests'] = await _testRLSPolicies();

      // Step 5: Generate Summary
      results['summary'] = _generateSummary(results);

      AppLogger.info('✅ تم إكمال التشخيص الشامل بنجاح');
      return results;

    } catch (e) {
      AppLogger.error('❌ خطأ في التشخيص الشامل: $e');
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Analyze current user context
  static Future<Map<String, dynamic>> _analyzeUserContext() async {
    try {
      AppLogger.info('👤 تحليل سياق المستخدم الحالي...');

      final context = <String, dynamic>{};

      // Method 1: Direct Supabase auth
      final supabaseUser = _supabase.auth.currentUser;
      context['supabase_auth'] = {
        'user_id': supabaseUser?.id,
        'email': supabaseUser?.email,
        'is_authenticated': supabaseUser != null,
      };

      // Method 2: AuthStateManager
      final authStateUser = await AuthStateManager.getCurrentUser();
      context['auth_state_manager'] = {
        'user_id': authStateUser?.id,
        'email': authStateUser?.email,
        'is_authenticated': authStateUser != null,
      };

      // Method 3: User Profile
      if (supabaseUser != null) {
        try {
          final userProfile = await _supabase
              .from('user_profiles')
              .select('id, email, name, role, status')
              .eq('id', supabaseUser.id)
              .single();

          context['user_profile'] = {
            'success': true,
            'data': userProfile,
            'role': userProfile['role'],
            'status': userProfile['status'],
            'expected_warehouse_access': _shouldHaveWarehouseAccess(
              userProfile['role'], 
              userProfile['status']
            ),
          };
        } catch (e) {
          context['user_profile'] = {
            'success': false,
            'error': e.toString(),
          };
        }
      }

      return context;
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Test authentication methods
  static Future<Map<String, dynamic>> _testAuthentication() async {
    try {
      AppLogger.info('🔐 اختبار طرق المصادقة...');

      final tests = <String, dynamic>{};

      // Test 1: Supabase auth current user
      tests['supabase_current_user'] = {
        'user_exists': _supabase.auth.currentUser != null,
        'user_id': _supabase.auth.currentUser?.id,
      };

      // Test 2: AuthStateManager current user
      try {
        final authUser = await AuthStateManager.getCurrentUser();
        tests['auth_state_manager_user'] = {
          'success': true,
          'user_exists': authUser != null,
          'user_id': authUser?.id,
        };
      } catch (e) {
        tests['auth_state_manager_user'] = {
          'success': false,
          'error': e.toString(),
        };
      }

      // Test 3: AuthStateManager user profile
      try {
        final userProfile = await AuthStateManager.getCurrentUserProfile();
        tests['auth_state_manager_profile'] = {
          'success': true,
          'profile_exists': userProfile != null,
          'role': userProfile?['role'],
          'status': userProfile?['status'],
        };
      } catch (e) {
        tests['auth_state_manager_profile'] = {
          'success': false,
          'error': e.toString(),
        };
      }

      // Test 4: AuthStateManager warehouse access check
      try {
        final hasAccess = await AuthStateManager.hasWarehouseAccess();
        tests['auth_state_manager_warehouse_access'] = {
          'success': true,
          'has_access': hasAccess,
        };
      } catch (e) {
        tests['auth_state_manager_warehouse_access'] = {
          'success': false,
          'error': e.toString(),
        };
      }

      return tests;
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Test warehouse data access
  static Future<Map<String, dynamic>> _testWarehouseAccess() async {
    try {
      AppLogger.info('🏢 اختبار الوصول لبيانات المخازن...');

      final tests = <String, dynamic>{};

      // Test 1: Warehouses table access
      tests['warehouses'] = await _testTableAccess('warehouses');

      // Test 2: Warehouse inventory table access
      tests['warehouse_inventory'] = await _testTableAccess('warehouse_inventory');

      // Test 3: Warehouse transactions table access
      tests['warehouse_transactions'] = await _testTableAccess('warehouse_transactions');

      // Test 4: Warehouse requests table access
      tests['warehouse_requests'] = await _testTableAccess('warehouse_requests');

      // Test 5: Warehouse request items table access (if exists)
      tests['warehouse_request_items'] = await _testTableAccess('warehouse_request_items');

      return tests;
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Test access to a specific table
  static Future<Map<String, dynamic>> _testTableAccess(String tableName) async {
    try {
      final startTime = DateTime.now();
      
      final response = await _supabase
          .from(tableName)
          .select('*')
          .limit(1);

      final endTime = DateTime.now();
      final duration = endTime.difference(startTime).inMilliseconds;

      return {
        'success': true,
        'accessible': true,
        'record_count': response.length,
        'response_time_ms': duration,
        'sample_data': response.isNotEmpty ? response.first : null,
      };
    } catch (e) {
      return {
        'success': false,
        'accessible': false,
        'error': e.toString(),
        'error_type': e.runtimeType.toString(),
      };
    }
  }

  /// Test RLS policies
  static Future<Map<String, dynamic>> _testRLSPolicies() async {
    try {
      AppLogger.info('🔒 اختبار سياسات RLS...');

      final tests = <String, dynamic>{};

      // Test RLS policy information query
      try {
        final policies = await _supabase
            .rpc('get_warehouse_policies'); // This would need to be a custom function

        tests['policy_query'] = {
          'success': true,
          'policies': policies,
        };
      } catch (e) {
        tests['policy_query'] = {
          'success': false,
          'error': e.toString(),
          'note': 'Custom RLS policy query function may not exist',
        };
      }

      // Test direct access patterns
      tests['direct_access_patterns'] = await _testDirectAccessPatterns();

      return tests;
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Test direct access patterns
  static Future<Map<String, dynamic>> _testDirectAccessPatterns() async {
    final patterns = <String, dynamic>{};

    // Pattern 1: Simple SELECT
    patterns['simple_select'] = await _testPattern(
      'Simple SELECT',
      () => _supabase.from('warehouses').select('id, name').limit(1),
    );

    // Pattern 2: SELECT with WHERE
    patterns['select_with_where'] = await _testPattern(
      'SELECT with WHERE',
      () => _supabase.from('warehouses').select('*').eq('is_active', true).limit(1),
    );

    // Pattern 3: JOIN query
    patterns['join_query'] = await _testPattern(
      'JOIN query',
      () => _supabase
          .from('warehouse_inventory')
          .select('*, warehouses(name)')
          .limit(1),
    );

    return patterns;
  }

  /// Test a specific access pattern
  static Future<Map<String, dynamic>> _testPattern(
    String patternName,
    Future<List<Map<String, dynamic>>> Function() testFunction,
  ) async {
    try {
      final startTime = DateTime.now();
      final result = await testFunction();
      final endTime = DateTime.now();

      return {
        'success': true,
        'pattern_name': patternName,
        'record_count': result.length,
        'response_time_ms': endTime.difference(startTime).inMilliseconds,
        'has_data': result.isNotEmpty,
      };
    } catch (e) {
      return {
        'success': false,
        'pattern_name': patternName,
        'error': e.toString(),
        'error_type': e.runtimeType.toString(),
      };
    }
  }

  /// Generate diagnostic summary
  static Map<String, dynamic> _generateSummary(Map<String, dynamic> results) {
    final summary = <String, dynamic>{
      'overall_status': 'unknown',
      'authentication_status': 'unknown',
      'warehouse_access_status': 'unknown',
      'issues_found': <String>[],
      'recommendations': <String>[],
    };

    // Analyze authentication
    final authTests = results['authentication_tests'] as Map<String, dynamic>?;
    if (authTests != null) {
      final hasAuth = authTests['supabase_current_user']?['user_exists'] == true;
      summary['authentication_status'] = hasAuth ? 'authenticated' : 'not_authenticated';
      
      if (!hasAuth) {
        summary['issues_found'].add('User not authenticated');
        summary['recommendations'].add('Ensure user is properly logged in');
      }
    }

    // Analyze warehouse access
    final warehouseTests = results['warehouse_access_tests'] as Map<String, dynamic>?;
    if (warehouseTests != null) {
      final accessibleTables = <String>[];
      final inaccessibleTables = <String>[];

      warehouseTests.forEach((tableName, testResult) {
        if (testResult is Map<String, dynamic>) {
          if (testResult['accessible'] == true) {
            accessibleTables.add(tableName);
          } else {
            inaccessibleTables.add(tableName);
          }
        }
      });

      if (inaccessibleTables.isEmpty) {
        summary['warehouse_access_status'] = 'full_access';
      } else if (accessibleTables.isEmpty) {
        summary['warehouse_access_status'] = 'no_access';
        summary['issues_found'].add('No warehouse table access');
        summary['recommendations'].add('Check RLS policies and user role permissions');
      } else {
        summary['warehouse_access_status'] = 'partial_access';
        summary['issues_found'].add('Partial warehouse access: ${inaccessibleTables.join(', ')} not accessible');
      }
    }

    // Overall status
    if (summary['authentication_status'] == 'authenticated' && 
        summary['warehouse_access_status'] == 'full_access') {
      summary['overall_status'] = 'healthy';
    } else {
      summary['overall_status'] = 'issues_detected';
    }

    return summary;
  }

  /// Check if user should have warehouse access based on role and status
  static bool _shouldHaveWarehouseAccess(String? role, String? status) {
    if (role == null || status == null) return false;
    
    final allowedRoles = ['admin', 'owner', 'accountant', 'warehouseManager'];
    final allowedStatuses = ['approved', 'active'];
    
    return allowedRoles.contains(role) && allowedStatuses.contains(status);
  }

  /// Quick access test for debugging
  static Future<bool> quickAccessTest() async {
    try {
      await _supabase.from('warehouses').select('id').limit(1);
      return true;
    } catch (e) {
      AppLogger.error('❌ Quick access test failed: $e');
      return false;
    }
  }
}
