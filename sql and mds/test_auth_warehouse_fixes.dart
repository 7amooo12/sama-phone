// 🧪 QUICK TEST FOR AUTHENTICATION & WAREHOUSE FIXES
// Run this to verify that the authentication and warehouse access issues are resolved

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'lib/services/auth_state_manager.dart';
import 'lib/services/auth_sync_service.dart';
import 'lib/services/warehouse_service.dart';
import 'lib/utils/app_logger.dart';

/// Quick test widget to verify fixes
class AuthWarehouseFixTest extends StatefulWidget {
  const AuthWarehouseFixTest({super.key});

  @override
  State<AuthWarehouseFixTest> createState() => _AuthWarehouseFixTestState();
}

class _AuthWarehouseFixTestState extends State<AuthWarehouseFixTest> {
  Map<String, dynamic>? _testResults;
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    // Auto-run test on widget creation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runQuickTest();
    });
  }

  /// Run quick test to verify fixes
  Future<void> _runQuickTest() async {
    setState(() {
      _isRunning = true;
      _testResults = null;
    });

    try {
      AppLogger.info('🧪 Running quick authentication & warehouse test...');
      
      final results = <String, dynamic>{
        'timestamp': DateTime.now().toIso8601String(),
        'tests': <String, dynamic>{},
      };

      // Test 1: Authentication State
      results['tests']['authentication'] = await _testAuthentication();
      
      // Test 2: Warehouse Access
      results['tests']['warehouse_access'] = await _testWarehouseAccess();
      
      // Test 3: Data Availability
      results['tests']['data_availability'] = await _testDataAvailability();
      
      // Generate summary
      results['summary'] = _generateQuickSummary(results['tests']);
      
      setState(() {
        _testResults = results;
        _isRunning = false;
      });
      
      AppLogger.info('✅ Quick test completed');
      
    } catch (e) {
      AppLogger.error('❌ Quick test failed: $e');
      setState(() {
        _testResults = {
          'error': e.toString(),
          'timestamp': DateTime.now().toIso8601String(),
        };
        _isRunning = false;
      });
    }
  }

  /// Test authentication state
  Future<Map<String, dynamic>> _testAuthentication() async {
    try {
      // Check Supabase auth
      final supabaseUser = Supabase.instance.client.auth.currentUser;
      final supabaseSession = Supabase.instance.client.auth.currentSession;
      
      // Check AuthStateManager
      final authStateUser = await AuthStateManager.getCurrentUser();
      final userProfile = await AuthStateManager.getCurrentUserProfile();
      
      // Check consistency
      final isConsistent = supabaseUser?.id == authStateUser?.id;
      
      return {
        'supabase_user_exists': supabaseUser != null,
        'supabase_session_exists': supabaseSession != null,
        'session_expired': supabaseSession?.isExpired ?? true,
        'auth_state_user_exists': authStateUser != null,
        'user_profile_exists': userProfile != null,
        'auth_consistent': isConsistent,
        'user_role': userProfile?['role'],
        'user_status': userProfile?['status'],
        'status': isConsistent ? 'PASS' : 'FAIL',
      };
    } catch (e) {
      return {
        'status': 'ERROR',
        'error': e.toString(),
      };
    }
  }

  /// Test warehouse access
  Future<Map<String, dynamic>> _testWarehouseAccess() async {
    try {
      // Test AuthStateManager warehouse access
      final authManagerAccess = await AuthStateManager.hasWarehouseAccess();
      
      // Test direct warehouse query
      final directQuery = await Supabase.instance.client
          .from('warehouses')
          .select('id, name')
          .limit(5);
      
      // Test warehouse service
      final warehouseService = WarehouseService();
      final warehouses = await warehouseService.getWarehouses(activeOnly: true);
      
      final allTestsPass = directQuery.isNotEmpty && warehouses.isNotEmpty;
      
      return {
        'auth_manager_access': authManagerAccess,
        'direct_query_count': directQuery.length,
        'service_warehouse_count': warehouses.length,
        'direct_query_works': directQuery.isNotEmpty,
        'service_works': warehouses.isNotEmpty,
        'all_access_methods_work': allTestsPass,
        'status': allTestsPass ? 'PASS' : 'FAIL',
      };
    } catch (e) {
      return {
        'status': 'ERROR',
        'error': e.toString(),
      };
    }
  }

  /// Test data availability for UI
  Future<Map<String, dynamic>> _testDataAvailability() async {
    try {
      final warehouseService = WarehouseService();
      final warehouses = await warehouseService.getWarehouses();
      
      final dataReady = warehouses.isNotEmpty;
      
      return {
        'warehouse_count': warehouses.length,
        'data_ready_for_ui': dataReady,
        'sample_warehouses': warehouses.take(3).map((w) => {
          'id': w.id,
          'name': w.name,
          'active': w.isActive,
        }).toList(),
        'status': dataReady ? 'PASS' : 'FAIL',
      };
    } catch (e) {
      return {
        'status': 'ERROR',
        'error': e.toString(),
      };
    }
  }

  /// Generate quick summary
  Map<String, dynamic> _generateQuickSummary(Map<String, dynamic> tests) {
    final authTest = tests['authentication'] as Map<String, dynamic>?;
    final warehouseTest = tests['warehouse_access'] as Map<String, dynamic>?;
    final dataTest = tests['data_availability'] as Map<String, dynamic>?;
    
    final authPass = authTest?['status'] == 'PASS';
    final warehousePass = warehouseTest?['status'] == 'PASS';
    final dataPass = dataTest?['status'] == 'PASS';
    
    final allPass = authPass && warehousePass && dataPass;
    
    return {
      'authentication_fixed': authPass,
      'warehouse_access_fixed': warehousePass,
      'data_availability_fixed': dataPass,
      'all_issues_resolved': allPass,
      'overall_status': allPass ? 'ALL_FIXED' : 'ISSUES_REMAIN',
      'user_role': authTest?['user_role'],
      'warehouse_count': dataTest?['warehouse_count'] ?? 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🧪 Auth & Warehouse Fix Test'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
      ),
      body: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🔧 Authentication & Warehouse Fix Verification',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This test verifies that the authentication state consistency and warehouse data visibility issues have been resolved.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Test Results
            Expanded(
              child: _isRunning
                  ? _buildLoadingState()
                  : _testResults != null
                      ? _buildTestResults()
                      : _buildInitialState(),
            ),
            
            // Action Buttons
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isRunning ? null : _runQuickTest,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Run Test Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                if (_testResults != null)
                  ElevatedButton.icon(
                    onPressed: () {
                      // Copy results to clipboard or show detailed view
                      _showDetailedResults();
                    },
                    icon: const Icon(Icons.info),
                    label: const Text('View Details'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Running authentication and warehouse tests...'),
        ],
      ),
    );
  }

  Widget _buildInitialState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.play_circle_outline, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('Ready to run tests'),
          SizedBox(height: 8),
          Text(
            'Click "Run Test Again" to start verification',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildTestResults() {
    if (_testResults!.containsKey('error')) {
      return _buildErrorState();
    }

    final summary = _testResults!['summary'] as Map<String, dynamic>?;
    final allFixed = summary?['all_issues_resolved'] == true;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall Status
          Card(
            color: allFixed ? Colors.green.shade50 : Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    allFixed ? Icons.check_circle : Icons.error,
                    color: allFixed ? Colors.green : Colors.red,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          allFixed ? '✅ All Issues Resolved!' : '❌ Issues Still Exist',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: allFixed ? Colors.green.shade800 : Colors.red.shade800,
                          ),
                        ),
                        Text(
                          'Status: ${summary?['overall_status'] ?? 'Unknown'}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Individual Test Results
          _buildTestCard('Authentication State', summary?['authentication_fixed'] == true),
          _buildTestCard('Warehouse Access', summary?['warehouse_access_fixed'] == true),
          _buildTestCard('Data Availability', summary?['data_availability_fixed'] == true),
          
          const SizedBox(height: 16),
          
          // Summary Info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Summary Information',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('User Role: ${summary?['user_role'] ?? 'Unknown'}'),
                  Text('Warehouses Available: ${summary?['warehouse_count'] ?? 0}'),
                  Text('Test Time: ${_testResults!['timestamp']}'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestCard(String title, bool passed) {
    return Card(
      child: ListTile(
        leading: Icon(
          passed ? Icons.check_circle : Icons.error,
          color: passed ? Colors.green : Colors.red,
        ),
        title: Text(title),
        subtitle: Text(passed ? 'Working correctly' : 'Issues detected'),
        trailing: Text(
          passed ? 'PASS' : 'FAIL',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: passed ? Colors.green : Colors.red,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error, color: Colors.red.shade800),
                const SizedBox(width: 8),
                Text(
                  'Test Error',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _testResults!['error'].toString(),
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetailedResults() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Detailed Test Results'),
        content: SingleChildScrollView(
          child: Text(
            _testResults.toString(),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
