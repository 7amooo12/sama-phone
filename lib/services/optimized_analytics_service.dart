import 'dart:async';
import 'package:smartbiztracker_new/services/invoice_creation_service.dart';
import 'package:smartbiztracker_new/services/real_profitability_service.dart';
import 'package:smartbiztracker_new/services/supabase_orders_service.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:smartbiztracker_new/services/reports_performance_monitor.dart';

/// Optimized Analytics Service for Owner Dashboard Reports
/// Provides fast, cached analytics with intelligent data management
class OptimizedAnalyticsService {
  static final OptimizedAnalyticsService _instance = OptimizedAnalyticsService._internal();
  factory OptimizedAnalyticsService() => _instance;
  OptimizedAnalyticsService._internal();

  // Services
  final InvoiceCreationService _invoiceCreationService = InvoiceCreationService();
  final ReportsPerformanceMonitor _performanceMonitor = ReportsPerformanceMonitor();

  // Cache management
  final Map<String, dynamic> _memoryCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiration = Duration(minutes: 30);

  // Performance tracking
  final Map<String, Stopwatch> _operationTimers = {};
  final Map<String, int> _cacheHitCounts = {};
  final Map<String, int> _cacheMissCounts = {};

  /// Get comprehensive dashboard statistics with intelligent caching
  Future<Map<String, dynamic>> getDashboardStatistics({
    String period = 'أسبوعي',
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'dashboard_stats_$period';
    final operationName = 'getDashboardStatistics_$period';

    // Start performance monitoring
    _performanceMonitor.startOperation(operationName);

    try {
      // Check cache first unless force refresh is requested
      if (!forceRefresh && _isCacheValid(cacheKey)) {
        _recordCacheHit(cacheKey);
        _performanceMonitor.recordCacheHit(cacheKey);
        AppLogger.info('📋 Using cached dashboard statistics for period: $period');
        final result = _memoryCache[cacheKey] as Map<String, dynamic>;
        _performanceMonitor.endOperation(operationName);
        return result;
      }

      _recordCacheMiss(cacheKey);
      _performanceMonitor.recordCacheMiss(cacheKey);
      _startTimer('dashboard_stats_$period');

      AppLogger.info('🔄 Generating optimized dashboard statistics for period: $period');

      // Use existing optimized services instead of manual calculations
      final results = await Future.wait([
        _getOptimizedInvoiceStatistics(),
        _getOptimizedSalesData(period),
        _getOptimizedProductStatistics(),
        _getOptimizedOrderStatistics(),
      ]);

      final invoiceStats = results[0];
      final salesData = results[1];
      final productStats = results[2];
      final orderStats = results[3];

      final dashboardStats = {
        'period': period,
        'lastUpdated': DateTime.now().toIso8601String(),
        'invoiceStatistics': invoiceStats,
        'salesData': salesData,
        'productStatistics': productStats,
        'orderStatistics': orderStats,
        'summary': _generateSummaryMetrics(invoiceStats, salesData, productStats, orderStats),
        'performanceMetrics': _performanceMonitor.getPerformanceStatistics(),
      };

      // Cache the results
      await _cacheResults(cacheKey, dashboardStats);

      final elapsed = _endTimer('dashboard_stats_$period');
      AppLogger.info('✅ Dashboard statistics generated in ${elapsed.inMilliseconds}ms for period: $period');

      _performanceMonitor.endOperation(operationName);
      return dashboardStats;
    } catch (e) {
      _endTimer('dashboard_stats_$period');
      _performanceMonitor.endOperation(operationName);
      AppLogger.error('❌ Error generating dashboard statistics: $e');
      return _getFallbackStatistics(period);
    }
  }

  /// Get optimized invoice statistics using existing services
  Future<Map<String, dynamic>> _getOptimizedInvoiceStatistics() async {
    try {
      // Use existing InvoiceCreationService which is already optimized
      final stats = await _invoiceCreationService.getInvoiceStatistics();
      
      if (stats.isNotEmpty) {
        return {
          'totalInvoices': stats['total_invoices'] ?? 0,
          'totalAmount': stats['total_amount'] ?? 0.0,
          'paidInvoices': stats['paid_invoices'] ?? 0,
          'pendingInvoices': stats['pending_invoices'] ?? 0,
          'draftInvoices': stats['draft_invoices'] ?? 0,
        };
      }

      // Fallback to basic statistics
      return {
        'totalInvoices': 0,
        'totalAmount': 0.0,
        'paidInvoices': 0,
        'pendingInvoices': 0,
        'draftInvoices': 0,
      };
    } catch (e) {
      AppLogger.error('❌ Error getting optimized invoice statistics: $e');
      return {
        'totalInvoices': 0,
        'totalAmount': 0.0,
        'paidInvoices': 0,
        'pendingInvoices': 0,
        'draftInvoices': 0,
      };
    }
  }

  /// Get optimized sales data for specific period
  Future<Map<String, dynamic>> _getOptimizedSalesData(String period) async {
    try {
      // Use existing invoice service for sales data
      final invoiceStats = await _invoiceCreationService.getInvoiceStatistics();

      return {
        'totalSales': invoiceStats['total_amount']?.toDouble() ?? 0.0,
        'totalOrders': invoiceStats['total_invoices'] ?? 0,
        'averageOrderValue': invoiceStats['average_amount']?.toDouble() ?? 0.0,
        'salesChart': _generateChartData(period, {}),
        'ordersChart': _generateOrdersChartData(period, {}),
        'salesChange': 0.0, // Would need historical data
        'ordersChange': 0.0,
      };
    } catch (e) {
      AppLogger.error('❌ Error getting optimized sales data: $e');
      return _getEmptySalesData();
    }
  }

  /// Get optimized product statistics using SimplifiedProductProvider
  Future<Map<String, dynamic>> _getOptimizedProductStatistics() async {
    try {
      // Use RealProfitabilityService for accurate profitability data
      final profitabilityData = await RealProfitabilityService.calculateRealProfitability();
      
      return {
        'totalProducts': profitabilityData['totalProducts'] ?? 0,
        'profitableProducts': profitabilityData['profitableProducts'] ?? 0,
        'lossProducts': profitabilityData['lossProducts'] ?? 0,
        'totalRevenue': profitabilityData['totalRevenue'] ?? 0.0,
        'totalProfit': profitabilityData['totalProfit'] ?? 0.0,
        'profitMargin': profitabilityData['profitMargin'] ?? 0.0,
        'topProfitable': profitabilityData['topProfitable'] ?? [],
        'leastProfitable': profitabilityData['leastProfitable'] ?? [],
      };
    } catch (e) {
      AppLogger.error('❌ Error getting optimized product statistics: $e');
      return {
        'totalProducts': 0,
        'profitableProducts': 0,
        'lossProducts': 0,
        'totalRevenue': 0.0,
        'totalProfit': 0.0,
        'profitMargin': 0.0,
        'topProfitable': [],
        'leastProfitable': [],
      };
    }
  }

  /// Get optimized order statistics using existing services
  Future<Map<String, dynamic>> _getOptimizedOrderStatistics() async {
    try {
      // Use existing services for order data
      final ordersService = SupabaseOrdersService();
      final stats = await ordersService.getOrderStatistics();

      if (stats != null) {
        return stats;
      }

      // Fallback to basic statistics
      return {
        'totalOrders': 0,
        'todayOrders': 0,
        'pendingOrders': 0,
        'completedOrders': 0,
        'totalOrderValue': 0.0,
      };
    } catch (e) {
      AppLogger.error('❌ Error getting optimized order statistics: $e');
      return {
        'totalOrders': 0,
        'todayOrders': 0,
        'pendingOrders': 0,
        'completedOrders': 0,
        'totalOrderValue': 0.0,
      };
    }
  }

  /// Generate summary metrics from all statistics
  Map<String, dynamic> _generateSummaryMetrics(
    Map<String, dynamic> invoiceStats,
    Map<String, dynamic> salesData,
    Map<String, dynamic> productStats,
    Map<String, dynamic> orderStats,
  ) {
    return {
      'totalRevenue': (invoiceStats['totalAmount'] ?? 0.0) + (orderStats['totalOrderValue'] ?? 0.0),
      'totalTransactions': (invoiceStats['totalInvoices'] ?? 0) + (orderStats['totalOrders'] ?? 0),
      'profitMargin': productStats['profitMargin'] ?? 0.0,
      'growthRate': salesData['salesChange'] ?? 0.0,
      'activeProducts': productStats['totalProducts'] ?? 0,
      'todayActivity': orderStats['todayOrders'] ?? 0,
    };
  }

  /// Cache management methods
  bool _isCacheValid(String key) {
    if (!_memoryCache.containsKey(key) || !_cacheTimestamps.containsKey(key)) {
      return false;
    }
    
    final timestamp = _cacheTimestamps[key]!;
    return DateTime.now().difference(timestamp) < _cacheExpiration;
  }

  Future<void> _cacheResults(String key, Map<String, dynamic> data) async {
    _memoryCache[key] = data;
    _cacheTimestamps[key] = DateTime.now();
    AppLogger.info('📋 Cached results for key: $key');
  }

  /// Performance tracking methods
  void _startTimer(String operation) {
    _operationTimers[operation] = Stopwatch()..start();
  }

  Duration _endTimer(String operation) {
    final timer = _operationTimers.remove(operation);
    if (timer != null) {
      timer.stop();
      return timer.elapsed;
    }
    return Duration.zero;
  }

  void _recordCacheHit(String key) {
    _cacheHitCounts[key] = (_cacheHitCounts[key] ?? 0) + 1;
  }

  void _recordCacheMiss(String key) {
    _cacheMissCounts[key] = (_cacheMissCounts[key] ?? 0) + 1;
  }

  /// Get performance metrics for monitoring
  Map<String, dynamic> getPerformanceMetrics() {
    final totalHits = _cacheHitCounts.values.fold(0, (sum, count) => sum + count);
    final totalMisses = _cacheMissCounts.values.fold(0, (sum, count) => sum + count);
    final hitRate = totalHits + totalMisses > 0 ? totalHits / (totalHits + totalMisses) : 0.0;

    return {
      'cacheHitRate': hitRate,
      'totalCacheHits': totalHits,
      'totalCacheMisses': totalMisses,
      'cachedItems': _memoryCache.length,
      'lastUpdated': DateTime.now().toIso8601String(),
    };
  }

  /// Clear all caches
  void clearCache() {
    _memoryCache.clear();
    _cacheTimestamps.clear();
    _cacheHitCounts.clear();
    _cacheMissCounts.clear();
    AppLogger.info('🧹 Cleared all analytics caches');
  }

  /// Get empty sales data structure
  Map<String, dynamic> _getEmptySalesData() {
    return {
      'totalSales': 0.0,
      'totalOrders': 0,
      'averageOrderValue': 0.0,
      'salesChart': List.filled(7, 0.0),
      'ordersChart': List.filled(7, 0.0),
      'salesChange': 0.0,
      'ordersChange': 0.0,
    };
  }

  /// Generate chart data from aggregated data
  List<double> _generateChartData(String period, Map<String, dynamic> data) {
    // This would be populated by the RPC function
    final chartData = data['chart_data'] as List<dynamic>?;
    if (chartData != null) {
      return chartData.map((e) => (e as num).toDouble()).toList();
    }

    // Fallback to empty chart data
    switch (period) {
      case 'أسبوعي':
        return List.filled(7, 0.0);
      case 'شهري':
        return List.filled(4, 0.0);
      case 'سنوي':
        return List.filled(12, 0.0);
      default:
        return List.filled(7, 0.0);
    }
  }

  /// Generate orders chart data
  List<double> _generateOrdersChartData(String period, Map<String, dynamic> data) {
    final ordersData = data['orders_chart'] as List<dynamic>?;
    if (ordersData != null) {
      return ordersData.map((e) => (e as num).toDouble()).toList();
    }

    // Fallback to empty chart data
    switch (period) {
      case 'أسبوعي':
        return List.filled(7, 0.0);
      case 'شهري':
        return List.filled(4, 0.0);
      case 'سنوي':
        return List.filled(12, 0.0);
      default:
        return List.filled(7, 0.0);
    }
  }



  /// Get fallback statistics when all else fails
  Map<String, dynamic> _getFallbackStatistics(String period) {
    return {
      'period': period,
      'lastUpdated': DateTime.now().toIso8601String(),
      'invoiceStatistics': {
        'totalInvoices': 0,
        'totalAmount': 0.0,
        'paidInvoices': 0,
        'pendingInvoices': 0,
        'draftInvoices': 0,
      },
      'salesData': _getEmptySalesData(),
      'productStatistics': {
        'totalProducts': 0,
        'profitableProducts': 0,
        'lossProducts': 0,
        'totalRevenue': 0.0,
        'totalProfit': 0.0,
        'profitMargin': 0.0,
        'topProfitable': [],
        'leastProfitable': [],
      },
      'orderStatistics': {
        'totalOrders': 0,
        'todayOrders': 0,
        'pendingOrders': 0,
        'completedOrders': 0,
        'totalOrderValue': 0.0,
      },
      'summary': {
        'totalRevenue': 0.0,
        'totalTransactions': 0,
        'profitMargin': 0.0,
        'growthRate': 0.0,
        'activeProducts': 0,
        'todayActivity': 0,
      },
    };
  }

  /// Initialize the service
  void initialize() {
    AppLogger.info('🚀 OptimizedAnalyticsService initialized');
  }
}
