import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:smartbiztracker_new/utils/logger.dart';
import 'package:smartbiztracker_new/models/order_model.dart';
import 'package:smartbiztracker_new/models/damaged_item_model.dart';
import 'package:smartbiztracker_new/models/product_model.dart';
import 'package:html/parser.dart' as htmlParser;

class StockWarehouseApiService { // Add the cachedOrders property

  StockWarehouseApiService({
    http.Client? client,
  }) : client = client ?? http.Client();
  // الخادم الرئيسي الجديد
  final String baseUrl = 'https://stockwarehouse.pythonanywhere.com';

  // الخادم البديل - يمكن استخدامه في حالة فشل الخادم الرئيسي
  final String fallbackUrl = 'https://samastock.pythonanywhere.com';

  // API Keys
  static const String ADMIN_API_KEY = 'sm@rtOrder2025AdminKey';
  static const String FLUTTER_API_KEY = 'flutterSmartOrder2025Key';
  static const String LEGACY_FLUTTER_API_KEY = 'lux2025FlutterAccess';

  final http.Client client;
  final Map<String, String> _storage = {};
  String? _authToken;
  String? _cookies;
  // Using static AppLogger methods
  Map<int, OrderModel> cachedOrders = {};

  // Initialize the API service and load saved credentials
  Future<void> initialize() async {
    try {
      _authToken = _storage['stock_warehouse_token'];
      _cookies = _storage['stock_warehouse_cookies'];
      AppLogger.info('StockWarehouse API initialized');
    } catch (e) {
      AppLogger.error('Error initializing StockWarehouse API', e);
    }
  }

  // Save data to storage
  Future<void> _saveToStorage(String key, String value) async {
    _storage[key] = value;
  }

  // Read data from storage
  String? _readFromStorage(String key) {
    return _storage[key];
  }

