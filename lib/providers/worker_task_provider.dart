import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/worker_task_model.dart';
import '../models/task_submission_model.dart';
import '../models/task_feedback_model.dart';
import '../services/supabase_storage_service.dart';
import '../utils/app_logger.dart';

class WorkerTaskProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final SupabaseStorageService _storageService = SupabaseStorageService();

  List<WorkerTaskModel> _assignedTasks = [];
  List<TaskSubmissionModel> _taskSubmissions = [];
  final List<TaskFeedbackModel> _taskFeedbacks = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<WorkerTaskModel> get assignedTasks => _assignedTasks;
  List<TaskSubmissionModel> get taskSubmissions => _taskSubmissions;
  List<TaskFeedbackModel> get taskFeedbacks => _taskFeedbacks;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Get tasks assigned to current user
  List<WorkerTaskModel> get myAssignedTasks {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return [];
    return _assignedTasks.where((task) => task.assignedTo == currentUserId).toList();
  }

  // Get completed tasks for current user
  List<WorkerTaskModel> get myCompletedTasks {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return [];
    return _assignedTasks.where((task) =>
      task.assignedTo == currentUserId &&
      (task.status == TaskStatus.completed || task.status == TaskStatus.approved)
    ).toList();
  }

  // Fetch assigned tasks with enhanced error handling and retry logic
  Future<void> fetchAssignedTasks() async {
    _setLoading(true);
    int retryCount = 0;
    const maxRetries = 3;
    const baseDelay = Duration(seconds: 2);

    while (retryCount < maxRetries) {
      try {
        AppLogger.info('🔄 Starting to fetch assigned tasks... (Attempt ${retryCount + 1}/$maxRetries)');

        // أولاً نحصل على المهام الأساسية مع timeout محسن
        final response = await _supabase
            .from('worker_tasks')
            .select('*')
            .eq('is_active', true)
            .order('created_at', ascending: false)
            .timeout(const Duration(seconds: 30));

        // ثم نحصل على أسماء المستخدمين بشكل منفصل مع timeout
        final userProfiles = await _supabase
            .from('user_profiles')
            .select('id, name')
            .timeout(const Duration(seconds: 30));

      // إنشاء خريطة للمستخدمين لسهولة البحث
      final userMap = <String, String>{};
      for (final profile in userProfiles) {
        final userId = profile['id'] as String;
        final userName = profile['name']?.toString() ?? 'مستخدم غير معروف';
        userMap[userId] = userName;
      }

      _assignedTasks = (response as List).map((json) {
        final task = WorkerTaskModel.fromJson(json as Map<String, dynamic>);
        return task.copyWith(
          assignedToName: userMap[task.assignedTo] ?? 'مستخدم غير معروف',
          assignedByName: task.assignedBy != null ? userMap[task.assignedBy!] ?? 'مستخدم غير معروف' : null,
        );
      }).toList();

        _clearError();
        AppLogger.info('✅ Fetched ${_assignedTasks.length} assigned tasks');

        // Success - break out of retry loop
        break;

      } catch (e) {
        retryCount++;
        final isNetworkError = e.toString().toLowerCase().contains('connection') ||
                              e.toString().toLowerCase().contains('timeout') ||
                              e.toString().toLowerCase().contains('reset by peer') ||
                              e.toString().toLowerCase().contains('network');

        AppLogger.error('❌ Error fetching assigned tasks (attempt $retryCount/$maxRetries): $e');

        if (retryCount >= maxRetries || !isNetworkError) {
          // Final failure or non-network error
          _setError('فشل في تحميل المهام المسندة: ${_getArabicErrorMessage(e.toString())}');
          break;
        } else {
          // Wait before retry with exponential backoff
          final delay = Duration(seconds: baseDelay.inSeconds * (1 << (retryCount - 1)));
          AppLogger.info('⏳ Retrying in ${delay.inSeconds} seconds...');
          await Future.delayed(delay);
        }
      }
    }
    _setLoading(false);
  }

  // Helper method to convert error messages to Arabic
  String _getArabicErrorMessage(String error) {
    final errorLower = error.toLowerCase();
    if (errorLower.contains('connection') || errorLower.contains('reset by peer')) {
      return 'مشكلة في الاتصال بالخادم. تحقق من اتصال الإنترنت';
    } else if (errorLower.contains('timeout')) {
      return 'انتهت مهلة الاتصال. حاول مرة أخرى';
    } else if (errorLower.contains('network')) {
      return 'خطأ في الشبكة. تحقق من اتصال الإنترنت';
    } else {
      return 'خطأ غير متوقع. حاول مرة أخرى لاحقاً';
    }
  }

  // Fetch task submissions with enhanced error handling and retry logic
  Future<void> fetchTaskSubmissions() async {
    _setLoading(true);
    int retryCount = 0;
    const maxRetries = 3;
    const baseDelay = Duration(seconds: 2);

    while (retryCount < maxRetries) {
      try {
        AppLogger.info('🔄 Starting to fetch task submissions... (Attempt ${retryCount + 1}/$maxRetries)');

        // أولاً نحصل على التقديمات الأساسية مع timeout
        final response = await _supabase
            .from('task_submissions')
            .select('*')
            .order('submitted_at', ascending: false)
            .timeout(const Duration(seconds: 30));

        // ثم نحصل على أسماء المستخدمين والمهام بشكل منفصل مع timeout
        final userProfiles = await _supabase
            .from('user_profiles')
            .select('id, name')
            .timeout(const Duration(seconds: 30));

        final workerTasks = await _supabase
            .from('worker_tasks')
            .select('id, title')
            .timeout(const Duration(seconds: 30));

      // إنشاء خرائط للبحث السريع
      final userMap = <String, String>{};
      for (final profile in userProfiles) {
        final userId = profile['id'] as String;
        final userName = profile['name']?.toString() ?? 'مستخدم غير معروف';
        userMap[userId] = userName;
      }

      final taskMap = <String, String>{};
      for (final task in workerTasks) {
        final taskId = task['id'] as String;
        final taskTitle = task['title']?.toString() ?? 'مهمة غير معروفة';
        taskMap[taskId] = taskTitle;
      }

      _taskSubmissions = (response as List).map((json) {
        final submission = TaskSubmissionModel.fromJson(json as Map<String, dynamic>);
        return submission.copyWith(
          workerName: userMap[submission.workerId] ?? 'مستخدم غير معروف',
          approvedByName: submission.approvedBy != null ? userMap[submission.approvedBy!] ?? 'مستخدم غير معروف' : null,
          taskTitle: taskMap[submission.taskId] ?? 'مهمة غير معروفة',
        );
      }).toList();

        _clearError();
        AppLogger.info('✅ Fetched ${_taskSubmissions.length} task submissions');

        // Success - break out of retry loop
        break;

      } catch (e) {
        retryCount++;
        final isNetworkError = e.toString().toLowerCase().contains('connection') ||
                              e.toString().toLowerCase().contains('timeout') ||
                              e.toString().toLowerCase().contains('reset by peer') ||
                              e.toString().toLowerCase().contains('network');

        AppLogger.error('❌ Error fetching task submissions (attempt $retryCount/$maxRetries): $e');

        if (retryCount >= maxRetries || !isNetworkError) {
          // Final failure or non-network error
          _setError('فشل في تحميل تقارير المهام: ${_getArabicErrorMessage(e.toString())}');
          break;
        } else {
          // Wait before retry with exponential backoff
          final delay = Duration(seconds: baseDelay.inSeconds * (1 << (retryCount - 1)));
          AppLogger.info('⏳ Retrying in ${delay.inSeconds} seconds...');
          await Future.delayed(delay);
        }
      }
    }
    _setLoading(false);
  }

  // Submit task progress
  Future<bool> submitTaskProgress({
    required String taskId,
    required String progressReport,
    required int completionPercentage,
    double? hoursWorked,
    String? notes,
    bool isFinalSubmission = false,
    List<File>? attachmentFiles,
    List<File>? evidenceFiles,
  }) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        _setError('المستخدم غير مسجل الدخول');
        return false;
      }

      // First, create the submission to get the submission ID
      final submissionData = {
        'task_id': taskId,
        'worker_id': currentUserId,
        'progress_report': progressReport,
        'completion_percentage': completionPercentage,
        'hours_worked': hoursWorked,
        'notes': notes,
        'is_final_submission': isFinalSubmission,
        'status': 'submitted',
        'attachments': <String>[], // Will be updated after file uploads
      };

      final submissionResponse = await _supabase
          .from('task_submissions')
          .insert(submissionData)
          .select()
          .single();

      final submissionId = submissionResponse['id'] as String;

      // Upload files if provided
      final allAttachmentUrls = <String>[];

      // Upload attachment files
      if (attachmentFiles != null && attachmentFiles.isNotEmpty) {
        for (final file in attachmentFiles) {
          final url = await _storageService.uploadTaskAttachment(
            userId: currentUserId,
            taskId: taskId,
            file: file,
          );
          if (url != null) {
            allAttachmentUrls.add(url);
          }
        }
      }

      // Upload evidence files
      if (evidenceFiles != null && evidenceFiles.isNotEmpty) {
        for (final file in evidenceFiles) {
          final url = await _storageService.uploadTaskEvidence(
            userId: currentUserId,
            taskId: taskId,
            submissionId: submissionId,
            file: file,
          );
          if (url != null) {
            allAttachmentUrls.add(url);
          }
        }
      }

      // Update submission with attachment URLs
      if (allAttachmentUrls.isNotEmpty) {
        await _supabase
            .from('task_submissions')
            .update({'attachments': allAttachmentUrls})
            .eq('id', submissionId);
      }

      // Update task status if final submission
      if (isFinalSubmission) {
        await _supabase
            .from('worker_tasks')
            .update({
              'status': 'completed',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', taskId);
      }

      // Refresh data
      await fetchTaskSubmissions();
      await fetchAssignedTasks();

      AppLogger.info('✅ Task progress submitted successfully');
      return true;
    } catch (e) {
      _setError('فشل في إرسال تقرير المهمة: $e');
      AppLogger.error('❌ Error submitting task progress: $e');
      return false;
    }
  }

  // Create new task (admin only)
  Future<bool> createTask({
    required String title,
    required String assignedTo,
    String? description,
    TaskPriority priority = TaskPriority.medium,
    DateTime? dueDate,
    int? estimatedHours,
    String? category,
    String? location,
    String? requirements,
  }) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        _setError('المستخدم غير مسجل الدخول');
        return false;
      }

      final taskData = {
        'title': title,
        'description': description,
        'assigned_to': assignedTo,
        'assigned_by': currentUserId,
        'priority': priority.name,
        'status': 'assigned',
        'due_date': dueDate?.toIso8601String(),
        'estimated_hours': estimatedHours,
        'category': category,
        'location': location,
        'requirements': requirements,
      };

      await _supabase.from('worker_tasks').insert(taskData);

      // Refresh data
      await fetchAssignedTasks();

      AppLogger.info('✅ Task created successfully');
      return true;
    } catch (e) {
      _setError('فشل في إنشاء المهمة: $e');
      AppLogger.error('❌ Error creating task: $e');
      return false;
    }
  }

  // Update task status (admin only)
  Future<bool> updateTaskStatus(String taskId, TaskStatus status) async {
    try {
      await _supabase
          .from('worker_tasks')
          .update({
            'status': status.name == 'inProgress' ? 'in_progress' : status.name,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', taskId);

      // Refresh data
      await fetchAssignedTasks();

      AppLogger.info('✅ Task status updated successfully');
      return true;
    } catch (e) {
      _setError('فشل في تحديث حالة المهمة: $e');
      AppLogger.error('❌ Error updating task status: $e');
      return false;
    }
  }

  // Approve task submission (admin only)
  Future<bool> approveTaskSubmission(String submissionId) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        _setError('المستخدم غير مسجل الدخول');
        return false;
      }

      await _supabase
          .from('task_submissions')
          .update({
            'status': 'approved',
            'approved_at': DateTime.now().toIso8601String(),
            'approved_by': currentUserId,
          })
          .eq('id', submissionId);

      // Refresh data
      await fetchTaskSubmissions();

      AppLogger.info('✅ Task submission approved successfully');
      return true;
    } catch (e) {
      _setError('فشل في اعتماد تقرير المهمة: $e');
      AppLogger.error('❌ Error approving task submission: $e');
      return false;
    }
  }

  // Add feedback to task submission (admin only)
  Future<bool> addTaskFeedback({
    required String submissionId,
    required String feedbackText,
    required FeedbackType feedbackType,
  }) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        _setError('المستخدم غير مسجل الدخول');
        return false;
      }

      final feedbackData = {
        'submission_id': submissionId,
        'admin_id': currentUserId,
        'feedback_text': feedbackText,
        'feedback_type': feedbackType.name == 'revisionRequest' ? 'revision_request' : feedbackType.name,
      };

      await _supabase.from('task_feedback').insert(feedbackData);

      AppLogger.info('✅ Task feedback added successfully');
      return true;
    } catch (e) {
      _setError('فشل في إضافة التعليق: $e');
      AppLogger.error('❌ Error adding task feedback: $e');
      return false;
    }
  }

  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _clearError();
  }
}
