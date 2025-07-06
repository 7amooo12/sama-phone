import 'package:supabase_flutter/supabase_flutter.dart';
import 'logger.dart';

class DatabaseTest {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // Test credentials for admin user
  static const String _testAdminEmail = 'admin@smartbiztracker.com';
  static const String _testAdminPassword = 'admin123456';

  /// Authenticate as admin user for testing
  static Future<bool> _authenticateAsAdmin() async {
    try {
      AppLogger.info('🔐 Authenticating as admin for database tests...');

      // Check if already authenticated
      final currentUser = _supabase.auth.currentUser;
      if (currentUser != null) {
        AppLogger.info('✅ Already authenticated as: ${currentUser.email}');
        return true;
      }

      // Sign in as admin
      final response = await _supabase.auth.signInWithPassword(
        email: _testAdminEmail,
        password: _testAdminPassword,
      );

      if (response.user != null) {
        AppLogger.info('✅ Successfully authenticated as admin: ${response.user!.email}');
        return true;
      } else {
        AppLogger.error('❌ Authentication failed: No user returned');
        return false;
      }
    } catch (e) {
      AppLogger.error('❌ Authentication failed: $e');
      return false;
    }
  }

  /// Sign out after tests
  static Future<void> _signOut() async {
    try {
      await _supabase.auth.signOut();
      AppLogger.info('🔓 Signed out successfully');
    } catch (e) {
      AppLogger.error('Error signing out: $e');
    }
  }

  /// Test if we can connect to Supabase and check table existence
  static Future<void> testConnection() async {
    try {
      AppLogger.info('Testing Supabase connection...');

      // Test basic connection
      final response = await _supabase.rpc('version');
      AppLogger.info('Supabase connection successful. Version info: $response');

    } catch (e) {
      AppLogger.error('Supabase connection failed: $e');
    }
  }

  /// Test if tasks table exists and what columns it has
  static Future<void> testTasksTable() async {
    try {
      AppLogger.info('Testing tasks table...');

      // Try to query the table structure
      final response = await _supabase
          .from('tasks')
          .select('*')
          .limit(1);

      AppLogger.info('Tasks table exists and is accessible');
      AppLogger.info('Sample query response: $response');

    } catch (e) {
      AppLogger.error('Tasks table test failed: $e');

      if (e.toString().contains('404') || e.toString().contains('Not Found')) {
        AppLogger.error('Tasks table does not exist or is not accessible');
      } else if (e.toString().contains('relation') && e.toString().contains('does not exist')) {
        AppLogger.error('Tasks table does not exist in the database');
      }
    }
  }

