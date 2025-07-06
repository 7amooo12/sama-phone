import 'package:flutter_test/flutter_test.dart';
import 'package:smartbiztracker_new/services/import_analysis/excel_parsing_service.dart';
import 'package:smartbiztracker_new/models/import_analysis_models.dart';

void main() {
  group('Import Analysis Data Persistence Tests', () {
    test('Raw integer parsing should return valid values', () {
      // Test the new raw parsing function
      final testCases = [
        {'input': '100', 'expected': 100},
        {'input': '1,000', 'expected': 1000},
        {'input': '50.0', 'expected': 50},
        {'input': '0', 'expected': 0},
        {'input': '', 'expected': null},
        {'input': 'invalid', 'expected': null},
      ];

      for (final testCase in testCases) {
        final result = ExcelParsingService.parseRawIntegerValue(testCase['input'] as String);
        expect(result, equals(testCase['expected']), 
               reason: 'Failed for input: ${testCase['input']}');
      }
    });

    test('Multi-product cell splitting should create valid data', () {
      final mockItemData = {
        'item_number': 'ITEM001/ITEM002',
        'total_quantity': 100,
        'carton_count': 10,
        'pieces_per_carton': 5,
        'remarks_a': 'Test remarks',
      };

      final result = ExcelParsingService.splitMultiProductCell(mockItemData, 1);
      
      expect(result.length, equals(2));
      
      // Check first item
      expect(result[0]['item_number'], equals('ITEM001'));
      expect(result[0]['total_quantity'], greaterThan(0));
      expect(result[0]['metadata'], isNotNull);
      expect(result[0]['metadata']['is_split_product'], isTrue);
      
      // Check second item
      expect(result[1]['item_number'], equals('ITEM002'));
      expect(result[1]['total_quantity'], greaterThan(0));
      expect(result[1]['metadata'], isNotNull);
      expect(result[1]['metadata']['is_split_product'], isTrue);
      
      // Verify total quantities are preserved
      final totalQuantity = result[0]['total_quantity'] + result[1]['total_quantity'];
      expect(totalQuantity, equals(100));
    });

    test('PackingListItem creation should handle null values gracefully', () {
      final testData = {
        'temp_id': 'test-id',
        'item_number': 'TEST001',
        'total_quantity': null, // This should default to 1
        'carton_count': null,
        'pieces_per_carton': null,
      };

      expect(() {
        final item = PackingListItem(
          id: testData['temp_id'] as String,
          importBatchId: 'test-batch',
          itemNumber: testData['item_number'] as String,
          totalQuantity: testData['total_quantity'] as int? ?? 1,
          cartonCount: testData['carton_count'] as int?,
          piecesPerCarton: testData['pieces_per_carton'] as int?,
          createdAt: DateTime.now(),
        );
        
        expect(item.totalQuantity, equals(1));
        expect(item.cartonCount, isNull);
        expect(item.piecesPerCarton, isNull);
      }, returnsNormally);
    });

    test('PackingListItem toJson should not include invalid fields', () {
      final item = PackingListItem(
        id: 'test-id',
        importBatchId: 'test-batch',
        itemNumber: 'TEST001',
        totalQuantity: 100,
        cartonCount: 10,
        piecesPerCarton: 5,
        createdAt: DateTime.now(),
        metadata: {
          'is_split_product': true,
          'original_item_number': 'TEST001/TEST002',
          'split_separator': '/',
        },
      );

      final json = item.toJson();
      
      // Verify required fields are present
      expect(json['item_number'], equals('TEST001'));
      expect(json['total_quantity'], equals(100));
      expect(json['carton_count'], equals(10));
      expect(json['pieces_per_carton'], equals(5));
      expect(json['import_batch_id'], equals('test-batch'));
      
      // Verify metadata is properly structured
      expect(json['metadata'], isNotNull);
      expect(json['metadata']['is_split_product'], isTrue);
      
      // Verify no invalid fields are present
      expect(json.containsKey('original_item_number'), isFalse);
      expect(json.containsKey('split_separator'), isFalse);
      expect(json.containsKey('split_index'), isFalse);
      expect(json.containsKey('total_splits'), isFalse);
    });

    test('Field value parsing should handle edge cases', () {
      // Test total_quantity parsing
      expect(ExcelParsingService.parseFieldValue('total_quantity', '100'), equals(100));
      expect(ExcelParsingService.parseFieldValue('total_quantity', '0'), equals(0));
      expect(ExcelParsingService.parseFieldValue('total_quantity', ''), isNull);
      
      // Test carton_count parsing
      expect(ExcelParsingService.parseFieldValue('carton_count', '50'), equals(50));
      expect(ExcelParsingService.parseFieldValue('carton_count', '0'), equals(0));
      
      // Test pieces_per_carton parsing
      expect(ExcelParsingService.parseFieldValue('pieces_per_carton', '10'), equals(10));
      expect(ExcelParsingService.parseFieldValue('pieces_per_carton', '0'), equals(0));
      
      // Test text fields
      expect(ExcelParsingService.parseFieldValue('item_number', 'ITEM001'), equals('ITEM001'));
      expect(ExcelParsingService.parseFieldValue('remarks_a', 'Test remarks'), equals('Test remarks'));
    });
  });
}

// Extension to access private methods for testing
extension ExcelParsingServiceTest on ExcelParsingService {
  static int? parseRawIntegerValue(String value) {
    return ExcelParsingService._parseRawIntegerValue(value);
  }
  
  static List<Map<String, dynamic>> splitMultiProductCell(Map<String, dynamic> itemData, int rowIndex) {
    return ExcelParsingService._splitMultiProductCell(itemData, rowIndex);
  }
  
  static dynamic parseFieldValue(String fieldName, dynamic cellValue) {
    return ExcelParsingService._parseFieldValue(fieldName, cellValue);
  }
}
