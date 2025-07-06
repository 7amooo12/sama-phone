import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/worker_task_provider.dart';
import '../../models/worker_task_model.dart';
import '../../widgets/custom_loader.dart';
import '../../utils/style_system.dart';
import '../../utils/worker_rewards_debug.dart';
import 'task_details_screen.dart';

class WorkerAssignedTasksScreen extends StatefulWidget {
  const WorkerAssignedTasksScreen({super.key});

  @override
  State<WorkerAssignedTasksScreen> createState() => _WorkerAssignedTasksScreenState();
}

class _WorkerAssignedTasksScreenState extends State<WorkerAssignedTasksScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WorkerTaskProvider>().fetchAssignedTasks();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StyleSystem.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: StyleSystem.headerGradient,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: StyleSystem.shadowSmall,
              ),
              child: const Icon(
                Icons.assignment_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'المهام المسندة',
                  style: StyleSystem.titleLarge.copyWith(
                    color: StyleSystem.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'إدارة المهام والتقديمات',
                  style: StyleSystem.bodySmall.copyWith(
                    color: StyleSystem.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: StyleSystem.surfaceDark,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.grey.shade600,
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.bug_report_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              onPressed: () async {
                _showDiagnosisDialog();
              },
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.green.shade600,
                      Colors.teal.shade600,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.refresh_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              onPressed: () {
                context.read<WorkerTaskProvider>().fetchAssignedTasks();
              },
            ),
          ),
        ],
      ),
      body: Consumer<WorkerTaskProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const CustomLoader(message: 'جاري تحميل المهام...');
          }

          if (provider.error != null) {
            return _buildErrorState(provider.error!);
          }

          final myTasks = provider.myAssignedTasks;

          if (myTasks.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: () => provider.fetchAssignedTasks(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: myTasks.length,
              itemBuilder: (context, index) {
                final task = myTasks[index];
                return _buildTaskCard(task);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildTaskCard(WorkerTaskModel task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: StyleSystem.cardGradient,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: StyleSystem.elevatedCardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TaskDetailsScreen(task: task),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with title and priority
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        task.title,
                        style: StyleSystem.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: StyleSystem.textPrimary,
                        ),
                      ),
                    ),
                    _buildPriorityBadge(task.priority),
                  ],
                ),

                const SizedBox(height: 12),

                // Status and due date
                Row(
                  children: [
                    _buildStatusBadge(task.status),
                    const Spacer(),
                    if (task.dueDate != null) ...[
                      Icon(
                        Icons.schedule_rounded,
                        size: 16,
                        color: _getDueDateColor(task.dueDate!),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('dd/MM/yyyy').format(task.dueDate!),
                        style: StyleSystem.bodySmall.copyWith(
                          color: _getDueDateColor(task.dueDate!),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),

                if (task.description != null && task.description!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    task.description!,
                    style: StyleSystem.bodyMedium.copyWith(
                      color: StyleSystem.textSecondary,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 16),

                // Additional info
                Row(
                  children: [
                    if (task.category != null) ...[
                      Icon(
                        Icons.category_rounded,
                        size: 16,
                        color: StyleSystem.primaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        task.category!,
                        style: StyleSystem.bodySmall.copyWith(
                          color: StyleSystem.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (task.estimatedHours != null) ...[
                      Icon(
                        Icons.access_time_rounded,
                        size: 16,
                        color: StyleSystem.accentColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${task.estimatedHours} ساعة',
                        style: StyleSystem.bodySmall.copyWith(
                          color: StyleSystem.accentColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(TaskPriority priority) {
    Color color;
    IconData icon;

    switch (priority) {
      case TaskPriority.urgent:
        color = StyleSystem.errorColor;
        icon = Icons.priority_high_rounded;
        break;
      case TaskPriority.high:
        color = Colors.orange;
        icon = Icons.keyboard_arrow_up_rounded;
        break;
      case TaskPriority.medium:
        color = StyleSystem.warningColor;
        icon = Icons.remove_rounded;
        break;
      case TaskPriority.low:
        color = StyleSystem.successColor;
        icon = Icons.keyboard_arrow_down_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            priority.name,
            style: StyleSystem.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(TaskStatus status) {
    Color color;
    IconData icon;

    switch (status) {
      case TaskStatus.assigned:
        color = StyleSystem.infoColor;
        icon = Icons.assignment_rounded;
        break;
      case TaskStatus.inProgress:
        color = StyleSystem.warningColor;
        icon = Icons.work_rounded;
        break;
      case TaskStatus.completed:
        color = StyleSystem.successColor;
        icon = Icons.check_circle_rounded;
        break;
      case TaskStatus.approved:
        color = StyleSystem.successColor;
        icon = Icons.verified_rounded;
        break;
      case TaskStatus.rejected:
        color = StyleSystem.errorColor;
        icon = Icons.cancel_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            status.name,
            style: StyleSystem.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getDueDateColor(DateTime dueDate) {
    final now = DateTime.now();
    final difference = dueDate.difference(now).inDays;

    if (difference < 0) {
      return StyleSystem.errorColor; // Overdue
    } else if (difference <= 1) {
      return StyleSystem.warningColor; // Due soon
    } else {
      return StyleSystem.textSecondary; // Normal
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  StyleSystem.primaryColor.withOpacity(0.1),
                  StyleSystem.accentColor.withOpacity(0.05),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.assignment_outlined,
              size: 64,
              color: StyleSystem.primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'لا توجد مهام مسندة',
            style: StyleSystem.headlineSmall.copyWith(
              color: StyleSystem.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'سيتم عرض المهام المسندة إليك هنا',
            style: StyleSystem.bodyMedium.copyWith(
              color: StyleSystem.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: StyleSystem.errorGradient,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'حدث خطأ',
            style: StyleSystem.headlineSmall.copyWith(
              color: StyleSystem.errorColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            error,
            style: StyleSystem.bodyMedium.copyWith(
              color: StyleSystem.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              context.read<WorkerTaskProvider>().fetchAssignedTasks();
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: StyleSystem.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// عرض نافذة التشخيص
  Future<void> _showDiagnosisDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        title: Text('جاري التشخيص...'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('يتم فحص نظام المهام والمكافآت...'),
          ],
        ),
      ),
    );

    try {
      final diagnosis = await WorkerRewardsDebug.diagnoseRewardsSystem();

      if (!mounted) return;
      Navigator.of(context).pop(); // إغلاق نافذة التحميل

      // عرض نتائج التشخيص
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('نتائج التشخيص'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDiagnosisSection('الجداول', diagnosis['tables']),
                const SizedBox(height: 16),
                _buildDiagnosisSection('البيانات', diagnosis['data']),
                const SizedBox(height: 16),
                _buildDiagnosisSection('المستخدم الحالي', diagnosis['currentUser']),
                const SizedBox(height: 16),
                _buildDiagnosisSection('الاستعلامات', diagnosis['queries']),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                final success = await WorkerRewardsDebug.createTestData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? 'تم إنشاء البيانات التجريبية' : 'فشل في إنشاء البيانات التجريبية'),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                  if (success) {
                    context.read<WorkerTaskProvider>().fetchAssignedTasks();
                  }
                }
              },
              child: const Text('إنشاء بيانات تجريبية'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // إغلاق نافذة التحميل

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في التشخيص: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildDiagnosisSection(String title, dynamic data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            data.toString(),
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          ),
        ),
      ],
    );
  }
}
