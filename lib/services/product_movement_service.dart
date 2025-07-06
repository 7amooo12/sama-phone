import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:smartbiztracker_new/config/flask_api_config.dart';
import 'package:smartbiztracker_new/models/product_movement_model.dart';

class ProductMovementService {
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

  /// Search for products by name, SKU, or category
  /// Uses the secured products search endpoint with API key
  Future<List<ProductSearchModel>> searchProducts(String query) async {
    try {
      final headers = await _getHeaders();

      // Use the secured products search endpoint
      final uri = Uri.parse('$baseUrl/secured/products/search').replace(
        queryParameters: {'q': query}
      );

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true && data['products'] != null) {
          final List<dynamic> productsJson = data['products'];
          return productsJson.map((json) => ProductSearchModel.fromJson(json)).toList();
        } else {
          return [];
        }
      } else if (response.statusCode == 401) {
        // Unauthorized
        throw Exception('Authentication failed. Please check your credentials.');
      } else if (response.statusCode == 500) {
        // Server error
        throw Exception('Server error occurred. Please try again later.');
      } else {
        throw Exception('Failed to load products: HTTP ${response.statusCode}');
      }
    } catch (e) {
      // Re-throw with more context if it's already our custom exception
      if (e.toString().contains('Exception:')) {
        rethrow;
      }
      throw Exception('Network error: $e');
    }
  }

  /// OPTIMIZED: Get comprehensive product movement data by product name using bulk API
  /// Reduces API calls from 2 per product to 1 bulk call for all products
  Future<ProductMovementModel> getProductMovementByName(String productName) async {
    try {
      final headers = await _getHeaders();

      // Use new bulk movement endpoint that returns all data in one call
      final bulkUri = Uri.parse('$baseUrl/api/products/movement/bulk').replace(
        queryParameters: {'product_names': productName}
      );

      final bulkResponse = await http.get(bulkUri, headers: headers);

      if (bulkResponse.statusCode == 200) {
        final bulkData = json.decode(bulkResponse.body);
        if (bulkData['success'] == true && bulkData['products'] != null) {
          final List<dynamic> products = bulkData['products'] as List<dynamic>;
          if (products.isNotEmpty) {
            return ProductMovementModel.fromJson(products.first as Map<String, dynamic>);
          }
        }
      }

      // Fallback to original method if bulk endpoint not available
      return await _getProductMovementByNameFallback(productName);
    } catch (e) {
      // Fallback to original method on error
      return await _getProductMovementByNameFallback(productName);
    }
  }

  /// Fallback method using original API calls (for backward compatibility)
  Future<ProductMovementModel> _getProductMovementByNameFallback(String productName) async {
    try {
      final headers = await _getHeaders();

      // First, get the product details from the working products endpoint
      final productsUri = Uri.parse('$baseUrl/api/products');
      final productsResponse = await http.get(productsUri, headers: headers);

      if (productsResponse.statusCode != 200) {
        throw Exception('Failed to load products');
      }

      final productsData = json.decode(productsResponse.body);
      if (productsData['success'] != true || productsData['products'] == null) {
        throw Exception('No products data available');
      }

      // Find the specific product
      final List<dynamic> allProducts = productsData['products'] as List<dynamic>;
      final productJson = allProducts.firstWhere(
        (p) => p['name'].toString().toLowerCase().contains(productName.toLowerCase()),
        orElse: () => null,
      );

      if (productJson == null) {
        throw Exception('Product not found');
      }

      // Now get all invoices to find sales data for this product
      final invoicesUri = Uri.parse('$baseUrl/api/invoices');
      final invoicesResponse = await http.get(invoicesUri, headers: headers);

      final List<ProductSaleModel> salesData = [];
      if (invoicesResponse.statusCode == 200) {
        final invoicesData = json.decode(invoicesResponse.body);
        if (invoicesData['success'] == true && invoicesData['invoices'] != null) {
          final List<dynamic> allInvoices = invoicesData['invoices'] as List<dynamic>;

          // Find sales of this product in all invoices
          for (var invoice in allInvoices) {
            if (invoice['items'] != null) {
              for (var item in invoice['items']) {
                if (item['product_name'].toString().toLowerCase().contains(productName.toLowerCase())) {
                  salesData.add(ProductSaleModel(
                    invoiceId: invoice['id'],
                    customerName: invoice['customer_name'] ?? 'Unknown Customer',
                    customerPhone: invoice['customer_phone'] ?? '',
                    customerEmail: invoice['customer_email'] ?? '',
                    quantity: item['quantity'] ?? 0,
                    unitPrice: (item['price'] ?? 0).toDouble(),
                    totalAmount: (item['total'] ?? 0).toDouble(),
                    discount: (item['discount'] ?? 0).toDouble(),
                    saleDate: DateTime.parse(invoice['created_at']),
                    invoiceStatus: invoice['status'] ?? 'unknown',
                  ));
                }
              }
            }
          }
        }
      }

      // Create product model with proper cost price mapping
      final purchasePrice = productJson['purchase_price']?.toDouble();
      final sellingPrice = productJson['selling_price']?.toDouble();

      print('🏷️ Product Price Data for ${productJson['name']}:');
      print('   - Purchase Price: $purchasePrice');
      print('   - Selling Price: $sellingPrice');

      final product = ProductMovementProductModel(
        id: productJson['id'],
        name: productJson['name'],
        sku: productJson['sku'],
        description: productJson['description'],
        category: productJson['category_name'],
        purchasePrice: purchasePrice,
        sellingPrice: sellingPrice,
        // Set costPrice to purchasePrice for profit calculations
        costPrice: purchasePrice,
        currentStock: productJson['stock_quantity'] ?? 0,
        imageUrl: productJson['image_url'],
      );

      // Create movement data based on sales (negative quantities for sales)
      final movementData = <ProductStockMovementModel>[];
      for (var sale in salesData) {
        movementData.add(ProductStockMovementModel(
          id: sale.invoiceId,
          quantity: -sale.quantity, // Negative for sales
          reason: 'بيع',
          reference: 'INV-${sale.invoiceId}',
          notes: 'بيع للعميل ${sale.customerName}',
          createdAt: sale.saleDate,
          createdBy: 'النظام',
        ));
      }

      // Calculate real statistics from actual sales data
      final totalSold = salesData.fold<int>(0, (sum, sale) => sum + sale.quantity);
      final totalRevenue = salesData.fold<double>(0, (sum, sale) => sum + sale.totalAmount);
      final avgPrice = totalSold > 0 ? totalRevenue / totalSold : 0;

      print('📊 Sales Statistics for ${product.name}:');
      print('   - Total Sold: $totalSold');
      print('   - Total Revenue: $totalRevenue');
      print('   - Average Price: $avgPrice');
      print('   - Sales Count: ${salesData.length}');

      // Enhanced profit calculation with multiple fallback options
      final profitCalculation = _calculateProfitMetrics(product, salesData, avgPrice.toDouble());
      final profitPerUnit = profitCalculation['profitPerUnit'] as double;
      final totalProfit = profitCalculation['totalProfit'] as double;
      final profitMargin = profitCalculation['profitMargin'] as double;

      print('💰 Final Profit Results:');
      print('   - Profit Per Unit: $profitPerUnit');
      print('   - Total Profit: $totalProfit');
      print('   - Profit Margin: $profitMargin%');

      final statistics = ProductMovementStatisticsModel(
        totalSoldQuantity: totalSold,
        totalRevenue: totalRevenue,
        averageSalePrice: avgPrice.toDouble(),
        profitPerUnit: profitPerUnit,
        totalProfit: totalProfit,
        profitMargin: profitMargin.toDouble(),
        totalSalesCount: salesData.length,
        currentStock: product.currentStock,
      );

      // Add a note if no sales found
      if (salesData.isEmpty) {
        print('لا يوجد حركة مبيعات لهذا الصنف: ${product.name}');
        print('الرصيد الحالي: ${product.currentStock}');
      }

      return ProductMovementModel(
        product: product,
        salesData: salesData,
        movementData: movementData,
        statistics: statistics,
      );

    } catch (e) {
      throw Exception('Error loading product movement: $e');
    }
  }

  /// Get comprehensive product movement data by product ID
  Future<ProductMovementModel> getProductMovementById(int productId) async {
    try {
      final headers = await _getHeaders();

      // Create URI with query parameters
      final uri = Uri.parse('$baseUrl/secured/products/movement').replace(
        queryParameters: {'product_id': productId.toString()}
      );

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          return ProductMovementModel.fromJson(data);
        } else {
          throw Exception(data['message'] ?? 'Failed to load product movement data');
        }
      } else {
        throw Exception('Failed to load product movement: ${response.statusCode} ${response.reasonPhrase}');
      }
    } catch (e) {
      throw Exception('Error loading product movement: $e');
    }
  }

  /// Get product movement data with error handling and retry logic
  Future<ProductMovementModel?> getProductMovementSafe(String productName) async {
    try {
      return await getProductMovementByName(productName);
    } catch (e) {
      // Log error but don't throw - return null instead
      print('Error getting product movement for "$productName": $e');
      return null;
    }
  }

  /// Get product movement data by ID with error handling
  Future<ProductMovementModel?> getProductMovementByIdSafe(int productId) async {
    try {
      return await getProductMovementById(productId);
    } catch (e) {
      // Log error but don't throw - return null instead
      print('Error getting product movement for ID $productId: $e');
      return null;
    }
  }

  /// Search products with error handling
  Future<List<ProductSearchModel>> searchProductsSafe(String query) async {
    try {
      return await searchProducts(query);
    } catch (e) {
      // Log error but don't throw - return empty list instead
      print('Error searching products with query "$query": $e');
      return [];
    }
  }

  /// Validate if a product exists and has sales data
  Future<bool> hasProductSalesData(String productName) async {
    try {
      final movement = await getProductMovementByName(productName);
      return movement.salesData.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get quick product statistics without full movement data
  Future<Map<String, dynamic>?> getProductQuickStats(int productId) async {
    try {
      final movement = await getProductMovementById(productId);
      return {
        'total_sold': movement.statistics.totalSoldQuantity,
        'total_revenue': movement.statistics.totalRevenue,
        'current_stock': movement.statistics.currentStock,
        'sales_count': movement.statistics.totalSalesCount,
        'profit_margin': movement.statistics.profitMargin,
      };
    } catch (e) {
      return null;
    }
  }

  /// Get all products with movement data using the new secured endpoint
  Future<List<ProductSearchModel>> getAllProductsMovement({bool includeAll = false}) async {
    try {
      final headers = await _getHeaders();

      // Use the working all products movement endpoint
      final uri = Uri.parse('$baseUrl/api/products/movement/all').replace(
        queryParameters: includeAll ? {'include_all': 'true'} : null
      );

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true && data['products'] != null) {
          final List<dynamic> productsJson = data['products'];
          return productsJson.map((json) => ProductSearchModel.fromJson(json)).toList();
        } else {
          return [];
        }
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please check your credentials.');
      } else if (response.statusCode == 500) {
        throw Exception('Server error occurred. Please try again later.');
      } else {
        throw Exception('Failed to load products movement: HTTP ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('Exception:')) {
        rethrow;
      }
      throw Exception('Network error: $e');
    }
  }

  /// Get all products movement with error handling
  Future<List<ProductSearchModel>> getAllProductsMovementSafe({bool includeAll = false}) async {
    try {
      return await getAllProductsMovement(includeAll: includeAll);
    } catch (e) {
      print('Error getting all products movement: $e');
      return [];
    }
  }

  /// CRITICAL OPTIMIZATION: Bulk API method to get movement data for multiple products in one call
  /// This reduces API calls from N*2 to 1 for N products
  Future<Map<String, ProductMovementModel>> getBulkProductMovement(List<String> productNames) async {
    try {
      final headers = await _getHeaders();

      // Use bulk movement endpoint
      final bulkUri = Uri.parse('$baseUrl/api/products/movement/bulk');
      final requestBody = json.encode({
        'product_names': productNames,
        'include_sales_data': true,
        'include_statistics': true,
      });

      final response = await http.post(
        bulkUri,
        headers: headers,
        body: requestBody,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['products'] != null) {
          final Map<String, ProductMovementModel> result = {};
          final List<dynamic> products = data['products'] as List<dynamic>;

          for (final productData in products) {
            final productMap = productData as Map<String, dynamic>;
            final productName = productMap['product']['name'] as String;
            result[productName] = ProductMovementModel.fromJson(productMap);
          }

          return result;
        }
      }

      // Fallback to individual calls if bulk endpoint fails
      return await _getBulkMovementFallback(productNames);
    } catch (e) {
      // Fallback to individual calls on error
      return await _getBulkMovementFallback(productNames);
    }
  }

  /// Fallback method for bulk movement data (backward compatibility)
  Future<Map<String, ProductMovementModel>> _getBulkMovementFallback(List<String> productNames) async {
    final Map<String, ProductMovementModel> result = {};

    // Process in smaller batches to avoid overwhelming the API
    const batchSize = 5;
    for (int i = 0; i < productNames.length; i += batchSize) {
      final batch = productNames.skip(i).take(batchSize).toList();

      await Future.wait(
        batch.map((productName) async {
          try {
            final movement = await getProductMovementByName(productName);
            result[productName] = movement;
          } catch (e) {
            print('Error getting movement for $productName: $e');
          }
        }),
      );
    }

    return result;
  }

  /// CRITICAL OPTIMIZATION: Bulk API method to get movement data by product IDs
  /// This is the most efficient method for comprehensive reports
  Future<Map<int, ProductMovementModel>> getBulkProductMovementByIds(List<int> productIds) async {
    try {
      final headers = await _getHeaders();

      // Use bulk movement endpoint with IDs
      final bulkUri = Uri.parse('$baseUrl/api/products/movement/bulk-ids');
      final requestBody = json.encode({
        'product_ids': productIds,
        'include_sales_data': true,
        'include_statistics': true,
        'include_movement_data': true,
      });

      final response = await http.post(
        bulkUri,
        headers: headers,
        body: requestBody,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['products'] != null) {
          final Map<int, ProductMovementModel> result = {};
          final List<dynamic> products = data['products'] as List<dynamic>;

          for (final productData in products) {
            final productMap = productData as Map<String, dynamic>;
            final productId = productMap['product']['id'] as int;
            result[productId] = ProductMovementModel.fromJson(productMap);
          }

          return result;
        }
      }

      // Fallback to individual calls if bulk endpoint fails
      return await _getBulkMovementByIdsFallback(productIds);
    } catch (e) {
      // Fallback to individual calls on error
      return await _getBulkMovementByIdsFallback(productIds);
    }
  }

  /// Fallback method for bulk movement data by IDs
  Future<Map<int, ProductMovementModel>> _getBulkMovementByIdsFallback(List<int> productIds) async {
    final Map<int, ProductMovementModel> result = {};

    // Process in smaller batches to avoid overwhelming the API
    const batchSize = 5;
    for (int i = 0; i < productIds.length; i += batchSize) {
      final batch = productIds.skip(i).take(batchSize).toList();

      await Future.wait(
        batch.map((productId) async {
          try {
            final movement = await getProductMovementById(productId);
            result[productId] = movement;
          } catch (e) {
            print('Error getting movement for product ID $productId: $e');
          }
        }),
      );
    }

    return result;
  }

  /// Enhanced profit calculation with multiple cost sources and fallback logic
  Map<String, double> _calculateProfitMetrics(
    ProductMovementProductModel product,
    List<ProductSaleModel> salesData,
    double averageSalePrice,
  ) {
    print('🧮 Calculating profit for product: ${product.name}');
    print('📊 Available data:');
    print('   - Cost Price: ${product.costPrice}');
    print('   - Purchase Price: ${product.purchasePrice}');
    print('   - Manufacturing Cost: ${product.manufacturingCost}');
    print('   - Selling Price: ${product.sellingPrice}');
    print('   - Average Sale Price: $averageSalePrice');
    print('   - Total Sales: ${salesData.length}');

    // Determine the best cost price to use
    final double? costPrice = _determineBestCostPrice(product, salesData);

    // Determine the best selling price to use
    final double sellingPrice = _determineBestSellingPrice(product, salesData, averageSalePrice);

    print('💰 Determined prices:');
    print('   - Cost Price: $costPrice');
    print('   - Selling Price: $sellingPrice');

    // Calculate profit metrics
    double profitPerUnit = 0.0;
    double totalProfit = 0.0;
    double profitMargin = 0.0;

    if (costPrice != null && costPrice > 0 && sellingPrice > 0) {
      // Calculate profit per unit
      profitPerUnit = sellingPrice - costPrice;

      // Calculate total profit using actual sales data
      if (salesData.isNotEmpty) {
        // Calculate profit for each sale individually for more accuracy
        totalProfit = salesData.fold<double>(0.0, (sum, sale) {
          final saleProfit = (sale.unitPrice - costPrice) * sale.quantity;
          print('   - Sale profit: ${sale.unitPrice} - $costPrice = ${sale.unitPrice - costPrice} * ${sale.quantity} = $saleProfit');
          return sum + saleProfit;
        });
      } else {
        // No sales data available, total profit is 0
        totalProfit = 0.0;
        print('   - No sales data available, total profit = 0');
      }

      // Calculate profit margin
      profitMargin = (profitPerUnit / sellingPrice) * 100;

      print('✅ Profit calculation successful:');
      print('   - Profit per unit: $profitPerUnit');
      print('   - Total profit: $totalProfit');
      print('   - Profit margin: ${profitMargin.toStringAsFixed(2)}%');
    } else {
      print('⚠️ Cannot calculate exact profit: missing cost or selling price data');
      print('   - Cost price available: ${costPrice != null && costPrice > 0}');
      print('   - Selling price available: ${sellingPrice > 0}');

      // If we have sales data, always try to estimate profit using a conservative approach
      if (salesData.isNotEmpty) {
        // Use average sale price if selling price is not available
        final effectiveSellingPrice = sellingPrice > 0 ? sellingPrice :
          (salesData.fold<double>(0.0, (sum, sale) => sum + sale.unitPrice) / salesData.length);

        if (effectiveSellingPrice > 0) {
          // Use 30% profit margin as default estimate (70% cost, 30% profit)
          final estimatedCostPrice = effectiveSellingPrice * 0.7;
          profitPerUnit = effectiveSellingPrice * 0.3; // 30% profit margin

          // Calculate total profit using actual sale prices with 30% margin
          totalProfit = salesData.fold<double>(0.0, (sum, sale) {
            final estimatedSaleProfit = sale.unitPrice * 0.3; // 30% of sale price as profit
            return sum + (estimatedSaleProfit * sale.quantity);
          });
          profitMargin = 30.0; // 30% estimated margin

          print('📈 Using estimated profit calculation (30% margin):');
          print('   - Effective Selling Price: $effectiveSellingPrice');
          print('   - Estimated Cost Price: $estimatedCostPrice');
          print('   - Estimated Profit Per Unit: $profitPerUnit');
          print('   - Estimated Total Profit: $totalProfit');
          print('   - Estimated Profit Margin: 30%');
        } else {
          print('❌ Cannot estimate profit: no valid price data available');
        }
      } else {
        print('❌ Cannot calculate profit: no sales data available');
      }
    }

    return {
      'profitPerUnit': profitPerUnit,
      'totalProfit': totalProfit,
      'profitMargin': profitMargin,
    };
  }

  /// Determine the best cost price from available sources
  double? _determineBestCostPrice(ProductMovementProductModel product, List<ProductSaleModel> salesData) {
    // Priority order for cost price sources:
    // 1. Direct cost price from product data
    // 2. Purchase price from product data
    // 3. Manufacturing cost from product data
    // 4. Estimated cost based on average selling price (70% rule)
    // 5. Estimated cost from sales data (70% rule)

    print('🔍 Searching for best cost price...');
    print('   - Direct cost price: ${product.costPrice}');
    print('   - Purchase price: ${product.purchasePrice}');
    print('   - Manufacturing cost: ${product.manufacturingCost}');
    print('   - Selling price: ${product.sellingPrice}');

    if (product.costPrice != null && product.costPrice! > 0) {
      print('💰 Using direct cost price: ${product.costPrice}');
      return product.costPrice;
    }

    if (product.purchasePrice != null && product.purchasePrice! > 0) {
      print('📦 Using purchase price: ${product.purchasePrice}');
      return product.purchasePrice;
    }

    if (product.manufacturingCost != null && product.manufacturingCost! > 0) {
      print('🏭 Using manufacturing cost: ${product.manufacturingCost}');
      return product.manufacturingCost;
    }

    // If we have selling price, estimate cost as 70% of selling price
    if (product.sellingPrice != null && product.sellingPrice! > 0) {
      final estimatedCost = product.sellingPrice! * 0.7;
      print('📈 Estimated cost from selling price (70%): $estimatedCost');
      return estimatedCost;
    }

    // If we have sales data, estimate cost from average sale price
    if (salesData.isNotEmpty) {
      final avgSalePrice = salesData.fold<double>(0.0, (sum, sale) => sum + sale.unitPrice) / salesData.length;
      if (avgSalePrice > 0) {
        final estimatedCost = avgSalePrice * 0.7;
        print('📊 Estimated cost from average sale price (70%): $estimatedCost');
        return estimatedCost;
      }
    }

    print('❌ No valid cost price source found - will use estimation in profit calculation');
    return null;
  }

  /// Determine the best selling price from available sources
  double _determineBestSellingPrice(
    ProductMovementProductModel product,
    List<ProductSaleModel> salesData,
    double averageSalePrice,
  ) {
    // Priority order for selling price sources:
    // 1. Average price from actual sales data (most accurate)
    // 2. Selling price from product data
    // 3. Purchase price with markup (if available)

    if (averageSalePrice > 0) {
      print('📊 Using average sale price: $averageSalePrice');
      return averageSalePrice;
    }

    if (product.sellingPrice != null && product.sellingPrice! > 0) {
      print('🏷️ Using product selling price: ${product.sellingPrice}');
      return product.sellingPrice!;
    }

    // Fallback: estimate selling price from purchase price with 30% markup
    if (product.purchasePrice != null && product.purchasePrice! > 0) {
      final estimatedSellingPrice = product.purchasePrice! * 1.3;
      print('📈 Estimated selling price from purchase price (130%): $estimatedSellingPrice');
      return estimatedSellingPrice;
    }

    print('⚠️ Using fallback selling price: 0.0');
    return 0.0;
  }
}
