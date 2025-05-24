import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/task_model.dart';
import '../models/order_model.dart';
import '../utils/app_logger.dart';
import '../models/productivity_model.dart';
import '../models/return_model.dart';
import '../config/constants.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';
import '../models/notification_model.dart';
import '../models/product_model.dart';
import '../models/waste_model.dart' as waste_models;
import '../models/message_model.dart';
import '../constants/app_constants.dart';
import '../models/fault_model.dart';

class DatabaseService {
  final _supabase = Supabase.instance.client;

  // Collection references
  SupabaseQueryBuilder get _usersCollection => _supabase.from('users');
  SupabaseQueryBuilder get _notificationsCollection => _supabase.from('notifications');
  SupabaseQueryBuilder get _productsCollection => _supabase.from('products');
  SupabaseQueryBuilder get _ordersCollection => _supabase.from('orders');
  SupabaseQueryBuilder get _tasksCollection => _supabase.from('tasks');
  SupabaseQueryBuilder get _messagesCollection => _supabase.from('messages');
  SupabaseQueryBuilder get _faultsCollection => _supabase.from('faults');
  SupabaseQueryBuilder get _productivityCollection => _supabase.from('productivity');
  SupabaseQueryBuilder get _wasteCollection => _supabase.from('waste');
  SupabaseQueryBuilder get _returnsCollection => _supabase.from('returns');

  // Users

