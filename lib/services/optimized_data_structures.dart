import 'dart:collection';
import 'dart:typed_data';
import '../models/flask_product_model.dart';
import '../models/product_movement_model.dart';
import '../utils/app_logger.dart';

/// CRITICAL PERFORMANCE: Optimized data structures for maximum performance
/// This service provides specialized data structures optimized for reports processing

/// ULTRA-FAST: Optimized product index for O(1) lookups
class OptimizedProductIndex {
  final Map<int, FlaskProductModel> _idIndex = {};
  final Map<String, List<FlaskProductModel>> _categoryIndex = {};
  final Map<String, List<FlaskProductModel>> _nameIndex = {};
  final SplayTreeMap<double, List<FlaskProductModel>> _priceIndex = SplayTreeMap();
  
  /// Build all indexes for ultra-fast lookups
  void buildIndexes(List<FlaskProductModel> products) {
    final stopwatch = Stopwatch()..start();
    
    // Clear existing indexes
    _idIndex.clear();
    _categoryIndex.clear();
    _nameIndex.clear();
    _priceIndex.clear();
    
    for (final product in products) {
      // ID index for O(1) lookup by ID
      _idIndex[product.id] = product;
      
      // Category index for fast category filtering
      _categoryIndex.putIfAbsent(product.categoryName ?? '', () => []).add(product);
      
      // Name index for fast name searching
      final nameKey = product.name.toLowerCase();
      _nameIndex.putIfAbsent(nameKey, () => []).add(product);
      
      // Price index for range queries
      _priceIndex.putIfAbsent(product.finalPrice, () => []).add(product);
    }
    
    stopwatch.stop();
    AppLogger.info('📊 Built optimized indexes for ${products.length} products in ${stopwatch.elapsedMilliseconds}ms');
  }
  
  /// O(1) lookup by product ID
  FlaskProductModel? getById(int id) => _idIndex[id];
  
  /// O(1) lookup by category
  List<FlaskProductModel> getByCategory(String category) => _categoryIndex[category] ?? [];
  
  /// Fast name search with partial matching
  List<FlaskProductModel> searchByName(String query) {
    final lowerQuery = query.toLowerCase();
    final results = <FlaskProductModel>[];
    
    for (final entry in _nameIndex.entries) {
      if (entry.key.contains(lowerQuery)) {
        results.addAll(entry.value);
      }
    }
    
    return results;
  }
  
  /// Fast price range queries
  List<FlaskProductModel> getByPriceRange(double minPrice, double maxPrice) {
    final results = <FlaskProductModel>[];

    for (final entry in _priceIndex.entries) {
      if (entry.key >= minPrice && entry.key <= maxPrice) {
        results.addAll(entry.value);
      }
    }

    return results;
  }
  
  /// Get all categories
  Set<String> getAllCategories() => _categoryIndex.keys.toSet();
  
  /// Get statistics
  Map<String, int> getIndexStatistics() {
    return {
      'totalProducts': _idIndex.length,
      'categories': _categoryIndex.length,
      'uniqueNames': _nameIndex.length,
      'uniquePrices': _priceIndex.length,
    };
  }
}

/// MEMORY-EFFICIENT: Compressed movement data storage
class CompressedMovementStorage {
  final Map<int, Uint8List> _compressedData = {};
  final Map<int, DateTime> _timestamps = {};
  
  /// Store movement data in compressed format
  void store(int productId, ProductMovementModel movement) {
    try {
      // Convert to compact representation
      final compactData = _compressMovementData(movement);
      _compressedData[productId] = compactData;
      _timestamps[productId] = DateTime.now();
      
      AppLogger.info('📦 Compressed movement data for product: $productId');
    } catch (e) {
      AppLogger.error('❌ Error compressing movement data: $e');
    }
  }
  
  /// Retrieve and decompress movement data
  ProductMovementModel? retrieve(int productId) {
    try {
      final compressedData = _compressedData[productId];
      if (compressedData != null) {
        return _decompressMovementData(compressedData);
      }
      return null;
    } catch (e) {
      AppLogger.error('❌ Error decompressing movement data: $e');
      return null;
    }
  }
  
  /// Check if data exists and is fresh
  bool hasValidData(int productId, {Duration maxAge = const Duration(hours: 1)}) {
    final timestamp = _timestamps[productId];
    if (timestamp == null) return false;
    
    return DateTime.now().difference(timestamp) <= maxAge;
  }
  
  /// Compress movement data to bytes
  Uint8List _compressMovementData(ProductMovementModel movement) {
    // Simplified compression - in real implementation would use proper compression
    final stats = movement.statistics;
    final data = [
      stats.totalSoldQuantity,
      (stats.totalRevenue * 100).toInt(), // Store as cents to avoid floating point
      (stats.averageSalePrice * 100).toInt(),
      (stats.profitMargin * 100).toInt(),
      stats.totalSalesCount,
      stats.currentStock,
    ];
    
    final bytes = Uint8List(data.length * 4); // 4 bytes per int
    final byteData = ByteData.sublistView(bytes);
    
    for (int i = 0; i < data.length; i++) {
      byteData.setInt32(i * 4, data[i]);
    }
    
    return bytes;
  }
  
