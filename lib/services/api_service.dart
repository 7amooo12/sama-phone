import 'dart:convert';
import 'dart:math';
import 'package:smartbiztracker_new/config/constants.dart';
import 'package:smartbiztracker_new/models/product_model.dart';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:smartbiztracker_new/utils/logger.dart';
import 'package:html/parser.dart' as htmlParser;
import 'package:html/dom.dart' as dom;
import '../utils/app_logger.dart';
import '../models/user_model.dart';

class ApiService {
  ApiService({
    String? baseUrl,
    http.Client? client,
    Dio? dio,
  })  : baseUrl = baseUrl ?? AppConstants.baseUrl,
        client = client ?? http.Client(),
        dio = dio ?? Dio();
  final String baseUrl;
  final http.Client client;
  final Dio dio;

  // Constants for SAMA API
  static const String samaApiBaseUrl = 'https://samastock.pythonanywhere.com';
  static const String samaAdminUsername = 'admin';
  static const String samaAdminPassword = 'mn402729';

  Future<Map<String, dynamic>> httpGet(String endpoint,
      {Map<String, String>? headers, String? token}) async {
    try {
      final response = await client
          .get(
            Uri.parse('$baseUrl/$endpoint'),
            headers: _buildHeaders(token, headers),
          )
          .timeout(const Duration(milliseconds: AppConstants.connectTimeout));

      return _processResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> httpPost(String endpoint, dynamic data,
      {Map<String, String>? headers, String? token}) async {
    try {
      final response = await client
          .post(
            Uri.parse('$baseUrl/$endpoint'),
            headers: _buildHeaders(token, headers),
            body: json.encode(data),
          )
          .timeout(const Duration(milliseconds: AppConstants.connectTimeout));

      return _processResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> httpPut(String endpoint, dynamic data,
      {Map<String, String>? headers, String? token}) async {
    try {
      final response = await client
          .put(
            Uri.parse('$baseUrl/$endpoint'),
            headers: _buildHeaders(token, headers),
            body: json.encode(data),
          )
          .timeout(const Duration(milliseconds: AppConstants.connectTimeout));

      return _processResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> httpDelete(String endpoint,
      {Map<String, String>? headers, String? token}) async {
    try {
      final response = await client
          .delete(
            Uri.parse('$baseUrl/$endpoint'),
            headers: _buildHeaders(token, headers),
          )
          .timeout(const Duration(milliseconds: AppConstants.connectTimeout));

      return _processResponse(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Map<String, String> _buildHeaders(
      String? token, Map<String, String>? additionalHeaders) {
    final headers = {'Content-Type': 'application/json'};

    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    if (additionalHeaders != null) {
      headers.addAll(additionalHeaders);
    }

    return headers;
  }

  Map<String, dynamic> _processResponse(http.Response response) {
    final int statusCode = response.statusCode;

    try {
      final responseData = json.decode(response.body);

      if (statusCode >= 200 && statusCode < 300) {
        return {'success': true, 'data': responseData};
      } else {
        return {
          'success': false,
          'status': statusCode,
          'message': responseData['message'] ?? 'Request failed',
          'errors': responseData['errors']
        };
      }
    } catch (e) {
      return {
        'success': false,
        'status': statusCode,
        'message': 'Failed to process response: ${e.toString()}',
      };
    }
  }

  // Get products from the API
  Future<List<ProductModel>> getProducts() async {
    try {
      final apiUrl = '$baseUrl${AppConstants.productsApi}';
      AppLogger.info('جاري تحميل المنتجات من API: $apiUrl');

      // تأكد من أن عنوان API صحيح
      if (!apiUrl.contains('sama-app.com')) {
        AppLogger.warning('عنوان API غير صحيح: $apiUrl');
        throw Exception('عنوان API غير صحيح: $apiUrl');
      }

      final response = await client.get(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body) as List<dynamic>;
        AppLogger.info('تم تحميل ${data.length} منتج من API');

        return data
            .map((item) => ProductModel.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        AppLogger.error(
          'فشل في تحميل المنتجات',
          'رمز الحالة: ${response.statusCode}, الاستجابة: ${response.body}'
        );

        // في حالة الفشل، نرجع خطأ
        throw Exception('فشل في تحميل المنتجات: ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.error('خطأ في تحميل المنتجات', e);

      // في حالة حدوث خطأ، نرجع الخطأ
      rethrow;
    }
  }

  // Get products from SAMA API using Basic Authentication
  Future<List<ProductModel>> getSamaProducts() async {
    try {
      AppLogger.info('جاري تحميل المنتجات من SAMA API...');
      
      // قائمة لتخزين جميع المنتجات من كل الصفحات
      List<ProductModel> allProducts = [];
      
      // إعداد التصفيح
      int currentPage = 1;
      int maxPages = 15; // زيادة الحد الأقصى للصفحات للحصول على كل المنتجات
      bool hasMorePages = true;
      
      // إنشاء هيدر المصادقة الأساسية
      String basicAuth = 'Basic ' + base64.encode(utf8.encode('$samaAdminUsername:$samaAdminPassword'));
      
      // استمرار في جلب الصفحات حتى الانتهاء من جميع المنتجات
      while (hasMorePages && currentPage <= maxPages) {
        final adminUrl = '$samaApiBaseUrl/admin/products?page=$currentPage&per_page=100';
        AppLogger.info('جاري تحميل الصفحة $currentPage: $adminUrl');
        
        final response = await client.get(
          Uri.parse(adminUrl),
          headers: {
            'Accept': 'text/html',
            'Authorization': basicAuth,
          },
        ).timeout(const Duration(seconds: 45)); // زيادة وقت الانتظار
        
        if (response.statusCode == 200) {
          AppLogger.info('تم استلام الصفحة $currentPage بنجاح (${response.body.length} بايت)');
          
          // تحليل المنتجات من HTML
          final pageProducts = _extractProductsFromHtml(response.body, currentPage);
          
          if (pageProducts.isNotEmpty) {
            // إضافة منتجات الصفحة الحالية إلى القائمة الكلية
            allProducts.addAll(pageProducts);
            AppLogger.info('تم تحميل ${pageProducts.length} منتج من الصفحة $currentPage، الإجمالي: ${allProducts.length}');
            
            // البحث عن وجود صفحات أخرى
            final document = htmlParser.parse(response.body);
            
            // البحث عن عناصر التصفيح
            final nextPageLinks = document.querySelectorAll('a.next, a[rel="next"], .pagination a:contains("Next"), .pagination a:contains("التالي"), .pagination li:not(.active):not(.disabled) a');
            bool foundNextPage = false;
            
            for (var link in nextPageLinks) {
              final text = link.text.trim().toLowerCase();
              final href = link.attributes['href'] ?? '';
              
              // إذا كان هذا رابط الصفحة التالية
              if (text.contains('next') || 
                  text.contains('التالي') || 
                  href.contains('page=${currentPage + 1}') ||
                  (RegExp(r'[^\d]' + (currentPage + 1).toString() + r'[^\d]').hasMatch(href))) {
                foundNextPage = true;
                break;
              }
            }
            
            if (foundNextPage) {
              currentPage++;
            } else {
              AppLogger.info('لم يتم العثور على رابط للصفحة التالية بعد الصفحة $currentPage');
              hasMorePages = false;
            }
          } else {
            AppLogger.info('لم يتم العثور على منتجات في الصفحة $currentPage');
            hasMorePages = false;
          }
        } else {
          AppLogger.error('فشل في تحميل الصفحة $currentPage، رمز الحالة: ${response.statusCode}');
          hasMorePages = false;
          
          // محاولة إرجاع ما تم تحميله إذا كان لدينا منتجات بالفعل
          if (allProducts.isNotEmpty) {
            AppLogger.info('إرجاع ${allProducts.length} منتج تم تحميلها بالفعل');
            return allProducts;
          }
          
          // محاولة استخدام API بديل إذا فشل HTML
          try {
            final apiUrl = '$samaApiBaseUrl/api/products';
            final apiResponse = await client.get(
              Uri.parse(apiUrl),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'Authorization': basicAuth,
              },
            ).timeout(const Duration(seconds: 30));
            
            if (apiResponse.statusCode == 200) {
              try {
                final data = json.decode(apiResponse.body);
                if (data is List) {
                  AppLogger.info('تم تحميل ${data.length} منتج من SAMA API (JSON)');
                  return _convertToProductModels(data);
                } else if (data is Map && data['products'] != null) {
                  final products = data['products'] as List<dynamic>;
                  AppLogger.info('تم تحميل ${products.length} منتج من SAMA API (JSON)');
                  return _convertToProductModels(products);
                }
              } catch (e) {
                AppLogger.error('خطأ في تحليل استجابة API: $e');
              }
            }
          } catch (apiError) {
            AppLogger.error('خطأ في استدعاء API البديل', apiError);
          }
        }
      }
      
      // التحقق من وجود منتجات
      if (allProducts.isEmpty) {
        AppLogger.warning('لم يتم العثور على أي منتجات من SAMA API بعد محاولة $currentPage صفحات');
        return [];
      }
      
      AppLogger.info('إجمالي المنتجات التي تم تحميلها: ${allProducts.length}');
      return allProducts;
    } catch (e) {
      AppLogger.error('خطأ في تحميل المنتجات من SAMA API', e);
      return [];
    }
  }

  // Helper method to extract products from HTML response
  List<ProductModel> _extractProductsFromHtml(String htmlContent, int page) {
    AppLogger.info('استخراج بيانات المنتجات من HTML للصفحة $page...');
    List<ProductModel> products = [];
    
    try {
      final document = htmlParser.parse(htmlContent);
      AppLogger.info('تم تحليل HTML بنجاح، البحث عن المنتجات...');
      
      // أولاً: محاولة إيجاد الجداول (أسلوب واجهة الإدارة)
      final tables = document.querySelectorAll('table.table, table.products-table, table.data-table, table.admin-table, table');
      
      if (tables.isNotEmpty) {
        AppLogger.info('تم العثور على ${tables.length} جدول في HTML');
        
        // البحث عن جدول المنتجات (عادةً الجدول الأكبر)
        var productTable = tables.first;
        int maxCells = 0;
        
        for (var table in tables) {
          final rows = table.querySelectorAll('tr');
          int cellCount = 0;
          
          for (var row in rows) {
            cellCount += row.querySelectorAll('td, th').length;
          }
          
          if (cellCount > maxCells) {
            maxCells = cellCount;
            productTable = table;
          }
        }
        
        final rows = productTable.querySelectorAll('tr');
        AppLogger.info('تم العثور على ${rows.length} صف في جدول المنتجات');
        
        // استخراج خريطة الأعمدة من صف الترويسة
        Map<String, int> columnMap = {};
        if (rows.isNotEmpty) {
          final headerCells = rows.first.querySelectorAll('th');
          
          for (int i = 0; i < headerCells.length; i++) {
            final headerText = headerCells[i].text.trim().toLowerCase();
            
            if (headerText.contains('name') || headerText.contains('product') || 
                headerText.contains('اسم') || headerText.contains('منتج')) {
              columnMap['name'] = i;
            } else if (headerText.contains('description') || headerText.contains('desc') || 
                       headerText.contains('وصف') || headerText.contains('تفاصيل')) {
              columnMap['description'] = i;
            } else if (headerText.contains('price') || headerText.contains('سعر') || 
                       headerText.contains('selling')) {
              columnMap['price'] = i;
            } else if (headerText.contains('purchase') || headerText.contains('cost') || 
                       headerText.contains('شراء') || headerText.contains('تكلفة')) {
              columnMap['cost'] = i;
            } else if (headerText.contains('quantity') || headerText.contains('stock') || 
                       headerText.contains('كمية') || headerText.contains('مخزون')) {
              columnMap['quantity'] = i;
            } else if (headerText.contains('category') || headerText.contains('فئة') || 
                       headerText.contains('تصنيف')) {
              columnMap['category'] = i;
            } else if (headerText.contains('image') || headerText.contains('photo') || 
                       headerText.contains('صورة')) {
              columnMap['image'] = i;
            } else if (headerText.contains('sku') || headerText.contains('code') || 
                       headerText.contains('رمز')) {
              columnMap['sku'] = i;
            } else if (headerText.contains('status') || headerText.contains('حالة')) {
              columnMap['status'] = i;
            } else if (headerText.contains('id') || headerText.contains('#')) {
              columnMap['id'] = i;
            } else if (headerText.contains('action') || headerText.contains('إجراءات')) {
              columnMap['actions'] = i;
            }
          }
        }
        
        // صفوف المنتجات (تخطي صف الترويسة)
        for (int i = 1; i < rows.length; i++) {
          final row = rows[i];
          final cells = row.querySelectorAll('td');
          
          if (cells.length >= 3) { // تأكد من وجود بيانات كافية
            try {
              // استخراج البيانات من الخلايا باستخدام خريطة الأعمدة
              String id = 'sama_${page}_${i}';
              String name = 'منتج ${page}_${i}';
              String description = '';
              String category = 'عام';
              double price = 0.0;
              double manufacturingCost = 0.0;
              int quantity = 0;
              String sku = 'SKU-${page}-${i}';
              List<String> images = [];
              String imageUrl = '';
              bool isActive = true;
              
              // استخراج المعرف
              if (columnMap.containsKey('id') && columnMap['id']! < cells.length) {
                final idCell = cells[columnMap['id']!];
                final idText = idCell.text.trim();
                final idMatch = RegExp(r'\d+').firstMatch(idText);
                
                if (idMatch != null) {
                  id = 'sama_${idMatch.group(0)}';
                } else {
                  // البحث عن معرف في روابط العمود
                  final links = idCell.querySelectorAll('a');
                  for (var link in links) {
                    if (link.attributes.containsKey('href')) {
                      final href = link.attributes['href']!;
                      final hrefIdMatch = RegExp(r'\/(\d+)(\/|$)').firstMatch(href);
                      if (hrefIdMatch != null) {
                        id = 'sama_${hrefIdMatch.group(1)}';
                        break;
                      }
                    }
                  }
                }
              }
              
              // استخراج الاسم
              if (columnMap.containsKey('name') && columnMap['name']! < cells.length) {
                final nameCell = cells[columnMap['name']!];
                
                // تجربة البحث عن الاسم في رابط أولاً
                final nameLink = nameCell.querySelector('a');
                if (nameLink != null) {
                  name = nameLink.text.trim();
                } else {
                  name = nameCell.text.trim();
                }
                
                if (name.isEmpty) name = 'منتج ${page}_${i}';
              } else if (cells.length > 0) {
                // استخدام العمود الأول إذا لم نجد عمود الاسم
                name = cells[0].text.trim();
                if (name.isEmpty) name = 'منتج ${page}_${i}';
              }
              
              // استخراج الوصف
              if (columnMap.containsKey('description') && columnMap['description']! < cells.length) {
                description = cells[columnMap['description']!].text.trim();
              } else {
                // محاولة استخراج الوصف من عناصر tooltip أو title
                for (var cell in cells) {
                  final elements = cell.querySelectorAll('[title], [data-toggle="tooltip"]');
                  for (var el in elements) {
                    final title = el.attributes['title']?.trim() ?? '';
                    if (title.length > 5 && !title.contains('تعديل') && !title.contains('حذف')) {
                      description = title;
                      break;
                    }
                  }
                  if (description.isNotEmpty) break;
                }
              }
              
              // استخراج التصنيف
              if (columnMap.containsKey('category') && columnMap['category']! < cells.length) {
                final catCell = cells[columnMap['category']!];
                // البحث عن badge أو span
                final badge = catCell.querySelector('.badge, span');
                if (badge != null) {
                  category = badge.text.trim();
                } else {
                  category = catCell.text.trim();
                }
                if (category.isEmpty) category = 'عام';
              }
              
              // استخراج السعر
              if (columnMap.containsKey('price') && columnMap['price']! < cells.length) {
                final priceText = cells[columnMap['price']!].text.trim();
                price = _extractNumericValue(priceText);
              }
              
              // استخراج سعر التكلفة
              if (columnMap.containsKey('cost') && columnMap['cost']! < cells.length) {
                final costText = cells[columnMap['cost']!].text.trim();
                manufacturingCost = _extractNumericValue(costText);
              } else {
                // تقدير سعر التكلفة كنسبة من سعر البيع
                manufacturingCost = price * 0.7;
              }
              
              // استخراج الكمية
              if (columnMap.containsKey('quantity') && columnMap['quantity']! < cells.length) {
                final qtyCell = cells[columnMap['quantity']!];
                // البحث عن badge أو الخلية نفسها
                final badge = qtyCell.querySelector('.badge, span');
                if (badge != null) {
                  quantity = _extractNumericValue(badge.text.trim()).toInt();
                } else {
                  quantity = _extractNumericValue(qtyCell.text.trim()).toInt();
                }
              }
              
              // استخراج SKU
              if (columnMap.containsKey('sku') && columnMap['sku']! < cells.length) {
                sku = cells[columnMap['sku']!].text.trim();
                if (sku.isEmpty) sku = 'SKU-${id.replaceAll('sama_', '')}';
              }
              
              // استخراج الحالة
              if (columnMap.containsKey('status') && columnMap['status']! < cells.length) {
                final statusCell = cells[columnMap['status']!];
                final statusText = statusCell.text.trim().toLowerCase();
                
                // البحث عن علامات الحالة النشطة
                isActive = !statusText.contains('hidden') && 
                          !statusText.contains('مخفي') &&
                          !statusText.contains('غير متاح') &&
                          !statusText.contains('unavailable');
                
                // البحث عن علامات بصرية للحالة
                final statusBadge = statusCell.querySelector('.badge, span');
                if (statusBadge != null) {
                  final badgeClass = statusBadge.className.toLowerCase();
                  if (badgeClass.contains('success') || badgeClass.contains('primary')) {
                    isActive = true;
                  } else if (badgeClass.contains('danger') || badgeClass.contains('warning')) {
                    isActive = false;
                  }
                }
              }
              
              // استخراج الصور - 1: من عمود الصورة
              if (columnMap.containsKey('image') && columnMap['image']! < cells.length) {
                final imgCell = cells[columnMap['image']!];
                final imgElement = imgCell.querySelector('img');
                
                if (imgElement != null && imgElement.attributes.containsKey('src')) {
                  final src = imgElement.attributes['src']!;
                  imageUrl = _normalizeImageUrl(src, samaApiBaseUrl);
                  images.add(imageUrl);
                }
              }
              
              // استخراج الصور - 2: البحث في جميع الخلايا
              if (images.isEmpty) {
                for (var cell in cells) {
                  final imgElements = cell.querySelectorAll('img');
                  
                  for (var img in imgElements) {
                    if (img.attributes.containsKey('src')) {
                      final src = img.attributes['src']!;
                      
                      // استبعاد أيقونات الإجراءات والشعارات
                      if (!src.contains('logo') && !src.contains('icon') &&
                          !src.contains('edit') && !src.contains('delete') &&
                          src.length > 5) {
                          
                        final normalizedUrl = _normalizeImageUrl(src, samaApiBaseUrl);
                        if (!images.contains(normalizedUrl)) {
                          images.add(normalizedUrl);
                          
                          // استخدام أول صورة صالحة كصورة رئيسية
                          if (imageUrl.isEmpty) {
                            imageUrl = normalizedUrl;
                          }
                        }
                      }
                    }
                  }
                }
              }
              
              // استخراج الصور - 3: استخدام معرف المنتج للبحث عن صورة
              if (images.isEmpty && id.contains('sama_')) {
                final productId = id.replaceAll('sama_', '');
                
                // محاولة أنماط URL محتملة للصور
                final possibleUrls = [
                  '$samaApiBaseUrl/static/uploads/product_$productId.jpg',
                  '$samaApiBaseUrl/static/uploads/products/$productId.jpg',
                  '$samaApiBaseUrl/static/products/$productId.jpg',
                  '$samaApiBaseUrl/media/products/$productId.jpg',
                  '$samaApiBaseUrl/uploads/products/$productId.jpg',
                ];
                
                images.addAll(possibleUrls);
                imageUrl = possibleUrls.first;
              }
              
              // استخراج الصور - 4: استخراج من روابط التعديل
              if ((images.isEmpty || imageUrl.isEmpty) && columnMap.containsKey('actions')) {
                final actionsCell = cells[columnMap['actions']!];
                final links = actionsCell.querySelectorAll('a');
                
                for (var link in links) {
                  if (link.attributes.containsKey('href')) {
                    final href = link.attributes['href']!;
                    
                    if (href.contains('edit') || href.contains('product')) {
                      final idMatch = RegExp(r'\/(\d+)(\/|$)').firstMatch(href);
                      if (idMatch != null) {
                        final productId = idMatch.group(1);
                        final imageUrl = '$samaApiBaseUrl/static/uploads/product_$productId.jpg';
                        
                        if (!images.contains(imageUrl)) {
                          images.add(imageUrl);
                          
                          // إذا كان المعرف لم يستخرج سابقاً من العمود، نستخدم المعرف من الرابط
                          if (id == 'sama_${page}_${i}') {
                            id = 'sama_$productId';
                          }
                        }
                      }
                    }
                  }
                }
              }
              
              // تكوين نموذج المنتج
              final product = ProductModel(
                id: id,
                name: name,
                description: description,
                price: price,
                category: category,
                quantity: quantity,
                sku: sku,
                isActive: isActive,
                supplier: 'SAMA Store',
                reorderPoint: 5,
                minimumStock: 10,
                images: images,
                imageUrl: imageUrl,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                manufacturingCost: manufacturingCost,
              );
              
              products.add(product);
            } catch (e) {
              AppLogger.error('خطأ في استخراج بيانات المنتج من الصف رقم $i في الصفحة $page', e);
            }
          }
        }
      } else {
        AppLogger.warning('لم يتم العثور على جداول في HTML، محاولة استخدام أسلوب البطاقات...');
      }

      // إذا لم نجد منتجات من الجدول، نحاول استخدام نمط البطاقات
      if (products.isEmpty) {
        AppLogger.info('استخدام أسلوب البطاقات لاستخراج المنتجات...');
        final productCards = document.querySelectorAll(
            '.product-card, .product-item, .card, .product, .product-wrapper, .item, .card-body, div[data-product-id]');
        
        for (int i = 0; i < productCards.length; i++) {
          final card = productCards[i];
          
          try {
            // استخراج المعرف
            String id = 'sama_card_${page}_${i}';
            final productIdAttr = card.attributes['data-product-id'] ?? 
                                card.attributes['data-id'] ?? 
                                card.attributes['id'];
            
            if (productIdAttr != null && productIdAttr.isNotEmpty) {
              final idMatch = RegExp(r'\d+').firstMatch(productIdAttr);
              if (idMatch != null) {
                id = 'sama_${idMatch.group(0)}';
              }
            }
            
            // استخراج الاسم
            String name = 'منتج بطاقة ${page}_${i}';
            final nameElement = card.querySelector('h1, h2, h3, h4, h5, .product-title, .title, .name, .card-title');
            if (nameElement != null) {
              name = nameElement.text.trim();
            }
            
            // استخراج الوصف
            String description = '';
            final descElement = card.querySelector('.description, .desc, .product-description, .details, .card-text, .product-details');
            if (descElement != null) {
              description = descElement.text.trim();
            }
            
            // استخراج السعر
            double price = 0.0;
            final priceElement = card.querySelector('.price, .product-price, .amount, .selling-price, .card-price');
            if (priceElement != null) {
              price = _extractNumericValue(priceElement.text.trim());
            }
            
            // استخراج سعر التكلفة
            double manufacturingCost = price * 0.7;
            final costElement = card.querySelector('.cost, .purchase-price');
            if (costElement != null) {
              manufacturingCost = _extractNumericValue(costElement.text.trim());
            }
            
            // استخراج الكمية
            int quantity = 10;
            final quantityElement = card.querySelector('.quantity, .stock, .inventory');
            if (quantityElement != null) {
              quantity = _extractNumericValue(quantityElement.text.trim()).toInt();
            }
            
            // استخراج التصنيف
            String category = 'عام';
            final categoryElement = card.querySelector('.category, .product-category, .badge');
            if (categoryElement != null) {
              category = categoryElement.text.trim();
            }
            
            // استخراج الصورة
            String imageUrl = '';
            List<String> images = [];
            final imgElement = card.querySelector('img');
            if (imgElement != null && imgElement.attributes.containsKey('src')) {
              final src = imgElement.attributes['src']!;
              imageUrl = _normalizeImageUrl(src, samaApiBaseUrl);
              images.add(imageUrl);
            }
            
            // استخراج المعرف من الروابط إذا لم نجده سابقاً
            if (id == 'sama_card_${page}_${i}') {
              final linkElement = card.querySelector('a[href*="product"], a[href*="edit"]');
              if (linkElement != null && linkElement.attributes.containsKey('href')) {
                final href = linkElement.attributes['href']!;
                final idMatch = RegExp(r'\/(\d+)(\/|$)').firstMatch(href);
                if (idMatch != null) {
                  id = 'sama_${idMatch.group(1)}';
                }
              }
            }
            
            // إذا لم نجد صورة، نحاول الاعتماد على معرف المنتج
            if (images.isEmpty && id.contains('sama_')) {
              final productId = id.replaceAll('sama_', '');
              imageUrl = '$samaApiBaseUrl/static/uploads/product_$productId.jpg';
              images.add(imageUrl);
            }
            
            // تكوين نموذج المنتج
            final product = ProductModel(
              id: id,
              name: name,
              description: description,
              price: price,
              quantity: quantity,
              category: category,
              images: images,
              sku: 'SAMA-${id.replaceAll('sama_', '')}',
              isActive: true,
              createdAt: DateTime.now(),
              reorderPoint: 3,
              minimumStock: 5,
              imageUrl: imageUrl,
              manufacturingCost: manufacturingCost,
              supplier: 'SAMA Store',
            );
            
            products.add(product);
          } catch (e) {
            AppLogger.error('خطأ في استخراج بيانات المنتج من البطاقة رقم $i في الصفحة $page', e);
          }
        }
      }
      
      AppLogger.info('تم استخراج ${products.length} منتج من الصفحة $page');
    } catch (e) {
      AppLogger.error('خطأ أثناء تحليل HTML للصفحة $page', e);
    }
    
    return products;
  }

  // تحسين دالة تطبيع روابط الصور
  String _normalizeImageUrl(String src, String baseUrl) {
    // تجاهل الروابط الفارغة
    if (src.isEmpty) return '';
    
    // إذا كان URL كامل، استخدمه كما هو
    if (src.startsWith('http://') || src.startsWith('https://')) {
      return src;
    }
    
    // معالجة روابط بروتوكول نسبي
    if (src.startsWith('//')) {
      return 'https:$src';
    }
    
    // إذا كان URL نسبي، أضفه إلى URL الأساسي
    if (src.startsWith('/')) {
      // تأكد من عدم تكرار الشرطة
      return baseUrl + src;
    } else {
      // إضافة شرطة بين URL الأساسي والنسبي
      return '$baseUrl/$src';
    }
  }

  // Helper for extracting numeric values from text
  double _extractNumericValue(String text) {
    try {
      // Remove any currency symbols and non-numeric characters except decimal points
      final cleanedText = text.replaceAll(RegExp(r'[^\d\.,]'), '');
      final normalized = cleanedText.replaceAll(',', '.');
      return double.parse(normalized);
    } catch (e) {
      // If parsing fails, try to extract any number
      final match = RegExp(r'\d+(\.\d+)?').firstMatch(text);
      if (match != null) {
        return double.parse(match.group(0) ?? '0');
      }
      return 0.0;
    }
  }

  // Tracking-specific method
  Future<Map<String, dynamic>> getTrackingInfo(String trackingId) async {
    return await httpGet('tracking/$trackingId');
  }

  // Admin login for web dashboard
  Future<Map<String, String>> adminLogin() async {
    try {
      final response = await client.post(
        Uri.parse(AppConstants.authLoginUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'username': AppConstants.adminUsername,
          'password': AppConstants.adminPassword,
        }),
      );

      if (response.statusCode == 200) {
        // Extract cookies from response
        final cookies = response.headers['set-cookie'];
        if (cookies != null) {
          return {'cookies': cookies};
        } else {
          throw Exception('No cookies found in response');
        }
      } else {
        throw Exception('Failed to login: ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.error('Admin login error', e);
      rethrow;
    }
  }

  Future<Response<dynamic>> dioGet(String endpoint) async {
    try {
      return await dio.get(
        endpoint,
        options: Options(
          receiveTimeout:
              const Duration(milliseconds: AppConstants.connectTimeout),
        ),
      );
    } catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Response<dynamic>> dioPost(String endpoint, dynamic data) async {
    try {
      return await dio.post(
        endpoint,
        data: data,
        options: Options(
          receiveTimeout:
              const Duration(milliseconds: AppConstants.connectTimeout),
        ),
      );
    } catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Response<dynamic>> dioPut(String endpoint, dynamic data) async {
    try {
      return await dio.put(
        endpoint,
        data: data,
        options: Options(
          receiveTimeout:
              const Duration(milliseconds: AppConstants.connectTimeout),
        ),
      );
    } catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<List<Map<String, dynamic>>> fetchProducts() async {
    try {
      final Response<dynamic> response = await dioGet(AppConstants.productsApi);
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data as List<dynamic>? ?? [];
        return data.map((item) => item as Map<String, dynamic>).toList();
      }
      throw Exception('Failed to load products');
    } catch (e) {
      AppLogger.error('Error fetching products', e);
      // Return empty list for now to avoid crashes
      return [];
    }
  }

  // Get admin authentication token
  Future<String?> getAdminAuthToken() async {
    try {
      final Response<dynamic> response = await dioPost(
        AppConstants.authLoginUrl,
        {
          'username': AppConstants.adminUsername,
          'password': AppConstants.adminPassword,
        },
      );

      // Process response
      if (response.statusCode == 200 && response.data != null) {
        final Map<String, dynamic> data = response.data as Map<String, dynamic>;
        return data['token'] as String?;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error getting admin auth token', e);
      return null;
    }
  }

  Exception _handleDioError(dynamic e) {
    if (e is DioException) {
      return Exception('API Error: ${e.message}');
    }
    return Exception('Unknown error: $e');
  }

  // التحقق من توفر API
  Future<bool> checkApiAvailability() async {
    try {
      AppLogger.info('التحقق من توفر API: $baseUrl');

      final response = await client.get(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      final isAvailable = response.statusCode >= 200 && response.statusCode < 500;

      AppLogger.info('نتيجة التحقق من توفر API: $isAvailable (${response.statusCode})');

      return isAvailable;
    } catch (e) {
      AppLogger.error('خطأ في التحقق من توفر API', e);
      return false;
    }
  }

  // Helper method to convert JSON data to ProductModel list
  List<ProductModel> _convertToProductModels(List<dynamic> data) {
    AppLogger.info('تحويل بيانات JSON: عدد ${data.length} منتج');
    
    return data.map((item) {
      final Map<String, dynamic> productData = item as Map<String, dynamic>;
      
      // Debug log to see all keys available in the data
      AppLogger.info('مفاتيح بيانات المنتج: ${productData.keys.join(', ')}');
      
      // Add any missing fields with default values
      if (!productData.containsKey('id')) {
        productData['id'] = productData['id'] ?? productData['_id'] ?? productData['productId'] ?? 'product_${DateTime.now().millisecondsSinceEpoch}';
      }
      
      // Handle numeric fields
      if (!productData.containsKey('quantity') || productData['quantity'] == null) {
        productData['quantity'] = productData['quantity'] ?? 
                                  productData['stock'] ?? 
                                  productData['inventory'] ?? 
                                  productData['available'] ?? 0;
      }
      
      if (!productData.containsKey('price') || productData['price'] == null) {
        productData['price'] = productData['price'] ?? 
                              productData['sellingPrice'] ?? 
                              productData['salePrice'] ?? 
                              productData['retailPrice'] ?? 0.0;
      }
      
      if (!productData.containsKey('manufacturingCost') || productData['manufacturingCost'] == null) {
        productData['manufacturingCost'] = productData['manufacturingCost'] ?? 
                                          productData['purchasePrice'] ?? 
                                          productData['costPrice'] ?? 
                                          productData['buyingPrice'] ?? 
                                          (productData['price'] != null ? (productData['price'] * 0.7) : 0.0);
      }
      
      if (!productData.containsKey('discountPrice') || productData['discountPrice'] == null) {
        productData['discountPrice'] = productData['discountPrice'] ?? 
                                      productData['salePrice'] ?? 
                                      productData['specialPrice'] ?? 
                                      productData['promotionPrice'] ?? null;
      }
      
      if (!productData.containsKey('reorderPoint')) {
        productData['reorderPoint'] = productData['reorderPoint'] ?? 
                                     productData['reorderLevel'] ?? 
                                     productData['minStock'] ?? 5;
      }
      
      if (!productData.containsKey('minimumStock')) {
        productData['minimumStock'] = productData['minimumStock'] ?? 
                                     productData['minStock'] ?? 
                                     productData['minQuantity'] ?? 10;
      }
      
      // Handle image fields
      if (!productData.containsKey('imageUrl') || productData['imageUrl'] == null || productData['imageUrl'] == '') {
        productData['imageUrl'] = productData['imageUrl'] ?? 
                                 productData['image'] ?? 
                                 productData['productImage'] ?? 
                                 productData['thumbnail'] ?? 
                                 productData['photo'] ?? 
                                 'https://via.placeholder.com/300x300.png?text=No+Image';
      }
      
      if (!productData.containsKey('images') || productData['images'] == null) {
        if (productData['imageUrl'] != null) {
          productData['images'] = [productData['imageUrl']];
        } else if (productData['image'] != null) {
          productData['images'] = [productData['image']];
        } else if (productData['gallery'] != null && productData['gallery'] is List) {
          productData['images'] = productData['gallery'];
        } else {
          productData['images'] = ['https://via.placeholder.com/300x300.png?text=No+Image'];
        }
      }
      
      // Handle string fields
      if (!productData.containsKey('category') || productData['category'] == null || productData['category'] == '') {
        productData['category'] = productData['category'] ?? 
                                 productData['productCategory'] ?? 
                                 productData['categoryName'] ?? 
                                 productData['group'] ?? 'عام';
      }
      
      if (!productData.containsKey('supplier') || productData['supplier'] == null || productData['supplier'] == '') {
        productData['supplier'] = productData['supplier'] ?? 
                                 productData['vendor'] ?? 
                                 productData['manufacturer'] ?? 
                                 productData['brand'] ?? 'متجر النجف والثريات';
      }
      
      if (!productData.containsKey('description') || productData['description'] == null || productData['description'] == '') {
        productData['description'] = productData['description'] ?? 
                                    productData['productDescription'] ?? 
                                    productData['details'] ?? 
                                    productData['info'] ?? 
                                    'منتج من متجر النجف والثريات';
      }
      
      if (!productData.containsKey('sku') || productData['sku'] == null || productData['sku'] == '') {
        productData['sku'] = productData['sku'] ?? 
                            productData['productCode'] ?? 
                            productData['itemCode'] ?? 
                            productData['barcode'] ?? 
                            'SKU-${DateTime.now().millisecondsSinceEpoch}';
      }

      // Ensure dates are properly set
      if (!productData.containsKey('createdAt') || productData['createdAt'] == null) {
        productData['createdAt'] = DateTime.now().toIso8601String();
      }
      
      // Convert the boolean field
      if (!productData.containsKey('isActive')) {
        productData['isActive'] = productData['isActive'] ?? 
                                 productData['active'] ?? 
                                 productData['published'] ?? 
                                 productData['visible'] ?? true;
      }

      // Debug log to verify price and manufacturingCost
      AppLogger.info('بيانات السعر للمنتج: ${productData['name']} - سعر البيع: ${productData['price']}, سعر الشراء: ${productData['manufacturingCost']}');
      
      try {
        return ProductModel.fromJson(productData);
      } catch (e) {
        AppLogger.error('خطأ في تحويل بيانات المنتج', e);
        // Return a basic product as fallback
        return ProductModel(
          id: productData['id']?.toString() ?? 'error_${DateTime.now().millisecondsSinceEpoch}',
          name: productData['name']?.toString() ?? 'منتج غير معروف',
          description: productData['description']?.toString() ?? '',
          price: _parseDouble(productData['price']) ?? 0.0,
          quantity: _parseInt(productData['quantity']) ?? 0,
          category: productData['category']?.toString() ?? 'عام',
          images: _parseStringList(productData['images']) ?? ['https://via.placeholder.com/300x300.png?text=No+Image'],
          sku: productData['sku']?.toString() ?? 'SKU-ERROR',
          isActive: true,
          createdAt: DateTime.now(),
          reorderPoint: _parseInt(productData['reorderPoint']) ?? 5,
          minimumStock: _parseInt(productData['minimumStock']) ?? 10,
          manufacturingCost: _parseDouble(productData['manufacturingCost']),
          discountPrice: _parseDouble(productData['discountPrice']),
          supplier: productData['supplier']?.toString() ?? 'متجر النجف والثريات',
          imageUrl: productData['imageUrl']?.toString(),
        );
      }
    }).toList();
  }

  // Helper methods for safer parsing
  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    
    try {
      return double.parse(value.toString());
    } catch (e) {
      return null;
    }
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    
    try {
      return int.parse(value.toString());
    } catch (e) {
      return null;
    }
  }

  List<String>? _parseStringList(dynamic value) {
    if (value == null) return null;
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return null;
  }

  // Submit a new order
  Future<bool> submitOrder(dynamic order) async {
    try {
      AppLogger.info('Submitting new order: ${order.id}');
      
      final endpoint = '${AppConstants.ordersApi}/create';
      final response = await httpPost(endpoint, order.toJson());
      
      if (response['success']) {
        AppLogger.info('Order submitted successfully: ${order.id}');
        return true;
      } else {
        AppLogger.error('Failed to submit order', response['message'] ?? 'Unknown error');
        return false;
      }
    } catch (e) {
      AppLogger.error('Error submitting order', e);
      return false;
    }
  }

  // Cancel an existing order
  Future<bool> cancelOrder(String orderId) async {
    try {
      AppLogger.info('Cancelling order: $orderId');
      
      final endpoint = '${AppConstants.ordersApi}/$orderId/cancel';
      final response = await httpPut(endpoint, {'status': 'cancelled'});
      
      if (response['success']) {
        AppLogger.info('Order cancelled successfully: $orderId');
        return true;
      } else {
        AppLogger.error('Failed to cancel order', response['message'] ?? 'Unknown error');
        return false;
      }
    } catch (e) {
      AppLogger.error('Error cancelling order', e);
      return false;
    }
  }
}
