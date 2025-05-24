import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class OrdersAnalyticsModel {
  final List<Map<String, dynamic>> orders;
  final Map<String, dynamic> stats;
  final Map<String, dynamic> filters;

  OrdersAnalyticsModel({
    required this.orders,
    required this.stats,
    required this.filters,
  });

  factory OrdersAnalyticsModel.fromJson(Map<String, dynamic> json) {
    final orders = List<Map<String, dynamic>>.from(json['orders'].map((x) => Map<String, dynamic>.from(x)));
    final stats = Map<String, dynamic>.from(json['stats']);
    final filters = Map<String, dynamic>.from(json['filters']);
    
    return OrdersAnalyticsModel(
      orders: orders,
      stats: stats,
      filters: filters,
    );
  }
}

class OrderDetailModel {
  final Map<String, dynamic> order;

  OrderDetailModel({required this.order});

  factory OrderDetailModel.fromJson(Map<String, dynamic> json) {
    return OrderDetailModel(
      order: Map<String, dynamic>.from(json['order']),
    );
  }
}

class DamagedItemsModel {
  final List<Map<String, dynamic>> damagedItems;
  final Map<String, dynamic> stats;
  final Map<String, dynamic> filters;

  DamagedItemsModel({
    required this.damagedItems,
    required this.stats,
    required this.filters,
  });

  factory DamagedItemsModel.fromJson(Map<String, dynamic> json) {
    final damagedItems = List<Map<String, dynamic>>.from(
        json['damaged_items'].map((x) => Map<String, dynamic>.from(x)));
    final stats = Map<String, dynamic>.from(json['stats']);
    final filters = Map<String, dynamic>.from(json['filters']);
    
    return DamagedItemsModel(
      damagedItems: damagedItems,
      stats: stats,
      filters: filters,
    );
  }
}

class DamagedItemDetailModel {
  final Map<String, dynamic> damagedItem;

  DamagedItemDetailModel({required this.damagedItem});

  factory DamagedItemDetailModel.fromJson(Map<String, dynamic> json) {
    return DamagedItemDetailModel(
      damagedItem: Map<String, dynamic>.from(json['damaged_item']),
    );
  }
}

class SmartOrderApiService {
  // نمط Singleton
  static final SmartOrderApiService _instance = SmartOrderApiService._internal();
  factory SmartOrderApiService() => _instance;
  SmartOrderApiService._internal();

  // الثوابت
  // تحديث عناوين API مع وجود عناوين بديلة للاختبار
  static const String _primaryBaseUrl = 'https://stockwarehouse.pythonanywhere.com';
  static const String _backupBaseUrl = 'https://stockwarehouse-api.onrender.com';
  static const String _localBaseUrl = 'http://10.0.2.2:5000'; // للاختبار المحلي
  
  // مفتاح API الحالي
  static const String _adminDashboardApiKey = 'sm@rtOrder2025AdminKey';
  
  // استخدام العنوان الرئيسي بشكل افتراضي
  String _baseUrl = _primaryBaseUrl;
  
  // تبديل عنوان API في حالة فشل الاتصال
  void _toggleBaseUrl() {
    if (_baseUrl == _primaryBaseUrl) {
      _baseUrl = _backupBaseUrl;
      debugPrint('⚠️ Switching to backup API URL: $_baseUrl');
    } else if (_baseUrl == _backupBaseUrl) {
      _baseUrl = _localBaseUrl;
      debugPrint('⚠️ Switching to local API URL: $_baseUrl');
    } else {
      _baseUrl = _primaryBaseUrl;
      debugPrint('⚠️ Switching back to primary API URL: $_baseUrl');
    }
  }
  
