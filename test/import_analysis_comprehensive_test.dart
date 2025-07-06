import 'package:flutter_test/flutter_test.dart';
import 'package:smartbiztracker_new/services/import_analysis/excel_parsing_service.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

void main() {
  group('Import Analysis Comprehensive Tests', () {
    setUpAll(() {
      // تهيئة نظام السجلات للاختبار
      AppLogger.init(enableDebugMode: true);
    });

    test('should process large Excel file with 145+ rows correctly', () async {
      // إنشاء بيانات Excel محاكية لملف كبير (145 صف)
      final largeExcelData = _createLargeExcelData(145);
      
      print('🔍 اختبار معالجة ملف Excel كبير مع ${largeExcelData.length} صف');
      
      // اختبار كشف الرؤوس
      final headerResult = ExcelParsingService.detectHeaders(largeExcelData);
      
      expect(headerResult.headerRow, greaterThanOrEqualTo(0));
      expect(headerResult.confidence, greaterThan(0.3));
      expect(headerResult.mapping.containsKey('item_number'), isTrue);
      expect(headerResult.mapping.containsKey('total_quantity'), isTrue);
      expect(headerResult.mapping.containsKey('carton_count'), isTrue);
      expect(headerResult.mapping.containsKey('pieces_per_carton'), isTrue);
      expect(headerResult.mapping.containsKey('remarks_a'), isTrue);
      
      print('✅ كشف الرؤوس: صف ${headerResult.headerRow}, ثقة ${(headerResult.confidence * 100).toStringAsFixed(1)}%');
      print('📋 خريطة الأعمدة: ${headerResult.mapping}');
      
      // اختبار استخراج البيانات
      final extractedData = ExcelParsingService.extractPackingListData(largeExcelData, headerResult);
      
      // التحقق من أن جميع البيانات تم استخراجها
      final expectedDataRows = largeExcelData.length - headerResult.headerRow - 1;
      expect(extractedData.length, equals(expectedDataRows), 
        reason: 'يجب استخراج جميع صفوف البيانات (${extractedData.length} من $expectedDataRows)');
      
      print('📊 تم استخراج ${extractedData.length} عنصر من $expectedDataRows صف بيانات');
      
      // التحقق من صحة البيانات المستخرجة
      int validItems = 0;
      int itemsWithQuantity = 0;
      int itemsWithCartons = 0;
      int itemsWithPiecesPerCarton = 0;
      int itemsWithMaterials = 0;
      
      for (final item in extractedData) {
        // التحقق من وجود رقم الصنف
        if (item['item_number'] != null && item['item_number'].toString().isNotEmpty) {
          validItems++;
        }
        
        // التحقق من الكمية
        if (item['total_quantity'] != null && item['total_quantity'] > 0) {
          itemsWithQuantity++;
        }
        
        // التحقق من الكراتين
        if (item['carton_count'] != null && item['carton_count'] > 0) {
          itemsWithCartons++;
        }
        
        // التحقق من القطع لكل كرتون
        if (item['pieces_per_carton'] != null && item['pieces_per_carton'] > 0) {
          itemsWithPiecesPerCarton++;
        }
        
        // التحقق من المواد
        if (item['remarks_a'] != null && item['remarks_a'].toString().isNotEmpty) {
          itemsWithMaterials++;
        }
      }
      
      // التحقق من معدلات التغطية
      final validItemsRate = (validItems / extractedData.length * 100);
      final quantityRate = (itemsWithQuantity / extractedData.length * 100);
      final cartonsRate = (itemsWithCartons / extractedData.length * 100);
      final piecesRate = (itemsWithPiecesPerCarton / extractedData.length * 100);
      final materialsRate = (itemsWithMaterials / extractedData.length * 100);
      
      print('📈 إحصائيات التغطية:');
      print('   عناصر صحيحة: $validItems/${extractedData.length} (${validItemsRate.toStringAsFixed(1)}%)');
      print('   عناصر بكمية: $itemsWithQuantity/${extractedData.length} (${quantityRate.toStringAsFixed(1)}%)');
      print('   عناصر بكراتين: $itemsWithCartons/${extractedData.length} (${cartonsRate.toStringAsFixed(1)}%)');
      print('   عناصر بقطع/كرتون: $itemsWithPiecesPerCarton/${extractedData.length} (${piecesRate.toStringAsFixed(1)}%)');
      print('   عناصر بمواد: $itemsWithMaterials/${extractedData.length} (${materialsRate.toStringAsFixed(1)}%)');
      
      // التوقعات للجودة
      expect(validItemsRate, greaterThan(95), reason: 'يجب أن تكون نسبة العناصر الصحيحة أكثر من 95%');
      expect(quantityRate, greaterThan(90), reason: 'يجب أن تكون نسبة العناصر بكمية أكثر من 90%');
      expect(cartonsRate, greaterThan(80), reason: 'يجب أن تكون نسبة العناصر بكراتين أكثر من 80%');
      expect(piecesRate, greaterThan(80), reason: 'يجب أن تكون نسبة العناصر بقطع/كرتون أكثر من 80%');
      expect(materialsRate, greaterThan(70), reason: 'يجب أن تكون نسبة العناصر بمواد أكثر من 70%');
      
      // طباعة عينة من البيانات المستخرجة
      print('📋 عينة من البيانات المستخرجة:');
      for (int i = 0; i < extractedData.length && i < 5; i++) {
        final item = extractedData[i];
        print('   العنصر ${i + 1}:');
        print('     رقم الصنف: "${item['item_number']}"');
        print('     الكمية الإجمالية: ${item['total_quantity']}');
        print('     عدد الكراتين: ${item['carton_count']}');
        print('     قطع/كرتون: ${item['pieces_per_carton']}');
        print('     الملاحظات: "${item['remarks_a']}"');
      }
      
      print('🎉 اختبار الملف الكبير مكتمل بنجاح!');
    });

    test('should correctly map column headers with case variations', () {
      // اختبار مع تنويعات مختلفة لأسماء الأعمدة
      final testData = [
        ['S/NO', 'ITEM NO', 'picture', 'ctn', 'pc/ctn', 'QTY', 'REMARKS'],
        ['1', 'ABC001', 'img1.jpg', '10', '50', '500', 'مادة بلاستيكية (300) مادة معدنية (200)'],
        ['2', 'DEF002', 'img2.jpg', '5', '100', '500', 'مادة خشبية (250) مادة زجاجية (250)'],
      ];
      
      final headerResult = ExcelParsingService.detectHeaders(testData);
      
      expect(headerResult.mapping['carton_count'], equals(3)); // ctn column
      expect(headerResult.mapping['pieces_per_carton'], equals(4)); // pc/ctn column
      expect(headerResult.mapping['total_quantity'], equals(5)); // QTY column
      expect(headerResult.mapping['remarks_a'], equals(6)); // REMARKS column
      
      final extractedData = ExcelParsingService.extractPackingListData(testData, headerResult);
      
      expect(extractedData.length, equals(2));
      expect(extractedData[0]['carton_count'], equals(10));
      expect(extractedData[0]['pieces_per_carton'], equals(50));
      expect(extractedData[0]['total_quantity'], equals(500));
      expect(extractedData[0]['remarks_a'], contains('مادة بلاستيكية'));
    });
  });
}

