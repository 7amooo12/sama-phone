import 'package:flutter/foundation.dart';
import '../services/database_service.dart';
import '../models/task_model.dart';
import '../utils/app_logger.dart';

class TaskProvider with ChangeNotifier {

  TaskProvider({required DatabaseService databaseService}) 
    : _databaseService = databaseService;
  final DatabaseService _databaseService;
  List<TaskModel> _tasks = [];
  bool _isLoading = false;
  String? _error;

  List<TaskModel> get tasks => _tasks;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadTasks(String userId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _tasks = await _databaseService.getTasks(userId);
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load tasks';
      _isLoading = false;
      AppLogger.error('Error loading tasks', e);
      notifyListeners();
    }
  }

  Future<void> addTask(TaskModel task) async {
    try {
      await _databaseService.saveTask(task);
      _tasks.insert(0, task);
      notifyListeners();
    } catch (e) {
      AppLogger.error('Error adding task', e);
      rethrow;
    }
  }

  Future<void> updateTask(TaskModel task) async {
    try {
      await _databaseService.saveTask(task);
      final index = _tasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        _tasks[index] = task;
        notifyListeners();
      }
    } catch (e) {
      AppLogger.error('Error updating task', e);
      rethrow;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
} 