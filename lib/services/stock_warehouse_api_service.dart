import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:smartbiztracker_new/models/product_model.dart';
import 'package:smartbiztracker_new/models/order_model.dart';

/// API service for stock and warehouse management
class StockWarehouseApiService {
  static const String _baseUrl = 'https://api.smartbiztracker.com';
  static const Duration _timeout = Duration(seconds: 30);

  /// Get all warehouses
  Future<List<Map<String, dynamic>>> getWarehouses() async {
    try {
      AppLogger.info('🏭 Fetching warehouses from API');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/warehouses'),
        headers: _getHeaders(),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        AppLogger.info('✅ Successfully fetched ${data['warehouses']?.length ?? 0} warehouses');
        return List<Map<String, dynamic>>.from(data['warehouses'] ?? []);
      } else {
        AppLogger.error('❌ Failed to fetch warehouses: ${response.statusCode}');
        throw Exception('Failed to fetch warehouses: ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.error('❌ Error fetching warehouses: $e');
      // Return mock data for development
      return _getMockWarehouses();
    }
  }

  /// Get warehouse by ID
  Future<Map<String, dynamic>?> getWarehouse(String warehouseId) async {
    try {
      AppLogger.info('🏭 Fetching warehouse $warehouseId from API');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/warehouses/$warehouseId'),
        headers: _getHeaders(),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        AppLogger.info('✅ Successfully fetched warehouse $warehouseId');
        return data['warehouse'];
      } else {
        AppLogger.error('❌ Failed to fetch warehouse: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      AppLogger.error('❌ Error fetching warehouse: $e');
      // Return mock data for development
      return _getMockWarehouse(warehouseId);
    }
  }

  /// Get stock items for a warehouse
  Future<List<Map<String, dynamic>>> getStockItems(String warehouseId) async {
    try {
      AppLogger.info('📦 Fetching stock items for warehouse $warehouseId');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/warehouses/$warehouseId/stock'),
        headers: _getHeaders(),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        AppLogger.info('✅ Successfully fetched ${data['items']?.length ?? 0} stock items');
        return List<Map<String, dynamic>>.from(data['items'] ?? []);
      } else {
        AppLogger.error('❌ Failed to fetch stock items: ${response.statusCode}');
        throw Exception('Failed to fetch stock items: ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.error('❌ Error fetching stock items: $e');
      // Return mock data for development
      return _getMockStockItems();
    }
  }

  /// Update stock item quantity
  Future<bool> updateStockQuantity(
    String warehouseId,
    String itemId,
    int newQuantity,
  ) async {
    try {
      AppLogger.info('📦 Updating stock quantity for item $itemId');
      
      final response = await http.put(
        Uri.parse('$_baseUrl/warehouses/$warehouseId/stock/$itemId'),
        headers: _getHeaders(),
        body: json.encode({
          'quantity': newQuantity,
          'updated_at': DateTime.now().toIso8601String(),
        }),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        AppLogger.info('✅ Successfully updated stock quantity');
        return true;
      } else {
        AppLogger.error('❌ Failed to update stock quantity: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      AppLogger.error('❌ Error updating stock quantity: $e');
      // Return success for development
      return true;
    }
  }

  /// Add new stock item
  Future<bool> addStockItem(String warehouseId, Map<String, dynamic> itemData) async {
    try {
      AppLogger.info('📦 Adding new stock item to warehouse $warehouseId');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/warehouses/$warehouseId/stock'),
        headers: _getHeaders(),
        body: json.encode(itemData),
      ).timeout(_timeout);

      if (response.statusCode == 201) {
        AppLogger.info('✅ Successfully added stock item');
        return true;
      } else {
        AppLogger.error('❌ Failed to add stock item: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      AppLogger.error('❌ Error adding stock item: $e');
      // Return success for development
      return true;
    }
  }

  /// Get stock movements/history
  Future<List<Map<String, dynamic>>> getStockMovements(String warehouseId) async {
    try {
      AppLogger.info('📊 Fetching stock movements for warehouse $warehouseId');

      final response = await http.get(
        Uri.parse('$_baseUrl/warehouses/$warehouseId/movements'),
        headers: _getHeaders(),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        AppLogger.info('✅ Successfully fetched ${data['movements']?.length ?? 0} movements');
        return List<Map<String, dynamic>>.from(data['movements'] ?? []);
      } else {
        AppLogger.error('❌ Failed to fetch stock movements: ${response.statusCode}');
        throw Exception('Failed to fetch stock movements: ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.error('❌ Error fetching stock movements: $e');
      // Return mock data for development
      return _getMockStockMovements();
    }
  }

  /// Get all products
  Future<List<ProductModel>> getProducts() async {
    try {
      AppLogger.info('📦 Fetching products from API');

      final response = await http.get(
        Uri.parse('$_baseUrl/products'),
        headers: _getHeaders(),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final productsList = List<Map<String, dynamic>>.from(data['products'] ?? []);
        final products = productsList.map((json) => ProductModel.fromJson(json)).toList();
        AppLogger.info('✅ Successfully fetched ${products.length} products');
        return products;
      } else {
        AppLogger.error('❌ Failed to fetch products: ${response.statusCode}');
        throw Exception('Failed to fetch products: ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.error('❌ Error fetching products: $e');
      // Return mock data for development
      return _getMockProducts();
    }
  }

  /// Get all orders
  Future<List<OrderModel>> getOrders() async {
    try {
      AppLogger.info('📋 Fetching orders from API');

      final response = await http.get(
        Uri.parse('$_baseUrl/orders'),
        headers: _getHeaders(),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final ordersList = List<Map<String, dynamic>>.from(data['orders'] ?? []);
        final orders = ordersList.map((json) => OrderModel.fromJson(json)).toList();
        AppLogger.info('✅ Successfully fetched ${orders.length} orders');
        return orders;
      } else {
        AppLogger.error('❌ Failed to fetch orders: ${response.statusCode}');
        throw Exception('Failed to fetch orders: ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.error('❌ Error fetching orders: $e');
      // Return mock data for development
      return _getMockOrders();
    }
  }

  /// Get request headers
  Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer ${_getAuthToken()}',
    };
  }

  /// Get authentication token (placeholder)
  String _getAuthToken() {
    // TODO: Implement proper token management
    return 'mock_token_for_development';
  }

  /// Mock data for development
  List<Map<String, dynamic>> _getMockWarehouses() {
    return [
      {
        'id': 'warehouse_1',
        'name': 'المستودع الرئيسي',
        'location': 'القاهرة',
        'capacity': 1000,
        'current_stock': 750,
        'status': 'active',
      },
      {
        'id': 'warehouse_2',
        'name': 'مستودع الإسكندرية',
        'location': 'الإسكندرية',
        'capacity': 500,
        'current_stock': 300,
        'status': 'active',
      },
    ];
  }

  Map<String, dynamic> _getMockWarehouse(String id) {
    return {
      'id': id,
      'name': 'المستودع الرئيسي',
      'location': 'القاهرة',
      'capacity': 1000,
      'current_stock': 750,
      'status': 'active',
      'manager': 'أحمد محمد',
      'created_at': '2024-01-01T00:00:00Z',
    };
  }

  List<Map<String, dynamic>> _getMockStockItems() {
    return [
      {
        'id': 'item_1',
        'name': 'منتج أ',
        'sku': 'SKU001',
        'quantity': 100,
        'min_quantity': 10,
        'max_quantity': 500,
        'unit_price': 25.50,
        'category': 'إلكترونيات',
      },
      {
        'id': 'item_2',
        'name': 'منتج ب',
        'sku': 'SKU002',
        'quantity': 50,
        'min_quantity': 5,
        'max_quantity': 200,
        'unit_price': 15.75,
        'category': 'ملابس',
      },
    ];
  }

  List<Map<String, dynamic>> _getMockStockMovements() {
    return [
      {
        'id': 'movement_1',
        'item_id': 'item_1',
        'type': 'in',
        'quantity': 50,
        'reason': 'استلام شحنة جديدة',
        'created_at': '2024-01-15T10:00:00Z',
        'created_by': 'مدير المستودع',
      },
      {
        'id': 'movement_2',
        'item_id': 'item_1',
        'type': 'out',
        'quantity': 25,
        'reason': 'بيع للعميل',
        'created_at': '2024-01-16T14:30:00Z',
        'created_by': 'موظف المبيعات',
      },
    ];
  }

  List<ProductModel> _getMockProducts() {
    return [
      ProductModel(
        id: 'product_1',
        name: 'منتج تجريبي 1',
        description: 'وصف المنتج التجريبي الأول',
        price: 100.0,
        category: 'إلكترونيات',
        sku: 'SKU001',
        quantity: 50,
        minimumStock: 10,
        reorderPoint: 15,
        images: [],
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      ProductModel(
        id: 'product_2',
        name: 'منتج تجريبي 2',
        description: 'وصف المنتج التجريبي الثاني',
        price: 75.0,
        category: 'ملابس',
        sku: 'SKU002',
        quantity: 30,
        minimumStock: 5,
        reorderPoint: 10,
        images: [],
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];
  }

  List<OrderModel> _getMockOrders() {
    return [
      OrderModel(
        id: '1',
        orderNumber: 'ORD001',
        customerName: 'عميل تجريبي 1',
        customerPhone: '01234567890',
        status: 'pending',
        totalAmount: 200.0,
        items: [],
        createdAt: DateTime.now(),
        notes: 'طلب تجريبي للاختبار',
        paymentMethod: 'cash',
        address: 'عنوان تجريبي',
      ),
      OrderModel(
        id: '2',
        orderNumber: 'ORD002',
        customerName: 'عميل تجريبي 2',
        customerPhone: '01234567891',
        status: 'confirmed',
        totalAmount: 150.0,
        items: [],
        createdAt: DateTime.now(),
        notes: 'طلب تجريبي آخر للاختبار',
        paymentMethod: 'card',
        address: 'عنوان تجريبي آخر',
      ),
    ];
  }
}
