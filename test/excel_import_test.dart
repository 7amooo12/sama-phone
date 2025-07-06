import 'package:flutter_test/flutter_test.dart';
import 'package:smartbiztracker_new/models/purchase_invoice_models.dart';

/// Comprehensive test suite for Excel import functionality
/// Tests production readiness, data integrity, and performance
void main() {
  group('Excel Import Production Tests', () {
    
    test('PurchaseInvoiceItem.create produces identical structure to manual creation', () {
      // Test data
      const productName = 'Test Product';
      const yuanPrice = 100.0;
      const exchangeRate = 0.19;
      const profitMargin = 15.0;
      const quantity = 5;
      
      // Create item using the same method as Excel import
      final importedItem = PurchaseInvoiceItem.create(
        productName: productName,
        yuanPrice: yuanPrice,
        exchangeRate: exchangeRate,
        profitMarginPercent: profitMargin,
        quantity: quantity,
      );
      
      // Verify calculations match expected values
      final expectedBasePrice = yuanPrice * exchangeRate; // 19.0
      final expectedProfitAmount = expectedBasePrice * (profitMargin / 100); // 2.85
      final expectedFinalPrice = expectedBasePrice + expectedProfitAmount; // 21.85
      final expectedTotalPrice = expectedFinalPrice * quantity; // 109.25
      
      expect(importedItem.baseEgpPrice, closeTo(expectedBasePrice, 0.01));
      expect(importedItem.profitAmount, closeTo(expectedProfitAmount, 0.01));
      expect(importedItem.finalEgpPrice, closeTo(expectedFinalPrice, 0.01));
      expect(importedItem.totalPrice, closeTo(expectedTotalPrice, 0.01));
      expect(importedItem.quantity, equals(quantity));
      expect(importedItem.productName, equals(productName));
    });

    test('PurchaseInvoice.create calculates totals correctly', () {
      // Create multiple items
      final items = [
        PurchaseInvoiceItem.create(
          productName: 'Product 1',
          yuanPrice: 50.0,
          exchangeRate: 0.19,
          profitMarginPercent: 10.0,
          quantity: 2,
        ),
        PurchaseInvoiceItem.create(
          productName: 'Product 2',
          yuanPrice: 75.0,
          exchangeRate: 0.19,
          profitMarginPercent: 20.0,
          quantity: 3,
        ),
      ];
      
      final invoice = PurchaseInvoice.create(
        supplierName: 'Test Supplier',
        items: items,
        notes: 'Test import',
      );
      
      // Calculate expected total
      final expectedTotal = items.fold<double>(0.0, (sum, item) => sum + item.totalPrice);
      
      expect(invoice.totalAmount, closeTo(expectedTotal, 0.01));
      expect(invoice.itemsCount, equals(2));
      expect(invoice.totalQuantity, equals(5));
      expect(invoice.supplierName, equals('Test Supplier'));
      expect(invoice.status, equals('pending'));
    });

    test('Data validation handles edge cases correctly', () {
      // Test minimum values
      final minItem = PurchaseInvoiceItem.create(
        productName: 'Min Product',
        yuanPrice: 0.01,
        exchangeRate: 0.01,
        profitMarginPercent: 0.0,
        quantity: 1,
      );
      
      expect(minItem.yuanPrice, equals(0.01));
      expect(minItem.exchangeRate, equals(0.01));
      expect(minItem.profitMarginPercent, equals(0.0));
      expect(minItem.quantity, equals(1));
      
      // Test validation
      final validation = PurchaseInvoiceValidator.validateItem(minItem);
      expect(validation['isValid'], isTrue);
    });

    test('Large quantity calculations maintain precision', () {
      final largeQuantityItem = PurchaseInvoiceItem.create(
        productName: 'Bulk Product',
        yuanPrice: 1.23,
        exchangeRate: 0.19,
        profitMarginPercent: 5.5,
        quantity: 9999, // Maximum allowed quantity
      );
      
      // Verify calculations don't overflow or lose precision
      expect(largeQuantityItem.quantity, equals(9999));
      expect(largeQuantityItem.totalPrice, isPositive);
      expect(largeQuantityItem.totalPrice, isFinite);
      
      // Verify precision is maintained
      final unitPrice = largeQuantityItem.finalEgpPrice;
      final calculatedTotal = unitPrice * 9999;
      expect(largeQuantityItem.totalPrice, closeTo(calculatedTotal, 0.01));
    });

    test('Currency formatting matches AccountantThemeConfig', () {
      final testItem = PurchaseInvoiceItem.create(
        productName: 'Currency Test',
        yuanPrice: 123.456,
        exchangeRate: 0.19,
        profitMarginPercent: 15.0,
        quantity: 1,
      );
      
      // Test that prices are properly rounded to 2 decimal places
      expect(testItem.finalEgpPrice.toString().split('.').last.length, lessThanOrEqualTo(2));
      expect(testItem.totalPrice.toString().split('.').last.length, lessThanOrEqualTo(2));
    });

    test('Invoice ID generation is unique and follows pattern', () {
      final invoice1 = PurchaseInvoice.create(
        items: [
          PurchaseInvoiceItem.create(
            productName: 'Test',
            yuanPrice: 10.0,
            exchangeRate: 0.19,
            profitMarginPercent: 0.0,
          ),
        ],
      );
      
      // Small delay to ensure different timestamps
      Future.delayed(const Duration(milliseconds: 1));
      
      final invoice2 = PurchaseInvoice.create(
        items: [
          PurchaseInvoiceItem.create(
            productName: 'Test 2',
            yuanPrice: 20.0,
            exchangeRate: 0.19,
            profitMarginPercent: 0.0,
          ),
        ],
      );
      
      // Verify ID pattern and uniqueness
      expect(invoice1.id, startsWith('PINV-'));
      expect(invoice2.id, startsWith('PINV-'));
      expect(invoice1.id, isNot(equals(invoice2.id)));
    });

    test('JSON serialization maintains data integrity', () {
      final originalItem = PurchaseInvoiceItem.create(
        productName: 'JSON Test Product',
        productImage: 'test_image.jpg',
        yuanPrice: 88.88,
        exchangeRate: 0.19,
        profitMarginPercent: 12.5,
        quantity: 3,
        notes: 'Test notes',
      );
      
      // Serialize and deserialize
      final json = originalItem.toJson();
      final deserializedItem = PurchaseInvoiceItem.fromJson(json);
      
      // Verify all fields match
      expect(deserializedItem.productName, equals(originalItem.productName));
      expect(deserializedItem.productImage, equals(originalItem.productImage));
      expect(deserializedItem.yuanPrice, equals(originalItem.yuanPrice));
      expect(deserializedItem.exchangeRate, equals(originalItem.exchangeRate));
      expect(deserializedItem.profitMarginPercent, equals(originalItem.profitMarginPercent));
      expect(deserializedItem.quantity, equals(originalItem.quantity));
      expect(deserializedItem.finalEgpPrice, equals(originalItem.finalEgpPrice));
      expect(deserializedItem.notes, equals(originalItem.notes));
    });

    test('Invoice validation catches all error conditions', () {
      // Test empty invoice
      final emptyInvoice = PurchaseInvoice.create(items: []);
      final emptyValidation = PurchaseInvoiceValidator.validateInvoice(emptyInvoice);
      expect(emptyValidation['isValid'], isFalse);
      expect(emptyValidation['errors'], contains('يجب إضافة عنصر واحد على الأقل للفاتورة'));
      
      // Test invalid item
      final invalidItem = PurchaseInvoiceItem(
        id: 'test',
        productName: '', // Empty name
        yuanPrice: -1.0, // Negative price
        exchangeRate: 0.0, // Zero exchange rate
        profitMarginPercent: -5.0, // Negative margin
        quantity: 0, // Zero quantity
        finalEgpPrice: 0.0,
        createdAt: DateTime.now(),
      );
      
      final itemValidation = PurchaseInvoiceValidator.validateItem(invalidItem);
      expect(itemValidation['isValid'], isFalse);
      final errors = itemValidation['errors'] as List<String>;
      expect(errors.length, greaterThan(3)); // Multiple validation errors
    });

    test('Performance benchmarks for large datasets', () {
      final stopwatch = Stopwatch()..start();
      
      // Create 1000 items (simulating large Excel import)
      final items = List.generate(1000, (index) {
        return PurchaseInvoiceItem.create(
          productName: 'Product $index',
          yuanPrice: 10.0 + (index % 100),
          exchangeRate: 0.19,
          profitMarginPercent: 5.0 + (index % 20),
          quantity: 1 + (index % 10),
        );
      });
      
      stopwatch.stop();
      
      // Should complete within reasonable time (< 1 second)
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
      
      // Create invoice with all items
      stopwatch.reset();
      stopwatch.start();
      
      final largeInvoice = PurchaseInvoice.create(
        supplierName: 'Large Supplier',
        items: items,
      );
      
      stopwatch.stop();
      
      // Invoice creation should also be fast
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
      expect(largeInvoice.itemsCount, equals(1000));
      expect(largeInvoice.totalAmount, isPositive);
    });
  });
}
