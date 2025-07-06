import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:smartbiztracker_new/models/flask_models.dart';
import 'package:smartbiztracker_new/utils/logger.dart';

class FlaskApiService {
  factory FlaskApiService() => _instance;
  FlaskApiService._internal();
  // Singleton pattern
  static final FlaskApiService _instance = FlaskApiService._internal();

  // Constants
  static const String _baseUrlKey = 'flask_api_base_url';
  static const String _tokenKey = 'flask_api_token';
  static const String _refreshTokenKey = 'flask_api_refresh_token';
  static const String _defaultBaseUrl = 'https://samastock.pythonanywhere.com';

  // Dependencies
  final Dio _dio = Dio();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Properties
  String? _baseUrl;
  String? _accessToken;
  String? _refreshToken;
  FlaskUserModel? _currentUser;

  // Getters
  String? get accessToken => _accessToken;
  FlaskUserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _accessToken != null && _currentUser != null;
  String get baseUrl => _baseUrl ?? _defaultBaseUrl;

  // Initialization
  Future<void> init() async {
    try {
      // Load base URL from secure storage or use default
      _baseUrl = await _secureStorage.read(key: _baseUrlKey) ?? _defaultBaseUrl;

      // Load tokens from secure storage
      _accessToken = await _secureStorage.read(key: _tokenKey);
      _refreshToken = await _secureStorage.read(key: _refreshTokenKey);

      // Setup dio interceptors
      _setupInterceptors();

      // If we have a token, fetch the user info to verify it's still valid
      if (_accessToken != null) {
        try {
          await _fetchUserInfo();
        } catch (e) {
          // If fetching user fails, try refreshing the token
          if (_refreshToken != null) {
            await refreshAccessToken();
          } else {
            // If no refresh token, clear tokens
            await logout();
          }
        }
      }

      AppLogger.info('FlaskApiService initialized with baseUrl: $_baseUrl');
    } catch (e) {
      AppLogger.error('Error initializing FlaskApiService', e);
      // Ensure we're logged out if there's an initialization error
      await logout();
    }
  }

