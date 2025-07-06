import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/worker_task_provider.dart';
import '../../models/task_submission_model.dart';
import '../../models/task_feedback_model.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_loader.dart';
import '../../utils/style_system.dart';

class AdminTaskReviewScreen extends StatefulWidget {
  const AdminTaskReviewScreen({super.key});

  @override
  State<AdminTaskReviewScreen> createState() => _AdminTaskReviewScreenState();
}

class _AdminTaskReviewScreenState extends State<AdminTaskReviewScreen> {
  String _selectedFilter = 'all'; // all, submitted, approved, rejected

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WorkerTaskProvider>().fetchTaskSubmissions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StyleSystem.scaffoldBackgroundColor,
      appBar: CustomAppBar(
        title: 'مراجعة المهام',
        backgroundColor: StyleSystem.primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () {
              context.read<WorkerTaskProvider>().fetchTaskSubmissions();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterTabs(),
          Expanded(
            child: Consumer<WorkerTaskProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const CustomLoader(message: 'جاري تحميل التقارير...');
                }

                if (provider.error != null) {
                  return _buildErrorState(provider.error!);
                }

                final filteredSubmissions = _getFilteredSubmissions(provider.taskSubmissions);

                if (filteredSubmissions.isEmpty) {
                  return _buildEmptyState();
                }

                return RefreshIndicator(
                  onRefresh: () => provider.fetchTaskSubmissions(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredSubmissions.length,
                    itemBuilder: (context, index) {
                      final submission = filteredSubmissions[index];
                      return _buildSubmissionCard(submission);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: StyleSystem.cardGradient,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: StyleSystem.elevatedCardShadow,
      ),
      child: Row(
        children: [
          _buildFilterTab('all', 'الكل'),
          _buildFilterTab('submitted', 'مرسلة'),
          _buildFilterTab('approved', 'معتمدة'),
          _buildFilterTab('rejected', 'مرفوضة'),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String value, String label) {
    final isSelected = _selectedFilter == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedFilter = value;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? StyleSystem.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: StyleSystem.titleSmall.copyWith(
              color: isSelected ? Colors.white : StyleSystem.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  List<TaskSubmissionModel> _getFilteredSubmissions(List<TaskSubmissionModel> submissions) {
    switch (_selectedFilter) {
      case 'submitted':
        return submissions.where((s) => s.status == SubmissionStatus.submitted).toList();
      case 'approved':
        return submissions.where((s) => s.status == SubmissionStatus.approved).toList();
      case 'rejected':
        return submissions.where((s) => s.status == SubmissionStatus.rejected).toList();
      default:
        return submissions;
    }
  }

  Widget _buildSubmissionCard(TaskSubmissionModel submission) {
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
            // Header with task title and status
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        submission.taskTitle ?? 'مهمة غير محددة',
                        style: StyleSystem.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: StyleSystem.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'بواسطة: ${submission.workerName ?? 'غير محدد'}',
                        style: StyleSystem.bodyMedium.copyWith(
                          color: StyleSystem.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(submission.status),
              ],
            ),

            const SizedBox(height: 16),

            // Progress report
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: StyleSystem.primaryColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: StyleSystem.primaryColor.withValues(alpha: 0.1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.assignment_rounded,
                        size: 20,
                        color: StyleSystem.primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'تقرير التقدم',
                        style: StyleSystem.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: StyleSystem.primaryColor,
                        ),
                      ),
                      const Spacer(),
                      _buildCompletionBadge(submission.completionPercentage),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    submission.progressReport,
                    style: StyleSystem.bodyMedium.copyWith(
                      color: StyleSystem.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Submission details
            Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 16,
                  color: StyleSystem.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  DateFormat('dd/MM/yyyy - hh:mm a').format(submission.submittedAt),
                  style: StyleSystem.bodySmall.copyWith(
                    color: StyleSystem.textSecondary,
                  ),
                ),
                if (submission.hoursWorked != null) ...[
                  const SizedBox(width: 16),
                  const Icon(
                    Icons.access_time_rounded,
                    size: 16,
                    color: StyleSystem.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${submission.hoursWorked} ساعة',
                    style: StyleSystem.bodySmall.copyWith(
                      color: StyleSystem.textSecondary,
                    ),
                  ),
                ],
                if (submission.isFinalSubmission) ...[
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: StyleSystem.successColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'تقرير نهائي',
                      style: StyleSystem.labelSmall.copyWith(
                        color: StyleSystem.successColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),

            if (submission.notes != null && submission.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: StyleSystem.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.note_rounded,
                      size: 16,
                      color: StyleSystem.accentColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        submission.notes!,
                        style: StyleSystem.bodySmall.copyWith(
                          color: StyleSystem.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Action buttons
            if (submission.status == SubmissionStatus.submitted) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _approveSubmission(submission),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('اعتماد'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: StyleSystem.successColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showFeedbackDialog(submission),
                      icon: const Icon(Icons.comment_rounded),
                      label: const Text('تعليق'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: StyleSystem.primaryColor,
                        side: BorderSide(color: StyleSystem.primaryColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (submission.status == SubmissionStatus.approved) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: StyleSystem.successColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      color: StyleSystem.successColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'تم اعتماد هذا التقرير',
                      style: StyleSystem.bodyMedium.copyWith(
                        color: StyleSystem.successColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (submission.approvedByName != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        'بواسطة ${submission.approvedByName}',
                        style: StyleSystem.bodySmall.copyWith(
                          color: StyleSystem.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(SubmissionStatus status) {
    Color color;
    IconData icon;

    switch (status) {
      case SubmissionStatus.submitted:
        color = StyleSystem.warningColor;
        icon = Icons.pending_rounded;
        break;
      case SubmissionStatus.approved:
        color = StyleSystem.successColor;
        icon = Icons.check_circle_rounded;
        break;
      case SubmissionStatus.rejected:
        color = StyleSystem.errorColor;
        icon = Icons.cancel_rounded;
        break;
      case SubmissionStatus.needsRevision:
        color = StyleSystem.infoColor;
        icon = Icons.edit_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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

  Widget _buildCompletionBadge(int percentage) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: StyleSystem.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: StyleSystem.primaryColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$percentage%',
        style: StyleSystem.labelSmall.copyWith(
          color: StyleSystem.primaryColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _approveSubmission(TaskSubmissionModel submission) async {
    final success = await context.read<WorkerTaskProvider>().approveTaskSubmission(submission.id);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم اعتماد التقرير بنجاح'),
            backgroundColor: StyleSystem.successColor,
          ),
        );
      } else {
        final error = context.read<WorkerTaskProvider>().error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? 'فشل في اعتماد التقرير'),
            backgroundColor: StyleSystem.errorColor,
          ),
        );
      }
    }
  }

  void _showFeedbackDialog(TaskSubmissionModel submission) {
    final feedbackController = TextEditingController();
    FeedbackType selectedType = FeedbackType.comment;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة تعليق'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<FeedbackType>(
              value: selectedType,
              decoration: const InputDecoration(
                labelText: 'نوع التعليق',
                border: OutlineInputBorder(),
              ),
              items: FeedbackType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(_getFeedbackTypeDisplayName(type)),
                );
              }).toList(),
              onChanged: (value) {
                selectedType = value!;
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: feedbackController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'التعليق',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (feedbackController.text.trim().isNotEmpty) {
                final success = await context.read<WorkerTaskProvider>().addTaskFeedback(
                  submissionId: submission.id,
                  feedbackText: feedbackController.text.trim(),
                  feedbackType: selectedType,
                );
                
                Navigator.pop(context);
                
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم إضافة التعليق بنجاح'),
                      backgroundColor: StyleSystem.successColor,
                    ),
                  );
                } else {
                  final error = context.read<WorkerTaskProvider>().error;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(error ?? 'فشل في إضافة التعليق'),
                      backgroundColor: StyleSystem.errorColor,
                    ),
                  );
                }
              }
            },
            child: const Text('إرسال'),
          ),
        ],
      ),
    );
  }

  String _getFeedbackTypeDisplayName(FeedbackType type) {
    switch (type) {
      case FeedbackType.comment:
        return 'تعليق';
      case FeedbackType.approval:
        return 'موافقة';
      case FeedbackType.rejection:
        return 'رفض';
      case FeedbackType.revisionRequest:
        return 'طلب مراجعة';
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
            'لا توجد تقارير للمراجعة',
            style: StyleSystem.headlineSmall.copyWith(
              color: StyleSystem.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'ستظهر تقارير العمال هنا للمراجعة والاعتماد',
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
              context.read<WorkerTaskProvider>().fetchTaskSubmissions();
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
