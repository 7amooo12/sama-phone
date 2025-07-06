import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/task_model.dart';
import '../models/order_model.dart';
import '../utils/app_logger.dart';
import '../models/productivity_model.dart';
import '../models/return_model.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';
import '../models/notification_model.dart';
import '../models/product_model.dart';
import '../models/waste_model.dart' as waste_models;
import '../models/message_model.dart';
import '../models/fault_model.dart';

class DatabaseService {
  // Lazy initialization to avoid accessing Supabase.instance before initialization
  SupabaseClient get _supabase {
    try {
      return Supabase.instance.client;
    } catch (e) {
      AppLogger.error('❌ Supabase not initialized yet in DatabaseService: $e');
      throw Exception('Supabase must be initialized before using DatabaseService');
    }
  }

  // Collection references with lazy initialization
  get _usersCollection => _supabase.from('user_profiles');
  get _notificationsCollection => _supabase.from('notifications');
  get _productsCollection => _supabase.from('products');
  get _ordersCollection => _supabase.from('orders');
  get _tasksCollection => _supabase.from('tasks');
  get _messagesCollection => _supabase.from('messages');
  get _faultsCollection => _supabase.from('faults');
  get _productivityCollection => _supabase.from('productivity');
  get _wasteCollection => _supabase.from('waste');
  get _returnsCollection => _supabase.from('returns');

  // Users

  Future<UserModel?> getUser(String userId) async {
    try {
      // Use SECURITY DEFINER function to bypass RLS and avoid infinite recursion
      final response = await _supabase.rpc('get_user_by_id_safe', params: {
        'user_id': userId,
      });

      if (response != null && response.isNotEmpty) {
        final userData = response is List ? response.first : response;
        return UserModel.fromJson(userData);
      }
      return null;
    } catch (e) {
      AppLogger.error('Error getting user: $e');

      // Fallback to direct query if function doesn't exist
      if (e.toString().contains('function') && e.toString().contains('does not exist')) {
        try {
          final fallbackResponse = await _usersCollection
              .select()
              .eq('id', userId)
              .single();
          return fallbackResponse != null ? UserModel.fromJson(fallbackResponse) : null;
        } catch (fallbackError) {
          AppLogger.error('Fallback query also failed: $fallbackError');
          return null;
        }
      }

      return null;
    }
  }

  Future<bool> createUserProfile(UserModel user) async {
    try {
      await _usersCollection.insert(user.toJson());
      return true;
    } catch (e) {
      AppLogger.error('Error creating user profile: $e');
      return false;
    }
  }

