import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/worker_task_provider.dart';
import '../../models/worker_task_model.dart';
import '../../models/task_submission_model.dart';
import '../../widgets/custom_loader.dart';
import '../../utils/style_system.dart';

class WorkerCompletedTasksScreen extends StatefulWidget {
  const WorkerCompletedTasksScreen({super.key});

  @override
  State<WorkerCompletedTasksScreen> createState() => _WorkerCompletedTasksScreenState();
}

class _WorkerCompletedTasksScreenState extends State<WorkerCompletedTasksScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<WorkerTaskProvider>();
      provider.fetchAssignedTasks();
      provider.fetchTaskSubmissions();
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
                  colors: StyleSystem.successGradient,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: StyleSystem.shadowSmall,
              ),
              child: const Icon(
                Icons.assignment_turned_in_rounded,
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
                  'المهام المنجزة',
                  style: StyleSystem.titleLarge.copyWith(
                    color: StyleSystem.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'تتبع الإنجازات والتقديمات',
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
            margin: const EdgeInsets.only(right: 16),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.purple.shade600,
                      Colors.pink.shade600,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.3),
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
                final provider = context.read<WorkerTaskProvider>();
                provider.fetchAssignedTasks();
                provider.fetchTaskSubmissions();
              },
            ),
          ),
        ],
      ),
      body: Consumer<WorkerTaskProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const CustomLoader(message: 'جاري تحميل المهام المنجزة...');
          }

          if (provider.error != null) {
            return _buildErrorState(provider.error!);
          }

          final completedTasks = provider.myCompletedTasks;

          if (completedTasks.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: () async {
              await provider.fetchAssignedTasks();
              await provider.fetchTaskSubmissions();
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: completedTasks.length,
              itemBuilder: (context, index) {
                final task = completedTasks[index];
                final submissions = _getTaskSubmissions(provider, task.id);
                return _buildCompletedTaskCard(task, submissions);
              },
            ),
          );
        },
      ),
    );
  }

  List<TaskSubmissionModel> _getTaskSubmissions(WorkerTaskProvider provider, String taskId) {
    return provider.taskSubmissions
        .where((submission) => submission.taskId == taskId)
        .toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
  }

  Widget _buildCompletedTaskCard(WorkerTaskModel task, List<TaskSubmissionModel> submissions) {
    final latestSubmission = submissions.isNotEmpty ? submissions.first : null;

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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and status
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
                _buildStatusBadge(task.status),
              ],
            ),

            const SizedBox(height: 12),

            // Task completion info
            if (latestSubmission != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: StyleSystem.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: StyleSystem.primaryColor.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.assignment_turned_in_rounded,
                          size: 20,
                          color: StyleSystem.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'آخر تقرير مرسل',
                          style: StyleSystem.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: StyleSystem.primaryColor,
                          ),
                        ),
                        const Spacer(),
                        _buildCompletionBadge(latestSubmission.completionPercentage),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      latestSubmission.progressReport,
                      style: StyleSystem.bodyMedium.copyWith(
                        color: StyleSystem.textSecondary,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 16,
                          color: StyleSystem.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('dd/MM/yyyy - hh:mm a').format(latestSubmission.submittedAt),
                          style: StyleSystem.bodySmall.copyWith(
                            color: StyleSystem.textSecondary,
                          ),
                        ),
                        if (latestSubmission.hoursWorked != null) ...[
                          const SizedBox(width: 16),
                          const Icon(
                            Icons.access_time_rounded,
                            size: 16,
                            color: StyleSystem.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${latestSubmission.hoursWorked} ساعة',
                            style: StyleSystem.bodySmall.copyWith(
                              color: StyleSystem.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Task details
            if (task.description != null && task.description!.isNotEmpty) ...[
              Text(
                task.description!,
                style: StyleSystem.bodyMedium.copyWith(
                  color: StyleSystem.textSecondary,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
            ],

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
                Text(
                  'مكتملة في ${DateFormat('dd/MM/yyyy').format(task.updatedAt)}',
                  style: StyleSystem.bodySmall.copyWith(
                    color: StyleSystem.textSecondary,
                  ),
                ),
              ],
            ),

            // Show all submissions count
            if (submissions.length > 1) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: StyleSystem.accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'عدد التقارير المرسلة: ${submissions.length}',
                  style: StyleSystem.bodySmall.copyWith(
                    color: StyleSystem.accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(TaskStatus status) {
    Color color;
    IconData icon;
    String text;

    switch (status) {
      case TaskStatus.completed:
        color = StyleSystem.successColor;
        icon = Icons.check_circle_rounded;
        text = 'مكتملة';
        break;
      case TaskStatus.approved:
        color = StyleSystem.successColor;
        icon = Icons.verified_rounded;
        text = 'معتمدة';
        break;
      default:
        color = StyleSystem.infoColor;
        icon = Icons.info_rounded;
        text = status.name;
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
            text,
            style: StyleSystem.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionBadge(int percentage) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: StyleSystem.successColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: StyleSystem.successColor.withOpacity(0.3)),
      ),
      child: Text(
        '$percentage%',
        style: StyleSystem.labelSmall.copyWith(
          color: StyleSystem.successColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
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
              Icons.assignment_turned_in_outlined,
              size: 64,
              color: StyleSystem.primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'لا توجد مهام منجزة',
            style: StyleSystem.headlineSmall.copyWith(
              color: StyleSystem.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'ستظهر المهام المنجزة هنا بعد إكمالها',
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
              final provider = context.read<WorkerTaskProvider>();
              provider.fetchAssignedTasks();
              provider.fetchTaskSubmissions();
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
}
