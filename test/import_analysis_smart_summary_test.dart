import 'package:flutter_test/flutter_test.dart';
import 'package:smartbiztracker_new/models/import_analysis_models.dart';
import 'package:smartbiztracker_new/services/import_analysis/smart_summary_service.dart';

void main() {
  group('Smart Summary Service Tests', () {
    late List<PackingListItem> testItems;

    setUp(() {
      // Create test data that matches the Excel structure
      testItems = [
        PackingListItem(
          id: '1',
          importBatchId: 'batch1',
          itemNumber: 'ABC123',
          totalQuantity: 100,
          cartonCount: 10,
          piecesPerCarton: 10,
          totalCubicMeters: 5.5,
          unitPrice: 25.0,
          rmbPrice: 175.0,
          weights: {
            'net_weight': 50.0,
            'gross_weight': 55.0,
            'total_net_weight': 500.0,
            'total_gross_weight': 550.0,
          },
          remarks: {
            'remarks_a': 'شبوه البلاستكية و قطعه غياره معدن',
            'remarks_b': null,
            'remarks_c': null,
          },
          imageUrl: 'image1.jpg',
          validationStatus: 'valid',
          isPotentialDuplicate: false,
          createdAt: DateTime.now(),
        ),
        PackingListItem(
          id: '2',
          importBatchId: 'batch1',
          itemNumber: 'DEF456',
          totalQuantity: 200,
          cartonCount: 20,
          piecesPerCarton: 10,
          totalCubicMeters: 8.0,
          unitPrice: 15.0,
          rmbPrice: 105.0,
          weights: {
            'net_weight': 30.0,
            'gross_weight': 35.0,
            'total_net_weight': 600.0,
            'total_gross_weight': 700.0,
          },
          remarks: {
            'remarks_a': 'شسي الالمينيوم',
            'remarks_b': null,
            'remarks_c': null,
          },
          imageUrl: 'image2.jpg',
          validationStatus: 'valid',
          isPotentialDuplicate: false,
          createdAt: DateTime.now(),
        ),
        PackingListItem(
          id: '3',
          importBatchId: 'batch1',
          itemNumber: 'GHI789',
          totalQuantity: 50,
          cartonCount: 5,
          piecesPerCarton: 10,
          totalCubicMeters: 2.5,
          unitPrice: 30.0,
          rmbPrice: 210.0,
          weights: {
            'net_weight': 40.0,
            'gross_weight': 45.0,
            'total_net_weight': 200.0,
            'total_gross_weight': 225.0,
          },
          remarks: {
            'remarks_a': 'شبوه البلاستكية و قطعه غياره معدن', // Same as first item
            'remarks_b': null,
            'remarks_c': null,
          },
          imageUrl: 'image3.jpg',
          validationStatus: 'valid',
          isPotentialDuplicate: false,
          createdAt: DateTime.now(),
        ),
      ];
    });

    test('should generate correct numerical totals', () {
      final summary = SmartSummaryService.generateSmartSummary(testItems);
      final totals = summary['totals'] as Map<String, dynamic>;

      expect(totals['ctn'], equals(35)); // 10 + 20 + 5
      expect(totals['pc_ctn'], equals(30)); // 10 + 10 + 10
      expect(totals['QTY'], equals(350)); // 100 + 200 + 50
      expect(totals['t_cbm'], equals(16.0)); // 5.5 + 8.0 + 2.5
      expect(totals['N_W'], equals(120.0)); // 50 + 30 + 40
      expect(totals['G_W'], equals(135.0)); // 55 + 35 + 45
      expect(totals['T_NW'], equals(1300.0)); // 500 + 600 + 200
      expect(totals['T_GW'], equals(1475.0)); // 550 + 700 + 225
      expect(totals['PRICE'], equals(8000.0)); // (25*100) + (15*200) + (30*50)
      expect(totals['RMB'], equals(56000.0)); // (175*100) + (105*200) + (210*50)
    });

    test('should group remarks by quantity correctly', () {
      final summary = SmartSummaryService.generateSmartSummary(testItems);
      final remarksSummary = summary['remarks_summary'] as List<dynamic>;

      expect(remarksSummary.length, equals(2));
      
      // Should be sorted by quantity descending
      expect(remarksSummary[0]['text'], equals('شسي الالمينيوم'));
      expect(remarksSummary[0]['qty'], equals(200));
      
      expect(remarksSummary[1]['text'], equals('شبوه البلاستكية و قطعه غياره معدن'));
      expect(remarksSummary[1]['qty'], equals(150)); // 100 + 50 (grouped together)
    });

    test('should generate products summary correctly', () {
      final summary = SmartSummaryService.generateSmartSummary(testItems);
      final products = summary['products'] as List<dynamic>;

      expect(products.length, equals(3));
      
      // Check each product
      final product1 = products.firstWhere((p) => p['item_no'] == 'ABC123');
      expect(product1['total_qty'], equals(100));
      expect(product1['picture'], equals('image1.jpg'));
      
      final product2 = products.firstWhere((p) => p['item_no'] == 'DEF456');
      expect(product2['total_qty'], equals(200));
      expect(product2['picture'], equals('image2.jpg'));
      
      final product3 = products.firstWhere((p) => p['item_no'] == 'GHI789');
      expect(product3['total_qty'], equals(50));
      expect(product3['picture'], equals('image3.jpg'));
    });

    test('should generate valid JSON output', () {
      final jsonString = SmartSummaryService.generateJsonSummary(testItems);
      expect(jsonString, isNotNull);
      expect(jsonString, isNotEmpty);
      expect(jsonString, contains('"totals"'));
      expect(jsonString, contains('"remarks_summary"'));
      expect(jsonString, contains('"products"'));
    });

    test('should validate summary correctly', () {
      final summary = SmartSummaryService.generateSmartSummary(testItems);
      final validation = SmartSummaryService.validateSummary(summary);
      
      expect(validation['is_valid'], isTrue);
      expect(validation['errors'], isEmpty);
    });

    test('should handle empty remarks correctly', () {
      final itemsWithoutRemarks = [
        PackingListItem(
          id: '1',
          importBatchId: 'batch1',
          itemNumber: 'TEST123',
          totalQuantity: 100,
          remarks: null,
          validationStatus: 'valid',
          isPotentialDuplicate: false,
          createdAt: DateTime.now(),
        ),
      ];

      final summary = SmartSummaryService.generateSmartSummary(itemsWithoutRemarks);
      final remarksSummary = summary['remarks_summary'] as List<dynamic>;
      
      expect(remarksSummary, isEmpty);
    });

    test('should handle multiple remarks fields correctly', () {
      final itemsWithMultipleRemarks = [
        PackingListItem(
          id: '1',
          importBatchId: 'batch1',
          itemNumber: 'TEST123',
          totalQuantity: 100,
          remarks: {
            'remarks_a': 'ملاحظة أولى',
            'remarks_b': 'ملاحظة ثانية',
            'remarks_c': 'ملاحظة ثالثة',
          },
          validationStatus: 'valid',
          isPotentialDuplicate: false,
          createdAt: DateTime.now(),
        ),
      ];

      final summary = SmartSummaryService.generateSmartSummary(itemsWithMultipleRemarks);
      final remarksSummary = summary['remarks_summary'] as List<dynamic>;
      
      expect(remarksSummary.length, equals(1));
      expect(remarksSummary[0]['text'], equals('ملاحظة أولى - ملاحظة ثانية - ملاحظة ثالثة'));
      expect(remarksSummary[0]['qty'], equals(100));
    });

    test('should normalize whitespace in remarks correctly', () {
      final itemsWithWhitespace = [
        PackingListItem(
          id: '1',
          importBatchId: 'batch1',
          itemNumber: 'TEST123',
          totalQuantity: 100,
          remarks: {
            'remarks_a': '  ملاحظة   مع   مسافات   ',
          },
          validationStatus: 'valid',
          isPotentialDuplicate: false,
          createdAt: DateTime.now(),
        ),
        PackingListItem(
          id: '2',
          importBatchId: 'batch1',
          itemNumber: 'TEST456',
          totalQuantity: 50,
          remarks: {
            'remarks_a': 'ملاحظة مع مسافات',
          },
          validationStatus: 'valid',
          isPotentialDuplicate: false,
          createdAt: DateTime.now(),
        ),
      ];

      final summary = SmartSummaryService.generateSmartSummary(itemsWithWhitespace);
      final remarksSummary = summary['remarks_summary'] as List<dynamic>;
      
      expect(remarksSummary.length, equals(1));
      expect(remarksSummary[0]['qty'], equals(150)); // Should be grouped together
    });
  });
}
