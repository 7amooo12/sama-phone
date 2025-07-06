import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smartbiztracker_new/models/product_return_model.dart';

class ProductReturnsService {
  final SupabaseClient _supabase = Supabase.instance.client;
  static const String _tableName = 'product_returns';

  // Get all product returns for admin
  Future<List<ProductReturn>> getAllProductReturns() async {
    try {
      print('🔍 ProductReturnsService: Fetching all product returns from table: $_tableName');

      // First, let's try a simple count to test table access
      try {
        final countResponse = await _supabase
            .from(_tableName)
            .select('id');
        print('📊 ProductReturnsService: Table access test - found ${countResponse.length} records');
      } catch (countError) {
        print('⚠️  ProductReturnsService: Count query failed: $countError');
      }

      final response = await _supabase
          .from(_tableName)
          .select('*')
          .order('created_at', ascending: false);

      print('📊 ProductReturnsService: Raw response type: ${response.runtimeType}');
      print('📊 ProductReturnsService: Raw response length: ${response?.length ?? 'null'}');

      if (response == null) {
        print('⚠️  ProductReturnsService: Response is null');
        return [];
      }

      final productReturns = (response as List<dynamic>? ?? [])
          .map((json) => ProductReturn.fromJson(json as Map<String, dynamic>))
          .toList();

      print('✅ ProductReturnsService: Successfully parsed ${productReturns.length} product returns');
      return productReturns;
    } catch (e) {
      print('❌ ProductReturnsService: Error fetching product returns: $e');
      print('❌ ProductReturnsService: Error type: ${e.runtimeType}');

      // Check if it's an RLS/permission error
      if (e.toString().contains('permission') || e.toString().contains('policy') || e.toString().contains('RLS')) {
        print('🔒 ProductReturnsService: This appears to be a Row Level Security (RLS) permission issue');
        print('🔒 Make sure the current user has admin role in user_profiles table');
      }

      throw Exception('Failed to fetch product returns: $e');
    }
  }

  // Get product returns by customer ID
  Future<List<ProductReturn>> getProductReturnsByCustomer(String customerId) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select('*')
          .eq('customer_id', customerId)
          .order('created_at', ascending: false);

