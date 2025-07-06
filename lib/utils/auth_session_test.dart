import 'package:smartbiztracker_new/services/auth_state_manager.dart';
import 'package:smartbiztracker_new/services/warehouse_service.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 🧪 أداة اختبار مشاركة جلسة المصادقة بين الخدمات
/// 
/// هذه الأداة تختبر ما إذا كانت جميع الخدمات تستطيع الوصول لنفس جلسة المصادقة
/// وتساعد في تشخيص مشاكل عزل الجلسات
class AuthSessionTest {
  
  /// اختبار شامل لمشاركة جلسة المصادقة
  static Future<Map<String, dynamic>> runComprehensiveSessionTest() async {
    try {
      AppLogger.info('🧪 === بدء اختبار شامل لمشاركة جلسة المصادقة ===');
      
      final results = <String, dynamic>{
        'timestamp': DateTime.now().toIso8601String(),
        'test_name': 'Comprehensive Authentication Session Test',
        'tests': <String, dynamic>{},
      };

      // اختبار 1: AuthStateManager
      AppLogger.info('🔍 اختبار 1: AuthStateManager');
      try {
        final authStateUser = await AuthStateManager.getCurrentUser();
        final authStateProfile = await AuthStateManager.getCurrentUserProfile();
        
        results['tests']['auth_state_manager'] = {
          'success': authStateUser != null,
          'user_id': authStateUser?.id,
          'user_email': authStateUser?.email,
          'profile_available': authStateProfile != null,
          'user_role': authStateProfile?['role'],
          'user_status': authStateProfile?['status'],
        };
        
        AppLogger.info('✅ AuthStateManager: ${authStateUser != null ? "نجح" : "فشل"}');
      } catch (e) {
        results['tests']['auth_state_manager'] = {
          'success': false,
          'error': e.toString(),
        };
        AppLogger.error('❌ AuthStateManager: $e');
      }

      // اختبار 2: WarehouseService
      AppLogger.info('🔍 اختبار 2: WarehouseService');
      try {
        final warehouseService = WarehouseService();
        final warehouses = await warehouseService.getWarehouses();
        final userInfo = await warehouseService.getCurrentUserInfo();
        
        results['tests']['warehouse_service'] = {
          'success': true,
          'warehouse_count': warehouses.length,
          'user_info_available': userInfo != null,
          'user_id': userInfo?['id'],
          'user_role': userInfo?['role'],
        };
        
        AppLogger.info('✅ WarehouseService: نجح - ${warehouses.length} مخزن');
      } catch (e) {
        results['tests']['warehouse_service'] = {
          'success': false,
          'error': e.toString(),
        };
        AppLogger.error('❌ WarehouseService: $e');
      }

      // اختبار 3: Supabase.instance.client مباشرة
      AppLogger.info('🔍 اختبار 3: Supabase.instance.client');
      try {
        final supabaseUser = Supabase.instance.client.auth.currentUser;
        final supabaseSession = Supabase.instance.client.auth.currentSession;
        
        results['tests']['supabase_instance'] = {
          'success': supabaseUser != null,
          'user_id': supabaseUser?.id,
          'user_email': supabaseUser?.email,
          'session_available': supabaseSession != null,
          'session_expired': supabaseSession?.isExpired,
        };
        
        AppLogger.info('✅ Supabase.instance: ${supabaseUser != null ? "نجح" : "فشل"}');
      } catch (e) {
        results['tests']['supabase_instance'] = {
          'success': false,
          'error': e.toString(),
        };
        AppLogger.error('❌ Supabase.instance: $e');
      }

      // اختبار 4: مقارنة معرفات المستخدمين
      AppLogger.info('🔍 اختبار 4: مقارنة معرفات المستخدمين');
      final authStateUserId = results['tests']['auth_state_manager']?['user_id'];
      final warehouseUserId = results['tests']['warehouse_service']?['user_id'];
      final supabaseUserId = results['tests']['supabase_instance']?['user_id'];
      
      results['tests']['user_id_consistency'] = {
        'auth_state_user_id': authStateUserId,
        'warehouse_user_id': warehouseUserId,
        'supabase_user_id': supabaseUserId,
        'all_match': authStateUserId != null && 
                    authStateUserId == warehouseUserId && 
                    authStateUserId == supabaseUserId,
        'auth_warehouse_match': authStateUserId == warehouseUserId,
        'auth_supabase_match': authStateUserId == supabaseUserId,
        'warehouse_supabase_match': warehouseUserId == supabaseUserId,
      };

      // تحديد النتيجة الإجمالية
      final authStateSuccess = results['tests']['auth_state_manager']?['success'] ?? false;
      final warehouseSuccess = results['tests']['warehouse_service']?['success'] ?? false;
      final supabaseSuccess = results['tests']['supabase_instance']?['success'] ?? false;
      final consistencySuccess = results['tests']['user_id_consistency']?['all_match'] ?? false;
      
      results['overall_success'] = authStateSuccess && warehouseSuccess && supabaseSuccess && consistencySuccess;
      results['summary'] = {
        'auth_state_manager': authStateSuccess ? 'نجح' : 'فشل',
        'warehouse_service': warehouseSuccess ? 'نجح' : 'فشل',
        'supabase_instance': supabaseSuccess ? 'نجح' : 'فشل',
        'user_id_consistency': consistencySuccess ? 'متطابق' : 'غير متطابق',
      };

      AppLogger.info('🎯 نتيجة الاختبار الشامل: ${results['overall_success'] ? "نجح" : "فشل"}');
      
      return results;
      
    } catch (e, stackTrace) {
      AppLogger.error('❌ خطأ في اختبار مشاركة الجلسة: $e');
      return {
        'overall_success': false,
        'error': e.toString(),
        'stack_trace': stackTrace.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// اختبار سريع للتحقق من حالة المصادقة
  static Future<bool> quickAuthCheck() async {
    try {
      final authStateUser = await AuthStateManager.getCurrentUser();
      final supabaseUser = Supabase.instance.client.auth.currentUser;
      
      final isAuthenticated = authStateUser != null && supabaseUser != null;
      final idsMatch = authStateUser?.id == supabaseUser?.id;
      
      AppLogger.info('🔍 فحص سريع للمصادقة: ${isAuthenticated ? "مصادق" : "غير مصادق"}');
      AppLogger.info('🔍 تطابق المعرفات: ${idsMatch ? "متطابق" : "غير متطابق"}');
      
      return isAuthenticated && idsMatch;
    } catch (e) {
      AppLogger.error('❌ خطأ في الفحص السريع للمصادقة: $e');
      return false;
    }
  }

  /// اختبار الوصول للمخازن مع تشخيص مفصل
  static Future<Map<String, dynamic>> testWarehouseAccess() async {
    try {
      AppLogger.info('🏢 اختبار الوصول للمخازن...');

      final warehouseService = WarehouseService();
      final warehouses = await warehouseService.getWarehouses();

      final result = {
        'success': true,
        'warehouse_count': warehouses.length,
        'warehouse_names': warehouses.map((w) => w.name).toList(),
        'test_timestamp': DateTime.now().toIso8601String(),
      };

      AppLogger.info('✅ اختبار المخازن: ${warehouses.length} مخزن تم تحميله');

      return result;
    } catch (e) {
      AppLogger.error('❌ فشل اختبار الوصول للمخازن: $e');
      return {
        'success': false,
        'error': e.toString(),
        'warehouse_count': 0,
      };
    }
  }

  /// اختبار شامل لحالة المستخدم hima@sama.com بعد إصلاح قاعدة البيانات
  static Future<Map<String, dynamic>> testHimaSamaUserAccess() async {
    try {
      AppLogger.info('🔍 === اختبار شامل للمستخدم hima@sama.com ===');

      final results = <String, dynamic>{
        'timestamp': DateTime.now().toIso8601String(),
        'user_email': 'hima@sama.com',
        'user_uid': '4ac083bc-3e05-4456-8579-0877d2627b15',
        'tests': <String, dynamic>{},
      };

      // اختبار 1: التحقق من المصادقة
      try {
        final authStateUser = await AuthStateManager.getCurrentUser();
        results['tests']['authentication'] = {
          'success': authStateUser != null,
          'user_id': authStateUser?.id,
          'user_email': authStateUser?.email,
          'matches_expected_uid': authStateUser?.id == '4ac083bc-3e05-4456-8579-0877d2627b15',
          'matches_expected_email': authStateUser?.email == 'hima@sama.com',
        };
        AppLogger.info('✅ اختبار المصادقة: ${authStateUser != null ? "نجح" : "فشل"}');
      } catch (e) {
        results['tests']['authentication'] = {
          'success': false,
          'error': e.toString(),
        };
        AppLogger.error('❌ اختبار المصادقة: $e');
      }

      // اختبار 2: التحقق من ملف المستخدم
      try {
        final userProfile = await AuthStateManager.getCurrentUserProfile();
        results['tests']['user_profile'] = {
          'success': userProfile != null,
          'profile_data': userProfile,
          'role': userProfile?['role'],
          'status': userProfile?['status'],
          'is_approved': userProfile?['status'] == 'approved',
        };
        AppLogger.info('✅ اختبار ملف المستخدم: ${userProfile != null ? "نجح" : "فشل"}');
      } catch (e) {
        results['tests']['user_profile'] = {
          'success': false,
          'error': e.toString(),
        };
        AppLogger.error('❌ اختبار ملف المستخدم: $e');
      }

      // اختبار 3: الوصول للمخازن
      try {
        final warehouseService = WarehouseService();
        final warehouses = await warehouseService.getWarehouses();
        results['tests']['warehouse_access'] = {
          'success': true,
          'warehouse_count': warehouses.length,
          'warehouse_names': warehouses.map((w) => w.name).toList(),
          'has_warehouses': warehouses.isNotEmpty,
        };
        AppLogger.info('✅ اختبار المخازن: ${warehouses.length} مخزن');
      } catch (e) {
        results['tests']['warehouse_access'] = {
          'success': false,
          'error': e.toString(),
          'warehouse_count': 0,
        };
        AppLogger.error('❌ اختبار المخازن: $e');
      }

      // اختبار 4: الوصول لجداول قاعدة البيانات المباشرة
      try {
        final supabase = Supabase.instance.client;

        // اختبار user_profiles
        final userProfilesCount = await supabase
            .from('user_profiles')
            .select('id')
            .count();

        // اختبار warehouses
        final warehousesCount = await supabase
            .from('warehouses')
            .select('id')
            .count();

        results['tests']['direct_database_access'] = {
          'success': true,
          'user_profiles_count': userProfilesCount.count,
          'warehouses_count': warehousesCount.count,
          'can_access_user_profiles': userProfilesCount.count != null,
          'can_access_warehouses': warehousesCount.count != null,
        };
        AppLogger.info('✅ اختبار قاعدة البيانات المباشرة: نجح');
      } catch (e) {
        results['tests']['direct_database_access'] = {
          'success': false,
          'error': e.toString(),
        };
        AppLogger.error('❌ اختبار قاعدة البيانات المباشرة: $e');
      }

      // تحديد النتيجة الإجمالية
      final authSuccess = results['tests']['authentication']?['success'] ?? false;
      final profileSuccess = results['tests']['user_profile']?['success'] ?? false;
      final warehouseSuccess = results['tests']['warehouse_access']?['success'] ?? false;
      final dbSuccess = results['tests']['direct_database_access']?['success'] ?? false;

      results['overall_success'] = authSuccess && profileSuccess && warehouseSuccess && dbSuccess;
      results['summary'] = {
        'authentication': authSuccess ? 'نجح' : 'فشل',
        'user_profile': profileSuccess ? 'نجح' : 'فشل',
        'warehouse_access': warehouseSuccess ? 'نجح' : 'فشل',
        'database_access': dbSuccess ? 'نجح' : 'فشل',
        'warehouse_count': results['tests']['warehouse_access']?['warehouse_count'] ?? 0,
      };

      AppLogger.info('🎯 نتيجة اختبار hima@sama.com: ${results['overall_success'] ? "نجح" : "فشل"}');

      return results;

    } catch (e, stackTrace) {
      AppLogger.error('❌ خطأ في اختبار hima@sama.com: $e');
      return {
        'overall_success': false,
        'error': e.toString(),
        'stack_trace': stackTrace.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }
}
