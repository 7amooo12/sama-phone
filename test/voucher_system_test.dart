import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/providers/voucher_cart_provider.dart';
import 'package:smartbiztracker_new/models/voucher_model.dart';
import 'package:smartbiztracker_new/models/product_model.dart';

void main() {
  group('Voucher Shopping System Tests', () {
    late VoucherCartProvider voucherCartProvider;
    late VoucherModel testVoucher;
    late ProductModel testProduct;

    setUp(() {
      voucherCartProvider = VoucherCartProvider();
      
      // Create test voucher
      testVoucher = VoucherModel(
        id: 'test-voucher-1',
        name: 'عيد سعيد',
        code: 'HAPPY-HOLIDAY',
        description: 'خصم عيد سعيد على الملابس',
        discountPercentage: 20,
        type: VoucherType.category,
        targetId: 'كلبس',
        targetName: 'كلبس',
        isActive: true,
        expirationDate: DateTime.now().add(const Duration(days: 30)),
        createdBy: 'test-user',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Create test product
      testProduct = ProductModel(
        id: 'test-product-1',
        name: 'قميص قطني',
        description: 'قميص قطني عالي الجودة',
        price: 100.0,
        category: 'كلبس',
        quantity: 50, // Using quantity instead of stockQuantity
        sku: 'SHIRT-001',
        reorderPoint: 10,
        images: ['https://example.com/shirt.jpg'],
        isActive: true,
        createdAt: DateTime.now(),
      );
    });

    testWidgets('VoucherCartProvider should be available in widget tree', (WidgetTester tester) async {
      bool providerFound = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<VoucherCartProvider>(
                create: (_) => VoucherCartProvider(),
              ),
            ],
            child: Builder(
              builder: (context) {
                try {
                  Provider.of<VoucherCartProvider>(context, listen: false);
                  providerFound = true;
                } catch (e) {
                  providerFound = false;
                }
                return const Scaffold(
                  body: Text('Test Widget'),
                );
              },
            ),
          ),
        ),
      );

      expect(providerFound, isTrue, reason: 'VoucherCartProvider should be available in widget tree');
    });

    test('VoucherCartProvider should initialize empty', () {
      expect(voucherCartProvider.isEmpty, isTrue);
      expect(voucherCartProvider.itemCount, equals(0));
      expect(voucherCartProvider.totalQuantity, equals(0));
      expect(voucherCartProvider.appliedVoucher, isNull);
    });

    test('VoucherCartProvider should set voucher correctly', () {
      voucherCartProvider.setVoucher(testVoucher);
      
      expect(voucherCartProvider.appliedVoucher, equals(testVoucher));
      expect(voucherCartProvider.discountPercentage, equals(20.0));
    });

    test('VoucherCartProvider should add products to cart with discount', () {
      // Set voucher first
      voucherCartProvider.setVoucher(testVoucher);
      
      // Add product to voucher cart
      voucherCartProvider.addToVoucherCart(testProduct, 2);
      
      expect(voucherCartProvider.isEmpty, isFalse);
      expect(voucherCartProvider.itemCount, equals(1));
      expect(voucherCartProvider.totalQuantity, equals(2));
      
      // Check pricing calculations
      expect(voucherCartProvider.totalOriginalPrice, equals(200.0)); // 100 * 2
      expect(voucherCartProvider.totalDiscountedPrice, equals(160.0)); // 200 * 0.8 (20% discount)
      expect(voucherCartProvider.totalSavings, equals(40.0)); // 200 - 160
    });

    test('VoucherCartProvider should update item quantities', () {
      voucherCartProvider.setVoucher(testVoucher);
      voucherCartProvider.addToVoucherCart(testProduct, 1);
      
      // Update quantity
      voucherCartProvider.updateVoucherCartItemQuantity(testProduct.id, 3);
      
      expect(voucherCartProvider.totalQuantity, equals(3));
      expect(voucherCartProvider.totalOriginalPrice, equals(300.0)); // 100 * 3
      expect(voucherCartProvider.totalDiscountedPrice, equals(240.0)); // 300 * 0.8
    });

    test('VoucherCartProvider should remove items from cart', () {
      voucherCartProvider.setVoucher(testVoucher);
      voucherCartProvider.addToVoucherCart(testProduct, 2);
      
      // Remove item
      voucherCartProvider.removeFromVoucherCart(testProduct.id);
      
      expect(voucherCartProvider.isEmpty, isTrue);
      expect(voucherCartProvider.itemCount, equals(0));
      expect(voucherCartProvider.totalQuantity, equals(0));
    });

    test('VoucherCartProvider should clear cart', () {
      voucherCartProvider.setVoucher(testVoucher);
      voucherCartProvider.addToVoucherCart(testProduct, 2);
      
      // Clear cart
      voucherCartProvider.clearVoucherCart();
      
      expect(voucherCartProvider.isEmpty, isTrue);
      expect(voucherCartProvider.appliedVoucher, isNull);
      expect(voucherCartProvider.itemCount, equals(0));
    });

    test('VoucherCartProvider should check product eligibility', () {
      voucherCartProvider.setVoucher(testVoucher);
      
      // Test eligible product (same category)
      expect(voucherCartProvider.isProductInVoucherCart(testProduct.id), isFalse);
      
      // Add product and check
      voucherCartProvider.addToVoucherCart(testProduct, 1);
      expect(voucherCartProvider.isProductInVoucherCart(testProduct.id), isTrue);
      expect(voucherCartProvider.getVoucherCartProductQuantity(testProduct.id), equals(1));
    });

    test('VoucherCartProvider should generate cart summary', () {
      voucherCartProvider.setVoucher(testVoucher);
      voucherCartProvider.addToVoucherCart(testProduct, 2);
      
      final summary = voucherCartProvider.getVoucherCartSummary();
      
      expect(summary['voucher'], isNotNull);
      expect(summary['cartItems'], isA<List>());
      expect(summary['totalOriginalPrice'], equals(200.0));
      expect(summary['totalDiscountedPrice'], equals(160.0));
      expect(summary['totalSavings'], equals(40.0));
      expect(summary['discountPercentage'], equals(20.0));
      expect(summary['itemCount'], equals(1));
      expect(summary['totalQuantity'], equals(2));
    });

    test('VoucherCartProvider should handle errors gracefully', () {
      // Try to add product without voucher
      voucherCartProvider.addToVoucherCart(testProduct, 1);
      
      expect(voucherCartProvider.error, isNotNull);
      expect(voucherCartProvider.isEmpty, isTrue);
    });

    test('VoucherCartProvider should handle zero quantity updates', () {
      voucherCartProvider.setVoucher(testVoucher);
      voucherCartProvider.addToVoucherCart(testProduct, 2);

      // Update to zero quantity (should remove item)
      voucherCartProvider.updateVoucherCartItemQuantity(testProduct.id, 0);

      expect(voucherCartProvider.isEmpty, isTrue);
      expect(voucherCartProvider.isProductInVoucherCart(testProduct.id), isFalse);
    });

    test('VoucherCartProvider should set and persist clientVoucherId', () {
      const testClientVoucherId = 'client-voucher-123';

      // Set voucher with clientVoucherId
      voucherCartProvider.setVoucher(testVoucher, clientVoucherId: testClientVoucherId);

      expect(voucherCartProvider.clientVoucherId, equals(testClientVoucherId));

      // Check cart summary includes clientVoucherId
      voucherCartProvider.addToVoucherCart(testProduct, 1);
      final summary = voucherCartProvider.getVoucherCartSummary();
      expect(summary['clientVoucherId'], equals(testClientVoucherId));
    });

    test('VoucherCartProvider should validate stock availability', () {
      // Create product with limited stock
      final limitedStockProduct = ProductModel(
        id: 'limited-product',
        name: 'منتج محدود',
        description: 'منتج بمخزون محدود',
        price: 50.0,
        category: 'كلبس',
        quantity: 3, // Only 3 items in stock
        sku: 'LIMITED-001',
        reorderPoint: 1,
        images: [],
        isActive: true,
        createdAt: DateTime.now(),
      );

      voucherCartProvider.setVoucher(testVoucher);

      // Add 2 items (should work)
      voucherCartProvider.addToVoucherCart(limitedStockProduct, 2);
      expect(voucherCartProvider.getVoucherCartProductQuantity(limitedStockProduct.id), equals(2));
      expect(voucherCartProvider.error, isNull);

      // Try to add 2 more items (should fail - total would be 4, but only 3 in stock)
      voucherCartProvider.addToVoucherCart(limitedStockProduct, 2);
      expect(voucherCartProvider.error, isNotNull);
      expect(voucherCartProvider.getVoucherCartProductQuantity(limitedStockProduct.id), equals(2)); // Should remain 2
    });

    test('VoucherCartProvider should handle out of stock products', () {
      // Create out of stock product
      final outOfStockProduct = ProductModel(
        id: 'out-of-stock',
        name: 'منتج نفد',
        description: 'منتج نفد من المخزون',
        price: 75.0,
        category: 'كلبس',
        quantity: 0, // Out of stock
        sku: 'OOS-001',
        reorderPoint: 5,
        images: [],
        isActive: true,
        createdAt: DateTime.now(),
      );

      voucherCartProvider.setVoucher(testVoucher);

      // Try to add out of stock product
      voucherCartProvider.addToVoucherCart(outOfStockProduct, 1);

      expect(voucherCartProvider.error, isNotNull);
      expect(voucherCartProvider.isEmpty, isTrue);
      expect(voucherCartProvider.isProductInVoucherCart(outOfStockProduct.id), isFalse);
    });

    test('VoucherCartProvider should validate quantity updates against stock', () {
      voucherCartProvider.setVoucher(testVoucher);
      voucherCartProvider.addToVoucherCart(testProduct, 5);

      // Try to update to quantity exceeding stock (testProduct has 50 in stock, so this should work)
      voucherCartProvider.updateVoucherCartItemQuantity(testProduct.id, 45, product: testProduct);
      expect(voucherCartProvider.getVoucherCartProductQuantity(testProduct.id), equals(45));
      expect(voucherCartProvider.error, isNull);

      // Try to update to quantity exceeding stock
      voucherCartProvider.updateVoucherCartItemQuantity(testProduct.id, 55, product: testProduct);
      expect(voucherCartProvider.error, isNotNull);
      expect(voucherCartProvider.getVoucherCartProductQuantity(testProduct.id), equals(45)); // Should remain unchanged
    });

    test('VoucherCartProvider should handle invalid voucher scenarios', () {
      // Try to add product without setting voucher first
      voucherCartProvider.addToVoucherCart(testProduct, 1);
      expect(voucherCartProvider.error, contains('يجب تطبيق قسيمة أولاً'));
      expect(voucherCartProvider.isEmpty, isTrue);

      // Create ineligible product (different category)
      final ineligibleProduct = ProductModel(
        id: 'ineligible-product',
        name: 'منتج غير مؤهل',
        description: 'منتج من فئة غير مؤهلة',
        price: 25.0,
        category: 'إلكترونيات', // Different category
        quantity: 10,
        sku: 'INELIG-001',
        reorderPoint: 2,
        images: [],
        isActive: true,
        createdAt: DateTime.now(),
      );

      voucherCartProvider.setVoucher(testVoucher);
      voucherCartProvider.addToVoucherCart(ineligibleProduct, 1);

      expect(voucherCartProvider.error, contains('غير مؤهل للقسيمة'));
      expect(voucherCartProvider.isEmpty, isTrue);
    });

    test('VoucherCartProvider should handle negative quantities gracefully', () {
      voucherCartProvider.setVoucher(testVoucher);
      voucherCartProvider.addToVoucherCart(testProduct, 2);

      // Try to add negative quantity
      voucherCartProvider.addToVoucherCart(testProduct, -1);
      expect(voucherCartProvider.error, isNotNull);

      // Try to update to negative quantity
      voucherCartProvider.updateVoucherCartItemQuantity(testProduct.id, -5);
      expect(voucherCartProvider.isEmpty, isTrue); // Should remove the item
    });
  });
}
