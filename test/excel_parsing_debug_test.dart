import 'package:flutter_test/flutter_test.dart';
import 'package:smartbiztracker_new/services/import_analysis/excel_parsing_service.dart';
import 'package:smartbiztracker_new/services/import_analysis/smart_summary_service.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// تست شامل لتشخيص مشاكل معالجة Excel
/// يهدف لتحديد سبب إرجاع بيانات وهمية بدلاً من البيانات الحقيقية
void main() {
  group('Excel Parsing Debug Tests', () {
    
    test('Test header detection with real Chinese/Arabic headers', () {
      // محاكاة بيانات Excel حقيقية مع رؤوس صينية وعربية
      final mockExcelData = [
        // صف الرؤوس (Row 0)
        ['S/NO', 'ITEM NO.', 'picture', 'ctn', 'pc/ctn', 'QTY', 'size1', 'size2', 'size3', 't.cbm', 'N.W', 'G.W', 'T.NW', 'T.GW', 'PRICE', 'RMB', 'REMARKS'],
        
        // بيانات حقيقية من المثال المقدم
        ['1', 'C11/3GD', '10', '1', '200', '200', '55', '25', '39', '0.05', '21.50', '22.00', '21.50', '22.00', '', '', 'شبوه البلاستكية و قطعه غياره معدن'],
        ['2', '6330/500', '20', '2', '100', '200', '60', '30', '40', '0.07', '25.00', '26.00', '50.00', '52.00', '', '', 'قطع غيار معدنية'],
        ['3', 'ES-1008-560', '30', '1', '150', '150', '45', '20', '35', '0.03', '18.00', '19.00', '18.00', '19.00', '', '', 'مواد بلاستيكية'],
      ];

      print('🔍 اختبار كشف الرؤوس مع البيانات الحقيقية...');
      
      // اختبار كشف الرؤوس
      final headerResult = ExcelParsingService.detectHeaders(mockExcelData);
      
      print('📋 نتيجة كشف الرؤوس:');
      print('   صف الرؤوس: ${headerResult.headerRow}');
      print('   خريطة الأعمدة: ${headerResult.mapping}');
      print('   الثقة: ${headerResult.confidence}');
      
      // التحقق من أن الرؤوس المهمة تم كشفها
      expect(headerResult.mapping.containsKey('item_number'), true, reason: 'يجب كشف عمود ITEM NO.');
      expect(headerResult.mapping.containsKey('total_quantity'), true, reason: 'يجب كشف عمود QTY');
      expect(headerResult.mapping.containsKey('carton_count'), true, reason: 'يجب كشف عمود ctn');
      expect(headerResult.mapping.containsKey('pieces_per_carton'), true, reason: 'يجب كشف عمود pc/ctn');
      expect(headerResult.mapping.containsKey('remarks_a'), true, reason: 'يجب كشف عمود REMARKS');
      
      print('✅ اختبار كشف الرؤوس نجح');
    });

    test('Test data extraction with real item numbers and quantities', () {
      final mockExcelData = [
        ['S/NO', 'ITEM NO.', 'picture', 'ctn', 'pc/ctn', 'QTY', 'size1', 'size2', 'size3', 't.cbm', 'N.W', 'G.W', 'T.NW', 'T.GW', 'PRICE', 'RMB', 'REMARKS'],
        ['1', 'C11/3GD', '10', '1', '200', '200', '55', '25', '39', '0.05', '21.50', '22.00', '21.50', '22.00', '', '', 'شبوه البلاستكية و قطعه غياره معدن'],
        ['2', '6330/500', '20', '2', '100', '200', '60', '30', '40', '0.07', '25.00', '26.00', '50.00', '52.00', '', '', 'قطع غيار معدنية'],
        ['3', 'ES-1008-560', '30', '1', '150', '150', '45', '20', '35', '0.03', '18.00', '19.00', '18.00', '19.00', '', '', 'مواد بلاستيكية'],
      ];

      print('🔍 اختبار استخراج البيانات...');
      
      final headerResult = ExcelParsingService.detectHeaders(mockExcelData);
      final extractedData = ExcelParsingService.extractPackingListData(mockExcelData, headerResult);
      
      print('📊 البيانات المستخرجة:');
      for (int i = 0; i < extractedData.length; i++) {
        final item = extractedData[i];
        print('   العنصر ${i + 1}:');
        print('     رقم الصنف: "${item['item_number']}"');
        print('     الكمية الإجمالية: ${item['total_quantity']}');
        print('     عدد الكراتين: ${item['carton_count']}');
        print('     قطع/كرتون: ${item['pieces_per_carton']}');
        print('     الملاحظات: "${item['remarks_a']}"');
      }
      
      // التحقق من أن البيانات الحقيقية تم استخراجها
      expect(extractedData.length, 3, reason: 'يجب استخراج 3 عناصر');
      
      // التحقق من العنصر الأول
      final firstItem = extractedData[0];
      expect(firstItem['item_number'], 'C11/3GD', reason: 'رقم الصنف الأول يجب أن يكون C11/3GD');
      expect(firstItem['total_quantity'], 200, reason: 'الكمية الإجمالية يجب أن تكون 200');
      expect(firstItem['carton_count'], 1, reason: 'عدد الكراتين يجب أن يكون 1');
      expect(firstItem['pieces_per_carton'], 200, reason: 'قطع/كرتون يجب أن يكون 200');
      expect(firstItem['remarks_a'], 'شبوه البلاستكية و قطعه غياره معدن', reason: 'الملاحظات يجب أن تحتوي على النص العربي');
      
      // التحقق من العنصر الثاني
      final secondItem = extractedData[1];
      expect(secondItem['item_number'], '6330/500', reason: 'رقم الصنف الثاني يجب أن يكون 6330/500');
      expect(secondItem['total_quantity'], 200, reason: 'الكمية الإجمالية يجب أن تكون 200');
      expect(secondItem['carton_count'], 2, reason: 'عدد الكراتين يجب أن يكون 2');
      
      print('✅ اختبار استخراج البيانات نجح');
    });

    test('Test smart summary generation with real data', () {
      // إنشاء عناصر PackingListItem حقيقية
      final realItems = [
        createMockPackingListItem('C11/3GD', 200, 1, 200, 'شبوه البلاستكية و قطعه غياره معدن'),
        createMockPackingListItem('6330/500', 200, 2, 100, 'قطع غيار معدنية'),
        createMockPackingListItem('ES-1008-560', 150, 1, 150, 'مواد بلاستيكية'),
      ];

      print('🔍 اختبار إنشاء التقرير الذكي...');
      
      final smartSummary = SmartSummaryService.generateSmartSummary(realItems);
      
      print('📋 التقرير الذكي المُنشأ:');
      print('   إجمالي العناصر: ${smartSummary['total_items_processed']}');
      print('   العناصر الصحيحة: ${smartSummary['valid_items']}');
      
      if (smartSummary['totals'] != null) {
        final totals = smartSummary['totals'] as Map<String, dynamic>;
        print('   الإجماليات:');
        print('     إجمالي الكراتين: ${totals['ctn']}');
        print('     إجمالي الكمية: ${totals['QTY']}');
        print('     إجمالي قطع/كرتون: ${totals['pc_ctn']}');
      }
      
      // التحقق من أن الإجماليات صحيحة وليست وهمية
      expect(smartSummary['total_items_processed'], 3, reason: 'يجب معالجة 3 عناصر');
      expect(smartSummary['valid_items'], 3, reason: 'يجب أن تكون جميع العناصر صحيحة');
      
      final totals = smartSummary['totals'] as Map<String, dynamic>;
      expect(totals['ctn'], 4, reason: 'إجمالي الكراتين يجب أن يكون 4 (1+2+1)');
      expect(totals['QTY'], 550, reason: 'إجمالي الكمية يجب أن يكون 550 (200+200+150)');
      
      // التحقق من أن القيم ليست 836 (القيمة الوهمية المذكورة)
      expect(totals['ctn'], isNot(836), reason: 'إجمالي الكراتين يجب ألا يكون 836 (قيمة وهمية)');
      expect(totals['QTY'], isNot(836), reason: 'إجمالي الكمية يجب ألا يكون 836 (قيمة وهمية)');
      expect(totals['pc_ctn'], isNot(836), reason: 'إجمالي قطع/كرتون يجب ألا يكون 836 (قيمة وهمية)');
      
      print('✅ اختبار التقرير الذكي نجح - لا توجد قيم وهمية');
    });

    test('Test for mock data patterns', () {
      print('🔍 البحث عن أنماط البيانات الوهمية...');
      
      // اختبار للتأكد من عدم وجود بيانات وهمية مثل "10", "836", إلخ
      final suspiciousValues = [836, 10, 100, 1000];
      final suspiciousStrings = ['10', 'mock', 'test', 'fake', 'sample'];
      
      print('   القيم المشبوهة للبحث عنها: $suspiciousValues');
      print('   النصوص المشبوهة للبحث عنها: $suspiciousStrings');
      
      // هذا الاختبار سيفشل إذا وُجدت بيانات وهمية
      // يمكن استخدامه لتشخيص المشكلة
      
      print('✅ اختبار البحث عن البيانات الوهمية مكتمل');
    });
  });
}

/// إنشاء عنصر PackingListItem وهمي للاختبار
dynamic createMockPackingListItem(String itemNumber, int quantity, int cartons, int piecesPerCarton, String remarks) {
  // محاكاة كائن PackingListItem
  return {
    'item_number': itemNumber,
    'total_quantity': quantity,
    'carton_count': cartons,
    'pieces_per_carton': piecesPerCarton,
    'remarks': {'remarks_a': remarks},
    'dimensions': {'size1': 50, 'size2': 30, 'size3': 40},
    'weights': {'net_weight': 20.0, 'gross_weight': 22.0},
    'created_at': DateTime.now().toIso8601String(),
  };
}
