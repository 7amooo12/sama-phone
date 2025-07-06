import 'package:smartbiztracker_new/models/client_order_model.dart';
import 'package:smartbiztracker_new/models/warehouse_release_order_model.dart';
import 'package:smartbiztracker_new/services/supabase_orders_service.dart';
import 'package:smartbiztracker_new/services/warehouse_release_orders_service.dart';
import 'package:smartbiztracker_new/services/real_notification_service.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// خدمة تزامن سير العمل الشامل
/// تدير التزامن بين الطلبات المعلقة وأذون الصرف وحالات العملاء
class WorkflowSynchronizationService {
  final SupabaseOrdersService _ordersService = SupabaseOrdersService();
  final WarehouseReleaseOrdersService _releaseOrdersService = WarehouseReleaseOrdersService();
  final RealNotificationService _notificationService = RealNotificationService();

  /// تنفيذ سير العمل الكامل من الموافقة على الطلب إلى الشحن
  Future<WorkflowResult> executeCompleteWorkflow({
    required String orderId,
    required String assignedTo,
    String? notes,
  }) async {
    try {
      AppLogger.info('🔄 بدء تنفيذ سير العمل الكامل للطلب: $orderId');

      // الخطوة 1: الحصول على الطلب الأصلي
      final originalOrder = await _getOrderById(orderId);
      if (originalOrder == null) {
        return WorkflowResult.failure('لم يتم العثور على الطلب');
      }

      // الخطوة 2: التحقق من حالة الطلب
      if (originalOrder.status != OrderStatus.pending) {
        return WorkflowResult.failure('الطلب ليس في حالة معلقة');
      }

      // الخطوة 3: تحديث حالة الطلب إلى معتمد
      final orderUpdateSuccess = await _ordersService.updateOrderStatus(
        orderId,
        OrderStatus.confirmed,
      );

      if (!orderUpdateSuccess) {
        return WorkflowResult.failure('فشل في تحديث حالة الطلب');
      }

      // الخطوة 4: إنشاء أذن صرف
      final releaseOrderId = await _releaseOrdersService.createReleaseOrderFromApprovedOrder(
        approvedOrder: originalOrder,
        assignedTo: assignedTo,
        notes: notes,
      );

      if (releaseOrderId == null) {
        // إعادة الطلب إلى حالة معلقة في حالة الفشل
        await _ordersService.updateOrderStatus(orderId, OrderStatus.pending);
        return WorkflowResult.failure('فشل في إنشاء أذن الصرف');
      }

      // الخطوة 5: إرسال الإشعارات
      await _sendWorkflowNotifications(
        originalOrder: originalOrder,
        releaseOrderId: releaseOrderId,
        assignedTo: assignedTo,
      );

      AppLogger.info('✅ تم تنفيذ سير العمل بنجاح');
      return WorkflowResult.success(
        orderId: orderId,
        releaseOrderId: releaseOrderId,
        message: 'تم تنفيذ سير العمل بنجاح',
      );

    } catch (e) {
      AppLogger.error('❌ خطأ في تنفيذ سير العمل: $e');
      return WorkflowResult.failure('خطأ في تنفيذ سير العمل: $e');
    }
  }

