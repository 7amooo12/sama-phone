import 'dart:async';
import 'dart:isolate';
import '../models/flask_product_model.dart';
import '../models/product_movement_model.dart';
import '../utils/app_logger.dart';

/// Service for background processing to prevent UI blocking
class BackgroundProcessingService {
  static final BackgroundProcessingService _instance = BackgroundProcessingService._internal();
  factory BackgroundProcessingService() => _instance;
  BackgroundProcessingService._internal();

  final Map<String, Isolate> _activeIsolates = {};
  final Map<String, ReceivePort> _receivePorts = {};
  final Map<String, Completer> _completers = {};

  /// ULTRA-OPTIMIZED: Process large datasets in background isolate with aggressive optimization
  Future<Map<String, dynamic>> processInventoryAnalysis(
    List<FlaskProductModel> products,
    String operationId,
  ) async {
    if (products.isEmpty) {
      return {
        'lowStock': 0,
        'outOfStock': 0,
        'optimalStock': 0,
        'overStock': 0,
        'stockDistribution': {
          'نفد المخزون': 0,
          'مخزون منخفض': 0,
          'مخزون مثالي': 0,
          'مخزون زائد': 0,
        },
      };
    }

    // AGGRESSIVE OPTIMIZATION: Use isolates for smaller datasets too
    if (products.length < 10) {
      return _processInventoryAnalysisSync(products);
    }

    // For datasets >= 10 products, use isolate for better performance
    return _processInIsolate(
      operationId,
      _inventoryAnalysisIsolateEntry,
      products.map((p) => p.toJson()).toList(),
    );
  }

  /// ULTRA-OPTIMIZED: Process chart data generation in background with aggressive optimization
  Future<List<Map<String, dynamic>>> processChartData(
    List<FlaskProductModel> products,
    String chartType,
    String operationId,
  ) async {
    if (products.isEmpty) return [];

    // AGGRESSIVE OPTIMIZATION: Use isolates for smaller datasets
    if (products.length < 5) {
      return _processChartDataSync(products, chartType);
    }

    // For datasets >= 5 products, use isolate for better performance
    return _processInIsolate(
      operationId,
      _chartDataIsolateEntry,
      {
        'products': products.map((p) => p.toJson()).toList(),
        'chartType': chartType,
      },
    );
  }

  /// Generic method to process data in isolate
  Future<T> _processInIsolate<T>(
    String operationId,
    Function isolateEntry,
    dynamic data,
  ) async {
    try {
      AppLogger.info('🔄 Starting background processing: $operationId');

      final receivePort = ReceivePort();
      final completer = Completer<T>();

      _receivePorts[operationId] = receivePort;
      _completers[operationId] = completer;

      // Listen for results
      receivePort.listen((message) {
        if (message is Map && message.containsKey('error')) {
          completer.completeError(Exception(message['error']));
        } else {
          completer.complete(message as T);
        }
        _cleanup(operationId);
      });

      // Spawn isolate
      final isolate = await Isolate.spawn(
        isolateEntry as void Function(dynamic),
        {
          'sendPort': receivePort.sendPort,
          'data': data,
        },
      );

      _activeIsolates[operationId] = isolate;

      // Set timeout to prevent hanging
      Timer(const Duration(seconds: 30), () {
        if (!completer.isCompleted) {
          completer.completeError(TimeoutException('Background processing timeout', const Duration(seconds: 30)));
          _cleanup(operationId);
        }
      });

      final result = await completer.future;
      AppLogger.info('✅ Background processing completed: $operationId');
      return result;

    } catch (e) {
      AppLogger.error('❌ Background processing failed: $operationId - $e');
      _cleanup(operationId);
      rethrow;
    }
  }

  /// Cleanup isolate resources
  void _cleanup(String operationId) {
    _activeIsolates[operationId]?.kill(priority: Isolate.immediate);
    _activeIsolates.remove(operationId);
    _receivePorts[operationId]?.close();
    _receivePorts.remove(operationId);
    _completers.remove(operationId);
  }

  /// Kill all active isolates
  void killAllIsolates() {
    for (final operationId in _activeIsolates.keys.toList()) {
      _cleanup(operationId);
    }
    AppLogger.info('🛑 All background processes terminated');
  }

  /// Synchronous inventory analysis for small datasets
  Map<String, dynamic> _processInventoryAnalysisSync(List<FlaskProductModel> products) {
    final lowStock = products.where((p) => p.stockQuantity > 0 && p.stockQuantity <= 10).length;
    final outOfStock = products.where((p) => p.stockQuantity <= 0).length;
    final optimalStock = products.where((p) => p.stockQuantity > 10 && p.stockQuantity <= 100).length;
    final overStock = products.where((p) => p.stockQuantity > 100).length;

    return {
      'lowStock': lowStock,
      'outOfStock': outOfStock,
      'optimalStock': optimalStock,
      'overStock': overStock,
      'stockDistribution': {
        'نفد المخزون': outOfStock,
        'مخزون منخفض': lowStock,
        'مخزون مثالي': optimalStock,
        'مخزون زائد': overStock,
      },
    };
  }

