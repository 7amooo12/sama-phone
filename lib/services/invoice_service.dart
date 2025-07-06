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

  // Get all invoices with full details (no pagination)
  Future<List<FlaskInvoiceModel>> getInvoices({
    String? customerName,
    String? status,
    String? sortBy,
    bool desc = true
  }) async {
    try {
      final headers = await _getHeaders();

      // Build query parameters - don't include page/per_page to get all invoices
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

      // Create URI with query parameters - use new API endpoint
      final uri = Uri.parse('$baseUrl/api/invoices').replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('📄 getInvoices response data keys: ${data.keys}');

        if (data['success'] == true && data['invoices'] != null) {
          final List<dynamic> invoicesJson = data['invoices'];
          print('📊 Found ${invoicesJson.length} invoices in getInvoices');

          // Debug: Check if items are present in the first invoice
          if (invoicesJson.isNotEmpty) {
            final firstInvoice = invoicesJson.first as Map<String, dynamic>;
            print('🔍 getInvoices first invoice keys: ${firstInvoice.keys}');
            print('🛒 getInvoices first invoice items: ${firstInvoice['items']}');
          }

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

  // Get invoices with pagination (for specific use cases)
  Future<Map<String, dynamic>> getInvoicesPaginated({
    String? customerName,
    String? status,
    String? sortBy,
    bool desc = true,
    int page = 1,
    int perPage = 20
  }) async {
    try {
      final headers = await _getHeaders();

      // Build query parameters with pagination
      final queryParams = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
      };

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

      // Create URI with query parameters
      final uri = Uri.parse('$baseUrl/secured/invoices').replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          final List<dynamic> invoicesJson = data['invoices'] ?? [];
          final invoices = invoicesJson.map((json) => FlaskInvoiceModel.fromJson(json)).toList();

          return {
            'invoices': invoices,
            'pagination': data['pagination'] ?? {},
          };
        } else {
          return {
            'invoices': <FlaskInvoiceModel>[],
            'pagination': {},
          };
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
        Uri.parse('$baseUrl/api/invoices/$invoiceId'),
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

  // Search invoices by customer name using the correct API endpoint
  Future<List<FlaskInvoiceModel>> searchInvoices(String query) async {
    try {
      final headers = await _getHeaders();

      // Use the same endpoint as getInvoices but with customer filter
      final queryParams = <String, String>{};
      if (query.isNotEmpty) {
        queryParams['customer'] = query;
      }

      // Create URI with query parameters using the working API endpoint
      final uri = Uri.parse('$baseUrl/api/invoices').replace(queryParameters: queryParams);

      print('🔍 Searching invoices with URI: $uri');
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('📄 Search response data keys: ${data.keys}');

        if (data['success'] == true && data['invoices'] != null) {
          final List<dynamic> invoicesJson = data['invoices'];
          print('📊 Found ${invoicesJson.length} invoices in search results');

          // Debug: Check if items are present in the first invoice
          if (invoicesJson.isNotEmpty) {
            final firstInvoice = invoicesJson.first as Map<String, dynamic>;
            print('🔍 First invoice keys: ${firstInvoice.keys}');
            print('🛒 First invoice items: ${firstInvoice['items']}');
            print('📦 Items type: ${firstInvoice['items']?.runtimeType}');
          }

          final invoices = <FlaskInvoiceModel>[];
          for (var invoiceJson in invoicesJson) {
            try {
              final invoice = FlaskInvoiceModel.fromJson(invoiceJson as Map<String, dynamic>);
              print('✅ Parsed invoice ${invoice.id} with ${invoice.items?.length ?? 0} items');

              // If items are missing or empty, try to fetch detailed invoice
              if (invoice.items == null || invoice.items!.isEmpty) {
                print('⚠️ Invoice ${invoice.id} has no items, attempting to fetch details...');
                try {
                  final detailedInvoice = await getInvoice(invoice.id);
                  print('✅ Fetched detailed invoice ${detailedInvoice.id} with ${detailedInvoice.items?.length ?? 0} items');
                  invoices.add(detailedInvoice);
                } catch (detailError) {
                  print('❌ Failed to fetch detailed invoice ${invoice.id}: $detailError');
                  // Add the original invoice even without items
                  invoices.add(invoice);
                }
              } else {
                invoices.add(invoice);
              }
            } catch (e) {
              print('❌ Error parsing invoice: $e');
              print('📄 Invoice JSON: $invoiceJson');
              // Continue with other invoices instead of failing completely
              continue;
            }
          }

          return invoices;
        } else {
          print('⚠️ API response indicates no success or no invoices');
          return [];
        }
      } else {
        throw Exception('Failed to search invoices: ${response.statusCode} ${response.reasonPhrase}');
      }
    } catch (e) {
      print('❌ Error searching invoices: $e');
      throw Exception('Error searching invoices: $e');
    }
  }

  // Enhanced search with multiple criteria (customer name, phone, and local product filtering)
  Future<List<FlaskInvoiceModel>> searchInvoicesEnhanced(String query) async {
    try {
      // First try to search by customer name using the API
      final customerResults = await searchInvoices(query);

      // If we have results from customer search, return them
      if (customerResults.isNotEmpty) {
        return customerResults;
      }

      // If no customer results, get all invoices and filter locally for products and phone numbers
      final allInvoices = await getInvoices();

      // Filter locally for phone numbers and product names
      final filteredInvoices = allInvoices.where((invoice) {
        // Check customer phone
        final phoneMatch = invoice.customerPhone != null &&
            invoice.customerPhone!.toLowerCase().contains(query.toLowerCase());

        // Check product names in items
        bool productMatch = false;
        if (invoice.items != null && invoice.items!.isNotEmpty) {
          productMatch = invoice.items!.any((item) =>
              item.productName.toLowerCase().contains(query.toLowerCase()));
        }

        // Check customer name (case-insensitive partial match)
        final nameMatch = invoice.customerName.toLowerCase().contains(query.toLowerCase());

        return phoneMatch || productMatch || nameMatch;
      }).toList();

      return filteredInvoices;
    } catch (e) {
      throw Exception('Error in enhanced search: $e');
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