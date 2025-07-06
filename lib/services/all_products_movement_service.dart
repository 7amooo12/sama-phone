import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/flask_api_config.dart';
import '../utils/app_logger.dart';

class AllProductsMovementService {
  final String baseUrl = FlaskApiConfig.prodApiUrl;
  final storage = const FlutterSecureStorage();
  final String apiKey = 'lux2025FlutterAccess';

  // Get API headers with authentication and API key
  Future<Map<String, String>> _getHeaders() async {
    final token = await storage.read(key: FlaskApiConfig.tokenKey);
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': token != null ? 'Bearer $token' : '',
      'X-API-KEY': apiKey,
    };
  }

  /// Get all products with their movement data
  Future<AllProductsMovementResponse> getAllProductsMovement() async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('$baseUrl/api/products/movement/all');

      AppLogger.info('جاري تحميل حركة جميع المنتجات من: $uri');

      final response = await http.get(uri, headers: headers).timeout(
        const Duration(seconds: 30),
      );

      AppLogger.info('استجابة API: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          AppLogger.info('تم تحميل ${data['count']} منتج بنجاح');
          return AllProductsMovementResponse.fromJson(data);
        } else {
          throw Exception(data['message'] ?? 'فشل في تحميل بيانات حركة المنتجات');
        }
      } else {
        throw Exception('خطأ في الخادم: ${response.statusCode} ${response.reasonPhrase}');
      }
    } catch (e) {
      AppLogger.error('خطأ في تحميل حركة المنتجات', e);
      throw Exception('فشل في تحميل حركة المنتجات: $e');
    }
  }

  /// Search products by name or SKU
  List<ProductMovementData> searchProducts(
    List<ProductMovementData> products,
    String query,
  ) {
    if (query.isEmpty) return products;

    final searchLower = query.toLowerCase();
    return products.where((product) {
      return product.name.toLowerCase().contains(searchLower) ||
          product.sku.toLowerCase().contains(searchLower) ||
          product.category.toLowerCase().contains(searchLower);
    }).toList();
  }

  /// Filter products by movement status
  List<ProductMovementData> filterByMovementStatus(
    List<ProductMovementData> products,
    String filter,
  ) {
    switch (filter) {
      case 'with_movement':
        return products.where((p) => p.salesSummary.totalSold > 0).toList();
      case 'without_movement':
        return products.where((p) => p.salesSummary.totalSold == 0).toList();
      case 'all':
      default:
        return products;
    }
  }

  /// Sort products by different criteria
  List<ProductMovementData> sortProducts(
    List<ProductMovementData> products,
    String sortBy,
  ) {
    final sortedProducts = List<ProductMovementData>.from(products);

    switch (sortBy) {
      case 'name_asc':
        sortedProducts.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'name_desc':
        sortedProducts.sort((a, b) => b.name.compareTo(a.name));
        break;
      case 'sales_desc':
        sortedProducts.sort((a, b) => b.salesSummary.totalSold.compareTo(a.salesSummary.totalSold));
        break;
      case 'sales_asc':
        sortedProducts.sort((a, b) => a.salesSummary.totalSold.compareTo(b.salesSummary.totalSold));
        break;
      case 'revenue_desc':
        sortedProducts.sort((a, b) => b.salesSummary.totalRevenue.compareTo(a.salesSummary.totalRevenue));
        break;
      case 'revenue_asc':
        sortedProducts.sort((a, b) => a.salesSummary.totalRevenue.compareTo(b.salesSummary.totalRevenue));
        break;
      case 'stock_desc':
        sortedProducts.sort((a, b) => b.currentStock.compareTo(a.currentStock));
        break;
      case 'stock_asc':
        sortedProducts.sort((a, b) => a.currentStock.compareTo(b.currentStock));
        break;
      default:
        // Default: products with movement first, then by name
        sortedProducts.sort((a, b) {
          if (a.salesSummary.totalSold > 0 && b.salesSummary.totalSold == 0) return -1;
          if (a.salesSummary.totalSold == 0 && b.salesSummary.totalSold > 0) return 1;
          return a.name.compareTo(b.name);
        });
    }

    return sortedProducts;
  }
}

