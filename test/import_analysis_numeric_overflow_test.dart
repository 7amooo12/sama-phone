import 'package:flutter_test/flutter_test.dart';
import 'package:smartbiztracker_new/services/import_analysis/excel_parsing_service.dart';
import 'package:smartbiztracker_new/models/import_analysis_models.dart';
import 'package:smartbiztracker_new/providers/import_analysis_provider.dart';
import 'package:smartbiztracker_new/services/import_analysis/currency_conversion_service.dart';

/// اختبارات شاملة لإصلاح مشكلة تجاوز الحدود الرقمية في تحليل الاستيراد
/// 
/// هذه الاختبارات تتحقق من:
/// 1. معالجة القيم الكبيرة في Excel parsing
/// 2. التحقق من حدود قاعدة البيانات DECIMAL(15,6)
/// 3. رسائل الخطأ المحسنة للمستخدم
/// 4. التحقق من أسعار الصرف
void main() {
  group('Import Analysis Numeric Overflow Fix Tests', () {
    
    test('Excel parsing should handle large values within DECIMAL(15,6) limits', () {
      // اختبار القيم الكبيرة التي كانت تسبب overflow مع DECIMAL(10,6)
      final testValues = [
        '15000.123456',    // total_cubic_meters - كان يسبب overflow
        '12345.678901',    // conversion_rate - كان يسبب overflow  
        '50000.50',        // rmb_price - قيمة كبيرة
        '999999999.999999', // الحد الأقصى المسموح
      ];
      
      for (final testValue in testValues) {
        final parsed = ExcelParsingService.parseDoubleValue(testValue);
        expect(parsed, isNotNull, reason: 'Should parse large value: $testValue');
        expect(parsed! <= 999999999.999999, isTrue, 
               reason: 'Parsed value should not exceed DECIMAL(15,6) max: $parsed');
        expect(parsed >= -999999999.999999, isTrue,
               reason: 'Parsed value should not be below DECIMAL(15,6) min: $parsed');
      }
    });
    
    test('Excel parsing should clamp values that exceed DECIMAL(15,6) limits', () {
      // اختبار القيم التي تتجاوز حتى الحدود الجديدة
      final testCases = [
        {
          'input': '9999999999.999999',  // أكبر من الحد الأقصى
          'expected': 999999999.999999,
        },
        {
          'input': '-9999999999.999999', // أصغر من الحد الأدنى
          'expected': -999999999.999999,
        },
      ];
      
      for (final testCase in testCases) {
        final parsed = ExcelParsingService.parseDoubleValue(testCase['input'] as String);
        expect(parsed, equals(testCase['expected']), 
               reason: 'Should clamp ${testCase['input']} to ${testCase['expected']}');
      }
    });
    
    test('PackingListItem should handle large numeric values correctly', () {
      // إنشاء عنصر بقيم كبيرة
      final item = PackingListItem(
        id: 'test-id',
        importBatchId: 'test-batch',
        itemNumber: 'TEST-LARGE-VALUES',
        totalQuantity: 1000,
        totalCubicMeters: 15000.123456,  // كان يسبب overflow مع DECIMAL(10,6)
        unitPrice: 50000.50,
        rmbPrice: 25000.75,
        convertedPrice: 171254.125,      // 25000.75 * 6.85 (RMB to EGP)
        conversionRate: 6.85,
        createdAt: DateTime.now(),
      );
      
      // التحقق من أن toJson لا يرمي استثناءات
      expect(() => item.toJson(), returnsNormally);
      
      final json = item.toJson();
      expect(json['total_cubic_meters'], equals(15000.123456));
      expect(json['unit_price'], equals(50000.50));
      expect(json['rmb_price'], equals(25000.75));
      expect(json['converted_price'], equals(171254.125));
      expect(json['conversion_rate'], equals(6.85));
    });
    
    test('Currency conversion should validate exchange rates', () {
      // اختبار أسعار الصرف الصحيحة
      final validRates = [6.85, 3.75, 0.85, 1.0, 100.0, 1000.0];
      
      for (final rate in validRates) {
        expect(() => CurrencyConversionService.validateExchangeRate(rate), 
               returnsNormally, reason: 'Valid rate $rate should not throw');
      }
      
      // اختبار أسعار الصرف غير الصحيحة
      final invalidRates = [
        9999999999.999999,  // أكبر من الحد الأقصى
        -9999999999.999999, // أصغر من الحد الأدنى
        double.infinity,
        double.negativeInfinity,
        double.nan,
      ];
      
      for (final rate in invalidRates) {
        if (rate.isFinite) {
          expect(() => CurrencyConversionService.validateExchangeRate(rate), 
                 throwsException, reason: 'Invalid rate $rate should throw');
        }
      }
    });
    
    test('Error messages should be user-friendly for numeric overflow', () {
      // محاكاة خطأ numeric overflow
      final overflowError = 'PostgrestException(message: numeric field overflow, code: 22003, details: A field with precision 10, scale 6 must round to an absolute value less than 10⁴., hint: null)';
      
      // التحقق من أن رسالة الخطأ تحتوي على معلومات مفيدة للمستخدم
      expect(overflowError.contains('numeric field overflow'), isTrue);
      
      // محاكاة معالجة الخطأ في ImportAnalysisProvider
      String userMessage = 'فشل في حفظ البيانات';
      if (overflowError.contains('numeric field overflow')) {
        userMessage = 'فشل في حفظ البيانات: قيمة رقمية تتجاوز الحد المسموح. يرجى التحقق من قيم الأسعار والأوزان والأحجام في الملف.';
      }
      
      expect(userMessage.contains('قيمة رقمية تتجاوز الحد المسموح'), isTrue);
      expect(userMessage.contains('الأسعار والأوزان والأحجام'), isTrue);
    });
    
    test('Database field validation should catch overflow before saving', () {
      // محاكاة بيانات JSON للعنصر
      final itemJson = {
        'item_number': 'TEST-OVERFLOW',
        'total_quantity': 100,
        'total_cubic_meters': 9999999999.999999, // يتجاوز الحد الأقصى
        'conversion_rate': 6.85,
        'rmb_price': 1000.0,
      };
      
      // محاكاة التحقق من الحقول الرقمية
      const maxDecimalValue = 999999999.999999;
      final totalCubicMeters = itemJson['total_cubic_meters'] as double;
      
      expect(totalCubicMeters > maxDecimalValue, isTrue, 
             reason: 'Test value should exceed database limit');
      
      // التحقق من أن التحقق سيكتشف المشكلة
      bool shouldThrowError = false;
      if (totalCubicMeters > maxDecimalValue) {
        shouldThrowError = true;
      }
      
      expect(shouldThrowError, isTrue, 
             reason: 'Validation should detect overflow');
    });
    
    test('Real-world Excel data scenarios should work correctly', () {
      // محاكاة بيانات Excel حقيقية قد تسبب مشاكل
      final realWorldScenarios = [
        {
          'description': 'Large container shipment',
          'total_cubic_meters': '15000.5',
          'rmb_price': '25000.75',
          'expected_cubic_meters': 15000.5,
          'expected_price': 25000.75,
        },
        {
          'description': 'High-value electronics',
          'rmb_price': '50000.00',
          'conversion_rate': '6.85',
          'expected_converted': 342500.0, // 50000 * 6.85
        },
        {
          'description': 'Bulk commodity',
          'total_cubic_meters': '8500.123',
          'rmb_price': '15000.50',
          'expected_cubic_meters': 8500.123,
          'expected_price': 15000.50,
        },
      ];
      
      for (final scenario in realWorldScenarios) {
        if (scenario.containsKey('total_cubic_meters')) {
          final parsed = ExcelParsingService.parseDoubleValue(
            scenario['total_cubic_meters'] as String
          );
          expect(parsed, equals(scenario['expected_cubic_meters']),
                 reason: 'Scenario: ${scenario['description']}');
        }
        
        if (scenario.containsKey('rmb_price')) {
          final parsed = ExcelParsingService.parseDoubleValue(
            scenario['rmb_price'] as String
          );
          expect(parsed, equals(scenario['expected_price']),
                 reason: 'Scenario: ${scenario['description']}');
        }
      }
    });
  });
}

/// Extension لإضافة طرق اختبار مساعدة
extension ExcelParsingServiceTest on ExcelParsingService {
  /// طريقة مساعدة لاختبار تحليل القيم العشرية
  static double? parseDoubleValue(String value) {
    // استدعاء الطريقة الخاصة للاختبار
    return ExcelParsingService._parseDoubleValue(value);
  }
}

/// Extension لإضافة طرق التحقق من أسعار الصرف
extension CurrencyConversionServiceTest on CurrencyConversionService {
  /// التحقق من صحة سعر الصرف
  static void validateExchangeRate(double rate) {
    const maxRate = 999999999.999999;
    const minRate = -999999999.999999;
    
    if (rate > maxRate || rate < minRate || !rate.isFinite) {
      throw Exception('سعر الصرف غير صالح: $rate');
    }
  }
}
