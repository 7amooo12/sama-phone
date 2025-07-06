import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smartbiztracker_new/models/warehouse_release_order_model.dart';
import 'package:smartbiztracker_new/models/client_order_model.dart';
import 'package:smartbiztracker_new/models/warehouse_dispatch_model.dart';
import 'package:smartbiztracker_new/models/dispatch_product_processing_model.dart';
import 'package:smartbiztracker_new/models/global_inventory_models.dart';
import 'package:smartbiztracker_new/services/supabase_orders_service.dart';
import 'package:smartbiztracker_new/services/real_notification_service.dart';
import 'package:smartbiztracker_new/services/warehouse_dispatch_service.dart';
import 'package:smartbiztracker_new/services/intelligent_inventory_deduction_service.dart';
import 'package:smartbiztracker_new/services/auth_state_manager.dart';
import 'package:smartbiztracker_new/services/operation_isolation_service.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// خدمة إدارة أذون صرف المخزون
/// تتعامل مع العمليات الأساسية لأذون الصرف وتكاملها مع نظام الطلبات
class WarehouseReleaseOrdersService {
  final _supabase = Supabase.instance.client;
  final SupabaseOrdersService _ordersService = SupabaseOrdersService();
  final RealNotificationService _notificationService = RealNotificationService();
  final WarehouseDispatchService _dispatchService = WarehouseDispatchService();
  final IntelligentInventoryDeductionService _deductionService = IntelligentInventoryDeductionService();
  static const String _releaseOrdersTable = 'warehouse_release_orders';
  static const String _releaseOrderItemsTable = 'warehouse_release_order_items';

  /// استخراج UUID الفعلي من معرف أذن الصرف المُنسق
  /// يتعامل مع الأشكال: "WRO-DISPATCH-uuid", "WRO-uuid", أو "uuid" مباشرة
  String _extractUuidFromReleaseOrderId(String releaseOrderId) {
    try {
      // إذا كان المعرف يحتوي على بادئة، استخرج الجزء الأخير
      if (releaseOrderId.contains('-') && releaseOrderId.length > 36) {
        // البحث عن آخر جزء يشبه UUID (36 حرف مع شرطات)
        final parts = releaseOrderId.split('-');
        if (parts.length >= 5) {
          // إعادة تجميع آخر 5 أجزاء لتكوين UUID
          final uuidParts = parts.sublist(parts.length - 5);
          final extractedUuid = uuidParts.join('-');

          // التحقق من صحة تنسيق UUID
          if (_isValidUuid(extractedUuid)) {
            AppLogger.info('🔧 تم استخراج UUID: $extractedUuid من $releaseOrderId');
            return extractedUuid;
          }
        }
      }

      // إذا كان المعرف بالفعل UUID صحيح، أرجعه كما هو
      if (_isValidUuid(releaseOrderId)) {
        return releaseOrderId;
      }

      // في حالة عدم التمكن من الاستخراج، أرجع المعرف الأصلي
      AppLogger.warning('⚠️ لم يتم التمكن من استخراج UUID صحيح من: $releaseOrderId');
      return releaseOrderId;

    } catch (e) {
      AppLogger.error('❌ خطأ في استخراج UUID: $e');
      return releaseOrderId;
    }
  }

