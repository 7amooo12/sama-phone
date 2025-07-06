import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/worker_task_model.dart';
import '../../providers/worker_task_provider.dart';
import '../../widgets/custom_app_bar.dart';
import '../../utils/style_system.dart';
import 'task_progress_submission_screen.dart';

class TaskDetailsScreen extends StatelessWidget {

  const TaskDetailsScreen({super.key, required this.task});
  final WorkerTaskModel task;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StyleSystem.scaffoldBackgroundColor,
      appBar: CustomAppBar(
        title: 'تفاصيل المهمة',
        backgroundColor: StyleSystem.primaryColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTaskHeader(),
            const SizedBox(height: 20),
            _buildTaskDetails(),
            const SizedBox(height: 20),
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: StyleSystem.cardGradient,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: StyleSystem.elevatedCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  task.title,
                  style: StyleSystem.headlineMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: StyleSystem.textPrimary,
                  ),
                ),
              ),
              _buildPriorityBadge(task.priority),
            ],
          ),
          const SizedBox(height: 12),
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
                  'موعد التسليم: ${DateFormat('dd/MM/yyyy').format(task.dueDate!)}',
                  style: StyleSystem.bodySmall.copyWith(
                    color: _getDueDateColor(task.dueDate!),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTaskDetails() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: StyleSystem.cardGradient,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: StyleSystem.elevatedCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تفاصيل المهمة',
            style: StyleSystem.titleLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: StyleSystem.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          if (task.description != null && task.description!.isNotEmpty) ...[
            _buildDetailRow(
              icon: Icons.description_rounded,
              label: 'الوصف',
              value: task.description!,
              isMultiline: true,
            ),
            const SizedBox(height: 16),
          ],

          if (task.category != null) ...[
            _buildDetailRow(
              icon: Icons.category_rounded,
              label: 'التصنيف',
              value: task.category!,
            ),
            const SizedBox(height: 16),
          ],

          if (task.location != null) ...[
            _buildDetailRow(
              icon: Icons.location_on_rounded,
              label: 'الموقع',
              value: task.location!,
            ),
            const SizedBox(height: 16),
          ],

          if (task.estimatedHours != null) ...[
            _buildDetailRow(
              icon: Icons.access_time_rounded,
              label: 'الساعات المقدرة',
              value: '${task.estimatedHours} ساعة',
            ),
            const SizedBox(height: 16),
          ],

          if (task.requirements != null && task.requirements!.isNotEmpty) ...[
            _buildDetailRow(
              icon: Icons.checklist_rounded,
              label: 'المتطلبات',
              value: task.requirements!,
              isMultiline: true,
            ),
            const SizedBox(height: 16),
          ],

          _buildDetailRow(
            icon: Icons.person_rounded,
            label: 'مسند بواسطة',
            value: task.assignedByName ?? 'غير محدد',
          ),
          const SizedBox(height: 16),

          _buildDetailRow(
            icon: Icons.calendar_today_rounded,
            label: 'تاريخ الإنشاء',
            value: DateFormat('dd/MM/yyyy - hh:mm a').format(task.createdAt),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    bool isMultiline = false,
  }) {
    return Row(
      crossAxisAlignment: isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: StyleSystem.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: StyleSystem.primaryColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: StyleSystem.labelMedium.copyWith(
                  color: StyleSystem.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: StyleSystem.bodyMedium.copyWith(
                  color: StyleSystem.textPrimary,
                  height: isMultiline ? 1.4 : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        if (task.status == TaskStatus.assigned || task.status == TaskStatus.inProgress) ...[
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TaskProgressSubmissionScreen(task: task),
                  ),
                );
              },
              icon: const Icon(Icons.edit_note_rounded),
              label: const Text('إرسال تقرير التقدم'),
              style: ElevatedButton.styleFrom(
                backgroundColor: StyleSystem.primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton.icon(
            onPressed: () {
              _markAsInProgress(context);
            },
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('بدء العمل'),
            style: OutlinedButton.styleFrom(
              foregroundColor: StyleSystem.primaryColor,
              side: BorderSide(color: StyleSystem.primaryColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _markAsInProgress(BuildContext context) {
    if (task.status == TaskStatus.assigned) {
      context.read<WorkerTaskProvider>().updateTaskStatus(task.id, TaskStatus.inProgress);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديث حالة المهمة إلى "قيد التنفيذ"'),
          backgroundColor: StyleSystem.successColor,
        ),
      );
    }
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
            task.priorityDisplayName,
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
            task.statusDisplayName,
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
}