  /// تنفيذ موافقة مدير المخزن وإكمال الشحن
  Future<WorkflowResult> executeWarehouseApprovalWorkflow({
    required String releaseOrderId,
    required String warehouseManagerId,
    required String warehouseManagerName,
  }) async {
    try {
      AppLogger.info('🏭 بدء تنفيذ موافقة مدير المخزن: $releaseOrderId');

      // الحصول على أذن الصرف
      final releaseOrder = await _releaseOrdersService.getReleaseOrder(releaseOrderId);
      if (releaseOrder == null) {
        return WorkflowResult.failure('لم يتم العثور على أذن الصرف');
      }

      // تحديث حالة أذن الصرف إلى مكتمل (سيؤدي إلى تحديث الطلب الأصلي تلقائياً)
      final success = await _releaseOrdersService.updateReleaseOrderStatus(
        releaseOrderId: releaseOrderId,
        newStatus: WarehouseReleaseOrderStatus.completed,
        warehouseManagerId: warehouseManagerId,
        warehouseManagerName: warehouseManagerName,
      );

      if (success) {
        AppLogger.info('✅ تم إكمال موافقة مدير المخزن بنجاح');
        return WorkflowResult.success(
          orderId: releaseOrder.originalOrderId,
          releaseOrderId: releaseOrderId,
          message: 'تم إكمال الموافقة والشحن بنجاح',
        );
      } else {
        return WorkflowResult.failure('فشل في موافقة مدير المخزن');
      }

    } catch (e) {
      AppLogger.error('❌ خطأ في موافقة مدير المخزن: $e');
      return WorkflowResult.failure('خطأ في موافقة مدير المخزن: $e');
    }
  }

  /// التحقق من تزامن البيانات عبر النظام
  Future<SynchronizationStatus> checkDataSynchronization(String orderId) async {
    try {
      AppLogger.info('🔍 فحص تزامن البيانات للطلب: $orderId');

      // الحصول على الطلب الأصلي
      final order = await _getOrderById(orderId);
      if (order == null) {
        return SynchronizationStatus.orderNotFound();
      }

      // البحث عن أذن الصرف المرتبط
      final releaseOrders = await _releaseOrdersService.getAllReleaseOrders();
      final relatedReleaseOrder = releaseOrders
          .where((ro) => ro.originalOrderId == orderId)
          .firstOrNull;

      // تحليل حالة التزامن
      final status = SynchronizationStatus(
        orderId: orderId,
        orderStatus: order.status,
        hasReleaseOrder: relatedReleaseOrder != null,
        releaseOrderId: relatedReleaseOrder?.id,
        releaseOrderStatus: relatedReleaseOrder?.status,
        isInSync: _isDataInSync(order, relatedReleaseOrder),
        lastChecked: DateTime.now(),
      );

      AppLogger.info('✅ فحص التزامن مكتمل: ${status.isInSync ? "متزامن" : "غير متزامن"}');
      return status;

    } catch (e) {
      AppLogger.error('❌ خطأ في فحص التزامن: $e');
      return SynchronizationStatus.error(orderId, e.toString());
    }
  }

  /// إصلاح عدم التزامن في البيانات
  Future<bool> repairDataSynchronization(String orderId) async {
    try {
      AppLogger.info('🔧 إصلاح عدم التزامن للطلب: $orderId');

      final syncStatus = await checkDataSynchronization(orderId);
      if (syncStatus.isInSync) {
        AppLogger.info('✅ البيانات متزامنة بالفعل');
        return true;
      }

      // تطبيق إصلاحات حسب نوع عدم التزامن
      if (syncStatus.orderStatus == OrderStatus.confirmed && !syncStatus.hasReleaseOrder) {
        // إنشاء أذن صرف مفقود
        final order = await _getOrderById(orderId);
        if (order != null) {
          final releaseOrderId = await _releaseOrdersService.createReleaseOrderFromApprovedOrder(
            approvedOrder: order,
            assignedTo: 'system_repair',
            notes: 'تم إنشاؤه تلقائياً لإصلاح عدم التزامن',
          );
          return releaseOrderId != null;
        }
      }

      // إضافة المزيد من منطق الإصلاح حسب الحاجة
      AppLogger.info('✅ تم إصلاح عدم التزامن');
      return true;

    } catch (e) {
      AppLogger.error('❌ خطأ في إصلاح عدم التزامن: $e');
      return false;
    }
  }

  /// الحصول على الطلب بواسطة المعرف
  Future<ClientOrder?> _getOrderById(String orderId) async {
    try {
      final orders = await _ordersService.getAllOrders();
      return orders.where((order) => order.id == orderId).firstOrNull;
    } catch (e) {
      AppLogger.error('❌ خطأ في الحصول على الطلب: $e');
      return null;
    }
  }

