import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_logger.dart';
import '../models/user_role.dart';

/// أداة اختبار تدفق تسجيل الدخول الشاملة
class LoginTestUtility {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// نتائج اختبار تسجيل الدخول
  static Future<LoginTestResults> runComprehensiveTest() async {
    final results = LoginTestResults();
    
    try {
      AppLogger.info('🚀 Starting comprehensive login test...');
      
      // 1. اختبار الاتصال بقاعدة البيانات
      results.connectionTest = await _testDatabaseConnection();
      
      // 2. اختبار المستخدمين المختلفين
      results.adminTest = await _testUserLogin('admin@smartbiztracker.com', 'admin123456', UserRole.admin);
      results.testUserTest = await _testUserLogin('testo@sama.com', 'password123', UserRole.user);
      results.pendingUserTest = await _testPendingUserLogin('pending@test.com', 'password123');
      
      // 3. اختبار حالات الخطأ
      results.invalidEmailTest = await _testInvalidLogin('invalid@email.com', 'wrongpassword');
      results.wrongPasswordTest = await _testInvalidLogin('admin@smartbiztracker.com', 'wrongpassword');
      
      // 4. حساب النتيجة الإجمالية
      results.overallSuccess = _calculateOverallSuccess(results);
      
      AppLogger.info('✅ Comprehensive login test completed');
      return results;
      
    } catch (e) {
      AppLogger.error('❌ Comprehensive login test failed: $e');
      results.error = e.toString();
      return results;
    }
  }

  /// اختبار الاتصال بقاعدة البيانات
  static Future<TestResult> _testDatabaseConnection() async {
    try {
      AppLogger.info('🔗 Testing database connection...');
      
      final response = await _supabase.rpc('version');
      
      return TestResult(
        success: true,
        message: 'Database connection successful',
        details: 'Version: $response',
      );
    } catch (e) {
      return TestResult(
        success: false,
        message: 'Database connection failed',
        details: e.toString(),
      );
    }
  }

