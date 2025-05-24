import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/task_model.dart';
import '../utils/app_logger.dart';

class TaskService {
  final SupabaseClient _supabase = Supabase.instance.client;
  static const String TABLE_NAME = 'tasks';

  // Get all tasks
  Future<List<TaskModel>> getAllTasks() async {
    try {
      final response = await _supabase
          .from(TABLE_NAME)
          .select()
          .order('created_at', ascending: false);
      
      return response.map<TaskModel>((json) => TaskModel.fromJson(json)).toList();
    } catch (e) {
      AppLogger.error('Error fetching all tasks: $e');
      return [];
    }
  }

  // Get tasks assigned to a specific worker
  Future<List<TaskModel>> getWorkerTasks(String workerId) async {
    try {
      final response = await _supabase
          .from(TABLE_NAME)
          .select()
          .eq('worker_id', workerId)
          .order('created_at', ascending: false);
      
      return response.map<TaskModel>((json) => TaskModel.fromJson(json)).toList();
    } catch (e) {
      AppLogger.error('Error fetching worker tasks: $e');
      return [];
    }
  }

  // Get tasks assigned by a specific admin
  Future<List<TaskModel>> getAdminTasks(String adminId) async {
    try {
      final response = await _supabase
          .from(TABLE_NAME)
          .select()
          .eq('admin_id', adminId)
          .order('created_at', ascending: false);
      
      return response.map<TaskModel>((json) => TaskModel.fromJson(json)).toList();
    } catch (e) {
      AppLogger.error('Error fetching admin tasks: $e');
      return [];
    }
  }

  // Stream all tasks - using polling instead of real-time since Supabase doesn't support real-time for all tables
  Stream<List<TaskModel>> streamAllTasks() {
    // TODO: Implement with Supabase realtime when available
    return Stream.periodic(const Duration(seconds: 10))
        .asyncMap((_) => getAllTasks());
  }

  // Stream worker tasks
  Stream<List<TaskModel>> streamWorkerTasks(String workerId) {
    // TODO: Implement with Supabase realtime when available
    return Stream.periodic(const Duration(seconds: 10))
        .asyncMap((_) => getWorkerTasks(workerId));
  }

  // Create a new task
  Future<TaskModel?> createTask(TaskModel task) async {
    try {
      final response = await _supabase
          .from(TABLE_NAME)
          .insert(task.toJson())
          .select()
          .single();
      
      AppLogger.info('Task created successfully: ${response['id']}');
      return TaskModel.fromJson(response);
    } catch (e) {
      AppLogger.error('Error creating task: $e');
      return null;
    }
  }

  // Update a task
  Future<bool> updateTask(TaskModel task) async {
    try {
      await _supabase
          .from(TABLE_NAME)
          .update(task.toJson())
          .eq('id', task.id);
      
      AppLogger.info('Task updated successfully: ${task.id}');
      return true;
    } catch (e) {
      AppLogger.error('Error updating task: $e');
      return false;
    }
  }

  // Update task status
  Future<bool> updateTaskStatus(String taskId, String status, double progress, int completedQuantity) async {
    try {
      await _supabase
          .from(TABLE_NAME)
          .update({
            'status': status,
            'progress': progress,
            'completed_quantity': completedQuantity
          })
          .eq('id', taskId);
      
      AppLogger.info('Task status updated successfully: $taskId');
      return true;
    } catch (e) {
      AppLogger.error('Error updating task status: $e');
      return false;
    }
  }

  // Delete a task
  Future<bool> deleteTask(String taskId) async {
    try {
      await _supabase
          .from(TABLE_NAME)
          .delete()
          .eq('id', taskId);
      
      AppLogger.info('Task deleted successfully: $taskId');
      return true;
    } catch (e) {
      AppLogger.error('Error deleting task: $e');
      return false;
    }
  }

  // Create multiple tasks at once
  Future<bool> createMultipleTasks(List<TaskModel> tasks) async {
    try {
      final taskJsonList = tasks.map((task) => task.toJson()).toList();
      await _supabase
          .from(TABLE_NAME)
          .insert(taskJsonList);
      
      AppLogger.info('Created ${tasks.length} tasks successfully');
      return true;
    } catch (e) {
      AppLogger.error('Error creating multiple tasks: $e');
      return false;
    }
  }

  // Get tasks by product ID
  Future<List<TaskModel>> getTasksByProductId(String productId) async {
    try {
      final response = await _supabase
          .from(TABLE_NAME)
          .select()
          .eq('product_id', productId)
          .order('created_at', ascending: false);
      
      return response.map<TaskModel>((json) => TaskModel.fromJson(json)).toList();
    } catch (e) {
      AppLogger.error('Error fetching tasks for product: $e');
      return [];
    }
  }

  // Get tasks by order ID
  Future<List<TaskModel>> getTasksByOrderId(String orderId) async {
    try {
      final response = await _supabase
          .from(TABLE_NAME)
          .select()
          .eq('order_id', orderId)
          .order('created_at', ascending: false);
      
      return response.map<TaskModel>((json) => TaskModel.fromJson(json)).toList();
    } catch (e) {
      AppLogger.error('Error fetching tasks for order: $e');
      return [];
    }
  }
} 