  Future<UserModel?> getUser(String userId) async {
    try {
      final response = await _usersCollection
          .select()
          .eq('id', userId)
          .single();
      return response != null ? UserModel.fromJson(response) : null;
    } catch (e) {
      AppLogger.error('Error getting user: $e');
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
      await _usersCollection
          .update({
            'role': role,
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);
      return true;
    } catch (e) {
      AppLogger.error('Error updating user role and status: $e');
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
      await _usersCollection
          .update(user.toJson())
          .eq('id', user.id);
      return true;
    } catch (e) {
      AppLogger.error('Error updating user: $e');
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
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: role.value)
          .get();

      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting users by role: $e');
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
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return ProductModel.fromJson(data);
        }).toList();
      });
    } catch (e) {
      rethrow;
    }
  }

  Stream<List<ProductModel>> getProductsByOwner(String ownerId) {
    try {
      return _productsCollection
          .where('ownerId', isEqualTo: ownerId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return ProductModel.fromJson(data);
        }).toList();
      });
    } catch (e) {
      rethrow;
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
    await _supabase
        .from(AppConstants.faultsCollection)
        .add(fault.toMap());
  }

  Future<void> deleteFault(String faultId) async {
    await _supabase
        .from(AppConstants.faultsCollection)
        .doc(faultId)
        .delete();
  }

  Future<void> addFaultReport(FaultModel fault) async {
    try {
      final docRef = await _supabase.from('faults').add(fault.toMap());
      await _supabase.from('faults').doc(docRef.id).update({'id': docRef.id});
    } catch (e) {
      rethrow;
    }
  }

  Stream<List<FaultModel>> getAllFaultReports() {
    return _supabase
        .from('faults')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return FaultModel.fromJson(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList();
    });
  }

  Future<List<FaultModel>> getFaultReportsByUser(String userId) async {
    try {
      final querySnapshot = await _supabase
          .from('faults')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => FaultModel.fromJson(
                doc.data() as Map<String, dynamic>,
                doc.id,
              ))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateFaultResolveStatus({
    required String faultId,
    required bool isResolved,
  }) async {
    try {
      await _supabase.from('faults').doc(faultId).update({
        'isResolved': isResolved,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      AppLogger.info('Updated fault $faultId resolve status to $isResolved');
    } catch (e) {
      AppLogger.error('Error updating fault resolve status', e);
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
    return _productivityCollection
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ProductivityModel.fromMap({
          'id': doc.id,
          ...doc.data(),
        });
      }).toList();
    });
  }

  Stream<List<ProductivityModel>> getWorkerProductivity(String workerId) {
    return _productivityCollection
        .where('workerId', isEqualTo: workerId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ProductivityModel.fromMap({
          'id': doc.id,
          ...doc.data(),
        });
      }).toList();
    });
  }

  Future<void> addProductivityRecord(ProductivityModel productivity) async {
    await _productivityCollection
        .add(productivity.toMap());
  }

  Future<void> updateProductivityRecord(ProductivityModel productivity) async {
    await _productivityCollection
        .doc(productivity.id)
        .update(productivity.toMap());
  }

  Future<void> deleteProductivityRecord(String productivityId) async {
    await _productivityCollection
        .doc(productivityId)
        .delete();
  }

  Future<void> addWorkerProductivity(ProductivityModel productivity) async {
    try {
      final CollectionReference productivityCollection =
          _supabase.from(AppConstants.productivityCollection);
      final docRef = await productivityCollection.add(productivity.toMap());
      await productivityCollection.doc(docRef.id).update({'id': docRef.id});
    } catch (e) {
      rethrow;
    }
  }

  Stream<List<ProductivityModel>> getAllProductivityReports() {
    final CollectionReference productivityCollection =
        _supabase.from(AppConstants.productivityCollection);
    return productivityCollection
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ProductivityModel.fromJson(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList();
    });
  }

  Future<List<ProductivityModel>> getProductivityReportsByWorker(
      String workerId) async {
    try {
      final CollectionReference productivityCollection =
          _supabase.from(AppConstants.productivityCollection);
      final querySnapshot = await productivityCollection
          .where('workerId', isEqualTo: workerId)
          .orderBy('date', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => ProductivityModel.fromJson(
                doc.data() as Map<String, dynamic>,
                doc.id,
              ))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  // Waste

  Future<void> createWaste(waste_models.WasteModel waste) async {
    try {
      await _wasteCollection.doc(waste.id).set(waste.toMap());
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
      Query query = _wasteCollection;
      if (workerId != null) {
        query = query.where('workerId', isEqualTo: workerId);
      }
      if (startDate != null) {
        query = query.where('createdAt', isGreaterThanOrEqualTo: startDate);
      }
      if (endDate != null) {
        query = query.where('createdAt', isLessThanOrEqualTo: endDate);
      }
      final QuerySnapshot snapshot = await query.get();
      return snapshot.docs
          .map((doc) => waste_models.WasteModel.fromMap(
              doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.error('Error getting waste', e);
      return [];
    }
  }

  Stream<List<waste_models.WasteModel>> getAllWasteReports() {
    return _wasteCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return waste_models.WasteModel.fromMap({
          'id': doc.id,
          ...doc.data(),
        });
      }).toList();
    });
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

    final docRef = await _wasteCollection
        .add(waste.toJson());
    await _wasteCollection
        .doc(docRef.id)
        .update({'id': docRef.id});
  }

  Future<void> updateWasteReport(waste_models.WasteModel waste) async {
    await _wasteCollection
        .doc(waste.id)
        .update(waste.toMap());
  }

  Future<void> deleteWasteReport(String wasteId) async {
    await _wasteCollection
        .doc(wasteId)
        .delete();
  }

  // Returns

  Future<void> createReturn(ReturnModel returnModel) async {
    try {
      await _returnsCollection
          .doc(returnModel.id)
          .set(returnModel.toMap());
    } catch (e) {
      AppLogger.error('Error creating return', e);
      throw Exception('Failed to create return');
    }
  }

  Future<void> updateReturn(ReturnModel returnModel) async {
    try {
      await _returnsCollection
          .doc(returnModel.id)
          .update(returnModel.toMap());
    } catch (e) {
      AppLogger.error('Error updating return', e);
      throw Exception('Failed to update return');
    }
  }

  Future<List<ReturnModel>> getReturns({String? status}) async {
    try {
      Query query = _returnsCollection;
      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }
      final QuerySnapshot snapshot = await query.get();
      return snapshot.docs
          .map((doc) => ReturnModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.error('Error getting returns', e);
      return [];
    }
  }

  Future<void> addReturnReport(ReturnModel returnReport) async {
    try {
      final CollectionReference returnsCollection =
          _returnsCollection;
      final docRef = await returnsCollection.add(returnReport.toMap());
      await returnsCollection.doc(docRef.id).update({'id': docRef.id});
    } catch (e) {
      rethrow;
    }
  }

  Stream<List<ReturnModel>> getAllReturnReports() {
    final CollectionReference returnsCollection =
        _returnsCollection;
    return returnsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ReturnModel.fromJson(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList();
    });
  }

  Future<List<ReturnModel>> getReturnReportsByUser(String userId) async {
    try {
      final CollectionReference returnsCollection =
          _returnsCollection;
      final querySnapshot = await returnsCollection
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => ReturnModel.fromJson(
                doc.data() as Map<String, dynamic>,
                doc.id,
              ))
          .toList();
    } catch (e) {
      rethrow;
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
      if (response != null) {
        return fromMap(response);
      }
      return null;
    } catch (e) {
      AppLogger.error('Error getting document', e);
      return null;
    }
  }

  Future<List<T>> getCollection<T>(
    String collection,
    T Function(Map<String, dynamic>) fromMap, {
    Function(SupabaseQueryBuilder)? queryBuilder,
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

  Stream<List<MessageModel>> getMessagesBetweenUsers(String userId1, String userId2) {
    try {
      return _messagesCollection
          .stream(primaryKey: ['id'])
          .eq('sender_id', userId1)
          .eq('receiver_id', userId2)
          .order('created_at')
          .map((data) => data
              .map((json) => MessageModel.fromJson(json))
              .toList());
    } catch (e) {
      AppLogger.error('Error getting messages: $e');
      rethrow;
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
          .is_('worker_id', null)
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
      if (task.id != null) {
        await _tasksCollection
            .update(task.toJson())
            .eq('id', task.id);
      } else {
        await _tasksCollection
            .insert(task.toJson());
      }
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
      AppLogger().e('Error getting all tasks: $e');
      return Stream.value([]);
    }
  }
}
