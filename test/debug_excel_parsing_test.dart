import 'package:flutter_test/flutter_test.dart';
import 'package:smartbiztracker_new/services/import_analysis/excel_parsing_service.dart';
import 'package:smartbiztracker_new/models/import_analysis_models.dart';

/// Debug test to verify Excel parsing is working correctly
/// This test helps identify why the Import Analysis feature is generating mock data
void main() {
  group('Debug Excel Parsing Tests', () {
    test('should detect headers correctly with Chinese and Arabic text', () {
      // Simulate the actual Excel data structure from the packing list
      final mockExcelData = [
        // Header row with Chinese and English headers
        ['PACKINGLIST-NO.2 CONTAINERS', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', ''],
        ['S/NO.', 'ITEM NO.', 'picture', 'ctn', 'pc/ctn', 'QTY', 'size1', 'size2', 'size3', 't.cbm', 'N.W', 'G.W', 'T.NW', 'T.GW', 'PRICE', 'RMB', 'REMARKS', 'REMARKS'],
        ['', '型号', '图片', '箱数', '支/箱', '数量', '长', '宽', '高', '总体积', '净重', '毛重', '总净重', '总毛重', '单价', '总金额', '', '备注'],
        // Sample data rows
        ['依米', 'C11/3GD', 'C11/3GD-H1', '1', '200', '200', '55', '25', '39', '0.05', '21.50', '22.00', '21.50', '22.00', '', '', 'شبوه البلاستكية و قطعه غياره معدن', '灯罩H (包含牙管，螺丝等配件）'],
        ['依米', '', 'C11/3GD-H2', '1', '100', '100', '55', '25', '19', '0.03', '9.70', '10.00', '9.70', '10.00', '', '', 'شبوه البلاستكية و قطعه غياره معدن', '灯罩H (包含牙管，螺丝等配件）'],
        ['名富豪', '6330/500', '', '6', '10', '60', '31', '31', '35', '0.20', '7.90', '9.00', '47.40', '54.00', '￥158.50', '￥9,510.00', 'شسي بدويل', '五金灯体穿好灯头线 B'],
      ];

      // Test header detection
      final headerResult = ExcelParsingService.detectHeaders(mockExcelData);

      // Verify header detection worked
      expect(headerResult.headerRow, equals(1)); // Should detect row 1 as headers
      expect(headerResult.confidence, greaterThan(0.3));
      expect(headerResult.mapping.containsKey('serial_number'), isTrue);
      expect(headerResult.mapping.containsKey('item_number'), isTrue);
      expect(headerResult.mapping.containsKey('total_quantity'), isTrue);
      
      print('Header detection result:');
      print('Row: ${headerResult.headerRow}');
      print('Confidence: ${headerResult.confidence}');
      print('Mapping: ${headerResult.mapping}');
    });

    test('should extract data correctly from mock Excel structure', () {
      final mockExcelData = [
        ['PACKINGLIST-NO.2 CONTAINERS', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', ''],
        ['S/NO.', 'ITEM NO.', 'picture', 'ctn', 'pc/ctn', 'QTY', 'size1', 'size2', 'size3', 't.cbm', 'N.W', 'G.W', 'T.NW', 'T.GW', 'PRICE', 'RMB', 'REMARKS', 'REMARKS'],
        ['', '型号', '图片', '箱数', '支/箱', '数量', '长', '宽', '高', '总体积', '净重', '毛重', '总净重', '总毛重', '单价', '总金额', '', '备注'],
        ['依米', 'C11/3GD', 'C11/3GD-H1', '1', '200', '200', '55', '25', '39', '0.05', '21.50', '22.00', '21.50', '22.00', '', '', 'شبوه البلاستكية و قطعه غياره معدن', '灯罩H (包含牙管，螺丝等配件）'],
        ['依米', '', 'C11/3GD-H2', '1', '100', '100', '55', '25', '19', '0.03', '9.70', '10.00', '9.70', '10.00', '', '', 'شبوه البلاستكية و قطعه غياره معدن', '灯罩H (包含牙管，螺丝等配件）'],
        ['名富豪', '6330/500', '', '6', '10', '60', '31', '31', '35', '0.20', '7.90', '9.00', '47.40', '54.00', '￥158.50', '￥9,510.00', 'شسي بدويل', '五金灯体穿好灯头线 B'],
      ];

      // Test header detection
      final headerResult = ExcelParsingService.detectHeaders(mockExcelData);

      // Test data extraction
      final extractedData = ExcelParsingService.extractPackingListData(mockExcelData, headerResult);
      
      // Verify data extraction
      expect(extractedData.length, greaterThan(0));
      
      // Check first item
      if (extractedData.isNotEmpty) {
        final firstItem = extractedData[0];
        print('First extracted item: $firstItem');
        
        // Should have item number and quantity
        expect(firstItem['item_number'], isNotNull);
        expect(firstItem['total_quantity'], isNotNull);
        expect(firstItem['total_quantity'], greaterThan(0));
      }
      
      print('Extracted ${extractedData.length} items');
      for (int i = 0; i < extractedData.length && i < 3; i++) {
        print('Item $i: ${extractedData[i]}');
      }
    });

    test('should validate packing items correctly with improved flexibility', () {
      // Test cases for the improved validation logic
      final validItemWithItemNumber = {
        'item_number': 'C11/3GD',
        'total_quantity': 200,
        'carton_count': 1,
        'pieces_per_carton': 200,
      };

      final validItemWithQuantityOnly = {
        'item_number': '',
        'total_quantity': 150,
        'carton_count': null,
        'pieces_per_carton': null,
      };

      final validItemWithCartonData = {
        'item_number': '',
        'total_quantity': null,
        'carton_count': 5,
        'pieces_per_carton': 20,
      };

      final validItemWithRemarks = {
        'item_number': '',
        'total_quantity': null,
        'carton_count': null,
        'pieces_per_carton': null,
        'remarks_a': 'شبوه البلاستكية و قطعه غياره معدن',
      };

      final completelyInvalidItem = {
        'item_number': '',
        'total_quantity': 0,
        'carton_count': null,
        'pieces_per_carton': null,
        'remarks_a': '',
      };

      // Test improved validation
      expect(ExcelParsingService.isValidPackingItem(validItemWithItemNumber), isTrue);
      expect(ExcelParsingService.isValidPackingItem(validItemWithQuantityOnly), isTrue);
      expect(ExcelParsingService.isValidPackingItem(validItemWithCartonData), isTrue);
      expect(ExcelParsingService.isValidPackingItem(validItemWithRemarks), isTrue);
      expect(ExcelParsingService.isValidPackingItem(completelyInvalidItem), isFalse);
    });

    test('should extract ALL data rows including partial data', () {
      // Test data with various scenarios including partial data
      final testExcelData = [
        ['PACKINGLIST-NO.2 CONTAINERS', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', ''],
        ['S/NO.', 'ITEM NO.', 'picture', 'ctn', 'pc/ctn', 'QTY', 'size1', 'size2', 'size3', 't.cbm', 'N.W', 'G.W', 'T.NW', 'T.GW', 'PRICE', 'RMB', 'REMARKS', 'REMARKS'],
        ['', '型号', '图片', '箱数', '支/箱', '数量', '长', '宽', '高', '总体积', '净重', '毛重', '总净重', '总毛重', '单价', '总金额', '', '备注'],
        // Complete data row
        ['依米', 'C11/3GD', 'C11/3GD-H1', '1', '200', '200', '55', '25', '39', '0.05', '21.50', '22.00', '21.50', '22.00', '', '', 'شبوه البلاستكية و قطعه غياره معدن', '灯罩H (包含牙管，螺丝等配件）'],
        // Row with missing item number but valid quantity
        ['依米', '', 'C11/3GD-H2', '1', '100', '100', '55', '25', '19', '0.03', '9.70', '10.00', '9.70', '10.00', '', '', 'شبوه البلاستكية و قطعه غياره معدن', '灯罩H (包含牙管，螺丝等配件）'],
        // Row with item number but missing quantity
        ['名富豪', '6330/500', '', '6', '10', '', '31', '31', '35', '0.20', '7.90', '9.00', '47.40', '54.00', '￥158.50', '￥9,510.00', 'شسي بدويل', '五金灯体穿好灯头线 B'],
        // Row with only carton data
        ['', '', '', '3', '50', '', '', '', '', '', '', '', '', '', '', '', 'بيانات كراتين فقط', ''],
        // Row with only remarks
        ['', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 'ملاحظات مهمة للمنتج', ''],
        // Completely empty row (should be skipped)
        ['', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', ''],
        // Row with only zeros (should be skipped)
        ['', '', '', '0', '0', '0', '', '', '', '', '', '', '', '', '', '', '', ''],
      ];

      // Test header detection
      final headerResult = ExcelParsingService.detectHeaders(testExcelData);

      // Test data extraction
      final extractedData = ExcelParsingService.extractPackingListData(testExcelData, headerResult);

      print('Test data extraction results:');
      print('Total rows in test data: ${testExcelData.length}');
      print('Header row: ${headerResult.headerRow}');
      print('Data rows available: ${testExcelData.length - headerResult.headerRow - 1}');
      print('Extracted items: ${extractedData.length}');

      // We should extract more items now with the improved logic
      // At minimum: complete row + quantity-only row + carton-only row + remarks-only row = 4 items
      expect(extractedData.length, greaterThanOrEqualTo(4));

      // Print details of extracted items
      for (int i = 0; i < extractedData.length; i++) {
        final item = extractedData[i];
        print('Extracted item $i: item_number="${item['item_number']}", quantity=${item['total_quantity']}, cartons=${item['carton_count']}, remarks="${item['remarks_a']}"');
      }
    });

    test('should extract ALL data rows without limits - comprehensive test', () {
      // Create a large test dataset with various data patterns
      final comprehensiveTestData = <List<dynamic>>[
        ['PACKINGLIST-NO.2 CONTAINERS', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', ''],
        ['S/NO.', 'ITEM NO.', 'picture', 'ctn', 'pc/ctn', 'QTY', 'size1', 'size2', 'size3', 't.cbm', 'N.W', 'G.W', 'T.NW', 'T.GW', 'PRICE', 'RMB', 'REMARKS', 'REMARKS'],
        ['', '型号', '图片', '箱数', '支/箱', '数量', '长', '宽', '高', '总体积', '净重', '毛重', '总净重', '总毛重', '单价', '总金额', '', '备注'],
      ];

      // Add 50 rows of various data patterns to test comprehensive extraction
      for (int i = 1; i <= 50; i++) {
        if (i % 10 == 0) {
          // Every 10th row: complete data
          comprehensiveTestData.add(['$i', 'ITEM-$i', 'image-$i.jpg', '$i', '${i * 10}', '${i * 100}', '55', '25', '39', '0.05', '21.50', '22.00', '21.50', '22.00', '10.5', '1050', 'منتج رقم $i مع بيانات كاملة', 'Complete item $i']);
        } else if (i % 7 == 0) {
          // Every 7th row: only item number and quantity
          comprehensiveTestData.add(['$i', 'ITEM-$i', '', '', '', '${i * 50}', '', '', '', '', '', '', '', '', '', '', 'منتج رقم $i مع كمية فقط', '']);
        } else if (i % 5 == 0) {
          // Every 5th row: only carton data
          comprehensiveTestData.add(['$i', '', '', '$i', '${i * 5}', '', '', '', '', '', '', '', '', '', '', '', 'بيانات كراتين للمنتج $i', '']);
        } else if (i % 3 == 0) {
          // Every 3rd row: only remarks
          comprehensiveTestData.add(['$i', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 'ملاحظات مهمة للمنتج رقم $i مع تفاصيل إضافية', 'Important notes for item $i']);
        } else if (i % 2 == 0) {
          // Every 2nd row: mixed partial data
          comprehensiveTestData.add(['$i', i % 4 == 0 ? 'ITEM-$i' : '', i % 6 == 0 ? 'image-$i.jpg' : '', i % 8 == 0 ? '$i' : '', '', i % 12 == 0 ? '${i * 25}' : '', '', '', '', '', '', '', '', '', '', '', i % 14 == 0 ? 'بيانات جزئية $i' : '', '']);
        } else {
          // Remaining rows: minimal data (serial number only)
          comprehensiveTestData.add(['$i', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '']);
        }
      }

      // Add some completely empty rows at the end
      for (int i = 0; i < 5; i++) {
        comprehensiveTestData.add(['', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '']);
      }

      print('Comprehensive test data created with ${comprehensiveTestData.length} total rows');
      print('Expected data rows: ${comprehensiveTestData.length - 3} (excluding header rows)');

      // Test header detection
      final headerResult = ExcelParsingService.detectHeaders(comprehensiveTestData);
      expect(headerResult.headerRow, greaterThanOrEqualTo(0));

      // Test comprehensive data extraction
      final extractedData = ExcelParsingService.extractPackingListData(comprehensiveTestData, headerResult);

      print('Comprehensive extraction results:');
      print('Total rows in test data: ${comprehensiveTestData.length}');
      print('Header row: ${headerResult.headerRow}');
      print('Available data rows: ${comprehensiveTestData.length - headerResult.headerRow - 1}');
      print('Extracted items: ${extractedData.length}');

      // We should extract a very high percentage of rows (at least 80% since most have some data)
      final expectedMinimumItems = ((comprehensiveTestData.length - headerResult.headerRow - 1) * 0.8).round();
      expect(extractedData.length, greaterThanOrEqualTo(expectedMinimumItems));

      // Verify we're extracting different types of data
      int itemsWithItemNumber = 0;
      int itemsWithQuantity = 0;
      int itemsWithCartonData = 0;
      int itemsWithRemarks = 0;

      for (final item in extractedData) {
        if (item['item_number'] != null && item['item_number'].toString().isNotEmpty) itemsWithItemNumber++;
        if (item['total_quantity'] != null && item['total_quantity'] > 0) itemsWithQuantity++;
        if ((item['carton_count'] != null && item['carton_count'] > 0) ||
            (item['pieces_per_carton'] != null && item['pieces_per_carton'] > 0)) itemsWithCartonData++;
        if (item['remarks_a'] != null && item['remarks_a'].toString().length > 2) itemsWithRemarks++;
      }

      print('Data variety analysis:');
      print('Items with item numbers: $itemsWithItemNumber');
      print('Items with quantities: $itemsWithQuantity');
      print('Items with carton data: $itemsWithCartonData');
      print('Items with remarks: $itemsWithRemarks');

      // Ensure we're capturing different types of data
      expect(itemsWithItemNumber, greaterThan(0));
      expect(itemsWithQuantity, greaterThan(0));
      expect(itemsWithCartonData, greaterThan(0));
      expect(itemsWithRemarks, greaterThan(0));

      print('✅ Comprehensive extraction test passed - extracting diverse data types without limits');
    });
  });
}
