import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smartbiztracker_new/models/product_model.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// Service for calculating real profitability using actual sales data from Supabase
class RealProfitabilityService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Calculate real profitability for all products using actual sales data
  static Future<Map<String, dynamic>> calculateRealProfitability() async {
    try {
      AppLogger.info('🔄 Calculating real profitability from sales data...');

      // Fetch all products with purchase prices
      final productsResponse = await _supabase
          .from('products')
          .select('*')
          .not('purchase_price', 'is', null)
          .gt('purchase_price', 0);

      if (productsResponse.isEmpty) {
        AppLogger.warning('⚠️ No products with purchase prices found');
        return _getEmptyProfitabilityData();
      }

      final products = productsResponse
          .map((json) => ProductModel.fromJson(json))
          .toList();

      // Fetch actual sales data from invoices
      final salesData = await _fetchRealSalesData();

      // Calculate profitability for each product
      final productAnalysis = <Map<String, dynamic>>[];
      double totalRevenue = 0.0;
      double totalCost = 0.0;
      double totalProfit = 0.0;

      for (final product in products) {
        final analysis = await _calculateProductProfitability(product, salesData);
        if (analysis != null) {
          productAnalysis.add(analysis);
          totalRevenue += analysis['totalRevenue'] as double;
          totalCost += analysis['totalCost'] as double;
          totalProfit += analysis['totalProfit'] as double;
        }
      }

      // Sort by profit margin (descending)
      productAnalysis.sort((a, b) => 
          (b['profitMargin'] as double).compareTo(a['profitMargin'] as double));

      // Get top 10 most profitable and least profitable
      final topProfitable = productAnalysis.take(10).toList();
      final leastProfitable = productAnalysis.reversed.take(10).toList().reversed.toList();

      AppLogger.info('✅ Real profitability calculated successfully');
      AppLogger.info('📊 Total products analyzed: ${productAnalysis.length}');
      AppLogger.info('💰 Total revenue: ${totalRevenue.toStringAsFixed(2)}');
      AppLogger.info('💸 Total cost: ${totalCost.toStringAsFixed(2)}');
      AppLogger.info('📈 Total profit: ${totalProfit.toStringAsFixed(2)}');

      return {
        'totalRevenue': totalRevenue,
        'totalCost': totalCost,
        'totalProfit': totalProfit,
        'profitMargin': totalCost > 0 ? (totalProfit / totalCost) * 100 : 0.0,
        'totalProducts': productAnalysis.length,
        'profitableProducts': productAnalysis.where((p) => (p['profitMargin'] as double) > 0).length,
        'lossProducts': productAnalysis.where((p) => (p['profitMargin'] as double) < 0).length,
        'topProfitable': topProfitable,
        'leastProfitable': leastProfitable,
        'allProducts': productAnalysis,
      };
    } catch (e) {
      AppLogger.error('❌ Error calculating real profitability: $e');
      return _getEmptyProfitabilityData();
    }
  }

  /// Fetch real sales data from invoices table
  static Future<Map<String, Map<String, dynamic>>> _fetchRealSalesData() async {
    try {
      AppLogger.info('🔄 Fetching real sales data from invoices...');

      // Fetch completed invoices with items
      final invoicesResponse = await _supabase
          .from('invoices')
          .select('items, status, created_at')
          .eq('status', 'completed')
          .order('created_at', ascending: false);

      final salesData = <String, Map<String, dynamic>>{};

      for (final invoice in invoicesResponse) {
        final items = invoice['items'] as List?;
        if (items == null) continue;

        for (final item in items) {
          final productName = item['product_name'] as String?;
          final quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
          final unitPrice = (item['price'] as num?)?.toDouble() ?? 0.0;
          final totalPrice = quantity * unitPrice;

          if (productName != null && quantity > 0 && unitPrice > 0) {
            if (salesData.containsKey(productName)) {
              salesData[productName]!['totalQuantitySold'] = 
                  (salesData[productName]!['totalQuantitySold'] as double) + quantity;
              salesData[productName]!['totalRevenue'] = 
                  (salesData[productName]!['totalRevenue'] as double) + totalPrice;
              salesData[productName]!['salesCount'] = 
                  (salesData[productName]!['salesCount'] as int) + 1;
            } else {
              salesData[productName] = {
                'totalQuantitySold': quantity,
                'totalRevenue': totalPrice,
                'averageUnitPrice': unitPrice,
                'salesCount': 1,
              };
            }
          }
        }
      }

      // Calculate average unit prices
      for (final productName in salesData.keys) {
        final data = salesData[productName]!;
        data['averageUnitPrice'] = (data['totalRevenue'] as double) / 
                                   (data['totalQuantitySold'] as double);
      }

      AppLogger.info('✅ Sales data fetched for ${salesData.length} products');
      return salesData;
    } catch (e) {
      AppLogger.error('❌ Error fetching sales data: $e');
      return {};
    }
  }

  /// Calculate profitability for a single product
  static Future<Map<String, dynamic>?> _calculateProductProfitability(
      ProductModel product, Map<String, Map<String, dynamic>> salesData) async {
    try {
      final purchasePrice = product.purchasePrice ?? 0.0;
      final sellingPrice = product.price;
      final currentStock = product.quantity;

      if (purchasePrice <= 0) return null;

      // Get sales data for this product
      final productSales = salesData[product.name];
      final totalQuantitySold = productSales?['totalQuantitySold'] as double? ?? 0.0;
      final totalRevenue = productSales?['totalRevenue'] as double? ?? 0.0;
      final averageUnitPrice = productSales?['averageUnitPrice'] as double? ?? sellingPrice;

      // Calculate costs and profits based on actual sales
      final totalCost = totalQuantitySold * purchasePrice;
      final totalProfit = totalRevenue - totalCost;
      final profitMargin = purchasePrice > 0 ? ((averageUnitPrice - purchasePrice) / purchasePrice) * 100 : 0.0;

      // Calculate potential profit from current stock
      final potentialRevenue = currentStock * sellingPrice;
      final potentialCost = currentStock * purchasePrice;
      final potentialProfit = potentialRevenue - potentialCost;

      return {
        'product': product,
        'purchasePrice': purchasePrice,
        'sellingPrice': sellingPrice,
        'averageUnitPrice': averageUnitPrice,
        'currentStock': currentStock,
        'totalQuantitySold': totalQuantitySold,
        'totalRevenue': totalRevenue,
        'totalCost': totalCost,
        'totalProfit': totalProfit,
        'profitMargin': profitMargin,
        'potentialRevenue': potentialRevenue,
        'potentialCost': potentialCost,
        'potentialProfit': potentialProfit,
        'salesCount': productSales?['salesCount'] as int? ?? 0,
      };
    } catch (e) {
      AppLogger.error('❌ Error calculating profitability for ${product.name}: $e');
      return null;
    }
  }

  /// Get empty profitability data structure
  static Map<String, dynamic> _getEmptyProfitabilityData() {
    return {
      'totalRevenue': 0.0,
      'totalCost': 0.0,
      'totalProfit': 0.0,
      'profitMargin': 0.0,
      'totalProducts': 0,
      'profitableProducts': 0,
      'lossProducts': 0,
      'topProfitable': <Map<String, dynamic>>[],
      'leastProfitable': <Map<String, dynamic>>[],
      'allProducts': <Map<String, dynamic>>[],
    };
  }

  /// Get top selling products based on actual sales volume
  static Future<List<Map<String, dynamic>>> getTopSellingProducts({int limit = 10}) async {
    try {
      AppLogger.info('🔄 Fetching top selling products...');

      final salesData = await _fetchRealSalesData();
      
      // Convert to list and sort by total quantity sold
      final productsList = salesData.entries.map((entry) => {
        'productName': entry.key,
        'totalQuantitySold': entry.value['totalQuantitySold'],
        'totalRevenue': entry.value['totalRevenue'],
        'averageUnitPrice': entry.value['averageUnitPrice'],
        'salesCount': entry.value['salesCount'],
      }).toList();

      productsList.sort((a, b) => 
          (b['totalQuantitySold'] as double).compareTo(a['totalQuantitySold'] as double));

      final topProducts = productsList.take(limit).toList();
      
      AppLogger.info('✅ Top ${topProducts.length} selling products fetched');
      return topProducts;
    } catch (e) {
      AppLogger.error('❌ Error fetching top selling products: $e');
      return [];
    }
  }

  /// Get product image URL with proper Supabase storage path
  static String getProductImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return '';
    }

    // If already a full URL, return as is
    if (imageUrl.startsWith('http')) {
      return imageUrl;
    }

    // Build Supabase storage URL
    const supabaseUrl = 'https://ivtjacsppwmjgmuskxis.supabase.co';
    if (imageUrl.startsWith('/')) {
      return '$supabaseUrl/storage/v1/object/public/product-images$imageUrl';
    } else {
      return '$supabaseUrl/storage/v1/object/public/product-images/$imageUrl';
    }
  }
}
