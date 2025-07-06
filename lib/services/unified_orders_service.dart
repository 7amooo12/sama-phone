import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:smartbiztracker_new/models/order_model.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// خدمة موحدة لجلب الطلبات من API واحد فقط
/// هذه هي الطريقة الوحيدة المعتمدة لجلب الطلبات في التطبيق
class UnifiedOrdersService {

  UnifiedOrdersService({http.Client? client}) : _client = client ?? http.Client();
  static const String _baseUrl = 'https://stockwarehouse.pythonanywhere.com';
  static const String _ordersEndpoint = '/api/admin/orders';
  static const String _apiKey = 'sm@rtOrder2025AdminKey';
  static const Duration _timeout = Duration(seconds: 30);

  final http.Client _client;

  /// الطريقة الوحيدة لجلب الطلبات
  /// هذه هي الطريقة المعتمدة الوحيدة في التطبيق
  Future<List<OrderModel>> getOrders() async {
    try {
      AppLogger.info('🔄 بدء جلب الطلبات من API الموحد');

      const url = '$_baseUrl$_ordersEndpoint';
      AppLogger.info('📡 الاتصال بـ: $url');

      final response = await _client.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-API-KEY': _apiKey,
        },
      ).timeout(_timeout);

      AppLogger.info('📊 رمز الاستجابة: ${response.statusCode}');

