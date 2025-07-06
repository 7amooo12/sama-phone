/// أداة اختبار خصم المخزون المدمجة
/// Integrated Inventory Deduction Tester

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smartbiztracker_new/models/dispatch_product_processing_model.dart';
import 'package:smartbiztracker_new/models/global_inventory_models.dart';
import 'package:smartbiztracker_new/services/intelligent_inventory_deduction_service.dart';
import 'package:smartbiztracker_new/services/global_inventory_service.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

class InventoryDeductionTester {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static final IntelligentInventoryDeductionService _deductionService = IntelligentInventoryDeductionService();
  static final GlobalInventoryService _globalService = GlobalInventoryService();

  /// تشغيل اختبار شامل لخصم المخزون
  static Future<Map<String, dynamic>> runComprehensiveTest() async {
    final results = <String, dynamic>{
      'success': false,
      'tests': <String, dynamic>{},
      'errors': <String>[],
      'summary': '',
    };

    try {
      AppLogger.info('🔄 بدء الاختبار الشامل لخصم المخزون...');

      // Test 1: Database Connection
      results['tests']['database_connection'] = await _testDatabaseConnection();
      
      // Test 2: User Authentication
      results['tests']['user_authentication'] = await _testUserAuthentication();
      
      // Test 3: Database Functions
      results['tests']['database_functions'] = await _testDatabaseFunctions();
      
      // Test 4: Product Search
      results['tests']['product_search'] = await _testProductSearch();
      
      // Test 5: Direct Database Call
      results['tests']['direct_database_call'] = await _testDirectDatabaseCall();
      
      // Test 6: Service Layer Test
      results['tests']['service_layer'] = await _testServiceLayer();

      // Calculate overall success
      final allTestsPassed = results['tests'].values.every((test) => test['success'] == true);
      results['success'] = allTestsPassed;
      
      // Generate summary
      results['summary'] = _generateTestSummary(results['tests']);
      
      AppLogger.info('✅ اكتمل الاختبار الشامل');
      
    } catch (e) {
      results['errors'].add('خطأ عام في الاختبار: $e');
      AppLogger.error('❌ خطأ في الاختبار الشامل: $e');
    }

    return results;
  }

