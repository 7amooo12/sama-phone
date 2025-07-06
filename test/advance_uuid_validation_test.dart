import 'package:flutter_test/flutter_test.dart';
import 'package:smartbiztracker_new/models/advance_model.dart';
import 'package:smartbiztracker_new/utils/uuid_validator.dart';

/// Test suite for advance UUID validation fixes
/// 
/// This test verifies that the UUID validation fixes prevent PostgreSQL
/// UUID validation errors when updating advance records.
void main() {
  group('Advance UUID Validation Tests', () {
    
    test('UuidValidator should validate correct UUID format', () {
      // Valid UUID v4 format
      const validUuid = '6a5b7c06-ac48-4c8b-9f0e-c9d2321adfab';
      expect(UuidValidator.isValidUuid(validUuid), isTrue);
      
      // Invalid formats
      expect(UuidValidator.isValidUuid(''), isFalse);
      expect(UuidValidator.isValidUuid('invalid-uuid'), isFalse);
      expect(UuidValidator.isValidUuid('123'), isFalse);
      expect(UuidValidator.isValidUuid(null), isFalse);
    });

    test('UuidValidator should handle empty strings correctly', () {
      expect(UuidValidator.toValidUuidOrNull(''), isNull);
      expect(UuidValidator.toValidUuidOrNull(null), isNull);
      expect(UuidValidator.toValidUuidOrNull('invalid'), isNull);
      
      const validUuid = '6a5b7c06-ac48-4c8b-9f0e-c9d2321adfab';
      expect(UuidValidator.toValidUuidOrNull(validUuid), equals(validUuid));
    });

    test('UuidValidator should add valid UUIDs to JSON', () {
      final json = <String, dynamic>{};
      
      // Valid UUID should be added
      const validUuid = '6a5b7c06-ac48-4c8b-9f0e-c9d2321adfab';
      UuidValidator.addUuidToJson(json, 'valid_id', validUuid);
      expect(json['valid_id'], equals(validUuid));
      
      // Invalid UUID should not be added
      UuidValidator.addUuidToJson(json, 'invalid_id', '');
      expect(json.containsKey('invalid_id'), isFalse);
      
      UuidValidator.addUuidToJson(json, 'null_id', null);
      expect(json.containsKey('null_id'), isFalse);
    });

    test('UuidValidator should validate advance-specific UUIDs', () {
      const validUuid = '6a5b7c06-ac48-4c8b-9f0e-c9d2321adfab';
      
      // Valid advance ID should not throw
      expect(() => UuidValidator.validateAdvanceId(validUuid), returnsNormally);
      
      // Invalid advance ID should throw with Arabic message
      expect(() => UuidValidator.validateAdvanceId(''), 
             throwsA(predicate((e) => e.toString().contains('معرف السلفة مطلوب'))));
      expect(() => UuidValidator.validateAdvanceId('invalid'), 
             throwsA(predicate((e) => e.toString().contains('معرف السلفة غير صحيح'))));
      
      // Valid created_by should not throw
      expect(() => UuidValidator.validateCreatedBy(validUuid), returnsNormally);
      
      // Invalid created_by should throw with Arabic message
      expect(() => UuidValidator.validateCreatedBy(''), 
             throwsA(predicate((e) => e.toString().contains('معرف منشئ السلفة مطلوب'))));
      
      // Optional client ID validation
      expect(() => UuidValidator.validateOptionalClientId(validUuid), returnsNormally);
      expect(() => UuidValidator.validateOptionalClientId(''), returnsNormally); // Empty is OK
      expect(() => UuidValidator.validateOptionalClientId(null), returnsNormally); // Null is OK
      expect(() => UuidValidator.validateOptionalClientId('invalid'), 
             throwsA(predicate((e) => e.toString().contains('معرف العميل غير صحيح'))));
    });

    test('AdvanceModel.fromDatabase should validate UUID fields', () {
      const validUuid = '6a5b7c06-ac48-4c8b-9f0e-c9d2321adfab';
      const validClientUuid = '7b6c8d07-bd59-5d9c-af1f-d0e3432befbc';
      
      // Valid data should create model successfully
      final validData = {
        'id': validUuid,
        'advance_name': 'Test Advance',
        'client_id': validClientUuid,
        'client_name': 'Test Client',
        'amount': 1000.0,
        'status': 'pending',
        'description': 'Test description',
        'created_at': '2024-01-01T00:00:00Z',
        'created_by': validUuid,
      };
      
      expect(() => AdvanceModel.fromDatabase(validData), returnsNormally);
      
      // Invalid advance ID should throw
      final invalidIdData = Map<String, dynamic>.from(validData);
      invalidIdData['id'] = 'invalid-uuid';
      expect(() => AdvanceModel.fromDatabase(invalidIdData), throwsArgumentError);
      
      // Invalid created_by should throw
      final invalidCreatedByData = Map<String, dynamic>.from(validData);
      invalidCreatedByData['created_by'] = 'invalid-uuid';
      expect(() => AdvanceModel.fromDatabase(invalidCreatedByData), throwsArgumentError);
      
      // Invalid client_id should throw (if not empty)
      final invalidClientIdData = Map<String, dynamic>.from(validData);
      invalidClientIdData['client_id'] = 'invalid-uuid';
      expect(() => AdvanceModel.fromDatabase(invalidClientIdData), throwsArgumentError);
    });

    test('AdvanceModel.toDatabase should handle UUID fields safely', () {
      const validUuid = '6a5b7c06-ac48-4c8b-9f0e-c9d2321adfab';
      const validClientUuid = '7b6c8d07-bd59-5d9c-af1f-d0e3432befbc';
      
      final advance = AdvanceModel(
        id: validUuid,
        advanceName: 'Test Advance',
        clientId: validClientUuid,
        clientName: 'Test Client',
        amount: 1000.0,
        status: 'pending',
        description: 'Test description',
        createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
        createdBy: validUuid,
      );
      
      final databaseData = advance.toDatabase();
      
      // Valid UUIDs should be included
      expect(databaseData['id'], equals(validUuid));
      expect(databaseData['client_id'], equals(validClientUuid));
      expect(databaseData['created_by'], equals(validUuid));
      
      // Other fields should be present
      expect(databaseData['advance_name'], equals('Test Advance'));
      expect(databaseData['amount'], equals(1000.0));
      expect(databaseData['status'], equals('pending'));
    });

    test('AdvanceModel should handle empty client_id correctly', () {
      const validUuid = '6a5b7c06-ac48-4c8b-9f0e-c9d2321adfab';
      
      // Create advance with empty client_id (backward compatibility)
      final advance = AdvanceModel(
        id: validUuid,
        advanceName: 'Test Advance',
        clientId: '', // Empty string for backward compatibility
        clientName: 'Test Client',
        amount: 1000.0,
        status: 'pending',
        description: 'Test description',
        createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
        createdBy: validUuid,
      );
      
      final databaseData = advance.toDatabase();
      
      // Empty client_id should not be included in database data
      expect(databaseData.containsKey('client_id'), isFalse);
      
      // Other valid UUIDs should still be included
      expect(databaseData['id'], equals(validUuid));
      expect(databaseData['created_by'], equals(validUuid));
    });
  });
}
