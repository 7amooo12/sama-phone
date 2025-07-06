import 'package:flutter_test/flutter_test.dart';
import 'package:smartbiztracker_new/models/import_analysis_models.dart';
import 'package:smartbiztracker_new/utils/uuid_validator.dart';

/// Test suite for Import Analysis UUID generation fixes
/// 
/// This test verifies that the UUID generation issues in ImportAnalysisSettings
/// have been resolved and that proper UUIDs are generated instead of invalid
/// "default_" prefixed strings.
void main() {
  group('Import Analysis UUID Generation Fix Tests', () {
    test('ImportAnalysisSettings.createDefault generates valid UUID', () {
      // Arrange
      const testUserId = 'test-user-123';
      
      // Act
      final settings = ImportAnalysisSettings.createDefault(testUserId);
      
      // Assert
      expect(settings.id, isNotNull);
      expect(settings.id, isNot(startsWith('default_')));
      expect(UuidValidator.isValidUuid(settings.id), isTrue);
      expect(settings.userId, equals(testUserId));
      expect(settings.defaultCurrency, equals('EGP'));
    });

    test('ImportAnalysisSettings.toJson uses UuidValidator for safe UUID handling', () {
      // Arrange
      const testUserId = 'test-user-456';
      final settings = ImportAnalysisSettings.createDefault(testUserId);
      
      // Act
      final json = settings.toJson();
      
      // Assert
      expect(json, containsPair('id', settings.id));
      expect(json, containsPair('user_id', testUserId));
      expect(json, containsPair('default_currency', 'EGP'));
      expect(UuidValidator.isValidUuid(json['id'] as String), isTrue);
    });

    test('ImportAnalysisSettings with invalid UUID is handled safely in toJson', () {
      // Arrange
      final settings = ImportAnalysisSettings(
        id: 'invalid-uuid-format',
        userId: 'test-user-789',
        createdAt: DateTime.now(),
      );
      
      // Act
      final json = settings.toJson();
      
      // Assert
      // The invalid UUID should not be included in the JSON
      expect(json, isNot(containsKey('id')));
      expect(json, containsPair('user_id', 'test-user-789'));
      expect(json, containsPair('default_currency', 'EGP'));
    });

    test('ImportAnalysisSettings default currency is EGP', () {
      // Arrange & Act
      const testUserId = 'test-user-currency';
      final settings = ImportAnalysisSettings.createDefault(testUserId);
      
      // Assert
      expect(settings.defaultCurrency, equals('EGP'));
    });

    test('ImportAnalysisSettings fromJson handles missing default_currency with EGP fallback', () {
      // Arrange
      final json = {
        'id': 'valid-uuid-12345678-1234-1234-1234-123456789012',
        'user_id': 'test-user-json',
        'created_at': DateTime.now().toIso8601String(),
      };
      
      // Act
      final settings = ImportAnalysisSettings.fromJson(json);
      
      // Assert
      expect(settings.defaultCurrency, equals('EGP'));
    });

    test('Multiple ImportAnalysisSettings instances generate unique UUIDs', () {
      // Arrange
      const testUserId = 'test-user-unique';
      
      // Act
      final settings1 = ImportAnalysisSettings.createDefault(testUserId);
      final settings2 = ImportAnalysisSettings.createDefault(testUserId);
      final settings3 = ImportAnalysisSettings.createDefault(testUserId);
      
      // Assert
      expect(settings1.id, isNot(equals(settings2.id)));
      expect(settings1.id, isNot(equals(settings3.id)));
      expect(settings2.id, isNot(equals(settings3.id)));
      
      expect(UuidValidator.isValidUuid(settings1.id), isTrue);
      expect(UuidValidator.isValidUuid(settings2.id), isTrue);
      expect(UuidValidator.isValidUuid(settings3.id), isTrue);
    });

    test('ImportBatch targetCurrency defaults to EGP', () {
      // Arrange
      final batch = ImportBatch(
        id: 'batch-test-id',
        userId: 'test-user-batch',
        fileName: 'test.xlsx',
        fileSize: 1024,
        status: ImportBatchStatus.pending,
        createdAt: DateTime.now(),
      );
      
      // Act & Assert
      expect(batch.targetCurrency, equals('EGP'));
    });

    test('ImportBatch exchangeRate defaults to EGP rate (2.25)', () {
      // Arrange
      final batch = ImportBatch(
        id: 'batch-test-id-2',
        userId: 'test-user-batch-2',
        fileName: 'test2.xlsx',
        fileSize: 2048,
        status: ImportBatchStatus.pending,
        createdAt: DateTime.now(),
      );
      
      // Act & Assert
      expect(batch.exchangeRate, equals(2.25));
    });
  });
}
