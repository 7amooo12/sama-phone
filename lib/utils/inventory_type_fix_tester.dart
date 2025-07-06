/// اختبار إصلاحات أنواع البيانات في نظام المخزون
/// Inventory Type Fix Tester
/// 
/// يختبر الإصلاحات المطبقة لحل مشاكل "operator does not exist: text = uuid"

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smartbiztracker_new/services/warehouse_service.dart';
import 'package:smartbiztracker_new/services/global_inventory_service.dart';
import 'package:smartbiztracker_new/services/intelligent_inventory_deduction_service.dart';
import 'package:smartbiztracker_new/models/dispatch_product_processing_model.dart';
import 'package:smartbiztracker_new/models/global_inventory_models.dart';
import 'package:smartbiztracker_new/utils/database_type_validator.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

class InventoryTypeFixTester {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static final WarehouseService _warehouseService = WarehouseService();
  static final GlobalInventoryService _globalInventoryService = GlobalInventoryService();
  static final IntelligentInventoryDeductionService _deductionService = IntelligentInventoryDeductionService();

  /// تشغيل جميع اختبارات إصلاحات أنواع البيانات
  static Future<Map<String, dynamic>> runAllTests() async {
    try {
      AppLogger.info('🧪 === بدء اختبارات إصلاحات أنواع البيانات ===');

      final results = <String, dynamic>{
        'timestamp': DateTime.now().toIso8601String(),
        'tests': <String, dynamic>{},
        'overall_success': false,
        'summary': <String, dynamic>{},
      };

      // اختبار 1: التحقق من دوال التحقق من أنواع البيانات
      results['tests']['type_validation'] = await _testTypeValidation();

      // اختبار 2: اختبار استعلامات المخزون
      results['tests']['warehouse_queries'] = await _testWarehouseQueries();

      // اختبار 3: اختبار البحث العالمي
      results['tests']['global_search'] = await _testGlobalSearch();

      // اختبار 4: اختبار خصم المخزون
      results['tests']['inventory_deduction'] = await _testInventoryDeduction();

      // اختبار 5: اختبار دالة قاعدة البيانات
      results['tests']['database_function'] = await _testDatabaseFunction();

      // حساب النتائج الإجمالية
      final testResults = results['tests'] as Map<String, dynamic>;
      final successCount = testResults.values.where((test) => test['success'] == true).length;
      final totalTests = testResults.length;

      results['overall_success'] = successCount == totalTests;
      results['summary'] = {
        'total_tests': totalTests,
        'successful_tests': successCount,
        'failed_tests': totalTests - successCount,
        'success_rate': totalTests > 0 ? (successCount / totalTests * 100).toStringAsFixed(1) : '0.0',
      };

      AppLogger.info('📊 نتائج الاختبارات:');
      AppLogger.info('   إجمالي الاختبارات: $totalTests');
      AppLogger.info('   نجح: $successCount');
      AppLogger.info('   فشل: ${totalTests - successCount}');
      AppLogger.info('   معدل النجاح: ${results['summary']['success_rate']}%');

      return results;
    } catch (e) {
      AppLogger.error('❌ خطأ في تشغيل اختبارات إصلاحات أنواع البيانات: $e');
      return {
        'timestamp': DateTime.now().toIso8601String(),
        'overall_success': false,
        'error': e.toString(),
      };
    }
  }