  /// Test creating a simple task with authentication
  static Future<void> testTaskCreation() async {
    try {
      AppLogger.info('🧪 Testing task creation...');

      // First authenticate as admin
      final isAuthenticated = await _authenticateAsAdmin();
      if (!isAuthenticated) {
        AppLogger.error('❌ Cannot test task creation: Authentication failed');
        return;
      }

      // Get current user info for proper task assignment
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        AppLogger.error('❌ No authenticated user found');
        return;
      }

      AppLogger.info('📝 Creating test task with authenticated user: ${currentUser.email}');

      final testTask = {
        'title': 'Test Task - Database Test',
        'description': 'This is a test task created by database test suite',
        'status': 'pending',
        'assigned_to': currentUser.id, // Use current user ID
        'due_date': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'priority': 'medium',
        'attachments': [],
        'admin_name': 'Test Admin',
        'category': 'product',
        'quantity': 1,
        'completed_quantity': 0,
        'product_name': 'Test Product',
        'progress': 0.0,
        'deadline': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
        'worker_name': 'Test Worker',
        'admin_id': currentUser.id, // Use current user ID as admin
        'worker_id': currentUser.id, // Use current user ID as worker for testing
      };

      final response = await _supabase
          .from('tasks')
          .insert(testTask)
          .select()
          .single();

      AppLogger.info('✅ Test task created successfully: ${response['id']}');
      AppLogger.info('📋 Task details: ${response['title']} - Status: ${response['status']}');

      // Clean up - delete the test task
      await _supabase
          .from('tasks')
          .delete()
          .eq('id', response['id'] as String);

      AppLogger.info('🧹 Test task cleaned up successfully');

    } catch (e) {
      AppLogger.error('❌ Task creation test failed: $e');

      // Provide more detailed error information
      if (e.toString().contains('permission denied')) {
        AppLogger.error('🔒 Permission denied - RLS policy issue detected');
        AppLogger.error('💡 Suggestion: Check if user has admin role and approved status');
      } else if (e.toString().contains('42501')) {
        AppLogger.error('🔒 PostgreSQL permission error - RLS policies need review');
      }
    }
  }

  /// Test user profile and role verification
  static Future<void> testUserProfile() async {
    try {
      AppLogger.info('🧪 Testing user profile and role verification...');

      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        AppLogger.error('❌ No authenticated user for profile test');
        return;
      }

      // Get user profile
      final profileResponse = await _supabase
          .from('user_profiles')
          .select('*')
          .eq('id', currentUser.id)
          .single();

      AppLogger.info('✅ User profile found:');
      AppLogger.info('   - ID: ${profileResponse['id']}');
      AppLogger.info('   - Email: ${profileResponse['email']}');
      AppLogger.info('   - Role: ${profileResponse['role']}');
      AppLogger.info('   - Status: ${profileResponse['status']}');

      // Verify admin role for task creation
      if (profileResponse['role'] == 'admin' && profileResponse['status'] == 'approved') {
        AppLogger.info('✅ User has admin role and approved status - task creation should work');
      } else {
        AppLogger.error('⚠️ User does not have admin role or approved status');
        AppLogger.error('   Current role: ${profileResponse['role']}');
        AppLogger.error('   Current status: ${profileResponse['status']}');
      }

    } catch (e) {
      AppLogger.error('❌ User profile test failed: $e');
    }
  }

  /// Test RLS policies specifically
  static Future<void> testRLSPolicies() async {
    try {
      AppLogger.info('🔒 Testing RLS policies for tasks table...');

      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        AppLogger.error('❌ No authenticated user for RLS test');
        return;
      }

      // Test 1: Check if we can read from tasks table
      try {
        final readResponse = await _supabase
            .from('tasks')
            .select('id, title, status')
            .limit(5);

        AppLogger.info('✅ READ permission: Success - Found ${readResponse.length} tasks');
      } catch (e) {
        AppLogger.error('❌ READ permission: Failed - $e');
      }

      // Test 2: Check if we can insert into tasks table
      try {
        final insertTest = {
          'title': 'RLS Test Task',
          'description': 'Testing RLS policies',
          'status': 'pending',
          'assigned_to': currentUser.id,
          'admin_id': currentUser.id,
          'worker_id': currentUser.id,
          'priority': 'low',
          'category': 'test',
          'quantity': 1,
          'completed_quantity': 0,
          'progress': 0.0,
          'due_date': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
          'deadline': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
        };

        final insertResponse = await _supabase
            .from('tasks')
            .insert(insertTest)
            .select()
            .single();

        AppLogger.info('✅ INSERT permission: Success - Created task ${insertResponse['id']}');

        // Clean up the test task
        await _supabase
            .from('tasks')
            .delete()
            .eq('id', insertResponse['id'] as String);

        AppLogger.info('🧹 Cleaned up RLS test task');

      } catch (e) {
        AppLogger.error('❌ INSERT permission: Failed - $e');

        if (e.toString().contains('permission denied') || e.toString().contains('42501')) {
          AppLogger.error('🔒 RLS Policy Issue: User lacks INSERT permission');
          AppLogger.error('💡 Solution: Run the fix_tasks_rls_comprehensive.sql script');
        }
      }

    } catch (e) {
      AppLogger.error('❌ RLS policy test failed: $e');
    }
  }

  /// Run all tests with proper authentication flow
  static Future<void> runAllTests() async {
    AppLogger.info('🚀 Starting comprehensive database tests...');

    try {
      // Test 1: Basic connection
      await testConnection();

      // Test 2: Tasks table structure
      await testTasksTable();

      // Test 3: Authentication
      final isAuthenticated = await _authenticateAsAdmin();
      if (!isAuthenticated) {
        AppLogger.error('❌ Authentication failed - skipping authenticated tests');
        return;
      }

      // Test 4: User profile verification
      await testUserProfile();

      // Test 5: RLS policies verification
      await testRLSPolicies();

      // Test 6: Task creation (requires authentication)
      await testTaskCreation();

      AppLogger.info('✅ All database tests completed successfully');

    } catch (e) {
      AppLogger.error('❌ Database tests failed: $e');
    } finally {
      // Clean up - sign out
      await _signOut();
    }
  }
}