  // الحصول على بيانات الطلبات للوحة التحكم
  Future<OrdersAnalyticsModel> getOrdersAnalytics({
    String? status,
    int? days,
    String? search,
    int? warehouseId,
  }) async {
    debugPrint('📊 Fetching orders analytics from: $_baseUrl');
    debugPrint('🔍 Params: status=$status, days=$days, search=$search, warehouseId=$warehouseId');
    
    try {
      // بناء عنوان URL مع المعاملات
      final Uri uri = Uri.parse('$_baseUrl/api/admin/orders').replace(
        queryParameters: {
          if (status != null) 'status': status,
          if (days != null) 'days': days.toString(),
          if (search != null) 'search': search,
          if (warehouseId != null) 'warehouse_id': warehouseId.toString(),
        },
      );

      debugPrint('🔗 Request URL: ${uri.toString()}');
      
      final response = await http.get(
        uri,
        headers: {
          'X-API-KEY': _adminDashboardApiKey,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15)); // إضافة مهلة زمنية للطلب

      debugPrint('📡 Response status code: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        debugPrint('✅ Response success: ${data['success']}');
        
        if (data['success'] == true) {
          return OrdersAnalyticsModel.fromJson(data);
        }
        
        // تسجيل رسالة الخطأ
        debugPrint('❌ API error: ${data['message'] ?? 'Unknown error'}');
        throw Exception('API returned success false: ${data['message'] ?? 'Unknown error'}');
      } else if (response.statusCode == 401) {
        debugPrint('🔒 Unauthorized: Invalid API key');
        throw Exception('Unauthorized: Invalid API key');
      } else {
        // محاولة تحليل رسالة الخطأ إن وجدت
        String errorMessage = 'Failed to load orders analytics: ${response.statusCode}';
        try {
          final errorData = json.decode(response.body);
          if (errorData['message'] != null) {
            errorMessage = errorData['message'];
          }
        } catch (e) {
          // تجاهل أخطاء تحليل JSON
        }
        
        debugPrint('❌ HTTP error: $errorMessage');
        
        // محاولة التبديل إلى عنوان API بديل وإعادة المحاولة
        _toggleBaseUrl();
        return getOrdersAnalytics(
          status: status,
          days: days,
          search: search,
          warehouseId: warehouseId,
        );
      }
    } catch (e) {
      debugPrint('❌ Error fetching orders analytics: $e');
      
      // في حالة أخطاء الاتصال، جرب عنوان API بديل
      if (e.toString().contains('SocketException') || 
          e.toString().contains('Connection refused') ||
          e.toString().contains('timed out')) {
        _toggleBaseUrl();
        // إعادة المحاولة مرة واحدة فقط مع العنوان البديل
        return getOrdersAnalytics(
          status: status,
          days: days,
          search: search,
          warehouseId: warehouseId,
        );
      }
      
      rethrow;
    }
  }
  
  // الحصول على تفاصيل طلب محدد
  Future<OrderDetailModel> getOrderDetail(int orderId) async {
    debugPrint('📋 Fetching order details for order ID: $orderId from: $_baseUrl');
    
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/admin/orders/$orderId'),
        headers: {
          'X-API-KEY': _adminDashboardApiKey,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('📡 Response status code: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        debugPrint('✅ Response success: ${data['success']}');
        
        if (data['success'] == true) {
          return OrderDetailModel.fromJson(data);
        }
        
        debugPrint('❌ API error: ${data['message'] ?? 'Unknown error'}');
        throw Exception('API returned success false: ${data['message'] ?? 'Unknown error'}');
      } else if (response.statusCode == 401) {
        debugPrint('🔒 Unauthorized: Invalid API key');
        throw Exception('Unauthorized: Invalid API key');
      } else if (response.statusCode == 404) {
        debugPrint('🔍 Order not found: $orderId');
        throw Exception('Order not found');
      } else {
        String errorMessage = 'Failed to load order details: ${response.statusCode}';
        try {
          final errorData = json.decode(response.body);
          if (errorData['message'] != null) {
            errorMessage = errorData['message'];
          }
        } catch (e) {
          // تجاهل أخطاء تحليل JSON
        }
        
        debugPrint('❌ HTTP error: $errorMessage');
        
        // محاولة التبديل إلى عنوان API بديل وإعادة المحاولة
        _toggleBaseUrl();
        return getOrderDetail(orderId);
      }
    } catch (e) {
      debugPrint('❌ Error fetching order details: $e');
      
      // في حالة أخطاء الاتصال، جرب عنوان API بديل
      if (e.toString().contains('SocketException') || 
          e.toString().contains('Connection refused') ||
          e.toString().contains('timed out')) {
        _toggleBaseUrl();
        // إعادة المحاولة مرة واحدة فقط مع العنوان البديل
        return getOrderDetail(orderId);
      }
      
      rethrow;
    }
  }
  