  /// FIXED: Synchronous chart data processing - DEPRECATED for candlestick charts
  /// Category charts now use proper opening balance calculation instead of background processing
  List<Map<String, dynamic>> _processChartDataSync(List<FlaskProductModel> products, String chartType) {
    switch (chartType) {
      case 'candlestick':
        // DEPRECATED: This method should not be used for candlestick charts anymore
        // Category charts now use the same proper opening balance calculation as product charts
        AppLogger.warning('⚠️ Background processing called for candlestick charts - this should not happen');
        AppLogger.warning('   Category charts should use _generateCandlestickDataSync() with proper opening balance calculation');

        // Return minimal data to prevent errors, but log the issue
        return products.map((product) {
          final currentStock = product.stockQuantity.toDouble();

          AppLogger.error('❌ Using deprecated background processing for ${product.name} - opening balance will be incorrect');

          return {
            'productName': product.name,
            'open': currentStock,
            'openingBalance': currentStock, // This will be incorrect - should use _getOpeningBalance()
            'low': (currentStock * 0.8),
            'close': currentStock,
          };
        }).toList();

      case 'profit':
        return products.map((product) => {
          'productName': product.name,
          'profit': _calculateProfitMargin(product),
          'revenue': product.finalPrice * product.stockQuantity,
        }).toList();

      default:
        return [];
    }
  }

  /// Calculate profit margin for a product
  double _calculateProfitMargin(FlaskProductModel product) {
    if (product.finalPrice <= 0) return 0.0;
    final costPrice = product.finalPrice * 0.7; // Assume 30% markup
    return ((product.finalPrice - costPrice) / product.finalPrice) * 100;
  }

  /// CRITICAL OPTIMIZATION: Process bulk movement data in background isolate
  /// This handles the heavy lifting of processing movement data for multiple products
  Future<Map<int, Map<String, dynamic>>> processBulkMovementAnalysis(
    Map<int, ProductMovementModel> movementData,
    String operationId,
  ) async {
    if (movementData.isEmpty) return {};

    // Always use isolate for movement data processing as it's computationally intensive
    return _processInIsolate(
      operationId,
      _bulkMovementAnalysisIsolateEntry,
      movementData.map((key, value) => MapEntry(key.toString(), value.toJson())),
    );
  }

  /// AGGRESSIVE OPTIMIZATION: Process category analytics in background
  /// This handles complex calculations for category-level analytics
  Future<Map<String, dynamic>> processCategoryAnalytics(
    List<FlaskProductModel> products,
    Map<int, ProductMovementModel> movementData,
    String category,
    String operationId,
  ) async {
    if (products.isEmpty) return {};

    // Use isolate for category analytics processing
    return _processInIsolate(
      operationId,
      _categoryAnalyticsIsolateEntry,
      {
        'products': products.map((p) => p.toJson()).toList(),
        'movementData': movementData.map((key, value) => MapEntry(key.toString(), value.toJson())),
        'category': category,
      },
    );
  }

  /// PERFORMANCE OPTIMIZATION: Process customer analytics in background
  /// This handles customer ranking and analysis calculations
  Future<List<Map<String, dynamic>>> processCustomerAnalytics(
    Map<int, ProductMovementModel> movementData,
    String operationId,
  ) async {
    if (movementData.isEmpty) return [];

    // Use isolate for customer analytics processing
    return _processInIsolate(
      operationId,
      _customerAnalyticsIsolateEntry,
      movementData.map((key, value) => MapEntry(key.toString(), value.toJson())),
    );
  }

  /// ULTRA-FAST: Process sales performance metrics in background
  /// This handles complex sales calculations and performance metrics
  Future<Map<String, dynamic>> processSalesPerformanceMetrics(
    List<FlaskProductModel> products,
    Map<int, ProductMovementModel> movementData,
    String operationId,
  ) async {
    if (products.isEmpty || movementData.isEmpty) return {};

    // Use isolate for sales performance calculations
    return _processInIsolate(
      operationId,
      _salesPerformanceIsolateEntry,
      {
        'products': products.map((p) => p.toJson()).toList(),
        'movementData': movementData.map((key, value) => MapEntry(key.toString(), value.toJson())),
      },
    );
  }

  /// Get active isolates count
  int get activeIsolatesCount => _activeIsolates.length;

  /// Check if processing is active
  bool get isProcessing => _activeIsolates.isNotEmpty;
}