  /// التحقق من صحة تنسيق UUID
  bool _isValidUuid(String uuid) {
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
    );
    return uuidRegex.hasMatch(uuid);
  }

  /// البحث عن أذن الصرف بطرق متعددة (UUID أو معرف منسق)
  Future<Map<String, dynamic>?> _findReleaseOrderInDatabase(String releaseOrderId) async {
    try {
      // التحقق من نوع أذن الصرف (عادي أم محول من طلب صرف)
      if (releaseOrderId.startsWith('WRO-DISPATCH-')) {
        AppLogger.info('🔄 أذن صرف محول من طلب صرف، البحث في جدول warehouse_requests');
        return await _findDispatchConvertedReleaseOrder(releaseOrderId);
      }

      // المحاولة الأولى: استخدام UUID المستخرج
      final extractedUuid = _extractUuidFromReleaseOrderId(releaseOrderId);

      try {
        final response = await _supabase
            .from(_releaseOrdersTable)
            .select('''
              *,
              warehouse_release_order_items (
                *
              )
            ''')
            .eq('id', extractedUuid)
            .single();

        AppLogger.info('✅ تم العثور على أذن الصرف باستخدام UUID: $extractedUuid');
        return response;
      } catch (e) {
        AppLogger.warning('⚠️ لم يتم العثور على أذن الصرف باستخدام UUID: $extractedUuid');
      }

      // المحاولة الثانية: البحث باستخدام release_order_number
      try {
        final response = await _supabase
            .from(_releaseOrdersTable)
            .select('''
              *,
              warehouse_release_order_items (
                *
              )
            ''')
            .eq('release_order_number', releaseOrderId)
            .single();

        AppLogger.info('✅ تم العثور على أذن الصرف باستخدام رقم الأذن: $releaseOrderId');
        return response;
      } catch (e) {
        AppLogger.warning('⚠️ لم يتم العثور على أذن الصرف باستخدام رقم الأذن: $releaseOrderId');
      }

      return null;
    } catch (e) {
      AppLogger.error('❌ خطأ في البحث عن أذن الصرف: $e');
      return null;
    }
  }

  /// البحث عن أذن صرف محول من طلب صرف في جدول warehouse_requests
  Future<Map<String, dynamic>?> _findDispatchConvertedReleaseOrder(String releaseOrderId) async {
    try {
      // استخراج UUID من معرف أذن الصرف المحول
      final extractedUuid = _extractUuidFromReleaseOrderId(releaseOrderId);
      AppLogger.info('🔍 البحث عن طلب الصرف الأصلي باستخدام UUID: $extractedUuid');

      // البحث في جدول warehouse_requests
      final response = await _supabase
          .from('warehouse_requests')
          .select('''
            *,
            warehouse_request_items (
              *
            )
          ''')
          .eq('id', extractedUuid)
          .single();

      AppLogger.info('✅ تم العثور على طلب الصرف الأصلي، سيتم تحويله إلى أذن صرف');

      // تحويل طلب الصرف إلى نموذج أذن صرف
      final dispatchModel = WarehouseDispatchModel.fromJson(response);
      final releaseOrderModel = await _convertDispatchToReleaseOrder(dispatchModel);

      // تحويل النموذج إلى Map للتوافق مع باقي الكود
      return releaseOrderModel.toJson();

    } catch (e) {
      AppLogger.warning('⚠️ لم يتم العثور على طلب الصرف الأصلي: $e');
      return null;
    }
  }

  /// إنشاء معرف أذن صرف منسق من UUID
  String _createFormattedReleaseOrderId(String uuid, {String prefix = 'WRO'}) {
    if (_isValidUuid(uuid)) {
      return '$prefix-$uuid';
    }
    return uuid; // إرجاع المعرف كما هو إذا لم يكن UUID صحيح
  }

  /// التحقق من نوع معرف أذن الصرف
  Map<String, dynamic> _analyzeReleaseOrderId(String releaseOrderId) {
    final isUuid = _isValidUuid(releaseOrderId);
    final hasPrefix = releaseOrderId.contains('-') && releaseOrderId.length > 36;
    final extractedUuid = _extractUuidFromReleaseOrderId(releaseOrderId);

    return {
      'original_id': releaseOrderId,
      'is_pure_uuid': isUuid,
      'has_prefix': hasPrefix,
      'extracted_uuid': extractedUuid,
      'is_valid_format': _isValidUuid(extractedUuid),
      'prefix': hasPrefix ? releaseOrderId.substring(0, releaseOrderId.length - 36) : null,
    };
  }

  /// تسجيل معلومات تحليل معرف أذن الصرف للتشخيص
  void _logReleaseOrderIdAnalysis(String releaseOrderId) {
    final analysis = _analyzeReleaseOrderId(releaseOrderId);
    AppLogger.info('🔍 تحليل معرف أذن الصرف:');
    AppLogger.info('   المعرف الأصلي: ${analysis['original_id']}');
    AppLogger.info('   UUID خالص: ${analysis['is_pure_uuid']}');
    AppLogger.info('   يحتوي على بادئة: ${analysis['has_prefix']}');
    AppLogger.info('   UUID المستخرج: ${analysis['extracted_uuid']}');
    AppLogger.info('   تنسيق صحيح: ${analysis['is_valid_format']}');
    if (analysis['prefix'] != null) {
      AppLogger.info('   البادئة: ${analysis['prefix']}');
    }
  }

  /// إنشاء أذن صرف جديد من طلب معتمد
  Future<String?> createReleaseOrderFromApprovedOrder({
    required ClientOrder approvedOrder,
    required String assignedTo,
    String? notes,
  }) async {
    try {
      AppLogger.info('🏭 إنشاء أذن صرف من الطلب المعتمد: ${approvedOrder.id}');

      // التحقق من المصادقة
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('المستخدم غير مسجل دخول');
      }

      // إنشاء نموذج أذن الصرف
      final releaseOrder = WarehouseReleaseOrderModel.fromClientOrder(
        approvedOrder,
        assignedTo,
      );

      // إدراج أذن الصرف في قاعدة البيانات
      final releaseOrderData = {
        'release_order_number': releaseOrder.releaseOrderNumber,
        'original_order_id': releaseOrder.originalOrderId,
        'client_id': releaseOrder.clientId,
        'client_name': releaseOrder.clientName,
        'client_email': releaseOrder.clientEmail,
        'client_phone': releaseOrder.clientPhone,
        'total_amount': releaseOrder.totalAmount,
        'discount': releaseOrder.discount,
        'final_amount': releaseOrder.finalAmount,
        'status': releaseOrder.status.toString().split('.').last,
        'notes': notes ?? releaseOrder.notes,
        'shipping_address': releaseOrder.shippingAddress,
        'assigned_to': assignedTo,
        'metadata': releaseOrder.metadata,
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from(_releaseOrdersTable)
          .insert(releaseOrderData)
          .select()
          .single();

      final releaseOrderId = response['id'] as String;
      AppLogger.info('✅ تم إنشاء أذن الصرف: $releaseOrderId');

      // إدراج عناصر أذن الصرف
      final itemsData = releaseOrder.items.map((item) => {
        'release_order_id': releaseOrderId,
        'product_id': item.productId,
        'product_name': item.productName,
        'product_image': item.productImage,
        'product_category': item.productCategory,
        'quantity': item.quantity,
        'unit_price': item.unitPrice,
        'subtotal': item.subtotal,
        'notes': item.notes,
        'metadata': item.metadata,
      }).toList();

      await _supabase
          .from(_releaseOrderItemsTable)
          .insert(itemsData);

      AppLogger.info('✅ تم إدراج ${itemsData.length} عنصر في أذن الصرف');

      return releaseOrderId;
    } catch (e) {
      AppLogger.error('❌ خطأ في إنشاء أذن الصرف: $e');
      rethrow;
    }
  }

  /// إنشاء أذن صرف جديد من طلب معتمد مع تحديد المخازن
  Future<String?> createReleaseOrderFromApprovedOrderWithWarehouseSelection({
    required ClientOrder approvedOrder,
    required String assignedTo,
    required Map<String, Map<String, int>> warehouseSelections,
    String? notes,
  }) async {
    try {
      AppLogger.info('🏭 إنشاء أذن صرف مع تحديد المخازن من الطلب المعتمد: ${approvedOrder.id}');

      // التحقق من المصادقة
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('المستخدم غير مسجل دخول');
      }

      // إنشاء نموذج أذن الصرف
      final releaseOrder = WarehouseReleaseOrderModel.fromClientOrder(
        approvedOrder,
        assignedTo,
      );

      // إضافة معلومات المخازن المحددة إلى الملاحظات
      final warehouseInfo = warehouseSelections.entries.map((entry) {
        final productId = entry.key;
        final warehouses = entry.value;
        final warehouseList = warehouses.entries.map((w) => '${w.key}: ${w.value}').join(', ');
        return 'المنتج $productId: $warehouseList';
      }).join('\n');

      final enhancedNotes = '${notes ?? ''}\n\nتوزيع المخازن:\n$warehouseInfo';

      // تحضير بيانات أذن الصرف
      final releaseOrderData = {
        'release_order_number': releaseOrder.releaseOrderNumber,
        'original_order_id': releaseOrder.originalOrderId,
        'client_id': releaseOrder.clientId,
        'client_name': releaseOrder.clientName,
        'client_email': releaseOrder.clientEmail,
        'client_phone': releaseOrder.clientPhone,
        'total_amount': releaseOrder.totalAmount,
        'discount': releaseOrder.discount,
        'final_amount': releaseOrder.finalAmount,
        'status': releaseOrder.status.toString().split('.').last,
        'notes': enhancedNotes,
        'shipping_address': releaseOrder.shippingAddress,
        'assigned_to': releaseOrder.assignedTo,
        'metadata': {
          ...(releaseOrder.metadata ?? {}),
          'warehouse_selections': warehouseSelections,
          'created_with_warehouse_selection': true,
        },
      };

      final response = await _supabase
          .from(_releaseOrdersTable)
          .insert(releaseOrderData)
          .select()
          .single();

      final releaseOrderId = response['id'] as String;
      AppLogger.info('✅ تم إنشاء أذن الصرف مع تحديد المخازن: $releaseOrderId');

      // إدراج عناصر أذن الصرف مع معلومات المخازن
      final itemsData = <Map<String, dynamic>>[];

      for (final item in releaseOrder.items) {
        final productWarehouseSelections = warehouseSelections[item.productId] ?? {};

        // إنشاء عنصر منفصل لكل مخزن محدد
        for (final warehouseEntry in productWarehouseSelections.entries) {
          final warehouseId = warehouseEntry.key;
          final quantity = warehouseEntry.value;

          if (quantity > 0) {
            itemsData.add({
              'release_order_id': releaseOrderId,
              'product_id': item.productId,
              'product_name': item.productName,
              'product_image': item.productImage,
              'product_category': item.productCategory,
              'quantity': quantity,
              'unit_price': item.unitPrice,
              'subtotal': item.unitPrice * quantity,
              'notes': item.notes,
              'metadata': {
                ...(item.metadata ?? {}),
                'warehouse_id': warehouseId,
                'original_quantity': item.quantity,
              },
            });
          }
        }
      }

      if (itemsData.isNotEmpty) {
        await _supabase
            .from(_releaseOrderItemsTable)
            .insert(itemsData);
      }

      AppLogger.info('✅ تم إنشاء أذن الصرف مع تحديد المخازن بنجاح');
      return releaseOrderId;
    } catch (e) {
      AppLogger.error('❌ خطأ في إنشاء أذن الصرف مع تحديد المخازن: $e');
      return null;
    }
  }

  /// الحصول على جميع أذون الصرف (موحد من مصادر متعددة)
  Future<List<WarehouseReleaseOrderModel>> getAllReleaseOrders({
    WarehouseReleaseOrderStatus? status,
    String? assignedTo,
    int limit = 100,
  }) async {
    try {
      AppLogger.info('📋 تحميل أذون الصرف من مصادر متعددة...');

      final allReleaseOrders = <WarehouseReleaseOrderModel>[];

      // 1. تحميل أذون الصرف من جدول warehouse_release_orders (الطلبات المعلقة)
      final pendingOrdersReleaseOrders = await _loadFromReleaseOrdersTable(
        status: status,
        assignedTo: assignedTo,
        limit: limit,
      );
      allReleaseOrders.addAll(pendingOrdersReleaseOrders);
      AppLogger.info('📦 تم تحميل ${pendingOrdersReleaseOrders.length} أذن صرف من الطلبات المعلقة');

      // 2. تحميل طلبات الصرف من جدول warehouse_requests (فواتير المتجر)
      final storeInvoiceReleaseOrders = await _loadFromWarehouseRequestsTable(
        status: status,
        assignedTo: assignedTo,
        limit: limit,
      );
      allReleaseOrders.addAll(storeInvoiceReleaseOrders);
      AppLogger.info('📦 تم تحميل ${storeInvoiceReleaseOrders.length} أذن صرف من فواتير المتجر');

      // 3. ترتيب النتائج حسب تاريخ الإنشاء (الأحدث أولاً)
      allReleaseOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // 4. تطبيق الحد الأقصى للنتائج
      final limitedResults = allReleaseOrders.take(limit).toList();

      AppLogger.info('✅ تم تحميل ${limitedResults.length} أذن صرف إجمالي من جميع المصادر');
      return limitedResults;
    } catch (e) {
      AppLogger.error('❌ خطأ في تحميل أذون الصرف: $e');
      return [];
    }
  }

  /// تحميل أذون الصرف من جدول warehouse_release_orders (الطلبات المعلقة)
  Future<List<WarehouseReleaseOrderModel>> _loadFromReleaseOrdersTable({
    WarehouseReleaseOrderStatus? status,
    String? assignedTo,
    int limit = 100,
  }) async {
    try {
      // First check if the tables exist
      final tablesExist = await _checkTablesExist();
      if (!tablesExist) {
        AppLogger.warning('⚠️ جداول أذون الصرف غير موجودة في قاعدة البيانات');
        return [];
      }

      var query = _supabase
          .from(_releaseOrdersTable)
          .select('''
            *,
            warehouse_release_order_items (
              *
            )
          ''');

      // تطبيق الفلاتر
      if (status != null) {
        query = query.eq('status', status.toString().split('.').last);
      }

      if (assignedTo != null) {
        query = query.eq('assigned_to', assignedTo);
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(limit);

      final releaseOrders = (response as List<dynamic>)
          .map((data) => _parseReleaseOrderFromResponse(data as Map<String, dynamic>))
          .toList();

      return releaseOrders;
    } catch (e) {
      AppLogger.error('❌ خطأ في تحميل أذون الصرف من جدول warehouse_release_orders: $e');

      // If it's a schema error, return empty list instead of crashing
      if (e.toString().contains('PGRST200') || e.toString().contains('relationship')) {
        AppLogger.warning('⚠️ جداول أذون الصرف غير متاحة - يرجى تطبيق migration قاعدة البيانات');
        return [];
      }

      return [];
    }
  }

  /// تحميل طلبات الصرف من جدول warehouse_requests وتحويلها إلى أذون صرف
  Future<List<WarehouseReleaseOrderModel>> _loadFromWarehouseRequestsTable({
    WarehouseReleaseOrderStatus? status,
    String? assignedTo,
    int limit = 100,
  }) async {
    try {
      // تحميل طلبات الصرف من فواتير المتجر
      final dispatchRequests = await _dispatchService.getDispatchRequests(
        limit: limit,
      );

      // تصفية الطلبات التي تأتي من فواتير المتجر فقط واستبعاد المحذوفة
      final storeInvoiceRequests = dispatchRequests.where((request) =>
        (request.reason.contains('صرف فاتورة') ||
         request.isMultiWarehouseDistribution) &&
        request.status != 'deleted' // استبعاد الطلبات المحذوفة
      ).toList();

      // تحويل طلبات الصرف إلى أذون صرف
      final releaseOrders = <WarehouseReleaseOrderModel>[];
      for (final request in storeInvoiceRequests) {
        // التحقق من أن الطلب لم يتم حذفه
        if (await _isRequestDeleted(request.id)) {
          AppLogger.info('🚫 تم تجاهل طلب محذوف: ${request.id}');
          continue;
        }

        final releaseOrder = await _convertDispatchToReleaseOrder(request);

        // تطبيق الفلاتر
        bool shouldInclude = true;

        if (status != null && releaseOrder.status != status) {
          shouldInclude = false;
        }

        if (assignedTo != null && releaseOrder.assignedTo != assignedTo) {
          shouldInclude = false;
        }

        if (shouldInclude) {
          releaseOrders.add(releaseOrder);
        }
      }

      return releaseOrders;
    } catch (e) {
      AppLogger.error('❌ خطأ في تحميل طلبات الصرف من warehouse_requests: $e');
      return [];
    }
  }

  /// التحقق من أن الطلب تم حذفه
  Future<bool> _isRequestDeleted(String requestId) async {
    try {
      final response = await _supabase
          .from('warehouse_requests')
          .select('status, metadata')
          .eq('id', requestId)
          .maybeSingle();

      if (response == null) {
        return true; // الطلب غير موجود = محذوف
      }

      final status = response['status'] as String?;
      final metadata = response['metadata'] as Map<String, dynamic>?;

      // التحقق من حالة الحذف
      if (status == 'deleted') {
        return true;
      }

      // التحقق من metadata للحذف
      if (metadata != null) {
        if (metadata.containsKey('deleted_at') ||
            metadata.containsKey('bulk_deleted_at')) {
          return true;
        }
      }

      return false;
    } catch (e) {
      AppLogger.error('❌ خطأ في التحقق من حالة الطلب: $e');
      return false; // في حالة الخطأ، نعتبر الطلب غير محذوف
    }
  }

  /// تحويل طلب صرف من warehouse_requests إلى نموذج أذن صرف
  Future<WarehouseReleaseOrderModel> _convertDispatchToReleaseOrder(WarehouseDispatchModel dispatch) async {
    // استخراج معلومات العميل من السبب
    final customerName = dispatch.customerNameFromReason ?? 'عميل غير معروف';

    // إنشاء معرف فريد لأذن الصرف
    final releaseOrderId = 'WRO-DISPATCH-${dispatch.id}';

    // تحويل عناصر طلب الصرف إلى عناصر أذن صرف مع جلب أسماء المنتجات الذكي
    final releaseOrderItems = <WarehouseReleaseOrderItem>[];

    for (final item in dispatch.items) {
      // محاولة الحصول على اسم المنتج الصحيح
      final productName = await _getIntelligentProductName(item);

      // محاولة الحصول على معلومات المنتج الإضافية
      final productInfo = await _getProductInfo(item.productId);

      // تحويل البيانات مع التحقق من الأنواع
      final productImage = productInfo?['imageUrl'] as String?;
      final productCategory = productInfo?['category'] as String?;
      final productPrice = (productInfo?['price'] as num?)?.toDouble() ?? item.unitPrice;

      releaseOrderItems.add(WarehouseReleaseOrderItem(
        id: 'WRI-${item.id}',
        productId: item.productId,
        productName: productName,
        productImage: productImage,
        productCategory: productCategory,
        quantity: item.quantity,
        unitPrice: productPrice,
        subtotal: productPrice * item.quantity,
        notes: item.notes,
        metadata: {
          'source': 'warehouse_dispatch',
          'original_dispatch_item_id': item.id,
          'product_lookup_method': productInfo != null ? 'database_lookup' : 'notes_extraction',
          'original_product_name': item.productName,
        },
      ));
    }

    // تحويل حالة طلب الصرف إلى حالة أذن الصرف
    final releaseOrderStatus = _mapDispatchStatusToReleaseOrderStatus(dispatch.status);

    // حساب المبلغ الإجمالي
    final totalAmount = releaseOrderItems.fold(0.0, (sum, item) => sum + item.subtotal);

    return WarehouseReleaseOrderModel(
      id: releaseOrderId,
      releaseOrderNumber: dispatch.requestNumber,
      originalOrderId: dispatch.originalInvoiceId ?? dispatch.id,
      clientId: dispatch.requestedBy,
      clientName: customerName,
      clientEmail: '', // غير متوفر في طلب الصرف
      clientPhone: '', // غير متوفر في طلب الصرف
      items: releaseOrderItems,
      totalAmount: totalAmount,
      discount: 0.0,
      finalAmount: totalAmount,
      status: releaseOrderStatus,
      createdAt: dispatch.requestedAt,
      approvedAt: dispatch.approvedAt,
      completedAt: dispatch.executedAt,
      notes: dispatch.notes,
      shippingAddress: null,
      assignedTo: dispatch.requestedBy,
      warehouseManagerId: dispatch.approvedBy,
      warehouseManagerName: null,
      rejectionReason: null,
      metadata: {
        'source': 'warehouse_dispatch',
        'original_dispatch_id': dispatch.id,
        'dispatch_type': dispatch.type,
        'warehouse_id': dispatch.warehouseId,
        'source_description': dispatch.sourceDescription,
        'is_multi_warehouse_distribution': dispatch.isMultiWarehouseDistribution,
      },
    );
  }

  /// الحصول على اسم المنتج بطريقة ذكية
  Future<String> _getIntelligentProductName(WarehouseDispatchItemModel item) async {
    try {
      // الطريقة الأولى: محاولة جلب اسم المنتج من قاعدة البيانات
      final productFromDb = await _getProductFromDatabase(item.productId);
      if (productFromDb != null && productFromDb['name'] != null) {
        AppLogger.info('✅ تم العثور على اسم المنتج من قاعدة البيانات: ${productFromDb['name']}');
        return productFromDb['name'] as String;
      }

      // الطريقة الثانية: استخراج اسم المنتج من حقل الملاحظات
      final nameFromNotes = _extractProductNameFromNotes(item.notes);
      if (nameFromNotes != null && nameFromNotes.isNotEmpty && nameFromNotes != 'منتج غير معروف') {
        AppLogger.info('✅ تم استخراج اسم المنتج من الملاحظات: $nameFromNotes');
        return nameFromNotes;
      }

      // الطريقة الثالثة: البحث في جدول المنتجات باستخدام معرف المنتج
      final productBySearch = await _searchProductById(item.productId);
      if (productBySearch != null) {
        AppLogger.info('✅ تم العثور على المنتج بالبحث: $productBySearch');
        return productBySearch;
      }

      // الطريقة الرابعة: إنشاء اسم مؤقت بناءً على معرف المنتج
      final fallbackName = 'منتج ${item.productId}';
      AppLogger.warning('⚠️ لم يتم العثور على اسم المنتج، استخدام الاسم المؤقت: $fallbackName');
      return fallbackName;

    } catch (e) {
      AppLogger.error('❌ خطأ في الحصول على اسم المنتج: $e');
      return 'منتج ${item.productId}';
    }
  }

  /// جلب معلومات المنتج من قاعدة البيانات
  Future<Map<String, dynamic>?> _getProductFromDatabase(String productId) async {
    try {
      final response = await _supabase
          .from('products')
          .select('id, name, price, category, images')
          .eq('id', productId)
          .maybeSingle();

      if (response != null) {
        // استخراج رابط الصورة الأولى إن وجدت
        String? imageUrl;
        if (response['images'] != null) {
          final images = response['images'] as List<dynamic>?;
          if (images != null && images.isNotEmpty) {
            imageUrl = images.first as String?;
          }
        }

        return {
          'name': response['name'],
          'price': response['price'],
          'category': response['category'],
          'imageUrl': imageUrl,
        };
      }
      return null;
    } catch (e) {
      AppLogger.error('❌ خطأ في جلب المنتج من قاعدة البيانات: $e');
      return null;
    }
  }

  /// استخراج اسم المنتج من حقل الملاحظات
  String? _extractProductNameFromNotes(String? notes) {
    if (notes == null || notes.isEmpty) return null;

    try {
      // تجربة عدة أنماط لاستخراج اسم المنتج

      // النمط الأول: "اسم المنتج - تفاصيل إضافية"
      if (notes.contains(' - ')) {
        final parts = notes.split(' - ');
        final productName = parts.first.trim();
        if (productName.isNotEmpty && productName != 'منتج غير معروف') {
          return productName;
        }
      }

      // النمط الثاني: "منتج: اسم المنتج"
      if (notes.contains('منتج:')) {
        final match = RegExp(r'منتج:\s*(.+?)(?:\s*-|\s*\n|$)').firstMatch(notes);
        if (match != null) {
          final productName = match.group(1)?.trim();
          if (productName != null && productName.isNotEmpty) {
            return productName;
          }
        }
      }

      // النمط الثالث: "صرف فاتورة: اسم العميل - اسم المنتج"
      if (notes.contains('صرف فاتورة:')) {
        final match = RegExp(r'صرف فاتورة:.*?-\s*(.+?)(?:\s*-|\s*\n|$)').firstMatch(notes);
        if (match != null) {
          final productName = match.group(1)?.trim();
          if (productName != null && productName.isNotEmpty) {
            return productName;
          }
        }
      }

      // النمط الرابع: استخدام الملاحظات كاملة إذا كانت قصيرة ومعقولة
      if (notes.length < 50 && !notes.contains('صرف') && !notes.contains('فاتورة')) {
        return notes.trim();
      }

      return null;
    } catch (e) {
      AppLogger.error('❌ خطأ في استخراج اسم المنتج من الملاحظات: $e');
      return null;
    }
  }

  /// البحث عن المنتج بالمعرف في جداول مختلفة
  Future<String?> _searchProductById(String productId) async {
    try {
      // البحث في جدول المخزون
      final inventoryResponse = await _supabase
          .from('warehouse_inventory')
          .select('product_id, notes')
          .eq('product_id', productId)
          .limit(1)
          .maybeSingle();

      if (inventoryResponse != null && inventoryResponse['notes'] != null) {
        final nameFromInventory = _extractProductNameFromNotes(inventoryResponse['notes'] as String);
        if (nameFromInventory != null) {
          return nameFromInventory;
        }
      }

      // البحث في جدول معاملات المخزون
      final transactionResponse = await _supabase
          .from('warehouse_transactions')
          .select('product_id, notes')
          .eq('product_id', productId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (transactionResponse != null && transactionResponse['notes'] != null) {
        final nameFromTransaction = _extractProductNameFromNotes(transactionResponse['notes'] as String);
        if (nameFromTransaction != null) {
          return nameFromTransaction;
        }
      }

      return null;
    } catch (e) {
      AppLogger.error('❌ خطأ في البحث عن المنتج: $e');
      return null;
    }
  }

  /// الحصول على معلومات المنتج الإضافية
  Future<Map<String, dynamic>?> _getProductInfo(String productId) async {
    return await _getProductFromDatabase(productId);
  }

  /// معالجة عنصر واحد من أذن الصرف (خصم المخزون)
  Future<bool> processReleaseOrderItem({
    required String releaseOrderId,
    required String itemId,
    required String warehouseManagerId,
    String? notes,
  }) async {
    try {
      AppLogger.info('🔄 بدء معالجة عنصر أذن الصرف: $itemId');

      // الحصول على تفاصيل أذن الصرف والعنصر
      final releaseOrder = await getReleaseOrder(releaseOrderId);
      if (releaseOrder == null) {
        throw Exception('لم يتم العثور على أذن الصرف');
      }

      final item = releaseOrder.items.firstWhere(
        (item) => item.id == itemId,
        orElse: () => throw Exception('لم يتم العثور على العنصر في أذن الصرف'),
      );

      // تحويل العنصر إلى نموذج معالجة للخصم الذكي
      final processingModel = DispatchProductProcessingModel.fromDispatchItem(
        itemId: item.id,
        requestId: releaseOrderId,
        productId: item.productId,
        productName: item.productName,
        quantity: item.quantity,
        notes: item.notes,
      );

      // تنفيذ الخصم الذكي للمخزون
      final deductionResult = await _deductionService.deductProductInventory(
        product: processingModel,
        performedBy: warehouseManagerId,
        requestId: releaseOrderId,
        strategy: WarehouseSelectionStrategy.balanced,
      );

      AppLogger.info('📊 نتيجة خصم المخزون:');
      AppLogger.info('   النجاح: ${deductionResult.success}');
      AppLogger.info('   المطلوب: ${deductionResult.totalRequestedQuantity}');
      AppLogger.info('   المخصوم: ${deductionResult.totalDeductedQuantity}');
      AppLogger.info('   المخازن المتأثرة: ${deductionResult.warehouseResults.length}');

      if (!deductionResult.success) {
        final errorMsg = 'فشل في خصم المخزون: ${deductionResult.errors.join(', ')}';
        AppLogger.error('❌ $errorMsg');
        throw Exception(errorMsg);
      }

      // تحديث حالة العنصر في قاعدة البيانات
      await _supabase
          .from(_releaseOrderItemsTable)
          .update({
            'processed_at': DateTime.now().toIso8601String(),
            'processed_by': warehouseManagerId,
            'processing_notes': notes,
            'deduction_result': {
              'success': deductionResult.success,
              'total_requested': deductionResult.totalRequestedQuantity,
              'total_deducted': deductionResult.totalDeductedQuantity,
              'warehouses_count': deductionResult.warehouseResults.length,
              'errors_count': deductionResult.errors.length,
            },
            'metadata': {
              ...(item.metadata ?? {}),
              'processed': true,
              'deduction_success': true,
              'warehouses_affected': deductionResult.warehouseResults.length,
              'total_deducted': deductionResult.totalDeductedQuantity,
            },
          })
          .eq('id', itemId);

      AppLogger.info('✅ تم معالجة العنصر بنجاح: ${item.productName}');
      return true;

    } catch (e) {
      AppLogger.error('❌ خطأ في معالجة عنصر أذن الصرف: $e');
      return false;
    }
  }

  /// معالجة جميع عناصر أذن الصرف
  Future<bool> processAllReleaseOrderItems({
    required String releaseOrderId,
    required String warehouseManagerId,
    String? notes,
  }) async {
    // CRITICAL FIX: Preserve authentication state throughout release order processing
    User? authenticatedUser;
    try {
      authenticatedUser = await AuthStateManager.getCurrentUser(forceRefresh: false);
      if (authenticatedUser == null) {
        AppLogger.error('❌ لا يوجد مستخدم مصادق عليه لمعالجة أذن الصرف');
        throw Exception('المستخدم غير مصادق عليه - يرجى تسجيل الدخول مرة أخرى');
      }

      if (authenticatedUser.id != warehouseManagerId) {
        AppLogger.warning('⚠️ عدم تطابق معرف المستخدم المصادق عليه مع معرف مدير المخزن');
        AppLogger.info('المستخدم المصادق عليه: ${authenticatedUser.id}');
        AppLogger.info('مدير المخزن المطلوب: $warehouseManagerId');
      }

      AppLogger.info('✅ تم التحقق من المصادقة لمعالجة أذن الصرف: ${authenticatedUser.id}');
    } catch (authError) {
      AppLogger.error('❌ خطأ في التحقق من المصادقة لمعالجة أذن الصرف: $authError');
      throw Exception('فشل في التحقق من المصادقة: $authError');
    }

    try {
      AppLogger.info('🔄 بدء معالجة جميع عناصر أذن الصرف: $releaseOrderId');

      // التحقق من نوع أذن الصرف (عادي أم محول من طلب صرف)
      if (releaseOrderId.startsWith('WRO-DISPATCH-')) {
        AppLogger.info('🔄 معالجة أذن صرف محول من طلب صرف');
        return await _processDispatchConvertedReleaseOrder(
          releaseOrderId: releaseOrderId,
          warehouseManagerId: warehouseManagerId,
          notes: notes,
        );
      }

      final releaseOrder = await getReleaseOrder(releaseOrderId);
      if (releaseOrder == null) {
        throw Exception('لم يتم العثور على أذن الصرف');
      }

      int successCount = 0;
      final int totalItems = releaseOrder.items.length;
      final errors = <String>[];

      // معالجة كل عنصر على حدة مع التحقق من المصادقة
      for (final item in releaseOrder.items) {
        try {
          // CRITICAL FIX: Verify authentication state before processing each item
          try {
            final currentUser = _supabase.auth.currentUser;
            if (currentUser == null || currentUser.id != authenticatedUser.id) {
              AppLogger.warning('⚠️ تأثرت حالة المصادقة أثناء معالجة العناصر، محاولة الاستعادة...');
              final recoveredUser = await AuthStateManager.getCurrentUser(forceRefresh: true);
              if (recoveredUser == null || recoveredUser.id != authenticatedUser.id) {
                throw Exception('فقدان المصادقة أثناء معالجة العنصر ${item.productName}');
              }
              AppLogger.info('✅ تم استعادة المصادقة بنجاح للعنصر: ${item.productName}');
            }
          } catch (authCheckError) {
            AppLogger.error('❌ خطأ في التحقق من المصادقة للعنصر ${item.productName}: $authCheckError');
            errors.add('خطأ في المصادقة للعنصر ${item.productName}: $authCheckError');
            continue;
          }

          // CRITICAL FIX: Use isolated operation for item processing to prevent cascading failures
          final success = await OperationIsolationService.executeIsolatedOperation<bool>(
            operationName: 'process_release_item_${item.productName}',
            operation: () => processReleaseOrderItem(
              releaseOrderId: releaseOrderId,
              itemId: item.id,
              warehouseManagerId: warehouseManagerId,
              notes: notes,
            ),
            fallbackValue: () => false,
            preserveAuthState: true,
            maxRetries: 1,
          );

          if (success) {
            successCount++;
          } else {
            errors.add('فشل في معالجة ${item.productName}');
          }
        } catch (e) {
          errors.add('خطأ في معالجة ${item.productName}: $e');
          AppLogger.error('❌ خطأ في معالجة العنصر ${item.productName}: $e');

          // CRITICAL FIX: Attempt authentication recovery after item processing failure
          try {
            AppLogger.info('🔄 محاولة استعادة المصادقة بعد فشل معالجة العنصر...');
            await AuthStateManager.getCurrentUser(forceRefresh: true);
          } catch (recoveryError) {
            AppLogger.error('❌ فشل في استعادة المصادقة بعد فشل العنصر: $recoveryError');
          }
        }
      }

      AppLogger.info('📊 نتائج المعالجة الشاملة:');
      AppLogger.info('   إجمالي العناصر: $totalItems');
      AppLogger.info('   نجح: $successCount');
      AppLogger.info('   فشل: ${totalItems - successCount}');
      AppLogger.info('   الأخطاء: ${errors.length}');

      // تحديث حالة أذن الصرف إذا تم معالجة جميع العناصر بنجاح
      if (successCount == totalItems) {
        await updateReleaseOrderStatus(
          releaseOrderId: releaseOrderId,
          newStatus: WarehouseReleaseOrderStatus.readyForDelivery,
          warehouseManagerId: warehouseManagerId,
          notes: notes,
        );
        AppLogger.info('✅ تم إكمال معالجة جميع العناصر - جاهز للتسليم');
        return true;
      } else {
        AppLogger.warning('⚠️ لم يتم معالجة جميع العناصر بنجاح');
        return false;
      }

    } catch (e) {
      AppLogger.error('❌ خطأ في معالجة جميع عناصر أذن الصرف: $e');

      // CRITICAL FIX: Attempt authentication recovery after release order processing failure
      try {
        AppLogger.info('🔄 محاولة استعادة المصادقة بعد فشل معالجة أذن الصرف...');
        final recoveredUser = await AuthStateManager.getCurrentUser(forceRefresh: true);
        if (recoveredUser != null) {
          AppLogger.info('✅ تم استعادة المصادقة بنجاح بعد فشل معالجة أذن الصرف: ${recoveredUser.id}');
        } else {
          AppLogger.warning('⚠️ فشل في استعادة المصادقة بعد فشل معالجة أذن الصرف');
        }
      } catch (recoveryError) {
        AppLogger.error('❌ خطأ في استعادة المصادقة بعد فشل معالجة أذن الصرف: $recoveryError');
      }

      return false;
    }
  }

  /// تأكيد التسليم لأذن الصرف
  Future<bool> confirmDelivery({
    required String releaseOrderId,
    required String warehouseManagerId,
    required String warehouseManagerName,
    String? deliveryNotes,
  }) async {
    try {
      AppLogger.info('🚚 بدء تأكيد التسليم لأذن الصرف: $releaseOrderId');

      // التحقق من المصادقة
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('المستخدم غير مسجل دخول');
      }

      // التحقق من وجود أذن الصرف والتأكد من أنه جاهز للتسليم
      final releaseOrder = await getReleaseOrder(releaseOrderId);
      if (releaseOrder == null) {
        throw Exception('أذن الصرف غير موجود');
      }

      if (releaseOrder.status != WarehouseReleaseOrderStatus.readyForDelivery) {
        throw Exception('أذن الصرف ليس جاهزاً للتسليم. الحالة الحالية: ${releaseOrder.statusText}');
      }

      // تحديث أذن الصرف بمعلومات التسليم
      final now = DateTime.now();
      await _supabase
          .from(_releaseOrdersTable)
          .update({
            'status': 'completed',
            'completed_at': now.toIso8601String(), // مطلوب لقيد valid_completion_data
            'delivered_at': now.toIso8601String(),
            'delivered_by': warehouseManagerId,
            'delivered_by_name': warehouseManagerName,
            'delivery_notes': deliveryNotes,
            'updated_at': now.toIso8601String(),
          })
          .eq('id', releaseOrderId);

      // إضافة سجل في تاريخ أذن الصرف
      await _addReleaseOrderHistory(
        releaseOrderId: releaseOrderId,
        action: 'delivered',
        oldStatus: 'readyForDelivery',
        newStatus: 'completed',
        description: 'تم تأكيد التسليم من مدير المخزن',
        changedBy: warehouseManagerId,
        changedByName: warehouseManagerName,
        changedByRole: 'warehouse_manager',
        metadata: {
          'delivered_at': now.toIso8601String(),
          'delivery_notes': deliveryNotes,
        },
      );

      AppLogger.info('✅ تم تأكيد التسليم بنجاح لأذن الصرف: $releaseOrderId');

      // ملاحظة: تحديث حالة الطلب الأصلي سيتم تلقائياً عبر المشغل في قاعدة البيانات

      return true;

    } catch (e) {
      AppLogger.error('❌ خطأ في تأكيد التسليم: $e');
      return false;
    }
  }

  /// معالجة أذن صرف محول من طلب صرف
  Future<bool> _processDispatchConvertedReleaseOrder({
    required String releaseOrderId,
    required String warehouseManagerId,
    String? notes,
  }) async {
    try {
      AppLogger.info('🔄 بدء معالجة أذن صرف محول من طلب صرف: $releaseOrderId');

      // استخراج UUID الأصلي من معرف أذن الصرف
      final extractedUuid = _extractUuidFromReleaseOrderId(releaseOrderId);

      // الحصول على طلب الصرف الأصلي
      final dispatchRequest = await _dispatchService.getDispatchRequestById(extractedUuid);
      if (dispatchRequest == null) {
        throw Exception('لم يتم العثور على طلب الصرف الأصلي');
      }

      AppLogger.info('✅ تم العثور على طلب الصرف الأصلي: ${dispatchRequest.requestNumber}');

      // معالجة عناصر طلب الصرف باستخدام خدمة الخصم الذكي
      int successCount = 0;
      final int totalItems = dispatchRequest.items.length;
      final errors = <String>[];

      for (final item in dispatchRequest.items) {
        try {
          AppLogger.info('🔄 بدء معالجة العنصر: ${item.productName} (الكمية: ${item.quantity})');

          // تحويل عنصر طلب الصرف إلى نموذج معالجة للخصم الذكي
          final processingItem = DispatchProductProcessingModel.fromDispatchItem(
            itemId: item.id,
            requestId: dispatchRequest.id,
            productId: item.productId,
            productName: item.productName,
            quantity: item.quantity,
            notes: item.notes,
          );

          AppLogger.info('📦 تم إنشاء نموذج المعالجة للمنتج: ${processingItem.productName}');
          AppLogger.info('   معرف المنتج: ${processingItem.productId}');
          AppLogger.info('   الكمية المطلوبة: ${processingItem.requestedQuantity}');
          AppLogger.info('   يحتوي على بيانات المواقع: ${processingItem.hasLocationData}');

          // إنشاء خدمة الخصم الذكي
          final intelligentDeductionService = IntelligentInventoryDeductionService();

          AppLogger.info('⚡ بدء تنفيذ الخصم الذكي للمنتج: ${processingItem.productName}');

          // تنفيذ الخصم الذكي
          final deductionResult = await intelligentDeductionService.deductProductInventory(
            product: processingItem,
            performedBy: warehouseManagerId,
            requestId: dispatchRequest.id,
          );

          AppLogger.info('📊 نتيجة الخصم الذكي:');
          AppLogger.info('   النجاح: ${deductionResult.success}');
          AppLogger.info('   الكمية المطلوبة: ${deductionResult.totalRequestedQuantity}');
          AppLogger.info('   الكمية المخصومة: ${deductionResult.totalDeductedQuantity}');
          AppLogger.info('   عدد المخازن المتأثرة: ${deductionResult.warehouseResults.length}');

          if (deductionResult.success && deductionResult.totalDeductedQuantity >= item.quantity) {
            successCount++;
            AppLogger.info('✅ تم معالجة العنصر بنجاح: ${item.productName}');
          } else {
            final errorMsg = 'فشل في معالجة ${item.productName}: كمية مخصومة ${deductionResult.totalDeductedQuantity} من ${item.quantity} مطلوب';
            errors.add(errorMsg);
            AppLogger.warning('⚠️ $errorMsg');

            // إضافة تفاصيل أخطاء المخازن إن وجدت
            for (final warehouseResult in deductionResult.warehouseResults) {
              if (!warehouseResult.success) {
                AppLogger.warning('   خطأ في المخزن ${warehouseResult.warehouseName}: ${warehouseResult.error}');
              }
            }
          }
        } catch (e, stackTrace) {
          final errorMsg = 'خطأ في معالجة ${item.productName}: $e';
          errors.add(errorMsg);
          AppLogger.error('❌ $errorMsg');
          AppLogger.error('📍 Stack trace: $stackTrace');
        }
      }

      AppLogger.info('📊 نتائج معالجة أذن الصرف المحول:');
      AppLogger.info('   إجمالي العناصر: $totalItems');
      AppLogger.info('   نجح: $successCount');
      AppLogger.info('   فشل: ${totalItems - successCount}');

      // تحديث حالة طلب الصرف الأصلي إذا تم معالجة جميع العناصر بنجاح
      if (successCount == totalItems) {
        await _dispatchService.updateDispatchStatus(
          requestId: extractedUuid,
          newStatus: 'completed',
          updatedBy: warehouseManagerId,
          notes: notes,
        );
        AppLogger.info('✅ تم إكمال معالجة جميع العناصر وتحديث حالة طلب الصرف الأصلي');
        return true;
      } else {
        AppLogger.warning('⚠️ لم يتم معالجة جميع العناصر بنجاح');
        return false;
      }

    } catch (e) {
      AppLogger.error('❌ خطأ في معالجة أذن الصرف المحول: $e');
      return false;
    }
  }

  /// تحويل حالة طلب الصرف إلى حالة أذن الصرف
  WarehouseReleaseOrderStatus _mapDispatchStatusToReleaseOrderStatus(String dispatchStatus) {
    switch (dispatchStatus) {
      case 'pending':
        return WarehouseReleaseOrderStatus.pendingWarehouseApproval;
      case 'approved':
      case 'processing': // قيد المعالجة يعتبر موافق عليه
        return WarehouseReleaseOrderStatus.approvedByWarehouse;
      case 'executed':
      case 'completed':
        return WarehouseReleaseOrderStatus.completed;
      case 'rejected':
        return WarehouseReleaseOrderStatus.rejected;
      case 'cancelled':
        return WarehouseReleaseOrderStatus.cancelled;
      default:
        AppLogger.warning('⚠️ حالة طلب صرف غير معروفة: $dispatchStatus، سيتم استخدام الحالة الافتراضية');
        return WarehouseReleaseOrderStatus.pendingWarehouseApproval;
    }
  }

  /// التحقق من وجود الجداول المطلوبة
  Future<bool> _checkTablesExist() async {
    try {
      // Try a simple query to check if the table exists
      await _supabase
          .from(_releaseOrdersTable)
          .select('id')
          .limit(1);
      return true;
    } catch (e) {
      if (e.toString().contains('relation') && e.toString().contains('does not exist')) {
        return false;
      }
      // If it's a different error, assume tables exist but there's another issue
      return true;
    }
  }

  /// الحصول على أذن صرف محدد
  Future<WarehouseReleaseOrderModel?> getReleaseOrder(String releaseOrderId) async {
    try {
      AppLogger.info('🔍 البحث عن أذن الصرف: $releaseOrderId');

      // استخدام البحث المتقدم الذي يتعامل مع تنسيقات UUID المختلفة
      final response = await _findReleaseOrderInDatabase(releaseOrderId);

      if (response == null) {
        AppLogger.warning('⚠️ لم يتم العثور على أذن الصرف: $releaseOrderId');
        return null;
      }

      final releaseOrder = _parseReleaseOrderFromResponse(response);
      AppLogger.info('✅ تم العثور على أذن الصرف');
      return releaseOrder;
    } catch (e) {
      AppLogger.error('❌ خطأ في البحث عن أذن الصرف: $e');
      return null;
    }
  }

  /// تحديث حالة أذن الصرف مع إدارة شاملة للحالات
  Future<bool> updateReleaseOrderStatus({
    required String releaseOrderId,
    required WarehouseReleaseOrderStatus newStatus,
    String? warehouseManagerId,
    String? warehouseManagerName,
    String? rejectionReason,
    String? notes,
  }) async {
    try {
      AppLogger.info('🔄 تحديث حالة أذن الصرف: $releaseOrderId إلى $newStatus');

      // التحقق من نوع أذن الصرف (حقيقي أم محول من طلب صرف)
      if (releaseOrderId.startsWith('WRO-DISPATCH-')) {
        AppLogger.info('🔄 أذن صرف محول من طلب صرف، سيتم تحديث الطلب الأصلي');
        return await _updateDispatchOrderStatus(releaseOrderId, newStatus, warehouseManagerId, warehouseManagerName, rejectionReason, notes);
      }

      // الحصول على أذن الصرف الحالي للوصول إلى معلومات الطلب الأصلي
      final currentReleaseOrder = await getReleaseOrder(releaseOrderId);
      if (currentReleaseOrder == null) {
        AppLogger.error('❌ لم يتم العثور على أذن الصرف: $releaseOrderId');
        return false;
      }

      final updateData = <String, dynamic>{
        'status': newStatus.toString().split('.').last,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // إضافة بيانات إضافية حسب الحالة
      switch (newStatus) {
        case WarehouseReleaseOrderStatus.approvedByWarehouse:
          updateData['approved_at'] = DateTime.now().toIso8601String();
          if (warehouseManagerId != null) {
            updateData['warehouse_manager_id'] = warehouseManagerId;
          }
          if (warehouseManagerName != null) {
            updateData['warehouse_manager_name'] = warehouseManagerName;
          }
          break;
        case WarehouseReleaseOrderStatus.readyForDelivery:
          updateData['completed_at'] = DateTime.now().toIso8601String(); // تم إكمال المعالجة
          break;
        case WarehouseReleaseOrderStatus.completed:
          updateData['completed_at'] = DateTime.now().toIso8601String();
          break;
        case WarehouseReleaseOrderStatus.rejected:
          if (rejectionReason != null) {
            updateData['rejection_reason'] = rejectionReason;
          }
          break;
        default:
          break;
      }

      if (notes != null) {
        updateData['notes'] = notes;
      }

      // استخراج UUID الصحيح للتحديث
      final extractedUuid = _extractUuidFromReleaseOrderId(releaseOrderId);

      // تحديث أذن الصرف باستخدام UUID الصحيح
      await _supabase
          .from(_releaseOrdersTable)
          .update(updateData)
          .eq('id', extractedUuid);

      AppLogger.info('✅ تم تحديث حالة أذن الصرف بنجاح');

      // تنفيذ الإجراءات الإضافية حسب الحالة الجديدة
      await _handleStatusChangeActions(
        currentReleaseOrder,
        newStatus,
        warehouseManagerName,
        rejectionReason,
      );

      return true;
    } catch (e) {
      AppLogger.error('❌ خطأ في تحديث حالة أذن الصرف: $e');
      return false;
    }
  }

  /// تحديث حالة طلب الصرف الأصلي (للأذون المحولة من طلبات الصرف)
  Future<bool> _updateDispatchOrderStatus(
    String releaseOrderId,
    WarehouseReleaseOrderStatus newStatus,
    String? warehouseManagerId,
    String? warehouseManagerName,
    String? rejectionReason,
    String? notes,
  ) async {
    try {
      // استخراج معرف طلب الصرف الأصلي من معرف أذن الصرف
      final dispatchId = releaseOrderId.replaceFirst('WRO-DISPATCH-', '');
      AppLogger.info('🔄 تحديث طلب الصرف الأصلي: $dispatchId');

      // تحويل حالة أذن الصرف إلى حالة طلب الصرف
      String dispatchStatus;
      switch (newStatus) {
        case WarehouseReleaseOrderStatus.pendingWarehouseApproval:
          dispatchStatus = 'pending';
          break;
        case WarehouseReleaseOrderStatus.approvedByWarehouse:
          dispatchStatus = 'approved';
          break;
        case WarehouseReleaseOrderStatus.readyForDelivery:
          dispatchStatus = 'processing';
          break;
        case WarehouseReleaseOrderStatus.completed:
          dispatchStatus = 'executed';
          break;
        case WarehouseReleaseOrderStatus.rejected:
          dispatchStatus = 'rejected';
          break;
        case WarehouseReleaseOrderStatus.cancelled:
          dispatchStatus = 'cancelled';
          break;
      }

      // تحديث طلب الصرف في قاعدة البيانات
      final updateData = <String, dynamic>{
        'status': dispatchStatus,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (warehouseManagerId != null) {
        updateData['approved_by'] = warehouseManagerId;
      }

      if (newStatus == WarehouseReleaseOrderStatus.approvedByWarehouse) {
        updateData['approved_at'] = DateTime.now().toIso8601String();
      } else if (newStatus == WarehouseReleaseOrderStatus.completed) {
        updateData['executed_at'] = DateTime.now().toIso8601String();
      }

      if (rejectionReason != null) {
        updateData['rejection_reason'] = rejectionReason;
      }

      if (notes != null) {
        updateData['notes'] = notes;
      }

      await _supabase
          .from('warehouse_requests')
          .update(updateData)
          .eq('id', dispatchId);

      AppLogger.info('✅ تم تحديث حالة طلب الصرف الأصلي بنجاح');

      // تنفيذ الإجراءات الإضافية (الإشعارات وتحديث الطلبات الأصلية)
      // إنشاء نموذج مؤقت لأذن الصرف لتمرير المعلومات للإجراءات الإضافية
      final tempReleaseOrder = WarehouseReleaseOrderModel(
        id: releaseOrderId,
        releaseOrderNumber: 'DISPATCH-$dispatchId',
        originalOrderId: dispatchId,
        clientId: warehouseManagerId ?? '',
        clientName: 'عميل طلب الصرف',
        clientEmail: '',
        clientPhone: '',
        items: [],
        totalAmount: 0.0,
        discount: 0.0,
        finalAmount: 0.0,
        status: newStatus,
        createdAt: DateTime.now(),
        assignedTo: warehouseManagerId,
        warehouseManagerId: warehouseManagerId,
        warehouseManagerName: warehouseManagerName,
        rejectionReason: rejectionReason,
        metadata: {
          'source': 'warehouse_dispatch',
          'original_dispatch_id': dispatchId,
        },
      );

      await _handleStatusChangeActions(
        tempReleaseOrder,
        newStatus,
        warehouseManagerName,
        rejectionReason,
      );

      return true;
    } catch (e) {
      AppLogger.error('❌ خطأ في تحديث حالة طلب الصرف: $e');
      return false;
    }
  }

  /// التعامل مع الإجراءات الإضافية عند تغيير الحالة
  Future<void> _handleStatusChangeActions(
    WarehouseReleaseOrderModel releaseOrder,
    WarehouseReleaseOrderStatus newStatus,
    String? warehouseManagerName,
    String? rejectionReason,
  ) async {
    try {
      switch (newStatus) {
        case WarehouseReleaseOrderStatus.readyForDelivery:
          // تحديث حالة الطلب الأصلي إلى "تم الشحن"
          await _updateOriginalOrderToShipped(releaseOrder);

          // إرسال إشعار للعميل بالشحن
          await _sendCustomerShippedNotification(releaseOrder);

          // إرسال إشعار للمحاسب بجاهزية التسليم
          await _sendAccountantReadyForDeliveryNotification(releaseOrder, warehouseManagerName);
          break;

        case WarehouseReleaseOrderStatus.completed:
          // تحديث حالة الطلب الأصلي إلى "تم التسليم"
          await _updateOriginalOrderToDelivered(releaseOrder);

          // إرسال إشعار للعميل بالتسليم
          await _sendCustomerDeliveredNotification(releaseOrder);

          // إرسال إشعار للمحاسب بإكمال التسليم
          await _sendAccountantDeliveryCompletionNotification(releaseOrder, warehouseManagerName);
          break;

        case WarehouseReleaseOrderStatus.rejected:
          // إرسال إشعار للمحاسب بالرفض
          await _sendAccountantRejectionNotification(releaseOrder, rejectionReason);

          // إعادة الطلب الأصلي إلى حالة "معتمد" للمراجعة
          await _revertOriginalOrderStatus(releaseOrder);
          break;

        case WarehouseReleaseOrderStatus.approvedByWarehouse:
          // إرسال إشعار للمحاسب بالموافقة
          await _sendAccountantApprovalNotification(releaseOrder, warehouseManagerName);
          break;

        default:
          break;
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في تنفيذ إجراءات تغيير الحالة: $e');
      // لا نرمي الخطأ هنا لأن تحديث الحالة الأساسي نجح
    }
  }

  /// تحديث الطلب الأصلي إلى حالة "تم الشحن"
  Future<void> _updateOriginalOrderToShipped(WarehouseReleaseOrderModel releaseOrder) async {
    try {
      AppLogger.info('📦 تحديث الطلب الأصلي إلى حالة "تم الشحن": ${releaseOrder.originalOrderId}');

      final success = await _ordersService.updateOrderStatus(
        releaseOrder.originalOrderId,
        OrderStatus.shipped,
      );

      if (success) {
        AppLogger.info('✅ تم تحديث حالة الطلب الأصلي إلى "تم الشحن"');
      } else {
        AppLogger.error('❌ فشل في تحديث حالة الطلب الأصلي');
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في تحديث الطلب الأصلي: $e');
    }
  }

  /// تحديث الطلب الأصلي إلى حالة "تم التسليم"
  Future<void> _updateOriginalOrderToDelivered(WarehouseReleaseOrderModel releaseOrder) async {
    try {
      AppLogger.info('🚚 تحديث الطلب الأصلي إلى حالة "تم التسليم": ${releaseOrder.originalOrderId}');

      final success = await _ordersService.updateOrderStatus(
        releaseOrder.originalOrderId,
        OrderStatus.delivered,
      );

      if (success) {
        AppLogger.info('✅ تم تحديث حالة الطلب الأصلي إلى "تم التسليم"');
      } else {
        AppLogger.error('❌ فشل في تحديث حالة الطلب الأصلي');
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في تحديث الطلب الأصلي: $e');
    }
  }

  /// إعادة الطلب الأصلي إلى حالة "معتمد" للمراجعة
  Future<void> _revertOriginalOrderStatus(WarehouseReleaseOrderModel releaseOrder) async {
    try {
      AppLogger.info('🔄 إعادة الطلب الأصلي إلى حالة "معتمد": ${releaseOrder.originalOrderId}');

      final success = await _ordersService.updateOrderStatus(
        releaseOrder.originalOrderId,
        OrderStatus.confirmed,
      );

      if (success) {
        AppLogger.info('✅ تم إعادة الطلب الأصلي إلى حالة "معتمد"');
      } else {
        AppLogger.error('❌ فشل في إعادة حالة الطلب الأصلي');
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في إعادة حالة الطلب الأصلي: $e');
    }
  }

  /// إرسال إشعار للعميل بالشحن
  Future<void> _sendCustomerShippedNotification(WarehouseReleaseOrderModel releaseOrder) async {
    try {
      AppLogger.info('📧 إرسال إشعار الشحن للعميل: ${releaseOrder.clientId}');

      // إنشاء إشعار في التطبيق للعميل
      await _notificationService.createNotification(
        userId: releaseOrder.clientId,
        title: 'تم شحن طلبك',
        body: 'تم شحن طلبك رقم ${releaseOrder.releaseOrderNumber} بنجاح! سيصلك خلال الأيام القادمة.',
        type: 'order_shipped',
        category: 'orders',
        priority: 'high',
        route: '/customer/orders/${releaseOrder.originalOrderId}',
        referenceId: releaseOrder.originalOrderId,
        referenceType: 'order',
        actionData: {
          'release_order_id': releaseOrder.id,
          'release_order_number': releaseOrder.releaseOrderNumber,
          'final_amount': releaseOrder.finalAmount,
          'total_items': releaseOrder.totalItems,
          'total_quantity': releaseOrder.totalQuantity,
        },
        metadata: {
          'notification_type': 'customer_order_shipped',
          'requires_action': false,
        },
      );

      AppLogger.info('✅ تم إرسال إشعار الشحن للعميل');
    } catch (e) {
      AppLogger.error('❌ خطأ في إرسال إشعار الشحن للعميل: $e');
    }
  }

  /// إرسال إشعار للمحاسب بإكمال أذن الصرف
  Future<void> _sendAccountantCompletionNotification(
    WarehouseReleaseOrderModel releaseOrder,
    String? warehouseManagerName,
  ) async {
    try {
      AppLogger.info('📧 إرسال إشعار الإكمال للمحاسب: ${releaseOrder.assignedTo}');

      if (releaseOrder.assignedTo != null) {
        await _notificationService.createNotification(
          userId: releaseOrder.assignedTo!,
          title: 'تم إكمال أذن الصرف',
          body: 'تم إكمال أذن الصرف ${releaseOrder.releaseOrderNumber} بواسطة ${warehouseManagerName ?? "مدير المخزن"}',
          type: 'order_completed',
          category: 'orders',
          priority: 'normal',
          route: '/accountant/warehouse-release-orders/${releaseOrder.id}',
          referenceId: releaseOrder.id,
          referenceType: 'warehouse_release_order',
          actionData: {
            'release_order_id': releaseOrder.id,
            'release_order_number': releaseOrder.releaseOrderNumber,
            'client_name': releaseOrder.clientName,
            'final_amount': releaseOrder.finalAmount,
            'warehouse_manager': warehouseManagerName,
          },
          metadata: {
            'notification_type': 'warehouse_release_completed',
            'requires_action': false,
          },
        );
      }

      AppLogger.info('✅ تم إرسال إشعار الإكمال للمحاسب');
    } catch (e) {
      AppLogger.error('❌ خطأ في إرسال إشعار الإكمال للمحاسب: $e');
    }
  }

  /// إرسال إشعار للمحاسب برفض أذن الصرف
  Future<void> _sendAccountantRejectionNotification(
    WarehouseReleaseOrderModel releaseOrder,
    String? rejectionReason,
  ) async {
    try {
      AppLogger.info('📧 إرسال إشعار الرفض للمحاسب: ${releaseOrder.assignedTo}');

      if (releaseOrder.assignedTo != null) {
        await _notificationService.createNotification(
          userId: releaseOrder.assignedTo!,
          title: 'تم رفض أذن الصرف',
          body: 'تم رفض أذن الصرف ${releaseOrder.releaseOrderNumber}${rejectionReason != null ? " - السبب: $rejectionReason" : ""}',
          type: 'order_status_changed',
          category: 'orders',
          priority: 'high',
          route: '/accountant/warehouse-release-orders/${releaseOrder.id}',
          referenceId: releaseOrder.id,
          referenceType: 'warehouse_release_order',
          actionData: {
            'release_order_id': releaseOrder.id,
            'release_order_number': releaseOrder.releaseOrderNumber,
            'client_name': releaseOrder.clientName,
            'rejection_reason': rejectionReason,
            'original_order_id': releaseOrder.originalOrderId,
          },
          metadata: {
            'notification_type': 'warehouse_release_rejected',
            'requires_action': true,
            'action_required': 'review_rejection',
          },
        );
      }

      AppLogger.info('✅ تم إرسال إشعار الرفض للمحاسب');
    } catch (e) {
      AppLogger.error('❌ خطأ في إرسال إشعار الرفض للمحاسب: $e');
    }
  }

  /// إرسال إشعار للمحاسب بموافقة مدير المخزن
  Future<void> _sendAccountantApprovalNotification(
    WarehouseReleaseOrderModel releaseOrder,
    String? warehouseManagerName,
  ) async {
    try {
      AppLogger.info('📧 إرسال إشعار الموافقة للمحاسب: ${releaseOrder.assignedTo}');

      if (releaseOrder.assignedTo != null) {
        await _notificationService.createNotification(
          userId: releaseOrder.assignedTo!,
          title: 'تمت الموافقة على أذن الصرف',
          body: 'تمت الموافقة على أذن الصرف ${releaseOrder.releaseOrderNumber} بواسطة ${warehouseManagerName ?? "مدير المخزن"}',
          type: 'order_status_changed',
          category: 'orders',
          priority: 'normal',
          route: '/accountant/warehouse-release-orders/${releaseOrder.id}',
          referenceId: releaseOrder.id,
          referenceType: 'warehouse_release_order',
          actionData: {
            'release_order_id': releaseOrder.id,
            'release_order_number': releaseOrder.releaseOrderNumber,
            'client_name': releaseOrder.clientName,
            'warehouse_manager': warehouseManagerName,
          },
          metadata: {
            'notification_type': 'warehouse_release_approved',
            'requires_action': false,
          },
        );
      }

      AppLogger.info('✅ تم إرسال إشعار الموافقة للمحاسب');
    } catch (e) {
      AppLogger.error('❌ خطأ في إرسال إشعار الموافقة للمحاسب: $e');
    }
  }

  /// إرسال إشعار للعميل بالتسليم
  Future<void> _sendCustomerDeliveredNotification(WarehouseReleaseOrderModel releaseOrder) async {
    try {
      AppLogger.info('📧 إرسال إشعار التسليم للعميل: ${releaseOrder.clientId}');

      // إنشاء إشعار في التطبيق للعميل
      await _notificationService.createNotification(
        userId: releaseOrder.clientId,
        title: 'تم تسليم طلبك',
        body: 'تم تسليم طلبك رقم ${releaseOrder.releaseOrderNumber} بنجاح! نشكرك لثقتك بنا.',
        type: 'order_delivered',
        category: 'orders',
        priority: 'high',
        route: '/customer/orders/${releaseOrder.originalOrderId}',
        referenceId: releaseOrder.originalOrderId,
        referenceType: 'order',
        actionData: {
          'order_id': releaseOrder.originalOrderId,
          'release_order_number': releaseOrder.releaseOrderNumber,
          'client_name': releaseOrder.clientName,
        },
        metadata: {
          'notification_type': 'order_delivered',
          'requires_action': false,
        },
      );

      AppLogger.info('✅ تم إرسال إشعار التسليم للعميل');
    } catch (e) {
      AppLogger.error('❌ خطأ في إرسال إشعار التسليم للعميل: $e');
    }
  }

  /// إرسال إشعار للمحاسب بجاهزية التسليم
  Future<void> _sendAccountantReadyForDeliveryNotification(
    WarehouseReleaseOrderModel releaseOrder,
    String? warehouseManagerName,
  ) async {
    try {
      AppLogger.info('📧 إرسال إشعار جاهزية التسليم للمحاسب: ${releaseOrder.assignedTo}');

      if (releaseOrder.assignedTo != null) {
        await _notificationService.createNotification(
          userId: releaseOrder.assignedTo!,
          title: 'أذن الصرف جاهز للتسليم',
          body: 'أذن الصرف ${releaseOrder.releaseOrderNumber} جاهز للتسليم بواسطة ${warehouseManagerName ?? "مدير المخزن"}',
          type: 'order_status_changed',
          category: 'orders',
          priority: 'normal',
          route: '/accountant/warehouse-release-orders/${releaseOrder.id}',
          referenceId: releaseOrder.id,
          referenceType: 'warehouse_release_order',
          actionData: {
            'release_order_id': releaseOrder.id,
            'release_order_number': releaseOrder.releaseOrderNumber,
            'client_name': releaseOrder.clientName,
            'warehouse_manager': warehouseManagerName,
          },
          metadata: {
            'notification_type': 'warehouse_release_ready_for_delivery',
            'requires_action': false,
          },
        );
      }

      AppLogger.info('✅ تم إرسال إشعار جاهزية التسليم للمحاسب');
    } catch (e) {
      AppLogger.error('❌ خطأ في إرسال إشعار جاهزية التسليم للمحاسب: $e');
    }
  }

  /// إرسال إشعار للمحاسب بإكمال التسليم
  Future<void> _sendAccountantDeliveryCompletionNotification(
    WarehouseReleaseOrderModel releaseOrder,
    String? warehouseManagerName,
  ) async {
    try {
      AppLogger.info('📧 إرسال إشعار إكمال التسليم للمحاسب: ${releaseOrder.assignedTo}');

      if (releaseOrder.assignedTo != null) {
        await _notificationService.createNotification(
          userId: releaseOrder.assignedTo!,
          title: 'تم إكمال التسليم',
          body: 'تم إكمال تسليم أذن الصرف ${releaseOrder.releaseOrderNumber} بواسطة ${warehouseManagerName ?? "مدير المخزن"}',
          type: 'order_status_changed',
          category: 'orders',
          priority: 'high',
          route: '/accountant/warehouse-release-orders/${releaseOrder.id}',
          referenceId: releaseOrder.id,
          referenceType: 'warehouse_release_order',
          actionData: {
            'release_order_id': releaseOrder.id,
            'release_order_number': releaseOrder.releaseOrderNumber,
            'client_name': releaseOrder.clientName,
            'warehouse_manager': warehouseManagerName,
          },
          metadata: {
            'notification_type': 'warehouse_release_delivery_completed',
            'requires_action': false,
          },
        );
      }

      AppLogger.info('✅ تم إرسال إشعار إكمال التسليم للمحاسب');
    } catch (e) {
      AppLogger.error('❌ خطأ في إرسال إشعار إكمال التسليم للمحاسب: $e');
    }
  }

  /// حذف أذن صرف مع تنظيف شامل من جميع المصادر
  Future<bool> deleteReleaseOrder(String releaseOrderId) async {
    try {
      AppLogger.info('🗑️ بدء حذف شامل لأذن الصرف: $releaseOrderId');

      // التحقق من المصادقة
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('المستخدم غير مسجل دخول');
      }

      // استخراج UUID من معرف أذن الصرف
      final extractedUuid = _extractUuidFromReleaseOrderId(releaseOrderId);
      AppLogger.info('🔧 تم استخراج UUID: $extractedUuid من $releaseOrderId');

      bool deletionSuccess = false;

      // 1. حذف من جدول warehouse_release_orders
      try {
        await _supabase
            .from(_releaseOrderItemsTable)
            .delete()
            .eq('release_order_id', extractedUuid);

        await _supabase
            .from(_releaseOrdersTable)
            .delete()
            .eq('id', extractedUuid);

        AppLogger.info('✅ تم حذف أذن الصرف من جدول warehouse_release_orders');
        deletionSuccess = true;
      } catch (e) {
        AppLogger.warning('⚠️ لم يتم العثور على أذن الصرف في warehouse_release_orders: $e');
      }

      // 2. حذف من جدول warehouse_requests (المصدر الأساسي)
      try {
        await _deleteFromWarehouseRequestsTable(extractedUuid);
        AppLogger.info('✅ تم حذف طلب الصرف من جدول warehouse_requests');
        deletionSuccess = true;
      } catch (e) {
        AppLogger.warning('⚠️ لم يتم العثور على طلب الصرف في warehouse_requests: $e');
      }

      // 3. حذف من جدول warehouse_request_items
      try {
        await _deleteWarehouseRequestItems(extractedUuid);
        AppLogger.info('✅ تم حذف عناصر طلب الصرف من warehouse_request_items');
      } catch (e) {
        AppLogger.warning('⚠️ خطأ في حذف عناصر طلب الصرف: $e');
      }

      // 4. تحديث حالة الطلبات المرتبطة لمنع إعادة الإنشاء
      try {
        await _markRelatedOrdersAsProcessed(extractedUuid);
        AppLogger.info('✅ تم تحديث حالة الطلبات المرتبطة');
      } catch (e) {
        AppLogger.warning('⚠️ خطأ في تحديث حالة الطلبات المرتبطة: $e');
      }

      if (!deletionSuccess) {
        AppLogger.warning('⚠️ لم يتم العثور على أذن الصرف في أي من الجداول');
        return false;
      }

      AppLogger.info('✅ تم الحذف الشامل لأذن الصرف بنجاح');
      return true;

    } catch (e) {
      AppLogger.error('❌ خطأ في حذف أذن الصرف: $e');
      return false;
    }
  }

  /// حذف من جدول warehouse_requests
  Future<void> _deleteFromWarehouseRequestsTable(String uuid) async {
    try {
      AppLogger.info('🗑️ حذف طلب الصرف من warehouse_requests: $uuid');

      await _supabase
          .from('warehouse_requests')
          .delete()
          .eq('id', uuid);

      AppLogger.info('✅ تم حذف طلب الصرف من warehouse_requests');
    } catch (e) {
      AppLogger.error('❌ خطأ في حذف طلب الصرف من warehouse_requests: $e');
      rethrow;
    }
  }

  /// حذف عناصر طلب الصرف من warehouse_request_items
  Future<void> _deleteWarehouseRequestItems(String requestId) async {
    try {
      AppLogger.info('🗑️ حذف عناصر طلب الصرف من warehouse_request_items: $requestId');

      await _supabase
          .from('warehouse_request_items')
          .delete()
          .eq('request_id', requestId);

      AppLogger.info('✅ تم حذف عناصر طلب الصرف من warehouse_request_items');
    } catch (e) {
      AppLogger.error('❌ خطأ في حذف عناصر طلب الصرف: $e');
      rethrow;
    }
  }

  /// تحديث حالة الطلبات المرتبطة لمنع إعادة الإنشاء
  Future<void> _markRelatedOrdersAsProcessed(String requestId) async {
    try {
      AppLogger.info('🔄 تحديث حالة الطلبات المرتبطة: $requestId');

      // البحث عن الطلبات المرتبطة وتحديث حالتها
      await _supabase
          .from('warehouse_requests')
          .update({
            'status': 'deleted',
            'metadata': {
              'deleted_at': DateTime.now().toIso8601String(),
              'deleted_by': _supabase.auth.currentUser?.id,
              'deletion_reason': 'حذف أذن الصرف',
            }
          })
          .eq('id', requestId);

      AppLogger.info('✅ تم تحديث حالة الطلبات المرتبطة');
    } catch (e) {
      AppLogger.error('❌ خطأ في تحديث حالة الطلبات المرتبطة: $e');
      rethrow;
    }
  }

  /// مسح جميع أذون الصرف مع تنظيف شامل
  Future<bool> clearAllReleaseOrders() async {
    try {
      AppLogger.info('🗑️ بدء مسح جميع أذون الصرف مع تنظيف شامل');

      // التحقق من المصادقة
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('المستخدم غير مسجل دخول');
      }

      // 1. الحصول على جميع أذون الصرف
      final allReleaseOrders = await getAllReleaseOrders();
      AppLogger.info('📋 تم العثور على ${allReleaseOrders.length} أذن صرف للحذف');

      if (allReleaseOrders.isEmpty) {
        AppLogger.info('ℹ️ لا توجد أذون صرف للحذف');
        return true;
      }

      int successCount = 0;
      int failureCount = 0;

      // 2. حذف كل أذن صرف بشكل فردي
      for (final order in allReleaseOrders) {
        try {
          final deleted = await deleteReleaseOrder(order.id);
          if (deleted) {
            successCount++;
          } else {
            failureCount++;
          }
        } catch (e) {
          AppLogger.error('❌ فشل في حذف أذن الصرف ${order.id}: $e');
          failureCount++;
        }
      }

      // 3. تنظيف إضافي شامل
      await _performAdditionalCleanup();

      // 4. التحقق من اكتمال المسح
      final verificationResult = await _verifyCompleteDeletion();

      AppLogger.info('📊 نتائج المسح: نجح $successCount، فشل $failureCount');
      AppLogger.info('🔍 نتائج التحقق: ${verificationResult['remaining_orders']} أذن متبقي');

      if (failureCount == 0 && verificationResult['is_complete'] == true) {
        AppLogger.info('✅ تم مسح جميع أذون الصرف بنجاح مع التحقق الكامل');
        return true;
      } else {
        AppLogger.warning('⚠️ تم مسح $successCount من ${allReleaseOrders.length} أذن صرف');
        AppLogger.warning('⚠️ تبقى ${verificationResult['remaining_orders']} أذن صرف');
        return successCount > 0;
      }

    } catch (e) {
      AppLogger.error('❌ خطأ في مسح جميع أذون الصرف: $e');
      return false;
    }
  }

  /// تنظيف إضافي شامل لضمان عدم إعادة الإنشاء
  Future<void> _performAdditionalCleanup() async {
    try {
      AppLogger.info('🧹 تنفيذ تنظيف إضافي شامل');

      // 1. تحديث جميع warehouse_requests المرتبطة بفواتير المتجر
      await _supabase
          .from('warehouse_requests')
          .update({
            'status': 'deleted',
            'metadata': {
              'bulk_deleted_at': DateTime.now().toIso8601String(),
              'bulk_deleted_by': _supabase.auth.currentUser?.id,
              'deletion_reason': 'مسح جميع أذون الصرف',
              'prevent_regeneration': true,
            }
          })
          .or('reason.ilike.%صرف فاتورة%,metadata->>isMultiWarehouseDistribution.eq.true');

      AppLogger.info('✅ تم تحديث حالة جميع طلبات الصرف المرتبطة');

      // 2. مسح جميع warehouse_release_order_items المتبقية
      await _supabase
          .from(_releaseOrderItemsTable)
          .delete()
          .neq('id', '00000000-0000-0000-0000-000000000000'); // حذف جميع السجلات

      AppLogger.info('✅ تم مسح جميع عناصر أذون الصرف المتبقية');

      // 3. مسح جميع warehouse_release_orders المتبقية
      await _supabase
          .from(_releaseOrdersTable)
          .delete()
          .neq('id', '00000000-0000-0000-0000-000000000000'); // حذف جميع السجلات

      AppLogger.info('✅ تم مسح جميع أذون الصرف المتبقية');

      // 4. تطبيق آليات منع إعادة الإنشاء
      await _preventRegeneration();

    } catch (e) {
      AppLogger.error('❌ خطأ في التنظيف الإضافي: $e');
      rethrow;
    }
  }

  /// التحقق من اكتمال المسح
  Future<Map<String, dynamic>> _verifyCompleteDeletion() async {
    try {
      AppLogger.info('🔍 التحقق من اكتمال المسح...');

      // 1. عد أذون الصرف المتبقية في warehouse_release_orders
      final releaseOrdersResponse = await _supabase
          .from(_releaseOrdersTable)
          .select('id')
          .count();
      final releaseOrdersCount = releaseOrdersResponse.count ?? 0;

      // 2. عد طلبات الصرف النشطة في warehouse_requests
      final activeRequestsResponse = await _supabase
          .from('warehouse_requests')
          .select('id')
          .or('reason.ilike.%صرف فاتورة%,metadata->>isMultiWarehouseDistribution.eq.true')
          .neq('status', 'deleted')
          .count();
      final activeRequestsCount = activeRequestsResponse.count ?? 0;

      // 3. عد عناصر أذون الصرف المتبقية
      final releaseOrderItemsResponse = await _supabase
          .from(_releaseOrderItemsTable)
          .select('id')
          .count();
      final releaseOrderItemsCount = releaseOrderItemsResponse.count ?? 0;

      final totalRemaining = releaseOrdersCount + activeRequestsCount + releaseOrderItemsCount;
      final isComplete = totalRemaining == 0;

      final result = {
        'is_complete': isComplete,
        'remaining_orders': totalRemaining,
        'release_orders_count': releaseOrdersCount,
        'active_requests_count': activeRequestsCount,
        'release_order_items_count': releaseOrderItemsCount,
        'verification_timestamp': DateTime.now().toIso8601String(),
      };

      AppLogger.info('📊 نتائج التحقق: $result');
      return result;

    } catch (e) {
      AppLogger.error('❌ خطأ في التحقق من اكتمال المسح: $e');
      return {
        'is_complete': false,
        'remaining_orders': -1,
        'error': e.toString(),
      };
    }
  }

  /// منع إعادة إنشاء أذون الصرف من المصادر المحذوفة
  Future<void> _preventRegeneration() async {
    try {
      AppLogger.info('🛡️ تطبيق آليات منع إعادة الإنشاء...');

      // 1. إضافة علامة منع إعادة الإنشاء في metadata
      await _supabase
          .from('warehouse_requests')
          .update({
            'metadata': {
              'prevent_regeneration': true,
              'deletion_timestamp': DateTime.now().toIso8601String(),
              'deletion_source': 'bulk_clear_operation',
            }
          })
          .or('reason.ilike.%صرف فاتورة%,metadata->>isMultiWarehouseDistribution.eq.true');

      AppLogger.info('✅ تم تطبيق آليات منع إعادة الإنشاء');

    } catch (e) {
      AppLogger.error('❌ خطأ في تطبيق آليات منع إعادة الإنشاء: $e');
      rethrow;
    }
  }

  /// تحليل استجابة قاعدة البيانات إلى نموذج أذن الصرف
  WarehouseReleaseOrderModel _parseReleaseOrderFromResponse(Map<String, dynamic> data) {
    final itemsData = data['warehouse_release_order_items'] as List<dynamic>? ?? [];
    final items = itemsData
        .map((itemData) => WarehouseReleaseOrderItem.fromJson(itemData as Map<String, dynamic>))
        .toList();

    return WarehouseReleaseOrderModel.fromJson(data).copyWith(items: items);
  }

  /// إضافة سجل في تاريخ أذن الصرف
  Future<bool> _addReleaseOrderHistory({
    required String releaseOrderId,
    required String action,
    String? oldStatus,
    String? newStatus,
    String? description,
    String? changedBy,
    String? changedByName,
    String? changedByRole,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      AppLogger.info('📝 إضافة سجل تاريخ لأذن الصرف: $releaseOrderId');

      // التحقق من وجود جدول التاريخ
      final tablesExist = await _checkTablesExist();
      if (!tablesExist) {
        AppLogger.warning('⚠️ جدول تاريخ أذون الصرف غير موجود');
        return false;
      }

      // إعداد بيانات السجل
      final historyData = <String, dynamic>{
        'release_order_id': releaseOrderId,
        'action': action,
        'description': description ?? 'تم تنفيذ العملية: $action',
        'created_at': DateTime.now().toIso8601String(),
        'metadata': {
          'source': 'warehouse_release_orders_service',
          ...?metadata,
        },
      };

      // إضافة الحالات إذا كانت متوفرة
      if (oldStatus != null) {
        historyData['old_status'] = oldStatus;
      }
      if (newStatus != null) {
        historyData['new_status'] = newStatus;
      }

      // إضافة معلومات المستخدم إذا كانت متوفرة
      if (changedBy != null) {
        historyData['changed_by'] = changedBy;
      }
      if (changedByName != null) {
        historyData['changed_by_name'] = changedByName;
      }
      if (changedByRole != null) {
        historyData['changed_by_role'] = changedByRole;
      }

      // إدراج السجل في قاعدة البيانات
      await _supabase
          .from('warehouse_release_order_history')
          .insert(historyData);

      AppLogger.info('✅ تم إضافة سجل التاريخ بنجاح');
      return true;

    } catch (e) {
      AppLogger.error('❌ خطأ في إضافة سجل التاريخ: $e');
      return false;
    }
  }

  /// الحصول على إحصائيات أذون الصرف
  Future<Map<String, int>> getReleaseOrdersStats() async {
    try {
      AppLogger.info('📊 تحميل إحصائيات أذون الصرف...');

      final response = await _supabase
          .from(_releaseOrdersTable)
          .select('status');

      final stats = <String, int>{
        'total': 0,
        'pending': 0,
        'approved': 0,
        'completed': 0,
        'rejected': 0,
        'cancelled': 0,
      };

      for (final item in response as List<dynamic>) {
        final status = item['status'] as String;
        stats['total'] = (stats['total'] ?? 0) + 1;
        stats[status] = (stats[status] ?? 0) + 1;
      }

      AppLogger.info('✅ تم تحميل الإحصائيات: $stats');
      return stats;
    } catch (e) {
      AppLogger.error('❌ خطأ في تحميل الإحصائيات: $e');
      return {
        'total': 0,
        'pending': 0,
        'approved': 0,
        'completed': 0,
        'rejected': 0,
        'cancelled': 0,
      };
    }
  }
}
