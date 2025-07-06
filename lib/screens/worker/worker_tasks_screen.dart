import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:smartbiztracker_new/services/task_service.dart';
import 'package:smartbiztracker_new/models/task_model.dart';
import 'package:smartbiztracker_new/widgets/common/custom_loader.dart';
import 'package:smartbiztracker_new/utils/show_snackbar.dart';
import 'package:smartbiztracker_new/utils/style_system.dart';
import 'package:intl/intl.dart';

class WorkerTasksScreen extends StatefulWidget {
  const WorkerTasksScreen({super.key});

  @override
  _WorkerTasksScreenState createState() => _WorkerTasksScreenState();
}

class _WorkerTasksScreenState extends State<WorkerTasksScreen> with SingleTickerProviderStateMixin {
  final TaskService _taskService = TaskService();
  late TabController _tabController;

  bool _isLoading = true;
  bool _isUpdating = false;
  List<TaskModel> _tasks = [];
  List<TaskModel> _pendingTasks = [];
  List<TaskModel> _inProgressTasks = [];
  List<TaskModel> _completedTasks = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadTasks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = Provider.of<SupabaseProvider>(context, listen: false).user;

      if (user == null) {
        throw Exception('لم يتم العثور على بيانات المستخدم');
      }

      final tasks = await _taskService.getWorkerTasks(user.id);

      // Sort tasks by different statuses
      final pendingTasks = tasks.where((task) => task.status == 'pending').toList();
      final inProgressTasks = tasks.where((task) => task.status == 'in_progress').toList();
      final completedTasks = tasks.where((task) => task.status == 'completed').toList();

      // Sort tasks by deadline (closer deadlines first)
      pendingTasks.sort((a, b) => a.deadline.compareTo(b.deadline));
      inProgressTasks.sort((a, b) => a.deadline.compareTo(b.deadline));
      completedTasks.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Most recently completed first