/// Isolate entry point for inventory analysis
void _inventoryAnalysisIsolateEntry(Map<String, dynamic> params) {
  try {
    final sendPort = params['sendPort'] as SendPort;
    final productsData = params['data'] as List<dynamic>;
    
    final products = productsData.map((json) => FlaskProductModel.fromJson(json)).toList();
    
    final lowStock = products.where((p) => p.stockQuantity > 0 && p.stockQuantity <= 10).length;
    final outOfStock = products.where((p) => p.stockQuantity <= 0).length;
    final optimalStock = products.where((p) => p.stockQuantity > 10 && p.stockQuantity <= 100).length;
    final overStock = products.where((p) => p.stockQuantity > 100).length;

    final result = {
      'lowStock': lowStock,
      'outOfStock': outOfStock,
      'optimalStock': optimalStock,
      'overStock': overStock,
      'stockDistribution': {
        'نفد المخزون': outOfStock,
        'مخزون منخفض': lowStock,
        'مخزون مثالي': optimalStock,
        'مخزون زائد': overStock,
      },
    };

    sendPort.send(result);
  } catch (e) {
    final sendPort = params['sendPort'] as SendPort;
    sendPort.send({'error': e.toString()});
  }
}

/// Isolate entry point for chart data processing
void _chartDataIsolateEntry(Map<String, dynamic> params) {
  try {
    final sendPort = params['sendPort'] as SendPort;
    final data = params['data'] as Map<String, dynamic>;
    final productsData = data['products'] as List<dynamic>;
    final chartType = data['chartType'] as String;
    
    final products = productsData.map((json) => FlaskProductModel.fromJson(json)).toList();
    
    List<Map<String, dynamic>> result = [];
    
    switch (chartType) {
      case 'candlestick':
        // DEPRECATED: Isolate processing should not be used for candlestick charts
        // Category charts now use proper opening balance calculation in main thread
        result = products.map((product) {
          final currentStock = product.stockQuantity.toDouble();

          // Log the deprecated usage
          print('⚠️ Isolate processing called for candlestick chart - this should not happen');
          print('   Product: ${product.name}, using incorrect opening balance');

          return {
            'productName': product.name,
            'open': currentStock,
            'openingBalance': currentStock, // This will be incorrect - should use proper calculation
            'low': (currentStock * 0.8),
            'close': currentStock,
          };
        }).toList();
        break;
      
      case 'profit':
        result = products.map((product) => {
          'productName': product.name,
          'profit': _calculateProfitMarginInIsolate(product),
          'revenue': product.finalPrice * product.stockQuantity,
        }).toList();
        break;
    }

    sendPort.send(result);
  } catch (e) {
    final sendPort = params['sendPort'] as SendPort;
    sendPort.send({'error': e.toString()});
  }
}

/// Calculate profit margin in isolate
double _calculateProfitMarginInIsolate(FlaskProductModel product) {
  if (product.finalPrice <= 0) return 0.0;
  final costPrice = product.finalPrice * 0.7; // Assume 30% markup
  return ((product.finalPrice - costPrice) / product.finalPrice) * 100;
}

/// CRITICAL OPTIMIZATION: Isolate entry point for bulk movement analysis
void _bulkMovementAnalysisIsolateEntry(Map<String, dynamic> params) {
  try {
    final sendPort = params['sendPort'] as SendPort;
    final movementDataMap = params['data'] as Map<String, dynamic>;

    final Map<int, Map<String, dynamic>> result = {};

    for (final entry in movementDataMap.entries) {
      final productId = int.parse(entry.key);
      final movementJson = entry.value as Map<String, dynamic>;

      // Extract key metrics from movement data
      final statistics = movementJson['statistics'] as Map<String, dynamic>;
      final salesData = movementJson['sales_data'] as List<dynamic>;

      result[productId] = {
        'totalRevenue': statistics['total_revenue'] ?? 0.0,
        'totalSold': statistics['total_sold_quantity'] ?? 0,
        'averagePrice': statistics['average_sale_price'] ?? 0.0,
        'profitMargin': statistics['profit_margin'] ?? 0.0,
        'salesCount': salesData.length,
        'lastSaleDate': salesData.isNotEmpty ? salesData.last['sale_date'] : null,
      };
    }

    sendPort.send(result);
  } catch (e) {
    final sendPort = params['sendPort'] as SendPort;
    sendPort.send({'error': e.toString()});
  }
}

