import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/models/warehouse_dispatch_model.dart';
import 'package:smartbiztracker_new/models/dispatch_product_processing_model.dart';
import 'package:smartbiztracker_new/screens/warehouse/interactive_dispatch_processing_screen.dart';
import 'package:smartbiztracker_new/providers/warehouse_dispatch_provider.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:smartbiztracker_new/widgets/warehouse/dispatch_product_processing_card.dart';

/// اختبار شاشة المعالجة التفاعلية لطلبات الصرف
/// يتحقق من صحة عمل الواجهة والتفاعلات
void main() {
  group('Interactive Dispatch Processing Tests', () {
    late WarehouseDispatchModel testDispatch;
    late List<WarehouseDispatchItemModel> testItems;

    setUp(() {
      // إنشاء بيانات اختبار
      testItems = [
        WarehouseDispatchItemModel(
          id: 'item1',
          requestId: 'request1',
          productId: 'product1',
          quantity: 5,
          notes: 'منتج اختبار 1',
        ),
        WarehouseDispatchItemModel(
          id: 'item2',
          requestId: 'request1',
          productId: 'product2',
          quantity: 3,
          notes: 'منتج اختبار 2',
        ),
      ];

      testDispatch = WarehouseDispatchModel(
        id: 'request1',
        requestNumber: 'REQ-001',
        type: 'withdrawal',
        status: 'processing',
        reason: 'طلب اختبار',
        requestedBy: 'user1',
        requestedAt: DateTime.now(),
        items: testItems,
      );
    });

    testWidgets('should display processing screen with products', (WidgetTester tester) async {
      // إنشاء مزودات وهمية
      final mockDispatchProvider = MockWarehouseDispatchProvider();
      final mockSupabaseProvider = MockSupabaseProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<WarehouseDispatchProvider>.value(
                value: mockDispatchProvider,
              ),
              ChangeNotifierProvider<SupabaseProvider>.value(
                value: mockSupabaseProvider,
              ),
            ],
            child: InteractiveDispatchProcessingScreen(dispatch: testDispatch),
          ),
        ),
      );

      // انتظار بناء الواجهة
      await tester.pumpAndSettle();

      // التحقق من وجود العناصر الأساسية
      expect(find.text('معالجة طلب الصرف'), findsOneWidget);
      expect(find.text('REQ-001'), findsOneWidget);
      expect(find.text('تقدم المعالجة'), findsOneWidget);
    });

    testWidgets('should show product cards for each item', (WidgetTester tester) async {
      final mockDispatchProvider = MockWarehouseDispatchProvider();
      final mockSupabaseProvider = MockSupabaseProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<WarehouseDispatchProvider>.value(
                value: mockDispatchProvider,
              ),
              ChangeNotifierProvider<SupabaseProvider>.value(
                value: mockSupabaseProvider,
              ),
            ],
            child: InteractiveDispatchProcessingScreen(dispatch: testDispatch),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // التحقق من وجود بطاقات المنتجات
      expect(find.byType(DispatchProductProcessingCard), findsNWidgets(testItems.length));
    });

    test('should create processing models from dispatch items', () {
      // اختبار إنشاء نماذج المعالجة
      final processingModel = DispatchProductProcessingModel.fromDispatchItem(
        itemId: testItems[0].id,
        requestId: testItems[0].requestId,
        productId: testItems[0].productId,
        productName: 'منتج اختبار',
        quantity: testItems[0].quantity,
        notes: testItems[0].notes,
      );

      expect(processingModel.id, equals(testItems[0].id));
      expect(processingModel.productId, equals(testItems[0].productId));
      expect(processingModel.requestedQuantity, equals(testItems[0].quantity));
      expect(processingModel.isCompleted, isFalse);
      expect(processingModel.progress, equals(0.0));
    });

    test('should handle product completion correctly', () {
      final processingModel = DispatchProductProcessingModel.fromDispatchItem(
        itemId: 'item1',
        requestId: 'request1',
        productId: 'product1',
        productName: 'منتج اختبار',
        quantity: 5,
      );

      // بدء المعالجة
      final processingModel2 = processingModel.startProcessing();
      expect(processingModel2.isProcessing, isTrue);
      expect(processingModel2.progress, equals(0.1));

      // إكمال المعالجة
      final completedModel = processingModel2.complete(completedBy: 'user1');
      expect(completedModel.isCompleted, isTrue);
      expect(completedModel.progress, equals(1.0));
      expect(completedModel.isProcessing, isFalse);
      expect(completedModel.completedBy, equals('user1'));
      expect(completedModel.completedAt, isNotNull);
    });

    test('should calculate overall progress correctly', () {
      final products = [
        DispatchProductProcessingModel.fromDispatchItem(
          itemId: 'item1',
          requestId: 'request1',
          productId: 'product1',
          productName: 'منتج 1',
          quantity: 5,
        ).complete(completedBy: 'user1'), // مكتمل (1.0)
        
        DispatchProductProcessingModel.fromDispatchItem(
          itemId: 'item2',
          requestId: 'request1',
          productId: 'product2',
          productName: 'منتج 2',
          quantity: 3,
        ).updateProgress(0.5), // نصف مكتمل (0.5)
      ];

      final collection = DispatchProcessingCollection(
        requestId: 'request1',
        products: products,
      );

      expect(collection.completedCount, equals(1));
      expect(collection.totalCount, equals(2));
      expect(collection.overallProgress, equals(0.75)); // (1.0 + 0.5) / 2
      expect(collection.isAllCompleted, isFalse);
    });

    test('should detect when all products are completed', () {
      final products = [
        DispatchProductProcessingModel.fromDispatchItem(
          itemId: 'item1',
          requestId: 'request1',
          productId: 'product1',
          productName: 'منتج 1',
          quantity: 5,
        ).complete(completedBy: 'user1'),
        
        DispatchProductProcessingModel.fromDispatchItem(
          itemId: 'item2',
          requestId: 'request1',
          productId: 'product2',
          productName: 'منتج 2',
          quantity: 3,
        ).complete(completedBy: 'user1'),
      ];

      final collection = DispatchProcessingCollection(
        requestId: 'request1',
        products: products,
      );

      expect(collection.isAllCompleted, isTrue);
      expect(collection.overallProgress, equals(1.0));
      expect(collection.completedCount, equals(2));
    });
  });
}

