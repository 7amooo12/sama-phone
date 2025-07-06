import 'package:flutter/material.dart';
import '../lib/services/supabase_service.dart';
import '../lib/utils/app_logger.dart';

/// Verification script to check email confirmation status and test authentication
class EmailFixVerification {
  static final SupabaseService _supabaseService = SupabaseService();

  /// Check the current status of the specific user
  static Future<void> checkUserStatus(String email) async {
    try {
      AppLogger.info('🔍 Checking status for user: $email');
      
      // Get user data from user_profiles table
      final userProfile = await _supabaseService.getUserDataByEmail(email);
      
      if (userProfile == null) {
        AppLogger.error('❌ User not found in user_profiles table: $email');
        return;
      }
      
      AppLogger.info('📋 User Profile Status:');
      AppLogger.info('   👤 Name: ${userProfile.name}');
      AppLogger.info('   📧 Email: ${userProfile.email}');
      AppLogger.info('   🔑 Role: ${userProfile.role}');
      AppLogger.info('   ✅ Status: ${userProfile.status}');
      AppLogger.info('   📬 Email Confirmed: ${userProfile.emailConfirmed ?? false}');
      AppLogger.info('   📅 Email Confirmed At: ${userProfile.emailConfirmedAt ?? 'Not set'}');
      AppLogger.info('   🆔 User ID: ${userProfile.id}');
      
      // Check if user should be able to login
      final shouldBeAbleToLogin = (userProfile.status == 'active' || userProfile.status == 'approved') 
                                  && userProfile.role != 'client';
      
      AppLogger.info('🎯 Should be able to login: $shouldBeAbleToLogin');
      
    } catch (e) {
      AppLogger.error('❌ Error checking user status: $e');
    }
  }

  /// Test the authentication bypass for admin-approved users
  static Future<void> testAuthenticationBypass(String email) async {
    try {
      AppLogger.info('🧪 Testing authentication bypass for: $email');
      
      // First check if user is admin-approved
      final userProfile = await _supabaseService.getUserDataByEmail(email);
      
      if (userProfile == null) {
        AppLogger.error('❌ User not found: $email');
        return;
      }
      
      if (userProfile.status != 'active' && userProfile.status != 'approved') {
        AppLogger.warning('⚠️ User is not approved: ${userProfile.status}');
        return;
      }
      
      if (userProfile.role == 'client') {
        AppLogger.info('ℹ️ User is a client - email confirmation bypass may not apply');
      }
      
      AppLogger.info('✅ User meets criteria for authentication bypass');
      AppLogger.info('   📧 Email: ${userProfile.email}');
      AppLogger.info('   🔑 Role: ${userProfile.role}');
      AppLogger.info('   ✅ Status: ${userProfile.status}');
      
      // Note: We can't test actual login without password
      AppLogger.info('💡 To test actual login, use: testLogin("$email", "actual_password")');
      
    } catch (e) {
      AppLogger.error('❌ Error testing authentication bypass: $e');
    }
  }

  /// Test actual login (requires password)
  static Future<void> testLogin(String email, String password) async {
    try {
      AppLogger.info('🔐 Testing actual login for: $email');
      
      final user = await _supabaseService.signIn(email, password);
      
      if (user != null) {
        AppLogger.info('🎉 LOGIN SUCCESSFUL!');
        AppLogger.info('   👤 User ID: ${user.id}');
        AppLogger.info('   📧 Email: ${user.email}');
        AppLogger.info('   ✅ Email Confirmed At: ${user.emailConfirmedAt ?? 'Not set'}');
        AppLogger.info('   🔑 User Metadata: ${user.userMetadata}');
        
        // Sign out after test
        await _supabaseService.signOut();
        AppLogger.info('🚪 Signed out after test');
        
      } else {
        AppLogger.error('❌ LOGIN FAILED - No user returned');
      }
      
    } catch (e) {
      AppLogger.error('❌ LOGIN ERROR: $e');
      
      // Check if it's still an email confirmation error
      if (e.toString().contains('Email not confirmed')) {
        AppLogger.error('🚨 STILL GETTING EMAIL CONFIRMATION ERROR!');
        AppLogger.error('💡 This means the fix did not work properly');
      }
    }
  }

