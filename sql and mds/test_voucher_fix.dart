import 'package:flutter_test/flutter_test.dart';
import 'package:smartbiztracker_new/models/voucher_model.dart';

void main() {
  group('Voucher Fix Tests', () {
    test('VoucherCreateRequest should set discount_percentage to null for fixed_amount', () {
      final request = VoucherCreateRequest(
        name: 'Fixed Amount Test',
        type: VoucherType.product,
        targetId: 'product1',
        targetName: 'Test Product',
        discountPercentage: 0, // This should be ignored for fixed_amount
        discountType: DiscountType.fixedAmount,
        discountAmount: 50.0,
        expirationDate: DateTime.now().add(const Duration(days: 30)),
      );

      final json = request.toJson();
      
      expect(json['discount_type'], 'fixed_amount');
      expect(json['discount_percentage'], null); // Should be null for fixed_amount
      expect(json['discount_amount'], 50.0);
    });

    test('VoucherCreateRequest should keep discount_percentage for percentage type', () {
      final request = VoucherCreateRequest(
        name: 'Percentage Test',
        type: VoucherType.product,
        targetId: 'product1',
        targetName: 'Test Product',
        discountPercentage: 20,
        discountType: DiscountType.percentage,
        discountAmount: null,
        expirationDate: DateTime.now().add(const Duration(days: 30)),
      );

      final json = request.toJson();
      
      expect(json['discount_type'], 'percentage');
      expect(json['discount_percentage'], 20);
      expect(json['discount_amount'], null);
    });

    test('VoucherModel.fromJson should handle null discount_percentage for fixed_amount', () {
      final json = {
        'id': 'test-id',
        'code': 'TEST-CODE',
        'name': 'Test Voucher',
        'type': 'product',
        'target_id': 'product1',
        'target_name': 'Test Product',
        'discount_type': 'fixed_amount',
        'discount_percentage': null, // null in database
        'discount_amount': 50.0,
        'expiration_date': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        'is_active': true,
        'created_by': 'user-id',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final voucher = VoucherModel.fromJson(json);
      
      expect(voucher.discountType, DiscountType.fixedAmount);
      expect(voucher.discountPercentage, 0); // Should be 0 for fixed_amount
      expect(voucher.discountAmount, 50.0);
      expect(voucher.formattedDiscount, '50.00 جنيه');
    });

    test('VoucherModel.fromJson should handle percentage vouchers correctly', () {
      final json = {
        'id': 'test-id',
        'code': 'TEST-CODE',
        'name': 'Test Voucher',
        'type': 'product',
        'target_id': 'product1',
        'target_name': 'Test Product',
        'discount_type': 'percentage',
        'discount_percentage': 20,
        'discount_amount': null,
        'expiration_date': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        'is_active': true,
        'created_by': 'user-id',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final voucher = VoucherModel.fromJson(json);
      
      expect(voucher.discountType, DiscountType.percentage);
      expect(voucher.discountPercentage, 20);
      expect(voucher.discountAmount, null);
      expect(voucher.formattedDiscount, '20%');
    });

    test('VoucherModel.toJson should set discount_percentage to null for fixed_amount', () {
      final voucher = VoucherModel(
        id: 'test-id',
        code: 'TEST-CODE',
        name: 'Test Voucher',
        type: VoucherType.product,
        targetId: 'product1',
        targetName: 'Test Product',
        discountPercentage: 0, // Will be converted to null in toJson
        discountType: DiscountType.fixedAmount,
        discountAmount: 50.0,
        expirationDate: DateTime.now().add(const Duration(days: 30)),
        isActive: true,
        createdBy: 'user-id',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final json = voucher.toJson();
      
      expect(json['discount_type'], 'fixed_amount');
      expect(json['discount_percentage'], null); // Should be null
      expect(json['discount_amount'], 50.0);
    });
  });
}