      if (response.statusCode == 200) {
        return _parseOrdersResponse(response.body);
      } else {
        throw _createHttpException(response.statusCode, response.body);
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في جلب الطلبات: $e');
      rethrow;
    }
  }

  /// جلب طلب محدد بالمعرف
  Future<OrderModel?> getOrderById(int orderId) async {
    try {
      AppLogger.info('🔍 جلب تفاصيل الطلب رقم: $orderId');

      final url = '$_baseUrl$_ordersEndpoint$orderId';
      AppLogger.info('📡 الاتصال بـ: $url');

      final response = await _client.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-API-KEY': _apiKey,
        },
      ).timeout(_timeout);

      AppLogger.info('📊 رمز الاستجابة: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // التحقق من نجاح الاستجابة
        if (data['success'] != true) {
          throw Exception('فشل في جلب تفاصيل الطلب: ${data['message'] ?? 'خطأ غير محدد'}');
        }

        if (!(data as Map<String, dynamic>).containsKey('order')) {
          throw Exception('لا توجد مفتاح "order" في الاستجابة');
        }

        final orderData = data['order'] as Map<String, dynamic>;
        final convertedOrder = _convertDetailedApiOrderToModel(orderData);
        return OrderModel.fromJson(convertedOrder);
      } else if (response.statusCode == 404) {
        AppLogger.warning('⚠️ الطلب رقم $orderId غير موجود');
        return null;
      } else {
        throw _createHttpException(response.statusCode, response.body);
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في جلب تفاصيل الطلب: $e');
      rethrow;
    }
  }

  /// تحليل استجابة API وتحويلها إلى قائمة طلبات
  List<OrderModel> _parseOrdersResponse(String responseBody) {
    try {
      AppLogger.info('📄 تحليل استجابة API - حجم البيانات: ${responseBody.length} بايت');

      final data = json.decode(responseBody);

      // التحقق من نجاح الاستجابة
      if (data is! Map<String, dynamic>) {
        throw Exception('تنسيق استجابة غير متوقع: ليس Map');
      }

      if (data['success'] != true) {
        throw Exception('فشل في جلب الطلبات: ${data['message'] ?? 'خطأ غير محدد'}');
      }

      if (!data.containsKey('orders')) {
        throw Exception('لا توجد مفتاح "orders" في الاستجابة');
      }

      final ordersList = data['orders'] as List;
      AppLogger.info('📦 تم العثور على ${ordersList.length} طلب في الاستجابة');

      final orders = <OrderModel>[];
      int successCount = 0;
      int errorCount = 0;

      for (int i = 0; i < ordersList.length; i++) {
        try {
          final orderData = ordersList[i];
          if (orderData is Map<String, dynamic>) {
            // تحويل البيانات إلى تنسيق OrderModel المتوقع
            final convertedOrder = _convertApiOrderToModel(orderData);
            final order = OrderModel.fromJson(convertedOrder);
            orders.add(order);
            successCount++;
          } else {
            AppLogger.warning('⚠️ عنصر الطلب رقم $i ليس Map صحيح');
            errorCount++;
          }
        } catch (e) {
          AppLogger.error('❌ خطأ في تحويل الطلب رقم $i: $e');
          errorCount++;
        }
      }

      AppLogger.info('✅ تم تحويل $successCount طلب بنجاح، فشل في $errorCount طلب');

      return orders;
    } catch (e) {
      AppLogger.error('❌ خطأ في تحليل استجابة الطلبات: $e');
      throw Exception('خطأ في تحليل البيانات: $e');
    }
  }

  /// تحويل بيانات API إلى تنسيق OrderModel (قائمة الطلبات)
  Map<String, dynamic> _convertApiOrderToModel(Map<String, dynamic> apiOrder) {
    return {
      'id': apiOrder['id']?.toString() ?? '',
      'orderNumber': apiOrder['order_number'] ?? '',
      'customerName': apiOrder['customer_name'] ?? '',
      'status': apiOrder['status'] ?? '',
      'createdAt': apiOrder['created_at'] ?? DateTime.now().toIso8601String(),
      'deliveryDate': apiOrder['delivery_date'],
      'completedAt': apiOrder['completed_at'],
      'warehouseName': apiOrder['warehouse_name'] ?? '',
      'itemsCount': apiOrder['items_count'] ?? 0,
      'progress': (apiOrder['progress'] ?? 0.0).toDouble(),
      'totalAmount': 0.0, // سيتم حسابه من العناصر
      'items': [], // سيتم جلبه من تفاصيل الطلب
      'notes': '',
      'trackingToken': '',
    };
  }

  /// تحويل تفاصيل الطلب من API إلى تنسيق OrderModel
  Map<String, dynamic> _convertDetailedApiOrderToModel(Map<String, dynamic> apiOrder) {
    // تحويل العناصر
    final items = <Map<String, dynamic>>[];
    if (apiOrder['items'] != null) {
      final apiItems = apiOrder['items'] as List;
      for (final item in apiItems) {
        if (item is Map<String, dynamic>) {
          items.add({
            'id': item['id']?.toString() ?? '',
            'name': item['name'] ?? item['product_name'] ?? '',
            'quantity': item['quantity_requested'] ?? 0,
            'price': 0.0, // غير متوفر في API
            'imageUrl': item['image_url'] ?? '',
            'progress': (item['progress'] ?? 0.0).toDouble(),
            'description': item['description'] ?? '',
            'quantityCompleted': item['quantity_completed'] ?? 0,
            'actualCompletion': item['actual_completion'],
            'expectedCompletion': item['expected_completion'],
            'startDate': item['start_date'],
            'workerName': item['worker_name'],
          });
        }
      }
    }

    // معلومات العميل
    final customer = apiOrder['customer'] as Map<String, dynamic>? ?? {};

    // معلومات المستودع
    final warehouse = apiOrder['warehouse'] as Map<String, dynamic>? ?? {};

    return {
      'id': apiOrder['id']?.toString() ?? '',
      'orderNumber': apiOrder['order_number'] ?? '',
      'customerName': customer['name'] ?? '',
      'customerPhone': customer['phone'] ?? '',
      'customerEmail': customer['email'] ?? '',
      'customerAddress': customer['address'] ?? '',
      'status': apiOrder['status'] ?? '',
      'createdAt': apiOrder['created_at'] ?? DateTime.now().toIso8601String(),
      'deliveryDate': apiOrder['delivery_date'],
      'completedAt': apiOrder['completed_at'],
      'warehouseName': warehouse['name'] ?? '',
      'warehouseLocation': warehouse['location'] ?? '',
      'itemsCount': items.length,
      'progress': (apiOrder['overall_progress'] ?? 0.0).toDouble(),
      'totalAmount': 0.0, // سيتم حسابه من العناصر
      'items': items,
      'notes': apiOrder['notes'] ?? '',
      'trackingToken': apiOrder['tracking_token'] ?? '',
    };
  }

  /// إنشاء استثناء مناسب حسب رمز HTTP
  Exception _createHttpException(int statusCode, String responseBody) {
    switch (statusCode) {
      case 401:
        return Exception('غير مصرح بالوصول - تحقق من مفتاح API');
      case 403:
        return Exception('ممنوع الوصول - ليس لديك صلاحية');
      case 404:
        return Exception('نقطة النهاية غير موجودة - تحقق من عنوان API');
      case 429:
        return Exception('تم تجاوز حد الطلبات - حاول مرة أخرى لاحقاً');
      case 500:
      case 502:
      case 503:
      case 504:
        return Exception('خطأ في الخادم - حاول مرة أخرى لاحقاً');
      default:
        return Exception('فشل في تحميل الطلبات - رمز الخطأ: $statusCode');
    }
  }

  /// تنظيف الموارد
  void dispose() {
    _client.close();
  }
}
