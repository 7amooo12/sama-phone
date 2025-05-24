import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart';
import 'dart:convert';
import '../models/product.dart';
import '../utils/logger.dart';
import '../utils/app_logger.dart';
import 'package:dio/dio.dart';
import '../models/product_model.dart';
import '../models/category_model.dart';

class SamaStoreService {
  final String baseUrl = 'https://samastock.pythonanywhere.com';
  final String storeUrl = 'https://samastock.pythonanywhere.com/store/';
  
  // Cache for products
  Map<String, dynamic> _cache = {};
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
          cachedData.map((item) => Product.fromJson(item))
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
      List<Product> products = [];
      
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
              
              // Try to extract category from the table if available
              String? productCategory;
              if (cells.length >= 4) {
                final categoryText = cells[3].text.trim();
                if (categoryText.isNotEmpty && !categoryText.contains('View') && !categoryText.contains('عرض')) {
                  productCategory = categoryText;
                }
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
      List<Product> filteredProducts = products.where((product) {
        bool passesFilter = true;
        
        if (category != null && category.isNotEmpty && category != 'All Categories') {
          // Make sure we have category data
          if (product.category == null || product.category!.isEmpty) {
            passesFilter = false;
          } else {
            // Compare categories case-insensitively with trimming
            passesFilter = product.category!.trim().toLowerCase() == category.trim().toLowerCase();
            
            // Log for debugging
            print('Comparing product category "${product.category}" with filter "$category" - Match: $passesFilter');
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
      
      // Log the results
      print('Found ${products.length} total products, ${filteredProducts.length} after filtering by category: $category');
      
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
      
      // Extract category (might not be available in card view)
      String? category;
      final categoryElement = card.querySelector('.category, .product-category');
      if (categoryElement != null) {
        category = categoryElement.text.trim();
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
  
  // Fetch categories from the store
  Future<List<String>> getCategories() async {
    try {
      // Check cache first
      final cacheKey = 'categories';
      final cachedData = _checkCache(cacheKey);
      if (cachedData != null) {
        return List<String>.from(cachedData);
      }
      
      // Fetch the store page
      final response = await http.get(Uri.parse(storeUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to load categories: ${response.statusCode}');
      }
      
      // Parse HTML
      final document = parser.parse(response.body);
      
      // Look for category dropdown or list
      final categories = <String>['All Categories'];
      
      // Try different selectors for category elements
      final categorySelectors = [
        'select[name="category"] option',
        '.category-filter option',
        '.category-list li',
        '.filters-container .category',
      ];
      
      for (var selector in categorySelectors) {
        final elements = document.querySelectorAll(selector);
        if (elements.isNotEmpty) {
          for (var element in elements) {
            final category = element.text.trim();
            if (category.isNotEmpty && 
                category != 'All Categories' && 
                category != 'All' && 
                !categories.contains(category)) {
              categories.add(category);
            }
          }
          break;  // Found categories, no need to continue with other selectors
        }
      }
      
      // Update cache
      _updateCache(cacheKey, categories);
      
      return categories;
    } catch (e) {
      AppLogger.error('Error fetching categories', e);
      return ['All Categories'];
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
        return Product.fromJson(cachedData);
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