// Data models for the response
class AllProductsMovementResponse {

  AllProductsMovementResponse({
    required this.success,
    required this.products,
    required this.summary,
    required this.count,
  });

  factory AllProductsMovementResponse.fromJson(Map<String, dynamic> json) {
    return AllProductsMovementResponse(
      success: (json['success'] as bool?) ?? false,
      products: (json['products'] as List<dynamic>?)
          ?.map((item) => ProductMovementData.fromJson((item as Map<String, dynamic>?) ?? {}))
          .toList() ?? [],
      summary: MovementSummary.fromJson((json['summary'] as Map<String, dynamic>?) ?? {}),
      count: (json['count'] as int?) ?? 0,
    );
  }
  final bool success;
  final List<ProductMovementData> products;
  final MovementSummary summary;
  final int count;
}

class ProductMovementData {

  ProductMovementData({
    required this.id,
    required this.name,
    required this.sku,
    required this.category,
    required this.description,
    required this.imageUrl,
    required this.currentStock,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.movementStatus,
    required this.salesSummary,
    required this.salesData,
  });

  factory ProductMovementData.fromJson(Map<String, dynamic> json) {
    // Handle the new API response format
    final statistics = json['statistics'] as Map<String, dynamic>? ?? {};
    final salesDataList = json['sales_data'] ?? [];
    final purchasePrice = (json['purchase_price'] ?? 0).toDouble();
    final sellingPrice = (json['selling_price'] ?? 0).toDouble();

    // Parse sales data
    final salesData = (salesDataList as List?)?.map<SalesData>((item) => SalesData.fromJson((item as Map<String, dynamic>?) ?? {})).toList() ?? <SalesData>[];

    // Create sales summary with calculated profit if not provided
    final salesSummary = createSalesSummaryWithProfit(statistics, salesData, purchasePrice, sellingPrice);

    return ProductMovementData(
      id: (json['id'] as int?) ?? 0,
      name: (json['name'] as String?) ?? '',
      sku: (json['sku'] as String?) ?? '',
      category: (json['category'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      imageUrl: (json['image_url'] as String?) ?? '',
      currentStock: (json['current_stock'] as int?) ?? 0,
      purchasePrice: purchasePrice,
      sellingPrice: sellingPrice,
      movementStatus: statistics['has_movement'] == true ? 'يوجد حركة' : 'لا يوجد حركة لهذا الصنف',
      salesSummary: salesSummary,
      salesData: salesData,
    );
  }
  final int id;
  final String name;
  final String sku;
  final String category;
  final String description;
  final String imageUrl;
  final int currentStock;
  final double purchasePrice;
  final double sellingPrice;
  final String movementStatus;
  final SalesSummary salesSummary;
  final List<SalesData> salesData;

  /// Create sales summary with calculated profit
  static SalesSummary createSalesSummaryWithProfit(
    Map<String, dynamic> statistics,
    List<SalesData> salesData,
    double purchasePrice,
    double sellingPrice,
  ) {
    final totalSold = statistics['total_sold_quantity'] ?? 0;
    final totalRevenue = (statistics['total_revenue'] ?? 0).toDouble();
    final salesCount = statistics['total_sales_count'] ?? 0;

    // Try to get profit data from statistics first
    double totalProfit = (statistics['total_profit'] ?? 0).toDouble();
    double profitMargin = (statistics['profit_margin'] ?? 0).toDouble();

    // If profit is 0 or not provided, calculate it
    if (totalProfit == 0.0 && salesData.isNotEmpty && purchasePrice > 0) {
      // Calculate profit using purchase price as cost
      totalProfit = salesData.fold<double>(0.0, (sum, sale) {
        final saleProfit = (sale.unitPrice - purchasePrice) * sale.quantity;
        return sum + saleProfit;
      });

      // Calculate profit margin
      if (totalRevenue > 0.0) {
        profitMargin = (totalProfit / (totalRevenue as num)) * 100;
      }

      print('📊 Calculated profit for product:');
      print('   - Purchase Price: $purchasePrice');
      print('   - Total Revenue: $totalRevenue');
      print('   - Total Profit: $totalProfit');
      print('   - Profit Margin: ${profitMargin.toStringAsFixed(2)}%');
    } else if (totalProfit == 0.0 && salesData.isNotEmpty && sellingPrice > 0) {
      // Fallback: estimate profit using 30% margin
      totalProfit = salesData.fold<double>(0.0, (sum, sale) {
        final estimatedProfit = sale.unitPrice * 0.3; // 30% profit margin
        return sum + (estimatedProfit * sale.quantity);
      });
      profitMargin = 30.0; // 30% estimated margin

      print('📈 Estimated profit (30% margin):');
      print('   - Total Revenue: $totalRevenue');
      print('   - Estimated Total Profit: $totalProfit');
      print('   - Estimated Profit Margin: 30%');
    }

    return SalesSummary(
      totalSold: totalSold,
      totalRevenue: totalRevenue,
      totalProfit: totalProfit,
      profitMargin: profitMargin,
      salesCount: salesCount,
    );
  }
}

class SalesSummary {

  SalesSummary({
    required this.totalSold,
    required this.totalRevenue,
    required this.totalProfit,
    required this.profitMargin,
    required this.salesCount,
  });

  factory SalesSummary.fromJson(Map<String, dynamic> json) {
    return SalesSummary(
      totalSold: json['total_sold_quantity'] ?? 0,
      totalRevenue: (json['total_revenue'] ?? 0).toDouble(),
      totalProfit: (json['total_profit'] ?? 0).toDouble(),
      profitMargin: (json['profit_margin'] ?? 0).toDouble(),
      salesCount: json['total_sales_count'] ?? 0,
    );
  }
  final int totalSold;
  final double totalRevenue;
  final double totalProfit;
  final double profitMargin;
  final int salesCount;
}

class SalesData {

  SalesData({
    required this.date,
    required this.invoiceNumber,
    required this.customerName,
    required this.quantity,
    required this.unitPrice,
    required this.totalAmount,
    required this.status,
    required this.user,
  });

  factory SalesData.fromJson(Map<String, dynamic> json) {
    return SalesData(
      date: json['date'] ?? '',
      invoiceNumber: json['invoice_number'] ?? '',
      customerName: json['customer_name'] ?? '',
      quantity: json['quantity'] ?? 0,
      unitPrice: (json['unit_price'] ?? 0).toDouble(),
      totalAmount: (json['total_amount'] ?? 0).toDouble(),
      status: json['status'] ?? '',
      user: json['user'] ?? '',
    );
  }
  final String date;
  final String invoiceNumber;
  final String customerName;
  final int quantity;
  final double unitPrice;
  final double totalAmount;
  final String status;
  final String user;
}

class MovementSummary {

  MovementSummary({
    required this.totalProducts,
    required this.processedProducts,
    required this.productsWithMovement,
    required this.productsWithoutMovement,
    required this.errorCount,
  });

  factory MovementSummary.fromJson(Map<String, dynamic> json) {
    return MovementSummary(
      totalProducts: json['total_products_in_db'] ?? 0,
      processedProducts: json['total_products_in_db'] ?? 0,
      productsWithMovement: json['products_with_movement'] ?? 0,
      productsWithoutMovement: json['products_without_movement'] ?? 0,
      errorCount: 0,
    );
  }
  final int totalProducts;
  final int processedProducts;
  final int productsWithMovement;
  final int productsWithoutMovement;
  final int errorCount;
}