  /// Check all approved users who might have email confirmation issues
  static Future<void> checkAllApprovedUsers() async {
    try {
      AppLogger.info('🔍 Checking all approved users...');
      
      // Get all approved/active users
      final allUsers = await _supabaseService.getAllUsers();
      final approvedUsers = allUsers.where((user) => 
        (user.status == 'active' || user.status == 'approved') && 
        user.role != 'client'
      ).toList();
      
      AppLogger.info('📊 Found ${approvedUsers.length} approved non-client users');
      
      for (final user in approvedUsers) {
        AppLogger.info('');
        AppLogger.info('👤 User: ${user.name} (${user.email})');
        AppLogger.info('   🔑 Role: ${user.role}');
        AppLogger.info('   ✅ Status: ${user.status}');
        AppLogger.info('   📬 Email Confirmed: ${user.emailConfirmed ?? false}');
        
        final hasEmailIssue = !(user.emailConfirmed ?? false);
        if (hasEmailIssue) {
          AppLogger.warning('   ⚠️ EMAIL CONFIRMATION ISSUE DETECTED');
        } else {
          AppLogger.info('   ✅ Email confirmation OK');
        }
      }
      
    } catch (e) {
      AppLogger.error('❌ Error checking approved users: $e');
    }
  }

  /// Apply fix to specific user
  static Future<void> applyFixToUser(String email) async {
    try {
      AppLogger.info('🔧 Applying fix to user: $email');
      
      final success = await _supabaseService.manuallyConfirmUserEmail(email);
      
      if (success) {
        AppLogger.info('✅ Fix applied successfully');
        
        // Verify the fix
        await checkUserStatus(email);
      } else {
        AppLogger.error('❌ Fix failed');
      }
      
    } catch (e) {
      AppLogger.error('❌ Error applying fix: $e');
    }
  }

  /// Main verification routine
  static Future<void> runFullVerification() async {
    try {
      AppLogger.info('🚀 Starting Full Email Confirmation Verification');
      AppLogger.info('=' * 60);
      
      const testEmail = 'tesz@sama.com';
      
      // Step 1: Check current status
      AppLogger.info('📋 STEP 1: Checking current user status');
      await checkUserStatus(testEmail);
      
      AppLogger.info('');
      
      // Step 2: Test authentication bypass logic
      AppLogger.info('📋 STEP 2: Testing authentication bypass logic');
      await testAuthenticationBypass(testEmail);
      
      AppLogger.info('');
      
      // Step 3: Check all approved users
      AppLogger.info('📋 STEP 3: Checking all approved users');
      await checkAllApprovedUsers();
      
      AppLogger.info('');
      
      // Step 4: Apply fix if needed
      AppLogger.info('📋 STEP 4: Applying fix to test user');
      await applyFixToUser(testEmail);
      
      AppLogger.info('');
      AppLogger.info('🎉 Verification completed!');
      AppLogger.info('💡 To test actual login, call:');
      AppLogger.info('   testLogin("$testEmail", "actual_password")');
      AppLogger.info('=' * 60);
      
    } catch (e) {
      AppLogger.error('❌ Verification failed: $e');
    }
  }
}

/// Usage:
/// 
/// ```dart
/// // Run full verification
/// await EmailFixVerification.runFullVerification();
/// 
/// // Test specific user login (with actual password)
/// await EmailFixVerification.testLogin('tesz@sama.com', 'actual_password');
/// 
/// // Check specific user status
/// await EmailFixVerification.checkUserStatus('tesz@sama.com');
/// ```
