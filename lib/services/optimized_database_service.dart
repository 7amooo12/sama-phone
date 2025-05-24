import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartbiztracker_new/models/user_model.dart';
import 'package:smartbiztracker_new/models/product_model.dart';
import 'package:smartbiztracker_new/models/order_model.dart';
import 'package:smartbiztracker_new/services/cache_service.dart';
import '../utils/logger.dart';

/// An optimized database service that uses caching to improve performance
class OptimizedDatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache keys
  static const String _userCacheKey = 'user_';
  static const String _productsCacheKey = 'products';
  static const String _productCacheKey = 'product_';
  static const String _ordersCacheKey = 'orders';
  static const String _orderCacheKey = 'order_';

  // Cache durations
  static const Duration _userCacheDuration = Duration(minutes: 15);
  static const Duration _productsCacheDuration = Duration(minutes: 10);
  static const Duration _ordersCacheDuration = Duration(minutes: 5);

  // Collection references
  CollectionReference get _usersCollection => _firestore.collection('users');
  CollectionReference get _productsCollection => _firestore.collection('products');
  CollectionReference get _ordersCollection => _firestore.collection('orders');

  // Users

  /// Get a user by ID with caching
  Future<UserModel?> getUserById(String userId) async {
    try {
      // Try to get from cache first
      final cachedUser = await CacheService.getCachedData<Map<String, dynamic>>(_userCacheKey + userId);

      if (cachedUser != null) {
        AppLogger.info('Retrieved user $userId from cache');
        return UserModel.fromJson(cachedUser, userId);
      }

      // If not in cache, get from Firestore
      final docSnapshot = await _usersCollection.doc(userId).get();

      if (docSnapshot.exists) {
        final userData = docSnapshot.data() as Map<String, dynamic>;

        // Cache the user data
        await CacheService.cacheData(
          key: _userCacheKey + userId,
          data: userData,
          expiration: _userCacheDuration,
        );

        return UserModel.fromJson(userData, docSnapshot.id);
      }

      return null;
    } catch (e) {
      AppLogger.error('Error getting user by ID: $userId', e);
      throw Exception('Failed to get user');
    }
  }

  /// Create a new user
  Future<void> createUser(UserModel user) async {
    try {
      await _usersCollection.doc(user.id).set(user.toJson());

      // Cache the new user
      await CacheService.cacheData(
        key: _userCacheKey + user.id,
        data: user.toJson(),
        expiration: _userCacheDuration,
      );
    } catch (e) {
      AppLogger.error('Error creating user', e);
      throw Exception('Failed to create user');
    }
  }

  /// Update an existing user
  Future<void> updateUser(UserModel user) async {
    try {
      await _usersCollection.doc(user.id).update(user.toJson());

      // Update the cache
      await CacheService.cacheData(
        key: _userCacheKey + user.id,
        data: user.toJson(),
        expiration: _userCacheDuration,
      );
    } catch (e) {
      AppLogger.error('Error updating user', e);
      throw Exception('Failed to update user');
    }
  }

  /// Delete a user
  Future<void> deleteUser(String userId) async {
    try {
      await _usersCollection.doc(userId).delete();

      // Remove from cache
      await CacheService.removeCachedData(_userCacheKey + userId);
    } catch (e) {
      AppLogger.error('Error deleting user', e);
      throw Exception('Failed to delete user');
    }
  }

  // Products

  /// Get all products with caching
  Future<List<ProductModel>> getProducts() async {
    try {
      // Try to get from cache first
      final cachedProducts = await CacheService.getCachedData<List<dynamic>>(_productsCacheKey);

      if (cachedProducts != null) {
        AppLogger.info('Retrieved products from cache');
        return cachedProducts
            .map((product) => ProductModel.fromJson(product as Map<String, dynamic>))
            .toList();
      }

      // If not in cache, get from Firestore
      final QuerySnapshot snapshot = await _productsCollection.get();

      final products = snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return ProductModel.fromJson(data);
          })
          .toList();

      // Cache the products
      await CacheService.cacheData(
        key: _productsCacheKey,
        data: products.map((product) => product.toJson()).toList(),
        expiration: _productsCacheDuration,
      );

      return products;
    } catch (e) {
      AppLogger.error('Error getting products', e);
      return [];
    }
  }

  /// Get a product by ID with caching
  Future<ProductModel?> getProductById(String productId) async {
    try {
      // Try to get from cache first
      final cachedProduct = await CacheService.getCachedData<Map<String, dynamic>>(_productCacheKey + productId);

      if (cachedProduct != null) {
        AppLogger.info('Retrieved product $productId from cache');
        return ProductModel.fromJson(cachedProduct);
      }

      // If not in cache, get from Firestore
      final docSnapshot = await _productsCollection.doc(productId).get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        data['id'] = docSnapshot.id;

        // Cache the product data
        await CacheService.cacheData(
          key: _productCacheKey + productId,
          data: data,
          expiration: _productsCacheDuration,
        );

        return ProductModel.fromJson(data);
      }

      return null;
    } catch (e) {
      AppLogger.error('Error getting product by ID: $productId', e);
      return null;
    }
  }
  /// Create a new product with caching
  Future<void> createProduct(ProductModel product) async {
    try {
      await _productsCollection.doc(product.id).set(product.toJson());

      // Cache the new product
      await CacheService.cacheData(
        key: _productCacheKey + product.id,
        data: product.toJson(),
        expiration: _productsCacheDuration,
      );

      // Invalidate products list cache
      await CacheService.removeCachedData(_productsCacheKey);
    } catch (e) {
      AppLogger.error('Error creating product', e);
      throw Exception('Failed to create product');
    }
  }

  /// Update an existing product
  Future<void> updateProduct(ProductModel product) async {
    try {
      await _productsCollection.doc(product.id).update(product.toJson());

      // Update the cache
      await CacheService.cacheData(
        key: _productCacheKey + product.id,
        data: product.toJson(),
        expiration: _productsCacheDuration,
      );

      // Invalidate products list cache
      await CacheService.removeCachedData(_productsCacheKey);
    } catch (e) {
      AppLogger.error('Error updating product', e);
      throw Exception('Failed to update product');
    }
  }

  /// Delete a product
  Future<void> deleteProduct(String productId) async {
    try {
      await _productsCollection.doc(productId).delete();

      // Remove from cache
      await CacheService.removeCachedData(_productCacheKey + productId);

      // Invalidate products list cache
      await CacheService.removeCachedData(_productsCacheKey);
    } catch (e) {
      AppLogger.error('Error deleting product', e);
      throw Exception('Failed to delete product');
    }
  }

  // Orders

  /// Get all orders with caching
  Future<List<OrderModel>> getOrders() async {
    try {
      // Try to get from cache first
      final cachedOrders = await CacheService.getCachedData<List<dynamic>>(_ordersCacheKey);

      if (cachedOrders != null) {
        AppLogger.info('Retrieved orders from cache');
        return cachedOrders
            .map((order) => OrderModel.fromJson(order as Map<String, dynamic>))
            .toList();
      }

      // If not in cache, get from Firestore
      final QuerySnapshot snapshot = await _ordersCollection
          .orderBy('orderDate', descending: true)
          .get();

      final orders = snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return OrderModel.fromJson(data);
          })
          .toList();

      // Cache the orders
      await CacheService.cacheData(
        key: _ordersCacheKey,
        data: orders.map((order) => order.toJson()).toList(),
        expiration: _ordersCacheDuration,
      );

      return orders;
    } catch (e) {
      AppLogger.error('Error getting orders', e);
      return [];
    }
  }

  /// Get orders by client with caching
  Future<List<OrderModel>> getOrdersByClient(String clientId) async {
    try {
      final cacheKey = '${_ordersCacheKey}_client_$clientId';

      // Try to get from cache first
      final cachedOrders = await CacheService.getCachedData<List<dynamic>>(cacheKey);

      if (cachedOrders != null) {
        AppLogger.info('Retrieved client orders from cache');
        return cachedOrders
            .map((order) => OrderModel.fromJson(order as Map<String, dynamic>))
            .toList();
      }

      // If not in cache, get from Firestore
      final QuerySnapshot snapshot = await _ordersCollection
          .where('clientId', isEqualTo: clientId)
          .orderBy('orderDate', descending: true)
          .get();

      final orders = snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return OrderModel.fromJson(data);
          })
          .toList();

      // Cache the orders
      await CacheService.cacheData(
        key: cacheKey,
        data: orders.map((order) => order.toJson()).toList(),
        expiration: _ordersCacheDuration,
      );

      return orders;
    } catch (e) {
      AppLogger.error('Error getting client orders', e);
      return [];
    }
  }

  /// Clear all caches
  Future<void> clearAllCaches() async {
    try {
      await CacheService.clearAllCache();
      AppLogger.info('All caches cleared');
    } catch (e) {
      AppLogger.error('Error clearing caches', e);
    }
  }
}