  /// Decompress movement data from bytes
  ProductMovementModel _decompressMovementData(Uint8List bytes) {
    final byteData = ByteData.sublistView(bytes);
    
    final totalSoldQuantity = byteData.getInt32(0);
    final totalRevenue = byteData.getInt32(4) / 100.0;
    final averageSalePrice = byteData.getInt32(8) / 100.0;
    final profitMargin = byteData.getInt32(12) / 100.0;
    final totalSalesCount = byteData.getInt32(16);
    final currentStock = byteData.getInt32(20);
    
    // Create minimal movement model with essential data
    final statistics = ProductMovementStatisticsModel(
      totalSoldQuantity: totalSoldQuantity,
      totalRevenue: totalRevenue,
      averageSalePrice: averageSalePrice,
      profitPerUnit: 0.0, // Calculated on demand
      totalProfit: 0.0, // Calculated on demand
      profitMargin: profitMargin,
      totalSalesCount: totalSalesCount,
      currentStock: currentStock,
    );
    
    // Create minimal product model
    final product = ProductMovementProductModel(
      id: 0, // Will be set by caller
      name: '', // Will be set by caller
      sku: '',
      category: '',
      currentStock: currentStock,
      sellingPrice: averageSalePrice,
      purchasePrice: 0.0,
      imageUrl: '',
    );
    
    return ProductMovementModel(
      product: product,
      salesData: [], // Empty for compressed storage
      movementData: [], // Empty for compressed storage
      statistics: statistics,
    );
  }
  
  /// Get storage statistics
  Map<String, dynamic> getStorageStatistics() {
    int totalBytes = 0;
    for (final data in _compressedData.values) {
      totalBytes += data.length;
    }
    
    return {
      'storedItems': _compressedData.length,
      'totalBytes': totalBytes,
      'averageBytesPerItem': _compressedData.isNotEmpty ? totalBytes / _compressedData.length : 0,
    };
  }
  
  /// Clear old data
  void clearOldData({Duration maxAge = const Duration(hours: 2)}) {
    final now = DateTime.now();
    final keysToRemove = <int>[];
    
    for (final entry in _timestamps.entries) {
      if (now.difference(entry.value) > maxAge) {
        keysToRemove.add(entry.key);
      }
    }
    
    for (final key in keysToRemove) {
      _compressedData.remove(key);
      _timestamps.remove(key);
    }
    
    if (keysToRemove.isNotEmpty) {
      AppLogger.info('🧹 Cleared ${keysToRemove.length} old compressed entries');
    }
  }
}

/// ULTRA-FAST: Optimized analytics aggregator
class OptimizedAnalyticsAggregator {
  final Map<String, double> _categoryRevenue = {};
  final Map<String, int> _categorySales = {};
  final Map<String, int> _categoryProducts = {};
  
  /// Add product data to aggregation
  void addProductData(String category, double revenue, int sales) {
    _categoryRevenue[category] = (_categoryRevenue[category] ?? 0.0) + revenue;
    _categorySales[category] = (_categorySales[category] ?? 0) + sales;
    _categoryProducts[category] = (_categoryProducts[category] ?? 0) + 1;
  }
  
  /// Get aggregated results
  Map<String, Map<String, dynamic>> getAggregatedResults() {
    final results = <String, Map<String, dynamic>>{};
    
    for (final category in _categoryRevenue.keys) {
      final revenue = _categoryRevenue[category] ?? 0.0;
      final sales = _categorySales[category] ?? 0;
      final products = _categoryProducts[category] ?? 0;
      
      results[category] = {
        'totalRevenue': revenue,
        'totalSales': sales,
        'totalProducts': products,
        'averageRevenuePerProduct': products > 0 ? revenue / products : 0.0,
        'averageSalesPerProduct': products > 0 ? sales / products : 0.0,
      };
    }
    
    return results;
  }
  
  /// Clear aggregation data
  void clear() {
    _categoryRevenue.clear();
    _categorySales.clear();
    _categoryProducts.clear();
  }
}

/// PERFORMANCE BOOST: Lazy-loaded data iterator
class LazyDataIterator<T> {
  LazyDataIterator(this._data, {int batchSize = 10}) : _batchSize = batchSize;

  final List<T> _data;
  final int _batchSize;
  int _currentIndex = 0;
  
  /// Get next batch of data
  List<T> getNextBatch() {
    if (_currentIndex >= _data.length) return [];
    
    final endIndex = (_currentIndex + _batchSize).clamp(0, _data.length);
    final batch = _data.sublist(_currentIndex, endIndex);
    _currentIndex = endIndex;
    
    return batch;
  }
  
  /// Check if more data is available
  bool get hasMore => _currentIndex < _data.length;
  
  /// Get remaining count
  int get remainingCount => _data.length - _currentIndex;
  
  /// Reset iterator
  void reset() => _currentIndex = 0;
}