/// AGGRESSIVE OPTIMIZATION: Isolate entry point for category analytics
void _categoryAnalyticsIsolateEntry(Map<String, dynamic> params) {
  try {
    final sendPort = params['sendPort'] as SendPort;
    final data = params['data'] as Map<String, dynamic>;
    final productsData = data['products'] as List<dynamic>;
    final movementDataMap = data['movementData'] as Map<String, dynamic>;
    final category = data['category'] as String;

    double totalRevenue = 0.0;
    int totalSold = 0;
    final int totalProducts = productsData.length;
    int activeProducts = 0;

    for (final productJson in productsData) {
      final productId = productJson['id'].toString();
      final movementJson = movementDataMap[productId];

      if (movementJson != null) {
        final statistics = movementJson['statistics'] as Map<String, dynamic>;
        totalRevenue += (statistics['total_revenue'] ?? 0.0) as double;
        totalSold += (statistics['total_sold_quantity'] ?? 0) as int;

        final soldQuantity = statistics['total_sold_quantity'] ?? 0;
        if (soldQuantity is int && soldQuantity > 0) {
          activeProducts++;
        }
      }
    }

    final result = {
      'category': category,
      'totalRevenue': totalRevenue,
      'totalSold': totalSold,
      'totalProducts': totalProducts,
      'activeProducts': activeProducts,
      'averageRevenuePerProduct': totalProducts > 0 ? totalRevenue / totalProducts : 0.0,
      'activityRate': totalProducts > 0 ? (activeProducts / totalProducts) * 100 : 0.0,
    };

    sendPort.send(result);
  } catch (e) {
    final sendPort = params['sendPort'] as SendPort;
    sendPort.send({'error': e.toString()});
  }
}

/// PERFORMANCE OPTIMIZATION: Isolate entry point for customer analytics
void _customerAnalyticsIsolateEntry(Map<String, dynamic> params) {
  try {
    final sendPort = params['sendPort'] as SendPort;
    final movementDataMap = params['data'] as Map<String, dynamic>;

    final Map<String, Map<String, dynamic>> customerMap = {};

    for (final entry in movementDataMap.entries) {
      final movementJson = entry.value as Map<String, dynamic>;
      final salesData = movementJson['sales_data'] as List<dynamic>;

      for (final sale in salesData) {
        final customerName = sale['customer_name'] as String;
        final totalAmount = (sale['total_amount'] ?? 0.0) as double;
        final quantity = (sale['quantity'] ?? 0) as int;

        if (customerMap.containsKey(customerName)) {
          customerMap[customerName]!['purchases'] = (customerMap[customerName]!['purchases'] as int) + 1;
          customerMap[customerName]!['totalSpent'] = (customerMap[customerName]!['totalSpent'] as double) + totalAmount;
          customerMap[customerName]!['totalQuantity'] = (customerMap[customerName]!['totalQuantity'] as int) + quantity;
        } else {
          customerMap[customerName] = {
            'name': customerName,
            'purchases': 1,
            'totalSpent': totalAmount,
            'totalQuantity': quantity,
          };
        }
      }
    }

    // Convert to sorted list
    final customerList = customerMap.values.toList();
    customerList.sort((a, b) => (b['totalSpent'] as double).compareTo(a['totalSpent'] as double));

    sendPort.send(customerList);
  } catch (e) {
    final sendPort = params['sendPort'] as SendPort;
    sendPort.send({'error': e.toString()});
  }
}

/// ULTRA-FAST: Isolate entry point for sales performance metrics
void _salesPerformanceIsolateEntry(Map<String, dynamic> params) {
  try {
    final sendPort = params['sendPort'] as SendPort;
    final data = params['data'] as Map<String, dynamic>;
    final productsData = data['products'] as List<dynamic>;
    final movementDataMap = data['movementData'] as Map<String, dynamic>;

    double totalRevenue = 0.0;
    int totalSales = 0;
    int totalTransactions = 0;
    double totalProfit = 0.0;

    for (final productJson in productsData) {
      final productId = productJson['id'].toString();
      final movementJson = movementDataMap[productId];

      if (movementJson != null) {
        final statistics = movementJson['statistics'] as Map<String, dynamic>;
        final salesData = movementJson['sales_data'] as List<dynamic>;

        totalRevenue += (statistics['total_revenue'] ?? 0.0) as double;
        totalSales += (statistics['total_sold_quantity'] ?? 0) as int;
        totalTransactions += salesData.length;
        totalProfit += (statistics['total_profit'] ?? 0.0) as double;
      }
    }

    final result = {
      'totalRevenue': totalRevenue,
      'totalSales': totalSales,
      'totalTransactions': totalTransactions,
      'totalProfit': totalProfit,
      'averageTransactionValue': totalTransactions > 0 ? totalRevenue / totalTransactions : 0.0,
      'averageProfitMargin': totalRevenue > 0 ? (totalProfit / totalRevenue) * 100 : 0.0,
      'salesVelocity': totalSales.toDouble(),
    };

    sendPort.send(result);
  } catch (e) {
    final sendPort = params['sendPort'] as SendPort;
    sendPort.send({'error': e.toString()});
  }
}