  /// اختبار تسجيل دخول مستخدم عادي
  static Future<TestResult> _testUserLogin(String email, String password, UserRole expectedRole) async {
    try {
      AppLogger.info('👤 Testing login for: $email');
      
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        // التحقق من ملف المستخدم
        final userProfile = await _supabase
            .from('user_profiles')
            .select('*')
            .eq('id', response.user!.id)
            .maybeSingle();

        // تسجيل الخروج فوراً
        await _supabase.auth.signOut();

        if (userProfile != null) {
          final userRole = UserRole.fromString(userProfile['role'] ?? 'user');
          final isRoleCorrect = userRole == expectedRole;
          
          return TestResult(
            success: true,
            message: 'Login successful for $email',
            details: 'Role: ${userRole.displayName}, Status: ${userProfile['status']}, Role Match: $isRoleCorrect',
          );
        } else {
          return TestResult(
            success: false,
            message: 'Login successful but no profile found',
            details: 'User authenticated but profile missing in database',
          );
        }
      } else {
        return TestResult(
          success: false,
          message: 'Login failed for $email',
          details: 'No user returned from authentication',
        );
      }
    } catch (e) {
      return TestResult(
        success: false,
        message: 'Login test failed for $email',
        details: e.toString(),
      );
    }
  }

  /// اختبار تسجيل دخول مستخدم في انتظار الموافقة
  static Future<PendingUserTestResult> _testPendingUserLogin(String email, String password) async {
    try {
      AppLogger.info('⏳ Testing pending user login for: $email');
      
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        // التحقق من حالة المستخدم
        final userProfile = await _supabase
            .from('user_profiles')
            .select('*')
            .eq('id', response.user!.id)
            .maybeSingle();

        await _supabase.auth.signOut();

        if (userProfile != null) {
          final status = userProfile['status'] as String?;
          final shouldShowWaitingScreen = status == 'pending' || status == 'waiting_approval';
          
          return PendingUserTestResult(
            success: true,
            message: 'Pending user test completed',
            details: 'Status: $status',
            shouldShowWaitingScreen: shouldShowWaitingScreen,
            userStatus: status ?? 'unknown',
          );
        } else {
          return PendingUserTestResult(
            success: false,
            message: 'User authenticated but no profile found',
            details: 'Profile missing in database',
            shouldShowWaitingScreen: false,
            userStatus: 'no_profile',
          );
        }
      } else {
        return PendingUserTestResult(
          success: false,
          message: 'Authentication failed',
          details: 'Invalid credentials or user does not exist',
          shouldShowWaitingScreen: false,
          userStatus: 'auth_failed',
        );
      }
    } catch (e) {
      return PendingUserTestResult(
        success: false,
        message: 'Pending user test failed',
        details: e.toString(),
        shouldShowWaitingScreen: false,
        userStatus: 'error',
      );
    }
  }

  /// اختبار تسجيل دخول غير صحيح
  static Future<TestResult> _testInvalidLogin(String email, String password) async {
    try {
      AppLogger.info('❌ Testing invalid login for: $email');
      
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        await _supabase.auth.signOut();
        return TestResult(
          success: false,
          message: 'Invalid login test failed - login succeeded unexpectedly',
          details: 'Expected failure but got success for $email',
        );
      } else {
        return TestResult(
          success: true,
          message: 'Invalid login correctly rejected',
          details: 'Authentication properly failed for invalid credentials',
        );
      }
    } catch (e) {
      // في هذه الحالة، الخطأ متوقع
      return TestResult(
        success: true,
        message: 'Invalid login correctly rejected',
        details: 'Expected error: ${e.toString()}',
      );
    }
  }

  /// حساب النجاح الإجمالي
  static bool _calculateOverallSuccess(LoginTestResults results) {
    return results.connectionTest.success &&
           results.adminTest.success &&
           results.testUserTest.success &&
           results.invalidEmailTest.success &&
           results.wrongPasswordTest.success;
  }

  /// عرض نتائج الاختبار في dialog
  static void showTestResults(BuildContext context, LoginTestResults results) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              results.overallSuccess ? Icons.check_circle : Icons.error,
              color: results.overallSuccess ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            const Text('نتائج اختبار تسجيل الدخول'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTestResultTile('اتصال قاعدة البيانات', results.connectionTest),
              _buildTestResultTile('مدير النظام', results.adminTest),
              _buildTestResultTile('مستخدم تجريبي', results.testUserTest),
              _buildPendingTestResultTile('مستخدم معلق', results.pendingUserTest),
              _buildTestResultTile('بريد إلكتروني خاطئ', results.invalidEmailTest),
              _buildTestResultTile('كلمة مرور خاطئة', results.wrongPasswordTest),

              if (results.error != null) ...[
                const Divider(),
                Text(
                  'خطأ: ${results.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  /// بناء عنصر نتيجة الاختبار
  static Widget _buildTestResultTile(String title, TestResult result) {
    return ListTile(
      leading: Icon(
        result.success ? Icons.check_circle : Icons.error,
        color: result.success ? Colors.green : Colors.red,
        size: 20,
      ),
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(result.message),
          if (result.details.isNotEmpty)
            Text(
              result.details,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
        ],
      ),
      dense: true,
    );
  }

  /// بناء عنصر نتيجة اختبار المستخدم المعلق
  static Widget _buildPendingTestResultTile(String title, PendingUserTestResult result) {
    return ListTile(
      leading: Icon(
        result.success ? Icons.check_circle : Icons.error,
        color: result.success ? Colors.green : Colors.red,
        size: 20,
      ),
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(result.message),
          Text('الحالة: ${result.userStatus}'),
          Text('عرض شاشة الانتظار: ${result.shouldShowWaitingScreen ? 'نعم' : 'لا'}'),
          if (result.details.isNotEmpty)
            Text(
              result.details,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
        ],
      ),
      dense: true,
    );
  }

  /// اختبار تسجيل دخول مستخدم معلق (للاستخدام الخارجي)
  static Future<PendingUserTestResult> testPendingUserLogin(String email, String password) async {
    return await _testPendingUserLogin(email, password);
  }
}

/// نتيجة اختبار واحد
class TestResult {

  TestResult({
    required this.success,
    required this.message,
    this.details = '',
  });
  final bool success;
  final String message;
  final String details;
}

/// نتيجة اختبار مستخدم معلق
class PendingUserTestResult extends TestResult {

  PendingUserTestResult({
    required super.success,
    required super.message,
    required this.shouldShowWaitingScreen,
    required this.userStatus,
    super.details,
  });
  final bool shouldShowWaitingScreen;
  final String userStatus;
}

/// نتائج الاختبار الشاملة
class LoginTestResults {
  TestResult connectionTest = TestResult(success: false, message: 'Not tested');
  TestResult adminTest = TestResult(success: false, message: 'Not tested');
  TestResult testUserTest = TestResult(success: false, message: 'Not tested');
  PendingUserTestResult pendingUserTest = PendingUserTestResult(
    success: false, 
    message: 'Not tested',
    shouldShowWaitingScreen: false,
    userStatus: 'not_tested',
  );
  TestResult invalidEmailTest = TestResult(success: false, message: 'Not tested');
  TestResult wrongPasswordTest = TestResult(success: false, message: 'Not tested');
  
  bool overallSuccess = false;
  String? error;
}
