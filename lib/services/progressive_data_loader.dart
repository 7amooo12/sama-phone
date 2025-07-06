import 'dart:async';
import '../models/flask_product_model.dart';
import '../models/product_movement_model.dart';
import '../utils/app_logger.dart';

/// CRITICAL PERFORMANCE: Progressive data loader for immediate UI responsiveness
/// This service loads data in chunks and provides immediate partial results
class ProgressiveDataLoader {
  static final ProgressiveDataLoader _instance = ProgressiveDataLoader._internal();
  factory ProgressiveDataLoader() => _instance;
  ProgressiveDataLoader._internal();

  // Stream controllers for real-time data updates
  final Map<String, StreamController<List<dynamic>>> _dataStreams = {};
  final Map<String, StreamController<double>> _progressStreams = {};
  
  // Loading state management
  final Map<String, bool> _isLoading = {};
  final Map<String, List<dynamic>> _loadedData = {};
  final Map<String, int> _totalItems = {};

  /// ULTRA-FAST: Start progressive loading with immediate partial results
  Stream<List<T>> startProgressiveLoading<T>(
    String operationId,
    Future<List<T>> Function() dataLoader, {
    int batchSize = 10,
    Duration batchDelay = const Duration(milliseconds: 50),
    bool showImmediateResults = true,
  }) async* {
    try {
      AppLogger.info('🚀 Starting progressive loading: $operationId');
      
      // Initialize streams
      _initializeStreams(operationId);
      _isLoading[operationId] = true;
      _loadedData[operationId] = [];

      // Load all data in background
      final allData = await dataLoader();
      _totalItems[operationId] = allData.length;
      
      if (allData.isEmpty) {
        _isLoading[operationId] = false;
        yield [];
        return;
      }

      // Progressive display
      final batches = _createBatches(allData, batchSize);
      
      for (int i = 0; i < batches.length; i++) {
        final batch = batches[i];
        _loadedData[operationId]!.addAll(batch);
        
        // Update progress
        final progress = (i + 1) / batches.length;
        _progressStreams[operationId]?.add(progress);
        
        // Yield current data
        yield List<T>.from(_loadedData[operationId]!);
        
        // Delay between batches (except last)
        if (i < batches.length - 1) {
          await Future.delayed(batchDelay);
        }
      }
      
      _isLoading[operationId] = false;
      AppLogger.info('✅ Progressive loading completed: $operationId');
      
    } catch (e) {
      AppLogger.error('❌ Progressive loading failed: $operationId - $e');
      _isLoading[operationId] = false;
      rethrow;
    }
  }

  /// PERFORMANCE OPTIMIZATION: Load category data progressively
  Stream<Map<String, List<FlaskProductModel>>> loadCategoryDataProgressively(
    List<FlaskProductModel> products, {
    int categoriesPerBatch = 3,
    Duration batchDelay = const Duration(milliseconds: 100),
  }) async* {
    try {
      AppLogger.info('🚀 Starting progressive category loading for ${products.length} products');
      
      // Group products by category
      final categoryMap = <String, List<FlaskProductModel>>{};
      for (final product in products) {
        final category = product.categoryName ?? 'غير محدد';
        categoryMap.putIfAbsent(category, () => []).add(product);
      }
      
      final categories = categoryMap.keys.toList();
      final result = <String, List<FlaskProductModel>>{};
      
      // Load categories in batches
      for (int i = 0; i < categories.length; i += categoriesPerBatch) {
        final batchCategories = categories.skip(i).take(categoriesPerBatch);
        
        for (final category in batchCategories) {
          result[category] = categoryMap[category]!;
        }
        
        yield Map<String, List<FlaskProductModel>>.from(result);
        
        // Delay between batches
        if (i + categoriesPerBatch < categories.length) {
          await Future.delayed(batchDelay);
        }
      }
      
      AppLogger.info('✅ Progressive category loading completed');
      
    } catch (e) {
      AppLogger.error('❌ Progressive category loading failed: $e');
      rethrow;
    }
  }

