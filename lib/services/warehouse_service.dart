import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'package:smartbiztracker_new/models/warehouse_model.dart';
import 'package:smartbiztracker_new/models/warehouse_inventory_model.dart';
import 'package:smartbiztracker_new/models/warehouse_request_model.dart';
import 'package:smartbiztracker_new/models/warehouse_transaction_model.dart';
import 'package:smartbiztracker_new/models/warehouse_deletion_models.dart';
import 'package:smartbiztracker_new/models/product_model.dart';
import 'package:smartbiztracker_new/services/supabase_service.dart';
import 'package:smartbiztracker_new/services/api_product_sync_service.dart';
import 'package:smartbiztracker_new/services/auth_state_manager.dart';
import 'package:smartbiztracker_new/services/warehouse_cache_service.dart';
import 'package:smartbiztracker_new/services/warehouse_performance_monitor.dart';
import 'package:smartbiztracker_new/services/operation_isolation_service.dart';
import 'package:smartbiztracker_new/services/transaction_isolation_service.dart';
import 'package:smartbiztracker_new/services/warehouse_order_transfer_service.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:smartbiztracker_new/utils/performance_monitor.dart';

/// خدمة إدارة المخازن مع إدارة محسنة للجلسات وتخزين مؤقت للأداء
class WarehouseService {
  final SupabaseService _supabaseService;
  final ApiProductSyncService _apiProductSyncService = ApiProductSyncService();
  final WarehouseOrderTransferService _orderTransferService = WarehouseOrderTransferService();

  // استخدام مرجع مشترك لـ Supabase client لضمان مشاركة الجلسة
  SupabaseClient get _supabase => Supabase.instance.client;

  // ==================== Cache Management ====================
  static const String _warehousesCacheKey = 'warehouses_cache';
  static const String _warehouseInventoryCachePrefix = 'warehouse_inventory_';
  static const Duration _cacheExpiration = Duration(minutes: 15);
  static const Duration _inventoryCacheExpiration = Duration(minutes: 10);

  // In-memory cache for faster access
  static List<WarehouseModel>? _warehousesMemoryCache;
  static DateTime? _warehousesCacheTime;
  static final Map<String, List<WarehouseInventoryModel>> _inventoryMemoryCache = {};
  static final Map<String, DateTime> _inventoryCacheTime = {};

  // Background sync timer
  static Timer? _backgroundSyncTimer;

  WarehouseService({SupabaseService? supabaseService})
      : _supabaseService = supabaseService ?? SupabaseService() {
    _initializeBackgroundSync();
    _initializeEnhancedCache();
  }

  /// Initialize enhanced caching system
  Future<void> _initializeEnhancedCache() async {
    try {
      await WarehouseCacheService.initialize();
      AppLogger.info('✅ Enhanced warehouse caching initialized');
    } catch (e) {
      AppLogger.error('❌ Failed to initialize enhanced caching: $e');
    }
  }

  /// Dispose of resources and timers
  void dispose() {
    _backgroundSyncTimer?.cancel();
    _backgroundSyncTimer = null;
    AppLogger.info('🗑️ WarehouseService disposed');
  }

  // ==================== Cache Management Methods ====================

  /// Initialize background sync for cache updates
  void _initializeBackgroundSync() {
    _backgroundSyncTimer?.cancel();
    _backgroundSyncTimer = Timer.periodic(Duration(minutes: 5), (timer) {
      _backgroundSyncWarehouses();
    });
  }

  /// Background sync for warehouses without blocking UI
  Future<void> _backgroundSyncWarehouses() async {
    try {
      AppLogger.info('🔄 Background sync: Updating warehouse cache');
      await _fetchWarehousesFromDatabase(useCache: false);
    } catch (e) {
      AppLogger.warning('⚠️ Background sync failed: $e');
    }
  }

  /// Check if warehouses cache is valid
  bool _isWarehousesCacheValid() {
    if (_warehousesCacheTime == null) return false;
    return DateTime.now().difference(_warehousesCacheTime!) < _cacheExpiration;
  }

  /// Check if inventory cache is valid for a specific warehouse
  bool _isInventoryCacheValid(String warehouseId) {
    final cacheTime = _inventoryCacheTime[warehouseId];
    if (cacheTime == null) return false;
    return DateTime.now().difference(cacheTime) < _inventoryCacheExpiration;
  }

  /// Save warehouses to persistent cache
  Future<void> _saveWarehousesToCache(List<WarehouseModel> warehouses) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final warehousesJson = warehouses.map((w) => w.toJson()).toList();
      await prefs.setString(_warehousesCacheKey, jsonEncode({
        'data': warehousesJson,
        'timestamp': DateTime.now().toIso8601String(),
      }));

      // Update memory cache
      _warehousesMemoryCache = warehouses;
      _warehousesCacheTime = DateTime.now();

