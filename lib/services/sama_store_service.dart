import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart';
import '../models/product.dart';
import '../utils/app_logger.dart';

class SamaStoreService {
  final String baseUrl = 'https://samastock.pythonanywhere.com';
  final String storeUrl = 'https://samastock.pythonanywhere.com/store/';

  // Cache for products
  final Map<String, dynamic> _cache = {};
  final int cacheDuration = 300000; // 5 minutes in milliseconds

  // Clear the cache
  void clearCache() {
    _cache.clear();
  }

  // Check if data is in cache and still valid
  dynamic _checkCache(String key) {
    if (_cache.containsKey(key)) {
      final cacheEntry = _cache[key];
      final timestamp = cacheEntry['timestamp'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;

      if (now - timestamp < cacheDuration) {
        return cacheEntry['data'];
      }
    }
    return null;
  }

  // Update cache with new data
  void _updateCache(String key, dynamic data) {
    _cache[key] = {
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  // Fetch all products from the store
  Future<List<Product>> getProducts({
    String? category,
    double? minPrice,
    double? maxPrice,
  }) async {
    try {
      // Check cache first
      final cacheKey = 'products_${category ?? ''}_${minPrice ?? ''}_${maxPrice ?? ''}';
      final cachedData = _checkCache(cacheKey);
      if (cachedData != null) {
        return List<Product>.from(
          (cachedData as List<dynamic>).map((item) => Product.fromJson(item as Map<String, dynamic>))
        );
      }

      // Fetch the store page
      final response = await http.get(Uri.parse(storeUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to load products: ${response.statusCode}');
      }

      // Parse HTML
      final document = parser.parse(response.body);

      // Extract products from the table or product cards
      final List<Product> products = [];

      // Try finding products in a table (new format)
      final table = document.querySelector('table');
      if (table != null) {
        final rows = table.querySelectorAll('tr');

        for (var i = 1; i < rows.length; i++) {  // Skip header row
          final row = rows[i];
          final cells = row.querySelectorAll('td');

          if (cells.length >= 3) {  // Ensure we have at least image, name and stock cells
            try {
              // Extract image
              String imageUrl = '';
              final imgElement = cells[0].querySelector('img');
              if (imgElement != null && imgElement.attributes.containsKey('src')) {
                imageUrl = imgElement.attributes['src'] ?? '';
                if (!imageUrl.startsWith('http')) {
                  imageUrl = '$baseUrl$imageUrl';
                }
              }

              // Extract name
              final name = cells[1].text.trim();

              // Extract stock
              final stockText = cells[2].text.trim();
              final stockMatch = RegExp(r'\d+').firstMatch(stockText);
              final stock = stockMatch != null ? int.parse(stockMatch.group(0) ?? '0') : 0;

              // Extract product ID from link
              int productId = 0;
              final linkElement = cells.length > 3 ? cells[3].querySelector('a') : null;
              if (linkElement != null && linkElement.attributes.containsKey('href')) {
                final href = linkElement.attributes['href'] ?? '';
                productId = _extractProductId(href);
              }

              // Enhanced category extraction from table
              String? productCategory;

              // Try different cell positions for category
              for (int i = 2; i < cells.length && i < 6; i++) {
                final cellText = cells[i].text.trim();
                if (cellText.isNotEmpty &&
                    !cellText.contains('View') &&
                    !cellText.contains('عرض') &&
                    !cellText.contains('\$') &&
                    !cellText.contains('ج.م') &&
                    !RegExp(r'^\d+$').hasMatch(cellText) && // Not just a number
                    cellText.length > 2 &&
                    cellText.length < 50) { // Reasonable category name length
                  productCategory = cellText;
                  AppLogger.info('📋 Found category "$productCategory" in table cell $i for product "$name"');
                  break;
                }
              }

              // If no category found in table, try to extract from any data attributes
              if (productCategory == null) {
                final row = cells[0].parent;
                if (row != null) {
                  final categoryAttr = row.attributes['data-category'] ??
                                     row.attributes['category'] ??
                                     row.attributes['class'];
                  if (categoryAttr != null && categoryAttr.isNotEmpty) {
                    productCategory = categoryAttr.trim();
                    AppLogger.info('🏷️ Found category "$productCategory" in row attributes for product "$name"');
                  }
                }
              }

              // Ensure every product has a category
              if (productCategory == null || productCategory.isEmpty) {
                productCategory = _assignCategoryByName(name);
                AppLogger.info('🔄 Auto-assigned category "$productCategory" to product "$name"');
              }

              // Create product with basic info (price will be 0 initially)
              final product = Product(
                id: productId,
                name: name,
                description: '',
                price: 0.0,  // Will update when fetching details
                imageUrl: imageUrl,
                category: productCategory,
                stock: stock,
                url: '$storeUrl/product/$productId',
                brand: 'SAMA',
              );

              products.add(product);
              AppLogger.info('✅ Added product: "$name" with category: "$productCategory"');
            } catch (e) {
              AppLogger.error('Error parsing product row', e);
              continue;
            }
          }
        }
      }

      // If no products found in table, try card format
      if (products.isEmpty) {
        final productCards = document.querySelectorAll('.product-card, .card, .item');

        for (var card in productCards) {
          final product = _extractProductFromCard(card);
          if (product != null) {
            products.add(product);
          }
        }
      }

      // Apply filters
      final List<Product> filteredProducts = products.where((product) {
        bool passesFilter = true;

        if (category != null && category.isNotEmpty && category != 'All Categories') {
          // Make sure we have category data
          if (product.category == null || product.category!.isEmpty) {
            passesFilter = false;
          } else {
            // Compare categories case-insensitively with trimming
            passesFilter = product.category!.trim().toLowerCase() == category.trim().toLowerCase();

            // Log for debugging
            debugPrint('Comparing product category "${product.category}" with filter "$category" - Match: $passesFilter');
          }
        }

        if (minPrice != null && product.price < minPrice) {
          passesFilter = false;
        }

        if (maxPrice != null && product.price > maxPrice) {
          passesFilter = false;
        }

        return passesFilter;
      }).toList();

      // Enhanced logging for debugging
      AppLogger.info('📊 Product filtering results:');
      AppLogger.info('   - Total products loaded: ${products.length}');
      AppLogger.info('   - Filter category: ${category ?? "none"}');
      AppLogger.info('   - Products after filtering: ${filteredProducts.length}');

      // Log category distribution for debugging
      final categoryCount = <String, int>{};
      for (var product in products) {
        final cat = product.category ?? 'null';
        categoryCount[cat] = (categoryCount[cat] ?? 0) + 1;
      }
      AppLogger.info('   - Category distribution: $categoryCount');

      // Update cache
      _updateCache(cacheKey, filteredProducts.map((p) => p.toJson()).toList());

      return filteredProducts;
    } catch (e) {
      AppLogger.error('Error fetching products', e);
      return [];
    }
  }

  // Extract product information from a product card
  Product? _extractProductFromCard(Element card) {
    try {
      // Extract product ID and URL
      int productId = 0;
      String productUrl = '';

      // Try different link selectors
      final linkSelectors = ['a.product-link', 'a.card-link', '.card-footer a', 'a'];
      for (var selector in linkSelectors) {
        final linkElement = card.querySelector(selector);
        if (linkElement != null && linkElement.attributes.containsKey('href')) {
          productUrl = linkElement.attributes['href'] ?? '';
          productId = _extractProductId(productUrl);
          break;
        }
      }

      if (productId == 0) return null;

      // Extract product name
      String name = 'Unknown Product';
      final nameSelectors = ['.product-name', '.card-title', 'h5', 'h4', 'h3'];
      for (var selector in nameSelectors) {
        final nameElement = card.querySelector(selector);
        if (nameElement != null) {
          name = nameElement.text.trim();
          break;
        }
      }

      // Extract price
      double price = 0.0;
      final priceSelectors = ['.product-price', '.price', '.card-text'];
      for (var selector in priceSelectors) {
        final priceElement = card.querySelector(selector);
        if (priceElement != null) {
          price = _extractPrice(priceElement.text.trim());
          break;
        }
      }

      // Extract image URL
      String imageUrl = '';
      final imgSelectors = ['img', '.card-img-top'];
      for (var selector in imgSelectors) {
        final imgElement = card.querySelector(selector);
        if (imgElement != null && imgElement.attributes.containsKey('src')) {
          imageUrl = imgElement.attributes['src'] ?? '';
          if (!imageUrl.startsWith('http')) {
            imageUrl = '$baseUrl$imageUrl';
          }
          break;
        }
      }

      // Extract stock
      int stock = 0;
      final stockSelectors = ['.product-stock', '.stock-info', '.inventory'];
      for (var selector in stockSelectors) {
        final stockElement = card.querySelector(selector);
        if (stockElement != null) {
          final stockText = stockElement.text.trim();
          final stockMatch = RegExp(r'\d+').firstMatch(stockText);
          if (stockMatch != null) {
            stock = int.parse(stockMatch.group(0) ?? '0');
            break;
          }
        }
      }

      // If still 0, look for stock in any text containing "stock" or "inventory"
      if (stock == 0) {
        final allElements = card.querySelectorAll('*');
        for (var element in allElements) {
          final text = element.text.toLowerCase();
          if (text.contains('stock') || text.contains('inventory') || text.contains('المخزون')) {
            final stockMatch = RegExp(r'\d+').firstMatch(text);
            if (stockMatch != null) {
              stock = int.parse(stockMatch.group(0) ?? '0');
              break;
            }
          }
        }
      }

      // Extract category (try multiple selectors)
      String? category;
      final categorySelectors = [
        '.category',
        '.product-category',
        '.badge',
        '.tag',
        '.chip',
        '.label',
        '[data-category]'
      ];

      for (var selector in categorySelectors) {
        final categoryElement = card.querySelector(selector);
        if (categoryElement != null) {
          final categoryText = categoryElement.text.trim();
          if (categoryText.isNotEmpty &&
              !categoryText.toLowerCase().contains('price') &&
              !categoryText.toLowerCase().contains('stock') &&
              !categoryText.toLowerCase().contains('add') &&
              categoryText.length > 2) {
            category = categoryText;
            break;
          }
        }
      }

      // If still no category, try data attributes
      if (category == null) {
        final dataCategory = card.attributes['data-category'];
        if (dataCategory != null && dataCategory.isNotEmpty) {
          category = dataCategory.trim();
        }
      }

      // Use helper method for category assignment
      if (category == null || category.isEmpty) {
        category = _assignCategoryByName(name);
        AppLogger.info('🏷️ Assigned category "$category" to product "$name" based on name pattern');
      }

      return Product(
        id: productId,
        name: name,
        description: '',  // Will be filled when fetching details
        price: price,
        imageUrl: imageUrl,
        category: category,
        stock: stock,
        url: productUrl.startsWith('http') ? productUrl : '$storeUrl$productUrl',
        brand: 'SAMA',
      );
    } catch (e) {
      AppLogger.error('Error extracting product from card', e);
      return null;
    }
  }

  // Extract product ID from URL
  int _extractProductId(String url) {
    try {
      final regexp = RegExp(r'/product/(\d+)');
      final match = regexp.firstMatch(url);
      if (match != null && match.groupCount >= 1) {
        return int.parse(match.group(1) ?? '0');
      }

      // If no match, try extracting any number
      final numMatch = RegExp(r'(\d+)').firstMatch(url);
      if (numMatch != null) {
        return int.parse(numMatch.group(1) ?? '0');
      }

      return 0;
    } catch (e) {
      return 0;
    }
  }

  // Extract price from string
  double _extractPrice(String text) {
    try {
      // Remove any currency symbols and non-numeric characters except decimal points
      final cleanedText = text.replaceAll(RegExp(r'[^\d.]'), '');
      return double.parse(cleanedText);
    } catch (e) {
      // If parsing fails, try to extract any number
      final match = RegExp(r'\d+(\.\d+)?').firstMatch(text);
      if (match != null) {
        return double.parse(match.group(0) ?? '0');
      }
      return 0.0;
    }
  }

  // Helper method to assign category based on product name (Arabic categories for SAMA store)
  String _assignCategoryByName(String productName) {
    final name = productName.toLowerCase();

    // Lighting and pendant patterns (دلاية)
    if (name.contains('pendant') || name.contains('hanging') ||
        name.contains('دلاية') || name.contains('معلق') ||
        name.contains('chandelier') || name.contains('شاندليه')) {
      return 'دلاية';
    }
    // Wall lights and appliques (ابليك)
    else if (name.contains('wall') || name.contains('sconce') ||
             name.contains('ابليك') || name.contains('حائط') ||
             name.contains('applique') || name.contains('جداري')) {
      return 'ابليك';
    }
    // Single pendant lights (دلاية مفرد)
    else if (name.contains('single') || name.contains('مفرد') ||
             name.contains('واحد') || name.contains('فردي')) {
      return 'دلاية مفرد';
    }
    // Table lamps (اباجورة)
    else if (name.contains('table') || name.contains('desk') ||
             name.contains('اباجورة') || name.contains('طاولة') ||
             name.contains('مكتب') || name.contains('lamp')) {
      return 'اباجورة';
    }
    // Crystal lights (كريستال)
    else if (name.contains('crystal') || name.contains('كريستال') ||
             name.contains('glass') || name.contains('زجاج') ||
             name.contains('شفاف') || name.contains('بلوري')) {
      return 'كريستال';
    }
    // Lampshades (لامبدير)
    else if (name.contains('shade') || name.contains('لامبدير') ||
             name.contains('غطاء') || name.contains('كشاف') ||
             name.contains('lampshade') || name.contains('cover')) {
      return 'لامبدير';
    }
    // Featured or special products (منتجات مميزه)
    else if (name.contains('featured') || name.contains('special') ||
             name.contains('مميز') || name.contains('خاص') ||
             name.contains('premium') || name.contains('luxury')) {
      return 'منتجات مميزه';
    }
    // Default to pendant lights (most common lighting category)
    else {
      return 'دلاية';
    }
  }

  // Fetch categories from the store
  Future<List<String>> getCategories() async {
    try {
      // Check cache first
      const cacheKey = 'categories';
      final cachedData = _checkCache(cacheKey);
      if (cachedData != null) {
        return List<String>.from(cachedData as List<dynamic>);
      }

      // First try to get categories from the store page
      final response = await http.get(Uri.parse(storeUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to load categories: ${response.statusCode}');
      }

      // Parse HTML
      final document = parser.parse(response.body);

      // Look for category dropdown or list
      final categories = <String>[];

      // Try different selectors for category elements
      final categorySelectors = [
        'select[name="category"] option',
        '.category-filter option',
        '.category-list li',
        '.filters-container .category',
        '.nav-item .category',
        '.dropdown-item',
      ];

      for (var selector in categorySelectors) {
        final elements = document.querySelectorAll(selector);
        if (elements.isNotEmpty) {
          for (var element in elements) {
            final category = element.text.trim();
            if (category.isNotEmpty &&
                category != 'All Categories' &&
                category != 'All' &&
                category != 'الكل' &&
                !categories.contains(category)) {
              categories.add(category);
            }
          }
          if (categories.isNotEmpty) {
            break;  // Found categories, no need to continue with other selectors
          }
        }
      }

      // If no categories found from page structure, extract from products
      if (categories.isEmpty) {
        AppLogger.info('No categories found in page structure, extracting from products...');
        final products = await getProducts();
        final productCategories = <String>{};

        for (var product in products) {
          if (product.category != null && product.category!.isNotEmpty) {
            productCategories.add(product.category!.trim());
          }
        }

        categories.addAll(productCategories.toList());
        AppLogger.info('Extracted ${categories.length} categories from products: $categories');
      }

      // If still no categories, provide the correct Arabic SAMA store categories
      if (categories.isEmpty) {
        categories.addAll([
          'دلاية',           // Pendant
          'ابليك',          // Wall Light/Applique
          'دلاية مفرد',      // Single Pendant
          'اباجورة',        // Table Lamp
          'كريستال',        // Crystal
          'لامبدير',        // Lampshade
          'منتجات مميزه'     // Featured Products
        ]);
        AppLogger.info('Using default Arabic SAMA store categories as fallback');
      }

      // Update cache
      _updateCache(cacheKey, categories);

      return categories;
    } catch (e) {
      AppLogger.error('Error fetching categories', e);
      // Return correct Arabic SAMA store categories as fallback
      return [
        'دلاية',           // Pendant
        'ابليك',          // Wall Light/Applique
        'دلاية مفرد',      // Single Pendant
        'اباجورة',        // Table Lamp
        'كريستال',        // Crystal
        'لامبدير',        // Lampshade
        'منتجات مميزه'     // Featured Products
      ];
    }
  }

  // Search products
  Future<List<Product>> searchProducts(String query) async {
    try {
      // Get all products first
      final allProducts = await getProducts();

      // Filter by query
      return allProducts.where((product) {
        return product.name.toLowerCase().contains(query.toLowerCase()) ||
               (product.description?.toLowerCase().contains(query.toLowerCase()) ?? false) ||
               (product.category?.toLowerCase().contains(query.toLowerCase()) ?? false);
      }).toList();
    } catch (e) {
      AppLogger.error('Error searching products', e);
      return [];
    }
  }

  // Get detailed product information
  Future<Product?> getProduct(int productId) async {
    try {
      // Check cache first
      final cacheKey = 'product_$productId';
      final cachedData = _checkCache(cacheKey);
      if (cachedData != null) {
        return Product.fromJson(cachedData as Map<String, dynamic>);
      }

      // Fetch the product page
      final url = '$storeUrl/product/$productId';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('Failed to load product: ${response.statusCode}');
      }

      // Parse HTML
      final document = parser.parse(response.body);

      // Extract product details
      final nameElement = document.querySelector('.product-title, .product-name, h1');
      final name = nameElement != null ? nameElement.text.trim() : 'Unknown Product';

      // Extract description
      String description = '';
      final descriptionSelectors = ['.product-description', '.description', '.product-details', '#product-details'];
      for (var selector in descriptionSelectors) {
        final descElement = document.querySelector(selector);
        if (descElement != null) {
          description = descElement.text.trim();
          break;
        }
      }

      // Extract price
      double price = 0.0;
      final priceSelectors = ['.product-price', '.price', '.current-price', '.sale-price'];
      for (var selector in priceSelectors) {
        final priceElement = document.querySelector(selector);
        if (priceElement != null) {
          price = _extractPrice(priceElement.text.trim());
          break;
        }
      }

      // Extract image URL
      String imageUrl = '';
      final imgElement = document.querySelector('.product-image img, .product-main-image, #product-image');
      if (imgElement != null && imgElement.attributes.containsKey('src')) {
        imageUrl = imgElement.attributes['src'] ?? '';
        if (!imageUrl.startsWith('http')) {
          imageUrl = '$baseUrl$imageUrl';
        }
      }

      // If no specific product image found, try any image
      if (imageUrl.isEmpty) {
        final allImages = document.querySelectorAll('img');
        for (var img in allImages) {
          if (img.attributes.containsKey('src')) {
            final src = img.attributes['src'] ?? '';
            if (!src.contains('logo') && !src.contains('icon')) {
              imageUrl = src;
              if (!imageUrl.startsWith('http')) {
                imageUrl = '$baseUrl$imageUrl';
              }
              break;
            }
          }
        }
      }

      // Extract category
      String? category;
      final categoryElement = document.querySelector('.product-category, .category, .breadcrumb-item:nth-child(2)');
      if (categoryElement != null) {
        category = categoryElement.text.trim();
      }

      // Extract stock
      int stock = 0;
      final stockSelectors = ['.product-stock', '.stock', '.inventory', '.availability'];
      for (var selector in stockSelectors) {
        final stockElement = document.querySelector(selector);
        if (stockElement != null) {
          final stockText = stockElement.text.trim();
          final stockMatch = RegExp(r'\d+').firstMatch(stockText);
          if (stockMatch != null) {
            stock = int.parse(stockMatch.group(0) ?? '0');
            break;
          }
        }
      }

      // If not found yet, look for any text containing "stock" or "inventory"
      if (stock == 0) {
        final allElements = document.querySelectorAll('*');
        for (var element in allElements) {
          final text = element.text.toLowerCase();
          if (text.contains('stock') || text.contains('inventory') || text.contains('المخزون')) {
            final stockMatch = RegExp(r'\d+').firstMatch(text);
            if (stockMatch != null) {
              stock = int.parse(stockMatch.group(0) ?? '0');
              break;
            }
          }
        }
      }

      // Create product object
      final product = Product(
        id: productId,
        name: name,
        description: description,
        price: price,
        imageUrl: imageUrl,
        category: category,
        stock: stock,
        url: url,
        brand: 'SAMA',
      );

      // Update cache
      _updateCache(cacheKey, product.toJson());

      return product;
    } catch (e) {
      AppLogger.error('Error fetching product details', e);
      return null;
    }
  }
}