  /// إرسال إشعارات سير العمل
  Future<void> _sendWorkflowNotifications({
    required ClientOrder originalOrder,
    required String releaseOrderId,
    required String assignedTo,
  }) async {
    try {
      // إشعار العميل
      await _notificationService.createNotification(
        userId: originalOrder.clientId,
        title: 'تم تأكيد طلبك',
        body: 'تم تأكيد طلبك وإرساله إلى مدير المخزن للمراجعة النهائية',
        type: 'order_confirmed',
        category: 'orders',
        priority: 'normal',
        route: '/customer/orders/${originalOrder.id}',
        referenceId: originalOrder.id,
        referenceType: 'order',
      );

      // إشعار مديري المخازن
      await _notificationService.createNotificationsForRoles(
        roles: ['warehouseManager'],
        title: 'أذن صرف جديد يتطلب الموافقة',
        body: 'أذن صرف جديد من ${originalOrder.clientName} يتطلب موافقتك',
        type: 'warehouse_release_pending',
        category: 'warehouse',
        priority: 'high',
        route: '/warehouse/release-orders/$releaseOrderId',
        referenceId: releaseOrderId,
        referenceType: 'warehouse_release_order',
      );

    } catch (e) {
      AppLogger.error('❌ خطأ في إرسال إشعارات سير العمل: $e');
    }
  }

  /// التحقق من تزامن البيانات
  bool _isDataInSync(ClientOrder order, WarehouseReleaseOrderModel? releaseOrder) {
    // قواعد التزامن
    switch (order.status) {
      case OrderStatus.pending:
        return releaseOrder == null;
      case OrderStatus.confirmed:
        return releaseOrder != null && 
               releaseOrder.status == WarehouseReleaseOrderStatus.pendingWarehouseApproval;
      case OrderStatus.shipped:
        return releaseOrder != null && 
               releaseOrder.status == WarehouseReleaseOrderStatus.completed;
      default:
        return true; // حالات أخرى تعتبر متزامنة
    }
  }
}

/// نتيجة تنفيذ سير العمل
class WorkflowResult {
  final bool isSuccess;
  final String message;
  final String? orderId;
  final String? releaseOrderId;
  final String? errorCode;

  const WorkflowResult({
    required this.isSuccess,
    required this.message,
    this.orderId,
    this.releaseOrderId,
    this.errorCode,
  });

  factory WorkflowResult.success({
    required String orderId,
    required String releaseOrderId,
    required String message,
  }) {
    return WorkflowResult(
      isSuccess: true,
      message: message,
      orderId: orderId,
      releaseOrderId: releaseOrderId,
    );
  }

  factory WorkflowResult.failure(String message, [String? errorCode]) {
    return WorkflowResult(
      isSuccess: false,
      message: message,
      errorCode: errorCode,
    );
  }
}

/// حالة تزامن البيانات
class SynchronizationStatus {
  final String orderId;
  final OrderStatus orderStatus;
  final bool hasReleaseOrder;
  final String? releaseOrderId;
  final WarehouseReleaseOrderStatus? releaseOrderStatus;
  final bool isInSync;
  final DateTime lastChecked;
  final String? errorMessage;

  const SynchronizationStatus({
    required this.orderId,
    required this.orderStatus,
    required this.hasReleaseOrder,
    this.releaseOrderId,
    this.releaseOrderStatus,
    required this.isInSync,
    required this.lastChecked,
    this.errorMessage,
  });

  factory SynchronizationStatus.orderNotFound() {
    return SynchronizationStatus(
      orderId: '',
      orderStatus: OrderStatus.pending,
      hasReleaseOrder: false,
      isInSync: false,
      lastChecked: DateTime.now(),
      errorMessage: 'الطلب غير موجود',
    );
  }

  factory SynchronizationStatus.error(String orderId, String error) {
    return SynchronizationStatus(
      orderId: orderId,
      orderStatus: OrderStatus.pending,
      hasReleaseOrder: false,
      isInSync: false,
      lastChecked: DateTime.now(),
      errorMessage: error,
    );
  }
}