      return (response as List<dynamic>? ?? [])
          .map((json) => ProductReturn.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch customer product returns: $e');
    }
  }

  // Get product returns by status
  Future<List<ProductReturn>> getProductReturnsByStatus(String status) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select('*')
          .eq('status', status)
          .order('created_at', ascending: false);

      return (response as List<dynamic>? ?? [])
          .map((json) => ProductReturn.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch product returns by status: $e');
    }
  }

  // Create a new product return request
  Future<ProductReturn> createProductReturn(ProductReturn productReturn) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .insert(productReturn.toJson())
          .select()
          .single();

      return ProductReturn.fromJson(response);
    } catch (e) {
      // Provide user-friendly Arabic error messages
      String errorMessage = 'فشل في إرسال طلب الإرجاع';

      if (e.toString().contains('uuid') || e.toString().contains('UUID')) {
        errorMessage = 'خطأ في معرف المستخدم - يرجى إعادة تسجيل الدخول';
      } else if (e.toString().contains('network') || e.toString().contains('connection')) {
        errorMessage = 'خطأ في الاتصال - تحقق من الإنترنت';
      } else if (e.toString().contains('JWT') || e.toString().contains('auth')) {
        errorMessage = 'انتهت صلاحية الجلسة - يرجى إعادة تسجيل الدخول';
      } else if (e.toString().contains('duplicate') || e.toString().contains('unique')) {
        errorMessage = 'تم إرسال طلب مماثل من قبل';
      }

      throw Exception(errorMessage);
    }
  }

  // Update product return status
  Future<void> updateProductReturnStatus(String returnId, String newStatus) async {
    try {
      await _supabase
          .from(_tableName)
          .update({
            'status': newStatus,
            'processed_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', returnId);
    } catch (e) {
      throw Exception('Failed to update product return status: $e');
    }
  }

  // Add admin response to product return
  Future<void> addAdminResponse(String returnId, String response) async {
    try {
      await _supabase
          .from(_tableName)
          .update({
            'admin_response': response,
            'admin_response_date': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', returnId);
    } catch (e) {
      throw Exception('Failed to add admin response: $e');
    }
  }

  // Add admin notes to product return
  Future<void> addAdminNotes(String returnId, String notes) async {
    try {
      await _supabase
          .from(_tableName)
          .update({
            'admin_notes': notes,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', returnId);
    } catch (e) {
      throw Exception('Failed to add admin notes: $e');
    }
  }

  // Update product return status and add admin response
  Future<void> updateProductReturnWithResponse(String returnId, String status, String response) async {
    try {
      await _supabase
          .from(_tableName)
          .update({
            'status': status,
            'admin_response': response,
            'admin_response_date': DateTime.now().toIso8601String(),
            'processed_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', returnId);
    } catch (e) {
      throw Exception('Failed to update product return with response: $e');
    }
  }

  // Set refund amount
  Future<void> setRefundAmount(String returnId, double amount) async {
    try {
      await _supabase
          .from(_tableName)
          .update({
            'refund_amount': amount,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', returnId);
    } catch (e) {
      throw Exception('Failed to set refund amount: $e');
    }
  }

  // Delete product return
  Future<void> deleteProductReturn(String returnId) async {
    try {
      await _supabase
          .from(_tableName)
          .delete()
          .eq('id', returnId);
    } catch (e) {
      throw Exception('Failed to delete product return: $e');
    }
  }

  // Get product return by ID
  Future<ProductReturn?> getProductReturnById(String returnId) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select('*')
          .eq('id', returnId)
          .maybeSingle();

      if (response == null) return null;
      return ProductReturn.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch product return: $e');
    }
  }

  // Get product returns count by status
  Future<Map<String, int>> getProductReturnsCountByStatus() async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select('status');

      final counts = <String, int>{};
      for (final item in response) {
        final status = item['status'] as String;
        counts[status] = (counts[status] ?? 0) + 1;
      }

      return counts;
    } catch (e) {
      throw Exception('Failed to get product returns count: $e');
    }
  }

  // Search product returns
  Future<List<ProductReturn>> searchProductReturns(String query) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select('*')
          .or('product_name.ilike.%$query%,reason.ilike.%$query%,customer_name.ilike.%$query%,order_number.ilike.%$query%')
          .order('created_at', ascending: false);

      return (response as List<dynamic>? ?? [])
          .map((json) => ProductReturn.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to search product returns: $e');
    }
  }

  // Get recent product returns (last 7 days)
  Future<List<ProductReturn>> getRecentProductReturns() async {
    try {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      
      final response = await _supabase
          .from(_tableName)
          .select('*')
          .filter('created_at', 'gte', sevenDaysAgo.toIso8601String())
          .order('created_at', ascending: false);

      return (response as List<dynamic>? ?? [])
          .map((json) => ProductReturn.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch recent product returns: $e');
    }
  }

  // Get pending product returns count
  Future<int> getPendingProductReturnsCount() async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select('id')
          .eq('status', 'pending');

      return response.length;
    } catch (e) {
      throw Exception('Failed to get pending product returns count: $e');
    }
  }

  // Get product returns by date range
  Future<List<ProductReturn>> getProductReturnsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      // Build query with correct pattern: from().select() first, then filters
      final response = await _supabase
          .from(_tableName)
          .select('*')
          .gte('created_at', startDate.toIso8601String())
          .lte('created_at', endDate.toIso8601String())
          .order('created_at', ascending: false);

      return (response as List<dynamic>? ?? [])
          .map((json) => ProductReturn.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch product returns by date range: $e');
    }
  }

  // Create test data for debugging (admin only)
  Future<bool> createTestProductReturn() async {
    try {
      print('🧪 ProductReturnsService: Creating test product return...');

      final testReturn = ProductReturn(
        id: '', // Will be generated by Supabase
        customerId: 'test-customer-id',
        customerName: 'عميل تجريبي',
        productName: 'منتج تجريبي للاختبار',
        orderNumber: 'TEST-001',
        reason: 'هذا طلب إرجاع تجريبي للاختبار',
        status: 'pending',
        phone: '01234567890',
        datePurchased: DateTime.now().subtract(const Duration(days: 30)),
        hasReceipt: true,
        termsAccepted: true,
        productImages: [],
        createdAt: DateTime.now(),
      );

      final response = await _supabase
          .from(_tableName)
          .insert(testReturn.toJson())
          .select()
          .single();

      print('✅ ProductReturnsService: Test product return created with ID: ${response['id']}');
      return true;
    } catch (e) {
      print('❌ ProductReturnsService: Failed to create test data: $e');
      return false;
    }
  }

  // Get total refund amount
  Future<double> getTotalRefundAmount() async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select('refund_amount')
          .not('refund_amount', 'is', null);

      double total = 0.0;
      for (final item in response) {
        final amount = item['refund_amount'];
        if (amount != null) {
          total += (amount as num).toDouble();
        }
      }

      return total;
    } catch (e) {
      throw Exception('Failed to get total refund amount: $e');
    }
  }
}