  // الحصول على بيانات الهوالك (العناصر التالفة) للوحة التحكم
  Future<DamagedItemsModel> getDamagedItems({
    int? days,
    String? search,
    int? warehouseId,
  }) async {
    debugPrint('🗑️ Fetching damaged items from: $_baseUrl');
    debugPrint('🔍 Params: days=$days, search=$search, warehouseId=$warehouseId');
    
    try {
      // بناء عنوان URL مع المعاملات
      final Uri uri = Uri.parse('$_baseUrl/api/admin/damaged').replace(
        queryParameters: {
          if (days != null) 'days': days.toString(),
          if (search != null) 'search': search,
          if (warehouseId != null) 'warehouse_id': warehouseId.toString(),
        },
      );

      debugPrint('🔗 Request URL: ${uri.toString()}');
      
      final response = await http.get(
        uri,
        headers: {
          'X-API-KEY': _adminDashboardApiKey,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('📡 Response status code: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        debugPrint('✅ Response success: ${data['success']}');
        
        if (data['success'] == true) {
          return DamagedItemsModel.fromJson(data);
        }
        
        debugPrint('❌ API error: ${data['message'] ?? 'Unknown error'}');
        throw Exception('API returned success false: ${data['message'] ?? 'Unknown error'}');
      } else if (response.statusCode == 401) {
        debugPrint('🔒 Unauthorized: Invalid API key');
        throw Exception('Unauthorized: Invalid API key');
      } else {
        String errorMessage = 'Failed to load damaged items: ${response.statusCode}';
        try {
          final errorData = json.decode(response.body);
          if (errorData['message'] != null) {
            errorMessage = errorData['message'];
          }
        } catch (e) {
          // تجاهل أخطاء تحليل JSON
        }
        
        debugPrint('❌ HTTP error: $errorMessage');
        
        // محاولة التبديل إلى عنوان API بديل وإعادة المحاولة
        _toggleBaseUrl();
        return getDamagedItems(
          days: days,
          search: search,
          warehouseId: warehouseId,
        );
      }
    } catch (e) {
      debugPrint('❌ Error fetching damaged items: $e');
      
      // في حالة أخطاء الاتصال، جرب عنوان API بديل
      if (e.toString().contains('SocketException') || 
          e.toString().contains('Connection refused') ||
          e.toString().contains('timed out')) {
        _toggleBaseUrl();
        // إعادة المحاولة مرة واحدة فقط مع العنوان البديل
        return getDamagedItems(
          days: days,
          search: search,
          warehouseId: warehouseId,
        );
      }
      
      rethrow;
    }
  }
  
  // الحصول على تفاصيل عنصر تالف محدد
  Future<DamagedItemDetailModel> getDamagedItemDetail(int damagedItemId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/admin/damaged/$damagedItemId'),
        headers: {
          'X-API-KEY': _adminDashboardApiKey,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return DamagedItemDetailModel.fromJson(data);
        }
        throw Exception('API returned success false: ${data['message'] ?? 'Unknown error'}');
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Invalid API key');
      } else if (response.statusCode == 404) {
        throw Exception('Damaged item not found');
      } else {
        throw Exception('Failed to load damaged item details: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching damaged item details: $e');
      rethrow;
    }
  }
  
  // دالة مساعدة للتحقق من صحة الرد
  bool _isValidResponse(http.Response response) {
    return response.statusCode == 200 && 
           json.decode(response.body)['success'] == true;
  }
} 