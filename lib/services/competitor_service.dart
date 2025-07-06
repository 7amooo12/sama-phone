import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../models/competitor_product.dart';

class CompetitorService {
  static const String _wadiHomeUrl = 'https://wadihome.com/collections/chandeliers/products.json';
  static const String _anaratUrl = 'https://scraper.pythonanywhere.com/products';
  static const String _nawrlyUrl = 'https://scraper.pythonanywhere.com/nawrly';
  static const String _lamaisonUrl = 'https://scraper.pythonanywhere.com/lamaison';

  static Future<List<CompetitorProduct>> fetchWadiHomeProducts() async {
    try {
      developer.log('Fetching WadiHome products from: $_wadiHomeUrl', name: 'CompetitorService');

      final response = await http.get(
        Uri.parse(_wadiHomeUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept': 'application/json',
        },
      );

      developer.log('WadiHome API response status: ${response.statusCode}', name: 'CompetitorService');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = (json.decode(response.body) as Map<String, dynamic>?) ?? <String, dynamic>{};
        developer.log('WadiHome API response keys: ${data.keys}', name: 'CompetitorService');

        if (data.containsKey('products')) {
          final List<dynamic> productsJson = (data['products'] as List<dynamic>?) ?? <dynamic>[];
          developer.log('Found ${productsJson.length} WadiHome products', name: 'CompetitorService');

          final List<CompetitorProduct> products = productsJson
              .map((json) => CompetitorProduct.fromJson((json as Map<String, dynamic>?) ?? <String, dynamic>{}))
              .toList();

          developer.log('Successfully parsed ${products.length} WadiHome products', name: 'CompetitorService');
          developer.log('Sample product titles:', name: 'CompetitorService');
          for (int i = 0; i < (products.length > 5 ? 5 : products.length); i++) {
            developer.log('${i + 1}. ${products[i].title}', name: 'CompetitorService');
          }
          return products;
        } else {
          developer.log('No products key found in WadiHome response', name: 'CompetitorService');
          return [];
        }
      } else {
        developer.log('WadiHome API error: ${response.statusCode} - ${response.body}', name: 'CompetitorService');
        throw Exception('Failed to load WadiHome products: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Error fetching WadiHome products: $e', name: 'CompetitorService');
      throw Exception('Error fetching WadiHome products: $e');
    }
  }