      setState(() {
        _tasks = tasks;
        _pendingTasks = pendingTasks;
        _inProgressTasks = inProgressTasks;
        _completedTasks = completedTasks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ShowSnackbar.show(context, 'حدث خطأ أثناء تحميل المهام: $e', isError: true);
      }
    }
  }

  Future<void> _updateTaskStatus(TaskModel task, String newStatus, double progress, int completedQuantity) async {
    setState(() {
      _isUpdating = true;
    });

    try {
      final success = await _taskService.updateTaskStatus(
        task.id,
        newStatus,
        progress,
        completedQuantity,
      );

      if (!success) {
        throw Exception('فشل في تحديث حالة المهمة');
      }

      await _loadTasks();

      if (mounted) {
        ShowSnackbar.show(context, 'تم تحديث حالة المهمة بنجاح', isError: false);
      }
    } catch (e) {
      if (mounted) {
        ShowSnackbar.show(context, 'حدث خطأ أثناء تحديث حالة المهمة: $e', isError: true);
      }
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  void _showTaskDetailsDialog(TaskModel task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Task header
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const Divider(),

            // Task details
            Text('الوصف: ${task.description}'),
            const SizedBox(height: 8),
            Text('المشرف: ${task.adminName}'),
            const SizedBox(height: 8),
            Text('تاريخ الإنشاء: ${DateFormat('yyyy-MM-dd').format(task.createdAt)}'),
            const SizedBox(height: 8),
            Text(
              'الموعد النهائي: ${DateFormat('yyyy-MM-dd').format(task.deadline)}',
              style: TextStyle(
                color: task.deadline.isBefore(DateTime.now()) ? Colors.red : Colors.black,
                fontWeight: task.deadline.isBefore(DateTime.now()) ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 8),
            Text('الكمية المطلوبة: ${task.quantity}'),
            const SizedBox(height: 8),
            Text('الكمية المكتملة: ${task.completedQuantity}'),
            const SizedBox(height: 8),
            Text('النوع: ${task.category == 'product' ? 'منتج' : 'طلب'}'),

            const SizedBox(height: 16),

            // Action buttons based on task status
            if (task.status == 'pending') ...[
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _updateTaskStatus(task, 'in_progress', 0.1, 0);
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('بدء العمل على المهمة'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ] else if (task.status == 'in_progress') ...[
              // Update progress
              const Text(
                'تحديث التقدم:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),

              StatefulBuilder(
                builder: (context, setModalState) {
                  // Local state for the bottom sheet
                  int localCompletedQuantity = task.completedQuantity;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('الكمية المكتملة: $localCompletedQuantity من ${task.quantity}'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: localCompletedQuantity > 0
                                ? () {
                                    setModalState(() {
                                      localCompletedQuantity--;
                                    });
                                  }
                                : null,
                          ),
                          Expanded(
                            child: Slider(
                              value: localCompletedQuantity.toDouble(),
                              min: 0,
                              max: task.quantity.toDouble(),
                              divisions: task.quantity,
                              onChanged: (value) {
                                setModalState(() {
                                  localCompletedQuantity = value.round();
                                });
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: localCompletedQuantity < task.quantity
                                ? () {
                                    setModalState(() {
                                      localCompletedQuantity++;
                                    });
                                  }
                                : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                final progress = localCompletedQuantity / task.quantity;
                                _updateTaskStatus(task, 'in_progress', progress, localCompletedQuantity);
                              },
                              icon: const Icon(Icons.update),
                              label: const Text('تحديث التقدم'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: localCompletedQuantity == task.quantity
                                  ? () {
                                      Navigator.pop(context);
                                      _updateTaskStatus(task, 'completed', 1.0, task.quantity);
                                    }
                                  : null,
                              icon: const Icon(Icons.check_circle),
                              label: const Text('إكمال المهمة'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: StyleSystem.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('مهامي', style: StyleSystem.titleLarge.copyWith(color: StyleSystem.textPrimary)),
        backgroundColor: StyleSystem.surfaceDark,
        iconTheme: const IconThemeData(color: StyleSystem.textPrimary),
        bottom: TabBar(
          controller: _tabController,
          labelColor: StyleSystem.primaryColor,
          unselectedLabelColor: StyleSystem.textSecondary,
          indicatorColor: StyleSystem.primaryColor,
          tabs: const [
            Tab(text: 'قيد الانتظار'),
            Tab(text: 'قيد التنفيذ'),
            Tab(text: 'مكتملة'),
          ],
        ),
      ),
      body: _isLoading
          ? const CustomLoader(message: 'جاري تحميل المهام...')
          : Stack(
              children: [
                TabBarView(
                  controller: _tabController,
                  children: [
                    // Pending tasks
                    _buildTasksList(_pendingTasks),

                    // In progress tasks
                    _buildTasksList(_inProgressTasks),

                    // Completed tasks
                    _buildTasksList(_completedTasks),
                  ],
                ),
                if (_isUpdating) const CustomLoader(message: 'جاري تحديث المهمة...'),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadTasks,
        backgroundColor: StyleSystem.primaryColor,
        child: const Icon(Icons.refresh, color: StyleSystem.textPrimary),
      ),
    );
  }

  Widget _buildTasksList(List<TaskModel> tasks) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.task_alt,
              size: 64,
              color: StyleSystem.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد مهام متاحة',
              style: StyleSystem.bodyLarge.copyWith(color: StyleSystem.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return _buildTaskCard(task);
      },
    );
  }

  Widget _buildTaskCard(TaskModel task) {
    final isProductTask = task.category == 'product';
    final bool isOverdue = task.deadline.isBefore(DateTime.now()) && task.status != 'completed';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: StyleSystem.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isOverdue
            ? const BorderSide(color: StyleSystem.errorColor, width: 1)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => _showTaskDetailsDialog(task),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Task header with title and icon
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isProductTask ? Colors.blue.shade100 : Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isProductTask ? Icons.inventory : Icons.shopping_cart,
                      color: isProductTask ? Colors.blue.shade800 : Colors.orange.shade800,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: StyleSystem.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: StyleSystem.textPrimary,
                          ),
                        ),
                        Text(
                          task.productName,
                          style: StyleSystem.bodyMedium.copyWith(
                            color: StyleSystem.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(task.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _getStatusText(task.status),
                      style: TextStyle(
                        color: _getStatusColor(task.status),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Progress bar if in progress
              if (task.status == 'in_progress') ...[
                LinearProgressIndicator(
                  value: task.progress,
                  backgroundColor: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
                Text(
                  'الإنجاز: ${(task.progress * 100).round()}% (${task.completedQuantity}/${task.quantity})',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 4),
              ],

              // Task info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        task.adminName,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.event, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('yyyy-MM-dd').format(task.deadline),
                        style: TextStyle(
                          fontSize: 12,
                          color: isOverdue ? Colors.red : null,
                          fontWeight: isOverdue ? FontWeight.bold : null,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.shopping_bag, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${task.quantity}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),

              // Action buttons based on status
              if (task.status == 'pending') ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _updateTaskStatus(task, 'in_progress', 0.1, 0),
                    icon: const Icon(Icons.play_arrow, size: 16),
                    label: const Text('بدء العمل'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ] else if (task.status == 'in_progress') ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showTaskDetailsDialog(task),
                        icon: const Icon(Icons.update, size: 16),
                        label: const Text('تحديث'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          backgroundColor: Colors.blue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: task.completedQuantity == task.quantity
                            ? () => _updateTaskStatus(task, 'completed', 1.0, task.quantity)
                            : null,
                        icon: const Icon(Icons.check_circle, size: 16),
                        label: const Text('إكمال'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          backgroundColor: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'قيد الانتظار';
      case 'in_progress':
        return 'قيد التنفيذ';
      case 'completed':
        return 'مكتملة';
      default:
        return status;
    }
  }
}