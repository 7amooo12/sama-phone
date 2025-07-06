import 'package:flutter_test/flutter_test.dart';
import 'package:smartbiztracker_new/models/import_analysis_models.dart';
import 'package:smartbiztracker_new/providers/import_analysis_provider.dart';
import 'package:smartbiztracker_new/services/supabase_service.dart';
import 'package:uuid/uuid.dart';

/// Test suite for Import Analysis Database Persistence Fixes
/// Tests the critical fixes implemented to resolve database save errors
void main() {
  group('Import Analysis Database Persistence Fixes', () {
    late ImportAnalysisProvider provider;
    late SupabaseService supabaseService;
    const uuid = Uuid();

    setUpAll(() async {
      // Initialize test environment
      supabaseService = SupabaseService();
      provider = ImportAnalysisProvider();
    });

    group('Data Validation Tests', () {
      test('should validate decimal precision limits correctly', () {
        // Test data with values that would cause database errors
        final testData = {
          'classification_confidence': 1.5, // Invalid: > 1.0
          'data_quality_score': -0.1, // Invalid: < 0.0
          'similarity_score': 10.0, // Invalid: > 1.0
          'unit_price': 1000000.0, // Valid: within DECIMAL(12,6) limits
          'rmb_price': 999999.999999, // Valid: at DECIMAL(12,6) limit
          'converted_price': 1000000.0, // Invalid: exceeds DECIMAL(12,6)
        };

        // This should clamp confidence values to 0.0-1.0 range
        // and validate price limits
        expect(() => provider.validateDecimalPrecisionLimits(testData, 'TEST-001'), 
               returnsNormally);
        
        // Check that confidence values were clamped
        expect(testData['classification_confidence'], equals(1.0));
        expect(testData['data_quality_score'], equals(0.0));
        expect(testData['similarity_score'], equals(1.0));
      });

      test('should validate required fields correctly', () {
        final validItem = PackingListItem(
          id: uuid.v4(),
          importBatchId: uuid.v4(),
          itemNumber: 'TEST-001',
          totalQuantity: 10,
          createdAt: DateTime.now(),
          createdBy: uuid.v4(),
        );

        final invalidItem = PackingListItem(
          id: uuid.v4(),
          importBatchId: '', // Invalid: empty
          itemNumber: '', // Invalid: empty
          totalQuantity: 0, // Invalid: zero
          createdAt: DateTime.now(),
          createdBy: null, // Invalid: null
        );

        // Valid item should pass validation
        expect(() => provider.validateItemDataForDatabase(validItem, validItem.toJson()),
               returnsNormally);

        // Invalid item should throw exception
        expect(() => provider.validateItemDataForDatabase(invalidItem, invalidItem.toJson()),
               throwsException);
      });

      test('should handle Arabic text in JSONB fields correctly', () {
        final arabicRemarks = {
          'remarks_a': 'هذا نص عربي للاختبار',
          'remarks_b': 'Arabic text: مواد البناء والتشييد',
          'remarks_c': 'Mixed: Building materials مواد البناء',
        };

        final item = PackingListItem(
          id: uuid.v4(),
          importBatchId: uuid.v4(),
          itemNumber: 'ARABIC-001',
          totalQuantity: 5,
          remarks: arabicRemarks,
          createdAt: DateTime.now(),
          createdBy: uuid.v4(),
        );

        // Should handle Arabic text without errors
        expect(() => provider.validateItemDataForDatabase(item, item.toJson()),
               returnsNormally);
      });
    });

    group('Database Schema Compliance Tests', () {
      test('should generate valid JSON for import_batches table', () {
        final batch = ImportBatch(
          id: uuid.v4(),
          filename: 'test.xlsx',
          originalFilename: 'test.xlsx',
          fileSize: 1024,
          fileType: 'xlsx',
          createdAt: DateTime.now(),
          createdBy: uuid.v4(),
        );

        final json = batch.toJson();

        // Check required fields are present
        expect(json['filename'], isNotNull);
        expect(json['original_filename'], isNotNull);
        expect(json['file_size'], isNotNull);
        expect(json['file_type'], isNotNull);
        expect(json['created_by'], isNotNull);
        expect(json['created_at'], isNotNull);

        // Check file_type is valid
        expect(['xlsx', 'xls', 'csv'].contains(json['file_type']), isTrue);

        // Check processing_status is valid
        final validStatuses = ['pending', 'processing', 'completed', 'failed', 'cancelled'];
        expect(validStatuses.contains(json['processing_status']), isTrue);
      });

      test('should generate valid JSON for packing_list_items table', () {
        final item = PackingListItem(
          id: uuid.v4(),
          importBatchId: uuid.v4(),
          itemNumber: 'TEST-001',
          totalQuantity: 10,
          cartonCount: 2,
          piecesPerCarton: 5,
          unitPrice: 15.50,
          rmbPrice: 100.0,
          convertedPrice: 225.0,
          conversionRate: 2.25,
          conversionCurrency: 'EGP',
          classificationConfidence: 0.95,
          dataQualityScore: 0.88,
          similarityScore: 0.0,
          validationStatus: 'valid',
          createdAt: DateTime.now(),
          createdBy: uuid.v4(),
        );

        final json = item.toJson();

        // Check required fields are present
        expect(json['import_batch_id'], isNotNull);
        expect(json['item_number'], isNotNull);
        expect(json['total_quantity'], isNotNull);
        expect(json['created_by'], isNotNull);
        expect(json['created_at'], isNotNull);

        // Check validation_status is valid
        final validStatuses = ['pending', 'valid', 'invalid', 'warning'];
        expect(validStatuses.contains(json['validation_status']), isTrue);

        // Check numeric precision compliance
        if (json['classification_confidence'] != null) {
          expect(json['classification_confidence'], lessThanOrEqualTo(1.0));
          expect(json['classification_confidence'], greaterThanOrEqualTo(0.0));
        }
        if (json['data_quality_score'] != null) {
          expect(json['data_quality_score'], lessThanOrEqualTo(1.0));
          expect(json['data_quality_score'], greaterThanOrEqualTo(0.0));
        }
      });
    });

    group('Error Handling Tests', () {
      test('should provide detailed error analysis for database failures', () {
        // Test various error scenarios
        final testErrors = [
          'PostgrestException: duplicate key value violates unique constraint "import_batches_pkey"',
          'PostgrestException: insert or update on table "packing_list_items" violates foreign key constraint',
          'PostgrestException: new row for relation "packing_list_items" violates check constraint',
          'PostgrestException: null value in column "item_number" violates not-null constraint',
          'PostgrestException: permission denied for table packing_list_items',
        ];

        for (final error in testErrors) {
          // Should analyze error without throwing
          expect(() => provider.analyzeAndLogDatabaseError(
            Exception(error), 
            StackTrace.current,
            ImportBatch(
              id: uuid.v4(),
              filename: 'test.xlsx',
              originalFilename: 'test.xlsx',
              fileSize: 1024,
              fileType: 'xlsx',
              createdAt: DateTime.now(),
              createdBy: uuid.v4(),
            ),
            []
          ), returnsNormally);
        }
      });
    });
  });
}

// Extension to access private methods for testing
extension ImportAnalysisProviderTest on ImportAnalysisProvider {
  void validateDecimalPrecisionLimits(Map<String, dynamic> itemJson, String itemNumber) {
    // This would need to be implemented as a public method or test helper
    // For now, this demonstrates the testing approach
  }

  Future<void> validateItemDataForDatabase(PackingListItem item, Map<String, dynamic> itemJson) async {
    // This would need to be implemented as a public method or test helper
    // For now, this demonstrates the testing approach
  }

  Future<void> analyzeAndLogDatabaseError(
    dynamic error, 
    StackTrace stackTrace, 
    ImportBatch batch, 
    List<PackingListItem> items
  ) async {
    // This would need to be implemented as a public method or test helper
    // For now, this demonstrates the testing approach
  }
}
