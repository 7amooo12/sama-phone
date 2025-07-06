import 'package:flutter_test/flutter_test.dart';
import 'package:smartbiztracker_new/models/user_model.dart';
import 'package:smartbiztracker_new/models/user_role.dart';

void main() {
  group('UserModel Phone Number Synchronization Tests', () {
    late UserModel testUser;

    setUp(() {
      testUser = UserModel(
        id: 'test-id',
        name: 'Test User',
        email: 'test@example.com',
        role: UserRole.client,
        phone: '01234567890',
        status: 'approved',
        createdAt: DateTime.now(),
        phoneNumber: '01234567890',
      );
    });

    test('copyWith should sync phone and phoneNumber when phoneNumber is updated', () {
      const newPhoneNumber = '09876543210';
      
      final updatedUser = testUser.copyWith(phoneNumber: newPhoneNumber);
      
      // Both phone and phoneNumber should be updated to the same value
      expect(updatedUser.phone, newPhoneNumber);
      expect(updatedUser.phoneNumber, newPhoneNumber);
    });

    test('copyWith should sync phone and phoneNumber when phone is updated', () {
      const newPhone = '09876543210';
      
      final updatedUser = testUser.copyWith(phone: newPhone);
      
      // Both phone and phoneNumber should be updated to the same value
      expect(updatedUser.phone, newPhone);
      expect(updatedUser.phoneNumber, newPhone);
    });

    test('copyWith should prioritize phoneNumber over phone when both are provided', () {
      const newPhoneNumber = '09876543210';
      const newPhone = '01111111111';
      
      final updatedUser = testUser.copyWith(
        phoneNumber: newPhoneNumber,
        phone: newPhone,
      );
      
      // phoneNumber should take priority and both fields should use its value
      expect(updatedUser.phone, newPhoneNumber);
      expect(updatedUser.phoneNumber, newPhoneNumber);
    });

    test('copyWith should preserve existing phone when neither phone nor phoneNumber is provided', () {
      final updatedUser = testUser.copyWith(name: 'Updated Name');
      
      // Phone fields should remain unchanged
      expect(updatedUser.phone, testUser.phone);
      expect(updatedUser.phoneNumber, testUser.phoneNumber);
    });

    test('copyWith should handle null phoneNumber correctly', () {
      final userWithNullPhone = UserModel(
        id: 'test-id',
        name: 'Test User',
        email: 'test@example.com',
        role: UserRole.client,
        phone: '',
        status: 'approved',
        createdAt: DateTime.now(),
        phoneNumber: null,
      );

      const newPhoneNumber = '09876543210';
      final updatedUser = userWithNullPhone.copyWith(phoneNumber: newPhoneNumber);
      
      expect(updatedUser.phone, newPhoneNumber);
      expect(updatedUser.phoneNumber, newPhoneNumber);
    });

    test('fromJson should properly map phone_number to both phone and phoneNumber fields', () {
      final json = {
        'id': 'test-id',
        'name': 'Test User',
        'email': 'test@example.com',
        'role': 'client',
        'phone_number': '01234567890',
        'status': 'approved',
        'created_at': DateTime.now().toIso8601String(),
      };

      final user = UserModel.fromJson(json);
      
      expect(user.phone, '01234567890');
      expect(user.phoneNumber, '01234567890');
    });

    test('toJson should output phone_number field correctly', () {
      final json = testUser.toJson();
      
      expect(json['phone_number'], testUser.phone);
      expect(json.containsKey('phoneNumber'), false); // Should not contain camelCase version
    });
  });
}
