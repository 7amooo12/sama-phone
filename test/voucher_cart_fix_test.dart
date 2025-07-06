import 'package:flutter_test/flutter_test.dart';
import '../lib/services/client_orders_service.dart';
import '../lib/models/product_model.dart';

/// Test to verify the CartItem.fromProductWithVoucher() fix
/// This test ensures that the factory constructor works correctly
/// without the discountAmount parameter
void main() {
  group('CartItem.fromProductWithVoucher Fix Tests', () {
    late ProductModel testProduct;

    setUp(() {
      testProduct = ProductModel(
        id: 'test-product-1',
        name: 'منتج اختبار',
        description: 'منتج للاختبار',
        price: 100.0,
        category: 'أثاث',
        quantity: 10,
        sku: 'TEST-001',
        reorderPoint: 2,
        images: ['test-image.jpg'],
        isActive: true,
        createdAt: DateTime.now(),
      );
    });

    test('should create CartItem with voucher discount correctly', () {
      // Test the fixed factory constructor
      final cartItem = CartItem.fromProductWithVoucher(
        product: testProduct,
        quantity: 2,
        discountedPrice: 80.0, // 20% discount
        originalPrice: 100.0,
        voucherCode: 'TEST20',
        voucherName: 'خصم 20%',
        discountPercentage: 20.0,
      );

      // Verify all properties are set correctly
      expect(cartItem.productId, equals('test-product-1'));
      expect(cartItem.productName, equals('منتج اختبار'));
      expect(cartItem.price, equals(80.0)); // Discounted price
      expect(cartItem.quantity, equals(2));
      expect(cartItem.category, equals('أثاث'));
      expect(cartItem.originalPrice, equals(100.0));
      expect(cartItem.discountAmount, equals(20.0)); // Calculated internally
      expect(cartItem.voucherCode, equals('TEST20'));
      expect(cartItem.voucherName, equals('خصم 20%'));
      expect(cartItem.discountPercentage, equals(20.0));
      expect(cartItem.isVoucherItem, isTrue);
    });

    test('should calculate discount amount correctly for percentage discount', () {
      final cartItem = CartItem.fromProductWithVoucher(
        product: testProduct,
        quantity: 1,
        discountedPrice: 75.0, // 25% discount
        originalPrice: 100.0,
        voucherCode: 'SAVE25',
        voucherName: 'خصم 25%',
        discountPercentage: 25.0,
      );

      expect(cartItem.discountAmount, equals(25.0));
      expect(cartItem.hasVoucherDiscount, isTrue);
      expect(cartItem.totalSavings, equals(25.0)); // 25.0 * 1 quantity
      expect(cartItem.totalPrice, equals(75.0)); // Discounted price * quantity
      expect(cartItem.totalOriginalPrice, equals(100.0)); // Original price * quantity
    });

    test('should calculate discount amount correctly for fixed amount discount', () {
      final cartItem = CartItem.fromProductWithVoucher(
        product: testProduct,
        quantity: 3,
        discountedPrice: 85.0, // 15 EGP fixed discount
        originalPrice: 100.0,
        voucherCode: 'FIXED15',
        voucherName: 'خصم 15 جنيه',
        discountPercentage: 0.0, // No percentage for fixed amount
      );

      expect(cartItem.discountAmount, equals(15.0));
      expect(cartItem.hasVoucherDiscount, isTrue);
      expect(cartItem.totalSavings, equals(45.0)); // 15.0 * 3 quantity
      expect(cartItem.totalPrice, equals(255.0)); // 85.0 * 3 quantity
      expect(cartItem.totalOriginalPrice, equals(300.0)); // 100.0 * 3 quantity
    });

    test('should handle zero discount correctly', () {
      final cartItem = CartItem.fromProductWithVoucher(
        product: testProduct,
        quantity: 1,
        discountedPrice: 100.0, // No discount
        originalPrice: 100.0,
        voucherCode: 'NODISCOUNT',
        voucherName: 'قسيمة بدون خصم',
        discountPercentage: 0.0,
      );

      expect(cartItem.discountAmount, equals(0.0));
      expect(cartItem.hasVoucherDiscount, isFalse); // No discount > 0
      expect(cartItem.totalSavings, equals(0.0));
      expect(cartItem.totalPrice, equals(100.0));
      expect(cartItem.totalOriginalPrice, equals(100.0));
    });

    test('should maintain AccountantThemeConfig compatibility', () {
      // This test ensures the fix doesn't break styling compatibility
      final cartItem = CartItem.fromProductWithVoucher(
        product: testProduct,
        quantity: 1,
        discountedPrice: 90.0,
        originalPrice: 100.0,
        voucherCode: 'STYLE10',
        voucherName: 'خصم التصميم',
        discountPercentage: 10.0,
      );

      // Verify that all required properties for UI display are present
      expect(cartItem.productName.isNotEmpty, isTrue);
      expect(cartItem.productImage.isNotEmpty, isTrue);
      expect(cartItem.category.isNotEmpty, isTrue);
      expect(cartItem.voucherName!.isNotEmpty, isTrue);
      expect(cartItem.voucherCode!.isNotEmpty, isTrue);
      
      // Verify Arabic RTL support (product name contains Arabic)
      expect(cartItem.productName, contains('منتج'));
      expect(cartItem.voucherName, contains('خصم'));
    });

    test('should work with copyWith method', () {
      final originalItem = CartItem.fromProductWithVoucher(
        product: testProduct,
        quantity: 1,
        discountedPrice: 80.0,
        originalPrice: 100.0,
        voucherCode: 'TEST20',
        voucherName: 'خصم 20%',
        discountPercentage: 20.0,
      );

      final updatedItem = originalItem.copyWith(
        quantity: 3,
        discountAmount: 25.0, // Update discount amount
      );

      expect(updatedItem.quantity, equals(3));
      expect(updatedItem.discountAmount, equals(25.0));
      expect(updatedItem.price, equals(80.0)); // Unchanged
      expect(updatedItem.voucherCode, equals('TEST20')); // Unchanged
    });
  });
}