  // Setup Dio interceptors
  void _setupInterceptors() {
    _dio.interceptors.clear();

    // Add logging interceptor
    _dio.interceptors.add(LogInterceptor(
      request: true,
      requestHeader: true,
      requestBody: true,
      responseHeader: true,
      responseBody: true,
      error: true,
    ));

    // Add auth interceptor
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // Add authorization header if we have a token
        if (_accessToken != null) {
          options.headers['Authorization'] = 'Bearer $_accessToken';
        }
        options.headers['Content-Type'] = 'application/json';
        options.headers['Accept'] = 'application/json';
        return handler.next(options);
      },
      onError: (DioException error, handler) async {
        // If 401 Unauthorized and we have a refresh token, try to refresh
        if (error.response?.statusCode == 401 && _refreshToken != null) {
          try {
            final refreshSuccess = await refreshAccessToken();
            if (refreshSuccess) {
              // Retry the failed request with the new token
              final options = error.requestOptions;
              options.headers['Authorization'] = 'Bearer $_accessToken';

              // Create a new request with the updated token
              final response = await _dio.fetch(options);
              return handler.resolve(response);
            }
          } catch (e) {
            AppLogger.error('Error refreshing token', e);
            // If refresh fails, continue with the original error
          }
        }
        return handler.next(error);
      }
    ));
  }

  // Set the base URL
  Future<void> setBaseUrl(String url) async {
    _baseUrl = url;
    await _secureStorage.write(key: _baseUrlKey, value: url);
    AppLogger.info('Base URL set to: $url');
  }

  // Authentication Methods
  Future<FlaskAuthModel> login(String username, String password) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$baseUrl/auth/login',
        data: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      final authModel = FlaskAuthModel.fromJson(response.data!);

      if (authModel.isAuthenticated) {
        // Save tokens
        _accessToken = authModel.accessToken;
        _refreshToken = authModel.refreshToken;
        _currentUser = authModel.user;

        // Store tokens in secure storage
        await _secureStorage.write(key: _tokenKey, value: _accessToken);
        await _secureStorage.write(key: _refreshTokenKey, value: _refreshToken);

        // Update dio interceptors with new token
        _setupInterceptors();

        AppLogger.info('User ${_currentUser?.username} logged in successfully');
      }

      return authModel;
    } catch (e) {
      AppLogger.error('Login error', e);
      if (e is DioException) {
        if (e.response?.statusCode == 403 &&
          e.response?.data != null &&
          e.response?.data is Map<String, dynamic>) {
          // Handle pending user status specially
          final errorData = e.response?.data as Map<String, dynamic>;
          if (errorData['status'] == 'pending') {
            return FlaskAuthModel.error(
              errorData['message'] ?? 'Account pending approval',
              status: 'pending'
            );
          }
          return FlaskAuthModel.error(errorData['message'] ?? 'Unknown error');
        }
        if (e.response?.data != null && e.response?.data is Map<String, dynamic>) {
          final errorData = e.response?.data as Map<String, dynamic>;
          return FlaskAuthModel.error(errorData['message'] ?? 'Unknown error');
        }
        return FlaskAuthModel.error('Network error: ${e.message}');
      }
      return FlaskAuthModel.error('Login failed: ${e.toString()}');
    }
  }

  Future<FlaskAuthModel> register(String username, String email, String password) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$baseUrl/api/auth/register',
        data: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
        }),
      );

      final authModel = FlaskAuthModel.fromJson(response.data!);

      if (authModel.isAuthenticated) {
        // Save tokens
        _accessToken = authModel.accessToken;
        _refreshToken = authModel.refreshToken;
        _currentUser = authModel.user;

        // Store tokens in secure storage
        await _secureStorage.write(key: _tokenKey, value: _accessToken);
        await _secureStorage.write(key: _refreshTokenKey, value: _refreshToken);

        // Update dio interceptors with new token
        _setupInterceptors();

        AppLogger.info('User ${_currentUser?.username} registered successfully');
      }

      return authModel;
    } catch (e) {
      AppLogger.error('Registration error', e);
      if (e is DioException) {
        if (e.response?.data != null && e.response?.data is Map<String, dynamic>) {
          final errorData = e.response?.data as Map<String, dynamic>;
          return FlaskAuthModel.error(errorData['error'] ?? 'Unknown error');
        }
        return FlaskAuthModel.error('Network error: ${e.message}');
      }
      return FlaskAuthModel.error('Registration failed: ${e.toString()}');
    }
  }

  Future<bool> refreshAccessToken() async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$baseUrl/api/auth/refresh',
        options: Options(
          headers: {
            'Authorization': 'Bearer $_refreshToken',
          },
        ),
      );

      final refreshData = response.data!;
      if (refreshData['success'] == true && refreshData['access_token'] != null) {
        _accessToken = refreshData['access_token'] as String;
        await _secureStorage.write(key: _tokenKey, value: _accessToken);

        // Update the user if provided
        if (refreshData['user'] != null) {
          _currentUser = FlaskUserModel.fromJson(refreshData['user'] as Map<String, dynamic>);
        } else {
          // Otherwise fetch the user info
          await _fetchUserInfo();
        }

        // Update dio interceptors with new token
        _setupInterceptors();

        AppLogger.info('Access token refreshed successfully');
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.error('Token refresh error', e);
      // If refresh fails, logout the user
      await logout();
      return false;
    }
  }

  Future<void> logout() async {
    // Clear tokens and user info
    _accessToken = null;
    _refreshToken = null;
    _currentUser = null;

    // Clear tokens from secure storage
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);

    // Update dio interceptors
    _setupInterceptors();

    AppLogger.info('User logged out');
  }

  Future<void> _fetchUserInfo() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$baseUrl/api/auth/user',
      );

      _currentUser = FlaskUserModel.fromJson(response.data!);
      AppLogger.info('User info fetched: ${_currentUser?.username}');
    } catch (e) {
      AppLogger.error('Error fetching user info', e);
      rethrow;
    }
  }

  // API Methods - Products
  Future<List<FlaskProductModel>> getProducts({
    double? minPrice,
    double? maxPrice,
    String? color,
    String? search,
    bool? inStock,
    bool? hasDiscount,
    String? sortBy,
    String? sortOrder,
    int? limit,
  }) async {
    try {
      // Build query parameters
      final queryParams = <String, dynamic>{};
      if (minPrice != null) queryParams['min_price'] = minPrice.toString();
      if (maxPrice != null) queryParams['max_price'] = maxPrice.toString();
      if (color != null) queryParams['color'] = color;
      if (search != null) queryParams['search'] = search;
      if (inStock != null) queryParams['in_stock'] = inStock ? '1' : '0';
      if (hasDiscount != null) queryParams['has_discount'] = hasDiscount ? '1' : '0';
      if (sortBy != null) queryParams['sort'] = sortBy;
      if (sortOrder != null) queryParams['order'] = sortOrder;
      if (limit != null) queryParams['limit'] = limit.toString();

      final response = await _dio.get<Map<String, dynamic>>(
        '$baseUrl/flutter/api/api/products',
        queryParameters: queryParams,
        options: Options(
          headers: {
            'x-api-key': 'lux2025FlutterAccess',
          },
        ),
      );

      final data = response.data!;
      final List<dynamic> productsData = data['products'] as List<dynamic>;

      return productsData
          .map((product) => FlaskProductModel.fromJson(product as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.error('Error fetching products', e);
      return [];
    }
  }

  Future<FlaskProductModel?> getProduct(int productId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$baseUrl/api/products/$productId',
      );

      return FlaskProductModel.fromJson(response.data!);
    } catch (e) {
      AppLogger.error('Error fetching product $productId', e);
      return null;
    }
  }

  // API Methods - Invoices
  Future<List<FlaskInvoiceModel>> getInvoices() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$baseUrl/api/invoices',
      );

      final data = response.data!;
      final List<dynamic> invoicesData = data['invoices'] as List<dynamic>;

      return invoicesData
          .map((invoice) => FlaskInvoiceModel.fromJson(invoice as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.error('Error fetching invoices', e);
      return [];
    }
  }

  Future<FlaskInvoiceModel?> getInvoice(int invoiceId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$baseUrl/api/invoices/$invoiceId',
      );

      return FlaskInvoiceModel.fromJson(response.data!);
    } catch (e) {
      AppLogger.error('Error fetching invoice $invoiceId', e);
      return null;
    }
  }

  // Get app settings
  Future<Map<String, dynamic>> getSettings() async {
    try {
      AppLogger.info('🔍 جلب الإعدادات من الخادم...');

      // Get auth token
      final token = await _secureStorage.read(key: _tokenKey);
      if (token == null) {
        AppLogger.warning('⚠️ لا يوجد token للمصادقة');
        throw Exception('Authentication required');
      }

      final response = await _dio.get<Map<String, dynamic>>(
        '$baseUrl/admin/settings',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      AppLogger.info('📊 رمز استجابة جلب الإعدادات: ${response.statusCode}');

      if (response.statusCode == 200 && response.data != null) {
        AppLogger.info('📄 إعدادات مستلمة: ${response.data}');
        return response.data!;
      } else {
        AppLogger.warning('⚠️ فشل في جلب الإعدادات، استخدام القيم الافتراضية');
        return {
          'show_prices_to_public': true,
          'show_stock_to_public': true,
          'store_name': 'SAMA Store',
          'currency_symbol': 'جنيه',
        };
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في جلب الإعدادات: $e');
      return {
        'show_prices_to_public': true,
        'show_stock_to_public': true,
        'store_name': 'SAMA Store',
        'currency_symbol': 'جنيه',
      };
    }
  }

  // Update app settings (admin only)
  Future<bool> updateSettings(Map<String, dynamic> settings) async {
    try {
      AppLogger.info('🔧 محاولة تحديث الإعدادات: $settings');

      final response = await _dio.post<Map<String, dynamic>>(
        '$baseUrl/admin/settings',
        data: settings,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      AppLogger.info('📊 رمز استجابة تحديث الإعدادات: ${response.statusCode}');
      AppLogger.info('📄 محتوى الاستجابة: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data;
        if (data != null && data['success'] == true) {
          AppLogger.info('✅ تم تحديث الإعدادات بنجاح');
          return true;
        } else {
          AppLogger.warning('⚠️ فشل في تحديث الإعدادات: ${data?['message'] ?? 'خطأ غير معروف'}');
          return false;
        }
      } else {
        AppLogger.error('❌ فشل في تحديث الإعدادات - رمز الخطأ: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في تحديث الإعدادات: $e');
      return false;
    }
  }



  // Get pending orders (admin only)
  Future<List<Map<String, dynamic>>> getPendingOrders() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$baseUrl/api/admin/pending-orders',
        options: Options(
          headers: {
            'X-API-KEY': 'lux2025FlutterAccess',
          },
        ),
      );

      if (response.data?['success'] == true) {
        final orders = response.data?['orders'] as List<dynamic>? ?? [];
        return orders.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      AppLogger.error('Error fetching pending orders', e);
      return [];
    }
  }

  // Approve order and add tracking link (admin only)
  Future<bool> approveOrderWithTracking({
    required String orderId,
    required String trackingUrl,
    required String trackingTitle,
    String? trackingDescription,
    required String adminName,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$baseUrl/api/admin/approve-order',
        data: {
          'order_id': orderId,
          'tracking_url': trackingUrl,
          'tracking_title': trackingTitle,
          'tracking_description': trackingDescription,
          'admin_name': adminName,
          'status': 'approved',
        },
        options: Options(
          headers: {
            'X-API-KEY': 'lux2025FlutterAccess',
          },
        ),
      );

      return response.data?['success'] == true;
    } catch (e) {
      AppLogger.error('Error approving order with tracking', e);
      return false;
    }
  }

  // Get client orders with tracking links
  Future<List<Map<String, dynamic>>> getClientOrdersWithTracking(String clientId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$baseUrl/api/client/orders-with-tracking',
        queryParameters: {'client_id': clientId},
        options: Options(
          headers: {
            'X-API-KEY': 'lux2025FlutterAccess',
          },
        ),
      );

      if (response.data?['success'] == true) {
        final orders = response.data?['orders'] as List<dynamic>? ?? [];
        return orders.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      AppLogger.error('Error fetching client orders with tracking', e);
      return [];
    }
  }

  // Add tracking link to existing order
  Future<bool> addTrackingLink({
    required String orderId,
    required String trackingUrl,
    required String trackingTitle,
    String? trackingDescription,
    required String adminName,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$baseUrl/api/admin/add-tracking',
        data: {
          'order_id': orderId,
          'tracking_url': trackingUrl,
          'tracking_title': trackingTitle,
          'tracking_description': trackingDescription,
          'admin_name': adminName,
        },
        options: Options(
          headers: {
            'X-API-KEY': 'lux2025FlutterAccess',
          },
        ),
      );

      return response.data?['success'] == true;
    } catch (e) {
      AppLogger.error('Error adding tracking link', e);
      return false;
    }
  }

  // Admin Methods for User Management

  // Get pending users (admin only)
  Future<List<FlaskUserModel>> getPendingUsers() async {
    try {
      if (_currentUser == null || !_currentUser!.isAdmin) {
        throw Exception('Unauthorized: Admin access required');
      }

      final response = await _dio.get<Map<String, dynamic>>(
        '$baseUrl/admin/users/pending',
      );

      if (response.data?['success'] == true) {
        final List<dynamic> usersData = response.data?['users'] ?? [];
        return usersData
            .map((userData) => FlaskUserModel.fromJson(userData))
            .toList();
      }

      return [];
    } catch (e) {
      AppLogger.error('Error getting pending users', e);
      return [];
    }
  }

  // Approve a user (admin only)
  Future<bool> approveUser(int userId) async {
    try {
      if (_currentUser == null || !_currentUser!.isAdmin) {
        throw Exception('Unauthorized: Admin access required');
      }

      final response = await _dio.post<Map<String, dynamic>>(
        '$baseUrl/admin/users/$userId/approve',
      );

      return response.data?['success'] == true;
    } catch (e) {
      AppLogger.error('Error approving user', e);
      return false;
    }
  }

  // Reject a user (admin only)
  Future<bool> rejectUser(int userId) async {
    try {
      if (_currentUser == null || !_currentUser!.isAdmin) {
        throw Exception('Unauthorized: Admin access required');
      }

      final response = await _dio.post<Map<String, dynamic>>(
        '$baseUrl/admin/users/$userId/reject',
      );

      return response.data?['success'] == true;
    } catch (e) {
      AppLogger.error('Error rejecting user', e);
      return false;
    }
  }

  // Methods for fetching products
  Future<List<FlaskProductModel>> getAllProducts() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$baseUrl/flutter/api/api/products',
        options: Options(
          headers: {
            'x-api-key': 'lux2025FlutterAccess',
          },
        ),
      );

      if (response.data?['success'] == true && response.data?['products'] != null) {
        final productsList = response.data!['products'] as List<dynamic>;

        // Debug print to check if purchase_price and selling_price are in the response
        if (productsList.isNotEmpty) {
          print('DEBUG: First product data: ${productsList.first}');
          print('DEBUG: purchase_price: ${productsList.first['purchase_price']}');
          print('DEBUG: selling_price: ${productsList.first['selling_price']}');
        }

        return productsList
            .map((json) => FlaskProductModel.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        AppLogger.warning('Failed to get products: ${response.data?['message'] ?? 'Unknown error'}');
        return [];
      }
    } catch (e) {
      AppLogger.error('Error fetching products', e);
      return [];
    }
  }
}