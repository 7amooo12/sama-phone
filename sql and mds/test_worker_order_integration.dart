// Test file to verify worker order integration
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'lib/services/worker_order_service.dart';
import 'lib/widgets/worker/order_products_widget.dart';
import 'lib/models/worker_task_model.dart';

void main() {
  group('Worker Order Integration Tests', () {
    late WorkerOrderService orderService;
    
    setUp(() {
      orderService = WorkerOrderService();
    });

    test('should create WorkerTaskModel with orderId', () {
      final task = WorkerTaskModel(
        id: 'task_1',
        title: 'تحضير طلبية العميل أحمد',
        description: 'تحضير وتجهيز المنتجات للطلبية رقم 12345',
        assignedTo: 'worker_1',
        priority: TaskPriority.high,
        status: TaskStatus.assigned,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        category: 'طلبيات',
        location: 'المستودع الرئيسي',
        requirements: 'تحضير المنتجات وفقاً لقائمة الطلبية',
        orderId: '12345', // Order ID linked to task
      );

      expect(task.orderId, equals('12345'));
      expect(task.title, contains('طلبية'));
      expect(task.category, equals('طلبيات'));
    });

    test('should handle task without orderId', () {
      final task = WorkerTaskModel(
        id: 'task_2',
        title: 'صيانة المعدات',
        description: 'فحص وصيانة معدات المستودع',
        assignedTo: 'worker_1',
        priority: TaskPriority.medium,
        status: TaskStatus.assigned,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        category: 'صيانة',
        location: 'المستودع',
        requirements: 'فحص شامل للمعدات',
        // No orderId - this is not an order-related task
      );

      expect(task.orderId, isNull);
      expect(task.category, equals('صيانة'));
    });

    test('should convert task to JSON with orderId', () {
      final task = WorkerTaskModel(
        id: 'task_3',
        title: 'تحضير طلبية',
        assignedTo: 'worker_1',
        priority: TaskPriority.high,
        status: TaskStatus.assigned,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        orderId: '67890',
      );

      final json = task.toJson();
      expect(json['order_id'], equals('67890'));
      expect(json['title'], equals('تحضير طلبية'));
    });

    test('should create task from JSON with orderId', () {
      final json = {
        'id': 'task_4',
        'title': 'تحضير طلبية العميل محمد',
        'description': 'تحضير المنتجات للطلبية',
        'assigned_to': 'worker_2',
        'priority': 'high',
        'status': 'assigned',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'category': 'طلبيات',
        'location': 'المستودع',
        'requirements': 'تحضير المنتجات بعناية',
        'order_id': '11111',
      };

      final task = WorkerTaskModel.fromJson(json);
      expect(task.orderId, equals('11111'));
      expect(task.title, equals('تحضير طلبية العميل محمد'));
      expect(task.category, equals('طلبيات'));
    });

    testWidgets('OrderProductsWidget should display loading state', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrderProductsWidget(orderId: '12345'),
          ),
        ),
      );

      // Should show loading indicator initially
      expect(find.text('جاري تحميل تفاصيل الطلبية...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    test('should handle empty orderId gracefully', () async {
      final products = await orderService.getOrderProductsAndQuantities('');
      expect(products, isEmpty);
    });

    test('should handle invalid orderId gracefully', () async {
      final products = await orderService.getOrderProductsAndQuantities('invalid_id');
      expect(products, isEmpty);
    });
  });

  group('Order Service Tests', () {
    late WorkerOrderService orderService;
    
    setUp(() {
      orderService = WorkerOrderService();
    });

    test('should return false for non-existent order', () async {
      final exists = await orderService.orderExists('non_existent_order');
      expect(exists, isFalse);
    });

    test('should handle null order details gracefully', () async {
      final order = await orderService.getOrderDetails('null_order');
      expect(order, isNull);
    });

    test('should return empty list for order with no products', () async {
      final products = await orderService.getOrderProductsAndQuantities('empty_order');
      expect(products, isEmpty);
    });
  });
}

// Helper function to create test data
Map<String, dynamic> createTestOrderData() {
  return {
    'id': '12345',
    'order_number': 'ORD-2024-001',
    'customer_name': 'أحمد محمد',
    'customer_phone': '01234567890',
    'status': 'completed',
    'total_amount': 500.0,
    'created_at': DateTime.now().toIso8601String(),
    'items': [
      {
        'id': '1',
        'product_name': 'منتج أ',
        'quantity': 2,
        'price': 100.0,
        'subtotal': 200.0,
        'description': 'وصف المنتج أ',
      },
      {
        'id': '2',
        'product_name': 'منتج ب',
        'quantity': 3,
        'price': 100.0,
        'subtotal': 300.0,
        'description': 'وصف المنتج ب',
      },
    ],
  };
}

// Helper function to create test task with order
WorkerTaskModel createTestTaskWithOrder() {
  return WorkerTaskModel(
    id: 'test_task_1',
    title: 'تحضير طلبية العميل أحمد محمد',
    description: 'تحضير وتجهيز جميع المنتجات المطلوبة في الطلبية',
    assignedTo: 'worker_123',
    assignedBy: 'manager_456',
    priority: TaskPriority.high,
    status: TaskStatus.assigned,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    estimatedHours: 2,
    category: 'طلبيات العملاء',
    location: 'المستودع الرئيسي - الرف A',
    requirements: 'تحضير المنتجات وفقاً لقائمة الطلبية المرفقة، التأكد من جودة المنتجات قبل التعبئة',
    orderId: '12345', // This links the task to an order
    assignedToName: 'محمد العامل',
    assignedByName: 'أحمد المدير',
  );
}