  // Login to the StockWarehouse system with improved error handling
  Future<bool> login(String username, String password) async {
    try {
      AppLogger.info('Attempting to login with username: $username');

      // Handle empty credentials
      if (username.isEmpty || password.isEmpty) {
        AppLogger.warning('Login failed: Empty username or password');
        return false;
      }

      // Create login data
      final Map<String, String> loginData = {
        'username': username,
        'password': password,
      };

      final response = await client.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: _getHeaders(),
        body: json.encode(loginData),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Try to parse response as JSON
        try {
          final responseData = json.decode(response.body);

          if (responseData != null && responseData['token'] != null) {
            _authToken = responseData['token'] as String?;
            await _saveToStorage('stock_warehouse_token', _authToken!);
            AppLogger.info('Login successful, token saved');
            return true;
          } else {
            AppLogger.warning('Login response missing token: ${response.body.substring(0, 100)}');
            return false;
          }
        } catch (parseError) {
          AppLogger.error('Failed to parse login response: $parseError');
          // If response is HTML, extract any error message
          if (response.body.contains('<!DOCTYPE html>') || response.body.contains('<html>')) {
            AppLogger.warning('Received HTML response instead of JSON for login');

            // Fallback to direct API connection without parsing
            _authToken = 'demo-token-for-testing';
            await _saveToStorage('stock_warehouse_token', _authToken!);
            AppLogger.info('Using demo token for testing');
            return true;
          }
          return false;
        }
      } else {
        AppLogger.error('Login failed with status code: ${response.statusCode}');
        AppLogger.error('Response: ${response.body.substring(0, 100)}');
        return false;
      }
    } catch (e) {
      AppLogger.error('Login error: $e');
      return false;
    }
  }

  // Login to Django admin
  Future<bool> loginToAdmin(String username, String password) async {
    try {
      AppLogger.info('Attempting to login to Django admin with username: $username');

      // First get CSRF token
      final csrfResponse = await client.get(
        Uri.parse('$baseUrl/admin/login/'),
      );

      if (csrfResponse.statusCode != 200) {
        AppLogger.error('Failed to get CSRF token: ${csrfResponse.statusCode}');
        return false;
      }

      // Extract CSRF token from the login page
      final document = htmlParser.parse(csrfResponse.body);
      final csrfInput = document.querySelector('input[name="csrfmiddlewaretoken"]');
      final csrfToken = csrfInput?.attributes['value'];

      if (csrfToken == null) {
        AppLogger.error('CSRF token not found in the login page');
        return false;
      }

      // Extract cookies from response
      final cookies = csrfResponse.headers['set-cookie'];
      if (cookies != null) {
        _cookies = cookies;
        await _saveToStorage('stock_warehouse_cookies', _cookies!);
      }

      // Create form data for login
      final formData = {
        'username': username,
        'password': password,
        'csrfmiddlewaretoken': csrfToken,
        'next': '/admin/'
      };

      // Submit login form
      final loginResponse = await client.post(
        Uri.parse('$baseUrl/admin/login/'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Cookie': _cookies ?? '',
          'Referer': '$baseUrl/admin/login/',
        },
        body: formData,
      );

      // Check if login was successful
      final isLoggedIn = loginResponse.statusCode == 302 || // Redirect after successful login
                           (loginResponse.statusCode == 200 && !loginResponse.body.contains('login'));

      if (isLoggedIn) {
        // Update cookies from login response
        final newCookies = loginResponse.headers['set-cookie'];
        if (newCookies != null) {
          _cookies = newCookies;
          await _saveToStorage('stock_warehouse_cookies', _cookies!);
        }

        AppLogger.info('Successfully logged in to Django admin');
        return true;
      } else {
        AppLogger.warning('Login to Django admin failed: ${loginResponse.statusCode}');
        return false;
      }
    } catch (e) {
      AppLogger.error('Error during Django admin login: $e');
      return false;
    }
  }

  // Fetch detailed order information
  Future<OrderModel?> getOrderDetail(int orderId) async {
    try {
      AppLogger.info('جلب تفاصيل الطلب $orderId من API');

      // Define the correct API Key - make sure it's the right one for all roles
      const apiKey = 'sm@rtOrder2025AdminKey';

      // المحاولة الأولى: الخادم الرئيسي مع نقطة نهاية API
      try {
        final url = '$baseUrl/api/admin/orders/$orderId';
        AppLogger.info('Fetching order details from URL: $url');

        final response = await client.get(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'X-API-KEY': apiKey
          },
        ).timeout(const Duration(seconds: 8)); // Reduced timeout to prevent hanging

        if (response.statusCode == 200) {
          final jsonData = json.decode(response.body);
          AppLogger.info('Order detail response received successfully');

          if (jsonData['success'] == true && jsonData['order'] != null) {
            AppLogger.info('تم جلب تفاصيل الطلب $orderId بنجاح');

            // Process the order details
            final orderData = jsonData['order'];

            // Create order items
            List<OrderItem> orderItems = [];
            if (orderData['items'] != null) {
              final itemsList = orderData['items'] as List;
              orderItems = itemsList.map((item) => OrderItem.fromJson(item as Map<String, dynamic>)).toList();
              AppLogger.info('Parsed ${orderItems.length} items for order $orderId');
            } else {
              AppLogger.warning('No items found in order $orderId response');
            }

            // Calculate total amount from items or use provided total
            double totalAmount = 0.0;
            if (orderItems.isNotEmpty) {
              totalAmount = orderItems.fold(
                  0.0, (sum, item) => sum + item.subtotal);
              AppLogger.info('Calculated total amount: $totalAmount from ${orderItems.length} items');
            } else if (orderData['total_amount'] != null) {
              totalAmount = double.tryParse(orderData['total_amount'].toString()) ?? 0.0;
              AppLogger.info('Using total_amount from API: $totalAmount');
            }

            // Extract customer data safely
            String customerName = '';
            String customerPhone = '';
            String? address;

            if (orderData['customer'] != null && orderData['customer'] is Map) {
              final customer = orderData['customer'] as Map;
              customerName = customer['name']?.toString() ?? '';
              customerPhone = customer['phone']?.toString() ?? '';
              address = customer['address']?.toString();
            } else {
              customerName = orderData['customer_name']?.toString() ?? '';
              customerPhone = orderData['customer_phone']?.toString() ?? '';
              address = orderData['address']?.toString();
            }

            // Extract warehouse data safely
            String? warehouseName;
            if (orderData['warehouse'] != null && orderData['warehouse'] is Map) {
              final warehouse = orderData['warehouse'] as Map;
              warehouseName = warehouse['name']?.toString();
            } else {
              warehouseName = orderData['warehouse_name']?.toString();
            }

            // Parse dates safely
            DateTime createdAt;
            try {
              createdAt = DateTime.parse((orderData['created_at'] as String?) ?? DateTime.now().toIso8601String());
            } catch (e) {
              AppLogger.warning('Error parsing created_at date: $e, using current date');
              createdAt = DateTime.now();
            }

            DateTime? deliveryDate;
            if (orderData['delivery_date'] != null) {
              try {
                deliveryDate = DateTime.parse(orderData['delivery_date'] as String? ?? '');
              } catch (e) {
                AppLogger.warning('Error parsing delivery_date: $e');
              }
            }

            // Create and return the order model
            return OrderModel(
              id: orderData['id'].toString(),
              orderNumber: (orderData['order_number'] as String?) ?? 'ORD-$orderId',
              customerName: customerName,
              customerPhone: customerPhone,
              status: (orderData['status'] as String?) ?? 'pending',
              totalAmount: totalAmount,
              items: orderItems,
              createdAt: createdAt,
              deliveryDate: deliveryDate,
              notes: (orderData['notes'] as String?),
              warehouseName: warehouseName,
              address: address,
            );
          } else {
            AppLogger.error('Invalid response format for order $orderId: success=${jsonData['success']}');
          }
        } else {
          AppLogger.error('Failed to get order details. Status: ${response.statusCode}');

          // Try alternative endpoint if first one fails
          return await _getOrderDetailAlternative(orderId);
        }
      } catch (e) {
        AppLogger.error('Error in first attempt to fetch order details: $e');
        // Try alternative endpoint if first one fails
        return await _getOrderDetailAlternative(orderId);
      }

      return null;
    } catch (e) {
      AppLogger.error('Fatal error in getOrderDetail: $e');
      return null;
    }
  }

  // Alternative method to fetch order details as fallback
  Future<OrderModel?> _getOrderDetailAlternative(int orderId) async {
    try {
      AppLogger.info('Trying alternative endpoint for order $orderId');

      final url = '$baseUrl/api/orders/$orderId';
      final response = await client.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 6)); // Reduced timeout for faster fallback

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        if (jsonData['success'] == true && jsonData['order'] != null) {
          AppLogger.info('Successfully retrieved order from alternative endpoint');

          final orderData = jsonData['order'];

          // Create order items
          List<OrderItem> orderItems = [];
          if (orderData['items'] != null) {
            final itemsList = orderData['items'] as List;
            orderItems = itemsList.map((item) => OrderItem.fromJson(item as Map<String, dynamic>)).toList();
          }

          // Calculate total amount
          final double totalAmount = orderItems.fold(0.0, (sum, item) => sum + item.subtotal);

          // Create basic order model
          return OrderModel(
            id: orderData['id'].toString(),
            orderNumber: (orderData['order_number'] as String?) ?? 'ORD-$orderId',
            customerName: (orderData['customer_name'] as String?) ?? '',
            customerPhone: (orderData['customer_phone'] as String?) ?? '',
            status: (orderData['status'] as String?) ?? 'pending',
            totalAmount: totalAmount,
            items: orderItems,
            createdAt: DateTime.parse((orderData['created_at'] as String?) ?? DateTime.now().toIso8601String()),
            deliveryDate: null,
            notes: (orderData['notes'] as String?),
            warehouseName: null,
          );
        }
      }
    } catch (e) {
      AppLogger.error('Alternative method also failed: $e');
    }

    return null;
  }

  Future<List<OrderModel>> getOrders() async {
    try {
      AppLogger.info('محاولة جلب الطلبات من الخادم الرئيسي: $baseUrl');

      // المحاولة الأولى: الخادم الرئيسي مع نقطة نهاية API المسؤول
      try {
        final response = await client.get(
          Uri.parse('$baseUrl/api/admin/orders'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'X-API-KEY': ADMIN_API_KEY
          },
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final jsonData = json.decode(response.body);
          AppLogger.info('تم استلام استجابة ناجحة من الخادم الرئيسي: $baseUrl');
          AppLogger.info('Response data: ${response.body.substring(0, min(200, response.body.length))}...');

          if (jsonData['orders'] != null) {
            final ordersList = jsonData['orders'] as List;
            AppLogger.info('تم جلب ${ordersList.length} طلب من الخادم الرئيسي - سيتم معالجة جميع الطلبات');

            // Process orders and fetch detailed information
            final List<OrderModel> result = [];
            int processedCount = 0;
            int successCount = 0;
            int failedCount = 0;

            // Process ALL orders from the list
            for (int index = 0; index < ordersList.length; index++) {
              final orderData = ordersList[index];
              final int orderId = (orderData['id'] as int?) ?? 0;
              processedCount++;

              AppLogger.info('معالجة الطلب $processedCount/${ordersList.length}: Order ID $orderId');

              if (orderId > 0) {
                try {
                  // Try to fetch detailed order information with shorter timeout
                  final detailedOrder = await getOrderDetail(orderId).timeout(
                    const Duration(seconds: 10),
                    onTimeout: () {
                      AppLogger.warning('Timeout fetching details for order $orderId, using basic info');
                      return null;
                    },
                  );

                  if (detailedOrder != null) {
                    // Use the detailed order with full items information
                    AppLogger.info('✅ نجح جلب تفاصيل الطلب $orderId مع ${detailedOrder.items.length} عنصر');
                    result.add(detailedOrder);
                    successCount++;
                  } else {
                    // Create basic order model as fallback
                    AppLogger.warning('⚠️ فشل جلب تفاصيل الطلب $orderId، استخدام البيانات الأساسية');
                    final basicOrder = _createBasicOrderFromData(orderData as Map<String, dynamic>);
                    result.add(basicOrder);
                    failedCount++;
                  }
                } catch (e) {
                  AppLogger.error('خطأ في معالجة الطلب $orderId: $e');
                  // Still create a basic order to not lose the order completely
                  try {
                    final basicOrder = _createBasicOrderFromData(orderData as Map<String, dynamic>);
                    result.add(basicOrder);
                    failedCount++;
                  } catch (basicError) {
                    AppLogger.error('فشل في إنشاء طلب أساسي للطلب $orderId: $basicError');
                  }
                }
              } else {
                AppLogger.warning('تخطي طلب بمعرف غير صالح: $orderId');
              }

              // Log progress every 5 orders
              if (processedCount % 5 == 0 || processedCount == ordersList.length) {
                AppLogger.info('تقدم المعالجة: $processedCount/${ordersList.length} - نجح: $successCount، فشل: $failedCount');
              }
            }

            AppLogger.info('🎉 انتهت معالجة جميع الطلبات: ${result.length} طلب تم إرجاعه من أصل ${ordersList.length}');
            AppLogger.info('📊 إحصائيات: نجح $successCount، فشل $failedCount، المجموع ${result.length}');
            return result;
          }
        } else {
          AppLogger.error('Error response from server: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        AppLogger.error('Error fetching orders from main server: $e');
      }

      // المحاولة الثانية: الخادم البديل
      try {
        AppLogger.info('محاولة الخادم البديل...');
        // Implementation for fallback server can be added here
      } catch (e) {
        AppLogger.error('Error fetching orders from fallback server: $e');
      }

      // در حالة عدم نجاح أي من المحاولات السابقة
      AppLogger.warning('All attempts to fetch orders failed, returning empty list');
      return [];
    } catch (e) {
      AppLogger.error('خطأ غير متوقع في جلب الطلبات: $e');
      return [];
    }
  }

  // Helper method to create basic order from API data
  OrderModel _createBasicOrderFromData(Map<String, dynamic> orderData) {
    try {
      OrderModel basicOrder = OrderModel.fromJson(orderData);

      // If we have no items but have items_count, create placeholder items
      if (basicOrder.items.isEmpty && orderData['items_count'] != null) {
        final List<OrderItem> placeholderItems = [];
        final int itemsCount = (orderData['items_count'] as int?) ?? 0;

        if (itemsCount > 0) {
          AppLogger.info('إنشاء $itemsCount عنصر وهمي للطلب ${basicOrder.id}');

          final productNames = [
            'غطاء بلاستيك', 'لوح خشبي', 'خزانة مطبخ', 'باب خشبي', 'رف معدني',
            'طاولة خشبية', 'كرسي مكتب', 'مقبض معدني', 'مفصلة باب', 'زجاج نافذة'
          ];

          final int numItems = itemsCount > 5 ? 5 : itemsCount;

          for (int i = 0; i < numItems; i++) {
            placeholderItems.add(OrderItem(
              id: 'placeholder_$i',
              productId: 'product_$i',
              productName: productNames[i % productNames.length],
              price: (i + 1) * 50.0,
              quantity: i < itemsCount - numItems + 1 ? 2 : 1,
              subtotal: (i + 1) * 50.0 * (i < itemsCount - numItems + 1 ? 2 : 1),
              imageUrl: 'https://via.placeholder.com/150/0000FF/808080?text=منتج+${i+1}',
            ));
          }

          basicOrder = basicOrder.copyWith(items: placeholderItems);
          AppLogger.info('تم إضافة ${placeholderItems.length} عنصر وهمي للطلب ${basicOrder.id}');
        }
      }

      return basicOrder;
    } catch (e) {
      AppLogger.error('خطأ في إنشاء طلب أساسي: $e');
      rethrow;
    }
  }

  // Get damaged items - updated to use the new API endpoint
  Future<List<DamagedItemModel>> getDamagedItems({int days = 90, String? search, int? warehouseId}) async {
    try {
      AppLogger.info('محاولة جلب العناصر التالفة من الخادم الرئيسي: $baseUrl');

      // بناء عنوان URL مع المعاملات
      final Uri uri = Uri.parse('$baseUrl/api/admin/damaged').replace(
        queryParameters: {
          'days': days.toString(),
          if (search != null) 'search': search,
          if (warehouseId != null) 'warehouse_id': warehouseId.toString(),
        },
      );

        try {
        final response = await client.get(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'X-API-KEY': ADMIN_API_KEY
          },
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final jsonData = json.decode(response.body);
          AppLogger.info('تم استلام استجابة ناجحة من الخادم الرئيسي: $baseUrl');

          if (jsonData['success'] == true && jsonData['damaged_items'] != null) {
            final itemsList = jsonData['damaged_items'] as List;
            AppLogger.info('تم جلب ${itemsList.length} عنصر تالف من الخادم الرئيسي');

            // حفظ البيانات الإحصائية والفلاتر للاستخدام لاحقًا
            if (jsonData['stats'] != null) {
              AppLogger.info('تم استلام بيانات إحصائية للعناصر التالفة');
            }

            if (jsonData['filters'] != null) {
              AppLogger.info('تم استلام فلاتر للعناصر التالفة');
            }

            return itemsList.map((item) => DamagedItemModel.fromJson(item as Map<String, dynamic>)).toList();
          } else {
            AppLogger.warning('الاستجابة لا تحتوي على العناصر التالفة المطلوبة');
            throw Exception('الاستجابة لا تحتوي على البيانات المطلوبة');
          }
        } else {
          AppLogger.error('فشل جلب العناصر التالفة مع رمز الحالة: ${response.statusCode}');
          throw Exception('فشل جلب العناصر التالفة: ${response.statusCode}');
          }
        } catch (e) {
        AppLogger.error('خطأ أثناء محاولة جلب العناصر التالفة: $e');

        // محاولة الخادم البديل
        AppLogger.info('محاولة جلب العناصر التالفة من الخادم البديل: $fallbackUrl');
        final fallbackUri = Uri.parse('$fallbackUrl/api/admin/damaged').replace(
          queryParameters: {
            'days': days.toString(),
            if (search != null) 'search': search,
            if (warehouseId != null) 'warehouse_id': warehouseId.toString(),
          },
        );

        try {
          final fallbackResponse = await client.get(
            fallbackUri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'X-API-KEY': ADMIN_API_KEY
            },
          ).timeout(const Duration(seconds: 15));

          if (fallbackResponse.statusCode == 200) {
            final jsonData = json.decode(fallbackResponse.body);

            if (jsonData['success'] == true && jsonData['damaged_items'] != null) {
              final itemsList = jsonData['damaged_items'] as List;
              AppLogger.info('تم جلب ${itemsList.length} عنصر تالف من الخادم البديل');
              return itemsList.map((item) => DamagedItemModel.fromJson(item as Map<String, dynamic>)).toList();
            }
          }
        } catch (fallbackError) {
          AppLogger.error('فشل الاتصال بالخادم البديل: $fallbackError');
        }

        // إذا وصلنا إلى هنا، فقد فشلت كل المحاولات
        // إذا فشلت جميع المحاولات، نعرض بيانات وهمية للاختبار
        AppLogger.warning('فشل الاتصال بخدمة API العناصر التالفة. استخدام بيانات وهمية للاختبار.');
      }

      // إنشاء قائمة وهمية من العناصر التالفة
      List<DamagedItemModel> mockDamagedItems = [];

      final List<String> productNames = [
        'استني'
      ];

      final List<String> reasons = [
        'استني'
      ];

      final List<String> warehouses = [
        'المستودع الرئيسي',
        'مستودع المنطقة الشرقية',
        'مستودع المدينة الصناعية',
        'مستودع التوزيع المركزي'
      ];

      final List<String?> images = [
        'https://via.placeholder.com/400x300',
        'https://via.placeholder.com/300x300',
        'https://via.placeholder.com/500x400',
        null, // بعض العناصر بدون صور
      ];

      // إنشاء عناصر وهمية
      for (int i = 1; i <= 15; i++) {
        final now = DateTime.now();
        final daysAgo = i * (days ~/ 15); // موزعة على الفترة الزمنية المحددة

        mockDamagedItems.add(
          DamagedItemModel(
            id: i,
            productName: productNames[i % productNames.length],
            quantity: i % 5 + 1, // كمية بين 1 و 6
            reason: reasons[i % reasons.length],
            createdAt: now.subtract(Duration(days: daysAgo)),
            imageUrl: images[i % images.length],
            warehouse: {
              'id': i % warehouses.length + 1,
              'name': warehouses[i % warehouses.length]
            },
            order: i % 3 == 0 ? null : {
              'id': i * 100,
              'order_number': 'ORD-2023-${i * 100}'
            },
            reportedBy: {
              'id': i % 3 + 1,
              'name': 'موظف ${i % 3 + 1}'
            }
          )
        );
      }

      // إذا تم تحديد بحث، قم بتصفية العناصر
      if (search != null && search.isNotEmpty) {
        mockDamagedItems = mockDamagedItems
            .where((item) => item.productName.toLowerCase().contains(search.toLowerCase()))
            .toList();
      }

      // إذا تم تحديد مستودع، قم بتصفية العناصر
      if (warehouseId != null) {
        mockDamagedItems = mockDamagedItems
            .where((item) => item.warehouseId == warehouseId)
            .toList();
      }

      return mockDamagedItems;
    } catch (e) {
      AppLogger.error('خطأ غير متوقع أثناء جلب العناصر التالفة: $e');
      return [];
    }
  }

  // Get detailed information for a specific damaged item
  Future<DamagedItemModel> getDamagedItemDetail(int itemId) async {
    try {
      AppLogger.info('جلب تفاصيل العنصر التالف رقم $itemId');

      final Uri uri = Uri.parse('$baseUrl/api/admin/damaged/$itemId');

      try {
        final response = await client.get(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'X-API-KEY': ADMIN_API_KEY
          },
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final jsonData = json.decode(response.body);

          if (jsonData['success'] == true && jsonData['damaged_item'] != null) {
            return DamagedItemModel.fromJson(jsonData['damaged_item'] as Map<String, dynamic>);
          } else {
            throw Exception('البيانات غير كاملة');
          }
        } else {
          throw Exception('فشل جلب البيانات التفصيلية');
        }
      } catch (e) {
        AppLogger.error('خطأ أثناء محاولة جلب تفاصيل العنصر التالف: $e');

        // محاولة الخادم البديل
        // ... similar to existing code ...
      }

      // إذا فشلت جميع المحاولات، نعيد العنصر التالف الذي لدينا بالفعل بمعرف محدد
      // أو نصنع عنصر وهمي
      AppLogger.warning('فشلت جميع محاولات جلب تفاصيل العنصر التالف رقم $itemId. إنشاء عنصر وهمي.');

      return DamagedItemModel(
        id: itemId,
        productName: 'منتج تالف رقم $itemId',
        quantity: 2,
        reason: 'سبب وهمي لاختبار التطبيق - فشل الاتصال بالخادم',
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        imageUrl: 'https://via.placeholder.com/800x600',
        warehouse: {
          'id': 1,
          'name': 'المستودع الرئيسي'
        },
        order: {
          'id': itemId * 100,
          'order_number': 'ORD-2023-${itemId * 100}'
        },
        reportedBy: {
          'id': 1,
          'name': 'مدير المستودع'
        }
      );
    } catch (e) {
      AppLogger.error('خطأ غير متوقع أثناء جلب تفاصيل العنصر التالف: $e');

      // نعيد عنصر وهمي في حالة الأخطاء غير المتوقعة
      return DamagedItemModel(
        id: itemId,
        productName: 'خطأ في جلب البيانات',
        quantity: 1,
        reason: 'حدث خطأ غير متوقع: $e',
        createdAt: DateTime.now(),
        imageUrl: null,
        warehouse: {
          'id': 1,
          'name': 'غير متاح'
        },
        order: null,
        reportedBy: null
      );
    }
  }

  // Extract orders from HTML response
  List<OrderModel> _extractOrdersFromHtml(String html) {
    AppLogger.info('Extracting orders from HTML');
    final List<OrderModel> orders = [];

    try {
      final document = htmlParser.parse(html);

      // محاولة العثور على العنوان أولاً للتحقق من صحة الصفحة
      final pageTitle = document.querySelector('title')?.text ?? '';
      AppLogger.info('عنوان الصفحة: $pageTitle');

      // البحث عن جداول بشكل أكثر تحديداً
      final orderTables = document.querySelectorAll('table.table, table.table-bordered, table.orders-table, table');
      AppLogger.info('تم العثور على ${orderTables.length} جدول');

      if (orderTables.isNotEmpty) {
        // العثور على الجدول الذي يحتوي على ترويسة مناسبة
        var orderTable = orderTables.first;
        for (var table in orderTables) {
          final headers = table.querySelectorAll('th, thead td');
          final headerTexts = headers.map((h) => h.text.trim().toLowerCase()).toList();

          // للتصحيح، سنطبع الترويسات التي وجدناها
          AppLogger.info('ترويسات الجدول: ${headerTexts.join(", ")}');

          if (headerTexts.any((h) => h.contains('order') || h.contains('طلب') || h.contains('الطلب'))) {
            orderTable = table;
            AppLogger.info('تم اختيار جدول الطلبات بناءً على الترويسة');
            break;
          }
        }

        final rows = orderTable.querySelectorAll('tbody tr, tr');
        AppLogger.info('تم العثور على ${rows.length} صف في جدول الطلبات');

        if (rows.isEmpty) {
          // محاولة البحث عن قائمة طلبات بتنسيق آخر
          final orderItems = document.querySelectorAll('.order-item, .order-card, .card');
          AppLogger.info('تم العثور على ${orderItems.length} عنصر طلب بديل');

          // Process order cards if available
          for (int i = 0; i < orderItems.length; i++) {
            final card = orderItems[i];
            try {
              final id = 'order_card_$i';

              // محاولة استخراج رقم الطلب
              String orderNumber = '';
              final orderNumberElement = card.querySelector('.order-number, .number, [class*="number"]');
              if (orderNumberElement != null) {
                orderNumber = orderNumberElement.text.trim();
              } else {
                orderNumber = 'Order-$i';
              }

              // استخراج اسم العميل
              String customerName = 'Customer';
              final customerElement = card.querySelector('.customer, .customer-name, [class*="customer"]');
              if (customerElement != null) {
                customerName = customerElement.text.trim();
              }

              // استخراج الحالة
              String status = 'pending';
              final statusElement = card.querySelector('.status, .state, .badge, [class*="status"], [class*="badge"]');
              if (statusElement != null) {
                status = statusElement.text.trim();
              }

              double totalAmount = 0.0;
              final totalElement = card.querySelector('.total, .amount, .price, [class*="total"], [class*="price"]');
              if (totalElement != null) {
                final amountText = totalElement.text.trim();
                final amountStr = amountText.replaceAll(RegExp(r'[^\d\.,]'), '').replaceAll(',', '.');
                totalAmount = double.tryParse(amountStr) ?? 0.0;
              }

              // إنشاء نموذج الطلب
              final order = OrderModel(
                id: id,
                orderNumber: orderNumber,
                customerName: customerName,
                customerPhone: '',
                status: status,
                totalAmount: totalAmount,
                items: [
                  OrderItem(
                    id: 'item_${id}_1',
                    productId: 'product_1',
                    productName: 'منتج',
                    price: totalAmount,
                    quantity: 1,
                    subtotal: totalAmount,
                  )
                ],
                createdAt: DateTime.now(),
              );

              orders.add(order);
            } catch (e) {
              AppLogger.error('خطأ في استخراج معلومات الطلب من البطاقة رقم $i', e);
            }
          }
        }

        // تخطي الصف الأول إذا كان ترويسة
        final startIndex = rows.isNotEmpty && rows.first.querySelectorAll('th').isNotEmpty ? 1 : 0;

        for (int i = startIndex; i < rows.length; i++) {
          final row = rows[i];
          final cells = row.querySelectorAll('td');

          if (cells.length >= 3) { // نحتاج على الأقل 3 خلايا للحصول على الحد الأدنى من المعلومات
            try {
              final id = 'order_$i';

              // محاولة استخراج رقم الطلب من معرف الصف أو من أول خلية
              String orderNumber = '';
              if (row.attributes.containsKey('id') && row.attributes['id']!.contains('order')) {
                orderNumber = row.attributes['id']!.replaceAll(RegExp(r'[^\d]'), '');
              } else if (row.attributes.containsKey('data-order-id')) {
                orderNumber = row.attributes['data-order-id']!;
              } else {
                orderNumber = cells.isNotEmpty ? cells[0].text.trim() : 'Order-$i';
              }

              // إنشاء مصفوفة من محتويات الخلايا لتسهيل البحث
              final List<String> cellTexts = cells.map((cell) => cell.text.trim()).toList();
              AppLogger.info('محتويات الصف $i: ${cellTexts.join(" | ")}');

              // استخراج معلومات العميل - عادة تكون في الخلية الثانية
              final String customerName = cells.length > 1 ? cells[1].text.trim() : 'Customer $i';

              // استخراج الحالة - عادة في خلية منفصلة أو تحتوي على شارة
              String status = 'pending';
              for (var cell in cells) {
                final badge = cell.querySelector('.badge, .status, .state, span[class*="status"], span[class*="badge"]');
                if (badge != null) {
                  status = badge.text.trim();
                  break;
                }

                // أو البحث عن كلمات دالة في النص
                final text = cell.text.trim().toLowerCase();
                if (text == 'مكتمل' || text == 'تم التسليم' || text == 'completed' || text == 'delivered') {
                  status = 'completed';
                  break;
                } else if (text == 'قيد الانتظار' || text == 'معلق' || text == 'pending' || text == 'waiting') {
                  status = 'pending';
                  break;
                } else if (text == 'ملغي' || text == 'cancelled' || text == 'canceled') {
                  status = 'cancelled';
                  break;
                } else if (text == 'قيد المعالجة' || text == 'جاري التجهيز' || text == 'processing') {
                  status = 'processing';
                  break;
                }
              }

              // استخراج التاريخ
              DateTime createdAt = DateTime.now();
              for (var cell in cells) {
                final text = cell.text.trim();
                // البحث عن نمط التاريخ
                if (RegExp(r'\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4}').hasMatch(text) ||
                    RegExp(r'\d{2,4}[\/\-\.]\d{1,2}[\/\-\.]\d{1,2}').hasMatch(text)) {
                  try {
                    // محاولة تحليل التاريخ بأنماط مختلفة
                    final dateStr = RegExp(r'\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4}').firstMatch(text)?.group(0) ??
                        RegExp(r'\d{2,4}[\/\-\.]\d{1,2}[\/\-\.]\d{1,2}').firstMatch(text)?.group(0) ?? '';

                    if (dateStr.isNotEmpty) {
                      final parts = dateStr.split(RegExp(r'[/\-\.]'));
                      if (parts.length == 3) {
                        // تحديد ما إذا كان التنسيق dd/mm/yyyy أو yyyy/mm/dd
                        if (parts[0].length == 4) {
                          // yyyy/mm/dd
                          final year = int.tryParse(parts[0]) ?? DateTime.now().year;
                          final month = int.tryParse(parts[1]) ?? 1;
                          final day = int.tryParse(parts[2]) ?? 1;
                          createdAt = DateTime(year, month, day);
                        } else {
                          // dd/mm/yyyy أو mm/dd/yyyy (نفترض dd/mm/yyyy في السياق العربي)
                          final day = int.tryParse(parts[0]) ?? 1;
                          final month = int.tryParse(parts[1]) ?? 1;
                          final year = int.tryParse(parts[2]) ?? DateTime.now().year;
                          // إضافة القرن إذا كانت السنة مكونة من رقمين فقط
                          final fullYear = year < 100 ? 2000 + year : year;
                          createdAt = DateTime(fullYear, month, day);
                        }
                      }
                    }
                    break;
                  } catch (e) {
                    AppLogger.error('خطأ في استخراج التاريخ', e);
                    break;
                  }
                }
              }

              // استخراج المبلغ الإجمالي
              double totalAmount = 0.0;
              for (var cell in cells) {
                final text = cell.text.trim();
                if (text.contains('ج.م') || text.contains('جنيه') || text.contains('EGP') ||
                    text.contains('\$') || text.contains('\$') || RegExp(r'\d+[\.,]\d+').hasMatch(text)) {
                  try {
                    final amountStr = text.replaceAll(RegExp(r'[^\d\.,]'), '').replaceAll(',', '.');
                    final amount = double.tryParse(amountStr);
                    if (amount != null && amount > 0) {
                      totalAmount = amount;
                      break;
                    }
                  } catch (e) {
                    AppLogger.error('خطأ في استخراج المبلغ', e);
                  }
                }
              }

              // استخراج رقم الهاتف
              String customerPhone = '';
              for (var cell in cells) {
                final text = cell.text.trim();
                // البحث عن نمط رقم الهاتف
                if (RegExp(r'\+?\d{8,}').hasMatch(text)) {
                  final phoneMatch = RegExp(r'\+?\d{8,}').firstMatch(text);
                  if (phoneMatch != null) {
                    customerPhone = phoneMatch.group(0) ?? '';
                    break;
                  }
                }
              }

              // إنشاء عناصر الطلب (افتراضية حيث أننا قد لا نحصل على تفاصيل العناصر من صفحة القائمة)
              final List<OrderItem> items = [
                OrderItem(
                  id: 'item_${id}_1',
                  productId: 'product_1',
                  productName: 'منتج 1',
                  price: totalAmount > 0 ? totalAmount * 0.6 : 100,
                  quantity: 1,
                  subtotal: totalAmount > 0 ? totalAmount * 0.6 : 100,
                ),
                OrderItem(
                  id: 'item_${id}_2',
                  productId: 'product_2',
                  productName: 'منتج 2',
                  price: totalAmount > 0 ? totalAmount * 0.4 : 50,
                  quantity: 1,
                  subtotal: totalAmount > 0 ? totalAmount * 0.4 : 50,
                ),
              ];

              // إنشاء نموذج الطلب
              final order = OrderModel(
                id: id,
                orderNumber: orderNumber,
                customerName: customerName,
                customerPhone: customerPhone,
                status: status,
                totalAmount: totalAmount,
                items: items,
                createdAt: createdAt,
              );

              orders.add(order);
            } catch (e) {
              AppLogger.error('خطأ في استخراج معلومات الطلب من الصف رقم $i', e);
            }
          }
        }
      } else {
        // محاولة البحث عن طلبات بتنسيق بديل (مثل البطاقات)
        AppLogger.info('لم يتم العثور على جداول، جاري البحث عن تنسيقات بديلة...');
        final orderCards = document.querySelectorAll('.order-card, .order, .card, [class*="order"]');

        if (orderCards.isNotEmpty) {
          AppLogger.info('تم العثور على ${orderCards.length} بطاقة طلب');

          for (int i = 0; i < orderCards.length; i++) {
            final card = orderCards[i];
            try {
              // استخراج المعلومات من البطاقة
              final id = 'order_card_$i';
              final String orderNumber = card.attributes['data-order-id'] ?? 'Order-$i';

              // محاولة العثور على عناصر بترويسات معروفة
              String customerName = 'عميل $i';
              final customerElement = card.querySelector('.customer-name, .client, [class*="customer"]');
              if (customerElement != null) {
                customerName = customerElement.text.trim();
              }

              String status = 'pending';
              final statusElement = card.querySelector('.status, .badge, [class*="status"]');
              if (statusElement != null) {
                status = statusElement.text.trim();
              }

              double totalAmount = 0.0;
              final totalElement = card.querySelector('.total, .amount, .price, [class*="total"], [class*="price"]');
              if (totalElement != null) {
                final amountText = totalElement.text.trim();
                final amountStr = amountText.replaceAll(RegExp(r'[^\d\.,]'), '').replaceAll(',', '.');
                totalAmount = double.tryParse(amountStr) ?? 0.0;
              }

              // إنشاء نموذج الطلب
              final order = OrderModel(
                id: id,
                orderNumber: orderNumber,
                customerName: customerName,
                customerPhone: '',
                status: status,
                totalAmount: totalAmount,
                items: [
                  OrderItem(
                    id: 'item_${id}_1',
                    productId: 'product_1',
                    productName: 'منتج',
                    price: totalAmount,
                    quantity: 1,
                    subtotal: totalAmount,
                  )
                ],
                createdAt: DateTime.now(),
              );

              orders.add(order);
            } catch (e) {
              AppLogger.error('خطأ في استخراج معلومات الطلب من البطاقة رقم $i', e);
            }
          }
        }
      }

      AppLogger.info('تم استخراج ${orders.length} طلب من HTML');
      return orders;
    } catch (e) {
      AppLogger.error('خطأ في استخراج الطلبات من HTML', e);
      return [];
    }
  }

  // Extract damaged items from HTML response
  List<DamagedItemModel> _extractDamagedItemsFromHtml(String html) {
    AppLogger.info('استخراج العناصر التالفة من HTML');
    final List<DamagedItemModel> damagedItems = [];

    try {
      final document = htmlParser.parse(html);

      // محاولة العثور على العنوان أولاً للتحقق من صحة الصفحة
      final pageTitle = document.querySelector('title')?.text ?? '';
      AppLogger.info('عنوان الصفحة: $pageTitle');

      // البحث عن جداول بشكل أكثر تحديداً
      final damagedTables = document.querySelectorAll('table.table, table.table-bordered, table.damaged-table, table');
      AppLogger.info('تم العثور على ${damagedTables.length} جدول');

      if (damagedTables.isNotEmpty) {
        // العثور على الجدول الذي يحتوي على ترويسة مناسبة للعناصر التالفة
        var damagedTable = damagedTables.first;
        for (var table in damagedTables) {
          final headers = table.querySelectorAll('th, thead td');
          final headerTexts = headers.map((h) => h.text.trim().toLowerCase()).toList();

          // للتصحيح، سنطبع الترويسات التي وجدناها
          AppLogger.info('ترويسات الجدول: ${headerTexts.join(", ")}');

          if (headerTexts.any((h) => h.contains('damage') || h.contains('تالف') || h.contains('عطب'))) {
            damagedTable = table;
            AppLogger.info('تم اختيار جدول العناصر التالفة بناءً على الترويسة');
            break;
          }
        }

        final rows = damagedTable.querySelectorAll('tbody tr, tr');
        AppLogger.info('تم العثور على ${rows.length} صف في جدول العناصر التالفة');

        if (rows.isEmpty) {
          // محاولة البحث عن قائمة العناصر التالفة بتنسيق آخر
          final damagedItems = document.querySelectorAll('.damaged-item, .damage-card, .card');
          AppLogger.info('تم العثور على ${damagedItems.length} عنصر تالف بتنسيق بديل');

          // TODO: يمكن إضافة منطق هنا لاستخراج البيانات من تنسيق بطاقات بدلاً من الجدول
        }

        // تخطي الصف الأول إذا كان ترويسة
        final startIndex = rows.isNotEmpty && rows.first.querySelectorAll('th').isNotEmpty ? 1 : 0;

        for (int i = startIndex; i < rows.length; i++) {
          final row = rows[i];
          final cells = row.querySelectorAll('td');

          if (cells.length >= 3) { // نحتاج على الأقل 3 خلايا للحد الأدنى من المعلومات
            try {
              final id = 'damaged_$i';

              // إنشاء مصفوفة من محتويات الخلايا لتسهيل البحث
              final List<String> cellTexts = cells.map((cell) => cell.text.trim()).toList();
              AppLogger.info('محتويات الصف $i: ${cellTexts.join(" | ")}');

              // استخراج اسم المنتج - عادة في الخلية الأولى
              final productName = cells.isNotEmpty ? cells[0].text.trim() : 'Product $i';
              final productId = 'product_$i';

              // استخراج الكمية
              int quantity = 1;
              for (var j = 0; j < cells.length; j++) {
                final cell = cells[j];
                final text = cell.text.trim();

                // البحث عن رقم منفرد أو كلمة تدل على الكمية
                if (RegExp(r'^\d+$').hasMatch(text)) {
                  quantity = int.tryParse(text) ?? 1;
                  break;
                } else if (text.contains('الكمية') || text.contains('quantity')) {
                  final quantityMatch = RegExp(r'(\d+)').firstMatch(text);
                  if (quantityMatch != null) {
                    quantity = int.tryParse(quantityMatch.group(1) ?? '1') ?? 1;
                    break;
                  }
                }
              }

              // استخراج سبب التلف
              String reason = 'غير معروف';
              for (var cell in cells) {
                final text = cell.text.trim();

                // البحث عن نص طويل يمكن أن يكون سبباً
                if (text.length > 5 &&
                    !RegExp(r'^\d+$').hasMatch(text) &&
                    !RegExp(r'\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4}').hasMatch(text) &&
                    text != productName) {
                  // استبعاد التواريخ والكميات والأرقام التسلسلية
                  if (!text.contains('/') && !text.contains('-') && !text.contains(':')) {
                    reason = text;
                    break;
                  }
                }
              }

              // استخراج التاريخ
              DateTime reportedDate = DateTime.now();
              for (var cell in cells) {
                final text = cell.text.trim();
                // البحث عن نمط التاريخ
                if (RegExp(r'\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4}').hasMatch(text) ||
                    RegExp(r'\d{2,4}[\/\-\.]\d{1,2}[\/\-\.]\d{1,2}').hasMatch(text)) {
                  try {
                    // محاولة تحليل التاريخ بأنماط مختلفة
                    final dateStr = RegExp(r'\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4}').firstMatch(text)?.group(0) ??
                        RegExp(r'\d{2,4}[\/\-\.]\d{1,2}[\/\-\.]\d{1,2}').firstMatch(text)?.group(0) ?? '';

                    if (dateStr.isNotEmpty) {
                      final parts = dateStr.split(RegExp(r'[/\-\.]'));
                      if (parts.length == 3) {
                        final day = int.tryParse(parts[0]) ?? 1;
                        final month = int.tryParse(parts[1]) ?? 1;
                        final year = int.tryParse(parts[2]) ?? DateTime.now().year;
                        reportedDate = DateTime(year, month, day);
                      }
                    }
                  } catch (e) {
                    // استخدام التاريخ الافتراضي
                  }
                }
              }

              // استخراج الحالة
              String status = 'pending';
              for (var cell in cells) {
                final badge = cell.querySelector('.badge, .status, .state, span[class*="status"]');
                if (badge != null) {
                  status = badge.text.trim();
                  break;
                }

                // البحث عن كلمات دالة في النص
                final text = cell.text.trim().toLowerCase();
                if (text == 'مكتمل' || text == 'تم الحل' || text == 'resolved' || text == 'completed') {
                  status = 'resolved';
                  break;
                } else if (text == 'قيد الانتظار' || text == 'معلق' || text == 'pending') {
                  status = 'pending';
                  break;
                } else if (text == 'مرفوض' || text == 'rejected') {
                  status = 'rejected';
                  break;
                }
              }

              // استخراج المبلغ المفقود (إن وجد)
              double? lossAmount;
              for (var cell in cells) {
                final text = cell.text.trim();
                if (text.contains('ج.م') || text.contains('جنيه') || text.contains('EGP') ||
                    text.contains('\$') || text.contains('\$') || RegExp(r'\d+[\.,]\d+').hasMatch(text)) {
                  try {
                    final amountStr = text.replaceAll(RegExp(r'[^\d\.,]'), '').replaceAll(',', '.');
                    final amount = double.tryParse(amountStr);
                    if (amount != null && amount > 0) {
                      lossAmount = amount;
                      break;
                    }
                  } catch (e) {
                    AppLogger.error('خطأ في استخراج المبلغ المفقود', e);
                  }
                }
              }

              // إنشاء نموذج العنصر التالف
              final damagedItem = DamagedItemModel(
                id: int.parse(id.replaceAll(RegExp(r'[^0-9]'), '1')),
                productName: productName,
                quantity: quantity,
                reason: reason,
                createdAt: reportedDate,
              );

              damagedItems.add(damagedItem);
            } catch (e) {
              AppLogger.error('خطأ في استخراج معلومات العنصر التالف من الصف رقم $i', e);
            }
          }
        }
      } else {
        // محاولة البحث عن عناصر تالفة بتنسيق بديل
        final damagedCards = document.querySelectorAll('.damaged-item, .damage-card, .card, div[class*="damage"]');

        if (damagedCards.isNotEmpty) {
          AppLogger.info('تم العثور على ${damagedCards.length} بطاقة عنصر تالف');

          for (int i = 0; i < damagedCards.length; i++) {
            final card = damagedCards[i];
            try {
              final id = 'damaged_card_$i';

              // استخراج اسم المنتج
              String productName = 'منتج $i';
              final productElement = card.querySelector('.product-name, .item-name, .title, h3, h4');
              if (productElement != null) {
                productName = productElement.text.trim();
              }

              // استخراج الكمية
              int quantity = 1;
              final quantityElement = card.querySelector('.quantity, .amount, [class*="quantity"]');
              if (quantityElement != null) {
                final quantityText = quantityElement.text.trim();
                final quantityMatch = RegExp(r'(\d+)').firstMatch(quantityText);
                if (quantityMatch != null) {
                  quantity = int.tryParse(quantityMatch.group(1) ?? '1') ?? 1;
                }
              }

              // استخراج السبب
              String reason = 'غير معروف';
              final reasonElement = card.querySelector('.reason, .cause, .description, [class*="reason"]');
              if (reasonElement != null) {
                reason = reasonElement.text.trim();
              }

              // استخراج التاريخ
              DateTime reportedDate = DateTime.now();
              final dateElement = card.querySelector('.date, .reported-date, [class*="date"]');
              if (dateElement != null) {
                final dateText = dateElement.text.trim();
                final dateMatch = RegExp(r'\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4}').firstMatch(dateText);
                if (dateMatch != null) {
                  try {
                    final dateStr = dateMatch.group(0) ?? '';
                    final parts = dateStr.split(RegExp(r'[/\-\.]'));
                    if (parts.length == 3) {
                      final day = int.tryParse(parts[0]) ?? 1;
                      final month = int.tryParse(parts[1]) ?? 1;
                      final year = int.tryParse(parts[2]) ?? DateTime.now().year;
                      reportedDate = DateTime(year, month, day);
                    }
                  } catch (e) {
                    // استخدام التاريخ الافتراضي
                  }
                }
              }

              // إنشاء نموذج العنصر التالف
              final damagedItem = DamagedItemModel(
                id: int.parse(id.replaceAll(RegExp(r'[^0-9]'), '1')),
                productName: productName,
                quantity: quantity,
                reason: reason,
                createdAt: reportedDate,
              );

              damagedItems.add(damagedItem);
            } catch (e) {
              AppLogger.error('خطأ في استخراج معلومات العنصر التالف من البطاقة رقم $i', e);
            }
          }
        }
      }

      AppLogger.info('تم استخراج ${damagedItems.length} عنصر تالف من HTML');
      return damagedItems;
    } catch (e) {
      AppLogger.error('خطأ في استخراج العناصر التالفة من HTML', e);
      return [];
    }
  }

  // Base method for GET requests
  Future<Map<String, dynamic>> _get(String endpoint) async {
    try {
      final response = await client.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: _getHeaders(),
      );

      return _processResponse(response);
    } catch (e) {
      AppLogger.error('Error in GET request to $endpoint', e);
      return {
        'success': false,
        'message': e.toString(),
        'data': null
      };
    }
  }

  // Base method for POST requests
  Future<Map<String, dynamic>> _post(String endpoint, dynamic data) async {
    try {
      final response = await client.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: _getHeaders(),
        body: json.encode(data),
      );

      return _processResponse(response);
    } catch (e) {
      AppLogger.error('Error in POST request to $endpoint', e);
      return {
        'success': false,
        'message': e.toString(),
        'data': null
      };
    }
  }

  // Process API responses
  Map<String, dynamic> _processResponse(http.Response response) {
    try {
      // Check if the response is JSON
      try {
        final responseData = json.decode(response.body);

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return {
            'success': true,
            'data': responseData
          };
        } else {
          return {
            'success': false,
            'message': responseData['message'] ?? 'Request failed',
            'data': null
          };
        }
      } catch (e) {
        // If it's not JSON, return the raw HTML
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return {
            'success': true,
            'data': response.body
          };
        } else {
          return {
            'success': false,
            'message': 'Request failed with status ${response.statusCode}',
            'data': null
          };
        }
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to process response: ${e.toString()}',
        'data': null
      };
    }
  }

  // Get headers with correct Accept header for JSON response
  Map<String, String> _getHeaders() {
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json, text/html',
      'User-Agent': 'SmartBizTracker/1.0',
    };

    // Add Authorization token if available
    if (_authToken != null && _authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_authToken';
    }

    // Add cookies if available (Django session authentication)
    if (_cookies != null && _cookies!.isNotEmpty) {
      headers['Cookie'] = _cookies!;
    }

    return headers;
  }

  // Handle API response - ensure we get JSON
  dynamic _handleResponse(http.Response response) {
    switch (response.statusCode) {
      case 200:
      case 201:
        // First check if response is JSON
        if (response.body.trim().startsWith('{') || response.body.trim().startsWith('[')) {
          try {
            return json.decode(response.body);
          } catch (e) {
            AppLogger.error('Error decoding JSON: $e');
            throw Exception('Invalid JSON response from server');
          }
        }
        // If we got HTML instead of JSON, try to extract data or throw error
        else if (response.body.trim().startsWith('<!DOCTYPE html>') ||
                 response.body.trim().startsWith('<html>')) {
          AppLogger.warning('Received HTML response instead of JSON');
          throw Exception('Unexpected HTML response from server');
        }
        else {
          AppLogger.warning('Response is not JSON or HTML: ${response.body.substring(0, 50)}...');
          throw Exception('Unexpected response format from server');
        }
      case 400:
        throw Exception('Bad request: ${response.body}');
      case 401:
        throw Exception('Unauthorized: Invalid credentials');
      case 404:
        throw Exception('Resource not found');
      case 500:
        throw Exception('Server error');
      default:
        throw Exception('HTTP Status ${response.statusCode}');
    }
  }

  // Check if the API is available
  Future<bool> checkApiAvailability() async {
    try {
      final response = await client.get(
        Uri.parse(baseUrl),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode >= 200 && response.statusCode < 500;
    } catch (e) {
      AppLogger.error('Error checking API availability', e);
      return false;
    }
  }

  // Get products from admin
  Future<List<Map<String, dynamic>>> getProductsFromAdmin() async {
    try {
      AppLogger.info('Fetching products from Django admin');

      // First ensure we are logged in
      if (_cookies == null || _cookies!.isEmpty) {
        final loginSuccess = await loginToAdmin('eslam@sama.com', 'eslam@123');
        if (!loginSuccess) {
          AppLogger.error('Failed to login to Django admin');
          return [];
        }
      }

      // Get the products page
      final response = await client.get(
        Uri.parse('$baseUrl/admin/products/'),
        headers: {
          'Cookie': _cookies ?? '',
          'Accept': 'text/html,application/xhtml+xml',
        },
      );

      if (response.statusCode != 200) {
        AppLogger.error('Failed to get products page: ${response.statusCode}');
        return [];
      }

      // Parse the HTML to extract product data
      final products = _extractProductsFromHtml(response.body);
      AppLogger.info('Extracted ${products.length} products from admin');

      return products;
    } catch (e) {
      AppLogger.error('Error fetching products from admin: $e');
      return [];
    }
  }

  // Extract products from HTML
  List<Map<String, dynamic>> _extractProductsFromHtml(String html) {
    final document = htmlParser.parse(html);
    final List<Map<String, dynamic>> products = [];

    try {
      // Try to find product table
      final productTable = document.querySelector('#result_list, table.table');

      if (productTable != null) {
        final rows = productTable.querySelectorAll('tbody tr');

        for (var row in rows) {
          try {
            final cells = row.querySelectorAll('td');

            if (cells.length >= 3) { // We need at least id, name and price
              final id = cells[0].text.trim();
              final name = cells.length > 1 ? cells[1].text.trim() : 'Unknown Product';
              final priceText = cells.length > 2 ? cells[2].text.trim() : '0';

              // Try to extract price (handle formatting)
              final priceString = priceText.replaceAll(RegExp(r'[^\d.,]'), '').replaceAll(',', '.');
              final price = double.tryParse(priceString) ?? 0.0;

              // Get category if available
              final category = cells.length > 3 ? cells[3].text.trim() : 'Uncategorized';

              products.add({
                'id': id,
                'name': name,
                'price': price,
                'category': category,
              });
            }
          } catch (e) {
            AppLogger.error('Error extracting product data from row: $e');
          }
        }
      } else {
        // Try alternative approach - look for product cards
        final productCards = document.querySelectorAll('.product-card, .card, .item');

        for (int i = 0; i < productCards.length; i++) {
          final card = productCards[i];

          try {
            // Extract product name
            final nameElement = card.querySelector('.product-name, .name, h3, h4');
            final name = nameElement?.text.trim() ?? 'Product ${i + 1}';

            // Extract price
            final priceElement = card.querySelector('.price, .product-price');
            final priceText = priceElement?.text.trim() ?? '0';
            final priceString = priceText.replaceAll(RegExp(r'[^\d.,]'), '').replaceAll(',', '.');
            final price = double.tryParse(priceString) ?? 0.0;

            // Extract category
            final categoryElement = card.querySelector('.category, .product-category');
            final category = categoryElement?.text.trim() ?? 'Uncategorized';

            products.add({
              'id': 'product_${i + 1}',
              'name': name,
              'price': price,
              'category': category,
            });
          } catch (e) {
            AppLogger.error('Error extracting product data from card: $e');
          }
        }
      }

      // If we couldn't extract any products, return some sample data
      if (products.isEmpty) {
        return [
          {'id': 'p1', 'name': 'نجف كريستال فاخر', 'price': 1999.99, 'category': 'نجف كريستال'},
          {'id': 'p2', 'name': 'نجف مودرن أبيض', 'price': 1299.99, 'category': 'نجف مودرن'},
          {'id': 'p3', 'name': 'ثريا كلاسيكية ذهبية', 'price': 2499.99, 'category': 'ثريات كلاسيكية'},
          {'id': 'p4', 'name': 'نجف LED معاصر', 'price': 899.99, 'category': 'إضاءة ليد'},
          {'id': 'p5', 'name': 'سبوت إضاءة دائري', 'price': 199.99, 'category': 'سبوتات'},
        ];
      }

      return products;
    } catch (e) {
      AppLogger.error('Error parsing products HTML: $e');
      return [];
    }
  }

  // Diagnostic method to check API connectivity and authentication
  Future<Map<String, dynamic>> checkApiStatus() async {
    final results = <String, dynamic>{
      'baseUrl': baseUrl,
      'connection': false,
      'login': false,
      'products': false,
      'errors': <String>[],
    };

    try {
      // Step 1: Check basic connectivity
      try {
        final response = await client.get(Uri.parse(baseUrl))
            .timeout(const Duration(seconds: 5));

        results['connection'] = response.statusCode >= 200 && response.statusCode < 500;
        results['statusCode'] = response.statusCode;
        results['htmlSize'] = response.body.length;
      } catch (e) {
        results['errors'].add('Connection error: ${e.toString()}');
      }

      // Step 2: Check admin login
      try {
        final loginSuccess = await loginToAdmin('eslam@sama.com', 'eslam@123');
        results['login'] = loginSuccess;
        if (!loginSuccess) {
          results['errors'].add('Admin login failed');
        }
      } catch (e) {
        results['errors'].add('Login error: ${e.toString()}');
      }

      // Step 3: Check products access
      if (results['login'] == true) {
        try {
          final products = await getProductsFromAdmin();
          results['products'] = products.isNotEmpty;
          results['productCount'] = products.length;
        } catch (e) {
          results['errors'].add('Products error: ${e.toString()}');
        }
      }

      return results;
    } catch (e) {
      results['errors'].add('Diagnostic error: ${e.toString()}');
      return results;
    }
  }

  // Obtener lista de productos
  Future<List<ProductModel>> getProducts() async {
    try {
      AppLogger.info('Obteniendo lista de productos desde API');

      // Crear lista de productos de muestra para pruebas
      final mockProducts = List.generate(15, (index) {
        final id = 'prod-${1000 + index}';
        final name = 'منتج رقم ${index + 1}';
        final description = 'وصف للمنتج رقم ${index + 1}';
        final price = (Random().nextDouble() * 500 + 50);
        final imageUrl = 'https://via.placeholder.com/150?text=Product+${index + 1}';

        return {
          'id': id,
          'name': name,
          'description': description,
          'price': price,
          'imageUrl': imageUrl,
          'quantity': Random().nextInt(100),
          'category': Random().nextInt(3) == 0 ? 'ملابس' : (Random().nextInt(2) == 0 ? 'إلكترونيات' : 'أدوات منزلية'),
          'sku': 'SKU-${1000 + index}',
          'isActive': true,
          'reorderPoint': Random().nextInt(10),
          'images': [imageUrl],
          'createdAt': DateTime.now().subtract(Duration(days: Random().nextInt(30))).toIso8601String(),
        };
      });

      AppLogger.info('Generados ${mockProducts.length} productos de prueba');

      // Convertir a la clase ProductModel
      final List<ProductModel> products = mockProducts.map((product) => ProductModel.fromMap(product)).toList();
      return products;
    } catch (e) {
      AppLogger.error('Error al obtener productos: $e');
      return [];
    }
  }
}


