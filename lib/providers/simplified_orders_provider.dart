import 'package:flutter/foundation.dart';
import '../models/order_model.dart';
import '../services/unified_orders_service.dart';
import '../utils/app_logger.dart';

/// مزود الطلبات المبسط - يستخدم خدمة واحدة فقط لجلب الطلبات
/// هذا هو المزود الوحيد المعتمد لجلب الطلبات في التطبيق
class SimplifiedOrdersProvider with ChangeNotifier {
  final UnifiedOrdersService _ordersService = UnifiedOrdersService();

  List<OrderModel> _orders = [];
  bool _isLoading = false;
  String? _error;
  DateTime? _lastFetchTime;

  /// الحصول على قائمة الطلبات
  List<OrderModel> get orders => _orders;

  /// حالة التحميل
  bool get isLoading => _isLoading;

  /// رسالة الخطأ إن وجدت
  String? get error => _error;

  /// وقت آخر جلب للطلبات
  DateTime? get lastFetchTime => _lastFetchTime;

  /// عدد الطلبات
  int get ordersCount => _orders.length;

  /// تحديث حالة التحميل
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// تحديث رسالة الخطأ
  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  /// الطريقة الوحيدة لجلب الطلبات
  /// هذه هي الطريقة المعتمدة الوحيدة في التطبيق
  Future<List<OrderModel>> loadOrders({bool forceRefresh = false}) async {
    try {
      // إذا كانت الطلبات موجودة وليس مطلوب تحديث قسري، أرجعها
      if (_orders.isNotEmpty && !forceRefresh) {
        AppLogger.info('📦 استخدام الطلبات المخزنة (${_orders.length} طلب)');
        return _orders;
      }

      AppLogger.info('🔄 بدء تحميل الطلبات...');

      _setLoading(true);
      _setError(null);

      // جلب الطلبات من الخدمة الموحدة
      final orders = await _ordersService.getOrders();

      // تحديث البيانات
      _orders = orders;
      _lastFetchTime = DateTime.now();

      AppLogger.info('✅ تم تحميل ${orders.length} طلب بنجاح');

      _setLoading(false);
      notifyListeners();

      return orders;
    } catch (e) {
      AppLogger.error('❌ فشل في تحميل الطلبات: $e');

      _setLoading(false);
      _setError(e.toString());

      // إرجاع الطلبات المخزنة إذا كانت موجودة
      return _orders;
    }
  }

  /// جلب طلب محدد بالمعرف مع التفاصيل الكاملة
  Future<OrderModel?> getOrderById(int orderId) async {
    try {
      // البحث في الطلبات المحلية أولاً
      final localOrder = _orders.where((order) => int.parse(order.id) == orderId).firstOrNull;
      if (localOrder != null && localOrder.items.isNotEmpty) {
        AppLogger.info('📦 تم العثور على الطلب محلياً مع التفاصيل: $orderId');
        return localOrder;
      }

      // جلب من الخدمة إذا لم يوجد محلياً أو لم يحتوي على تفاصيل
      AppLogger.info('🔍 جلب الطلب مع التفاصيل من الخادم: $orderId');
      final detailedOrder = await _ordersService.getOrderById(orderId);

      if (detailedOrder != null) {
        // تحديث الطلب في القائمة المحلية
        final index = _orders.indexWhere((order) => int.parse(order.id) == orderId);
        if (index != -1) {
          _orders[index] = detailedOrder;
          notifyListeners();
        }
      }

      return detailedOrder;
    } catch (e) {
      AppLogger.error('❌ فشل في جلب الطلب $orderId: $e');
      return null;
    }
  }

  /// البحث في الطلبات المحلية
  List<OrderModel> searchOrders(String query) {
    if (query.isEmpty) {
      return _orders;
    }

    final lowerQuery = query.toLowerCase();
    return _orders.where((order) {
      return order.orderNumber.toLowerCase().contains(lowerQuery) ||
             order.customerName.toLowerCase().contains(lowerQuery) ||
             order.status.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// فلترة الطلبات حسب الحالة
  List<OrderModel> filterByStatus(String? status) {
    if (status == null || status.isEmpty || status == 'all') {
      return _orders;
    }

    return _orders.where((order) {
      return order.status.toLowerCase() == status.toLowerCase();
    }).toList();
  }

  /// فلترة الطلبات حسب التاريخ
  List<OrderModel> filterByDateRange(DateTime? startDate, DateTime? endDate) {
    if (startDate == null && endDate == null) {
      return _orders;
    }

    return _orders.where((order) {
      final orderDate = order.createdAt;

      if (startDate != null && orderDate.isBefore(startDate)) {
        return false;
      }

      if (endDate != null && orderDate.isAfter(endDate.add(const Duration(days: 1)))) {
        return false;
      }

      return true;
    }).toList();
  }

  /// الحصول على الحالات المتاحة
  List<String> getAvailableStatuses() {
    final statuses = _orders.map((order) => order.status).toSet().toList();
    statuses.sort();
    return ['all', ...statuses];
  }

  /// الحصول على إحصائيات الطلبات
  Map<String, int> getOrdersStatistics() {
    final stats = <String, int>{};

    for (final order in _orders) {
      stats[order.status] = (stats[order.status] ?? 0) + 1;
    }

    return stats;
  }

  /// مسح رسالة الخطأ
  void clearError() {
    _setError(null);
  }

  /// مسح جميع البيانات
  void clearData() {
    _orders.clear();
    _lastFetchTime = null;
    _setError(null);
    notifyListeners();
  }

  /// إعادة المحاولة في حالة الخطأ
  Future<List<OrderModel>> retry() async {
    return loadOrders(forceRefresh: true);
  }

  /// تنظيف الموارد
  @override
  void dispose() {
    _ordersService.dispose();
    super.dispose();
  }
}