  /// CRITICAL OPTIMIZATION: Load movement data with immediate statistics
  Stream<Map<String, dynamic>> loadMovementDataProgressively(
    List<FlaskProductModel> products,
    Future<Map<int, ProductMovementModel>> Function(List<FlaskProductModel>) bulkLoader, {
    int productsPerBatch = 5,
    Duration batchDelay = const Duration(milliseconds: 100),
  }) async* {
    try {
      AppLogger.info('🚀 Starting progressive movement loading for ${products.length} products');
      
      final result = <String, dynamic>{
        'products': <FlaskProductModel>[],
        'movements': <int, ProductMovementModel>{},
        'statistics': <String, dynamic>{
          'totalRevenue': 0.0,
          'totalSales': 0,
          'processedProducts': 0,
        },
      };
      
      // Process products in batches
      for (int i = 0; i < products.length; i += productsPerBatch) {
        final batch = products.skip(i).take(productsPerBatch).toList();
        
        // Load movement data for batch
        final batchMovements = await bulkLoader(batch);
        
        // Update result
        result['products'] = [...(result['products'] as List<FlaskProductModel>), ...batch];
        (result['movements'] as Map<int, ProductMovementModel>).addAll(batchMovements);
        
        // Update statistics
        double totalRevenue = (result['statistics'] as Map<String, dynamic>)['totalRevenue'] as double;
        int totalSales = (result['statistics'] as Map<String, dynamic>)['totalSales'] as int;
        
        for (final movement in batchMovements.values) {
          totalRevenue += movement.statistics.totalRevenue;
          totalSales += movement.statistics.totalSoldQuantity;
        }
        
        (result['statistics'] as Map<String, dynamic>)['totalRevenue'] = totalRevenue;
        (result['statistics'] as Map<String, dynamic>)['totalSales'] = totalSales;
        (result['statistics'] as Map<String, dynamic>)['processedProducts'] = i + batch.length;
        
        yield Map<String, dynamic>.from(result);
        
        // Delay between batches
        if (i + productsPerBatch < products.length) {
          await Future.delayed(batchDelay);
        }
      }
      
      AppLogger.info('✅ Progressive movement loading completed');
      
    } catch (e) {
      AppLogger.error('❌ Progressive movement loading failed: $e');
      rethrow;
    }
  }

  /// Get progress stream for an operation
  Stream<double>? getProgressStream(String operationId) {
    return _progressStreams[operationId]?.stream;
  }

  /// Check if operation is loading
  bool isLoading(String operationId) {
    return _isLoading[operationId] ?? false;
  }

  /// Get current loaded data count
  int getLoadedCount(String operationId) {
    return _loadedData[operationId]?.length ?? 0;
  }

  /// Get total items count
  int getTotalCount(String operationId) {
    return _totalItems[operationId] ?? 0;
  }

  /// Cancel progressive loading
  void cancelLoading(String operationId) {
    _isLoading[operationId] = false;
    _cleanupStreams(operationId);
    AppLogger.info('🛑 Cancelled progressive loading: $operationId');
  }

  /// Initialize streams for an operation
  void _initializeStreams(String operationId) {
    _dataStreams[operationId] = StreamController<List<dynamic>>.broadcast();
    _progressStreams[operationId] = StreamController<double>.broadcast();
  }

  /// Cleanup streams for an operation
  void _cleanupStreams(String operationId) {
    _dataStreams[operationId]?.close();
    _progressStreams[operationId]?.close();
    _dataStreams.remove(operationId);
    _progressStreams.remove(operationId);
    _loadedData.remove(operationId);
    _totalItems.remove(operationId);
    _isLoading.remove(operationId);
  }

  /// Create batches from data list
  List<List<T>> _createBatches<T>(List<T> data, int batchSize) {
    final batches = <List<T>>[];
    for (int i = 0; i < data.length; i += batchSize) {
      final end = (i + batchSize < data.length) ? i + batchSize : data.length;
      batches.add(data.sublist(i, end));
    }
    return batches;
  }

  /// Cleanup all operations
  void dispose() {
    for (final operationId in _dataStreams.keys.toList()) {
      _cleanupStreams(operationId);
    }
    AppLogger.info('🧹 Progressive data loader disposed');
  }

  /// Get loading statistics
  Map<String, dynamic> getLoadingStatistics() {
    return {
      'activeOperations': _isLoading.values.where((loading) => loading).length,
      'totalOperations': _isLoading.length,
      'totalLoadedItems': _loadedData.values.fold<int>(0, (sum, list) => sum + list.length),
    };
  }
}