  Future<bool> updateUserRoleAndStatus(String userId, String role, String status) async {
    try {
      // Use SECURITY DEFINER function to bypass RLS and avoid infinite recursion
      final updateData = {
        'role': role,
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase.rpc('update_user_profile_safe', params: {
        'user_id': userId,
        'update_data': updateData,
      });

      if (response != null && response.isNotEmpty) {
        return true;
      } else {
        AppLogger.warning('Update function returned empty result for user $userId');
        return false;
      }
    } catch (e) {
      AppLogger.error('Error updating user role and status: $e');

      // Fallback to direct query if function doesn't exist
      if (e.toString().contains('function') && e.toString().contains('does not exist')) {
        try {
          await _usersCollection
              .update({
                'role': role,
                'status': status,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', userId);
          return true;
        } catch (fallbackError) {
          AppLogger.error('Fallback update also failed: $fallbackError');
          return false;
        }
      }

      return false;
    }
  }

  Future<List<UserModel>> getUsers() async {
    try {
      final response = await _usersCollection
          .select()
          .order('created_at', ascending: false);

      return (response as List).map((json) => UserModel.fromJson(json)).toList();
    } catch (e) {
      AppLogger.error('Error getting users: $e');
      return [];
    }
  }

  Future<String?> createUser(UserModel user) async {
    try {
      final response = await _usersCollection
          .insert(user.toJson())
          .select()
          .single();
      return response['id'] as String;
    } catch (e) {
      AppLogger.error('Error creating user: $e');
      return null;
    }
  }

  Future<bool> updateUser(UserModel user) async {
    try {
      // Create update data with proper null handling
      final updateData = user.toJson();

      // Remove null values to prevent database errors
      updateData.removeWhere((key, value) => value == null);

      // Remove tracking_link if it exists (not in database schema)
      updateData.remove('tracking_link');

      AppLogger.info('Updating user ${user.id} with fields: ${updateData.keys.join(', ')}');

      // Use SECURITY DEFINER function to bypass RLS and avoid infinite recursion
      try {
        final response = await _supabase.rpc('update_user_profile_safe', params: {
          'user_id': user.id,
          'update_data': updateData,
        });

        if (response != null && response.isNotEmpty) {
          AppLogger.info('✅ Successfully updated user ${user.id}');
          return true;
        } else {
          AppLogger.warning('⚠️ Update function returned empty result for user ${user.id}');
          return false;
        }
      } catch (functionError) {
        // If function doesn't exist, fall back to direct query
        if (functionError.toString().contains('function') &&
            functionError.toString().contains('does not exist')) {
          AppLogger.warning('🔧 Database function missing - falling back to direct query');

          try {
            await _usersCollection
                .update(updateData)
                .eq('id', user.id);

            AppLogger.info('✅ Successfully updated user ${user.id} (fallback method)');
            return true;
          } catch (fallbackError) {
            AppLogger.error('❌ Fallback update also failed: $fallbackError');
            throw fallbackError;
          }
        } else {
          rethrow;
        }
      }
    } catch (e) {
      AppLogger.error('❌ Error updating user ${user.id}: $e');

      // Enhanced error diagnostics
      final errorString = e.toString();
      if (errorString.contains('infinite recursion') || errorString.contains('42P17')) {
        AppLogger.error('🔄 DIAGNOSIS: RLS infinite recursion detected');
        AppLogger.error('💡 SOLUTION: Run sql/fix_infinite_recursion_final.sql to fix RLS policies');
      } else if (errorString.contains('permission denied') || errorString.contains('42501')) {
        AppLogger.error('🔒 DIAGNOSIS: Permission denied - RLS policy issue');
        AppLogger.error('💡 SOLUTION: Run sql/fix_infinite_recursion_final.sql to fix RLS policies');
      } else if (errorString.contains('relation') && errorString.contains('does not exist')) {
        AppLogger.error('🗄️ DIAGNOSIS: Table does not exist');
        AppLogger.error('💡 SOLUTION: Verify user_profiles table exists in Supabase');
      }

      return false;
    }
  }

  Future<bool> deleteUser(String userId) async {
    try {
      await _usersCollection
          .delete()
          .eq('id', userId);
      return true;
    } catch (e) {
      AppLogger.error('Error deleting user: $e');
      return false;
    }
  }

  Future<List<UserModel>> getPendingUsers() async {
    try {
      final response = await _usersCollection
          .select()
          .eq('status', 'pending')
          .order('created_at');

      return response.map((json) => UserModel.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<UserModel>> getUsersByRole(String role) async {
    try {
      final response = await _usersCollection
          .select()
          .eq('role', role)
          .order('created_at');

      return response.map((json) => UserModel.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<UserModel>> getUsersByRoleEnum(UserRole role) async {
    try {
      final response = await _usersCollection
          .select()
          .eq('role', role.value)
          .order('created_at');

      return response.map((json) => UserModel.fromJson(json)).toList();
    } catch (e) {
      AppLogger.error('Error getting users by role: $e');
      return [];
    }
  }

  // Notifications

  Future<void> saveNotification(NotificationModel notification) async {
    try {
      await _notificationsCollection
          .insert(notification.toJson());
    } catch (e) {
      AppLogger.error('Error saving notification: $e');
      rethrow;
    }
  }

  Future<List<NotificationModel>> getNotifications(String userId) async {
    try {
      final response = await _notificationsCollection
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List).map((json) => NotificationModel.fromJson(json)).toList();
    } catch (e) {
      AppLogger.error('Error getting notifications: $e');
      return [];
    }
  }

  // Products

  Future<List<ProductModel>> getProducts() async {
    try {
      final response = await _productsCollection
          .select()
          .order('created_at', ascending: false);

      return (response as List).map((json) => ProductModel.fromJson(json)).toList();
    } catch (e) {
      AppLogger.error('Error getting products: $e');
      return [];
    }
  }

  Future<ProductModel?> getProductById(String productId) async {
    try {
      final response = await _productsCollection
          .select()
          .eq('id', productId)
          .single();

      return response != null ? ProductModel.fromJson(response) : null;
    } catch (e) {
      AppLogger.error('Error getting product by ID: $e');
      return null;
    }
  }

  Future<String?> createProduct(ProductModel product) async {
    try {
      final response = await _productsCollection
          .insert(product.toJson())
          .select()
          .single();
      return response['id'] as String;
    } catch (e) {
      AppLogger.error('Error creating product: $e');
      return null;
    }
  }

  Future<bool> updateProduct(ProductModel product) async {
    try {
      await _productsCollection
          .update(product.toJson())
          .eq('id', product.id);
      return true;
    } catch (e) {
      AppLogger.error('Error updating product: $e');
      return false;
    }
  }

  Stream<List<ProductModel>> getAllProducts() {
    try {
      return _productsCollection
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .map((data) => data.map((json) => ProductModel.fromJson(json)).toList());
    } catch (e) {
      AppLogger.error('Error getting all products stream: $e');
      return Stream.value([]);
    }
  }

  Stream<List<ProductModel>> getProductsByOwner(String ownerId) {
    try {
      return _productsCollection
          .stream(primaryKey: ['id'])
          .eq('owner_id', ownerId)
          .order('created_at', ascending: false)
          .map((data) => data.map((json) => ProductModel.fromJson(json)).toList());
    } catch (e) {
      AppLogger.error('Error getting products by owner stream: $e');
      return Stream.value([]);
    }
  }

  // Faults

  Future<void> saveFault(FaultModel fault) async {
    try {
      final response = await _faultsCollection
          .insert(fault.toJson())
          .select()
          .single();

      await _faultsCollection
          .update({'id': response['id']})
          .eq('id', response['id']);
    } catch (e) {
      AppLogger.error('Error saving fault: $e');
      rethrow;
    }
  }

  Future<List<FaultModel>> getFaults(String userId) async {
    try {
      final response = await _faultsCollection
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return response.map((json) => FaultModel.fromJson(json)).toList();
    } catch (e) {
      AppLogger.error('Error getting faults: $e');
      return [];
    }
  }

  Stream<List<FaultModel>> getAllFaults() {
    try {
      return _faultsCollection
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .map((data) => data.map((json) => FaultModel.fromJson(json)).toList());
    } catch (e) {
      AppLogger.error('Error getting all faults: $e');
      return Stream.value([]);
    }
  }

  Stream<List<FaultModel>> getWorkerFaults(String workerId) {
    try {
      return _faultsCollection
          .stream(primaryKey: ['id'])
          .eq('worker_id', workerId)
          .order('created_at', ascending: false)
          .map((data) => data.map((json) => FaultModel.fromJson(json)).toList());
    } catch (e) {
      AppLogger.error('Error getting worker faults: $e');
      return Stream.value([]);
    }
  }

  Future<void> addFault(FaultModel fault) async {
    try {
      await _faultsCollection.insert(fault.toMap());
    } catch (e) {
      AppLogger.error('Error adding fault: $e');
      rethrow;
    }
  }

  Future<void> deleteFault(String faultId) async {
    try {
      await _faultsCollection
          .delete()
          .eq('id', faultId);
    } catch (e) {
      AppLogger.error('Error deleting fault: $e');
      rethrow;
    }
  }

  Future<void> addFaultReport(FaultModel fault) async {
    try {
      await _faultsCollection.insert(fault.toMap());
    } catch (e) {
      AppLogger.error('Error adding fault report: $e');
      rethrow;
    }
  }

  Stream<List<FaultModel>> getAllFaultReports() {
    try {
      return _faultsCollection
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .map((data) => data.map((json) => FaultModel.fromJson(json)).toList());
    } catch (e) {
      AppLogger.error('Error getting all fault reports stream: $e');
      return Stream.value([]);
    }
  }

  Future<List<FaultModel>> getFaultReportsByUser(String userId) async {
    try {
      final response = await _faultsCollection
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return response.map((json) => FaultModel.fromJson(json)).toList();
    } catch (e) {
      AppLogger.error('Error getting fault reports by user: $e');
      return [];
    }
  }

  Future<void> updateFaultResolveStatus({
    required String faultId,
    required bool isResolved,
  }) async {
    try {
      await _faultsCollection
          .update({
            'is_resolved': isResolved,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', faultId);
      AppLogger.info('Updated fault $faultId resolve status to $isResolved');
    } catch (e) {
      AppLogger.error('Error updating fault resolve status: $e');
      throw Exception('Failed to update fault status');
    }
  }

  // Productivity

  Future<void> saveProductivity(ProductivityModel productivity) async {
    try {
      await _productivityCollection
          .insert(productivity.toJson());
    } catch (e) {
      AppLogger.error('Error saving productivity: $e');
      rethrow;
    }
  }

  Future<List<ProductivityModel>> getProductivity(String workerId) async {
    try {
      final response = await _productivityCollection
          .select()
          .eq('worker_id', workerId)
          .order('date', ascending: false);

      return response.map((json) => ProductivityModel.fromJson(json)).toList();
    } catch (e) {
      AppLogger.error('Error getting productivity: $e');
      return [];
    }
  }

  Stream<List<ProductivityModel>> getAllWorkersProductivity() {
    try {
      return _supabase
          .from('productivity')
          .stream(primaryKey: ['id'])
          .order('date', ascending: false)
          .map((data) => data
              .map((json) => ProductivityModel.fromJson(json))
              .toList());
    } catch (e) {
      AppLogger.error('Error getting all workers productivity: $e');
      return Stream.value([]);
    }
  }

  Stream<List<ProductivityModel>> getWorkerProductivity(String workerId) {
    try {
      return _supabase
          .from('productivity')
          .stream(primaryKey: ['id'])
          .eq('worker_id', workerId)
          .order('date', ascending: false)
          .map((data) => data
              .map((json) => ProductivityModel.fromJson(json))
              .toList());
    } catch (e) {
      AppLogger.error('Error getting worker productivity: $e');
      return Stream.value([]);
    }
  }

  Future<void> addProductivityRecord(ProductivityModel productivity) async {
    try {
      await _supabase
          .from('productivity')
          .insert(productivity.toJson());
    } catch (e) {
      AppLogger.error('Error adding productivity record: $e');
      rethrow;
    }
  }

  Future<void> updateProductivityRecord(ProductivityModel productivity) async {
    try {
      await _supabase
          .from('productivity')
          .update(productivity.toJson())
          .eq('id', productivity.id);
    } catch (e) {
      AppLogger.error('Error updating productivity record: $e');
      rethrow;
    }
  }

  Future<void> deleteProductivityRecord(String productivityId) async {
    try {
      await _supabase
          .from('productivity')
          .delete()
          .eq('id', productivityId);
    } catch (e) {
      AppLogger.error('Error deleting productivity record: $e');
      rethrow;
    }
  }

  // Removed duplicate productivity methods

  // Waste

  Future<void> createWaste(waste_models.WasteModel waste) async {
    try {
      await _supabase
          .from('waste')
          .insert(waste.toJson());
    } catch (e) {
      AppLogger.error('Error creating waste', e);
      throw Exception('Failed to create waste');
    }
  }

  Future<List<waste_models.WasteModel>> getWaste({
    String? workerId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // Build query with correct pattern: from().select() first, then filters
      var query = _supabase.from('waste').select();

      if (workerId != null) {
        query = query.eq('worker_id', workerId);
      }
      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }
      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      final response = await query;
      return (response as List)
          .map((json) => waste_models.WasteModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.error('Error getting waste', e);
      return [];
    }
  }

  Stream<List<waste_models.WasteModel>> getAllWasteReports() {
    try {
      return _supabase
          .from('waste')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .map((data) => data
              .map((json) => waste_models.WasteModel.fromJson(json))
              .toList());
    } catch (e) {
      AppLogger.error('Error getting all waste reports: $e');
      return Stream.value([]);
    }
  }

  Future<void> addWasteReport(
      {required String workerId,
      required String workerName,
      required String itemName,
      required int quantity,
      required String details}) async {
    final waste = waste_models.WasteModel(
      id: '', // ID will be updated after document creation
      productId: '', // Can be updated if needed
      userId: '', // Can be updated if needed
      workerId: workerId,
      workerName: workerName,
      itemName: itemName,
      description: details,
      details: details,
      quantity: quantity.toDouble(),
      unit: 'pieces', // Default unit
      type: 'waste', // Default type
      status: 'pending', // Default status
      date: DateTime.now(),
      createdAt: DateTime.now(),
    );

    await _supabase
        .from('waste')
        .insert(waste.toJson());
  }

  Future<void> updateWasteReport(waste_models.WasteModel waste) async {
    try {
      await _supabase
          .from('waste')
          .update(waste.toJson())
          .eq('id', waste.id);
    } catch (e) {
      AppLogger.error('Error updating waste report: $e');
      rethrow;
    }
  }

  Future<void> deleteWasteReport(String wasteId) async {
    try {
      await _supabase
          .from('waste')
          .delete()
          .eq('id', wasteId);
    } catch (e) {
      AppLogger.error('Error deleting waste report: $e');
      rethrow;
    }
  }

  // Returns

  Future<void> createReturn(ReturnModel returnModel) async {
    try {
      await _supabase
          .from('returns')
          .insert(returnModel.toMap());
    } catch (e) {
      AppLogger.error('Error creating return', e);
      throw Exception('Failed to create return');
    }
  }

  Future<void> updateReturn(ReturnModel returnModel) async {
    try {
      await _supabase
          .from('returns')
          .update(returnModel.toMap())
          .eq('id', returnModel.id);
    } catch (e) {
      AppLogger.error('Error updating return', e);
      throw Exception('Failed to update return');
    }
  }

  Future<List<ReturnModel>> getReturns({String? status}) async {
    try {
      var query = _supabase.from('returns').select();
      if (status != null) {
        query = query.eq('status', status);
      }
      final response = await query;
      return (response as List)
          .map((json) => ReturnModel.fromMap(json))
          .toList();
    } catch (e) {
      AppLogger.error('Error getting returns', e);
      return [];
    }
  }

  Future<void> addReturnReport(ReturnModel returnReport) async {
    try {
      await _supabase
          .from('returns')
          .insert(returnReport.toMap());
    } catch (e) {
      AppLogger.error('Error adding return report: $e');
      rethrow;
    }
  }

  Stream<List<ReturnModel>> getAllReturnReports() {
    try {
      return _supabase
          .from('returns')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .map((data) => data
              .map((json) => ReturnModel.fromMap(json))
              .toList());
    } catch (e) {
      AppLogger.error('Error getting all return reports: $e');
      return Stream.value([]);
    }
  }

  Future<List<ReturnModel>> getReturnReportsByUser(String userId) async {
    try {
      final response = await _supabase
          .from('returns')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => ReturnModel.fromMap(json))
          .toList();
    } catch (e) {
      AppLogger.error('Error getting return reports by user: $e');
      return [];
    }
  }

  // Return methods

  Future<void> updateReturnProcessStatus(
      String returnId, bool isProcessed) async {
    try {
      await _returnsCollection.update({
        'is_processed': isProcessed,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', returnId);
    } catch (e) {
      AppLogger.error('Error updating return process status', e);
      throw Exception('Failed to update return process status');
    }
  }

  // Generic methods

  Future<T?> getDocument<T>(String collection, String id,
      T Function(Map<String, dynamic>) fromMap) async {
    try {
      final response = await _supabase
          .from(collection)
          .select()
          .eq('id', id)
          .single();
      return fromMap(response);
          return null;
    } catch (e) {
      AppLogger.error('Error getting document', e);
      return null;
    }
  }

  Future<List<T>> getCollection<T>(
    String collection,
    T Function(Map<String, dynamic>) fromMap, {
    Function(PostgrestFilterBuilder)? queryBuilder,
  }) async {
    try {
      var query = _supabase.from(collection).select();
      if (queryBuilder != null) {
        query = queryBuilder(query);
      }
      final response = await query;
      return (response as List)
          .map((data) => fromMap(data))
          .toList();
    } catch (e) {
      AppLogger.error('Error getting collection', e);
      return [];
    }
  }

  Future<void> deleteDocument(String collection, String id) async {
    try {
      await _supabase.from(collection).delete().eq('id', id);
    } catch (e) {
      AppLogger.error('Error deleting document', e);
      throw Exception('Failed to delete document');
    }
  }

  // Messages

  Future<String> addMessage(MessageModel message) async {
    try {
      final response = await _messagesCollection
          .insert(message.toJson())
          .select()
          .single();
      return response['id'];
    } catch (e) {
      AppLogger.error('Error adding message: $e');
      rethrow;
    }
  }

  Future<List<MessageModel>> getMessagesBetweenUsers(String userId1, String userId2) async {
    try {
      final response = await _messagesCollection
          .select()
          .or('and(sender_id.eq.$userId1,receiver_id.eq.$userId2),and(sender_id.eq.$userId2,receiver_id.eq.$userId1)')
          .order('created_at');

      return (response as List)
          .map((json) => MessageModel.fromJson(json))
          .toList();
    } catch (e) {
      AppLogger.error('Error getting messages: $e');
      return [];
    }
  }

  Future<void> markMessageAsRead(String messageId) async {
    try {
      await _messagesCollection
          .update({'is_read': true})
          .eq('id', messageId);
    } catch (e) {
      rethrow;
    }
  }

  // Orders

  Future<List<OrderModel>> getAllOrders() async {
    try {
      final response = await _ordersCollection
          .select()
          .order('created_at', ascending: false);

      return (response as List).map((json) => OrderModel.fromJson(json)).toList();
    } catch (e) {
      AppLogger.error('Error getting all orders: $e');
      return [];
    }
  }

  Future<List<OrderModel>> getOrdersByClient(String clientId) async {
    try {
      final response = await _ordersCollection
          .select()
          .eq('client_id', clientId)
          .order('created_at', ascending: false);

      return (response as List).map((json) => OrderModel.fromJson(json)).toList();
    } catch (e) {
      AppLogger.error('Error getting client orders: $e');
      return [];
    }
  }

  Future<List<OrderModel>> getOrdersByWorker(String workerId) async {
    try {
      final response = await _ordersCollection
          .select()
          .eq('worker_id', workerId)
          .order('created_at', ascending: false);

      return (response as List).map((json) => OrderModel.fromJson(json)).toList();
    } catch (e) {
      AppLogger.error('Error getting worker orders: $e');
      return [];
    }
  }

  Future<List<OrderModel>> getUnassignedOrders() async {
    try {
      final response = await _ordersCollection
          .select()
          .isFilter('worker_id', null)
          .order('created_at', ascending: false);

      return (response as List).map((json) => OrderModel.fromJson(json)).toList();
    } catch (e) {
      AppLogger.error('Error getting unassigned orders: $e');
      return [];
    }
  }

  Future<String> addOrder(OrderModel order) async {
    try {
      final response = await _ordersCollection
          .insert(order.toJson())
          .select();
      return response[0]['id'] as String;
    } catch (e) {
      AppLogger.error('Error adding order: $e');
      rethrow;
    }
  }

  Future<void> updateOrder(OrderModel order) async {
    try {
      await _ordersCollection
          .update(order.toJson())
          .eq('id', order.id);
    } catch (e) {
      AppLogger.error('Error updating order: $e');
      rethrow;
    }
  }

  Future<void> deleteOrder(String orderId) async {
    try {
      await _ordersCollection
          .delete()
          .eq('id', orderId);
    } catch (e) {
      AppLogger.error('Error deleting order: $e');
      rethrow;
    }
  }

  Future<void> assignWorkerToOrder(String orderId, String workerId) async {
    try {
      await _ordersCollection
          .update({'worker_id': workerId})
          .eq('id', orderId);
    } catch (e) {
      AppLogger.error('Error assigning worker to order: $e');
      rethrow;
    }
  }

  Future<bool> updateOrderStatus(String orderId, String status) async {
    try {
      await _ordersCollection
          .update({'status': status})
          .eq('id', orderId);
      return true;
    } catch (e) {
      AppLogger.error('Error updating order status: $e');
      return false;
    }
  }

  Future<void> updateTrackingNumber(String orderId, String trackingNumber) async {
    try {
      await _ordersCollection
          .update({'tracking_number': trackingNumber})
          .eq('id', orderId);
    } catch (e) {
      AppLogger.error('Error updating tracking number: $e');
      rethrow;
    }
  }

  // Tasks

  Future<List<TaskModel>> getTasks(String userId) async {
    try {
      final response = await _tasksCollection
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List).map((json) => TaskModel.fromJson(json)).toList();
    } catch (e) {
      AppLogger.error('Error getting tasks: $e');
      return [];
    }
  }

  Future<void> saveTask(TaskModel task) async {
    try {
      await _tasksCollection
          .update(task.toJson())
          .eq('id', task.id);
        } catch (e) {
      AppLogger.error('Error saving task: $e');
      rethrow;
    }
  }

  Future<TaskModel?> getTaskById(String taskId) async {
    try {
      final response = await _tasksCollection
          .select()
          .eq('id', taskId)
          .single();

      return response != null ? TaskModel.fromJson(response) : null;
    } catch (e) {
      AppLogger.error('Error getting task: $e');
      return null;
    }
  }

  Future<String?> createTask(TaskModel task) async {
    try {
      final response = await _tasksCollection
          .insert(task.toJson())
          .select()
          .single();
      return response['id'] as String;
    } catch (e) {
      AppLogger.error('Error creating task: $e');
      return null;
    }
  }

  Future<bool> updateTask(TaskModel task) async {
    try {
      await _tasksCollection
          .update(task.toJson())
          .eq('id', task.id);
      return true;
    } catch (e) {
      AppLogger.error('Error updating task: $e');
      return false;
    }
  }

  Future<bool> deleteTask(String taskId) async {
    try {
      await _tasksCollection
          .delete()
          .eq('id', taskId);
      return true;
    } catch (e) {
      AppLogger.error('Error deleting task: $e');
      return false;
    }
  }

  Stream<List<TaskModel>> getWorkerTasks(String workerId) {
    return _tasksCollection
        .stream(primaryKey: ['id'])
        .eq('worker_id', workerId)
        .order('created_at')
        .map((data) => data.map((json) => TaskModel.fromJson(json)).toList());
  }

  Stream<List<OrderModel>> getOrders() {
    return _ordersCollection
        .stream(primaryKey: ['id'])
        .order('created_at')
        .map((data) => data.map((json) => OrderModel.fromJson(json)).toList());
  }

  // Other methods

  Future<void> processChatMessages(String userId, String adminId) async {
    try {
      // Implementation...
    } catch (e) {
      AppLogger.error('Error processing chat messages', e);
      throw Exception('Failed to process chat messages');
    }
  }

  Future<void> processOrderPayment(String orderId) async {
    try {
      // Implementation...
    } catch (e) {
      AppLogger.error('Error processing order payment', e);
      throw Exception('Failed to process order payment');
    }
  }

  Future<void> updateInventoryStatus(String productId, int quantity) async {
    try {
      // Implementation...
    } catch (e) {
      AppLogger.error('Error updating inventory status', e);
      throw Exception('Failed to update inventory status');
    }
  }

  Future<void> archiveOldData(DateTime cutoffDate) async {
    try {
      // Implementation...
    } catch (e) {
      AppLogger.error('Error archiving old data', e);
      throw Exception('Failed to archive old data');
    }
  }

  Future<void> optimizeDatabase() async {
    try {
      // Implementation...
    } catch (e) {
      AppLogger.error('Error optimizing database', e);
      throw Exception('Failed to optimize database');
    }
  }

  Future<void> backupUserData(String userId) async {
    try {
      // Implementation...
    } catch (e) {
      AppLogger.error('Error backing up user data', e);
      throw Exception('Failed to backup user data');
    }
  }

  Future<void> restoreUserData(String userId, Map<String, dynamic> data) async {
    try {
      // Implementation...
    } catch (e) {
      AppLogger.error('Error restoring user data', e);
      throw Exception('Failed to restore user data');
    }
  }

  Future<void> migrateData(String collection, String field, dynamic oldValue,
      dynamic newValue) async {
    try {
      // Implementation...
    } catch (e) {
      AppLogger.error('Error migrating data', e);
      throw Exception('Failed to migrate data');
    }
  }

  Stream<List<TaskModel>> getAllTasks() {
    try {
      return _tasksCollection
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .map((data) => data
              .map((json) => TaskModel.fromJson(json))
              .toList());
    } catch (e) {
      AppLogger.error('Error getting all tasks: $e');
      return Stream.value([]);
    }
  }

}
