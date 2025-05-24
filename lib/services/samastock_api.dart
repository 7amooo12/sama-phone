import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:html/parser.dart' as htmlParser;
import 'package:smartbiztracker_new/models/product_model.dart';

class SamaStockApiService {
  final String baseUrl = 'https://samastock.pythonanywhere.com';
  final http.Client client;
  final Map<String, String> _storage = {};
  String? _authToken;
  String? _cookies;

  SamaStockApiService({
    http.Client? client,
  }) : client = client ?? http.Client();

  // Initialize the API service and load saved credentials
  Future<void> initialize() async {
    try {
      _authToken = _storage['sama_stock_token'];
      _cookies = _storage['sama_stock_cookies'];
      AppLogger.info('SamaStock API initialized');
    } catch (e) {
      AppLogger.error('Error initializing SamaStock API', e);
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

  // Helper method to get headers with authentication
  Map<String, String> _getHeaders() {
    Map<String, String> headers = {
      'Accept': 'application/json, text/html',
      'Content-Type': 'application/json',
    };
    
    if (_cookies != null) {
      headers['Cookie'] = _cookies!;
    }
    
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    
    return headers;
  }

  // Login to the SamaStock system
  Future<bool> login(String username, String password) async {
    try {
      AppLogger.info('محاولة تسجيل الدخول إلى SamaStock API');
      
      // استخدام بيانات اعتماد ثابتة لتسجيل الدخول
      final adminUsername = 'admin';
      final adminPassword = 'mn402729'; // تعديل كلمة المرور الصحيحة

      // استخدام بيانات الاعتماد المقدمة أو البيانات الافتراضية
      final useUsername = username.isEmpty ? adminUsername : username;
      final usePassword = password.isEmpty ? adminPassword : password;
      
      // First, get the CSRF token and cookies
      final initialResponse = await client.get(
        Uri.parse('$baseUrl/admin/login/'),
        headers: {'Accept': 'text/html'},
      ).timeout(const Duration(seconds: 10));
      
      String? csrfToken;
      if (initialResponse.statusCode == 200) {
        // Extract CSRF token from the HTML response
        final document = htmlParser.parse(initialResponse.body);
        
        // طباعة العنوان للتصحيح
        final title = document.querySelector('title')?.text ?? '';
        AppLogger.info('عنوان صفحة تسجيل الدخول: $title');
        
        // البحث عن عنصر CSRF token بعدة طرق
        final csrfElements = [
          document.querySelector('input[name="csrfmiddlewaretoken"]'),
          document.querySelector('input[name="csrf_token"]'),
          document.querySelector('meta[name="csrf-token"]'),
          document.querySelector('[name*="csrf"]'),
        ];
        
        for (var element in csrfElements) {
          if (element != null) {
            if (element.attributes.containsKey('value')) {
              csrfToken = element.attributes['value'];
              AppLogger.info('تم العثور على CSRF token في عنصر input');
              break;
            } else if (element.attributes.containsKey('content')) {
              csrfToken = element.attributes['content'];
              AppLogger.info('تم العثور على CSRF token في عنصر meta');
              break;
            }
          }
        }
        
        // إذا لم نجد CSRF token، نبحث في JavaScript
        if (csrfToken == null) {
          final scriptElements = document.querySelectorAll('script');
          for (var script in scriptElements) {
            final scriptText = script.text;
            if (scriptText.contains('csrf') || scriptText.contains('token')) {
              final tokenMatch = RegExp("csrf[^'\"]*['\"]([^'\"]+)['\"]").firstMatch(scriptText);
              if (tokenMatch != null) {
                csrfToken = tokenMatch.group(1);
                AppLogger.info('تم العثور على CSRF token في نص JavaScript');
                break;
              }
            }
          }
        }
        
        // Extract cookies from the response
        final cookies = initialResponse.headers['set-cookie'];
        if (cookies != null) {
          _cookies = cookies;
          await _saveToStorage('sama_stock_cookies', _cookies!);
          AppLogger.info('تم حفظ الـ cookies من الاستجابة الأولية');
        }
      } else {
        AppLogger.warning('فشل في الوصول إلى صفحة تسجيل الدخول: ${initialResponse.statusCode}');
      }
      
      // محاولة تسجيل الدخول بنموذج HTML
      Map<String, String> loginData = {
        'username': useUsername,
        'password': usePassword,
        'remember': 'on',
      };
      
      if (csrfToken != null) {
        loginData['csrfmiddlewaretoken'] = csrfToken;
      }
      
      Map<String, String> headers = {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept': 'text/html,application/json',
        'Referer': '$baseUrl/admin/login/',
      };
      
      if (_cookies != null) {
        headers['Cookie'] = _cookies!;
      }
      
      AppLogger.info('محاولة تسجيل الدخول باستخدام نموذج HTML');
      final formResponse = await client.post(
        Uri.parse('$baseUrl/admin/login/'),
        headers: headers,
        body: loginData,
      ).timeout(const Duration(seconds: 15));
      
      // فحص نتيجة محاولة تسجيل الدخول
      if (formResponse.statusCode == 200 || formResponse.statusCode == 302) {
        // Extract and save cookies
        if (formResponse.headers['set-cookie'] != null) {
          _cookies = formResponse.headers['set-cookie'];
          await _saveToStorage('sama_stock_cookies', _cookies!);
          AppLogger.info('تم حفظ الـ cookies بعد تسجيل الدخول');
        }
        
        // محاولة التحقق من نجاح تسجيل الدخول من خلال فحص محتوى الصفحة المُرجعة
        if (!formResponse.body.contains('تسجيل الدخول') && !formResponse.body.contains('login')) {
          AppLogger.info('تم تسجيل الدخول بنجاح (تم التحقق من المحتوى)');
          return true;
        }
        
        // فحص الـ headers للتحقق من وجود redirect يدل على النجاح
        if (formResponse.headers.containsKey('location') && 
            (formResponse.headers['location']?.contains('dashboard') ?? false)) {
          AppLogger.info('تم تسجيل الدخول بنجاح (تم التحقق من عنوان التوجيه)');
          return true;
        }
      }
      
      // محاولة التحقق من نجاح تسجيل الدخول عن طريق زيارة صفحة محمية
      AppLogger.info('محاولة التحقق من تسجيل الدخول من خلال زيارة صفحة محمية');
      final checkResponse = await client.get(
        Uri.parse('$baseUrl/admin/products/'),
        headers: {
          'Accept': 'text/html',
          if (_cookies != null) 'Cookie': _cookies!,
          if (_authToken != null) 'Authorization': 'Bearer $_authToken',
        },
      ).timeout(const Duration(seconds: 10));
      
      if (checkResponse.statusCode == 200) {
        // فحص ما إذا كانت الصفحة المُرجعة هي صفحة تسجيل الدخول أم صفحة محمية
        if (!checkResponse.body.contains('تسجيل الدخول') && !checkResponse.body.contains('login')) {
          // يبدو أننا تمكنا من الوصول إلى صفحة محمية، مما يعني نجاح تسجيل الدخول
          AppLogger.info('تم التحقق من نجاح تسجيل الدخول من خلال الوصول إلى صفحة محمية');
          return true;
        }
      }
      
      // إذا وصلنا إلى هنا، فقد فشلت جميع محاولات تسجيل الدخول
      AppLogger.warning('فشلت جميع محاولات تسجيل الدخول');
      return false;
    } catch (e) {
      AppLogger.error('خطأ أثناء تسجيل الدخول', e);
      return false;
    }
  }

  // Get all products - now uses the standardized API endpoint with API key
  Future<List<ProductModel>> getProducts() async {
    AppLogger.info('استدعاء getProducts() - استخدام getProductsWithApiKey()');
    // استخدام نفس الطريقة المركزية للحصول على المنتجات
    return getProductsWithApiKey();
  }
  
  // Get admin products with toJSON - now uses the standardized API endpoint with API key
  Future<List<ProductModel>> getAdminProducts() async {
    AppLogger.info('استدعاء getAdminProducts() - استخدام getProductsWithApiKey()');
    // استخدام نفس الطريقة المركزية للحصول على المنتجات
    return getProductsWithApiKey();
  }
  
  // Get dashboard analytics data
  Future<Map<String, dynamic>> getDashboardAnalytics() async {
    try {
      AppLogger.info('جلب بيانات تحليلات لوحة التحكم');
      
      // Check if we have auth credentials and try to login if not
      if (_cookies == null) {
        AppLogger.warning('لا توجد بيانات جلسة مخزنة، محاولة تسجيل الدخول');
        final loginSuccess = await login('admin', 'mn402729');
        if (!loginSuccess) {
          AppLogger.error('فشل تسجيل الدخول قبل طلب بيانات لوحة التحكم');
          return {};
        }
      }
      
      // استخدام نقطة نهاية API الجديدة لبيانات لوحة التحكم
      final response = await client.get(
        Uri.parse('$baseUrl/admin/api/dashboard-data'),
        headers: _getHeaders(),
      ).timeout(const Duration(seconds: 15));
      
      AppLogger.info('استجابة API لوحة التحكم: ${response.statusCode}');
      if (response.body.isNotEmpty) {
        AppLogger.info('عينة من محتوى الاستجابة: ${response.body.substring(0, min(100, response.body.length))}...');
      }
      
      if (response.statusCode == 200) {
        try {
          final jsonData = json.decode(response.body);
          
          if (jsonData is Map) {
            AppLogger.info('تم جلب بيانات لوحة التحكم بنجاح');
            // Convert to Map<String, dynamic> explicitly
            final Map<String, dynamic> typedData = {};
            jsonData.forEach((key, value) {
              typedData[key.toString()] = value;
            });
            return typedData;
          } else {
            AppLogger.error('بنية JSON غير متوقعة لبيانات لوحة التحكم: ${jsonData.toString().substring(0, min(50, jsonData.toString().length))}...');
            return {};
          }
        } catch (e) {
          AppLogger.error('خطأ في تحليل استجابة JSON لبيانات لوحة التحكم', e);
          return {};
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Try to login again and retry
        AppLogger.warning('غير مصرح، محاولة إعادة تسجيل الدخول');
        final loginSuccess = await login('admin', 'mn402729');
        if (loginSuccess) {
          // Retry the request
          return getDashboardAnalytics();
        } else {
          AppLogger.error('فشل إعادة تسجيل الدخول');
          return {};
        }
      } else {
        AppLogger.error('فشل في جلب بيانات لوحة التحكم - رمز الحالة: ${response.statusCode}');
        return {};
      }
    } catch (e) {
      AppLogger.error('خطأ في جلب بيانات لوحة التحكم', e);
      
      // إرجاع هيكل بيانات فارغ في حالة الفشل
      return {
        'total_sales': 0,
        'total_revenue': 0,
        'monthly_sales': 0,
        'monthly_revenue': 0,
        'total_products': 0,
        'low_stock_products': [],
        'recent_invoices': [],
      };
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
      AppLogger.error('خطأ في التحقق من توفر API', e);
      return false;
    }
  }
  
  // Extract products from HTML response
  List<ProductModel> _extractProductsFromHtml(String html) {
    AppLogger.info('استخراج المنتجات من HTML');
    List<ProductModel> products = [];
    
    try {
      // طباعة حجم HTML للتصحيح
      AppLogger.info('حجم HTML المستلم: ${html.length} حرف');
      
      final document = htmlParser.parse(html);
      
      // محاولة العثور على العنوان أولاً للتحقق من صحة الصفحة
      final title = document.querySelector('title')?.text ?? '';
      AppLogger.info('عنوان الصفحة: $title');
      
      // البحث عن عناصر المنتجات باستخدام محددات مختلفة
      final productElements = [
        ...document.querySelectorAll('table tbody tr'),              // منتجات في جدول
        ...document.querySelectorAll('.product-card, .card'),        // بطاقات المنتجات
        ...document.querySelectorAll('.product-item, .product'),     // عناصر المنتج العامة
        ...document.querySelectorAll('[data-product-id]'),           // أي عنصر له معرف منتج
        ...document.querySelectorAll('.inventory-item'),             // عناصر المخزون
      ];
      
      AppLogger.info('تم العثور على ${productElements.length} عنصر محتمل للمنتجات');
      
      // البحث عن المنتجات في جدول
      if (productElements.isNotEmpty) {
        for (var element in productElements) {
          try {
            // طباعة نص العنصر للتحليل
            AppLogger.debug('بيانات عنصر المنتج: ${element.text.trim().substring(0, min(50, element.text.trim().length))}...');
            
            // استخراج معرف المنتج
            String? id;
            if (element.attributes.containsKey('data-product-id')) {
              id = element.attributes['data-product-id'];
            } else if (element.attributes.containsKey('data-id')) {
              id = element.attributes['data-id'];
            } else if (element.attributes.containsKey('id')) {
              id = element.attributes['id']?.replaceAll(RegExp(r'[^0-9]'), '');
            }
            
            final idValue = int.tryParse(id ?? '') ?? products.length + 1; // استخدام الفهرس كمعرف بديل
            
            // استخراج اسم المنتج
            String? name;
            final nameElement = element.querySelector('.product-name, .name, h2, h3, .title, .product-title, td:first-child');
            if (nameElement != null) {
              name = nameElement.text.trim();
            } else {
              // محاولة استخراج الاسم من نص العنصر الأول بحد أقصى 50 حرف
              name = element.text.trim().split('\n').first;
              if (name.length > 50) {
                name = name.substring(0, 50) + '...';
              }
            }
            
            // استخراج السعر
            double price = 0.0;
            final priceElement = element.querySelector('.price, .product-price, [data-price], td:nth-child(3), td:nth-child(4)');
            if (priceElement != null) {
              String priceText = priceElement.text.trim();
              // إزالة أي أحرف غير رقمية باستثناء النقطة العشرية
              priceText = priceText.replaceAll(RegExp(r'[^\d.]'), '');
              price = double.tryParse(priceText) ?? 0.0;
            }
            
            // استخراج الكمية
            int stock = 0;
            final stockElement = element.querySelector('.stock, .quantity, .product-quantity, [data-quantity], td:nth-child(5), td:nth-child(6)');
            if (stockElement != null) {
              String stockText = stockElement.text.trim();
              // إزالة أي أحرف غير رقمية
              stockText = stockText.replaceAll(RegExp(r'\D'), '');
              stock = int.tryParse(stockText) ?? 0;
            }
            
            // استخراج الصورة
            String? imageUrl;
            final imgElement = element.querySelector('img');
            if (imgElement != null && imgElement.attributes.containsKey('src')) {
              final src = imgElement.attributes['src'] ?? '';
              if (src.isNotEmpty) {
                // إذا كان مسار الصورة نسبيًا، قم بتحويله إلى مسار مطلق
                if (src.startsWith('/')) {
                  imageUrl = baseUrl + src;
                } else {
                  imageUrl = src;
                }
              }
            }
            
            // استخراج الوصف
            String description = '';
            final descElement = element.querySelector('.description, .product-description, [data-description], td:nth-child(2)');
            if (descElement != null) {
              description = descElement.text.trim();
            }
            
            // استخراج الفئة
            String category = '';
            final catElement = element.querySelector('.category, .product-category, [data-category]');
            if (catElement != null) {
              category = catElement.text.trim();
            }
            
            // إنشاء كائن المنتج
            final product = ProductModel(
              id: idValue.toString(),
              name: name ?? 'منتج غير معروف',
              price: price,
              quantity: stock,
              imageUrl: imageUrl,
              description: description,
              category: category,
              sku: 'SKU-${idValue.toString().padLeft(4, '0')}',
              images: imageUrl != null ? [imageUrl] : [],
              isActive: true,
              createdAt: DateTime.now(),
              reorderPoint: 5,
            );
            
            products.add(product);
            AppLogger.debug('تم استخراج منتج: ${product.name} (${product.id})');
          } catch (e) {
            AppLogger.error('خطأ في استخراج منتج من HTML', e);
          }
        }
      } else {
        // محاولة استخراج معلومات المنتج من النص
        AppLogger.warning('لم يتم العثور على عناصر منتج صريحة، محاولة تحليل النص');
        
        final text = document.body?.text ?? '';
        final lines = text.split('\n').where((line) => line.trim().isNotEmpty).toList();
        
        // محاولة إنشاء منتجات بناءً على الأسطر
        for (int i = 0; i < lines.length; i += 3) {
          if (i + 1 < lines.length) {
            try {
              final name = lines[i].trim();
              final priceText = lines[i+1].trim().replaceAll(RegExp(r'[^\d.]'), '');
              final price = double.tryParse(priceText) ?? 0.0;
              
              final product = ProductModel(
                id: i.toString(),
                name: name,
                price: price,
                quantity: 10,
                description: '',
                category: '',
                sku: 'SKU-${i.toString().padLeft(4, '0')}',
                images: [],
                isActive: true,
                createdAt: DateTime.now(),
                reorderPoint: 5,
              );
              
              products.add(product);
            } catch (e) {
              AppLogger.error('خطأ في استخراج منتج من النص', e);
            }
          }
        }
      }
      
      AppLogger.info('تم استخراج ${products.length} منتج من HTML');
    } catch (e) {
      AppLogger.error('خطأ عام في استخراج المنتجات من HTML', e);
    }
    
    return products;
  }

  // استخراج المنتجات من بيانات JSON
  List<ProductModel> _extractProductsFromJson(dynamic jsonData) {
    try {
      // قائمة لتخزين المنتجات المستخرجة
      List<dynamic> productsList = [];
      
      if (jsonData is List) {
        // إذا كان JSON على شكل مصفوفة مباشرة
        productsList = jsonData;
      } else if (jsonData is Map) {
        // إذا كان JSON على شكل كائن به خاصية للمنتجات
        if (jsonData.containsKey('products')) {
          productsList = jsonData['products'] as List;
        } else if (jsonData.containsKey('data')) {
          productsList = jsonData['data'] as List;
        } else if (jsonData.containsKey('results')) {
          productsList = jsonData['results'] as List;
        } else if (jsonData.containsKey('items')) {
          productsList = jsonData['items'] as List;
        } else {
          // محاولة استخراج أول قائمة في الكائن
          for (var key in jsonData.keys) {
            if (jsonData[key] is List && (jsonData[key] as List).isNotEmpty) {
              productsList = jsonData[key];
              break;
            }
          }
        }
      }
      
      if (productsList.isEmpty) {
        return [];
      }
      
      // تحويل بيانات JSON إلى كائنات ProductModel
      final products = productsList.map((item) {
        try {
          return ProductModel.fromJson(item);
        } catch (e) {
          AppLogger.error('خطأ في تحويل بيانات المنتج: $e');
          return null;
        }
      }).where((product) => product != null).cast<ProductModel>().toList();
      
      return products;
    } catch (e) {
      AppLogger.error('خطأ في استخراج المنتجات من JSON', e);
      return [];
    }
  }
  
  // إنشاء منتجات وهمية للاختبار
  List<ProductModel> _createDummyProducts() {
    AppLogger.info('إنشاء قائمة منتجات وهمية للاختبار');
    final dummyProducts = <ProductModel>[];
    
    // إضافة بعض المنتجات الوهمية
    final productNames = [
      'جهاز آيفون 15 برو ماكس',
      'سماعة سوني XM5',
      'لابتوب ديل XPS 15',
      'ساعة آبل الإصدار 9',
      'سماعة آيربودز برو 2',
      'تلفاز سامسونج OLED 65 بوصة',
      'كاميرا كانون EOS R5',
      'مكبر صوت جي بي إل',
      'جهاز بلاي ستيشن 5',
      'قارئ كتب إلكترونية كيندل',
      'ابليك 1002/400',
      'ابليك 1002/520',
      'ابليك 1002/710',
      'ابليك 1003/320',
      'ابليك 1003/520',
      'ابليك 1004/1160',
      'ابليك 1004/560',
      'ابليك 1004/760',
      'ابليك 1004/960',
    ];
    
    final categories = ['إلكترونيات', 'صوتيات', 'حواسيب', 'هواتف', 'ألعاب', 'ابليك'];
    final imageUrls = [
      'https://samastock.pythonanywhere.com/static/uploads/20250408150623_1002.png',
      'https://samastock.pythonanywhere.com/static/uploads/20250408150916_1002.png',
      'https://samastock.pythonanywhere.com/static/uploads/20250408151622_1002.png',
      'https://samastock.pythonanywhere.com/static/uploads/20250407223251_1003.png',
      'https://samastock.pythonanywhere.com/static/uploads/20250407223317_1003.png',
      'https://samastock.pythonanywhere.com/static/uploads/20250408155057_1004.png',
    ];
    
    for (int i = 0; i < productNames.length; i++) {
      final category = i < 10 ? categories[i % 5] : categories[5];
      final price = 100.0 + (i * 100);
      final discount = i % 3 == 0 ? 100.0 : 0.0;
      
      final product = ProductModel(
        id: (i + 1).toString(),
        name: productNames[i],
        price: price,
        quantity: 10 + (i * 5),
        description: 'وصف المنتج ${i + 1}',
        category: category,
        sku: 'SKU-${(i + 1).toString().padLeft(4, '0')}',
        images: [],
        imageUrl: imageUrls[i % imageUrls.length],
        isActive: true,
        createdAt: DateTime.now().subtract(Duration(days: i)),
        reorderPoint: 5,
      );
      
      dummyProducts.add(product);
    }
    
    // حفظ المنتجات الوهمية في التخزين المؤقت أيضًا
    _saveToStorage('product_count', dummyProducts.length.toString());
    _saveToStorage('cached_products', json.encode(dummyProducts.map((p) => p.toJson()).toList()));
    _saveToStorage('last_product_fetch', DateTime.now().toIso8601String());
    
    return dummyProducts;
  }

  // Get products using API key
  Future<List<ProductModel>> getProductsWithApiKey() async {
    try {
      AppLogger.info('جاري تحميل المنتجات باستخدام مفتاح API');
      
      // استخدام نقطة نهاية API واحدة فقط للمنتجات
      final apiEndpoint = '$baseUrl/flutter/api/api/products';
      
      try {
        AppLogger.info('محاولة جلب المنتجات من: $apiEndpoint');
        final response = await client.get(
          Uri.parse(apiEndpoint),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'x-api-key': 'lux2025FlutterAccess',
          },
        ).timeout(const Duration(seconds: 30)); // Increased timeout for larger responses
          
        if (response.statusCode == 200) {
          try {
            AppLogger.info('تم استلام استجابة من API - حجم الاستجابة: ${response.body.length} بايت');
            final data = json.decode(response.body);
            
            if (data is Map && data.containsKey('products')) {
              final productsList = data['products'] as List<dynamic>;
              AppLogger.info('تم العثور على ${productsList.length} منتج في API response');
              
              final products = productsList.map((item) {
                try {
                  return ProductModel.fromJson(item);
                } catch (e) {
                  AppLogger.error('خطأ في تحويل عنصر المنتج: $e');
                  return null;
                }
              }).where((product) => product != null).cast<ProductModel>().toList();
              
              AppLogger.info('تم تحويل ${products.length} منتج بنجاح');
              return products;
            } else {
              AppLogger.warning('بنية JSON غير متوقعة من API: ${data.toString().substring(0, min(200, data.toString().length))}...');
              return [];
            }
          } catch (e) {
            AppLogger.error('خطأ في تحليل استجابة API: ${e.toString()}');
            return [];
          }
        } else {
          AppLogger.warning('فشل في تحميل المنتجات. رمز الحالة: ${response.statusCode}');
          return [];
        }
      } catch (e) {
        AppLogger.error('خطأ في الاتصال بالخادم: ${e.toString()}');
        return [];
      }
    } catch (e) {
      AppLogger.error('خطأ في تحميل المنتجات', e);
      return [];
    }
  }
  
  // تحويل البيانات إلى كائنات ProductModel
  List<ProductModel> _convertToProductModels(dynamic data) {
    try {
      if (data is List) {
        return data.map((item) => ProductModel.fromJson(item)).toList();
      } else if (data is Map && data['products'] != null) {
        final products = data['products'] as List<dynamic>;
        return products.map((item) => ProductModel.fromJson(item)).toList();
      } else {
        AppLogger.error('بنية JSON غير متوقعة من API: ${data.toString().substring(0, min(50, data.toString().length))}...');
        return [];
      }
    } catch (e) {
      AppLogger.error('خطأ في تحويل بيانات API إلى ProductModel', e);
      return [];
    }
  }

  // تحديث المنتجات في الخلفية بدون انتظار الاستجابة
  void _refreshProductsInBackground() {
    AppLogger.info('جاري تحديث المنتجات في الخلفية');
    client.get(
      Uri.parse('$baseUrl/flutter/api/api/products'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'x-api-key': 'lux2025FlutterAccess',
      },
    ).then((response) {
      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          List<ProductModel> products;
          
          if (data is List) {
            products = _convertToProductModels(data);
          } else if (data is Map && data['products'] != null) {
            final productsList = data['products'] as List<dynamic>;
            products = _convertToProductModels(productsList);
          } else {
            return;
          }
          
          if (products.isNotEmpty) {
            _saveToStorage('product_count', products.length.toString());
            _saveToStorage('cached_products', json.encode(products.map((p) => p.toJson()).toList()));
            _saveToStorage('last_product_fetch', DateTime.now().toIso8601String());
            AppLogger.info('تم تحديث ${products.length} منتج في التخزين المؤقت');
          }
        } catch (e) {
          AppLogger.error('خطأ في تحديث المنتجات في الخلفية', e);
        }
      }
    }).catchError((e) {
      AppLogger.error('خطأ في طلب تحديث المنتجات في الخلفية', e);
    });
  }
} 