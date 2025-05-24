import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:smartbiztracker_new/config/flask_api_config.dart';
import 'package:smartbiztracker_new/models/flask_invoice_model.dart';

class InvoiceService {
  final String baseUrl = FlaskApiConfig.prodApiUrl;
  final storage = const FlutterSecureStorage();
  final String apiKey = 'lux2025FlutterAccess'; // API key for secured endpoints
  
  // Get authentication token
  Future<String?> _getToken() async {
    return await storage.read(key: FlaskApiConfig.tokenKey);
  }
  
  // Get API headers with authentication and API key
  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': token != null ? 'Bearer $token' : '',
      'X-API-KEY': apiKey, // Add API key to headers
    };
  }
  
  // Get all invoices
  Future<List<FlaskInvoiceModel>> getInvoices({
    String? customerName, 
    String? status, 
    String? sortBy, 
    bool desc = true
  }) async {
    try {
      final headers = await _getHeaders();
      
      // Build query parameters
      final queryParams = <String, String>{};
      if (customerName != null && customerName.isNotEmpty) {
        queryParams['customer'] = customerName;
      }
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }
      if (sortBy != null && sortBy.isNotEmpty) {
        queryParams['sort_by'] = sortBy;
        queryParams['desc'] = desc.toString();
      }
      
      // Create URI with query parameters - use new secured endpoint
      final uri = Uri.parse('$baseUrl/secured/invoices').replace(queryParameters: queryParams);
      
      final response = await http.get(uri, headers: headers);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true && data['invoices'] != null) {
          final List<dynamic> invoicesJson = data['invoices'];
          return invoicesJson.map((json) => FlaskInvoiceModel.fromJson(json)).toList();
        } else {
          return [];
        }
      } else {
        throw Exception('Failed to load invoices: ${response.statusCode} ${response.reasonPhrase}');
      }
    } catch (e) {
      throw Exception('Error loading invoices: $e');
    }
  }
  
  // Get a specific invoice
  Future<FlaskInvoiceModel> getInvoice(int invoiceId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/secured/invoices/$invoiceId'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true && data['invoice'] != null) {
          return FlaskInvoiceModel.fromJson(data['invoice']);
        } else {
          throw Exception('Invoice data format error');
        }
      } else {
        throw Exception('Failed to load invoice: ${response.statusCode} ${response.reasonPhrase}');
      }
    } catch (e) {
      throw Exception('Error loading invoice: $e');
    }
  }
  
  // Search invoices by product name or customer name
  Future<List<FlaskInvoiceModel>> searchInvoices(String query) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/secured/invoices/search?q=$query'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true && data['invoices'] != null) {
          final List<dynamic> invoicesJson = data['invoices'];
          return invoicesJson.map((json) => FlaskInvoiceModel.fromJson(json)).toList();
        } else {
          return [];
        }
      } else {
        throw Exception('Failed to search invoices: ${response.statusCode} ${response.reasonPhrase}');
      }
    } catch (e) {
      throw Exception('Error searching invoices: $e');
    }
  }
  
  // Get invoice movement for a product
  Future<List<Map<String, dynamic>>> getProductMovement(int productId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/products/$productId/movement'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['movements'] != null) {
          return List<Map<String, dynamic>>.from(data['movements']);
        } else {
          return [];
        }
      } else {
        throw Exception('Failed to load product movement: ${response.statusCode} ${response.reasonPhrase}');
      }
    } catch (e) {
      throw Exception('Error loading product movement: $e');
    }
  }
} 