/// مزود وهمي لطلبات الصرف للاختبار
class MockWarehouseDispatchProvider extends ChangeNotifier implements WarehouseDispatchProvider {
  @override
  List<WarehouseDispatchModel> get dispatchRequests => [];

  @override
  List<WarehouseDispatchModel> get filteredRequests => [];

  @override
  bool get isLoading => false;

  @override
  String? get errorMessage => null;

  @override
  bool get hasError => false;

  @override
  Future<bool> updateDispatchStatus({
    required String requestId,
    required String newStatus,
    required String updatedBy,
    String? notes,
  }) async {
    return true;
  }

  @override
  Future<void> loadDispatchRequests({bool forceRefresh = false}) async {}

  @override
  void setSearchQuery(String query) {}

  @override
  void setStatusFilter(String status) {}

  @override
  Map<String, int> getRequestsStats() => {};

  @override
  Future<bool> clearAllDispatchRequests() async => true;
}

/// مزود وهمي لـ Supabase للاختبار
class MockSupabaseProvider extends ChangeNotifier implements SupabaseProvider {
  @override
  dynamic get user => MockUser();

  @override
  bool get isAuthenticated => true;

  @override
  bool get isLoading => false;

  @override
  String? get errorMessage => null;
}

/// مستخدم وهمي للاختبار
class MockUser {
  String get id => 'test-user-id';
  String get name => 'مستخدم اختبار';
  String get email => 'test@example.com';
}