  /// اختبار دوال التحقق من أنواع البيانات
  static Future<Map<String, dynamic>> _testTypeValidation() async {
    try {
      AppLogger.info('🔍 اختبار دوال التحقق من أنواع البيانات...');

      final results = <String, dynamic>{
        'success': true,
        'tests': <String, dynamic>{},
        'errors': <String>[],
      };

      // اختبار معرفات المخازن الصحيحة
      final validWarehouseIds = [
        '123e4567-e89b-12d3-a456-426614174000',
        'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
      ];

      for (final id in validWarehouseIds) {
        try {
          final isValid = DatabaseTypeValidator.isValidWarehouseId(id);
          final formatted = DatabaseTypeValidator.ensureWarehouseIdFormat(id);
          results['tests']['valid_warehouse_$id'] = {
            'success': isValid && formatted.isNotEmpty,
            'is_valid': isValid,
            'formatted': formatted,
          };
        } catch (e) {
          results['tests']['valid_warehouse_$id'] = {'success': false, 'error': e.toString()};
          results['errors'].add('فشل في التحقق من معرف المخزن الصحيح: $id - $e');
        }
      }

      // اختبار معرفات المخازن غير الصحيحة
      final invalidWarehouseIds = ['invalid-id', '123', '', 'not-a-uuid'];

      for (final id in invalidWarehouseIds) {
        try {
          final isValid = DatabaseTypeValidator.isValidWarehouseId(id);
          results['tests']['invalid_warehouse_$id'] = {
            'success': !isValid, // يجب أن يكون false
            'is_valid': isValid,
          };
          
          if (isValid) {
            results['errors'].add('معرف المخزن غير الصحيح تم قبوله: $id');
          }
        } catch (e) {
          results['tests']['invalid_warehouse_$id'] = {'success': true, 'expected_error': true};
        }
      }

      // اختبار معرفات المنتجات
      final validProductIds = ['1007', '500', 'PROD-123', 'product_id_test'];
      final invalidProductIds = ['', '   ', null];

      for (final id in validProductIds) {
        try {
          final isValid = DatabaseTypeValidator.isValidProductId(id);
          final formatted = DatabaseTypeValidator.ensureProductIdFormat(id);
          results['tests']['valid_product_$id'] = {
            'success': isValid && formatted.isNotEmpty,
            'is_valid': isValid,
            'formatted': formatted,
          };
        } catch (e) {
          results['tests']['valid_product_$id'] = {'success': false, 'error': e.toString()};
          results['errors'].add('فشل في التحقق من معرف المنتج الصحيح: $id - $e');
        }
      }

      for (final id in invalidProductIds) {
        try {
          final isValid = DatabaseTypeValidator.isValidProductId(id ?? '');
          results['tests']['invalid_product_${id ?? 'null'}'] = {
            'success': !isValid, // يجب أن يكون false
            'is_valid': isValid,
          };
          
          if (isValid) {
            results['errors'].add('معرف المنتج غير الصحيح تم قبوله: $id');
          }
        } catch (e) {
          results['tests']['invalid_product_${id ?? 'null'}'] = {'success': true, 'expected_error': true};
        }
      }

      // تحديد النجاح الإجمالي
      final testResults = results['tests'] as Map<String, dynamic>;
      final failedTests = testResults.values.where((test) => test['success'] != true).length;
      results['success'] = failedTests == 0;

      AppLogger.info('✅ اختبار دوال التحقق مكتمل - النجاح: ${results['success']}');
      return results;
    } catch (e) {
      AppLogger.error('❌ خطأ في اختبار دوال التحقق: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// اختبار استعلامات المخزون
  static Future<Map<String, dynamic>> _testWarehouseQueries() async {
    try {
      AppLogger.info('🏢 اختبار استعلامات المخزون...');

      final results = <String, dynamic>{
        'success': true,
        'tests': <String, dynamic>{},
        'errors': <String>[],
      };

      // الحصول على مخزن للاختبار
      final warehouses = await _warehouseService.getWarehouses();
      if (warehouses.isEmpty) {
        results['success'] = false;
        results['errors'].add('لا توجد مخازن متاحة للاختبار');
        return results;
      }

      final testWarehouse = warehouses.first;
      AppLogger.info('📦 استخدام المخزن للاختبار: ${testWarehouse.name} (${testWarehouse.id})');

      // اختبار getWarehouseInventory
      try {
        final inventory = await _warehouseService.getWarehouseInventory(testWarehouse.id);
        results['tests']['get_warehouse_inventory'] = {
          'success': true,
          'inventory_count': inventory.length,
        };
        AppLogger.info('✅ getWarehouseInventory نجح - ${inventory.length} عنصر');
      } catch (e) {
        results['tests']['get_warehouse_inventory'] = {'success': false, 'error': e.toString()};
        results['errors'].add('فشل في getWarehouseInventory: $e');
        
        if (DatabaseTypeValidator.isTypeRelatedError(e.toString())) {
          results['errors'].add('⚠️ خطأ مرتبط بأنواع البيانات في getWarehouseInventory');
        }
      }

      // اختبار getWarehouseStatistics
      try {
        final stats = await _warehouseService.getWarehouseStatistics(testWarehouse.id);
        results['tests']['get_warehouse_statistics'] = {
          'success': true,
          'stats': stats,
        };
        AppLogger.info('✅ getWarehouseStatistics نجح');
      } catch (e) {
        results['tests']['get_warehouse_statistics'] = {'success': false, 'error': e.toString()};
        results['errors'].add('فشل في getWarehouseStatistics: $e');
      }

      // تحديد النجاح الإجمالي
      final testResults = results['tests'] as Map<String, dynamic>;
      final failedTests = testResults.values.where((test) => test['success'] != true).length;
      results['success'] = failedTests == 0;

      AppLogger.info('✅ اختبار استعلامات المخزون مكتمل - النجاح: ${results['success']}');
      return results;
    } catch (e) {
      AppLogger.error('❌ خطأ في اختبار استعلامات المخزون: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// اختبار البحث العالمي
  static Future<Map<String, dynamic>> _testGlobalSearch() async {
    try {
      AppLogger.info('🌍 اختبار البحث العالمي...');

      final results = <String, dynamic>{
        'success': true,
        'tests': <String, dynamic>{},
        'errors': <String>[],
      };

      // البحث عن منتج للاختبار
      final testProductIds = ['1007', '500', '15'];

      for (final productId in testProductIds) {
        try {
          final searchResult = await _globalInventoryService.searchProductGlobally(
            productId: productId,
            requestedQuantity: 1,
          );

          results['tests']['global_search_$productId'] = {
            'success': true,
            'can_fulfill': searchResult.canFulfill,
            'total_available': searchResult.totalAvailableQuantity,
            'warehouses_count': searchResult.availableWarehouses.length,
          };

          AppLogger.info('✅ البحث العالمي للمنتج $productId نجح - متاح: ${searchResult.totalAvailableQuantity}');
        } catch (e) {
          results['tests']['global_search_$productId'] = {'success': false, 'error': e.toString()};
          results['errors'].add('فشل في البحث العالمي للمنتج $productId: $e');
          
          if (DatabaseTypeValidator.isTypeRelatedError(e.toString())) {
            results['errors'].add('⚠️ خطأ مرتبط بأنواع البيانات في البحث العالمي للمنتج $productId');
          }
        }
      }

      // تحديد النجاح الإجمالي
      final testResults = results['tests'] as Map<String, dynamic>;
      final failedTests = testResults.values.where((test) => test['success'] != true).length;
      results['success'] = failedTests == 0;

      AppLogger.info('✅ اختبار البحث العالمي مكتمل - النجاح: ${results['success']}');
      return results;
    } catch (e) {
      AppLogger.error('❌ خطأ في اختبار البحث العالمي: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// اختبار خصم المخزون
  static Future<Map<String, dynamic>> _testInventoryDeduction() async {
    try {
      AppLogger.info('📦 اختبار خصم المخزون...');

      final results = <String, dynamic>{
        'success': true,
        'tests': <String, dynamic>{},
        'errors': <String>[],
      };

      // الحصول على مستخدم للاختبار
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        results['success'] = false;
        results['errors'].add('لا يوجد مستخدم مسجل دخول للاختبار');
        return results;
      }

      // إنشاء منتج وهمي للاختبار
      final testProduct = DispatchProductProcessingModel.fromDispatchItem(
        itemId: 'test-item-${DateTime.now().millisecondsSinceEpoch}',
        requestId: 'test-request-${DateTime.now().millisecondsSinceEpoch}',
        productId: '1007', // منتج معروف للاختبار
        productName: 'منتج اختبار إصلاحات أنواع البيانات',
        quantity: 1,
        notes: 'اختبار إصلاحات أنواع البيانات',
      );

      // اختبار فحص إمكانية الخصم
      try {
        final feasibilityCheck = await _deductionService.checkDeductionFeasibility(
          product: testProduct,
          strategy: WarehouseSelectionStrategy.balanced,
        );

        results['tests']['deduction_feasibility'] = {
          'success': true,
          'can_fulfill': feasibilityCheck.canFulfill,
          'available_quantity': feasibilityCheck.availableQuantity,
          'available_warehouses': feasibilityCheck.availableWarehouses,
        };

        AppLogger.info('✅ فحص إمكانية الخصم نجح - يمكن التلبية: ${feasibilityCheck.canFulfill}');
      } catch (e) {
        results['tests']['deduction_feasibility'] = {'success': false, 'error': e.toString()};
        results['errors'].add('فشل في فحص إمكانية الخصم: $e');

        if (DatabaseTypeValidator.isTypeRelatedError(e.toString())) {
          results['errors'].add('⚠️ خطأ مرتبط بأنواع البيانات في فحص إمكانية الخصم');
        }
      }

      // تحديد النجاح الإجمالي
      final testResults = results['tests'] as Map<String, dynamic>;
      final failedTests = testResults.values.where((test) => test['success'] != true).length;
      results['success'] = failedTests == 0;

      AppLogger.info('✅ اختبار خصم المخزون مكتمل - النجاح: ${results['success']}');
      return results;
    } catch (e) {
      AppLogger.error('❌ خطأ في اختبار خصم المخزون: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// اختبار دالة قاعدة البيانات
  static Future<Map<String, dynamic>> _testDatabaseFunction() async {
    try {
      AppLogger.info('🗄️ اختبار دالة قاعدة البيانات...');

      final results = <String, dynamic>{
        'success': true,
        'tests': <String, dynamic>{},
        'errors': <String>[],
      };

      // أولاً: التحقق من وجود الدالة
      try {
        final functionCheck = await _supabase.rpc('pg_get_function_identity_arguments', params: {
          'funcid': 'deduct_inventory_with_validation'
        });

        results['tests']['function_exists'] = {
          'success': functionCheck != null,
          'function_signature': functionCheck,
        };

        AppLogger.info('🔍 دالة قاعدة البيانات موجودة: ${functionCheck != null}');
      } catch (e) {
        AppLogger.info('⚠️ لا يمكن التحقق من وجود الدالة: $e');
        results['tests']['function_exists'] = {'success': false, 'error': e.toString()};
      }

      // الحصول على مستخدم للاختبار
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        results['success'] = false;
        results['errors'].add('لا يوجد مستخدم مسجل دخول للاختبار');
        return results;
      }

      // الحصول على مخزن ومنتج للاختبار
      final warehouses = await _warehouseService.getWarehouses();
      if (warehouses.isEmpty) {
        results['success'] = false;
        results['errors'].add('لا توجد مخازن متاحة للاختبار');
        return results;
      }

      final testWarehouse = warehouses.first;
      final inventory = await _warehouseService.getWarehouseInventory(testWarehouse.id);

      if (inventory.isEmpty) {
        results['tests']['database_function'] = {
          'success': true,
          'note': 'لا توجد منتجات في المخزون للاختبار - تم تخطي اختبار دالة قاعدة البيانات',
        };
        return results;
      }

      final testInventoryItem = inventory.first;

      // اختبار دالة deduct_inventory_with_validation مع كمية صفر (اختبار آمن)
      try {
        AppLogger.info('🧪 اختبار دالة الخصم مع المعاملات:');
        AppLogger.info('   warehouse_id: ${testWarehouse.id}');
        AppLogger.info('   product_id: ${testInventoryItem.productId}');
        AppLogger.info('   quantity: 0');
        AppLogger.info('   performed_by: ${currentUser.id}');

        final response = await _supabase.rpc(
          'deduct_inventory_with_validation',
          params: {
            'p_warehouse_id': testWarehouse.id,
            'p_product_id': testInventoryItem.productId,
            'p_quantity': 0, // كمية صفر للاختبار الآمن
            'p_performed_by': currentUser.id,
            'p_reason': 'اختبار إصلاحات أنواع البيانات',
            'p_reference_id': 'type-fix-test-${DateTime.now().millisecondsSinceEpoch}',
            'p_reference_type': 'type_fix_test',
          },
        );

        results['tests']['database_function'] = {
          'success': response != null,
          'response': response,
          'warehouse_id_type': 'UUID',
          'product_id_type': 'TEXT',
        };

        AppLogger.info('✅ اختبار دالة قاعدة البيانات نجح');
        AppLogger.info('📤 استجابة الدالة: $response');
      } catch (e) {
        results['tests']['database_function'] = {'success': false, 'error': e.toString()};
        results['errors'].add('فشل في اختبار دالة قاعدة البيانات: $e');

        AppLogger.error('❌ خطأ في دالة قاعدة البيانات: $e');

        if (DatabaseTypeValidator.isTypeRelatedError(e.toString())) {
          results['errors'].add('⚠️ خطأ مرتبط بأنواع البيانات في دالة قاعدة البيانات');
          results['success'] = false; // هذا خطأ حرج
        }
      }

      AppLogger.info('✅ اختبار دالة قاعدة البيانات مكتمل - النجاح: ${results['success']}');
      return results;
    } catch (e) {
      AppLogger.error('❌ خطأ في اختبار دالة قاعدة البيانات: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// إنشاء تقرير مفصل عن نتائج الاختبارات
  static String generateTestReport(Map<String, dynamic> results) {
    final buffer = StringBuffer();

    buffer.writeln('📋 تقرير اختبارات إصلاحات أنواع البيانات');
    buffer.writeln('=' * 50);
    buffer.writeln('التاريخ: ${results['timestamp']}');
    buffer.writeln('النجاح الإجمالي: ${results['overall_success'] ? "✅ نعم" : "❌ لا"}');

    if (results['summary'] != null) {
      final summary = results['summary'] as Map<String, dynamic>;
      buffer.writeln('\nملخص النتائج:');
      buffer.writeln('  إجمالي الاختبارات: ${summary['total_tests']}');
      buffer.writeln('  نجح: ${summary['successful_tests']}');
      buffer.writeln('  فشل: ${summary['failed_tests']}');
      buffer.writeln('  معدل النجاح: ${summary['success_rate']}%');
    }

    if (results['tests'] != null) {
      buffer.writeln('\nتفاصيل الاختبارات:');
      final tests = results['tests'] as Map<String, dynamic>;

      for (final entry in tests.entries) {
        final testName = entry.key;
        final testResult = entry.value as Map<String, dynamic>;
        final success = testResult['success'] == true;

        buffer.writeln('  $testName: ${success ? "✅ نجح" : "❌ فشل"}');

        if (!success && testResult['error'] != null) {
          buffer.writeln('    الخطأ: ${testResult['error']}');
        }
      }
    }

    return buffer.toString();
  }
}
