import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_logger.dart';
import 'auth_state_manager.dart';

/// Service for diagnosing database connectivity and RLS policy issues
class DatabaseDiagnosticService {
  static final _supabase = Supabase.instance.client;

  /// Run comprehensive database diagnostics
  static Future<Map<String, dynamic>> runComprehensiveDiagnostics() async {
    final diagnostics = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'tests': <String, dynamic>{},
      'errors': <String>[],
      'summary': <String, dynamic>{},
    };

    AppLogger.info('🔍 Starting comprehensive database diagnostics...');

    // Test 1: Basic connectivity
    await _testBasicConnectivity(diagnostics);

    // Test 2: Authentication status
    await _testAuthenticationStatus(diagnostics);

    // Test 3: User profiles access
    await _testUserProfilesAccess(diagnostics);

    // Test 4: Warehouse tables access
    await _testWarehouseTablesAccess(diagnostics);

    // Test 5: Warehouse dispatch specific queries
    await _testWarehouseDispatchQueries(diagnostics);

    // Test 6: SECURITY DEFINER functions
    await _testSecurityDefinerFunctions(diagnostics);

    // Test 7: Critical Accountant Dashboard Issues
    await _testAccountantDashboardIssues(diagnostics);

    // Test 8: Wallet Transaction Constraints
    await _testWalletTransactionConstraints(diagnostics);

    // Test 9: Electronic Payment Validation
    await _testElectronicPaymentValidation(diagnostics);

    // Generate summary
    _generateDiagnosticSummary(diagnostics);

