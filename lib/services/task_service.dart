import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/task_model.dart';
import '../utils/logger.dart';

class TaskService {
  final SupabaseClient _supabase = Supabase.instance.client;
  static const String TABLE_NAME = 'tasks'; // Using 'tasks' table for TaskModel data

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

  // Stream all tasks - using cached data with manual refresh to prevent excessive polling
  Stream<List<TaskModel>> streamAllTasks() {
    // Return a stream that emits cached data and only refreshes on manual trigger
    return Stream.fromFuture(getAllTasks());
  }

  // Stream worker tasks - using cached data with manual refresh
  Stream<List<TaskModel>> streamWorkerTasks(String workerId) {
    // Return a stream that emits cached data and only refreshes on manual trigger
    return Stream.fromFuture(getWorkerTasks(workerId));
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
      AppLogger.info('🚀 Attempting to create ${tasks.length} tasks...');

      // Check authentication first
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        AppLogger.error('❌ User not authenticated');
        return false;
      }
      AppLogger.info('✅ User authenticated: ${currentUser.email}');

      // First, test if the table exists and is accessible
      try {
        final testResult = await _supabase.from(TABLE_NAME).select('id').limit(1);
        AppLogger.info('✅ Tasks table exists and is accessible. Test query returned ${testResult.length} rows');
        AppLogger.info('🔍 Using table: $TABLE_NAME');
      } catch (tableError) {
        AppLogger.error('❌ Tasks table test failed: $tableError');

        // More detailed error analysis
        final errorString = tableError.toString().toLowerCase();
        if (errorString.contains('404') || errorString.contains('not found')) {
          AppLogger.error('💡 SOLUTION: The tasks table endpoint does not exist. Check your Supabase project URL and table name.');
          return false;
        } else if (errorString.contains('relation') && errorString.contains('does not exist')) {
          AppLogger.error('💡 SOLUTION: The tasks table does not exist in the database. Please create it using the SQL editor.');
          return false;
        } else if (errorString.contains('permission denied') || errorString.contains('42501')) {
          AppLogger.error('💡 SOLUTION: Row Level Security (RLS) is blocking access. Please check your RLS policies.');
          return false;
        } else {
          AppLogger.error('💡 Unknown table access error. Please check your Supabase configuration.');
          return false;
        }
      }

      // تحويل المهام إلى JSON مع التحقق من البيانات
      final taskJsonList = <Map<String, dynamic>>[];

      AppLogger.info('📋 Validating and preparing ${tasks.length} tasks...');

      for (int i = 0; i < tasks.length; i++) {
        final task = tasks[i];
        final taskJson = task.toJson();

        // التحقق من البيانات المطلوبة
        if (taskJson['title'] == null || taskJson['title'].toString().isEmpty) {
          throw Exception('Task ${i + 1}: Title is required');
        }
        if (taskJson['assigned_to'] == null || taskJson['assigned_to'].toString().isEmpty) {
          throw Exception('Task ${i + 1}: Assigned worker is required');
        }
        if (taskJson['admin_id'] == null || taskJson['admin_id'].toString().isEmpty) {
          throw Exception('Task ${i + 1}: Admin ID is required');
        }

        // Additional validation for critical fields
        if (taskJson['status'] == null || taskJson['status'].toString().isEmpty) {
          taskJson['status'] = 'pending'; // Default status
        }
        if (taskJson['priority'] == null || taskJson['priority'].toString().isEmpty) {
          taskJson['priority'] = 'medium'; // Default priority
        }
        if (taskJson['category'] == null || taskJson['category'].toString().isEmpty) {
          taskJson['category'] = 'general'; // Default category
        }

        AppLogger.info('✅ Task ${i + 1} validated: ${taskJson['title']} -> ${taskJson['assigned_to']}');
        taskJsonList.add(taskJson);
      }

      // إرسال المهام إلى قاعدة البيانات
      AppLogger.info('💾 Sending ${taskJsonList.length} tasks to database...');
      AppLogger.info('🎯 Target table: $TABLE_NAME');

      try {
        AppLogger.info('🔍 About to insert into table: $TABLE_NAME');
        AppLogger.info('📝 Sample task data: ${taskJsonList.isNotEmpty ? taskJsonList.first : "No tasks"}');

        final response = await _supabase
            .from(TABLE_NAME)
            .insert(taskJsonList)
            .select();

        AppLogger.info('✅ Successfully created ${response.length} tasks');

        // Log the first task for verification
        if (response.isNotEmpty) {
          AppLogger.info('📄 Sample created task: ${response.first}');
        }

        return true;
      } catch (insertError) {
        AppLogger.error('❌ Database insert failed: $insertError');

        // Analyze the insert error
        final errorString = insertError.toString().toLowerCase();
        if (errorString.contains('permission denied') || errorString.contains('42501')) {
          AppLogger.error('💡 RLS POLICY ERROR: The authenticated user does not have permission to insert tasks.');
          AppLogger.error('💡 SOLUTION: Check your RLS policies for the tasks table.');
        } else if (errorString.contains('column') && errorString.contains('does not exist')) {
          AppLogger.error('💡 COLUMN ERROR: One or more columns in the task data do not exist in the database table.');
          AppLogger.error('💡 SOLUTION: Check your database schema matches the TaskModel structure.');
        } else if (errorString.contains('violates') && errorString.contains('constraint')) {
          AppLogger.error('💡 CONSTRAINT ERROR: The task data violates a database constraint.');
          AppLogger.error('💡 SOLUTION: Check for foreign key constraints and data types.');
        }

        rethrow;
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error creating multiple tasks: $e');
      AppLogger.error('Stack trace: $stackTrace');

      // طباعة تفاصيل إضافية للتشخيص
      if (e.toString().contains('relation') && e.toString().contains('does not exist')) {
        AppLogger.error('Database table issue detected. Please check if tasks table exists and has correct schema.');
      } else if (e.toString().contains('404') || e.toString().contains('Not Found')) {
        AppLogger.error('404 error detected. The tasks table or endpoint may not exist.');
      } else if (e.toString().contains('column') && e.toString().contains('does not exist')) {
        AppLogger.error('Column missing error detected. The tasks table schema may be outdated.');
      } else if (e.toString().contains('permission denied') || e.toString().contains('42501')) {
        AppLogger.error('PERMISSION DENIED ERROR DETECTED!');
        AppLogger.error('This is a Row Level Security (RLS) issue in Supabase.');
        AppLogger.error('SOLUTION: Go to your Supabase Dashboard > Authentication > Policies');
        AppLogger.error('Create the following policies for the "tasks" table:');
        AppLogger.error('1. SELECT policy: Allow all users to read tasks');
        AppLogger.error('2. INSERT policy: Allow authenticated users to insert tasks');
        AppLogger.error('3. UPDATE policy: Allow authenticated users to update tasks');
        AppLogger.error('4. DELETE policy: Allow authenticated users to delete tasks');
        AppLogger.error('Or run this SQL in your Supabase SQL Editor:');
        AppLogger.error('ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;');
        AppLogger.error('CREATE POLICY "Enable read access for all users" ON public.tasks FOR SELECT USING (true);');
        AppLogger.error('CREATE POLICY "Enable insert for authenticated users" ON public.tasks FOR INSERT TO authenticated WITH CHECK (true);');
        AppLogger.error('CREATE POLICY "Enable update for authenticated users" ON public.tasks FOR UPDATE TO authenticated USING (true) WITH CHECK (true);');
        AppLogger.error('CREATE POLICY "Enable delete for authenticated users" ON public.tasks FOR DELETE TO authenticated USING (true);');
      }

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