  static Future<Map<String, dynamic>> _testDatabaseConnection() async {
    try {
      AppLogger.info('📡 اختبار الاتصال بقاعدة البيانات...');
      
      final response = await _supabase
          .from('warehouses')
          .select('id, name')
          .limit(1);
      
      return {
        'success': true,
        'message': 'الاتصال بقاعدة البيانات يعمل',
        'data': {'warehouse_count': response.length},
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'فشل الاتصال بقاعدة البيانات',
        'error': e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> _testUserAuthentication() async {
    try {
      AppLogger.info('👤 اختبار المصادقة...');
      
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'message': 'لا يوجد مستخدم مسجل دخول',
        };
      }

      final profile = await _supabase
          .from('user_profiles')
          .select('id, role, status, email')
          .eq('id', user.id)
          .single();

      final isAuthorized = ['admin', 'owner', 'warehouseManager', 'accountant'].contains(profile['role']);
      final isApproved = profile['status'] == 'approved';

      return {
        'success': isAuthorized && isApproved,
        'message': isAuthorized && isApproved 
            ? 'المستخدم مصادق ومخول'
            : 'المستخدم غير مخول أو غير موافق عليه',
        'data': {
          'user_id': user.id,
          'role': profile['role'],
          'status': profile['status'],
          'email': profile['email'],
          'authorized': isAuthorized,
          'approved': isApproved,
        },
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'خطأ في فحص المصادقة',
        'error': e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> _testDatabaseFunctions() async {
    try {
      AppLogger.info('🔧 اختبار دوال قاعدة البيانات...');
      
      final results = <String, bool>{};
      
      // Test deduct_inventory_with_validation
      try {
        await _supabase.rpc('deduct_inventory_with_validation', params: {
          'p_warehouse_id': 'test-id',
          'p_product_id': 'test-id',
          'p_quantity': 0,
          'p_performed_by': 'test-user',
          'p_reason': 'Test function existence',
        });
        results['deduct_inventory_with_validation'] = true;
      } catch (e) {
        results['deduct_inventory_with_validation'] = !e.toString().contains('does not exist');
      }
      
      // Test search_product_globally
      try {
        await _supabase.rpc('search_product_globally', params: {
          'p_product_id': 'test-id',
          'p_requested_quantity': 1,
        });
        results['search_product_globally'] = true;
      } catch (e) {
        results['search_product_globally'] = !e.toString().contains('does not exist');
      }

      final allFunctionsExist = results.values.every((exists) => exists);

      return {
        'success': allFunctionsExist,
        'message': allFunctionsExist 
            ? 'جميع دوال قاعدة البيانات موجودة'
            : 'بعض دوال قاعدة البيانات مفقودة',
        'data': results,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'خطأ في اختبار دوال قاعدة البيانات',
        'error': e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> _testProductSearch() async {
    try {
      AppLogger.info('🔍 اختبار البحث عن المنتجات...');
      
      // Get a real product
      final products = await _supabase
          .from('warehouse_inventory')
          .select('product_id, quantity, warehouse_id')
          .gt('quantity', 0)
          .limit(1);

      if (products.isEmpty) {
        return {
          'success': false,
          'message': 'لا توجد منتجات في المخزون للاختبار',
        };
      }

      final testProduct = products.first;
      final productId = testProduct['product_id'];

      // Test global search
      final searchResult = await _globalService.searchProductGlobally(
        productId: productId,
        requestedQuantity: 1,
      );

      return {
        'success': true,
        'message': 'البحث العالمي نجح',
        'data': {
          'product_id': productId,
          'total_available': searchResult.totalAvailableQuantity,
          'can_fulfill': searchResult.canFulfill,
          'warehouses_count': searchResult.availableWarehouses.length,
        },
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'فشل البحث عن المنتجات',
        'error': e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> _testDirectDatabaseCall() async {
    try {
      AppLogger.info('⚡ اختبار استدعاء دالة قاعدة البيانات مباشرة...');
      
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'message': 'لا يوجد مستخدم مسجل دخول',
        };
      }

      // Get a real warehouse and product with sufficient stock
      final inventory = await _supabase
          .from('warehouse_inventory')
          .select('warehouse_id, product_id, quantity')
          .gt('quantity', 5)
          .limit(1);

      if (inventory.isEmpty) {
        return {
          'success': false,
          'message': 'لا توجد منتجات كافية للاختبار',
        };
      }

      final testItem = inventory.first;

      // Call the database function directly
      final result = await _supabase.rpc(
        'deduct_inventory_with_validation',
        params: {
          'p_warehouse_id': testItem['warehouse_id'],
          'p_product_id': testItem['product_id'],
          'p_quantity': 1,
          'p_performed_by': user.id,
          'p_reason': 'اختبار تشخيص خصم المخزون',
          'p_reference_id': 'debug-test-${DateTime.now().millisecondsSinceEpoch}',
          'p_reference_type': 'debug_test',
        },
      );

      final success = result['success'] == true;

      return {
        'success': success,
        'message': success 
            ? 'استدعاء دالة قاعدة البيانات نجح'
            : 'فشل استدعاء دالة قاعدة البيانات',
        'data': {
          'warehouse_id': testItem['warehouse_id'],
          'product_id': testItem['product_id'],
          'original_quantity': testItem['quantity'],
          'deduction_result': result,
        },
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'خطأ في استدعاء دالة قاعدة البيانات',
        'error': e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> _testServiceLayer() async {
    try {
      AppLogger.info('🔄 اختبار طبقة الخدمات...');
      
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'message': 'لا يوجد مستخدم مسجل دخول',
        };
      }

      // Get a real product with sufficient stock
      final inventory = await _supabase
          .from('warehouse_inventory')
          .select('''
            warehouse_id,
            product_id,
            quantity,
            warehouse:warehouses!inner(name),
            product:products!inner(name)
          ''')
          .gt('quantity', 3)
          .limit(1);

      if (inventory.isEmpty) {
        return {
          'success': false,
          'message': 'لا توجد منتجات كافية للاختبار',
        };
      }

      final testItem = inventory.first;
      final productName = testItem['product']['name'] ?? 'منتج غير معروف';

      // Create a mock dispatch product
      final mockProduct = DispatchProductProcessingModel.fromDispatchItem(
        itemId: 'debug-test-${DateTime.now().millisecondsSinceEpoch}',
        requestId: 'debug-request-${DateTime.now().millisecondsSinceEpoch}',
        productId: testItem['product_id'],
        productName: productName,
        quantity: 2,
        notes: 'اختبار تشخيص خصم المخزون',
      );

      // Test the full deduction flow
      final result = await _deductionService.deductProductInventory(
        product: mockProduct,
        performedBy: user.id,
        requestId: mockProduct.requestId,
        strategy: WarehouseSelectionStrategy.balanced,
      );

      return {
        'success': result.success,
        'message': result.success 
            ? 'طبقة الخدمات تعمل بشكل صحيح'
            : 'فشل في طبقة الخدمات',
        'data': {
          'product_name': productName,
          'requested_quantity': result.totalRequestedQuantity,
          'deducted_quantity': result.totalDeductedQuantity,
          'warehouses_affected': result.warehouseResults.length,
          'errors': result.errors,
        },
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'خطأ في طبقة الخدمات',
        'error': e.toString(),
      };
    }
  }

  static String _generateTestSummary(Map<String, dynamic> tests) {
    final buffer = StringBuffer();
    buffer.writeln('📊 ملخص نتائج الاختبار:');
    buffer.writeln('');

    for (final entry in tests.entries) {
      final testName = entry.key;
      final testResult = entry.value;
      final success = testResult['success'] == true;
      final icon = success ? '✅' : '❌';
      final message = testResult['message'] ?? 'لا توجد رسالة';
      
      buffer.writeln('$icon $testName: $message');
      
      if (!success && testResult['error'] != null) {
        buffer.writeln('   خطأ: ${testResult['error']}');
      }
    }

    final passedTests = tests.values.where((test) => test['success'] == true).length;
    final totalTests = tests.length;
    
    buffer.writeln('');
    buffer.writeln('📈 النتيجة الإجمالية: $passedTests/$totalTests اختبار نجح');
    
    if (passedTests == totalTests) {
      buffer.writeln('🎉 جميع الاختبارات نجحت! نظام خصم المخزون يعمل بشكل صحيح.');
    } else {
      buffer.writeln('⚠️ بعض الاختبارات فشلت. يرجى مراجعة الأخطاء أعلاه.');
    }

    return buffer.toString();
  }

  /// اختبار سريع لخصم منتج واحد
  static Future<bool> quickDeductionTest({
    required String productId,
    required String warehouseId,
    required int quantity,
    required String performedBy,
    String? reason,
  }) async {
    try {
      AppLogger.info('⚡ اختبار خصم سريع...');

      final result = await _supabase.rpc(
        'deduct_inventory_with_validation',
        params: {
          'p_warehouse_id': warehouseId,
          'p_product_id': productId,
          'p_quantity': quantity,
          'p_performed_by': performedBy,
          'p_reason': reason ?? 'اختبار خصم سريع',
          'p_reference_id': 'quick-test-${DateTime.now().millisecondsSinceEpoch}',
          'p_reference_type': 'quick_test',
        },
      );

      final success = result['success'] == true;

      if (success) {
        AppLogger.info('✅ الاختبار السريع نجح');
      } else {
        AppLogger.error('❌ الاختبار السريع فشل: ${result['error']}');
      }

      return success;
    } catch (e) {
      AppLogger.error('❌ خطأ في الاختبار السريع: $e');
      return false;
    }
  }

  /// اختبار مخصص للمنتج 1007/500
  static Future<Map<String, dynamic>> debugProduct1007() async {
    final results = <String, dynamic>{
      'success': false,
      'product_found': false,
      'inventory_available': false,
      'deduction_test': false,
      'errors': <String>[],
      'details': <String, dynamic>{},
    };

    try {
      AppLogger.info('🔍 بدء تشخيص المنتج 1007/500...');

      // 1. البحث عن المنتج في جدول المنتجات
      try {
        final productQuery = await _supabase
            .from('products')
            .select('id, name, sku, category, active')
            .or('id.eq.1007,name.ilike.%1007%,sku.ilike.%1007%,name.ilike.%500%');

        AppLogger.info('📦 نتائج البحث عن المنتج: ${productQuery.length} منتج');

        if (productQuery.isNotEmpty) {
          results['product_found'] = true;
          results['details']['products'] = productQuery;
          AppLogger.info('✅ تم العثور على المنتج');

          for (final product in productQuery) {
            AppLogger.info('   المنتج: ${product['id']} - ${product['name']} (${product['sku']})');
          }
        } else {
          results['errors'].add('المنتج 1007/500 غير موجود في جدول المنتجات');
          AppLogger.error('❌ لم يتم العثور على المنتج 1007/500');
        }
      } catch (e) {
        results['errors'].add('خطأ في البحث عن المنتج: $e');
        AppLogger.error('❌ خطأ في البحث عن المنتج: $e');
      }

      // 2. البحث عن المنتج في المخزون
      try {
        final inventoryQuery = await _supabase
            .from('warehouse_inventory')
            .select('''
              id, warehouse_id, product_id, quantity, minimum_stock,
              warehouse:warehouses!inner(name, is_active),
              product:products!inner(name, sku)
            ''')
            .or('product_id.eq.1007,product.name.ilike.%1007%,product.sku.ilike.%1007%,product.name.ilike.%500%');

        AppLogger.info('🏪 نتائج البحث في المخزون: ${inventoryQuery.length} سجل');

        if (inventoryQuery.isNotEmpty) {
          results['inventory_available'] = true;
          results['details']['inventory'] = inventoryQuery;
          AppLogger.info('✅ تم العثور على المنتج في المخزون');

          for (final item in inventoryQuery) {
            final warehouseName = item['warehouse']['name'];
            final productName = item['product']['name'];
            final quantity = item['quantity'];
            AppLogger.info('   المخزن: $warehouseName - المنتج: $productName - الكمية: $quantity');
          }
        } else {
          results['errors'].add('المنتج 1007/500 غير موجود في أي مخزن');
          AppLogger.error('❌ لم يتم العثور على المنتج في أي مخزن');
        }
      } catch (e) {
        results['errors'].add('خطأ في البحث في المخزون: $e');
        AppLogger.error('❌ خطأ في البحث في المخزون: $e');
      }

      // 3. اختبار الخصم إذا كان المنتج متاحاً
      if (results['inventory_available'] == true) {
        try {
          final user = _supabase.auth.currentUser;
          if (user == null) {
            results['errors'].add('المستخدم غير مسجل دخول');
            AppLogger.error('❌ المستخدم غير مسجل دخول');
          } else {
            final inventory = results['details']['inventory'] as List;
            Map<String, dynamic>? testItem;

            for (final item in inventory) {
              final itemMap = item as Map<String, dynamic>;
              final quantity = itemMap['quantity'] as int? ?? 0;
              if (quantity > 0) {
                testItem = itemMap;
                break;
              }
            }

            if (testItem != null) {
              AppLogger.info('⚡ اختبار خصم المنتج 1007/500...');

              final testResult = await quickDeductionTest(
                productId: testItem['product_id'].toString(),
                warehouseId: testItem['warehouse_id'].toString(),
                quantity: 1,
                performedBy: user.id,
                reason: 'اختبار تشخيص المنتج 1007/500',
              );

              results['deduction_test'] = testResult;

              if (testResult) {
                AppLogger.info('✅ اختبار الخصم نجح للمنتج 1007/500');
              } else {
                results['errors'].add('فشل اختبار الخصم للمنتج 1007/500');
                AppLogger.error('❌ فشل اختبار الخصم للمنتج 1007/500');
              }
            } else {
              results['errors'].add('لا توجد كمية متاحة للاختبار');
              AppLogger.error('❌ لا توجد كمية متاحة للاختبار');
            }
          }
        } catch (e) {
          results['errors'].add('خطأ في اختبار الخصم: $e');
          AppLogger.error('❌ خطأ في اختبار الخصم: $e');
        }
      }

      // تحديد النجاح الإجمالي
      results['success'] = results['product_found'] == true &&
                          results['inventory_available'] == true &&
                          results['deduction_test'] == true;

      AppLogger.info('📊 ملخص تشخيص المنتج 1007/500:');
      AppLogger.info('   المنتج موجود: ${results['product_found']}');
      AppLogger.info('   المخزون متاح: ${results['inventory_available']}');
      AppLogger.info('   اختبار الخصم: ${results['deduction_test']}');
      AppLogger.info('   النجاح الإجمالي: ${results['success']}');

      return results;
    } catch (e) {
      results['errors'].add('خطأ عام في التشخيص: $e');
      AppLogger.error('❌ خطأ عام في تشخيص المنتج 1007/500: $e');
      return results;
    }
  }
}
