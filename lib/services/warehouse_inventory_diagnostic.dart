// 🔍 WAREHOUSE INVENTORY DIAGNOSTIC SERVICE
// Comprehensive diagnostic tool to trace why warehouse inventory is not displaying

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_logger.dart';
import '../models/warehouse_model.dart';
import '../models/warehouse_inventory_model.dart';
import 'auth_state_manager.dart';

class WarehouseInventoryDiagnostic {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Run comprehensive warehouse inventory diagnostic
  static Future<Map<String, dynamic>> runFullInventoryDiagnostic() async {
    try {
      AppLogger.info('🔍 === بدء التشخيص الشامل لمخزون المخازن ===');

      final results = <String, dynamic>{
        'timestamp': DateTime.now().toIso8601String(),
        'authentication_check': {},
        'database_connectivity': {},
        'warehouse_data_check': {},
        'inventory_data_check': {},
        'ui_state_check': {},
        'summary': {},
      };

      // Step 1: Authentication Check
      results['authentication_check'] = await _checkAuthentication();

      // Step 2: Database Connectivity
      results['database_connectivity'] = await _checkDatabaseConnectivity();

      // Step 3: Warehouse Data Check
      results['warehouse_data_check'] = await _checkWarehouseData();

      // Step 4: Inventory Data Check
      results['inventory_data_check'] = await _checkInventoryData();

      // Step 5: UI State Check
      results['ui_state_check'] = await _checkUIState();

      // Step 6: Generate Summary
      results['summary'] = _generateDiagnosticSummary(results);

      AppLogger.info('✅ تم إكمال التشخيص الشامل لمخزون المخازن');
      return results;

    } catch (e) {
      AppLogger.error('❌ خطأ في التشخيص الشامل: $e');
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Check authentication state
  static Future<Map<String, dynamic>> _checkAuthentication() async {
    try {
      AppLogger.info('🔐 فحص حالة المصادقة...');

      final authCheck = <String, dynamic>{};

      // Check Supabase auth
      final supabaseUser = _supabase.auth.currentUser;
      authCheck['supabase_auth'] = {
        'is_authenticated': supabaseUser != null,
        'user_id': supabaseUser?.id,
        'email': supabaseUser?.email,
      };

      // Check AuthStateManager
      try {
        final authStateUser = await AuthStateManager.getCurrentUser();
        authCheck['auth_state_manager'] = {
          'is_authenticated': authStateUser != null,
          'user_id': authStateUser?.id,
          'email': authStateUser?.email,
        };
      } catch (e) {
        authCheck['auth_state_manager'] = {
          'error': e.toString(),
        };
      }

      // Check user profile
      if (supabaseUser != null) {
        try {
          final userProfile = await _supabase
              .from('user_profiles')
              .select('*')
              .eq('id', supabaseUser.id)
              .single();

          authCheck['user_profile'] = {
            'success': true,
            'data': userProfile,
            'role': userProfile['role'],
            'status': userProfile['status'],
            'should_have_warehouse_access': _shouldHaveWarehouseAccess(
              userProfile['role'], 
              userProfile['status']
            ),
          };
        } catch (e) {
          authCheck['user_profile'] = {
            'success': false,
            'error': e.toString(),
          };
        }
      }

      return authCheck;
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Check database connectivity
  static Future<Map<String, dynamic>> _checkDatabaseConnectivity() async {
    try {
      AppLogger.info('🔗 فحص الاتصال بقاعدة البيانات...');

      final connectivity = <String, dynamic>{};

      // Test basic connection
      try {
        final testQuery = await _supabase
            .from('user_profiles')
            .select('count')
            .count(CountOption.exact);

        connectivity['basic_connection'] = {
          'success': true,
          'user_profiles_count': testQuery.count,
        };
      } catch (e) {
        connectivity['basic_connection'] = {
          'success': false,
          'error': e.toString(),
        };
      }

      // Test warehouse tables access
      final warehouseTables = ['warehouses', 'warehouse_inventory', 'warehouse_transactions', 'warehouse_requests'];
      
      for (final tableName in warehouseTables) {
        try {
          final tableQuery = await _supabase
              .from(tableName)
              .select('id')
              .count();

          connectivity['table_$tableName'] = {
            'success': true,
            'record_count': tableQuery.count,
            'accessible': true,
          };
        } catch (e) {
          connectivity['table_$tableName'] = {
            'success': false,
            'error': e.toString(),
            'accessible': false,
          };
        }
      }

      return connectivity;
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Check warehouse data
  static Future<Map<String, dynamic>> _checkWarehouseData() async {
    try {
      AppLogger.info('🏢 فحص بيانات المخازن...');

      final warehouseCheck = <String, dynamic>{};

      // Get all warehouses
      try {
        final warehousesResponse = await _supabase
            .from('warehouses')
            .select('*')
            .order('created_at', ascending: false);

        warehouseCheck['warehouses_query'] = {
          'success': true,
          'total_warehouses': warehousesResponse.length,
          'active_warehouses': warehousesResponse.where((w) => w['is_active'] == true).length,
          'sample_warehouses': warehousesResponse.take(3).toList(),
        };

        // Test warehouse model parsing
        if (warehousesResponse.isNotEmpty) {
          try {
            final firstWarehouse = WarehouseModel.fromJson(warehousesResponse.first);
            warehouseCheck['model_parsing'] = {
              'success': true,
              'sample_warehouse': {
                'id': firstWarehouse.id,
                'name': firstWarehouse.name,
                'is_active': firstWarehouse.isActive,
              },
            };
          } catch (e) {
            warehouseCheck['model_parsing'] = {
              'success': false,
              'error': e.toString(),
            };
          }
        }
      } catch (e) {
        warehouseCheck['warehouses_query'] = {
          'success': false,
          'error': e.toString(),
        };
      }

      return warehouseCheck;
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Check inventory data
  static Future<Map<String, dynamic>> _checkInventoryData() async {
    try {
      AppLogger.info('📦 فحص بيانات المخزون...');

      final inventoryCheck = <String, dynamic>{};

      // Get all inventory
      try {
        final inventoryResponse = await _supabase
            .from('warehouse_inventory')
            .select('*')
            .order('last_updated', ascending: false);

        inventoryCheck['inventory_query'] = {
          'success': true,
          'total_inventory_items': inventoryResponse.length,
          'warehouses_with_inventory': inventoryResponse.map((i) => i['warehouse_id']).toSet().length,
          'sample_inventory': inventoryResponse.take(3).toList(),
        };

        // Test inventory model parsing
        if (inventoryResponse.isNotEmpty) {
          try {
            final firstInventory = WarehouseInventoryModel.fromJson(inventoryResponse.first);
            inventoryCheck['inventory_model_parsing'] = {
              'success': true,
              'sample_inventory': {
                'id': firstInventory.id,
                'warehouse_id': firstInventory.warehouseId,
                'product_id': firstInventory.productId,
                'quantity': firstInventory.quantity,
              },
            };
          } catch (e) {
            inventoryCheck['inventory_model_parsing'] = {
              'success': false,
              'error': e.toString(),
            };
          }
        }

        // Test inventory for specific warehouse
        if (inventoryResponse.isNotEmpty) {
          final firstWarehouseId = inventoryResponse.first['warehouse_id'];
          try {
            final warehouseInventoryResponse = await _supabase
                .from('warehouse_inventory')
                .select('*')
                .eq('warehouse_id', firstWarehouseId);

            inventoryCheck['warehouse_specific_inventory'] = {
              'success': true,
              'warehouse_id': firstWarehouseId,
              'inventory_count': warehouseInventoryResponse.length,
              'sample_items': warehouseInventoryResponse.take(2).toList(),
            };
          } catch (e) {
            inventoryCheck['warehouse_specific_inventory'] = {
              'success': false,
              'error': e.toString(),
            };
          }
        }
      } catch (e) {
        inventoryCheck['inventory_query'] = {
          'success': false,
          'error': e.toString(),
        };
      }

      return inventoryCheck;
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Check UI state
  static Future<Map<String, dynamic>> _checkUIState() async {
    try {
      AppLogger.info('🖥️ فحص حالة واجهة المستخدم...');

      final uiCheck = <String, dynamic>{};

      // This would be called from a widget context to check provider states
      uiCheck['note'] = 'UI state check requires widget context - call from widget';
      uiCheck['instructions'] = [
        'Check WarehouseProvider.isLoading',
        'Check WarehouseProvider.error',
        'Check WarehouseProvider.warehouses.length',
        'Check WarehouseProvider.currentInventory.length',
        'Check WarehouseProvider.selectedWarehouse',
      ];

      return uiCheck;
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Generate diagnostic summary
  static Map<String, dynamic> _generateDiagnosticSummary(Map<String, dynamic> results) {
    final summary = <String, dynamic>{
      'overall_status': 'unknown',
      'critical_issues': <String>[],
      'warnings': <String>[],
      'recommendations': <String>[],
    };

    // Check authentication
    final authCheck = results['authentication_check'] as Map<String, dynamic>?;
    if (authCheck != null) {
      if (authCheck['supabase_auth']?['is_authenticated'] != true) {
        summary['critical_issues'].add('User not authenticated');
        summary['recommendations'].add('Ensure user is properly logged in');
      }

      final userProfile = authCheck['user_profile'] as Map<String, dynamic>?;
      if (userProfile?['success'] == true) {
        if (userProfile?['should_have_warehouse_access'] != true) {
          summary['critical_issues'].add('User should not have warehouse access based on role/status');
          summary['recommendations'].add('Check user role and approval status');
        }
      }
    }

    // Check database connectivity
    final dbCheck = results['database_connectivity'] as Map<String, dynamic>?;
    if (dbCheck != null) {
      final warehouseTableAccess = dbCheck['table_warehouses'] as Map<String, dynamic>?;
      final inventoryTableAccess = dbCheck['table_warehouse_inventory'] as Map<String, dynamic>?;

      if (warehouseTableAccess?['accessible'] != true) {
        summary['critical_issues'].add('Cannot access warehouses table');
      }

      if (inventoryTableAccess?['accessible'] != true) {
        summary['critical_issues'].add('Cannot access warehouse_inventory table');
      }
    }

    // Check data availability
    final warehouseCheck = results['warehouse_data_check'] as Map<String, dynamic>?;
    final inventoryCheck = results['inventory_data_check'] as Map<String, dynamic>?;

    if (warehouseCheck?['warehouses_query']?['total_warehouses'] == 0) {
      summary['warnings'].add('No warehouses found in database');
      summary['recommendations'].add('Create some warehouse records for testing');
    }

    if (inventoryCheck?['inventory_query']?['total_inventory_items'] == 0) {
      summary['warnings'].add('No inventory items found in database');
      summary['recommendations'].add('Add some inventory items for testing');
    }

    // Determine overall status
    if (summary['critical_issues'].isEmpty) {
      if (summary['warnings'].isEmpty) {
        summary['overall_status'] = 'healthy';
      } else {
        summary['overall_status'] = 'warnings_detected';
      }
    } else {
      summary['overall_status'] = 'critical_issues_detected';
    }

    return summary;
  }

  /// Check if user should have warehouse access
  static bool _shouldHaveWarehouseAccess(String? role, String? status) {
    if (role == null || status == null) return false;
    
    final allowedRoles = ['admin', 'owner', 'accountant', 'warehouseManager'];
    final allowedStatuses = ['approved', 'active'];
    
    return allowedRoles.contains(role) && allowedStatuses.contains(status);
  }

  /// Quick test for immediate debugging
  static Future<void> quickInventoryTest() async {
    try {
      AppLogger.info('🧪 === اختبار سريع للمخزون ===');

      // Test 1: Basic auth
      final user = _supabase.auth.currentUser;
      AppLogger.info('👤 المستخدم: ${user?.email ?? 'غير مسجل دخول'}');

      // Test 2: Warehouses access
      final warehouses = await _supabase.from('warehouses').select('id, name').limit(3);
      AppLogger.info('🏢 المخازن: ${warehouses.length} مخزن');

      // Test 3: Inventory access
      final inventory = await _supabase.from('warehouse_inventory').select('id, warehouse_id, product_id, quantity').limit(5);
      AppLogger.info('📦 المخزون: ${inventory.length} عنصر');

      // Test 4: Specific warehouse inventory
      if (warehouses.isNotEmpty && inventory.isNotEmpty) {
        final warehouseId = warehouses.first['id'];
        final warehouseInventory = await _supabase
            .from('warehouse_inventory')
            .select('*')
            .eq('warehouse_id', warehouseId);
        AppLogger.info('📦 مخزون المخزن $warehouseId: ${warehouseInventory.length} عنصر');
      }

      AppLogger.info('✅ اكتمل الاختبار السريع بنجاح');
    } catch (e) {
      AppLogger.error('❌ فشل الاختبار السريع: $e');
    }
  }
}
