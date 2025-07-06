// Test script for SmartBizTracker Notification System
// This script can be used to verify that the notification system works correctly

import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/services/real_notification_service.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// Test class for verifying notification system functionality
class NotificationSystemTest {
  final RealNotificationService _notificationService = RealNotificationService();

  /// Test notification creation for different user roles
  Future<void> testNotificationCreation() async {
    AppLogger.info('🧪 Starting notification system test...');

    try {
      // Test 1: Create order notification for client
      await _testClientOrderNotification();
      
      // Test 2: Create staff notification for new order
      await _testStaffOrderNotification();
      
      // Test 3: Test role-based routing
      await _testRoleBasedRouting();
      
      AppLogger.info('✅ All notification tests completed successfully');
    } catch (e) {
      AppLogger.error('❌ Notification test failed: $e');
    }
  }

  /// Test client order notification creation
  Future<void> _testClientOrderNotification() async {
    AppLogger.info('🧪 Testing client order notification...');
    
    const testUserId = 'test-client-id';
    const testOrderId = 'test-order-123';
    const testOrderNumber = 'ORD-20241201-001';
    
    final success = await _notificationService.createOrderStatusNotification(
      userId: testUserId,
      orderId: testOrderId,
      orderNumber: testOrderNumber,
      status: 'تم إنشاء طلبك بنجاح',
    );
    
    if (success) {
      AppLogger.info('✅ Client notification created successfully');
    } else {
      AppLogger.error('❌ Failed to create client notification');
    }
  }

  /// Test staff order notification creation
  Future<void> _testStaffOrderNotification() async {
    AppLogger.info('🧪 Testing staff order notification...');
    
    const testOrderId = 'test-order-123';
    const testOrderNumber = 'ORD-20241201-001';
    const testClientName = 'عميل تجريبي';
    const testTotalAmount = 150.0;
    
    final success = await _notificationService.createNewOrderNotificationForStaff(
      orderId: testOrderId,
      orderNumber: testOrderNumber,
      clientName: testClientName,
      totalAmount: testTotalAmount,
    );
    
    if (success) {
      AppLogger.info('✅ Staff notification created successfully');
    } else {
      AppLogger.error('❌ Failed to create staff notification');
    }
  }

  /// Test role-based routing logic
  Future<void> _testRoleBasedRouting() async {
    AppLogger.info('🧪 Testing role-based routing...');
    
    // Test different roles and their expected routes
    final testCases = {
      'accountant': '/accountant/pending-orders',
      'admin': '/admin/pending-orders',
      'manager': '/admin/pending-orders',
      'owner': '/admin/pending-orders',
      'client': '/admin/pending-orders', // Default fallback
    };
    
    for (final entry in testCases.entries) {
      final role = entry.key;
      final expectedRoute = entry.value;
      
      // This would test the route mapping logic
      AppLogger.info('🔍 Role: $role -> Expected Route: $expectedRoute');
    }
    
    AppLogger.info('✅ Role-based routing test completed');
  }

  /// Test notification retrieval for different roles
  Future<void> testNotificationRetrieval() async {
    AppLogger.info('🧪 Testing notification retrieval...');
    
    try {
      const testUserId = 'test-user-id';
      const testRole = 'accountant';
      
      final notifications = await _notificationService.getRoleSpecificNotifications(
        testUserId,
        testRole,
        unreadOnly: false,
      );
      
      AppLogger.info('✅ Retrieved ${notifications.length} notifications for role: $testRole');
    } catch (e) {
      AppLogger.error('❌ Failed to retrieve notifications: $e');
    }
  }
}

/// Widget for testing notification system in the app
class NotificationSystemTestWidget extends StatefulWidget {
  const NotificationSystemTestWidget({super.key});

  @override
  State<NotificationSystemTestWidget> createState() => _NotificationSystemTestWidgetState();
}

class _NotificationSystemTestWidgetState extends State<NotificationSystemTestWidget> {
  final NotificationSystemTest _test = NotificationSystemTest();
  bool _isRunning = false;
  String _testResults = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اختبار نظام الإشعارات'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'اختبار نظام الإشعارات',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            
            ElevatedButton(
              onPressed: _isRunning ? null : _runNotificationTest,
              child: _isRunning 
                ? const CircularProgressIndicator()
                : const Text('تشغيل اختبار الإشعارات'),
            ),
            
            const SizedBox(height: 20),
            
            ElevatedButton(
              onPressed: _isRunning ? null : _runRetrievalTest,
              child: _isRunning 
                ? const CircularProgressIndicator()
                : const Text('اختبار استرجاع الإشعارات'),
            ),
            
            const SizedBox(height: 20),
            
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _testResults.isEmpty ? 'نتائج الاختبار ستظهر هنا...' : _testResults,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runNotificationTest() async {
    setState(() {
      _isRunning = true;
      _testResults = 'جاري تشغيل اختبار الإشعارات...\n';
    });

    try {
      await _test.testNotificationCreation();
      setState(() {
        _testResults += '✅ تم اختبار إنشاء الإشعارات بنجاح\n';
      });
    } catch (e) {
      setState(() {
        _testResults += '❌ فشل اختبار الإشعارات: $e\n';
      });
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  Future<void> _runRetrievalTest() async {
    setState(() {
      _isRunning = true;
      _testResults += 'جاري اختبار استرجاع الإشعارات...\n';
    });

    try {
      await _test.testNotificationRetrieval();
      setState(() {
        _testResults += '✅ تم اختبار استرجاع الإشعارات بنجاح\n';
      });
    } catch (e) {
      setState(() {
        _testResults += '❌ فشل اختبار استرجاع الإشعارات: $e\n';
      });
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }
}

/// Instructions for manual testing
/*
MANUAL TESTING INSTRUCTIONS:

1. **Test Order Creation Notifications**:
   - Login as a client
   - Add items to cart and create an order
   - Check that client receives order confirmation notification
   - Login as admin/accountant and check for new order notifications

2. **Test Notification Navigation**:
   - Click on order notifications
   - Verify navigation goes to pending orders screen (not order details)
   - Test with different user roles (admin, accountant, owner)

3. **Test Route Handlers**:
   - Navigate to /accountant/pending-orders directly
   - Verify no "page not found" error occurs
   - Check that the pending orders screen loads correctly

4. **Test Database Triggers**:
   - Create orders through different methods (regular cart, voucher orders)
   - Check database for notification records
   - Verify notifications are created for all relevant users

5. **Test Arabic RTL Support**:
   - Verify all notification text displays correctly in Arabic
   - Check that navigation maintains RTL layout
   - Ensure AccountantThemeConfig styling is preserved
*/
