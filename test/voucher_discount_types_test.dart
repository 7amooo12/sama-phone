import 'package:flutter_test/flutter_test.dart';
import 'package:smartbiztracker_new/models/voucher_model.dart';
import 'package:smartbiztracker_new/services/voucher_service.dart';

void main() {
  group('Voucher Discount Types Tests', () {
    late VoucherService voucherService;

    setUp(() {
      voucherService = VoucherService();
    });

    group('DiscountType Enum Tests', () {
      test('should have correct values for discount types', () {
        expect(DiscountType.percentage.value, 'percentage');
        expect(DiscountType.fixedAmount.value, 'fixed_amount');
      });

      test('should have correct display names', () {
        expect(DiscountType.percentage.displayName, 'نسبة مئوية');
        expect(DiscountType.fixedAmount.displayName, 'مبلغ ثابت');
      });

      test('should have correct symbols', () {
        expect(DiscountType.percentage.symbol, '%');
        expect(DiscountType.fixedAmount.symbol, 'جنيه');
      });

      test('should parse from string correctly', () {
        expect(DiscountType.fromString('percentage'), DiscountType.percentage);
        expect(DiscountType.fromString('fixed_amount'), DiscountType.fixedAmount);
        expect(DiscountType.fromString('invalid'), DiscountType.percentage); // default
      });
    });

    group('VoucherModel Tests', () {
      test('should create voucher with percentage discount', () {
        final voucher = VoucherModel(
          id: '1',
          code: 'TEST20',
          name: 'Test Voucher',
          type: VoucherType.product,
          targetId: 'product1',
          targetName: 'Test Product',
          discountPercentage: 20,
          discountType: DiscountType.percentage,
          expirationDate: DateTime.now().add(const Duration(days: 30)),
          isActive: true,
          createdBy: 'test',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(voucher.discountType, DiscountType.percentage);
        expect(voucher.getDiscountValue(), 20.0);
        expect(voucher.formattedDiscount, '20%');
      });

      test('should create voucher with fixed amount discount', () {
        final voucher = VoucherModel(
          id: '2',
          code: 'FIXED50',
          name: 'Fixed Discount Voucher',
          type: VoucherType.product,
          targetId: 'product1',
          targetName: 'Test Product',
          discountPercentage: 0,
          discountType: DiscountType.fixedAmount,
          discountAmount: 50.0,
          expirationDate: DateTime.now().add(const Duration(days: 30)),
          isActive: true,
          createdBy: 'test',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(voucher.discountType, DiscountType.fixedAmount);
        expect(voucher.getDiscountValue(), 50.0);
        expect(voucher.formattedDiscount, '50.00 جنيه');
      });

      test('should serialize and deserialize correctly', () {
        final originalVoucher = VoucherModel(
          id: '3',
          code: 'SERIALIZE',
          name: 'Serialization Test',
          type: VoucherType.category,
          targetId: 'category1',
          targetName: 'Test Category',
          discountPercentage: 15,
          discountType: DiscountType.percentage,
          expirationDate: DateTime.now().add(const Duration(days: 30)),
          isActive: true,
          createdBy: 'test',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final json = originalVoucher.toJson();
        final deserializedVoucher = VoucherModel.fromJson(json);

        expect(deserializedVoucher.discountType, originalVoucher.discountType);
        expect(deserializedVoucher.discountPercentage, originalVoucher.discountPercentage);
        expect(deserializedVoucher.discountAmount, originalVoucher.discountAmount);
      });
    });

    group('Discount Calculation Tests', () {
      test('should calculate percentage discount correctly', () {
        final voucher = VoucherModel(
          id: '4',
          code: 'PERCENT25',
          name: 'Percentage Test',
          type: VoucherType.product,
          targetId: 'product1',
          targetName: 'Test Product',
          discountPercentage: 25,
          discountType: DiscountType.percentage,
          expirationDate: DateTime.now().add(const Duration(days: 30)),
          isActive: true,
          createdBy: 'test',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final cartItems = [
          {
            'productId': 'product1',
            'name': 'Test Product',
            'price': 100.0,
            'quantity': 2,
            'category': 'test'
          }
        ];

        final result = voucherService.calculateVoucherDiscount(voucher, cartItems);
        
        expect(result['totalDiscount'], 50.0); // 25% of 200
        expect(result['discountType'], 'percentage');
        expect(result['formattedDiscount'], '25%');
      });

      test('should calculate fixed amount discount correctly', () {
        final voucher = VoucherModel(
          id: '5',
          code: 'FIXED30',
          name: 'Fixed Amount Test',
          type: VoucherType.product,
          targetId: 'product1',
          targetName: 'Test Product',
          discountPercentage: 0,
          discountType: DiscountType.fixedAmount,
          discountAmount: 30.0,
          expirationDate: DateTime.now().add(const Duration(days: 30)),
          isActive: true,
          createdBy: 'test',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final cartItems = [
          {
            'productId': 'product1',
            'name': 'Test Product',
            'price': 100.0,
            'quantity': 2,
            'category': 'test'
          }
        ];

        final result = voucherService.calculateVoucherDiscount(voucher, cartItems);
        
        expect(result['totalDiscount'], 60.0); // 30 per item * 2 items
        expect(result['discountType'], 'fixed_amount');
        expect(result['formattedDiscount'], '30.00 جنيه');
      });

      test('should not exceed item price for fixed amount discount', () {
        final voucher = VoucherModel(
          id: '6',
          code: 'FIXED200',
          name: 'High Fixed Amount Test',
          type: VoucherType.product,
          targetId: 'product1',
          targetName: 'Test Product',
          discountPercentage: 0,
          discountType: DiscountType.fixedAmount,
          discountAmount: 200.0, // Higher than item price
          expirationDate: DateTime.now().add(const Duration(days: 30)),
          isActive: true,
          createdBy: 'test',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final cartItems = [
          {
            'productId': 'product1',
            'name': 'Test Product',
            'price': 50.0,
            'quantity': 1,
            'category': 'test'
          }
        ];

        final result = voucherService.calculateVoucherDiscount(voucher, cartItems);
        
        expect(result['totalDiscount'], 50.0); // Should not exceed item price
      });
    });

    group('VoucherCreateRequest Tests', () {
      test('should create request with percentage discount', () {
        final request = VoucherCreateRequest(
          name: 'Test Request',
          type: VoucherType.product,
          targetId: 'product1',
          targetName: 'Test Product',
          discountPercentage: 15,
          discountType: DiscountType.percentage,
          expirationDate: DateTime.now().add(const Duration(days: 30)),
        );

        final json = request.toJson();
        expect(json['discount_type'], 'percentage');
        expect(json['discount_percentage'], 15);
        expect(json['discount_amount'], null);
      });

      test('should create request with fixed amount discount', () {
        final request = VoucherCreateRequest(
          name: 'Test Request',
          type: VoucherType.product,
          targetId: 'product1',
          targetName: 'Test Product',
          discountPercentage: 0,
          discountType: DiscountType.fixedAmount,
          discountAmount: 25.0,
          expirationDate: DateTime.now().add(const Duration(days: 30)),
        );

        final json = request.toJson();
        expect(json['discount_type'], 'fixed_amount');
        expect(json['discount_amount'], 25.0);
      });
    });
  });
}