      AppLogger.info('💾 Saved ${warehouses.length} warehouses to cache');
    } catch (e) {
      AppLogger.error('❌ Failed to save warehouses to cache: $e');
    }
  }

  /// Load warehouses from persistent cache
  Future<List<WarehouseModel>?> _loadWarehousesFromCache() async {
    try {
      // Check memory cache first
      if (_warehousesMemoryCache != null && _isWarehousesCacheValid()) {
        AppLogger.info('⚡ Using warehouses from memory cache');
        return _warehousesMemoryCache;
      }

      final prefs = await SharedPreferences.getInstance();
      final cacheString = prefs.getString(_warehousesCacheKey);
      if (cacheString == null) return null;

      final cacheData = jsonDecode(cacheString);
      final timestamp = DateTime.parse(cacheData['timestamp']);

      if (DateTime.now().difference(timestamp) > _cacheExpiration) {
        AppLogger.info('⏰ Warehouse cache expired');
        return null;
      }

      final warehousesJson = cacheData['data'] as List;
      final warehouses = warehousesJson
          .map((json) => WarehouseModel.fromJson(json))
          .toList();

      // Update memory cache
      _warehousesMemoryCache = warehouses;
      _warehousesCacheTime = timestamp;

      AppLogger.info('📦 Loaded ${warehouses.length} warehouses from persistent cache');
      return warehouses;
    } catch (e) {
      AppLogger.error('❌ Failed to load warehouses from cache: $e');
      return null;
    }
  }

  /// Clear all caches
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_warehousesCacheKey);

      // Clear inventory caches
      final keys = prefs.getKeys().where((key) => key.startsWith(_warehouseInventoryCachePrefix));
      for (final key in keys) {
        await prefs.remove(key);
      }

      // Clear memory caches
      _warehousesMemoryCache = null;
      _warehousesCacheTime = null;
      _inventoryMemoryCache.clear();
      _inventoryCacheTime.clear();

      AppLogger.info('🗑️ All warehouse caches cleared');
    } catch (e) {
      AppLogger.error('❌ Failed to clear cache: $e');
    }
  }

  // ==================== Type Validation Helpers ====================

  /// التحقق من صحة معرف المخزن (UUID)
  bool _isValidWarehouseId(String warehouseId) {
    if (warehouseId.isEmpty) return false;
    try {
      // محاولة تحويل النص إلى UUID للتحقق من صحته
      final uuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);
      return uuid.hasMatch(warehouseId);
    } catch (e) {
      return false;
    }
  }

  /// التحقق من صحة معرف المنتج (TEXT)
  bool _isValidProductId(String productId) {
    return productId.isNotEmpty && productId.trim().isNotEmpty;
  }

  /// تحويل معرف المخزن إلى UUID آمن للاستعلامات
  String _ensureWarehouseIdFormat(String warehouseId) {
    if (!_isValidWarehouseId(warehouseId)) {
      throw Exception('معرف المخزن غير صحيح: $warehouseId. يجب أن يكون UUID صحيح.');
    }
    return warehouseId.toLowerCase();
  }

  /// تحويل معرف المنتج إلى TEXT آمن للاستعلامات
  String _ensureProductIdFormat(String productId) {
    if (!_isValidProductId(productId)) {
      throw Exception('معرف المنتج غير صحيح: $productId. لا يمكن أن يكون فارغاً.');
    }
    return productId.trim();
  }

  // ==================== إدارة المخازن ====================

  /// الحصول على جميع المخازن - نسخة محسنة مع تخزين مؤقت للأداء
  Future<List<WarehouseModel>> getWarehouses({bool activeOnly = true, bool useCache = true}) async {
    final timer = TimedOperation('warehouse_loading');

    try {
      AppLogger.info('🏢 Loading warehouses (Enhanced Performance)');

      // Try to load from enhanced cache first if enabled
      if (useCache) {
        final cacheTimer = TimedOperation('enhanced_cache_loading');
        final cacheKey = activeOnly ? 'active_only' : 'all';
        final cachedWarehouses = await WarehouseCacheService.loadWarehouses(cacheKey: cacheKey);
        cacheTimer.complete();

        if (cachedWarehouses != null) {
          final filteredWarehouses = activeOnly
              ? cachedWarehouses.where((w) => w.isActive).toList()
              : cachedWarehouses;
          AppLogger.info('⚡ Loaded ${filteredWarehouses.length} warehouses from enhanced cache');

          // Record performance metrics
          final loadTime = timer.elapsedMilliseconds;
          WarehousePerformanceMonitor().recordLoadTime('warehouse_loading', loadTime, fromCache: true);

          return timer.completeWithResult(filteredWarehouses);
        }
      }

      // CRITICAL FIX: Load from database using isolated operation to prevent system-wide impact
      final result = await OperationIsolationService.executeIsolatedOperation<List<WarehouseModel>>(
        operationName: 'fetch_warehouses_from_database',
        operation: () => _fetchWarehousesFromDatabase(activeOnly: activeOnly, useCache: useCache),
        fallbackValue: () => <WarehouseModel>[],
        preserveAuthState: true,
        maxRetries: 2,
      );

      // Record performance metrics for database load
      final loadTime = timer.elapsedMilliseconds;
      WarehousePerformanceMonitor().recordLoadTime('warehouse_loading', loadTime, fromCache: false);

      // Complete the timer operation to prevent "No start time found" warnings
      timer.complete();

      return result;
    } catch (e, stackTrace) {
      timer.complete();
      AppLogger.error('❌ Error loading warehouses: $e');
      return [];
    }
  }

  /// Fetch warehouses from database with optimized queries
  Future<List<WarehouseModel>> _fetchWarehousesFromDatabase({bool activeOnly = true, bool useCache = true}) async {
    try {
      AppLogger.info('🌐 Fetching warehouses from database');

      // CRITICAL FIX: Validate authentication state before database operations
      final authValid = await AuthStateManager.validateAuthenticationState();
      if (!authValid) {
        AppLogger.error('❌ No authenticated user after recovery attempts');
        // Try one more recovery attempt
        final recoveredUser = await AuthStateManager.getCurrentUser(forceRefresh: true);
        if (recoveredUser == null) {
          AppLogger.error('❌ Authentication recovery failed completely');
          return [];
        }
        AppLogger.info('✅ Authentication recovered successfully');
      }

      // CRITICAL FIX: Use AuthStateManager for robust authentication recovery
      User? currentUser;
      try {
        currentUser = await AuthStateManager.getCurrentUser(forceRefresh: false);
        if (currentUser == null) {
          AppLogger.warning('⚠️ No authenticated user found, attempting recovery...');
          currentUser = await AuthStateManager.getCurrentUser(forceRefresh: true);
        }

        if (currentUser == null) {
          AppLogger.error('❌ No authenticated user after recovery attempts');
          return [];
        }

        AppLogger.info('✅ Authenticated user verified: ${currentUser.id}');
      } catch (authError) {
        AppLogger.error('❌ Authentication error: $authError');
        return [];
      }

      // Quick permission check (optimized for production)
      try {
        final userProfile = await _supabase
            .from('user_profiles')
            .select('role, status')
            .eq('id', currentUser.id)
            .single();

        final role = userProfile['role'] as String?;
        final status = userProfile['status'] as String?;

        final allowedRoles = ['admin', 'owner', 'accountant', 'warehouseManager', 'warehouse_manager'];
        final allowedStatuses = ['approved', 'active'];

        if (role == null || !allowedRoles.contains(role) ||
            status == null || !allowedStatuses.contains(status)) {
          AppLogger.warning('⚠️ User lacks warehouse access permissions');
          return [];
        }
      } catch (profileError) {
        AppLogger.error('❌ Error fetching user profile: $profileError');
        return [];
      }

      // PERFORMANCE OPTIMIZED: Try direct query first, fallback to isolated transaction if needed
      final selectFields = 'id, name, address, description, is_active, created_at, created_by';
      List<dynamic> response;

      try {
        // First attempt: Direct query for better performance
        AppLogger.info('🚀 Attempting direct warehouse query for better performance');
        response = await (activeOnly
            ? Supabase.instance.client
                .from('warehouses')
                .select(selectFields)
                .eq('is_active', true)
                .order('name')
                .limit(100)
            : Supabase.instance.client
                .from('warehouses')
                .select(selectFields)
                .order('name')
                .limit(100));

        AppLogger.info('✅ Direct warehouse query successful');
      } catch (directQueryError) {
        AppLogger.warning('⚠️ Direct query failed, using isolated transaction: $directQueryError');

        // Fallback: Use transaction isolation for warehouse query
        response = await TransactionIsolationService.executeIsolatedReadTransaction<List<dynamic>>(
          queryName: 'fetch_warehouses_${activeOnly ? 'active' : 'all'}',
          query: (client) => activeOnly
              ? client
                  .from('warehouses')
                  .select(selectFields)
                  .eq('is_active', true)
                  .order('name')
                  .limit(100)
              : client
                  .from('warehouses')
                  .select(selectFields)
                  .order('name')
                  .limit(100),
          fallbackValue: () => <dynamic>[],
          preserveAuthState: false, // Don't preserve auth state for read operations to improve performance
        );
      }

      final warehouses = response
          .map((json) => WarehouseModel.fromJson(json as Map<String, dynamic>))
          .toList();

      AppLogger.info('✅ Loaded ${warehouses.length} warehouses from database');

      // DIAGNOSTIC: If no warehouses found, run comprehensive diagnostics
      if (warehouses.isEmpty) {
        AppLogger.warning('⚠️ No warehouses found - running diagnostics...');
        await _runWarehouseDiagnostics();
      }

      // Save to enhanced cache if enabled
      if (useCache && warehouses.isNotEmpty) {
        final cacheKey = activeOnly ? 'active_only' : 'all';
        await WarehouseCacheService.saveWarehouses(warehouses, cacheKey: cacheKey);
        // Also save to legacy cache for backward compatibility
        await _saveWarehousesToCache(warehouses);
      }

      return warehouses;
    } catch (e) {
      AppLogger.error('❌ Database fetch error: $e');

      // Simplified error handling for production
      if (e.toString().contains('row-level security policy')) {
        AppLogger.error('🔒 RLS policy violation - insufficient permissions');
      } else if (e.toString().contains('JWT')) {
        AppLogger.error('🔑 Authentication error - session may be expired');
      }

      return [];
    }
  }

  /// Run comprehensive diagnostics when no warehouses are found
  Future<void> _runWarehouseDiagnostics() async {
    try {
      AppLogger.info('🔍 Running warehouse diagnostics...');

      // Check authentication state
      final currentUser = await AuthStateManager.getCurrentUser();
      AppLogger.info('👤 Current user: ${currentUser?.id ?? 'null'}');

      // Check database connection
      try {
        final testQuery = await Supabase.instance.client
            .from('warehouses')
            .select('count(*)')
            .count(CountOption.exact);
        AppLogger.info('📊 Total warehouses in database: $testQuery');
      } catch (e) {
        AppLogger.error('❌ Database connection test failed: $e');
      }

      // Check user permissions
      if (currentUser != null) {
        try {
          final userProfile = await AuthStateManager.getCurrentUserProfile();
          AppLogger.info('👤 User profile: $userProfile');
        } catch (e) {
          AppLogger.error('❌ Failed to get user profile: $e');
        }
      }

      // Check RLS policies
      try {
        final directQuery = await Supabase.instance.client
            .from('warehouses')
            .select('id, name, is_active')
            .limit(5);
        AppLogger.info('🔓 Direct query result: $directQuery');
      } catch (e) {
        AppLogger.error('❌ Direct query failed (possible RLS issue): $e');
      }

    } catch (e) {
      AppLogger.error('❌ Warehouse diagnostics failed: $e');
    }
  }

  /// الحصول على مخزن واحد بالمعرف
  Future<WarehouseModel?> getWarehouse(String warehouseId) async {
    try {
      AppLogger.info('🏢 جاري تحميل المخزن: $warehouseId');

      final response = await Supabase.instance.client
          .from('warehouses')
          .select('*')
          .eq('id', warehouseId)
          .maybeSingle();

      if (response == null) {
        AppLogger.warning('⚠️ المخزن غير موجود: $warehouseId');
        return null;
      }

      final warehouse = WarehouseModel.fromJson(response);
      AppLogger.info('✅ تم تحميل المخزن: ${warehouse.name}');
      return warehouse;
    } catch (e) {
      AppLogger.error('❌ خطأ في تحميل المخزن: $e');
      throw Exception('فشل في تحميل المخزن: $e');
    }
  }

  /// إنشاء مخزن جديد
  Future<WarehouseModel?> createWarehouse({
    required String name,
    required String address,
    String? description,
    required String createdBy,
  }) async {
    try {
      AppLogger.info('🏢 جاري إنشاء مخزن جديد: $name');

      // التحقق من صلاحيات المستخدم أولاً
      final hasPermission = await _checkWarehouseCreatePermission(createdBy);
      if (!hasPermission) {
        AppLogger.error('❌ المستخدم لا يملك صلاحية إنشاء مخازن');
        throw Exception('ليس لديك صلاحية لإنشاء مخازن. يرجى التواصل مع المدير.');
      }

      final data = {
        'name': name,
        'address': address,
        'description': description,
        'created_by': createdBy,
        'is_active': true,
      };

      final response = await _supabaseService.createRecord('warehouses', data);
      final warehouse = WarehouseModel.fromJson(response);

      AppLogger.info('✅ تم إنشاء المخزن بنجاح: ${warehouse.id}');
      return warehouse;
    } catch (e) {
      AppLogger.error('❌ خطأ في إنشاء المخزن: $e');

      // تحسين رسائل الخطأ
      if (e.toString().contains('row-level security policy')) {
        throw Exception('ليس لديك صلاحية لإنشاء مخازن. يرجى التواصل مع المدير.');
      } else if (e.toString().contains('duplicate key')) {
        throw Exception('اسم المخزن موجود بالفعل. يرجى اختيار اسم آخر.');
      } else {
        throw Exception('حدث خطأ في إنشاء المخزن: ${e.toString()}');
      }
    }
  }

  /// التحقق من صلاحية إنشاء المخازن
  Future<bool> _checkWarehouseCreatePermission(String userId) async {
    try {
      AppLogger.info('🔍 التحقق من صلاحيات المستخدم: $userId');

      final response = await Supabase.instance.client
          .from('user_profiles')
          .select('role, name, email')
          .eq('id', userId)
          .single();

      final role = response['role'] as String?;
      final name = response['name'] as String?;
      final email = response['email'] as String?;

      AppLogger.info('👤 بيانات المستخدم: الاسم=$name، البريد=$email، الدور=$role');

      // Support both camelCase and snake_case role formats
      final hasPermission = role != null && [
        'admin',
        'owner',
        'warehouse_manager',  // snake_case format
        'warehouseManager',   // camelCase format
        'accountant'          // accountants can also create warehouses
      ].contains(role);
      AppLogger.info('🔐 نتيجة التحقق من الصلاحيات: $hasPermission');

      return hasPermission;
    } catch (e) {
      AppLogger.error('❌ خطأ في التحقق من صلاحيات المستخدم: $e');
      return false;
    }
  }

  /// طريقة تشخيصية للتحقق من المستخدم الحالي
  Future<Map<String, dynamic>?> getCurrentUserInfo() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        AppLogger.error('❌ لا يوجد مستخدم مسجل دخول');
        return null;
      }

      AppLogger.info('🔍 المستخدم الحالي: ${currentUser.id}');

      final response = await Supabase.instance.client
          .from('user_profiles')
          .select('*')
          .eq('id', currentUser.id)
          .single();

      AppLogger.info('👤 بيانات المستخدم الكاملة: $response');
      return response;
    } catch (e) {
      AppLogger.error('❌ خطأ في الحصول على بيانات المستخدم: $e');
      return null;
    }
  }

  /// اختبار تشخيصي شامل للمصادقة والوصول للمخازن مع AuthStateManager
  Future<Map<String, dynamic>> debugAuthenticationAndAccess() async {
    try {
      AppLogger.info('🔍 === بدء تشخيص شامل للمصادقة والمخازن مع AuthStateManager ===');

      final results = <String, dynamic>{
        'timestamp': DateTime.now().toIso8601String(),
        'steps': <String, dynamic>{},
      };

      // خطوة 1: فحص Supabase client
      results['steps']['supabase_client'] = {
        'has_client': _supabase != null,
        'client_type': _supabase.runtimeType.toString(),
      };

      // خطوة 2: فحص المصادقة باستخدام AuthStateManager
      final authTests = <String, dynamic>{};

      // طريقة 1: AuthStateManager.getCurrentUser()
      final authStateUser = await AuthStateManager.getCurrentUser();
      authTests['method_1_auth_state_manager'] = {
        'user_id': authStateUser?.id,
        'user_email': authStateUser?.email,
        'is_null': authStateUser == null,
      };

      // طريقة 2: _supabase.auth.currentUser (للمقارنة)
      final user1 = _supabase.auth.currentUser;
      authTests['method_2_supabase_auth'] = {
        'user_id': user1?.id,
        'user_email': user1?.email,
        'is_null': user1 == null,
      };

      // طريقة 3: Supabase.instance.client.auth.currentUser (للمقارنة)
      final user2 = Supabase.instance.client.auth.currentUser;
      authTests['method_3_instance_auth'] = {
        'user_id': user2?.id,
        'user_email': user2?.email,
        'is_null': user2 == null,
      };

      // طريقة 4: فحص الجلسة
      final session1 = _supabase.auth.currentSession;
      final session2 = Supabase.instance.client.auth.currentSession;
      authTests['sessions'] = {
        'supabase_session_exists': session1 != null,
        'instance_session_exists': session2 != null,
        'supabase_session_expired': session1?.isExpired,
        'instance_session_expired': session2?.isExpired,
        'sessions_match': session1?.accessToken == session2?.accessToken,
        'auth_state_user_matches_session': authStateUser?.id == session1?.user.id,
      };

      results['steps']['authentication'] = authTests;

      // خطوة 3: اختبار الاستعلامات المباشرة
      final queryTests = <String, dynamic>{};

      try {
        // اختبار استعلام user_profiles
        final profileQuery = await _supabase
            .from('user_profiles')
            .select('count')
            .count(CountOption.exact);
        queryTests['user_profiles_query'] = {
          'success': true,
          'count': profileQuery.count,
        };
      } catch (e) {
        queryTests['user_profiles_query'] = {
          'success': false,
          'error': e.toString(),
        };
      }

      try {
        // اختبار استعلام warehouses
        final warehouseQuery = await _supabase
            .from('warehouses')
            .select('id')
            .count();
        queryTests['warehouses_query'] = {
          'success': true,
          'count': warehouseQuery.count,
        };
      } catch (e) {
        queryTests['warehouses_query'] = {
          'success': false,
          'error': e.toString(),
        };
      }

      results['steps']['database_queries'] = queryTests;

      // خطوة 4: اختبار RLS policies باستخدام AuthStateManager
      if (authStateUser != null) {
        try {
          // استخدام AuthStateManager للحصول على ملف المستخدم
          final userProfile = await AuthStateManager.getCurrentUserProfile();

          results['steps']['user_profile'] = {
            'success': userProfile != null,
            'profile': userProfile,
          };

          // اختبار الوصول للمخازن مع المستخدم الحالي
          final warehouses = await _supabase
              .from('warehouses')
              .select('*');

          results['steps']['warehouse_access_test'] = {
            'success': true,
            'warehouse_count': warehouses.length,
            'warehouses': warehouses,
          };

        } catch (e) {
          results['steps']['authenticated_queries'] = {
            'success': false,
            'error': e.toString(),
          };
        }
      } else {
        results['steps']['authenticated_queries'] = {
          'success': false,
          'error': 'لا يوجد مستخدم مصادق عليه من AuthStateManager',
        };
      }

      results['overall_success'] = true;
      return results;

    } catch (e, stackTrace) {
      AppLogger.error('❌ خطأ في التشخيص الشامل: $e');
      return {
        'overall_success': false,
        'error': e.toString(),
        'stack_trace': stackTrace.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// اختبار سريع لتحميل المخازن مع تشخيص مفصل باستخدام AuthStateManager
  Future<Map<String, dynamic>> testWarehouseAccess() async {
    try {
      AppLogger.info('🧪 === بدء اختبار الوصول للمخازن مع AuthStateManager ===');

      // اختبار 1: التحقق من المصادقة باستخدام AuthStateManager
      final currentUser = await AuthStateManager.getCurrentUser();
      if (currentUser == null) {
        return {
          'success': false,
          'step': 'authentication',
          'error': 'لا يوجد مستخدم مسجل دخول',
          'details': 'فشل في الخطوة الأولى - المصادقة باستخدام AuthStateManager'
        };
      }

      AppLogger.info('✅ اختبار 1: المصادقة نجحت مع AuthStateManager - ${currentUser.id}');

      // اختبار 2: جلب ملف المستخدم باستخدام AuthStateManager
      Map<String, dynamic>? userProfile;
      try {
        userProfile = await AuthStateManager.getCurrentUserProfile();
        if (userProfile != null) {
          AppLogger.info('✅ اختبار 2: ملف المستخدم مع AuthStateManager - ${userProfile['role']}');
        } else {
          AppLogger.warning('⚠️ اختبار 2: AuthStateManager أرجع null لملف المستخدم');
        }
      } catch (e) {
        AppLogger.warning('⚠️ اختبار 2: فشل في جلب ملف المستخدم مع AuthStateManager - $e');
      }

      // اختبار 3: استعلام المخازن المباشر
      final warehouses = await _supabase
          .from('warehouses')
          .select('*')
          .order('name');

      AppLogger.info('✅ اختبار 3: استعلام المخازن نجح - ${warehouses.length} مخزن');

      // اختبار 4: استعلام المخازن النشطة
      final activeWarehouses = await _supabase
          .from('warehouses')
          .select('*')
          .eq('is_active', true)
          .order('name');

      AppLogger.info('✅ اختبار 4: المخازن النشطة - ${activeWarehouses.length} مخزن');

      return {
        'success': true,
        'user_id': currentUser.id,
        'user_email': currentUser.email,
        'user_profile': userProfile,
        'total_warehouses': warehouses.length,
        'active_warehouses': activeWarehouses.length,
        'warehouse_names': warehouses.map((w) => w['name']).toList(),
        'test_completed_at': DateTime.now().toIso8601String(),
      };

    } catch (e, stackTrace) {
      AppLogger.error('❌ فشل اختبار الوصول للمخازن: $e');
      AppLogger.error('📍 تفاصيل الخطأ: $stackTrace');

      return {
        'success': false,
        'error': e.toString(),
        'stack_trace': stackTrace.toString(),
        'test_failed_at': DateTime.now().toIso8601String(),
      };
    }
  }

  /// تشخيص شامل لصلاحيات المخازن باستخدام AuthStateManager
  Future<Map<String, dynamic>> diagnoseWarehousePermissions() async {
    try {
      AppLogger.info('🔍 بدء تشخيص صلاحيات المخازن مع AuthStateManager...');

      final currentUser = await AuthStateManager.getCurrentUser();
      if (currentUser == null) {
        return {
          'success': false,
          'error': 'لا يوجد مستخدم مسجل دخول (AuthStateManager)',
          'user_id': null,
          'user_role': null,
          'warehouse_count': 0,
        };
      }

      // جلب بيانات المستخدم باستخدام AuthStateManager
      final userProfile = await AuthStateManager.getCurrentUserProfile();
      if (userProfile == null) {
        return {
          'success': false,
          'error': 'فشل في جلب ملف المستخدم (AuthStateManager)',
          'user_id': currentUser.id,
          'user_role': null,
          'warehouse_count': 0,
        };
      }

      AppLogger.info('👤 ملف المستخدم للتشخيص مع AuthStateManager: $userProfile');

      // اختبار استعلام المخازن المباشر
      final warehousesResponse = await Supabase.instance.client
          .from('warehouses')
          .select('id, name, is_active, created_by')
          .order('name');

      AppLogger.info('📦 استجابة المخازن المباشرة: $warehousesResponse');

      // اختبار استعلام المخازن النشطة فقط
      final activeWarehousesResponse = await Supabase.instance.client
          .from('warehouses')
          .select('id, name, is_active, created_by')
          .eq('is_active', true)
          .order('name');

      AppLogger.info('🟢 استجابة المخازن النشطة: $activeWarehousesResponse');

      // اختبار عدد المخازن
      final countResponse = await Supabase.instance.client
          .from('warehouses')
          .select('id')
          .count();

      AppLogger.info('🔢 عدد المخازن الإجمالي: ${countResponse.count}');

      return {
        'success': true,
        'user_id': currentUser.id,
        'user_email': currentUser.email,
        'user_role': userProfile['role'],
        'user_status': userProfile['status'],
        'is_approved': userProfile['is_approved'],
        'approval_status_message': userProfile['is_approved'] == true
            ? 'المستخدم معتمد ✅'
            : 'المستخدم غير معتمد ❌ - هذا هو سبب عدم ظهور المخازن',
        'total_warehouses': warehousesResponse.length,
        'active_warehouses': activeWarehousesResponse.length,
        'warehouse_count_from_count_query': countResponse.count,
        'raw_warehouses_response': warehousesResponse,
        'raw_active_warehouses_response': activeWarehousesResponse,
        'rls_policy_check': userProfile['is_approved'] == true
            ? 'RLS policies allow access'
            : 'RLS policies BLOCKING access - user not approved',
      };
    } catch (e, stackTrace) {
      AppLogger.error('❌ خطأ في تشخيص صلاحيات المخازن: $e');
      AppLogger.error('📍 تفاصيل الخطأ: $stackTrace');

      return {
        'success': false,
        'error': e.toString(),
        'stack_trace': stackTrace.toString(),
      };
    }
  }

  /// 🚨 SECURITY FIX: Disabled dangerous role update function
  /// This function was causing privilege escalation vulnerabilities
  Future<bool> updateCurrentUserRole(String newRole) async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        AppLogger.error('❌ لا يوجد مستخدم مسجل دخول');
        return false;
      }

      // 🚨 CRITICAL SECURITY ALERT
      AppLogger.error('🚨 SECURITY ALERT: Role update function called');
      AppLogger.error('🔒 User: ${currentUser.id} attempted to change role to: $newRole');
      AppLogger.error('❌ BLOCKED: This function causes privilege escalation');
      AppLogger.error('💡 Contact system administrator for proper role management');

      // 🔒 SECURITY: Do NOT allow role modifications through this function
      // This was causing warehouse managers to become admins
      return false;
    } catch (e) {
      AppLogger.error('❌ خطأ في محاولة تحديث دور المستخدم: $e');
      return false;
    }
  }

  /// تحديث مخزن
  Future<WarehouseModel?> updateWarehouse({
    required String warehouseId,
    String? name,
    String? address,
    String? description,
    bool? isActive,
  }) async {
    try {
      AppLogger.info('🏢 جاري تحديث المخزن: $warehouseId');

      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (address != null) data['address'] = address;
      if (description != null) data['description'] = description;
      if (isActive != null) data['is_active'] = isActive;

      final response = await _supabaseService.updateRecord('warehouses', warehouseId, data);
      final warehouse = WarehouseModel.fromJson(response);

      AppLogger.info('✅ تم تحديث المخزن بنجاح');
      return warehouse;
    } catch (e) {
      AppLogger.error('❌ خطأ في تحديث المخزن: $e');
      return null;
    }
  }

  /// التأكد من وجود المنتج في قاعدة البيانات مع تحميل البيانات من API
  Future<void> _ensureProductExists(String productId) async {
    try {
      AppLogger.info('🔍 التحقق من وجود المنتج: $productId');

      // التحقق من وجود المنتج في قاعدة البيانات
      final existingProduct = await Supabase.instance.client
          .from('products')
          .select('*')
          .eq('id', productId)
          .maybeSingle();

      if (existingProduct != null) {
        AppLogger.info('✅ المنتج موجود بالفعل في قاعدة البيانات');
        return;
      }

      AppLogger.info('📥 المنتج غير موجود، جاري تحميل البيانات من API...');

      // محاولة تحميل المنتج من API
      final apiProduct = await _apiProductSyncService.getProductFromApi(productId);

      if (apiProduct != null) {
        // إنشاء منتج من بيانات API المحسنة
        await _createProductFromApiData(productId, apiProduct);

        // تسجيل معلومات مفصلة عن المنتج المُنشأ
        final productName = apiProduct['name']?.toString() ?? 'منتج غير محدد';
        final productCategory = apiProduct['category']?.toString() ?? 'غير محدد';
        final productPrice = apiProduct['price']?.toString() ?? '0';

        AppLogger.info('✅ تم إنشاء المنتج من بيانات API الحقيقية:');
        AppLogger.info('   المعرف: $productId');
        AppLogger.info('   الاسم: ${apiProduct['name']}');
        AppLogger.info('   الفئة: ${apiProduct['category']}');
        AppLogger.info('   السعر: ${apiProduct['price']}');
        AppLogger.info('   المصدر: ${apiProduct['metadata']?['api_source'] ?? 'unknown'}');
        AppLogger.info('   جودة البيانات: بيانات حقيقية من API');
      } else {
        // إنشاء منتج افتراضي إذا لم يوجد في API
        AppLogger.warning('⚠️ المنتج غير موجود في API، جاري إنشاء منتج افتراضي محسن');
        await _createDefaultProduct(productId);
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في التأكد من وجود المنتج: $e');

      // في حالة الفشل، إنشاء منتج افتراضي
      try {
        await _createDefaultProduct(productId);
      } catch (fallbackError) {
        AppLogger.error('❌ فشل في إنشاء منتج افتراضي: $fallbackError');
        throw Exception('فشل في إنشاء المنتج في قاعدة البيانات');
      }
    }
  }

  /// إنشاء منتج من بيانات API الحقيقية
  Future<void> _createProductFromApiData(String productId, Map<String, dynamic> apiProduct) async {
    try {
      AppLogger.info('📦 إنشاء منتج من بيانات API: ${apiProduct['name']}');

      // تحضير قائمة الصور
      final List<String> imageUrls = [];

      // إضافة الصورة الرئيسية
      if (apiProduct['image_url'] != null && apiProduct['image_url'].toString().isNotEmpty) {
        imageUrls.add(apiProduct['image_url'].toString());
      }

      // إضافة الصور الإضافية إذا كانت متوفرة
      if (apiProduct['images'] is List) {
        for (final img in apiProduct['images']) {
          if (img != null && img.toString().isNotEmpty && !imageUrls.contains(img.toString())) {
            imageUrls.add(img.toString());
          }
        }
      }

      // التحقق من جودة البيانات المستلمة من API
      final productName = apiProduct['name']?.toString();
      final productDescription = apiProduct['description']?.toString();
      final productCategory = apiProduct['category']?.toString();
      final apiSource = apiProduct['metadata']?['api_source']?.toString() ?? 'unknown';

      // التأكد من أن البيانات ليست عامة أو مولدة
      if (productName == null ||
          productName.isEmpty ||
          productName.contains('منتج $productId من API') ||
          productName.contains('منتج رقم $productId') ||
          productName.contains('منتج $productId')) {
        AppLogger.warning('⚠️ تم استلام اسم منتج عام من API: $productName');
        throw Exception('بيانات المنتج المستلمة من API عامة أو غير صحيحة');
      }

      // تحضير بيانات المنتج للإدراج مع التحقق من صحة البيانات
      final productData = {
        'id': productId,
        'name': productName,
        'description': productDescription ?? 'منتج عالي الجودة',
        'price': (apiProduct['price'] as num?)?.toDouble() ?? 0.0,
        'sale_price': (apiProduct['sale_price'] as num?)?.toDouble(),
        'category': productCategory ?? 'إلكترونيات',
        'image_url': imageUrls.isNotEmpty ? imageUrls.first : null,
        'main_image_url': imageUrls.isNotEmpty ? imageUrls.first : null,
        'images': imageUrls, // قائمة الصور كـ JSONB
        'sku': apiProduct['sku']?.toString() ?? 'SKU-$productId',
        'barcode': apiProduct['barcode']?.toString(),
        'manufacturer': apiProduct['manufacturer']?.toString(),
        'supplier': apiProduct['supplier']?.toString() ?? 'مورد معتمد',
        'active': apiProduct['is_active'] ?? apiProduct['active'] ?? true,
        'quantity': 0, // الكمية ستكون في warehouse_inventory
        'minimum_stock': (apiProduct['minimum_stock'] as num?)?.toInt() ?? 10,
        'reorder_point': (apiProduct['reorder_point'] as num?)?.toInt() ?? 10,
        'source': 'external_api',
        'external_id': productId,
        'original_price': (apiProduct['original_price'] as num?)?.toDouble(),
        'purchase_price': (apiProduct['purchase_price'] as num?)?.toDouble(),
        'discount_price': (apiProduct['discount_price'] as num?)?.toDouble(),
        'tags': apiProduct['tags'] ?? [],
        'metadata': {
          'api_source': apiSource,
          'imported_at': DateTime.now().toIso8601String(),
          'original_data': apiProduct,
          'data_quality': 'verified_real_data',
        },
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // إدراج المنتج في قاعدة البيانات
      await Supabase.instance.client
          .from('products')
          .insert(productData);

      AppLogger.info('✅ تم إنشاء المنتج من بيانات API بنجاح: ${productData['name']}');
      AppLogger.info('🖼️ تم إضافة ${imageUrls.length} صورة للمنتج');
    } catch (e) {
      AppLogger.error('❌ خطأ في إنشاء المنتج من بيانات API: $e');
      throw e;
    }
  }

  /// إنشاء منتج مؤقت للعرض فقط (بدون تعديل قاعدة البيانات)
  ProductModel _createTemporaryProductForDisplay(String productId) {
    AppLogger.info('📦 إنشاء منتج مؤقت للعرض: $productId');

    return ProductModel(
      id: productId,
      name: 'منتج مؤقت - معرف: $productId (يحتاج تحديث)',
      description: 'منتج مؤقت للعرض - يحتاج إضافة بيانات حقيقية',
      price: 0.0,
      quantity: 0,
      category: 'غير محدد',
      isActive: true,
      sku: 'TEMP-$productId',
      reorderPoint: 10,
      images: [],
      createdAt: DateTime.now(),
      minimumStock: 10,
    );
  }

  /// إنشاء منتج افتراضي للمنتجات المفقودة (للاستخدام في عمليات الإضافة فقط)
  Future<void> _createDefaultProduct(String productId) async {
    try {
      AppLogger.info('📦 إنشاء منتج افتراضي للمعرف: $productId');

      // محاولة الحصول على بيانات المنتج من API أولاً
      String productName = 'منتج $productId';
      String productDescription = 'منتج تم إنشاؤه تلقائياً من نظام المخازن';
      String productCategory = 'عام';
      double productPrice = 0.0;

      try {
        final apiProduct = await _apiProductSyncService.getProductFromApi(productId);
        if (apiProduct != null) {
          productName = apiProduct['name']?.toString() ?? productName;
          productDescription = apiProduct['description']?.toString() ?? productDescription;
          productCategory = apiProduct['category']?.toString() ?? productCategory;
          productPrice = (apiProduct['price'] as num?)?.toDouble() ?? productPrice;
          AppLogger.info('✅ تم الحصول على بيانات المنتج من API للمنتج الافتراضي');
        }
      } catch (apiError) {
        AppLogger.warning('⚠️ فشل في تحميل بيانات المنتج من API، استخدام البيانات الافتراضية: $apiError');
      }

      // إنشاء منتج افتراضي مباشرة في قاعدة البيانات
      final defaultProductData = {
        'id': productId,
        'name': productName,
        'description': productDescription,
        'price': productPrice,
        'category': productCategory,
        'sku': 'DEFAULT-$productId',
        'active': true,  // Use 'active' instead of 'is_active'
        'quantity': 0,
        'images': [],  // Use empty array instead of <String>[]
        'minimum_stock': 10,
        'reorder_point': 10,
        'source': 'warehouse_system',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await Supabase.instance.client
          .from('products')
          .insert(defaultProductData);

      AppLogger.info('✅ تم إنشاء المنتج الافتراضي بنجاح: $productId');
    } catch (e) {
      AppLogger.error('❌ خطأ في إنشاء المنتج الافتراضي: $e');
      throw e;
    }
  }

  /// حذف مخزن مع التعامل مع القيود الخارجية
  Future<bool> deleteWarehouse(String warehouseId, {bool forceDelete = false, String? targetWarehouseId}) async {
    try {
      AppLogger.info('🏢 جاري حذف المخزن: $warehouseId (قسري: $forceDelete)');

      if (forceDelete && targetWarehouseId != null) {
        // تنفيذ الحذف القسري مع نقل الطلبات
        return await _executeForceDeleteWithTransfer(warehouseId, targetWarehouseId);
      }

      // التحقق من وجود طلبات مرتبطة بالمخزن (الحذف العادي)
      final relatedRequests = await _checkWarehouseRelatedRecords(warehouseId);

      if (relatedRequests['hasActiveRequests'] == true) {
        final requestCount = relatedRequests['requestCount'] ?? 0;
        final inventoryCount = relatedRequests['inventoryCount'] ?? 0;

        AppLogger.warning('⚠️ لا يمكن حذف المخزن: يحتوي على $requestCount طلب و $inventoryCount منتج');
        throw Exception(
          'لا يمكن حذف المخزن لأنه يحتوي على:\n'
          '• $requestCount طلب نشط\n'
          '• $inventoryCount منتج في المخزون\n\n'
          'يرجى إزالة جميع الطلبات والمنتجات أولاً أو نقلها إلى مخزن آخر.'
        );
      }

      // إذا لم توجد قيود، قم بالحذف الآمن
      await _safeDeleteWarehouse(warehouseId);

      AppLogger.info('✅ تم حذف المخزن بنجاح');
      return true;
    } catch (e) {
      AppLogger.error('❌ خطأ في حذف المخزن: $e');

      // تحسين رسائل الخطأ
      if (e.toString().contains('foreign key constraint')) {
        throw Exception(
          'لا يمكن حذف المخزن لأنه مرتبط بسجلات أخرى في النظام.\n'
          'يرجى إزالة جميع الطلبات والمنتجات المرتبطة بهذا المخزن أولاً.'
        );
      }

      return false;
    }
  }

  /// تنفيذ الحذف القسري مع نقل الطلبات التلقائي
  Future<bool> _executeForceDeleteWithTransfer(String warehouseId, String targetWarehouseId) async {
    try {
      AppLogger.info('🔥 بدء الحذف القسري للمخزن مع نقل الطلبات: $warehouseId -> $targetWarehouseId');

      // استخدام دالة قاعدة البيانات للحذف القسري مع النقل
      final result = await Supabase.instance.client.rpc(
        'force_delete_warehouse_with_transfer',
        params: {
          'p_warehouse_id': warehouseId,
          'p_target_warehouse_id': targetWarehouseId,
          'p_performed_by': null, // سيستخدم المستخدم الحالي
          'p_force_options': {
            'force_delete': true,
            'auto_transfer': true,
          },
        },
      );

      if (result == null) {
        throw Exception('لم يتم إرجاع نتائج من دالة الحذف القسري');
      }

      final success = result['success'] ?? false;
      final operationId = result['operation_id'] ?? 'unknown';
      final warehouseName = result['warehouse_name'] ?? 'غير معروف';
      final duration = result['duration_seconds'] ?? 0;
      final transferResult = result['transfer_result'] ?? {};
      final cleanupResult = result['cleanup_result'] ?? {};
      final errors = List<String>.from(result['errors'] ?? []);

      if (success) {
        final transferredOrders = transferResult['transferred_count'] ?? 0;
        AppLogger.info('✅ تم الحذف القسري بنجاح في ${duration.toStringAsFixed(2)} ثانية');
        AppLogger.info('📦 تم نقل $transferredOrders طلب إلى المخزن الهدف');

        if (errors.isNotEmpty) {
          AppLogger.warning('⚠️ تحذيرات أثناء الحذف القسري: ${errors.join(', ')}');
        }

        return true;
      } else {
        final errorMessage = errors.isNotEmpty ? errors.join(', ') : 'فشل غير معروف';
        AppLogger.error('❌ فشل الحذف القسري: $errorMessage');
        throw Exception('فشل في الحذف القسري: $errorMessage');
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في تنفيذ الحذف القسري: $e');
      throw Exception('خطأ في الحذف القسري: $e');
    }
  }

  /// التحقق من السجلات المرتبطة بالمخزن مع تفاصيل شاملة للحذف
  Future<WarehouseDeletionAnalysis> analyzeWarehouseDeletion(String warehouseId) async {
    try {
      AppLogger.info('🔍 تحليل شامل لإمكانية حذف المخزن: $warehouseId');

      // الحصول على تفاصيل المخزن
      final warehouse = await getWarehouse(warehouseId);
      if (warehouse == null) {
        throw Exception('المخزن غير موجود');
      }

      // تحليل الطلبات النشطة
      final activeRequests = await _analyzeActiveRequests(warehouseId);

      // تحليل المخزون
      final inventoryAnalysis = await _analyzeInventoryItems(warehouseId);

      // تحليل المعاملات
      final transactionAnalysis = await _analyzeTransactions(warehouseId);

      // تحديد إمكانية الحذف والخطوات المطلوبة
      final canDelete = activeRequests.isEmpty && inventoryAnalysis.totalItems == 0;
      final blockingFactors = <String>[];
      final requiredActions = <WarehouseDeletionAction>[];

      if (activeRequests.isNotEmpty) {
        blockingFactors.add('${activeRequests.length} طلب نشط');
        requiredActions.add(WarehouseDeletionAction(
          type: DeletionActionType.manageRequests,
          title: 'إدارة الطلبات النشطة',
          description: 'يجب إكمال أو إلغاء ${activeRequests.length} طلب نشط',
          priority: DeletionActionPriority.high,
          estimatedTime: '5-15 دقيقة',
          affectedItems: activeRequests.length,
        ));
      }

      if (inventoryAnalysis.totalItems > 0) {
        blockingFactors.add('${inventoryAnalysis.totalItems} منتج في المخزون');
        requiredActions.add(WarehouseDeletionAction(
          type: DeletionActionType.manageInventory,
          title: 'إدارة المخزون',
          description: 'يجب نقل أو إزالة ${inventoryAnalysis.totalItems} منتج (${inventoryAnalysis.totalQuantity} قطعة)',
          priority: DeletionActionPriority.high,
          estimatedTime: '10-30 دقيقة',
          affectedItems: inventoryAnalysis.totalItems,
        ));
      }

      if (transactionAnalysis.recentTransactions > 0) {
        requiredActions.add(WarehouseDeletionAction(
          type: DeletionActionType.archiveTransactions,
          title: 'أرشفة المعاملات',
          description: 'أرشفة ${transactionAnalysis.totalTransactions} معاملة للحفظ',
          priority: DeletionActionPriority.medium,
          estimatedTime: '2-5 دقائق',
          affectedItems: transactionAnalysis.totalTransactions,
        ));
      }

      return WarehouseDeletionAnalysis(
        warehouseId: warehouseId,
        warehouseName: warehouse.name,
        canDelete: canDelete,
        blockingFactors: blockingFactors,
        requiredActions: requiredActions,
        activeRequests: activeRequests,
        inventoryAnalysis: inventoryAnalysis,
        transactionAnalysis: transactionAnalysis,
        estimatedCleanupTime: _calculateEstimatedTime(requiredActions),
        riskLevel: _calculateRiskLevel(activeRequests.length, inventoryAnalysis.totalQuantity, transactionAnalysis.recentTransactions),
      );
    } catch (e) {
      AppLogger.error('❌ خطأ في تحليل حذف المخزن: $e');
      throw Exception('فشل في تحليل إمكانية حذف المخزن: $e');
    }
  }

  /// التحقق من السجلات المرتبطة بالمخزن باستخدام دالة قاعدة البيانات (للتوافق مع الكود الحالي)
  Future<Map<String, dynamic>> _checkWarehouseRelatedRecords(String warehouseId) async {
    try {
      final analysis = await analyzeWarehouseDeletion(warehouseId);

      return {
        'hasActiveRequests': !analysis.canDelete,
        'requestCount': analysis.activeRequests.length,
        'activeRequestCount': analysis.activeRequests.length,
        'inventoryCount': analysis.inventoryAnalysis.totalItems,
        'totalQuantity': analysis.inventoryAnalysis.totalQuantity,
        'blockingReason': analysis.blockingFactors.join(', '),
        'canDelete': analysis.canDelete,
      };
    } catch (e) {
      AppLogger.error('❌ خطأ في التحقق من السجلات المرتبطة: $e');
      return await _fallbackCheckRelatedRecords(warehouseId);
    }
  }

  /// تحليل الطلبات النشطة في المخزن
  Future<List<WarehouseRequestSummary>> _analyzeActiveRequests(String warehouseId) async {
    try {
      final response = await Supabase.instance.client
          .from('warehouse_requests')
          .select('''
            id,
            type,
            status,
            reason,
            requested_by,
            created_at,
            requester:user_profiles!requested_by (
              name,
              email
            )
          ''')
          .eq('warehouse_id', warehouseId)
          .not('status', 'in', '(completed,cancelled)');

      return response.map<WarehouseRequestSummary>((item) {
        final requesterData = item['requester'] as Map<String, dynamic>?;
        return WarehouseRequestSummary(
          id: item['id'],
          type: item['type'],
          status: item['status'],
          reason: item['reason'] ?? '',
          requestedBy: item['requested_by'],
          requesterName: requesterData?['name'] ?? 'غير معروف',
          createdAt: DateTime.parse(item['created_at']),
        );
      }).toList();
    } catch (e) {
      AppLogger.error('❌ خطأ في تحليل الطلبات النشطة: $e');
      return [];
    }
  }

  /// تحليل عناصر المخزون
  Future<InventoryAnalysis> _analyzeInventoryItems(String warehouseId) async {
    try {
      final response = await Supabase.instance.client
          .from('warehouse_inventory')
          .select('id, product_id, quantity, minimum_stock')
          .eq('warehouse_id', warehouseId);

      final totalItems = response.length;
      final totalQuantity = response.fold<int>(0, (sum, item) => sum + (item['quantity'] as int? ?? 0));
      final lowStockItems = response.where((item) =>
          (item['quantity'] as int? ?? 0) <= (item['minimum_stock'] as int? ?? 0)
      ).length;

      return InventoryAnalysis(
        totalItems: totalItems,
        totalQuantity: totalQuantity,
        lowStockItems: lowStockItems,
        highValueItems: 0, // يمكن تحسينه لاحقاً بحساب القيمة
      );
    } catch (e) {
      AppLogger.error('❌ خطأ في تحليل المخزون: $e');
      return InventoryAnalysis(totalItems: 0, totalQuantity: 0, lowStockItems: 0, highValueItems: 0);
    }
  }

  /// تحليل المعاملات
  Future<TransactionAnalysis> _analyzeTransactions(String warehouseId) async {
    try {
      final response = await Supabase.instance.client
          .from('warehouse_transactions')
          .select('id, performed_at, type')
          .eq('warehouse_id', warehouseId);

      final totalTransactions = response.length;
      final recentTransactions = response.where((item) {
        final performedAt = DateTime.parse(item['performed_at']);
        return DateTime.now().difference(performedAt).inDays <= 30;
      }).length;

      return TransactionAnalysis(
        totalTransactions: totalTransactions,
        recentTransactions: recentTransactions,
      );
    } catch (e) {
      AppLogger.error('❌ خطأ في تحليل المعاملات: $e');
      return TransactionAnalysis(totalTransactions: 0, recentTransactions: 0);
    }
  }

  /// الحصول على معاملات المخزن للعرض في واجهة المستخدم
  Future<List<WarehouseTransactionModel>> getWarehouseTransactions(
    String warehouseId, {
    int limit = 50,
    int offset = 0,
    String? transactionType,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final timer = TimedOperation('warehouse_transactions_loading');

    try {
      AppLogger.info('📋 Loading warehouse transactions for warehouse: $warehouseId');

      // التحقق من صحة معرف المخزن
      final validWarehouseId = _ensureWarehouseIdFormat(warehouseId);
      AppLogger.info('🔍 Using validated warehouse ID: $validWarehouseId');

      // بناء الاستعلام بالنمط الصحيح: from().select() أولاً ثم الفلاتر
      var query = _supabase
          .from('warehouse_transactions')
          .select('*')
          .eq('warehouse_id', validWarehouseId);

      AppLogger.info('🔍 Query filters - warehouse_id: $validWarehouseId');

      // تطبيق فلاتر إضافية بعد select()
      if (transactionType != null && transactionType != 'all') {
        query = query.eq('type', transactionType);
        AppLogger.info('🔍 Added transaction type filter: $transactionType');
      }

      if (startDate != null) {
        query = query.gte('performed_at', startDate.toIso8601String());
        AppLogger.info('🔍 Added start date filter: ${startDate.toIso8601String()}');
      }

      if (endDate != null) {
        query = query.lte('performed_at', endDate.toIso8601String());
        AppLogger.info('🔍 Added end date filter: ${endDate.toIso8601String()}');
      }

      // تطبيق الترتيب والنطاق
      final response = await query
          .order('performed_at', ascending: false)
          .range(offset, offset + limit - 1);

      // Process transactions and manually load product information
      final List<WarehouseTransactionModel> transactions = [];
      final Set<String> productIds = {};

      // First pass: collect all product IDs
      for (final json in response) {
        final transactionData = json as Map<String, dynamic>;
        final productId = transactionData['product_id'] as String?;
        if (productId != null && productId.isNotEmpty) {
          productIds.add(productId);
        }
      }

      // Batch load products to avoid N+1 queries
      final Map<String, Map<String, dynamic>> productsMap = {};
      if (productIds.isNotEmpty) {
        try {
          final productsResponse = await Supabase.instance.client
              .from('products')
              .select('id, name, sku, category, image_url')
              .inFilter('id', productIds.toList());

          for (final productJson in productsResponse) {
            final productData = productJson as Map<String, dynamic>;
            productsMap[productData['id']] = productData;
          }
          AppLogger.info('✅ Batch loaded ${productsMap.length} products for transactions');
        } catch (e) {
          AppLogger.warning('⚠️ Failed to batch load products: $e');
        }
      }

      // Second pass: create transaction models with product data
      for (final json in response) {
        try {
          final transactionData = json as Map<String, dynamic>;
          final productId = transactionData['product_id'] as String?;

          // Add product data if available
          if (productId != null && productsMap.containsKey(productId)) {
            transactionData['products'] = productsMap[productId];
          }

          final transaction = WarehouseTransactionModel.fromJson(transactionData);
          transactions.add(transaction);
        } catch (e) {
          AppLogger.error('❌ Error processing transaction: $e');
        }
      }

      AppLogger.info('✅ Loaded ${transactions.length} warehouse transactions for warehouse: $validWarehouseId');

      // Log sample transaction data for debugging
      if (transactions.isNotEmpty) {
        final firstTransaction = transactions.first;
        AppLogger.info('📋 Sample transaction - ID: ${firstTransaction.id}, Type: ${firstTransaction.type}, Warehouse: ${firstTransaction.warehouseId}');
      }

      return timer.completeWithResult(transactions);
    } catch (e) {
      timer.complete();
      AppLogger.error('❌ Error loading warehouse transactions: $e');
      return [];
    }
  }

  /// الحصول على جميع معاملات المخزن (لجميع المخازن)
  Future<List<WarehouseTransactionModel>> getAllWarehouseTransactions({
    int limit = 100,
    int offset = 0,
    String? transactionType,
    String? warehouseId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final timer = TimedOperation('all_warehouse_transactions_loading');

    try {
      AppLogger.info('📋 Loading all warehouse transactions');

      // بناء الاستعلام بالنمط الصحيح: from().select() أولاً ثم الفلاتر
      var query = _supabase.from('warehouse_transactions').select('*');

      // تطبيق فلاتر إضافية بعد select()
      if (warehouseId != null && warehouseId != 'all') {
        final validWarehouseId = _ensureWarehouseIdFormat(warehouseId);
        query = query.eq('warehouse_id', validWarehouseId);
      }

      if (transactionType != null && transactionType != 'all') {
        query = query.eq('type', transactionType);
      }

      if (startDate != null) {
        query = query.gte('performed_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('performed_at', endDate.toIso8601String());
      }

      // تطبيق الترتيب والنطاق
      final response = await query
          .order('performed_at', ascending: false)
          .range(offset, offset + limit - 1);

      // Process transactions and manually load product and warehouse information
      final List<WarehouseTransactionModel> transactions = [];
      final Set<String> productIds = {};
      final Set<String> warehouseIds = {};

      // First pass: collect all product and warehouse IDs
      for (final json in response) {
        final transactionData = json as Map<String, dynamic>;
        final productId = transactionData['product_id'] as String?;
        final warehouseId = transactionData['warehouse_id'] as String?;
        if (productId != null && productId.isNotEmpty) {
          productIds.add(productId);
        }
        if (warehouseId != null && warehouseId.isNotEmpty) {
          warehouseIds.add(warehouseId);
        }
      }

      // Batch load products and warehouses to avoid N+1 queries
      final Map<String, Map<String, dynamic>> productsMap = {};
      final Map<String, Map<String, dynamic>> warehousesMap = {};

      if (productIds.isNotEmpty) {
        try {
          final productsResponse = await Supabase.instance.client
              .from('products')
              .select('id, name, sku, category, image_url')
              .inFilter('id', productIds.toList());

          for (final productJson in productsResponse) {
            final productData = productJson as Map<String, dynamic>;
            productsMap[productData['id']] = productData;
          }
          AppLogger.info('✅ Batch loaded ${productsMap.length} products for all transactions');
        } catch (e) {
          AppLogger.warning('⚠️ Failed to batch load products: $e');
        }
      }

      if (warehouseIds.isNotEmpty) {
        try {
          final warehousesResponse = await Supabase.instance.client
              .from('warehouses')
              .select('id, name, address')
              .inFilter('id', warehouseIds.toList());

          for (final warehouseJson in warehousesResponse) {
            final warehouseData = warehouseJson as Map<String, dynamic>;
            warehousesMap[warehouseData['id']] = warehouseData;
          }
          AppLogger.info('✅ Batch loaded ${warehousesMap.length} warehouses for all transactions');
        } catch (e) {
          AppLogger.warning('⚠️ Failed to batch load warehouses: $e');
        }
      }

      // Second pass: create transaction models with product and warehouse data
      for (final json in response) {
        try {
          final transactionData = json as Map<String, dynamic>;
          final productId = transactionData['product_id'] as String?;
          final warehouseId = transactionData['warehouse_id'] as String?;

          // Add product data if available
          if (productId != null && productsMap.containsKey(productId)) {
            transactionData['products'] = productsMap[productId];
          }

          // Add warehouse data if available
          if (warehouseId != null && warehousesMap.containsKey(warehouseId)) {
            transactionData['warehouses'] = warehousesMap[warehouseId];
          }

          final transaction = WarehouseTransactionModel.fromJson(transactionData);
          transactions.add(transaction);
        } catch (e) {
          AppLogger.error('❌ Error processing transaction: $e');
        }
      }

      AppLogger.info('✅ Loaded ${transactions.length} total warehouse transactions');
      return timer.completeWithResult(transactions);
    } catch (e) {
      timer.complete();
      AppLogger.error('❌ Error loading all warehouse transactions: $e');
      return [];
    }
  }

  /// حساب الوقت المقدر للتنظيف
  String _calculateEstimatedTime(List<WarehouseDeletionAction> actions) {
    if (actions.isEmpty) return '< 1 دقيقة';

    final highPriorityActions = actions.where((a) => a.priority == DeletionActionPriority.high).length;
    final mediumPriorityActions = actions.where((a) => a.priority == DeletionActionPriority.medium).length;

    final estimatedMinutes = (highPriorityActions * 15) + (mediumPriorityActions * 5);

    if (estimatedMinutes < 5) return '< 5 دقائق';
    if (estimatedMinutes < 15) return '5-15 دقيقة';
    if (estimatedMinutes < 30) return '15-30 دقيقة';
    return '30+ دقيقة';
  }

  /// حساب مستوى المخاطر
  DeletionRiskLevel _calculateRiskLevel(int activeRequests, int totalQuantity, int recentTransactions) {
    if (activeRequests > 5 || totalQuantity > 1000 || recentTransactions > 50) {
      return DeletionRiskLevel.high;
    } else if (activeRequests > 2 || totalQuantity > 100 || recentTransactions > 10) {
      return DeletionRiskLevel.medium;
    } else if (activeRequests > 0 || totalQuantity > 0 || recentTransactions > 0) {
      return DeletionRiskLevel.low;
    }
    return DeletionRiskLevel.none;
  }

  /// طريقة احتياطية للتحقق من السجلات المرتبطة
  Future<Map<String, dynamic>> _fallbackCheckRelatedRecords(String warehouseId) async {
    try {
      AppLogger.info('🔄 استخدام الطريقة الاحتياطية للتحقق من السجلات المرتبطة');

      // التحقق من طلبات المخزن
      final requestsResponse = await Supabase.instance.client
          .from('warehouse_requests')
          .select('id, status')
          .eq('warehouse_id', warehouseId);

      final requestCount = requestsResponse.length;
      final activeRequests = requestsResponse.where((req) =>
          req['status'] != 'completed' && req['status'] != 'cancelled'
      ).length;

      // التحقق من مخزون المخزن
      final inventoryResponse = await Supabase.instance.client
          .from('warehouse_inventory')
          .select('id, quantity')
          .eq('warehouse_id', warehouseId);

      final inventoryCount = inventoryResponse.length;
      final totalQuantity = inventoryResponse.fold<int>(0, (sum, item) =>
          sum + (item['quantity'] as int? ?? 0)
      );

      final result = {
        'hasActiveRequests': activeRequests > 0 || totalQuantity > 0,
        'requestCount': requestCount,
        'activeRequestCount': activeRequests,
        'inventoryCount': inventoryCount,
        'totalQuantity': totalQuantity,
        'blockingReason': activeRequests > 0
            ? 'يحتوي على طلبات نشطة'
            : totalQuantity > 0
                ? 'يحتوي على مخزون'
                : 'يمكن الحذف',
        'canDelete': activeRequests == 0 && totalQuantity == 0,
      };

      AppLogger.info('📊 نتائج التحقق (الطريقة الاحتياطية): $result');
      return result;
    } catch (e) {
      AppLogger.error('❌ خطأ في الطريقة الاحتياطية للتحقق: $e');
      return {'hasActiveRequests': true}; // افتراض وجود قيود للأمان
    }
  }

  /// حذف آمن للمخزن باستخدام دالة قاعدة البيانات
  Future<void> _safeDeleteWarehouse(String warehouseId) async {
    try {
      AppLogger.info('🧹 بدء الحذف الآمن للمخزن باستخدام دالة قاعدة البيانات: $warehouseId');

      // استخدام دالة الحذف الآمن في قاعدة البيانات
      final result = await Supabase.instance.client.rpc(
        'safe_delete_warehouse',
        params: {'p_warehouse_id': warehouseId},
      );

      if (result.isNotEmpty) {
        final deleteResult = result.first;
        final success = deleteResult['success'] as bool? ?? false;
        final message = deleteResult['message'] as String? ?? '';
        final deletedTransactions = deleteResult['deleted_transactions'] as int? ?? 0;
        final deletedRequests = deleteResult['deleted_requests'] as int? ?? 0;

        if (success) {
          AppLogger.info('✅ $message');
          AppLogger.info('📊 تم حذف $deletedTransactions معاملة و $deletedRequests طلب');
        } else {
          throw Exception(message);
        }
      } else {
        throw Exception('لم يتم الحصول على نتيجة من دالة الحذف الآمن');
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في الحذف الآمن: $e');

      // في حالة فشل الدالة، استخدم الطريقة التقليدية
      AppLogger.info('🔄 محاولة الحذف بالطريقة التقليدية...');
      await _fallbackDeleteWarehouse(warehouseId);
    }
  }

  /// طريقة احتياطية للحذف في حالة فشل الدالة المحسنة
  Future<void> _fallbackDeleteWarehouse(String warehouseId) async {
    try {
      AppLogger.info('🔄 بدء الحذف الاحتياطي للمخزن: $warehouseId');

      // حذف المعاملات أولاً (CASCADE)
      await Supabase.instance.client
          .from('warehouse_transactions')
          .delete()
          .eq('warehouse_id', warehouseId);

      AppLogger.info('✅ تم حذف معاملات المخزن');

      // حذف الطلبات المكتملة/الملغاة
      await Supabase.instance.client
          .from('warehouse_requests')
          .delete()
          .eq('warehouse_id', warehouseId)
          .inFilter('status', ['completed', 'cancelled']);

      AppLogger.info('✅ تم حذف الطلبات المكتملة/الملغاة');

      // حذف المخزون الفارغ
      await Supabase.instance.client
          .from('warehouse_inventory')
          .delete()
          .eq('warehouse_id', warehouseId)
          .eq('quantity', 0);

      AppLogger.info('✅ تم حذف المخزون الفارغ');

      // أخيراً، حذف المخزن نفسه
      await _supabaseService.deleteRecord('warehouses', warehouseId);

      AppLogger.info('✅ تم حذف المخزن نهائياً (الطريقة الاحتياطية)');
    } catch (e) {
      AppLogger.error('❌ خطأ في الحذف الاحتياطي: $e');
      throw e;
    }
  }

  /// الحصول على المخازن المتاحة للنقل
  Future<List<AvailableTargetWarehouse>> getAvailableTargetWarehouses(
    String sourceWarehouseId, {
    bool excludeEmpty = true,
  }) async {
    try {
      return await _orderTransferService.getAvailableTargetWarehouses(
        sourceWarehouseId,
        excludeEmpty: excludeEmpty,
      );
    } catch (e) {
      AppLogger.error('❌ خطأ في الحصول على المخازن المتاحة: $e');
      return [];
    }
  }

  /// التحقق من صحة نقل الطلبات
  Future<TransferValidationResult> validateOrderTransfer(
    String sourceWarehouseId,
    String targetWarehouseId, {
    List<String>? orderIds,
  }) async {
    try {
      return await _orderTransferService.validateOrderTransfer(
        sourceWarehouseId,
        targetWarehouseId,
        orderIds: orderIds,
      );
    } catch (e) {
      AppLogger.error('❌ خطأ في التحقق من صحة النقل: $e');
      return TransferValidationResult(
        isValid: false,
        transferableOrders: 0,
        blockedOrders: 0,
        validationErrors: ['خطأ في التحقق: $e'],
        transferSummary: {},
      );
    }
  }

  /// تنفيذ نقل الطلبات
  Future<OrderTransferResult> executeOrderTransfer(
    String sourceWarehouseId,
    String targetWarehouseId, {
    List<String>? orderIds,
    String? performedBy,
    String transferReason = 'نقل طلبات لحذف المخزن',
  }) async {
    try {
      return await _orderTransferService.executeOrderTransfer(
        sourceWarehouseId,
        targetWarehouseId,
        orderIds: orderIds,
        performedBy: performedBy,
        transferReason: transferReason,
      );
    } catch (e) {
      AppLogger.error('❌ خطأ في تنفيذ نقل الطلبات: $e');
      return OrderTransferResult(
        success: false,
        transferredCount: 0,
        failedCount: 0,
        errors: ['خطأ في التنفيذ: $e'],
        summary: {'execution_error': e.toString()},
      );
    }
  }

  /// إحصائيات النقل للمخزن
  Future<Map<String, dynamic>> getTransferStatistics(String warehouseId) async {
    try {
      return await _orderTransferService.getTransferStatistics(warehouseId);
    } catch (e) {
      AppLogger.error('❌ خطأ في الحصول على إحصائيات النقل: $e');
      return {
        'active_orders_count': 0,
        'available_target_warehouses': 0,
        'suitable_warehouses': 0,
        'high_capacity_warehouses': 0,
        'transfer_feasible': false,
        'error': e.toString(),
      };
    }
  }

  // ==================== إدارة المخزون ====================

  /// الحصول على مخزون مخزن معين مع تخزين مؤقت محسن
  Future<List<WarehouseInventoryModel>> getWarehouseInventory(String warehouseId, {bool useCache = true}) async {
    final timer = TimedOperation('inventory_loading');

    try {
      AppLogger.info('📦 Loading warehouse inventory: $warehouseId');

      // التحقق من صحة معرف المخزن وتنسيقه
      final validWarehouseId = _ensureWarehouseIdFormat(warehouseId);

      // Try to load from enhanced cache first if enabled
      if (useCache) {
        final cacheTimer = TimedOperation('enhanced_cache_loading');
        final cachedInventory = await WarehouseCacheService.loadInventory(validWarehouseId);
        cacheTimer.complete();

        if (cachedInventory != null) {
          AppLogger.info('⚡ Loaded ${cachedInventory.length} inventory items from enhanced cache');

          // Record performance metrics
          final loadTime = timer.elapsedMilliseconds;
          WarehousePerformanceMonitor().recordLoadTime('inventory_loading', loadTime, fromCache: true);

          return timer.completeWithResult(cachedInventory);
        }

        // Fallback to legacy cache
        final legacyCachedInventory = await _loadInventoryFromCache(validWarehouseId);
        if (legacyCachedInventory != null) {
          AppLogger.info('⚡ Loaded ${legacyCachedInventory.length} inventory items from legacy cache');

          // Record performance metrics
          final loadTime = timer.elapsedMilliseconds;
          WarehousePerformanceMonitor().recordLoadTime('inventory_loading', loadTime, fromCache: true);

          return timer.completeWithResult(legacyCachedInventory);
        }
      }

      // Load from database if cache miss
      final result = await _fetchInventoryFromDatabase(validWarehouseId, useCache: useCache);

      // Record performance metrics for database load
      final loadTime = timer.elapsedMilliseconds;
      WarehousePerformanceMonitor().recordLoadTime('inventory_loading', loadTime, fromCache: false);

      return timer.completeWithResult(result);
    } catch (e) {
      timer.complete();
      AppLogger.error('❌ Error loading warehouse inventory: $e');
      return [];
    }
  }

  /// Load inventory from cache
  Future<List<WarehouseInventoryModel>?> _loadInventoryFromCache(String warehouseId) async {
    try {
      // Check memory cache first
      if (_inventoryMemoryCache.containsKey(warehouseId) && _isInventoryCacheValid(warehouseId)) {
        AppLogger.info('⚡ Using inventory from memory cache');
        return _inventoryMemoryCache[warehouseId];
      }

      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_warehouseInventoryCachePrefix$warehouseId';
      final cacheString = prefs.getString(cacheKey);
      if (cacheString == null) return null;

      final cacheData = jsonDecode(cacheString);
      final timestamp = DateTime.parse(cacheData['timestamp']);

      if (DateTime.now().difference(timestamp) > _inventoryCacheExpiration) {
        AppLogger.info('⏰ Inventory cache expired for warehouse: $warehouseId');
        return null;
      }

      final inventoryJson = cacheData['data'] as List;
      final inventory = inventoryJson
          .map((json) => WarehouseInventoryModel.fromJson(json))
          .toList();

      // Update memory cache
      _inventoryMemoryCache[warehouseId] = inventory;
      _inventoryCacheTime[warehouseId] = timestamp;

      AppLogger.info('📦 Loaded ${inventory.length} inventory items from persistent cache');
      return inventory;
    } catch (e) {
      AppLogger.error('❌ Failed to load inventory from cache: $e');
      return null;
    }
  }

  /// Save inventory to cache
  Future<void> _saveInventoryToCache(String warehouseId, List<WarehouseInventoryModel> inventory) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_warehouseInventoryCachePrefix$warehouseId';
      final inventoryJson = inventory.map((i) => i.toJson()).toList();

      await prefs.setString(cacheKey, jsonEncode({
        'data': inventoryJson,
        'timestamp': DateTime.now().toIso8601String(),
      }));

      // Update memory cache
      _inventoryMemoryCache[warehouseId] = inventory;
      _inventoryCacheTime[warehouseId] = DateTime.now();

      AppLogger.info('💾 Saved ${inventory.length} inventory items to cache');
    } catch (e) {
      AppLogger.error('❌ Failed to save inventory to cache: $e');
    }
  }

  /// Fetch inventory from database with optimized queries
  Future<List<WarehouseInventoryModel>> _fetchInventoryFromDatabase(String warehouseId, {bool useCache = true}) async {
    try {
      AppLogger.info('🌐 Fetching inventory from database for warehouse: $warehouseId');

      // Try optimized database function first
      try {
        final response = await Supabase.instance.client
            .rpc('get_warehouse_inventory_with_products', params: {
              'p_warehouse_id': warehouseId,
            });

        if (response == null) {
          AppLogger.warning('⚠️ Database function returned null response');
          throw Exception('Database function returned null response');
        }

        final List<WarehouseInventoryModel> inventory = [];

        for (final item in response) {
          try {
            // Convert data to WarehouseInventoryModel format
            final inventoryData = {
              'id': item['inventory_id'],
              'warehouse_id': item['warehouse_id'],
              'product_id': item['product_id'],
              'quantity': item['quantity'],
              'minimum_stock': item['minimum_stock'],
              'maximum_stock': item['maximum_stock'],
              'quantity_per_carton': item['quantity_per_carton'] ?? 1,
              'last_updated': item['last_updated'],
              'updated_by': item['updated_by'],
            };

            // Create product model if data is available
            ProductModel? product;
            if (item['product_name'] != null) {
              final productData = {
                'id': item['product_id'],
                'name': item['product_name'],
                'description': item['product_description'] ?? '',
                'price': item['product_price'] ?? 0.0,
                'category': item['product_category'] ?? '',
                'image_url': item['product_image_url'],
                'sku': item['product_sku'] ?? '',
                'is_active': item['product_is_active'] ?? true,
                'quantity': 0,
                'images': item['product_image_url'] != null ? [item['product_image_url']] : [],
                'created_at': DateTime.now().toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
                'minimum_stock': 10,
                'reorder_point': 10,
              };
              product = ProductModel.fromJson(productData);
            }

            final inventoryItem = WarehouseInventoryModel.fromJson(inventoryData);
            final inventoryWithProduct = inventoryItem.copyWith(product: product);
            inventory.add(inventoryWithProduct);
          } catch (itemError) {
            AppLogger.error('❌ Error processing inventory item: $itemError');
          }
        }

        AppLogger.info('✅ Loaded ${inventory.length} inventory items (optimized function)');

        // Save to enhanced cache if enabled
        if (useCache && inventory.isNotEmpty) {
          await WarehouseCacheService.saveInventory(warehouseId, inventory);
          // Also save to legacy cache for backward compatibility
          await _saveInventoryToCache(warehouseId, inventory);
        }

        return inventory;
      } catch (functionError) {
        AppLogger.warning('⚠️ Optimized function failed, trying traditional method: $functionError');

        // Check if it's the specific column reference error
        if (functionError.toString().contains('p.is_active') ||
            functionError.toString().contains('column') && functionError.toString().contains('does not exist')) {
          AppLogger.error('❌ Database function has column reference error. Please run database migration to fix.');
          throw Exception('Database function error: Column reference issue detected. Please contact administrator.');
        }
      }

      // Traditional method as fallback - optimized for performance
      AppLogger.info('🔄 Using traditional method as fallback');
      final response = await Supabase.instance.client
          .from('warehouse_inventory')
          .select('*')
          .eq('warehouse_id', warehouseId)
          .order('last_updated', ascending: false);

      if (response.isEmpty) {
        AppLogger.info('ℹ️ No inventory items found for warehouse: $warehouseId');
        return [];
      }

      final List<WarehouseInventoryModel> inventory = [];

      // Batch load all products to avoid N+1 queries
      final productIds = response.map((item) => item['product_id'] as String).toSet().toList();
      final Map<String, ProductModel> productsMap = {};

      if (productIds.isNotEmpty) {
        try {
          final productsResponse = await Supabase.instance.client
              .from('products')
              .select('*')
              .inFilter('id', productIds);

          for (final productJson in productsResponse) {
            final product = ProductModel.fromJson(productJson);
            productsMap[product.id] = product;
          }
          AppLogger.info('✅ Batch loaded ${productsMap.length} products');
        } catch (e) {
          AppLogger.warning('⚠️ Failed to batch load products: $e');
        }
      }

      for (final json in response) {
        try {
          final inventoryData = json as Map<String, dynamic>;
          final inventoryItem = WarehouseInventoryModel.fromJson(inventoryData);

          // Get product from batch-loaded map or create temporary
          ProductModel? product = productsMap[inventoryItem.productId];
          if (product == null) {
            product = _createTemporaryProductForDisplay(inventoryItem.productId);
          }

          inventory.add(inventoryItem.copyWith(product: product));
        } catch (itemError) {
          AppLogger.error('❌ Error processing inventory item: $itemError');
        }
      }

      AppLogger.info('✅ Loaded ${inventory.length} inventory items (traditional method)');

      // Save to enhanced cache if enabled
      if (useCache && inventory.isNotEmpty) {
        await WarehouseCacheService.saveInventory(warehouseId, inventory);
        // Also save to legacy cache for backward compatibility
        await _saveInventoryToCache(warehouseId, inventory);
      }

      return inventory;
    } catch (e) {
      AppLogger.error('❌ Error loading inventory: $e');
      return [];
    }
  }

  /// الحصول على مخزون منتج معين في جميع المخازن
  Future<List<WarehouseInventoryModel>> getProductInventoryAcrossWarehouses(String productId) async {
    try {
      AppLogger.info('📦 جاري تحميل مخزون المنتج: $productId');

      // التحقق من صحة معرف المنتج وتنسيقه
      final validProductId = _ensureProductIdFormat(productId);
      AppLogger.info('🔍 معرف المنتج المُنسق: $validProductId');

      final response = await Supabase.instance.client
          .from('warehouse_inventory')
          .select('''
            *,
            warehouses!warehouse_id (
              id,
              name,
              address
            )
          ''')
          .eq('product_id', validProductId)
          .order('quantity', ascending: false);

      final inventory = (response as List<dynamic>)
          .map((json) {
            final item = WarehouseInventoryModel.fromJson(json as Map<String, dynamic>);
            final warehouseData = json['warehouses'] as Map<String, dynamic>?;
            return item.copyWith(
              warehouseName: warehouseData?['name'] as String?,
            );
          })
          .toList();

      AppLogger.info('✅ تم تحميل مخزون المنتج من ${inventory.length} مخزن');
      return inventory;
    } catch (e) {
      AppLogger.error('❌ خطأ في تحميل مخزون المنتج: $e');
      return [];
    }
  }

  /// الحصول على مخزون مخزن معين مع أسماء المخازن (محسن للتقارير)
  Future<List<WarehouseInventoryModel>> getWarehouseInventoryWithNames(String warehouseId) async {
    try {
      AppLogger.info('📦 جاري تحميل مخزون المخزن مع الأسماء: $warehouseId');

      final response = await Supabase.instance.client
          .from('warehouse_inventory')
          .select('''
            *,
            warehouses!warehouse_id (
              id,
              name,
              address
            ),
            products!product_id (
              id,
              name,
              description,
              price,
              category,
              image_url,
              images,
              sku,
              active
            )
          ''')
          .eq('warehouse_id', warehouseId)
          .order('last_updated', ascending: false);

      final inventory = (response as List<dynamic>)
          .map((json) {
            try {
              final item = WarehouseInventoryModel.fromJson(json as Map<String, dynamic>);
              final warehouseData = json['warehouses'] as Map<String, dynamic>?;
              final productData = json['products'] as Map<String, dynamic>?;

              ProductModel? product;
              if (productData != null) {
                // إضافة الحقول المطلوبة للمنتج
                final enhancedProductData = Map<String, dynamic>.from(productData);
                enhancedProductData['quantity'] = 0; // المخزون الفعلي في inventory
                enhancedProductData['images'] = productData['images'] ??
                    (productData['image_url'] != null ? [productData['image_url']] : []);
                enhancedProductData['created_at'] = DateTime.now().toIso8601String();
                enhancedProductData['updated_at'] = DateTime.now().toIso8601String();
                enhancedProductData['minimum_stock'] = 10;
                enhancedProductData['reorder_point'] = 10;

                product = ProductModel.fromJson(enhancedProductData);
              }

              return item.copyWith(
                warehouseName: warehouseData?['name'] as String?,
                product: product,
              );
            } catch (itemError) {
              AppLogger.error('❌ خطأ في معالجة عنصر المخزون: $itemError');
              return null;
            }
          })
          .where((item) => item != null)
          .cast<WarehouseInventoryModel>()
          .toList();

      AppLogger.info('✅ تم تحميل ${inventory.length} عنصر مخزون مع أسماء المخازن');
      return inventory;
    } catch (e) {
      AppLogger.error('❌ خطأ في تحميل مخزون المخزن مع الأسماء: $e');
      return [];
    }
  }

  /// تحديث مخزون منتج في مخزن
  Future<bool> updateInventory({
    required String warehouseId,
    required String productId,
    required int quantityChange,
    required String performedBy,
    required String reason,
    String? referenceId,
    String? referenceType,
  }) async {
    try {
      AppLogger.info('📦 جاري تحديث المخزون: $productId في المخزن $warehouseId');

      // التحقق من صحة المعرفات وتنسيقها
      final validWarehouseId = _ensureWarehouseIdFormat(warehouseId);
      final validProductId = _ensureProductIdFormat(productId);

      AppLogger.info('🔍 معرفات مُنسقة - المخزن: $validWarehouseId، المنتج: $validProductId');

      // استخدام الدالة المخزنة في قاعدة البيانات
      final response = await Supabase.instance.client.rpc(
        'update_warehouse_inventory',
        params: {
          'p_warehouse_id': validWarehouseId,
          'p_product_id': validProductId,
          'p_quantity_change': quantityChange,
          'p_performed_by': performedBy,
          'p_reason': reason,
          'p_reference_id': referenceId,
          'p_reference_type': referenceType,
        },
      );

      if (response == true) {
        AppLogger.info('✅ تم تحديث المخزون بنجاح');
        return true;
      } else {
        AppLogger.error('❌ فشل في تحديث المخزون');
        return false;
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في تحديث المخزون: $e');
      return false;
    }
  }

  /// إضافة منتج جديد إلى مخزن أو تحديث الكمية إذا كان موجوداً
  Future<WarehouseInventoryModel?> addProductToWarehouse({
    required String warehouseId,
    required String productId,
    required int quantity,
    required String addedBy,
    int? minimumStock,
    int? maximumStock,
    int quantityPerCarton = 1, // الكمية في الكرتونة الواحدة
  }) async {
    try {
      AppLogger.info('📦 جاري إضافة منتج إلى المخزن: $productId');

      // التحقق من صحة المعرفات وتنسيقها
      final validWarehouseId = _ensureWarehouseIdFormat(warehouseId);
      final validProductId = _ensureProductIdFormat(productId);

      AppLogger.info('🔍 معرفات مُنسقة - المخزن: $validWarehouseId، المنتج: $validProductId');

      // التحقق من وجود المنتج في المخزن
      final existingInventoryResponse = await Supabase.instance.client
          .from('warehouse_inventory')
          .select('*')
          .eq('warehouse_id', validWarehouseId)
          .eq('product_id', validProductId)
          .maybeSingle();

      WarehouseInventoryModel? inventory;

      if (existingInventoryResponse != null) {
        // المنتج موجود بالفعل - تحديث الكمية
        AppLogger.info('📦 المنتج موجود بالفعل في المخزن، جاري تحديث الكمية...');

        final existingInventory = WarehouseInventoryModel.fromJson(existingInventoryResponse);
        final newQuantity = existingInventory.quantity + quantity;

        final updateData = {
          'quantity': newQuantity,
          'minimum_stock': minimumStock ?? existingInventory.minimumStock,
          'maximum_stock': maximumStock ?? existingInventory.maximumStock,
          'quantity_per_carton': quantityPerCarton,
          'last_updated': DateTime.now().toIso8601String(),
          'updated_by': addedBy,
        };

        // إضافة تسجيل للتحقق من البيانات المرسلة للتحديث
        AppLogger.info('🔍 بيانات التحديث المرسلة: $updateData');

        final response = await _supabaseService.updateRecord(
          'warehouse_inventory',
          existingInventory.id,
          updateData
        );

        inventory = WarehouseInventoryModel.fromJson(response);

        // إضافة تسجيل للتحقق من البيانات المستلمة من قاعدة البيانات
        AppLogger.info('🔍 البيانات المستلمة من قاعدة البيانات بعد التحديث: $response');
        AppLogger.info('🔍 النموذج المحول - الكمية في الكرتونة: ${inventory.quantityPerCarton}');

        // إنشاء معاملة للتحديث
        await updateInventory(
          warehouseId: validWarehouseId,
          productId: validProductId,
          quantityChange: quantity,
          performedBy: addedBy,
          reason: 'تحديث كمية منتج موجود في المخزن',
          referenceType: 'manual',
        );

        AppLogger.info('✅ تم تحديث كمية المنتج في المخزن بنجاح');
      } else {
        // المنتج غير موجود - التأكد من وجود المنتج في قاعدة البيانات أولاً
        AppLogger.info('📦 المنتج غير موجود، جاري التحقق من قاعدة البيانات...');

        // التأكد من وجود المنتج في جدول products
        await _ensureProductExists(validProductId);

        final data = {
          'warehouse_id': validWarehouseId,
          'product_id': validProductId,
          'quantity': quantity,
          'minimum_stock': minimumStock,
          'maximum_stock': maximumStock,
          'quantity_per_carton': quantityPerCarton,
          'updated_by': addedBy,
        };

        // إضافة تسجيل للتحقق من البيانات المرسلة للإنشاء
        AppLogger.info('🔍 بيانات الإنشاء المرسلة: $data');

        final response = await _supabaseService.createRecord('warehouse_inventory', data);
        inventory = WarehouseInventoryModel.fromJson(response);

        // إضافة تسجيل للتحقق من البيانات المستلمة من قاعدة البيانات
        AppLogger.info('🔍 البيانات المستلمة من قاعدة البيانات بعد الإنشاء: $response');
        AppLogger.info('🔍 النموذج المحول - الكمية في الكرتونة: ${inventory.quantityPerCarton}');

        // إنشاء معاملة للإضافة مباشرة (بدون استخدام updateInventory)
        try {
          // تحويل معرف المخزن إلى UUID صحيح للإدراج في قاعدة البيانات
          final warehouseUuid = validWarehouseId; // Already validated as UUID format

          await Supabase.instance.client.from('warehouse_transactions').insert({
            'warehouse_id': warehouseUuid,
            'product_id': validProductId,
            'quantity': quantity,
            'quantity_change': quantity, // إضافة حقل quantity_change
            'quantity_before': 0,
            'quantity_after': quantity,
            'type': 'stock_in',
            'reason': 'إضافة منتج جديد إلى المخزن',
            'performed_by': addedBy,
            'reference_type': 'manual',
            'transaction_number': 'TXN-${DateTime.now().millisecondsSinceEpoch}-ADD',
          });
          AppLogger.info('✅ تم إنشاء معاملة الإضافة بنجاح');
        } catch (transactionError) {
          AppLogger.error('❌ خطأ في إنشاء معاملة الإضافة: $transactionError');

          // تحليل نوع الخطأ لتحديد ما إذا كان مرتبطاً بأنواع البيانات
          if (transactionError.toString().contains('uuid') ||
              transactionError.toString().contains('type')) {
            AppLogger.error('⚠️ خطأ في نوع البيانات - معرف المخزن: $validWarehouseId');
          }
          // المتابعة حتى لو فشلت المعاملة
        }

        AppLogger.info('✅ تم إنشاء سجل جديد للمنتج في المخزن بنجاح');
      }

      // الحصول على معلومات المنتج من قاعدة البيانات
      ProductModel? productInfo;
      try {
        final productResponse = await Supabase.instance.client
            .from('products')
            .select('*')
            .eq('id', validProductId)
            .maybeSingle();

        if (productResponse != null) {
          productInfo = ProductModel.fromJson(productResponse);
          AppLogger.info('✅ تم تحميل معلومات المنتج: ${productInfo.name}');
        } else {
          // إذا لم يوجد المنتج، استخدم دالة ensure_product_exists
          AppLogger.warning('⚠️ المنتج غير موجود في قاعدة البيانات، جاري إنشاء منتج افتراضي');

          try {
            // محاولة الحصول على اسم المنتج الحقيقي من API أولاً
            String productName = 'منتج $productId';
            try {
              final apiProduct = await _apiProductSyncService.getProductFromApi(productId);
              if (apiProduct != null && apiProduct['name'] != null) {
                productName = apiProduct['name'].toString();
              }
            } catch (apiError) {
              AppLogger.warning('⚠️ فشل في تحميل اسم المنتج من API: $apiError');
            }

            final ensureResult = await Supabase.instance.client.rpc(
              'ensure_product_exists',
              params: {
                'p_product_id': productId,
                'p_product_name': productName,
              },
            );

            if (ensureResult == true) {
              // محاولة تحميل المنتج مرة أخرى
              final retryResponse = await Supabase.instance.client
                  .from('products')
                  .select('*')
                  .eq('id', productId)
                  .maybeSingle();

              if (retryResponse != null) {
                productInfo = ProductModel.fromJson(retryResponse);
                AppLogger.info('✅ تم إنشاء وتحميل المنتج الافتراضي: ${productInfo.name}');
              }
            }
          } catch (ensureError) {
            AppLogger.error('❌ فشل في استخدام دالة ensure_product_exists: $ensureError');
            // الرجوع للطريقة القديمة
            await _createDefaultProduct(productId);
          }
        }
      } catch (e) {
        AppLogger.error('❌ خطأ في تحميل معلومات المنتج: $e');
        // محاولة إنشاء منتج افتراضي في حالة الخطأ
        try {
          await _createDefaultProduct(productId);
          AppLogger.info('✅ تم إنشاء منتج افتراضي بعد الخطأ');
        } catch (createError) {
          AppLogger.error('❌ فشل في إنشاء منتج افتراضي: $createError');
        }
      }

      // إرجاع نموذج المخزون مع معلومات المنتج
      final finalInventory = inventory!.copyWith(product: productInfo);

      AppLogger.info('✅ تم إضافة/تحديث المنتج في المخزن بنجاح: ${productInfo?.name ?? productId}');
      return finalInventory;
    } catch (e) {
      AppLogger.error('❌ خطأ في إضافة المنتج إلى المخزن: $e');

      // تحسين رسائل الخطأ
      if (e.toString().contains('duplicate key')) {
        throw Exception('المنتج موجود بالفعل في هذا المخزن. يرجى استخدام خاصية تحديث الكمية.');
      } else if (e.toString().contains('row-level security policy')) {
        throw Exception('ليس لديك صلاحية لإضافة منتجات إلى هذا المخزن.');
      } else {
        throw Exception('حدث خطأ في إضافة المنتج إلى المخزن: ${e.toString()}');
      }
    }
  }

  /// حذف منتج من المخزن بشكل آمن
  Future<bool> removeProductFromWarehouse({
    required String warehouseId,
    required String productId,
    required String performedBy,
    required String reason,
  }) async {
    try {
      AppLogger.info('🗑️ جاري حذف المنتج من المخزن: $productId');

      // التحقق من صحة المعرفات وتنسيقها
      final validWarehouseId = _ensureWarehouseIdFormat(warehouseId);
      final validProductId = _ensureProductIdFormat(productId);

      AppLogger.info('🔍 معرفات مُنسقة - المخزن: $validWarehouseId، المنتج: $validProductId');

      // الحصول على الكمية الحالية
      final existingInventoryResponse = await Supabase.instance.client
          .from('warehouse_inventory')
          .select('*')
          .eq('warehouse_id', validWarehouseId)
          .eq('product_id', validProductId)
          .maybeSingle();

      if (existingInventoryResponse == null) {
        AppLogger.warning('⚠️ المنتج غير موجود في المخزن');
        throw Exception('المنتج غير موجود في هذا المخزن');
      }

      final existingInventory = WarehouseInventoryModel.fromJson(existingInventoryResponse);
      final currentQuantity = existingInventory.quantity;

      // إنشاء معاملة سحب للكمية الكاملة (بدون استخدام updateInventory)
      try {
        // تحويل معرف المخزن إلى UUID صحيح للإدراج في قاعدة البيانات
        final warehouseUuid = validWarehouseId; // Already validated as UUID format

        await Supabase.instance.client.from('warehouse_transactions').insert({
          'warehouse_id': warehouseUuid,
          'product_id': validProductId,
          'quantity': currentQuantity, // الكمية المسحوبة (موجبة)
          'quantity_change': -currentQuantity, // إضافة حقل quantity_change (سالب للسحب)
          'quantity_before': currentQuantity,
          'quantity_after': 0,
          'type': 'stock_out',
          'reason': reason,
          'performed_by': performedBy,
          'reference_type': 'manual_removal',
          'transaction_number': 'TXN-${DateTime.now().millisecondsSinceEpoch}-REM',
        });

        AppLogger.info('✅ تم إنشاء معاملة السحب بنجاح');
      } catch (transactionError) {
        AppLogger.error('❌ خطأ في إنشاء معاملة السحب: $transactionError');

        // تحليل نوع الخطأ لتحديد ما إذا كان مرتبطاً بأنواع البيانات
        if (transactionError.toString().contains('uuid') ||
            transactionError.toString().contains('type')) {
          AppLogger.error('⚠️ خطأ في نوع البيانات - معرف المخزن: $validWarehouseId');
        }
        // المتابعة حتى لو فشلت المعاملة
      }

      // حذف السجل من المخزون مباشرة
      await Supabase.instance.client
          .from('warehouse_inventory')
          .delete()
          .eq('warehouse_id', validWarehouseId)
          .eq('product_id', validProductId);

      AppLogger.info('✅ تم حذف المنتج من المخزن بنجاح');
      return true;
    } catch (e) {
      AppLogger.error('❌ خطأ في حذف المنتج من المخزن: $e');

      // تحسين رسائل الخطأ
      if (e.toString().contains('row-level security policy')) {
        throw Exception('ليس لديك صلاحية لحذف منتجات من هذا المخزن.');
      } else {
        throw Exception('حدث خطأ في حذف المنتج من المخزن: ${e.toString()}');
      }
    }
  }

  // ==================== إدارة طلبات السحب ====================

  /// الحصول على طلبات السحب
  Future<List<WarehouseRequestModel>> getWarehouseRequests({
    String? warehouseId,
    WarehouseRequestStatus? status,
    String? requestedBy,
    int? limit,
  }) async {
    try {
      AppLogger.info('📋 جاري تحميل طلبات السحب...');

      // Build the query step by step
      dynamic queryBuilder = Supabase.instance.client
          .from('warehouse_requests')
          .select('''
            *,
            warehouse_request_items (
              *
            ),
            requester:user_profiles!requested_by (
              id,
              name,
              email
            ),
            approver:user_profiles!approved_by (
              id,
              name,
              email
            ),
            executor:user_profiles!executed_by (
              id,
              name,
              email
            ),
            warehouses!warehouse_id (
              id,
              name,
              address
            )
          ''');

      if (warehouseId != null) {
        final validWarehouseId = _ensureWarehouseIdFormat(warehouseId);
        queryBuilder = queryBuilder.eq('warehouse_id', validWarehouseId);
      }
      if (status != null) {
        queryBuilder = queryBuilder.eq('status', status.value);
      }
      if (requestedBy != null) {
        queryBuilder = queryBuilder.eq('requested_by', requestedBy);
      }

      queryBuilder = queryBuilder.order('requested_at', ascending: false);

      if (limit != null) {
        queryBuilder = queryBuilder.limit(limit);
      }

      final response = await queryBuilder;

      final requests = (response as List<dynamic>)
          .map((json) {
            final requestData = json as Map<String, dynamic>;
            
            // تحويل عناصر الطلب
            final items = (requestData['warehouse_request_items'] as List<dynamic>?)
                ?.map((item) => WarehouseRequestItemModel.fromJson(item as Map<String, dynamic>))
                .toList() ?? [];

            // إنشاء نموذج الطلب مع البيانات الإضافية
            return WarehouseRequestModel.fromJson(requestData).copyWith(
              items: items,
              warehouseName: (requestData['warehouses'] as Map<String, dynamic>?)?['name'] as String?,
            );
          })
          .toList();

      AppLogger.info('✅ تم تحميل ${requests.length} طلب سحب');
      return requests;
    } catch (e) {
      AppLogger.error('❌ خطأ في تحميل طلبات السحب: $e');
      return [];
    }
  }

  /// إنشاء طلب سحب جديد
  Future<WarehouseRequestModel?> createWarehouseRequest({
    required WarehouseRequestType type,
    required String requestedBy,
    required String warehouseId,
    String? targetWarehouseId,
    required String reason,
    String? notes,
    required List<WarehouseRequestItemModel> items,
  }) async {
    try {
      AppLogger.info('📋 جاري إنشاء طلب سحب جديد...');

      // إنشاء الطلب الرئيسي
      final requestData = {
        'type': type.value,
        'requested_by': requestedBy,
        'warehouse_id': warehouseId,
        'target_warehouse_id': targetWarehouseId,
        'reason': reason,
        'notes': notes,
      };

      final requestResponse = await _supabaseService.createRecord('warehouse_requests', requestData);
      final requestId = requestResponse['id'] as String;

      // إضافة عناصر الطلب
      for (final item in items) {
        final itemData = {
          'request_id': requestId,
          'product_id': item.productId,
          'quantity': item.quantity,
          'notes': item.notes,
        };
        await _supabaseService.createRecord('warehouse_request_items', itemData);
      }

      // الحصول على الطلب الكامل مع العناصر
      final requests = await getWarehouseRequests();
      final createdRequest = requests.firstWhere((r) => r.id == requestId);

      AppLogger.info('✅ تم إنشاء طلب السحب بنجاح: ${createdRequest.requestNumber}');
      return createdRequest;
    } catch (e) {
      AppLogger.error('❌ خطأ في إنشاء طلب السحب: $e');
      return null;
    }
  }

  /// الموافقة على طلب سحب
  Future<bool> approveWarehouseRequest({
    required String requestId,
    required String approvedBy,
    String? notes,
  }) async {
    try {
      AppLogger.info('✅ جاري الموافقة على طلب السحب: $requestId');

      final data = {
        'status': WarehouseRequestStatus.approved.value,
        'approved_by': approvedBy,
        'approved_at': DateTime.now().toIso8601String(),
        'notes': notes,
      };

      await _supabaseService.updateRecord('warehouse_requests', requestId, data);

      AppLogger.info('✅ تم الموافقة على طلب السحب بنجاح');
      return true;
    } catch (e) {
      AppLogger.error('❌ خطأ في الموافقة على طلب السحب: $e');
      return false;
    }
  }

  /// رفض طلب سحب
  Future<bool> rejectWarehouseRequest({
    required String requestId,
    required String rejectedBy,
    String? reason,
  }) async {
    try {
      AppLogger.info('❌ جاري رفض طلب السحب: $requestId');

      final data = {
        'status': WarehouseRequestStatus.rejected.value,
        'approved_by': rejectedBy,
        'approved_at': DateTime.now().toIso8601String(),
        'notes': reason,
      };

      await _supabaseService.updateRecord('warehouse_requests', requestId, data);

      AppLogger.info('✅ تم رفض طلب السحب بنجاح');
      return true;
    } catch (e) {
      AppLogger.error('❌ خطأ في رفض طلب السحب: $e');
      return false;
    }
  }

  /// تنفيذ طلب سحب
  Future<bool> executeWarehouseRequest({
    required String requestId,
    required String executedBy,
  }) async {
    try {
      AppLogger.info('🔄 جاري تنفيذ طلب السحب: $requestId');

      // الحصول على تفاصيل الطلب
      final requests = await getWarehouseRequests();
      final request = requests.firstWhere((r) => r.id == requestId);

      if (request.status != WarehouseRequestStatus.approved) {
        throw Exception('لا يمكن تنفيذ طلب غير موافق عليه');
      }

      // تنفيذ السحب لكل منتج
      for (final item in request.items) {
        final success = await updateInventory(
          warehouseId: request.warehouseId,
          productId: item.productId,
          quantityChange: -item.quantity, // سحب (كمية سالبة)
          performedBy: executedBy,
          reason: 'تنفيذ طلب سحب: ${request.requestNumber}',
          referenceId: requestId,
          referenceType: 'request',
        );

        if (!success) {
          throw Exception('فشل في سحب المنتج: ${item.productId}');
        }
      }

      // تحديث حالة الطلب
      final data = {
        'status': WarehouseRequestStatus.executed.value,
        'executed_by': executedBy,
        'executed_at': DateTime.now().toIso8601String(),
      };

      await _supabaseService.updateRecord('warehouse_requests', requestId, data);

      AppLogger.info('✅ تم تنفيذ طلب السحب بنجاح');
      return true;
    } catch (e) {
      AppLogger.error('❌ خطأ في تنفيذ طلب السحب: $e');
      return false;
    }
  }

  /// إلغاء طلب سحب
  Future<bool> cancelWarehouseRequest({
    required String requestId,
    required String cancelledBy,
    String? reason,
  }) async {
    try {
      AppLogger.info('🚫 جاري إلغاء طلب السحب: $requestId');

      final data = {
        'status': WarehouseRequestStatus.cancelled.value,
        'notes': reason,
      };

      await _supabaseService.updateRecord('warehouse_requests', requestId, data);

      AppLogger.info('✅ تم إلغاء طلب السحب بنجاح');
      return true;
    } catch (e) {
      AppLogger.error('❌ خطأ في إلغاء طلب السحب: $e');
      return false;
    }
  }

  /// الحصول على إحصائيات المخزن
  Future<Map<String, dynamic>> getWarehouseStatistics(String warehouseId) async {
    try {
      AppLogger.info('📊 جاري تحميل إحصائيات المخزن: $warehouseId');

      // الحصول على المخزون الحالي
      final inventory = await getWarehouseInventory(warehouseId);

      // الحصول على الطلبات المعلقة
      final pendingRequests = await getWarehouseRequests(
        warehouseId: warehouseId,
        status: WarehouseRequestStatus.pending,
      );

      // حساب الإحصائيات
      final totalProducts = inventory.length;
      final totalQuantity = inventory.fold(0, (sum, item) => sum + item.quantity);
      final lowStockCount = inventory.where((item) => item.isLowStock).length;
      final outOfStockCount = inventory.where((item) => item.isOutOfStock).length;

      final statistics = {
        'total_products': totalProducts,
        'total_quantity': totalQuantity,
        'low_stock_count': lowStockCount,
        'out_of_stock_count': outOfStockCount,
        'pending_requests_count': pendingRequests.length,
        'last_updated': DateTime.now().toIso8601String(),
      };

      AppLogger.info('✅ تم تحميل إحصائيات المخزن بنجاح');
      return statistics;
    } catch (e) {
      AppLogger.error('❌ خطأ في تحميل إحصائيات المخزن: $e');
      return {};
    }
  }

  /// مسح جميع معاملات مخزن محدد
  Future<void> clearAllWarehouseTransactions(String warehouseId) async {
    try {
      AppLogger.info('🗑️ Clearing all transactions for warehouse: $warehouseId');

      // التحقق من صحة معرف المخزن
      final validWarehouseId = _ensureWarehouseIdFormat(warehouseId);
      AppLogger.info('🔍 Using validated warehouse ID: $validWarehouseId');

      // التحقق من صلاحيات المستخدم
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('المستخدم غير مسجل دخول');
      }

      final hasPermission = await _checkWarehouseCreatePermission(currentUser.id);
      if (!hasPermission) {
        throw Exception('ليس لديك صلاحية لمسح معاملات المخزن');
      }

      // الحصول على عدد المعاملات قبل الحذف للتأكيد
      final countResponse = await _supabase
          .from('warehouse_transactions')
          .select('id')
          .eq('warehouse_id', validWarehouseId)
          .count();

      final transactionCount = countResponse.count;
      AppLogger.info('📊 عدد المعاملات المراد حذفها: $transactionCount');

      if (transactionCount == 0) {
        AppLogger.info('ℹ️ لا توجد معاملات للحذف في هذا المخزن');
        return;
      }

      // حذف جميع معاملات المخزن
      await _supabase
          .from('warehouse_transactions')
          .delete()
          .eq('warehouse_id', validWarehouseId);

      AppLogger.info('✅ تم حذف $transactionCount معاملة من المخزن $validWarehouseId بنجاح');

    } catch (e) {
      AppLogger.error('❌ خطأ في مسح معاملات المخزن: $e');
      rethrow;
    }
  }
}