/// إنشاء بيانات Excel محاكية لملف كبير
List<List<dynamic>> _createLargeExcelData(int totalRows) {
  final data = <List<dynamic>>[];
  
  // صف الرؤوس
  data.add(['S/NO', 'ITEM NO', 'picture', 'ctn', 'pc/ctn', 'QTY', 'size1', 'size2', 'size3', 't.cbm', 'N.W', 'G.W', 'T.NW', 'T.GW', 'PRICE', 'RMB', 'REMARKS']);
  
  // إنشاء صفوف البيانات
  for (int i = 1; i <= totalRows; i++) {
    final itemNumber = 'ITEM${i.toString().padLeft(3, '0')}';
    final cartons = (i % 20) + 1; // 1-20 كرتون
    final piecesPerCarton = ((i % 10) + 1) * 10; // 10-100 قطعة لكل كرتون
    final totalQuantity = cartons * piecesPerCarton;
    
    // إنشاء ملاحظات متنوعة مع مواد
    final materials = _generateMaterialsRemarks(i);
    
    data.add([
      i, // S/NO
      itemNumber, // ITEM NO
      'image$i.jpg', // picture
      cartons, // ctn
      piecesPerCarton, // pc/ctn
      totalQuantity, // QTY
      (i % 50) + 10, // size1
      (i % 30) + 5, // size2
      (i % 20) + 3, // size3
      (i * 0.1).toStringAsFixed(2), // t.cbm
      (i * 2.5).toStringAsFixed(1), // N.W
      (i * 3.0).toStringAsFixed(1), // G.W
      (cartons * i * 2.5).toStringAsFixed(1), // T.NW
      (cartons * i * 3.0).toStringAsFixed(1), // T.GW
      (i * 1.5).toStringAsFixed(2), // PRICE
      (i * 10.5).toStringAsFixed(2), // RMB
      materials, // REMARKS
    ]);
  }
  
  return data;
}

/// إنشاء ملاحظات متنوعة مع مواد
String _generateMaterialsRemarks(int index) {
  final materialTypes = [
    'مادة بلاستيكية',
    'مادة معدنية',
    'مادة خشبية',
    'مادة زجاجية',
    'مادة قماشية',
    'مادة مطاطية',
    'مادة سيراميكية',
    'مادة ورقية',
  ];
  
  final selectedMaterials = <String>[];
  final materialCount = (index % 3) + 1; // 1-3 مواد لكل عنصر
  
  for (int i = 0; i < materialCount; i++) {
    final materialIndex = (index + i) % materialTypes.length;
    final quantity = ((index + i) % 100) + 50; // 50-149 قطعة لكل مادة
    selectedMaterials.add('${materialTypes[materialIndex]} ($quantity)');
  }
  
  return selectedMaterials.join(' - ');
}