  static Future<List<CompetitorProduct>> fetchAnaratProducts() async {
    try {
      developer.log('Fetching Anarat products from: $_anaratUrl', name: 'CompetitorService');

      final response = await http.get(
        Uri.parse(_anaratUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept': 'application/json',
        },
      );

      developer.log('Anarat API response status: ${response.statusCode}', name: 'CompetitorService');

      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);
        developer.log('Anarat API response type: ${data.runtimeType}', name: 'CompetitorService');

        List<dynamic> productsJson = [];

        // Check if data is a list directly or contains products key
        if (data is List) {
          productsJson = data;
          developer.log('Data is a direct list with ${productsJson.length} items', name: 'CompetitorService');
        } else if (data is Map && data.containsKey('products')) {
          productsJson = (data['products'] as List<dynamic>?) ?? <dynamic>[];
          developer.log('Found products key with ${productsJson.length} items', name: 'CompetitorService');
        } else if (data is Map) {
          developer.log('Data is a map with keys: ${data.keys}', name: 'CompetitorService');
          // Try to find any key that might contain products
          for (var key in data.keys) {
            if (data[key] is List) {
              productsJson = (data[key] as List<dynamic>?) ?? <dynamic>[];
              developer.log('Using key "$key" with ${productsJson.length} items', name: 'CompetitorService');
              break;
            }
          }
        }

        if (productsJson.isNotEmpty) {
          developer.log('Found ${productsJson.length} Anarat products', name: 'CompetitorService');

          final List<CompetitorProduct> products = productsJson
              .map((json) => _convertAnaratToCompetitorProduct(json))
              .where((product) => product != null)
              .cast<CompetitorProduct>()
              .toList();

          developer.log('Successfully parsed ${products.length} Anarat products', name: 'CompetitorService');
          developer.log('Sample Anarat product titles:', name: 'CompetitorService');
          for (int i = 0; i < (products.length > 5 ? 5 : products.length); i++) {
            developer.log('${i + 1}. ${products[i].title}', name: 'CompetitorService');
          }
          return products;
        } else {
          developer.log('No products found in Anarat response', name: 'CompetitorService');
          return [];
        }
      } else {
        developer.log('Anarat API error: ${response.statusCode} - ${response.body}', name: 'CompetitorService');
        throw Exception('Failed to load Anarat products: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Error fetching Anarat products: $e', name: 'CompetitorService');
      throw Exception('Error fetching Anarat products: $e');
    }
  }

  static Future<List<CompetitorProduct>> fetchNawrlyProducts() async {
    try {
      developer.log('Fetching Nawrly products from: $_nawrlyUrl', name: 'CompetitorService');

      final response = await http.get(
        Uri.parse(_nawrlyUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept': 'application/json',
        },
      );

      developer.log('Nawrly API response status: ${response.statusCode}', name: 'CompetitorService');

      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);
        developer.log('Nawrly API response type: ${data.runtimeType}', name: 'CompetitorService');

        List<dynamic> productsJson = [];

        // Check if data is a list directly or contains products key
        if (data is List) {
          productsJson = data;
          developer.log('Data is a direct list with ${productsJson.length} items', name: 'CompetitorService');
        } else if (data is Map && data.containsKey('products')) {
          productsJson = (data['products'] as List<dynamic>?) ?? <dynamic>[];
          developer.log('Found products key with ${productsJson.length} items', name: 'CompetitorService');
        } else if (data is Map) {
          developer.log('Data is a map with keys: ${data.keys}', name: 'CompetitorService');
          // Try to find any key that might contain products
          for (var key in data.keys) {
            if (data[key] is List) {
              productsJson = (data[key] as List<dynamic>?) ?? <dynamic>[];
              developer.log('Using key "$key" with ${productsJson.length} items', name: 'CompetitorService');
              break;
            }
          }
        }

        if (productsJson.isNotEmpty) {
          developer.log('Found ${productsJson.length} Nawrly products', name: 'CompetitorService');

          final List<CompetitorProduct> products = productsJson
              .map((json) => _convertNawrlyToCompetitorProduct(json))
              .where((product) => product != null)
              .cast<CompetitorProduct>()
              .toList();

          developer.log('Successfully parsed ${products.length} Nawrly products', name: 'CompetitorService');
          developer.log('Sample Nawrly product titles:', name: 'CompetitorService');
          for (int i = 0; i < (products.length > 5 ? 5 : products.length); i++) {
            developer.log('${i + 1}. ${products[i].title}', name: 'CompetitorService');
          }
          return products;
        } else {
          developer.log('No products found in Nawrly response', name: 'CompetitorService');
          return [];
        }
      } else {
        developer.log('Nawrly API error: ${response.statusCode} - ${response.body}', name: 'CompetitorService');
        throw Exception('Failed to load Nawrly products: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Error fetching Nawrly products: $e', name: 'CompetitorService');
      throw Exception('Error fetching Nawrly products: $e');
    }
  }

  static Future<List<CompetitorProduct>> fetchLamaisonProducts() async {
    try {
      developer.log('Fetching Lamaison products from: $_lamaisonUrl', name: 'CompetitorService');

      final response = await http.get(
        Uri.parse(_lamaisonUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept': 'application/json',
        },
      );

      developer.log('Lamaison API response status: ${response.statusCode}', name: 'CompetitorService');

      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);
        developer.log('Lamaison API response type: ${data.runtimeType}', name: 'CompetitorService');

        List<dynamic> productsJson = [];

        // Check if data is a list directly or contains products key
        if (data is List) {
          productsJson = data;
          developer.log('Data is a direct list with ${productsJson.length} items', name: 'CompetitorService');
        } else if (data is Map && data.containsKey('products')) {
          productsJson = (data['products'] as List<dynamic>?) ?? <dynamic>[];
          developer.log('Found products key with ${productsJson.length} items', name: 'CompetitorService');
        } else if (data is Map) {
          developer.log('Data is a map with keys: ${data.keys}', name: 'CompetitorService');
          // Try to find any key that might contain products
          for (var key in data.keys) {
            if (data[key] is List) {
              productsJson = (data[key] as List<dynamic>?) ?? <dynamic>[];
              developer.log('Using key "$key" with ${productsJson.length} items', name: 'CompetitorService');
              break;
            }
          }
        }

        if (productsJson.isNotEmpty) {
          developer.log('Found ${productsJson.length} Lamaison products', name: 'CompetitorService');

          final List<CompetitorProduct> products = productsJson
              .map((json) => _convertLamaisonToCompetitorProduct(json))
              .where((product) => product != null)
              .cast<CompetitorProduct>()
              .toList();

          developer.log('Successfully parsed ${products.length} Lamaison products', name: 'CompetitorService');
          developer.log('Sample Lamaison product titles:', name: 'CompetitorService');
          for (int i = 0; i < (products.length > 5 ? 5 : products.length); i++) {
            developer.log('${i + 1}. ${products[i].title}', name: 'CompetitorService');
          }
          return products;
        } else {
          developer.log('No products found in Lamaison response', name: 'CompetitorService');
          return [];
        }
      } else {
        developer.log('Lamaison API error: ${response.statusCode} - ${response.body}', name: 'CompetitorService');
        throw Exception('Failed to load Lamaison products: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Error fetching Lamaison products: $e', name: 'CompetitorService');
      throw Exception('Error fetching Lamaison products: $e');
    }
  }

  static CompetitorProduct? _convertLamaisonToCompetitorProduct(dynamic json) {
    try {
      // Extract title and decode Unicode characters
      String title = json['title']?.toString() ?? json['name']?.toString() ?? '';

      // Decode Unicode escape sequences like \u0646\u062c\u0641\u0647
      if (title.contains('\\u')) {
        try {
          // Replace Unicode escape sequences
          title = title.replaceAllMapped(RegExp(r'\\u([0-9a-fA-F]{4})'), (match) {
            final int codeUnit = int.parse(match.group(1)!, radix: 16);
            return String.fromCharCode(codeUnit);
          });
        } catch (e) {
          developer.log('Error decoding Unicode in title: $e', name: 'CompetitorService');
        }
      }

      if (title.isEmpty && json['image'] != null) {
        final String imageUrl = json['image'].toString();
        // Extract filename from URL and clean it up
        final String filename = imageUrl.split('/').last.split('.').first;
        title = filename.replaceAll('-', ' ').replaceAll('_', ' ');
        // Remove numbers and common suffixes
        title = title.replaceAll(RegExp(r'\d+'), '').replaceAll('optimized', '').trim();
        if (title.isEmpty) {
          title = 'منتج lamaison';
        }
      }

      return CompetitorProduct(
        id: (json['id'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
        title: title.isNotEmpty ? title : 'منتج lamaison',
        handle: (json['slug'] as String?) ?? (json['handle'] as String?) ?? '',
        bodyHtml: (json['description'] as String?) ?? (json['body_html'] as String?) ?? '',
        publishedAt: (json['created_at'] as String?) ?? (json['published_at'] as String?) ?? DateTime.now().toIso8601String(),
        createdAt: (json['created_at'] as String?) ?? DateTime.now().toIso8601String(),
        updatedAt: (json['updated_at'] as String?) ?? DateTime.now().toIso8601String(),
        vendor: (json['brand'] as String?) ?? (json['vendor'] as String?) ?? 'lamaison',
        productType: (json['category'] as String?) ?? (json['product_type'] as String?) ?? 'أثاث منزلي',
        tags: _extractTagsForLamaison(json),
        variants: _extractVariantsForLamaison(json),
        images: _extractImagesForLamaison(json),
        options: _extractOptions(json),
      );
    } catch (e) {
      developer.log('Error converting Lamaison product: $e', name: 'CompetitorService');
      return null;
    }
  }

  static CompetitorProduct? _convertNawrlyToCompetitorProduct(dynamic json) {
    try {
      // Extract title from image URL if title is empty
      String title = json['title']?.toString() ?? json['name']?.toString() ?? '';
      if (title.isEmpty && json['image'] != null) {
        final String imageUrl = json['image'].toString();
        // Extract filename from URL and clean it up
        final String filename = imageUrl.split('/').last.split('.').first;
        title = filename.replaceAll('-', ' ').replaceAll('_', ' ');
        // Remove numbers and common suffixes
        title = title.replaceAll(RegExp(r'\d+'), '').replaceAll('optimized', '').trim();
        if (title.isEmpty) {
          title = 'منتج نورلي';
        }
      }

      return CompetitorProduct(
        id: (json['id'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
        title: title.isNotEmpty ? title : 'منتج نورلي',
        handle: (json['slug'] as String?) ?? (json['handle'] as String?) ?? '',
        bodyHtml: (json['description'] as String?) ?? (json['body_html'] as String?) ?? '',
        publishedAt: (json['created_at'] as String?) ?? (json['published_at'] as String?) ?? DateTime.now().toIso8601String(),
        createdAt: (json['created_at'] as String?) ?? DateTime.now().toIso8601String(),
        updatedAt: (json['updated_at'] as String?) ?? DateTime.now().toIso8601String(),
        vendor: (json['brand'] as String?) ?? (json['vendor'] as String?) ?? 'نورلي',
        productType: (json['category'] as String?) ?? (json['product_type'] as String?) ?? 'إنارة',
        tags: _extractTagsForNawrly(json),
        variants: _extractVariantsForNawrly(json),
        images: _extractImagesForNawrly(json),
        options: _extractOptions(json),
      );
    } catch (e) {
      developer.log('Error converting Nawrly product: $e', name: 'CompetitorService');
      return null;
    }
  }

  static List<String> _extractTagsForLamaison(dynamic json) {
    if (json['tags'] is List) {
      return List<String>.from((json['tags'] as Iterable<dynamic>?) ?? <dynamic>[]);
    } else if (json['tags'] is String) {
      return (json['tags'] as String).split(',').map((tag) => tag.trim()).toList();
    } else if (json['category'] != null) {
      return [json['category'].toString()];
    }
    return ['lamaison', 'أثاث منزلي'];
  }

  static List<String> _extractTagsForNawrly(dynamic json) {
    if (json['tags'] is List) {
      return List<String>.from((json['tags'] as Iterable<dynamic>?) ?? <dynamic>[]);
    } else if (json['tags'] is String) {
      return (json['tags'] as String).split(',').map((tag) => tag.trim()).toList();
    } else if (json['category'] != null) {
      return [json['category'].toString()];
    }
    return ['نورلي', 'إنارة'];
  }

  static List<CompetitorVariant> _extractVariantsForLamaison(dynamic json) {
    final List<CompetitorVariant> variants = [];

    // Try to extract price from different possible fields
    String price = '0.00';
    if (json['price'] != null) {
      String priceText = json['price'].toString();

      // Decode Unicode escape sequences in price text
      if (priceText.contains('\\u')) {
        try {
          priceText = priceText.replaceAllMapped(RegExp(r'\\u([0-9a-fA-F]{4})'), (match) {
            final int codeUnit = int.parse(match.group(1)!, radix: 16);
            return String.fromCharCode(codeUnit);
          });
        } catch (e) {
          developer.log('Error decoding Unicode in price: $e', name: 'CompetitorService');
        }
      }

      // Extract price from formats like "550٫00EGP" or "1٬350٫00EGP"
      final RegExp arabicPriceRegex = RegExp(r'([\d٬٫]+)EGP');
      final RegExp simplePriceRegex = RegExp(r'([\d,\.]+)\s*EGP');

      final Match? arabicMatch = arabicPriceRegex.firstMatch(priceText);
      final Match? simpleMatch = simplePriceRegex.firstMatch(priceText);

      if (arabicMatch != null) {
        // Replace Arabic decimal separators with standard ones
        price = arabicMatch.group(1)!
            .replaceAll('٬', '') // Remove Arabic thousands separator
            .replaceAll('٫', '.'); // Replace Arabic decimal separator
      } else if (simpleMatch != null) {
        price = simpleMatch.group(1)!.replaceAll(',', '');
      } else {
        // Try to extract any number from the price text
        final RegExp numberRegex = RegExp(r'([\d]+)');
        final Match? numberMatch = numberRegex.firstMatch(priceText);
        if (numberMatch != null) {
          price = numberMatch.group(1)!;
        }
      }
    } else if (json['cost'] != null) {
      price = json['cost'].toString();
    } else if (json['amount'] != null) {
      price = json['amount'].toString();
    }

    variants.add(CompetitorVariant(
      id: (json['id'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      title: (json['name'] as String?) ?? (json['title'] as String?) ?? 'الافتراضي',
      option1: null,
      option2: null,
      option3: null,
      sku: json['sku']?.toString(),
      requiresShipping: true,
      taxable: true,
      available: (json['available'] as bool?) ?? (json['in_stock'] as bool?) ?? true,
      price: price,
      grams: 0,
      compareAtPrice: '0.00',
      position: 1,
      productId: (json['id'] as int?) ?? 0,
      createdAt: (json['created_at'] as String?) ?? DateTime.now().toIso8601String(),
      updatedAt: (json['updated_at'] as String?) ?? DateTime.now().toIso8601String(),
    ));

    return variants;
  }

  static List<CompetitorVariant> _extractVariantsForNawrly(dynamic json) {
    final List<CompetitorVariant> variants = [];

    // Try to extract price from different possible fields
    String price = '0.00';
    if (json['price'] != null) {
      final String priceText = json['price'].toString();
      // Extract current price from complex price text
      // Look for Arabic "السعر الحالي هو: X EGP" or "Current price is: X EGP" or just "X EGP"
      final RegExp arabicCurrentPriceRegex = RegExp(r'السعر الحالي هو: ([\d,]+)');
      final RegExp currentPriceRegex = RegExp(r'Current price is: ([\d,]+)');
      final RegExp simplePriceRegex = RegExp(r'([\d,]+)\s*EGP');

      final Match? arabicMatch = arabicCurrentPriceRegex.firstMatch(priceText);
      final Match? currentMatch = currentPriceRegex.firstMatch(priceText);

      if (arabicMatch != null) {
        price = arabicMatch.group(1)!.replaceAll(',', '');
      } else if (currentMatch != null) {
        price = currentMatch.group(1)!.replaceAll(',', '');
      } else {
        // Try to find any price in EGP
        final Iterable<Match> allMatches = simplePriceRegex.allMatches(priceText);
        if (allMatches.isNotEmpty) {
          // Take the last price found (usually the current price)
          price = allMatches.last.group(1)!.replaceAll(',', '');
        }
      }
    } else if (json['cost'] != null) {
      price = json['cost'].toString();
    } else if (json['amount'] != null) {
      price = json['amount'].toString();
    }

    variants.add(CompetitorVariant(
      id: (json['id'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      title: (json['name'] as String?) ?? (json['title'] as String?) ?? 'الافتراضي',
      option1: null,
      option2: null,
      option3: null,
      sku: json['sku']?.toString(),
      requiresShipping: true,
      taxable: true,
      available: (json['available'] as bool?) ?? (json['in_stock'] as bool?) ?? true,
      price: price,
      grams: 0,
      compareAtPrice: '0.00',
      position: 1,
      productId: (json['id'] as int?) ?? 0,
      createdAt: (json['created_at'] as String?) ?? DateTime.now().toIso8601String(),
      updatedAt: (json['updated_at'] as String?) ?? DateTime.now().toIso8601String(),
    ));

    return variants;
  }

  static List<CompetitorImage> _extractImagesForLamaison(dynamic json) {
    final List<CompetitorImage> images = [];

    // Try different possible image field names
    String? imageUrl;
    if (json['image'] != null) {
      imageUrl = json['image'].toString();
    } else if (json['image_url'] != null) {
      imageUrl = json['image_url'].toString();
    } else if (json['photo'] != null) {
      imageUrl = json['photo'].toString();
    } else if (json['picture'] != null) {
      imageUrl = json['picture'].toString();
    }

    if (imageUrl != null && imageUrl.isNotEmpty) {
      images.add(CompetitorImage(
        id: DateTime.now().millisecondsSinceEpoch,
        createdAt: DateTime.now().toIso8601String(),
        position: 1,
        updatedAt: DateTime.now().toIso8601String(),
        productId: (json['id'] as int?) ?? 0,
        variantIds: [],
        src: imageUrl,
        width: 800,
        height: 600,
      ));
    }

    return images;
  }

  static List<CompetitorImage> _extractImagesForNawrly(dynamic json) {
    final List<CompetitorImage> images = [];

    // Try different possible image field names
    String? imageUrl;
    if (json['image'] != null) {
      imageUrl = json['image'].toString();
    } else if (json['image_url'] != null) {
      imageUrl = json['image_url'].toString();
    } else if (json['photo'] != null) {
      imageUrl = json['photo'].toString();
    } else if (json['picture'] != null) {
      imageUrl = json['picture'].toString();
    }

    if (imageUrl != null && imageUrl.isNotEmpty) {
      images.add(CompetitorImage(
        id: DateTime.now().millisecondsSinceEpoch,
        createdAt: DateTime.now().toIso8601String(),
        position: 1,
        updatedAt: DateTime.now().toIso8601String(),
        productId: (json['id'] as int?) ?? 0,
        variantIds: [],
        src: imageUrl,
        width: 800,
        height: 600,
      ));
    }

    return images;
  }

  static CompetitorProduct? _convertAnaratToCompetitorProduct(dynamic json) {
    try {
      // Extract title from image URL if title is empty
      String title = json['title']?.toString() ?? json['name']?.toString() ?? '';
      if (title.isEmpty && json['image'] != null) {
        final String imageUrl = json['image'].toString();
        // Extract filename from URL and clean it up
        final String filename = imageUrl.split('/').last.split('.').first;
        title = filename.replaceAll('-', ' ').replaceAll('_', ' ');
        // Remove numbers and common suffixes
        title = title.replaceAll(RegExp(r'\d+'), '').replaceAll('optimized', '').trim();
        if (title.isEmpty) {
          title = 'منتج إنارة';
        }
      }

      return CompetitorProduct(
        id: (json['id'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
        title: title.isNotEmpty ? title : 'منتج إنارة',
        handle: (json['slug'] as String?) ?? (json['handle'] as String?) ?? '',
        bodyHtml: (json['description'] as String?) ?? (json['body_html'] as String?) ?? '',
        publishedAt: (json['created_at'] as String?) ?? (json['published_at'] as String?) ?? DateTime.now().toIso8601String(),
        createdAt: (json['created_at'] as String?) ?? DateTime.now().toIso8601String(),
        updatedAt: (json['updated_at'] as String?) ?? DateTime.now().toIso8601String(),
        vendor: (json['brand'] as String?) ?? (json['vendor'] as String?) ?? 'انارات',
        productType: (json['category'] as String?) ?? (json['product_type'] as String?) ?? 'إنارة',
        tags: _extractTags(json),
        variants: _extractVariants(json),
        images: _extractImages(json),
        options: _extractOptions(json),
      );
    } catch (e) {
      developer.log('Error converting Anarat product: $e', name: 'CompetitorService');
      return null;
    }
  }

  static List<String> _extractTags(dynamic json) {
    if (json['tags'] is List) {
      return List<String>.from((json['tags'] as Iterable<dynamic>?) ?? <dynamic>[]);
    } else if (json['tags'] is String) {
      return (json['tags'] as String).split(',').map((tag) => tag.trim()).toList();
    } else if (json['category'] != null) {
      return [json['category'].toString()];
    }
    return ['إنارة'];
  }

  static List<CompetitorVariant> _extractVariants(dynamic json) {
    final List<CompetitorVariant> variants = [];

    // Try to extract price from different possible fields
    String price = '0.00';
    if (json['price'] != null) {
      final String priceText = json['price'].toString();
      // Extract current price from complex price text
      // Look for "Current price is: X EGP" or just "X EGP"
      final RegExp currentPriceRegex = RegExp(r'Current price is: ([\d,]+)');
      final RegExp simplePriceRegex = RegExp(r'([\d,]+)\s*EGP');

      final Match? currentMatch = currentPriceRegex.firstMatch(priceText);
      if (currentMatch != null) {
        price = currentMatch.group(1)!.replaceAll(',', '');
      } else {
        // Try to find any price in EGP
        final Iterable<Match> allMatches = simplePriceRegex.allMatches(priceText);
        if (allMatches.isNotEmpty) {
          // Take the last price found (usually the current price)
          price = allMatches.last.group(1)!.replaceAll(',', '');
        }
      }
    } else if (json['cost'] != null) {
      price = json['cost'].toString();
    } else if (json['amount'] != null) {
      price = json['amount'].toString();
    }

    variants.add(CompetitorVariant(
      id: (json['id'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      title: (json['name'] as String?) ?? (json['title'] as String?) ?? 'الافتراضي',
      option1: null,
      option2: null,
      option3: null,
      sku: json['sku']?.toString(),
      requiresShipping: true,
      taxable: true,
      available: (json['available'] as bool?) ?? (json['in_stock'] as bool?) ?? true,
      price: price,
      grams: 0,
      compareAtPrice: '0.00',
      position: 1,
      productId: (json['id'] as int?) ?? 0,
      createdAt: (json['created_at'] as String?) ?? DateTime.now().toIso8601String(),
      updatedAt: (json['updated_at'] as String?) ?? DateTime.now().toIso8601String(),
    ));

    return variants;
  }

  static List<CompetitorImage> _extractImages(dynamic json) {
    final List<CompetitorImage> images = [];

    // Try different possible image field names
    String? imageUrl;
    if (json['image'] != null) {
      imageUrl = json['image'].toString();
    } else if (json['image_url'] != null) {
      imageUrl = json['image_url'].toString();
    } else if (json['photo'] != null) {
      imageUrl = json['photo'].toString();
    } else if (json['picture'] != null) {
      imageUrl = json['picture'].toString();
    }

    if (imageUrl != null && imageUrl.isNotEmpty) {
      images.add(CompetitorImage(
        id: DateTime.now().millisecondsSinceEpoch,
        createdAt: DateTime.now().toIso8601String(),
        position: 1,
        updatedAt: DateTime.now().toIso8601String(),
        productId: (json['id'] as int?) ?? 0,
        variantIds: [],
        src: imageUrl,
        width: 800,
        height: 600,
      ));
    }

    return images;
  }

  static List<CompetitorOption> _extractOptions(dynamic json) {
    // For now, return empty options as we don't have variant options from this API
    return [];
  }

  static Future<Map<String, List<CompetitorProduct>>> fetchAllCompetitorProducts() async {
    try {
      developer.log('Fetching all competitor products...', name: 'CompetitorService');

      final wadiHomeProducts = await fetchWadiHomeProducts();
      final anaratProducts = await fetchAnaratProducts();
      final nawrlyProducts = await fetchNawrlyProducts();
      final lamaisonProducts = await fetchLamaisonProducts();

      final Map<String, List<CompetitorProduct>> competitors = {
        'wadihome': wadiHomeProducts,
        'anarat': anaratProducts,
        'nawrly': nawrlyProducts,
        'lamaison': lamaisonProducts,
      };

      developer.log('Successfully fetched competitor products:', name: 'CompetitorService');
      competitors.forEach((key, value) {
        developer.log('$key: ${value.length} products', name: 'CompetitorService');
      });

      return competitors;
    } catch (e) {
      developer.log('Error fetching competitor products: $e', name: 'CompetitorService');
      return {
        'wadihome': <CompetitorProduct>[],
        'anarat': <CompetitorProduct>[],
        'nawrly': <CompetitorProduct>[],
        'lamaison': <CompetitorProduct>[],
      };
    }
  }
}