    AppLogger.info('✅ Database diagnostics completed');
    return diagnostics;
  }

  /// Test basic database connectivity
  static Future<void> _testBasicConnectivity(Map<String, dynamic> diagnostics) async {
    try {
      AppLogger.info('🔗 Testing basic database connectivity...');
      
      // Simple query to test connection
      final response = await _supabase.rpc('version');
      
      diagnostics['tests']['basic_connectivity'] = {
        'status': 'PASSED',
        'message': 'Database connection successful',
        'response': response,
      };
      
      AppLogger.info('✅ Basic connectivity test passed');
    } catch (e) {
      diagnostics['tests']['basic_connectivity'] = {
        'status': 'FAILED',
        'error': e.toString(),
      };
      diagnostics['errors'].add('Basic connectivity failed: $e');
      AppLogger.error('❌ Basic connectivity test failed: $e');
    }
  }

  /// Test authentication status
  static Future<void> _testAuthenticationStatus(Map<String, dynamic> diagnostics) async {
    try {
      AppLogger.info('🔐 Testing authentication status...');
      
      final user = _supabase.auth.currentUser;
      final isAuthenticated = user != null;
      
      diagnostics['tests']['authentication'] = {
        'status': isAuthenticated ? 'PASSED' : 'WARNING',
        'authenticated': isAuthenticated,
        'user_id': user?.id,
        'user_email': user?.email,
        'message': isAuthenticated ? 'User is authenticated' : 'User is not authenticated',
      };
      
      AppLogger.info('✅ Authentication test completed - Authenticated: $isAuthenticated');
    } catch (e) {
      diagnostics['tests']['authentication'] = {
        'status': 'FAILED',
        'error': e.toString(),
      };
      diagnostics['errors'].add('Authentication test failed: $e');
      AppLogger.error('❌ Authentication test failed: $e');
    }
  }

  /// Test user profiles table access
  static Future<void> _testUserProfilesAccess(Map<String, dynamic> diagnostics) async {
    try {
      AppLogger.info('👤 Testing user_profiles table access...');
      
      // Test basic count query
      final countResponse = await _supabase
          .from('user_profiles')
          .select('id')
          .count();
      
      diagnostics['tests']['user_profiles_access'] = {
        'status': 'PASSED',
        'message': 'user_profiles table accessible',
        'count': countResponse.count,
      };
      
      AppLogger.info('✅ user_profiles access test passed - Count: ${countResponse.count}');
    } catch (e) {
      diagnostics['tests']['user_profiles_access'] = {
        'status': 'FAILED',
        'error': e.toString(),
      };
      diagnostics['errors'].add('user_profiles access failed: $e');
      AppLogger.error('❌ user_profiles access test failed: $e');
    }
  }

  /// Test warehouse tables access
  static Future<void> _testWarehouseTablesAccess(Map<String, dynamic> diagnostics) async {
    final warehouseTables = ['warehouses', 'warehouse_inventory', 'warehouse_transactions'];
    
    for (final tableName in warehouseTables) {
      try {
        AppLogger.info('🏢 Testing $tableName table access...');
        
        final countResponse = await _supabase
            .from(tableName)
            .select('id')
            .count();
        
        diagnostics['tests']['${tableName}_access'] = {
          'status': 'PASSED',
          'message': '$tableName table accessible',
          'count': countResponse.count,
        };
        
        AppLogger.info('✅ $tableName access test passed - Count: ${countResponse.count}');
      } catch (e) {
        diagnostics['tests']['${tableName}_access'] = {
          'status': 'FAILED',
          'error': e.toString(),
        };
        diagnostics['errors'].add('$tableName access failed: $e');
        AppLogger.error('❌ $tableName access test failed: $e');
      }
    }
  }

  /// Test warehouse dispatch specific queries
  static Future<void> _testWarehouseDispatchQueries(Map<String, dynamic> diagnostics) async {
    // Test 1: warehouse_requests basic query
    try {
      AppLogger.info('📦 Testing warehouse_requests basic query...');
      
      final requestsResponse = await _supabase
          .from('warehouse_requests')
          .select('id')
          .count();
      
      diagnostics['tests']['warehouse_requests_basic'] = {
        'status': 'PASSED',
        'message': 'warehouse_requests basic query successful',
        'count': requestsResponse.count,
      };
      
      AppLogger.info('✅ warehouse_requests basic test passed - Count: ${requestsResponse.count}');
    } catch (e) {
      diagnostics['tests']['warehouse_requests_basic'] = {
        'status': 'FAILED',
        'error': e.toString(),
      };
      diagnostics['errors'].add('warehouse_requests basic query failed: $e');
      AppLogger.error('❌ warehouse_requests basic test failed: $e');
    }

    // Test 2: warehouse_request_items basic query
    try {
      AppLogger.info('📋 Testing warehouse_request_items basic query...');
      
      final itemsResponse = await _supabase
          .from('warehouse_request_items')
          .select('id')
          .count();
      
      diagnostics['tests']['warehouse_request_items_basic'] = {
        'status': 'PASSED',
        'message': 'warehouse_request_items basic query successful',
        'count': itemsResponse.count,
      };
      
      AppLogger.info('✅ warehouse_request_items basic test passed - Count: ${itemsResponse.count}');
    } catch (e) {
      diagnostics['tests']['warehouse_request_items_basic'] = {
        'status': 'FAILED',
        'error': e.toString(),
      };
      diagnostics['errors'].add('warehouse_request_items basic query failed: $e');
      AppLogger.error('❌ warehouse_request_items basic test failed: $e');
    }

    // Test 3: The exact Flutter query that was failing
    try {
      AppLogger.info('🔄 Testing exact Flutter warehouse dispatch query...');
      
      final response = await _supabase
          .from('warehouse_requests')
          .select('''
            *,
            warehouse_request_items (
              *
            )
          ''')
          .order('requested_at', ascending: false)
          .limit(5);
      
      diagnostics['tests']['flutter_dispatch_query'] = {
        'status': 'PASSED',
        'message': 'Flutter warehouse dispatch query successful',
        'count': (response as List).length,
      };
      
      AppLogger.info('✅ Flutter dispatch query test passed - Count: ${(response as List).length}');
    } catch (e) {
      diagnostics['tests']['flutter_dispatch_query'] = {
        'status': 'FAILED',
        'error': e.toString(),
      };
      diagnostics['errors'].add('Flutter dispatch query failed: $e');
      AppLogger.error('❌ Flutter dispatch query test failed: $e');
      
      // Check if it's the infinite recursion error
      if (e.toString().contains('infinite recursion')) {
        diagnostics['tests']['flutter_dispatch_query']['infinite_recursion_detected'] = true;
        AppLogger.error('🔍 INFINITE RECURSION ERROR DETECTED!');
      }
    }
  }

  /// Test SECURITY DEFINER functions
  static Future<void> _testSecurityDefinerFunctions(Map<String, dynamic> diagnostics) async {
    final functions = [
      'get_user_role_safe',
      'get_user_status_safe', 
      'check_warehouse_access_safe',
      'is_admin_safe',
      'is_owner_safe',
      'is_warehouse_manager_safe'
    ];
    
    for (final functionName in functions) {
      try {
        AppLogger.info('🔧 Testing SECURITY DEFINER function: $functionName...');
        
        final result = await _supabase.rpc(functionName);
        
        diagnostics['tests']['function_$functionName'] = {
          'status': 'PASSED',
          'message': 'Function $functionName executed successfully',
          'result': result,
        };
        
        AppLogger.info('✅ Function $functionName test passed - Result: $result');
      } catch (e) {
        diagnostics['tests']['function_$functionName'] = {
          'status': 'FAILED',
          'error': e.toString(),
        };
        diagnostics['errors'].add('Function $functionName failed: $e');
        AppLogger.error('❌ Function $functionName test failed: $e');
      }
    }
  }

  /// Generate diagnostic summary
  static void _generateDiagnosticSummary(Map<String, dynamic> diagnostics) {
    final tests = diagnostics['tests'] as Map<String, dynamic>;
    final errors = diagnostics['errors'] as List<String>;
    
    int passedCount = 0;
    int failedCount = 0;
    int warningCount = 0;
    
    for (final test in tests.values) {
      final status = test['status'] as String;
      switch (status) {
        case 'PASSED':
          passedCount++;
          break;
        case 'FAILED':
          failedCount++;
          break;
        case 'WARNING':
          warningCount++;
          break;
      }
    }
    
    diagnostics['summary'] = {
      'total_tests': tests.length,
      'passed': passedCount,
      'failed': failedCount,
      'warnings': warningCount,
      'error_count': errors.length,
      'overall_status': failedCount == 0 ? 'HEALTHY' : 'ISSUES_DETECTED',
    };
    
    AppLogger.info('📊 Diagnostic Summary:');
    AppLogger.info('   Total Tests: ${tests.length}');
    AppLogger.info('   Passed: $passedCount');
    AppLogger.info('   Failed: $failedCount');
    AppLogger.info('   Warnings: $warningCount');
    AppLogger.info('   Overall Status: ${diagnostics['summary']['overall_status']}');
  }
}
