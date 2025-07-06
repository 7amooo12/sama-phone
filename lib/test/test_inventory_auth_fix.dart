/// 🧪 TEST: Authentication Context Fix for Inventory Search
/// Test the fix for Product ID "131" inventory search issue
/// This test verifies that authentication context is properly maintained during isolated transactions

import 'package:flutter/foundation.dart';
import 'package:smartbiztracker_new/services/global_inventory_service.dart';
import 'package:smartbiztracker_new/services/auth_state_manager.dart';
import 'package:smartbiztracker_new/services/transaction_isolation_service.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:smartbiztracker_new/models/warehouse_selection_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InventoryAuthFixTest {
  static final GlobalInventoryService _globalInventoryService = GlobalInventoryService();
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Test the authentication context fix for Product ID "131"
  static Future<void> testProduct131InventorySearch() async {
    try {
      AppLogger.info('🧪 بدء اختبار إصلاح المصادقة للمنتج 131');
      
      // Step 1: Verify authentication state
      await _testAuthenticationState();
      
      // Step 2: Test direct database access
      await _testDirectDatabaseAccess();
      
      // Step 3: Test global inventory search
      await _testGlobalInventorySearch();
      
      // Step 4: Test transaction isolation service
      await _testTransactionIsolationService();
      
      AppLogger.info('✅ اكتمل اختبار إصلاح المصادقة بنجاح');
      
    } catch (e) {
      AppLogger.error('❌ فشل اختبار إصلاح المصادقة: $e');
      rethrow;
    }
  }

  /// Test authentication state management
  static Future<void> _testAuthenticationState() async {
    AppLogger.info('🔍 اختبار حالة المصادقة...');
    
    // Test AuthStateManager
    final currentUser = await AuthStateManager.getCurrentUser(forceRefresh: false);
    if (currentUser == null) {
      throw Exception('لا يوجد مستخدم مصادق عليه');
    }
    
    AppLogger.info('👤 المستخدم الحالي: ${currentUser.id}');
    
    // Test Supabase client auth context
    final supabaseUser = _supabase.auth.currentUser;
    final supabaseSession = _supabase.auth.currentSession;
    
    AppLogger.info('🔒 حالة المصادقة في العميل:');
    AppLogger.info('   المستخدم: ${supabaseUser?.id ?? 'null'}');
    AppLogger.info('   الجلسة: ${supabaseSession != null ? 'موجودة' : 'غير موجودة'}');
    
    if (supabaseUser == null || supabaseUser.id != currentUser.id) {
      throw Exception('حالة المصادقة غير متطابقة في العميل');
    }
    
    // Test user profile access
    final userProfile = await AuthStateManager.getCurrentUserProfile(forceRefresh: false);
    if (userProfile == null) {
      throw Exception('لا يمكن الوصول إلى ملف المستخدم');
    }
    
    AppLogger.info('👤 ملف المستخدم: ${userProfile['role']} - ${userProfile['status']}');
    
    if (!['admin', 'owner', 'accountant', 'warehouseManager'].contains(userProfile['role'])) {
      throw Exception('دور المستخدم غير كافي للوصول إلى المخزون');
    }
    
    if (userProfile['status'] != 'approved') {
      throw Exception('حالة المستخدم غير مُعتمدة');
    }
    
    AppLogger.info('✅ اختبار حالة المصادقة نجح');
  }

  /// Test direct database access
  static Future<void> _testDirectDatabaseAccess() async {
    AppLogger.info('🔍 اختبار الوصول المباشر لقاعدة البيانات...');
    
    try {
      // Test basic warehouse_inventory access
      final inventoryCount = await _supabase
          .from('warehouse_inventory')
          .select('id')
          .count();
      
      AppLogger.info('📦 إجمالي سجلات المخزون المرئية: $inventoryCount');
      
      // Test specific product access
      final product131Records = await _supabase
          .from('warehouse_inventory')
          .select('id, warehouse_id, product_id, quantity, last_updated')
          .eq('product_id', '131');
      
      AppLogger.info('🎯 سجلات المنتج 131: ${product131Records.length}');
      
      if (product131Records.isEmpty) {
        throw Exception('لا يمكن العثور على سجلات المنتج 131 في المخزون');
      }
      
      for (final record in product131Records) {
        AppLogger.info('📦 سجل مخزون: المخزن ${record['warehouse_id']}, الكمية: ${record['quantity']}');
      }
      
      // Test warehouse access
      final warehouseRecords = await _supabase
          .from('warehouses')
          .select('id, name, is_active')
          .eq('id', '338d5af4-88ad-49cb-aec6-456ac6bd318c');
      
      if (warehouseRecords.isEmpty) {
        throw Exception('لا يمكن العثور على المخزن المحدد');
      }
      
      final warehouse = warehouseRecords.first;
      AppLogger.info('🏪 المخزن: ${warehouse['name']}, نشط: ${warehouse['is_active']}');
      
      if (warehouse['is_active'] != true) {
        throw Exception('المخزن غير نشط');
      }
      
      AppLogger.info('✅ اختبار الوصول المباشر لقاعدة البيانات نجح');
      
    } catch (e) {
      AppLogger.error('❌ فشل اختبار الوصول المباشر لقاعدة البيانات: $e');
      rethrow;
    }
  }

  /// Test global inventory search
  static Future<void> _testGlobalInventorySearch() async {
    AppLogger.info('🔍 اختبار البحث العالمي في المخزون...');
    
    try {
      final searchResult = await _globalInventoryService.searchProductGlobally(
        productId: '131',
        requestedQuantity: 4,
        strategy: WarehouseSelectionStrategy.highestStock,
      );
      
      AppLogger.info('🎯 نتائج البحث العالمي:');
      AppLogger.info('   المنتج: ${searchResult.productId}');
      AppLogger.info('   الكمية المطلوبة: ${searchResult.requestedQuantity}');
      AppLogger.info('   الكمية المتاحة: ${searchResult.totalAvailableQuantity}');
      AppLogger.info('   يمكن التلبية: ${searchResult.canFulfill}');
      AppLogger.info('   عدد المخازن: ${searchResult.availableWarehouses.length}');
      
      if (searchResult.totalAvailableQuantity == 0) {
        throw Exception('البحث العالمي لم يجد أي كمية متاحة للمنتج 131');
      }
      
      if (!searchResult.canFulfill) {
        throw Exception('البحث العالمي يشير إلى عدم إمكانية تلبية الطلب');
      }
      
      if (searchResult.availableWarehouses.isEmpty) {
        throw Exception('البحث العالمي لم يجد أي مخازن متاحة');
      }
      
      // Log warehouse details
      for (final warehouse in searchResult.availableWarehouses) {
        AppLogger.info('🏪 مخزن متاح: ${warehouse.warehouseName}, الكمية: ${warehouse.availableQuantity}');
      }
      
      AppLogger.info('✅ اختبار البحث العالمي في المخزون نجح');
      
    } catch (e) {
      AppLogger.error('❌ فشل اختبار البحث العالمي في المخزون: $e');
      rethrow;
    }
  }

  /// Test transaction isolation service
  static Future<void> _testTransactionIsolationService() async {
    AppLogger.info('🔍 اختبار خدمة عزل المعاملات...');
    
    try {
      final result = await TransactionIsolationService.executeIsolatedReadTransaction<List<dynamic>>(
        queryName: 'test_product_131_access',
        query: (client) => client
            .from('warehouse_inventory')
            .select('id, warehouse_id, product_id, quantity')
            .eq('product_id', '131'),
        fallbackValue: () => <dynamic>[],
        preserveAuthState: true,
      );
      
      AppLogger.info('🔒 نتائج المعاملة المعزولة:');
      AppLogger.info('   عدد السجلات: ${result.length}');
      
      if (result.isEmpty) {
        throw Exception('المعاملة المعزولة لم تجد أي سجلات للمنتج 131');
      }
      
      for (final record in result) {
        AppLogger.info('📦 سجل: المخزن ${record['warehouse_id']}, الكمية: ${record['quantity']}');
      }
      
      AppLogger.info('✅ اختبار خدمة عزل المعاملات نجح');
      
    } catch (e) {
      AppLogger.error('❌ فشل اختبار خدمة عزل المعاملات: $e');
      rethrow;
    }
  }

  /// Run comprehensive test suite
  static Future<Map<String, dynamic>> runComprehensiveTest() async {
    final results = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'tests': <String, dynamic>{},
      'overall_success': false,
      'error_details': null,
    };
    
    try {
      AppLogger.info('🚀 بدء الاختبار الشامل لإصلاح المصادقة');
      
      // Run all tests
      await testProduct131InventorySearch();
      
      results['tests']['authentication_state'] = {'success': true, 'error': null};
      results['tests']['direct_database_access'] = {'success': true, 'error': null};
      results['tests']['global_inventory_search'] = {'success': true, 'error': null};
      results['tests']['transaction_isolation'] = {'success': true, 'error': null};
      results['overall_success'] = true;
      
      AppLogger.info('🎉 الاختبار الشامل نجح بالكامل!');
      
    } catch (e) {
      results['overall_success'] = false;
      results['error_details'] = e.toString();
      AppLogger.error('❌ فشل الاختبار الشامل: $e');
    }
    
    return results;
  }
}
