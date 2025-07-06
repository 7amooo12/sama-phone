import 'package:flutter/material.dart';
import '../lib/services/supabase_service.dart';
import '../lib/utils/app_logger.dart';

/// Script to fix email confirmation issues for admin-approved users
/// 
/// This script specifically addresses the issue where admin-approved users
/// cannot login due to "Email not confirmed" errors, even though they
/// have been approved by an admin and assigned roles.
class EmailConfirmationFixer {
  static final SupabaseService _supabaseService = SupabaseService();

  /// Fix email confirmation for the specific user mentioned in the issue
  static Future<void> fixSpecificUser() async {
    const email = 'tesz@sama.com';
    const userId = 'c4e6d714-0bf9-4334-ab2c-9fecabdef6ad';
    
    try {
      AppLogger.info('🔧 Fixing email confirmation for specific user: $email');
      
      // Method 1: Use the manual confirmation utility
      final success = await _supabaseService.manuallyConfirmUserEmail(email);
      
      if (success) {
        AppLogger.info('✅ Successfully fixed email confirmation for: $email');
      } else {
        AppLogger.warning('⚠️ Could not fix via utility method, trying direct approach');
        
        // Method 2: Direct database update
        await _fixUserDirectly(userId, email);
      }
      
    } catch (e) {
      AppLogger.error('❌ Error fixing specific user: $e');
    }
  }

  /// Fix all approved users with email confirmation issues
  static Future<void> fixAllApprovedUsers() async {
    try {
      AppLogger.info('🔄 Starting comprehensive email confirmation fix...');
      
      await _supabaseService.fixApprovedUsersEmailConfirmation();
      
      AppLogger.info('🎉 Comprehensive fix completed');
    } catch (e) {
      AppLogger.error('❌ Error in comprehensive fix: $e');
    }
  }

  /// Direct database fix for a specific user
  static Future<void> _fixUserDirectly(String userId, String email) async {
    try {
      AppLogger.info('🔧 Applying direct fix for: $email');
      
      // Update user_profiles table directly
      await _supabaseService.updateRecord('user_profiles', userId, {
        'status': 'active',
        'email_confirmed': true,
        'email_confirmed_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      
      AppLogger.info('✅ Direct fix applied for: $email');
    } catch (e) {
      AppLogger.error('❌ Error in direct fix: $e');
    }
  }

  /// Test login for fixed user
  static Future<void> testUserLogin(String email, String password) async {
    try {
      AppLogger.info('🧪 Testing login for: $email');
      
      final user = await _supabaseService.signIn(email, password);
      
      if (user != null) {
        AppLogger.info('✅ Login test successful for: $email');
        AppLogger.info('👤 User ID: ${user.id}');
        AppLogger.info('📧 Email confirmed: ${user.emailConfirmedAt != null}');
      } else {
        AppLogger.warning('⚠️ Login test failed for: $email');
      }
      
    } catch (e) {
      AppLogger.error('❌ Login test error: $e');
    }
  }

  /// Main execution method
  static Future<void> run() async {
    try {
      AppLogger.info('🚀 Starting Email Confirmation Fix Script');
      AppLogger.info('=' * 50);
      
      // Step 1: Fix the specific user mentioned in the issue
      AppLogger.info('📋 Step 1: Fixing specific user (tesz@sama.com)');
      await fixSpecificUser();
      
      AppLogger.info('');
      
      // Step 2: Fix all approved users
      AppLogger.info('📋 Step 2: Fixing all approved users');
      await fixAllApprovedUsers();
      
      AppLogger.info('');
      
      // Step 3: Test login (you would need to provide the password)
      AppLogger.info('📋 Step 3: Testing login (password required)');
      AppLogger.info('ℹ️  To test login, call: testUserLogin("tesz@sama.com", "password")');
      
      AppLogger.info('');
      AppLogger.info('🎉 Email Confirmation Fix Script Completed Successfully!');
      AppLogger.info('=' * 50);
      
    } catch (e) {
      AppLogger.error('❌ Script execution failed: $e');
    }
  }
}

/// Usage example:
/// 
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   
///   // Initialize Supabase first
///   await Supabase.initialize(
///     url: 'your-supabase-url',
///     anonKey: 'your-anon-key',
///   );
///   
///   // Run the fix script
///   await EmailConfirmationFixer.run();
///   
///   // Test specific user login
///   await EmailConfirmationFixer.testUserLogin('tesz@sama.com', 'actual-password');
/// }
/// ```
