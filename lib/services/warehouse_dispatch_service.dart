import 'package:smartbiztracker_new/models/warehouse_dispatch_model.dart';
import 'package:smartbiztracker_new/models/multi_warehouse_dispatch_models.dart';
import 'package:smartbiztracker_new/models/global_inventory_models.dart';
import 'package:smartbiztracker_new/services/intelligent_multi_warehouse_dispatch_service.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:smartbiztracker_new/constants/warehouse_dispatch_constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// خدمة طلبات صرف المخزون
/// تدير العمليات المتعلقة بطلبات الصرف والتحديثات
class WarehouseDispatchService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// الحصول على جميع طلبات الصرف
  Future<List<WarehouseDispatchModel>> getDispatchRequests({
    String? status,
    String? warehouseId,
    int limit = 100,
  }) async {
    try {
      AppLogger.info('🔄 جاري تحميل طلبات صرف المخزون...');
      AppLogger.info('📋 فلاتر البحث - الحالة: $status، المخزن: $warehouseId، الحد الأقصى: $limit');

      // بناء الاستعلام
      var query = _supabase
          .from('warehouse_requests')
          .select('''
            *,
            warehouse_request_items (
              *
            )
          ''');

      // تطبيق فلاتر إضافية
      if (status != null && status != 'all') {
        query = query.eq('status', status);
      }

      if (warehouseId != null) {
        query = query.eq('warehouse_id', warehouseId);
      }

      final response = await query
          .order('requested_at', ascending: false)
          .limit(limit);

      AppLogger.info('📊 استجابة قاعدة البيانات: تم استلام ${(response as List).length} طلب');

      // تسجيل تفاصيل البيانات المستلمة للتشخيص
      for (int i = 0; i < (response as List).length && i < 3; i++) {
        final requestData = response[i] as Map<String, dynamic>;
        final itemsData = requestData['warehouse_request_items'];
        AppLogger.info('📦 طلب ${i + 1}: ID=${requestData['id']}, عدد العناصر=${itemsData is List ? itemsData.length : 'null/invalid'}');

        if (itemsData is List && itemsData.isNotEmpty) {
          AppLogger.info('🔍 عينة من العناصر: ${itemsData.take(2).map((item) => 'ID=${item['id']}, ProductID=${item['product_id']}, Quantity=${item['quantity']}')}');
        }
      }

      final requests = (response as List)
          .map((data) {
            try {
              final requestData = data as Map<String, dynamic>;
              final request = WarehouseDispatchModel.fromJson(requestData);

              // تسجيل تفاصيل الطلب المحول
              AppLogger.info('✅ تم تحويل الطلب: ${request.requestNumber} مع ${request.items.length} عنصر');

              return request;
            } catch (e) {
              AppLogger.error('❌ خطأ في تحويل طلب الصرف: $e');
              AppLogger.error('📄 بيانات الطلب المعطلة: $data');
              return null;
            }
          })
          .where((request) => request != null)
          .cast<WarehouseDispatchModel>()
          .toList();

      AppLogger.info('✅ تم تحميل ${requests.length} طلب صرف بنجاح');

      // إحصائيات العناصر
      final totalItems = requests.fold<int>(0, (sum, request) => sum + request.items.length);
      AppLogger.info('📊 إجمالي العناصر في جميع الطلبات: $totalItems');

      return requests;
    } catch (e) {
      AppLogger.error('❌ خطأ في تحميل طلبات الصرف: $e');
      rethrow;
    }
  }

  /// إنشاء طلب صرف من فاتورة (مع دعم التوزيع الذكي متعدد المخازن)
  Future<dynamic> createDispatchFromInvoice({
    required String invoiceId,
    required String customerName,
    required double totalAmount,
    required List<Map<String, dynamic>> items,
    required String requestedBy,
    String? notes,
    String? warehouseId,
  }) async {
    try {
      AppLogger.info('📋 إنشاء طلب صرف من فاتورة: $invoiceId');

      // التحقق من وجود معرف المخزن
      if (warehouseId == null || warehouseId.isEmpty) {
        throw Exception('يجب اختيار المخزن المطلوب الصرف منه لتحويل الفاتورة');
      }

      // التحقق من خيار "جميع المخازن" للتوزيع الذكي
      if (warehouseId == 'ALL_WAREHOUSES') {
        return await _createIntelligentMultiWarehouseDispatch(
          invoiceId: invoiceId,
          customerName: customerName,
          totalAmount: totalAmount,
          items: items,
          requestedBy: requestedBy,
          notes: notes,
        );
      }

      // التحقق من المصادقة
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('المستخدم غير مسجل دخول');
      }

      AppLogger.info('📦 Warehouse ID for invoice conversion: $warehouseId');

      // إنشاء رقم الطلب
      final requestNumber = _generateRequestNumber();

      // إنشاء الطلب الرئيسي
      final requestData = {
        'request_number': requestNumber,
        'type': 'withdrawal',
        'status': 'pending',
        'reason': 'صرف فاتورة: $customerName - $totalAmount جنيه',
        'requested_by': requestedBy,
        'notes': notes,
        'warehouse_id': warehouseId,
      };

      final requestResponse = await _supabase
          .from('warehouse_requests')
          .insert(requestData)
          .select()
          .single();

      final requestId = requestResponse['id'] as String;

      // إضافة عناصر الطلب
      final itemsData = items.map((item) => {
        'request_id': requestId,
        'product_id': item['product_id']?.toString() ?? '',
        'quantity': _parseInt(item['quantity']) ?? 0,
        'notes': '${item['product_name']?.toString() ?? ''} - ${item['unit_price']?.toString() ?? '0'} جنيه',
      }).toList();

      await _supabase
          .from('warehouse_request_items')
          .insert(itemsData);

      // إنشاء نموذج الطلب للإرجاع
      final dispatchItems = items.map((item) => WarehouseDispatchItemModel(
        id: '', // سيتم تعيينه من قاعدة البيانات
        requestId: requestId,
        productId: item['product_id']?.toString() ?? '',
        quantity: _parseInt(item['quantity']) ?? 0,
        notes: '${item['product_name']?.toString() ?? ''} - ${item['unit_price']?.toString() ?? '0'} جنيه',
      )).toList();

      final dispatch = WarehouseDispatchModel(
        id: requestId,
        requestNumber: requestNumber,
        type: 'withdrawal',
        status: 'pending',
        reason: 'صرف فاتورة: $customerName - $totalAmount جنيه',
        requestedBy: requestedBy,
        requestedAt: DateTime.now(),
        notes: notes,
        warehouseId: warehouseId,
        items: dispatchItems,
      );

      AppLogger.info('✅ تم إنشاء طلب الصرف بنجاح: $requestNumber');
      return dispatch;
    } catch (e) {
      AppLogger.error('❌ خطأ في إنشاء طلب الصرف من فاتورة: $e');
      return null;
    }
  }

  /// إنشاء طلبات صرف متعددة باستخدام التوزيع الذكي
  Future<MultiWarehouseDispatchResult> _createIntelligentMultiWarehouseDispatch({
    required String invoiceId,
    required String customerName,
    required double totalAmount,
    required List<Map<String, dynamic>> items,
    required String requestedBy,
    String? notes,
  }) async {
    try {
      AppLogger.info('🤖 بدء التوزيع الذكي متعدد المخازن للفاتورة: $invoiceId');

      // إنشاء خدمة التوزيع الذكي
      final intelligentService = IntelligentMultiWarehouseDispatchService();

      // تنفيذ التوزيع الذكي
      final result = await intelligentService.createIntelligentDispatchFromInvoice(
        invoiceId: invoiceId,
        customerName: customerName,
        totalAmount: totalAmount,
        items: items,
        requestedBy: requestedBy,
        notes: notes,
        strategy: WarehouseSelectionStrategy.balanced,
      );

      AppLogger.info('✅ تم إكمال التوزيع الذكي متعدد المخازن');
      AppLogger.info('📊 النتيجة: ${result.resultText}');

      return result;
    } catch (e) {
      AppLogger.error('❌ خطأ في التوزيع الذكي متعدد المخازن: $e');

      // إرجاع نتيجة فاشلة
      return MultiWarehouseDispatchResult(
        success: false,
        createdDispatches: [],
        distributionPlan: DistributionPlan(
          invoiceId: invoiceId,
          customerName: customerName,
          totalAmount: totalAmount,
          requestedBy: requestedBy,
          warehouseDispatches: [],
          unfulfillableProducts: [],
          partiallyFulfillableProducts: [],
          distributionStrategy: WarehouseSelectionStrategy.balanced,
          createdAt: DateTime.now(),
        ),
        errors: [e.toString()],
        totalDispatchesCreated: 0,
        totalWarehousesInvolved: 0,
        completionPercentage: 0.0,
      );
    }
  }

  /// إنشاء طلب صرف يدوي
  Future<bool> createManualDispatch({
    required String productName,
    required int quantity,
    required String reason,
    required String requestedBy,
    String? notes,
    String? warehouseId,
    double unitPrice = 0.0,
  }) async {
    try {
      AppLogger.info('📋 إنشاء طلب صرف يدوي للمنتج: $productName');

      // التحقق من وجود معرف المخزن
      if (warehouseId == null || warehouseId.isEmpty) {
        throw Exception('يجب اختيار المخزن المطلوب الصرف منه');
      }

      // 🔒 SECURITY FIX: Ensure requestedBy matches authenticated user
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('المستخدم غير مسجل دخول');
      }

      // Verify requestedBy matches current user for security
      if (requestedBy != currentUser.id) {
        AppLogger.warning('⚠️ requestedBy mismatch: provided=$requestedBy, actual=${currentUser.id}');
        // Use the actual authenticated user ID for security
        requestedBy = currentUser.id;
      }

      AppLogger.info('🔒 Verified user: ${currentUser.id} creating dispatch request');
      AppLogger.info('📦 Warehouse ID: $warehouseId');

      // إنشاء رقم الطلب
      final requestNumber = _generateRequestNumber();

      // إنشاء الطلب الرئيسي
      final requestData = {
        'request_number': requestNumber,
        'type': 'withdrawal',
        'status': 'pending',
        'reason': 'طلب يدوي: $productName - $reason',
        'requested_by': requestedBy, // Now guaranteed to be current user ID
        'notes': notes,
        'warehouse_id': warehouseId,
      };

      AppLogger.info('📤 Inserting request data: $requestData');

      final requestResponse = await _supabase
          .from('warehouse_requests')
          .insert(requestData)
          .select()
          .single();

      final requestId = requestResponse['id'] as String;
      AppLogger.info('✅ Request created with ID: $requestId');

      // إضافة عنصر الطلب
      final itemData = {
        'request_id': requestId,
        'product_id': 'manual_${DateTime.now().millisecondsSinceEpoch}', // معرف فريد للطلبات اليدوية
        'quantity': quantity,
        'notes': '$productName - $reason - ${unitPrice.toStringAsFixed(2)} جنيه',
      };

      await _supabase
          .from('warehouse_request_items')
          .insert(itemData);

      AppLogger.info('✅ تم إنشاء طلب الصرف اليدوي بنجاح: $requestNumber');
      return true;
    } catch (e) {
      AppLogger.error('❌ خطأ في إنشاء طلب الصرف اليدوي: $e');
      return false;
    }
  }

  /// تحديث حالة طلب الصرف
  Future<bool> updateDispatchStatus({
    required String requestId,
    required String newStatus,
    required String updatedBy,
    String? notes,
  }) async {
    try {
      AppLogger.info('🔄 تحديث حالة طلب الصرف: $requestId إلى $newStatus');

      // التحقق من صحة الحالة الجديدة
      if (!WarehouseDispatchConstants.isValidStatus(newStatus)) {
        throw Exception('حالة غير صحيحة: $newStatus. الحالات المسموحة: ${WarehouseDispatchConstants.validStatusValues.join(', ')}');
      }

      // الحصول على الطلب الحالي للتحقق من إمكانية التحديث
      final currentRequest = await getDispatchRequestById(requestId);
      if (currentRequest == null) {
        throw Exception('الطلب غير موجود: $requestId');
      }

      // FIXED: التحقق من صحة انتقال الحالة مع تسجيل مفصل
      AppLogger.info('🔍 فحص انتقال الحالة:');
      AppLogger.info('   من: ${currentRequest.status} (${WarehouseDispatchConstants.getStatusDisplayName(currentRequest.status)})');
      AppLogger.info('   إلى: $newStatus (${WarehouseDispatchConstants.getStatusDisplayName(newStatus)})');
      AppLogger.info('   الانتقالات المسموحة من ${currentRequest.status}: ${WarehouseDispatchConstants.getNextPossibleStatuses(currentRequest.status)}');

      if (!WarehouseDispatchConstants.isValidStatusTransition(currentRequest.status, newStatus)) {
        AppLogger.error('❌ انتقال حالة غير صحيح من ${currentRequest.status} إلى $newStatus');
        AppLogger.error('📋 الانتقالات المسموحة: ${WarehouseDispatchConstants.getNextPossibleStatuses(currentRequest.status)}');
        AppLogger.error('🔍 تفاصيل الطلب:');
        AppLogger.error('   رقم الطلب: ${currentRequest.requestNumber}');
        AppLogger.error('   نوع الطلب: ${currentRequest.type}');
        AppLogger.error('   تاريخ الطلب: ${currentRequest.requestedAt}');
        throw Exception('انتقال حالة غير صحيح من ${currentRequest.status} إلى $newStatus');
      }

      AppLogger.info('✅ تم التحقق من صحة انتقال الحالة من ${currentRequest.status} إلى $newStatus');

      final updateData = <String, dynamic>{
        'status': newStatus,
      };

      // إضافة معالج الطلب حسب الحالة الجديدة
      if (newStatus == WarehouseDispatchConstants.statusApproved) {
        updateData['approved_by'] = updatedBy;
        updateData['approved_at'] = DateTime.now().toIso8601String();
      } else if (newStatus == WarehouseDispatchConstants.statusProcessing) {
        // إضافة معلومات بدء المعالجة (يتطلب الموافقة)
        updateData['approved_by'] = updatedBy;
        updateData['approved_at'] = DateTime.now().toIso8601String();
      } else if (newStatus == WarehouseDispatchConstants.statusExecuted) {
        updateData['executed_by'] = updatedBy;
        updateData['executed_at'] = DateTime.now().toIso8601String();
      } else if (newStatus == WarehouseDispatchConstants.statusCompleted) {
        // الحالة المكتملة تتطلب كل من الموافقة والتنفيذ
        updateData['executed_by'] = updatedBy;
        updateData['executed_at'] = DateTime.now().toIso8601String();

        // إذا لم تكن الموافقة موجودة، أضفها
        if (currentRequest.approvedAt == null) {
          updateData['approved_by'] = updatedBy;
          updateData['approved_at'] = DateTime.now().toIso8601String();
        }
      }

      // إضافة الملاحظات إذا كانت متوفرة
      if (notes != null && notes.isNotEmpty) {
        updateData['notes'] = notes;
      }

      AppLogger.info('📤 بيانات التحديث: $updateData');

      await _supabase
          .from('warehouse_requests')
          .update(updateData)
          .eq('id', requestId);

      AppLogger.info('✅ تم تحديث حالة طلب الصرف بنجاح من ${currentRequest.status} إلى $newStatus');
      return true;
    } catch (e) {
      AppLogger.error('❌ خطأ في تحديث حالة طلب الصرف: $e');

      // إضافة تفاصيل إضافية للخطأ إذا كان خطأ قاعدة بيانات
      if (e.toString().contains('23514') || e.toString().contains('check constraint')) {
        AppLogger.error('🚫 خطأ قيد قاعدة البيانات: الحالة $newStatus غير مسموحة في قاعدة البيانات');
        AppLogger.error('📋 الحالات المسموحة: ${WarehouseDispatchConstants.validStatusValues.join(', ')}');
      }

      return false;
    }
  }

  /// حذف طلب صرف
  Future<bool> deleteDispatchRequest(String requestId) async {
    try {
      AppLogger.info('🗑️ حذف طلب الصرف: $requestId');

      // حذف عناصر الطلب أولاً
      await _supabase
          .from('warehouse_request_items')
          .delete()
          .eq('request_id', requestId);

      // حذف الطلب الرئيسي
      await _supabase
          .from('warehouse_requests')
          .delete()
          .eq('id', requestId);

      AppLogger.info('✅ تم حذف طلب الصرف بنجاح');
      return true;
    } catch (e) {
      AppLogger.error('❌ خطأ في حذف طلب الصرف: $e');
      return false;
    }
  }

  /// الحصول على طلب صرف بالمعرف
  Future<WarehouseDispatchModel?> getDispatchRequestById(String requestId) async {
    try {
      AppLogger.info('🔍 البحث عن طلب الصرف: $requestId');

      final response = await _supabase
          .from('warehouse_requests')
          .select('''
            *,
            warehouse_request_items (
              *
            )
          ''')
          .eq('id', requestId)
          .single();

      final request = WarehouseDispatchModel.fromJson(response as Map<String, dynamic>);

      AppLogger.info('✅ تم العثور على طلب الصرف');
      return request;
    } catch (e) {
      AppLogger.error('❌ خطأ في البحث عن طلب الصرف: $e');
      return null;
    }
  }

  /// الحصول على طلب صرف بالمعرف مع ضمان الحصول على أحدث البيانات
  Future<WarehouseDispatchModel?> getDispatchRequestByIdFresh(String requestId, {Duration delay = const Duration(milliseconds: 200)}) async {
    try {
      AppLogger.info('🔍 البحث عن طلب الصرف (fresh): $requestId');

      // إضافة تأخير قصير للسماح لقاعدة البيانات بالتزامن
      if (delay.inMilliseconds > 0) {
        AppLogger.info('⏳ انتظار ${delay.inMilliseconds}ms للتزامن...');
        await Future.delayed(delay);
      }

      final response = await _supabase
          .from('warehouse_requests')
          .select('''
            *,
            warehouse_request_items (
              *
            )
          ''')
          .eq('id', requestId)
          .single();

      final request = WarehouseDispatchModel.fromJson(response as Map<String, dynamic>);

      AppLogger.info('✅ تم العثور على طلب الصرف (fresh) - الحالة: ${request.status}');
      return request;
    } catch (e) {
      AppLogger.error('❌ خطأ في البحث عن طلب الصرف (fresh): $e');
      return null;
    }
  }

  /// الحصول على إحصائيات طلبات الصرف
  Future<Map<String, int>> getDispatchStats({String? warehouseId}) async {
    try {
      AppLogger.info('📊 تحميل إحصائيات طلبات الصرف...');

      var query = _supabase
          .from('warehouse_requests')
          .select('status');

      if (warehouseId != null) {
        query = query.eq('warehouse_id', warehouseId);
      }

      final response = await query;
      
      final requests = response as List;
      
      final stats = {
        'total': requests.length,
        'pending': requests.where((r) => r['status'] == 'pending').length,
        'processing': requests.where((r) => r['status'] == 'processing').length,
        'completed': requests.where((r) => r['status'] == 'completed').length,
        'cancelled': requests.where((r) => r['status'] == 'cancelled').length,
      };
      
      AppLogger.info('✅ تم تحميل إحصائيات طلبات الصرف');
      return stats;
    } catch (e) {
      AppLogger.error('❌ خطأ في تحميل إحصائيات طلبات الصرف: $e');
      return {
        'total': 0,
        'pending': 0,
        'processing': 0,
        'completed': 0,
        'cancelled': 0,
      };
    }
  }

  /// إنشاء رقم طلب فريد
  String _generateRequestNumber() {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch;
    return 'WD${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${timestamp.toString().substring(timestamp.toString().length - 6)}';
  }

  /// تحويل القيمة إلى عدد صحيح
  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// التحقق من وجود الجداول المطلوبة
  Future<bool> checkTablesExist() async {
    try {
      AppLogger.info('🔍 التحقق من وجود جداول طلبات الصرف...');

      // محاولة الاستعلام من الجداول للتحقق من وجودها
      await _supabase
          .from('warehouse_requests')
          .select('id')
          .limit(1);

      await _supabase
          .from('warehouse_request_items')
          .select('id')
          .limit(1);

      AppLogger.info('✅ جداول طلبات الصرف موجودة');
      return true;
    } catch (e) {
      AppLogger.error('❌ جداول طلبات الصرف غير موجودة أو غير متاحة: $e');
      return false;
    }
  }

  /// التحقق من سلامة البيانات لطلب معين
  Future<Map<String, dynamic>> verifyRequestDataIntegrity(String requestId) async {
    try {
      AppLogger.info('🔍 التحقق من سلامة بيانات الطلب: $requestId');

      // الحصول على الطلب الأساسي
      final requestResponse = await _supabase
          .from('warehouse_requests')
          .select('*')
          .eq('id', requestId)
          .single();

      // الحصول على عناصر الطلب
      final itemsResponse = await _supabase
          .from('warehouse_request_items')
          .select('*')
          .eq('request_id', requestId);

      final result = {
        'requestExists': true,
        'requestData': requestResponse,
        'itemsCount': (itemsResponse as List).length,
        'itemsData': itemsResponse,
        'hasItems': (itemsResponse as List).isNotEmpty,
        'integrity': 'good',
      };

      if ((itemsResponse as List).isEmpty) {
        result['integrity'] = 'warning';
        result['issues'] = ['لا توجد عناصر مرتبطة بهذا الطلب'];
      }

      AppLogger.info('📊 نتائج التحقق: ${result['itemsCount']} عنصر، السلامة: ${result['integrity']}');
      return result;
    } catch (e) {
      AppLogger.error('❌ خطأ في التحقق من سلامة البيانات: $e');
      return {
        'requestExists': false,
        'error': e.toString(),
        'integrity': 'error',
      };
    }
  }

  /// إصلاح البيانات المفقودة لطلب معين
  Future<bool> repairRequestData(String requestId) async {
    try {
      AppLogger.info('🔧 محاولة إصلاح بيانات الطلب: $requestId');

      final integrity = await verifyRequestDataIntegrity(requestId);

      if (integrity['integrity'] == 'error') {
        AppLogger.error('❌ لا يمكن إصلاح الطلب - الطلب غير موجود');
        return false;
      }

      if (integrity['integrity'] == 'warning' && !integrity['hasItems']) {
        AppLogger.info('⚠️ الطلب موجود لكن لا توجد عناصر - قد يكون طلب فارغ أو تالف');

        // يمكن إضافة منطق إصلاح هنا إذا لزم الأمر
        // مثل إنشاء عنصر افتراضي أو وضع علامة على الطلب كتالف

        return false;
      }

      AppLogger.info('✅ بيانات الطلب سليمة - لا حاجة للإصلاح');
      return true;
    } catch (e) {
      AppLogger.error('❌ خطأ في إصلاح بيانات الطلب: $e');
      return false;
    }
  }

  /// مسح جميع طلبات الصرف من قاعدة البيانات
  Future<bool> clearAllDispatchRequests() async {
    try {
      AppLogger.info('🗑️ بدء عملية مسح جميع طلبات الصرف...');

      // التحقق من صلاحيات المستخدم أولاً
      await _checkUserPermissions();

      // الحصول على عدد الطلبات قبل الحذف للتأكيد
      final countResponse = await _supabase
          .from('warehouse_requests')
          .select('id')
          .count();

      final requestCount = countResponse.count;
      AppLogger.info('📊 عدد الطلبات المراد حذفها: $requestCount');

      if (requestCount == 0) {
        AppLogger.info('ℹ️ لا توجد طلبات للحذف');
        return true;
      }

      // حذف جميع عناصر الطلبات أولاً
      AppLogger.info('🗑️ حذف عناصر الطلبات...');
      try {
        // استخدام طريقة آمنة للحذف بدون الاعتماد على created_at
        final itemsDeleteResponse = await _supabase
            .from('warehouse_request_items')
            .delete()
            .neq('id', '00000000-0000-0000-0000-000000000000'); // حذف جميع السجلات

        AppLogger.info('📊 استجابة حذف العناصر: $itemsDeleteResponse');
      } catch (itemsError) {
        AppLogger.error('❌ خطأ في حذف عناصر الطلبات: $itemsError');

        // محاولة بديلة باستخدام دالة قاعدة البيانات
        AppLogger.info('🔄 محاولة حذف العناصر باستخدام دالة قاعدة البيانات...');
        try {
          await _clearUsingDatabaseFunction();
          return true;
        } catch (fallbackError) {
          AppLogger.error('❌ فشل في الطريقة البديلة أيضاً: $fallbackError');
          throw Exception('فشل في حذف عناصر الطلبات: $itemsError');
        }
      }

      // حذف جميع طلبات الصرف
      AppLogger.info('🗑️ حذف طلبات الصرف...');
      try {
        // استخدام العمود الموجود requested_at بدلاً من created_at
        final requestsDeleteResponse = await _supabase
            .from('warehouse_requests')
            .delete()
            .gt('requested_at', '1900-01-01T00:00:00Z');

        AppLogger.info('📊 استجابة حذف الطلبات: $requestsDeleteResponse');
      } catch (requestsError) {
        AppLogger.error('❌ خطأ في حذف طلبات الصرف: $requestsError');

        // محاولة بديلة باستخدام دالة قاعدة البيانات الآمنة
        AppLogger.info('🔄 محاولة حذف الطلبات باستخدام الدالة الآمنة...');
        try {
          final functionResult = await _supabase.rpc('clear_all_warehouse_dispatch_requests_safe');
          AppLogger.info('✅ نجح الحذف باستخدام الدالة الآمنة: $functionResult');
          return true;
        } catch (fallbackError) {
          AppLogger.error('❌ فشل في الطريقة البديلة أيضاً: $fallbackError');
          throw Exception('فشل في حذف طلبات الصرف: $requestsError');
        }
      }

      // انتظار قصير للتأكد من اكتمال المعاملة
      await Future.delayed(const Duration(milliseconds: 500));

      // التحقق من نجاح الحذف
      AppLogger.info('🔍 التحقق من نجاح عملية الحذف...');
      final verificationResponse = await _supabase
          .from('warehouse_requests')
          .select('id')
          .count();

      final remainingCount = verificationResponse.count;

      if (remainingCount > 0) {
        AppLogger.warning('⚠️ لا تزال هناك $remainingCount طلبات لم يتم حذفها');
        AppLogger.info('🔄 محاولة استخدام دالة قاعدة البيانات كبديل...');

        // محاولة استخدام دالة قاعدة البيانات كبديل
        return await _clearUsingDatabaseFunction();
      }

      AppLogger.info('✅ تم حذف جميع طلبات الصرف بنجاح ($requestCount طلب)');
      return true;
    } catch (e) {
      AppLogger.error('❌ خطأ في حذف جميع طلبات الصرف: $e');
      AppLogger.info('🔄 محاولة استخدام دالة قاعدة البيانات كبديل...');

      // محاولة استخدام دالة قاعدة البيانات كبديل
      return await _clearUsingDatabaseFunction();
    }
  }

  /// مسح البيانات باستخدام دالة قاعدة البيانات
  Future<bool> _clearUsingDatabaseFunction() async {
    try {
      AppLogger.info('🔧 استخدام دالة قاعدة البيانات لمسح طلبات الصرف...');

      // محاولة استخدام الدالة الآمنة أولاً
      try {
        final safeResponse = await _supabase.rpc('clear_all_warehouse_dispatch_requests_safe');
        AppLogger.info('📊 استجابة الدالة الآمنة: $safeResponse');

        if (safeResponse != null && safeResponse['success'] == true) {
          final deletedRequests = safeResponse['deleted_requests'] as int? ?? 0;
          final deletedItems = safeResponse['deleted_items'] as int? ?? 0;
          AppLogger.info('✅ الدالة الآمنة: تم حذف $deletedRequests طلب و $deletedItems عنصر');
          return true;
        }
      } catch (safeError) {
        AppLogger.warning('⚠️ فشل في استخدام الدالة الآمنة: $safeError');
      }

      // محاولة استخدام الدالة العادية كبديل
      final response = await _supabase.rpc('clear_all_warehouse_dispatch_requests');
      AppLogger.info('📊 استجابة دالة قاعدة البيانات العادية: $response');

      // التحقق من نوع الاستجابة
      if (response != null) {
        // إذا كانت الاستجابة JSON object مباشرة
        if (response is Map<String, dynamic>) {
          final success = response['success'] as bool? ?? false;
          if (success) {
            final deletedRequests = response['deleted_requests'] as int? ?? 0;
            final deletedItems = response['deleted_items'] as int? ?? 0;
            AppLogger.info('✅ دالة قاعدة البيانات: تم حذف $deletedRequests طلب و $deletedItems عنصر');
            return true;
          } else {
            final errorMessage = response['error'] as String?;
            AppLogger.error('❌ دالة قاعدة البيانات فشلت: $errorMessage');
            return false;
          }
        }
        // إذا كانت الاستجابة array
        else if (response is List && response.isNotEmpty) {
          final result = response.first as Map<String, dynamic>;
          final success = result['success'] as bool? ?? false;
          if (success) {
            final deletedRequests = result['deleted_requests'] as int? ?? 0;
            final deletedItems = result['deleted_items'] as int? ?? 0;
            AppLogger.info('✅ دالة قاعدة البيانات: تم حذف $deletedRequests طلب و $deletedItems عنصر');
            return true;
          }
        }

        AppLogger.warning('⚠️ استجابة غير متوقعة من دالة قاعدة البيانات: $response');
        return false;
      } else {
        AppLogger.error('❌ لم تعيد دالة قاعدة البيانات أي استجابة');
        return false;
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في استخدام دالة قاعدة البيانات: $e');
      return false;
    }
  }

  /// الحصول على عدد طلبات الصرف الحالية
  Future<int> getDispatchRequestsCount() async {
    try {
      AppLogger.info('📊 جاري حساب عدد طلبات الصرف...');

      final response = await _supabase
          .from('warehouse_requests')
          .select('id')
          .count();

      final count = response.count;
      AppLogger.info('📊 عدد طلبات الصرف الحالية: $count');

      return count;
    } catch (e) {
      AppLogger.error('❌ خطأ في حساب عدد طلبات الصرف: $e');
      return 0;
    }
  }

  /// التحقق من صلاحيات المستخدم للحذف
  Future<void> _checkUserPermissions() async {
    try {
      AppLogger.info('🔐 التحقق من صلاحيات المستخدم...');

      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('المستخدم غير مسجل دخول');
      }

      AppLogger.info('👤 المستخدم الحالي: ${currentUser.id} (${currentUser.email})');

      // التحقق من دور المستخدم
      final userProfile = await _supabase
          .from('user_profiles')
          .select('role, status')
          .eq('id', currentUser.id)
          .single();

      final userRole = userProfile['role'] as String;
      final userStatus = userProfile['status'] as String;

      AppLogger.info('🎭 دور المستخدم: $userRole، الحالة: $userStatus');

      // التحقق من الصلاحيات
      if (!['admin', 'owner', 'warehouseManager', 'accountant'].contains(userRole)) {
        throw Exception('المستخدم لا يملك صلاحيات حذف طلبات الصرف. الدور الحالي: $userRole');
      }

      if (userStatus != 'approved' && userStatus != 'active') {
        throw Exception('حساب المستخدم غير مفعل. الحالة الحالية: $userStatus');
      }

      AppLogger.info('✅ تم التحقق من صلاحيات المستخدم بنجاح');

    } catch (e) {
      AppLogger.error('❌ خطأ في التحقق من صلاحيات المستخدم: $e');
      rethrow;
    }
  }

  /// اختبار عملية حذف بسيطة للتشخيص
  Future<Map<String, dynamic>> testDeleteOperation() async {
    try {
      AppLogger.info('🧪 اختبار عملية الحذف...');

      final result = <String, dynamic>{
        'canRead': false,
        'canDelete': false,
        'currentUser': null,
        'userRole': null,
        'requestCount': 0,
        'error': null,
      };

      // التحقق من المستخدم الحالي
      final currentUser = _supabase.auth.currentUser;
      result['currentUser'] = currentUser?.email;

      if (currentUser == null) {
        result['error'] = 'لا يوجد مستخدم مسجل دخول';
        return result;
      }

      // التحقق من القراءة
      try {
        final readResponse = await _supabase
            .from('warehouse_requests')
            .select('id')
            .limit(1);
        result['canRead'] = true;
        AppLogger.info('✅ يمكن قراءة البيانات');
      } catch (readError) {
        result['error'] = 'لا يمكن قراءة البيانات: $readError';
        AppLogger.error('❌ لا يمكن قراءة البيانات: $readError');
        return result;
      }

      // عد الطلبات
      final countResponse = await _supabase
          .from('warehouse_requests')
          .select('id')
          .count();
      result['requestCount'] = countResponse.count;

      // اختبار الحذف على طلب وهمي
      try {
        await _supabase
            .from('warehouse_requests')
            .delete()
            .eq('id', '00000000-0000-0000-0000-000000000000'); // معرف وهمي
        result['canDelete'] = true;
        AppLogger.info('✅ يمكن تنفيذ عمليات الحذف');
      } catch (deleteError) {
        result['error'] = 'لا يمكن تنفيذ عمليات الحذف: $deleteError';
        AppLogger.error('❌ لا يمكن تنفيذ عمليات الحذف: $deleteError');
      }

      return result;

    } catch (e) {
      AppLogger.error('❌ خطأ في اختبار عملية الحذف: $e');
      return {
        'error': e.toString(),
        'canRead': false,
        'canDelete': false,
      };
    }
  }

  /// تشخيص شامل لمشاكل RLS والصلاحيات
  Future<Map<String, dynamic>> runComprehensiveDiagnostics() async {
    try {
      AppLogger.info('🔍 بدء التشخيص الشامل لمشاكل RLS...');

      final diagnostics = <String, dynamic>{
        'timestamp': DateTime.now().toIso8601String(),
        'userInfo': {},
        'tableAccess': {},
        'rlsStatus': {},
        'permissions': {},
        'errors': [],
      };

      // 1. معلومات المستخدم
      try {
        final currentUser = _supabase.auth.currentUser;
        diagnostics['userInfo'] = {
          'isAuthenticated': currentUser != null,
          'userId': currentUser?.id,
          'email': currentUser?.email,
        };

        if (currentUser != null) {
          final userProfile = await _supabase
              .from('user_profiles')
              .select('role, status')
              .eq('id', currentUser.id)
              .maybeSingle();

          if (userProfile != null) {
            diagnostics['userInfo']['role'] = userProfile['role'];
            diagnostics['userInfo']['status'] = userProfile['status'];
          }
        }
      } catch (e) {
        diagnostics['errors'].add('خطأ في جلب معلومات المستخدم: $e');
      }

      // 2. اختبار الوصول للجداول
      try {
        final requestsCount = await _supabase
            .from('warehouse_requests')
            .select('id')
            .count();

        final itemsCount = await _supabase
            .from('warehouse_request_items')
            .select('id')
            .count();

        diagnostics['tableAccess'] = {
          'warehouse_requests': {
            'canRead': true,
            'count': requestsCount.count,
          },
          'warehouse_request_items': {
            'canRead': true,
            'count': itemsCount.count,
          },
        };
      } catch (e) {
        diagnostics['errors'].add('خطأ في الوصول للجداول: $e');
        diagnostics['tableAccess']['error'] = e.toString();
      }

      // 3. اختبار دوال قاعدة البيانات
      try {
        final rlsStatus = await _supabase.rpc('check_warehouse_rls_status');
        diagnostics['rlsStatus'] = rlsStatus;
      } catch (e) {
        diagnostics['errors'].add('خطأ في فحص حالة RLS: $e');
      }

      // 4. اختبار صلاحيات المسح
      try {
        final permissionsTest = await _supabase.rpc('test_warehouse_clear_permissions');
        diagnostics['permissions'] = permissionsTest;
      } catch (e) {
        diagnostics['errors'].add('خطأ في اختبار صلاحيات المسح: $e');
      }

      AppLogger.info('✅ تم إكمال التشخيص الشامل');
      AppLogger.info('📊 نتائج التشخيص: $diagnostics');

      return diagnostics;

    } catch (e) {
      AppLogger.error('❌ خطأ في التشخيص الشامل: $e');
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }
}
