import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/admin_product_model.dart';

class AdminProductService {
  // Singleton pattern
  static final AdminProductService _instance = AdminProductService._internal();
  factory AdminProductService() => _instance;
  AdminProductService._internal();

  // Constants
  static const String _baseUrl = 'https://samastock.pythonanywhere.com'; // Change this to your actual API base URL
  static const String _apiKey = 'lux2025FlutterAccess';

  // Get all products including visible and non-visible
  Future<List<AdminProductModel>> getAllProducts() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/flutter/api/api/products'),
        headers: {
          'x-api-key': _apiKey,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true && data['products'] != null) {
          final List<dynamic> productList = data['products'];
          
          // Process the products to ensure image URLs are properly formatted
          final processedProducts = productList.map((item) {
            // Check if image_url is a relative path that needs the base URL
            if (item['image_url'] != null && item['image_url'].toString().isNotEmpty) {
              final imageUrl = item['image_url'].toString();
              if (!imageUrl.startsWith('http') && !imageUrl.startsWith('https')) {
                // Add the base URL to make it a complete URL
                item['image_url'] = '$_baseUrl/static/uploads/$imageUrl';
              }
            }
            return item;
          }).toList();
          
          return processedProducts
              .map((json) => AdminProductModel.fromJson(json))
              .toList();
        }
        throw Exception('API returned success false or no products');
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Invalid API key');
      } else {
        throw Exception('Failed to load products: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching products: $e');
      rethrow;
    }
  }

  // Helper method to handle API response
  bool _isValidResponse(http.Response response) {
    return response.statusCode == 200 && 
           json.decode(response.body)['success'] == true;
  }
} 