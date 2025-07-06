import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/worker_task_model.dart';
import '../../providers/worker_task_provider.dart';
import '../../widgets/custom_app_bar.dart';
import '../../utils/style_system.dart';

class TaskProgressSubmissionScreen extends StatefulWidget {

  const TaskProgressSubmissionScreen({super.key, required this.task});
  final WorkerTaskModel task;

  @override
  State<TaskProgressSubmissionScreen> createState() => _TaskProgressSubmissionScreenState();
}

class _TaskProgressSubmissionScreenState extends State<TaskProgressSubmissionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _progressReportController = TextEditingController();
  final _hoursWorkedController = TextEditingController();
  final _notesController = TextEditingController();
  
  int _completionPercentage = 0;
  bool _isFinalSubmission = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _progressReportController.dispose();
    _hoursWorkedController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StyleSystem.scaffoldBackgroundColor,
      appBar: CustomAppBar(
        title: 'تقرير التقدم',
        backgroundColor: StyleSystem.primaryColor,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTaskInfo(),
              const SizedBox(height: 20),
              _buildProgressForm(),
              const SizedBox(height: 20),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskInfo() {
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
            'المهمة',
            style: StyleSystem.titleMedium.copyWith(
              color: StyleSystem.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.task.title,
            style: StyleSystem.headlineSmall.copyWith(
              fontWeight: FontWeight.bold,
              color: StyleSystem.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressForm() {
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
            'تقرير التقدم',
            style: StyleSystem.titleLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: StyleSystem.textPrimary,
            ),
          ),
          const SizedBox(height: 20),

          // Progress Report
          TextFormField(
            controller: _progressReportController,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: 'تقرير العمل المنجز *',
              hintText: 'اكتب تفاصيل العمل الذي أنجزته...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: StyleSystem.primaryColor, width: 2),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'يرجى كتابة تقرير العمل المنجز';
              }
              if (value.trim().length < 10) {
                return 'يجب أن يكون التقرير أكثر تفصيلاً (10 أحرف على الأقل)';
              }
              return null;
            },
          ),

          const SizedBox(height: 20),

          // Completion Percentage
          Text(
            'نسبة الإنجاز: $_completionPercentage%',
            style: StyleSystem.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: StyleSystem.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: StyleSystem.primaryColor,
              inactiveTrackColor: StyleSystem.primaryColor.withOpacity(0.3),
              thumbColor: StyleSystem.primaryColor,
              overlayColor: StyleSystem.primaryColor.withOpacity(0.2),
              valueIndicatorColor: StyleSystem.primaryColor,
            ),
            child: Slider(
              value: _completionPercentage.toDouble(),
              min: 0,
              max: 100,
              divisions: 20,
              label: '$_completionPercentage%',
              onChanged: (value) {
                setState(() {
                  _completionPercentage = value.round();
                });
              },
            ),
          ),

          const SizedBox(height: 20),

          // Hours Worked
          TextFormField(
            controller: _hoursWorkedController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'عدد الساعات المعمولة',
              hintText: 'مثال: 8.5',
              suffixText: 'ساعة',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: StyleSystem.primaryColor, width: 2),
              ),
            ),
            validator: (value) {
              if (value != null && value.isNotEmpty) {
                final hours = double.tryParse(value);
                if (hours == null || hours < 0) {
                  return 'يرجى إدخال عدد ساعات صحيح';
                }
              }
              return null;
            },
          ),

          const SizedBox(height: 20),

          // Notes
          TextFormField(
            controller: _notesController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'ملاحظات إضافية',
              hintText: 'أي ملاحظات أو تحديات واجهتها...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: StyleSystem.primaryColor, width: 2),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Final Submission Checkbox
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: StyleSystem.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: StyleSystem.primaryColor.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: _isFinalSubmission,
                  onChanged: (value) {
                    setState(() {
                      _isFinalSubmission = value ?? false;
                    });
                  },
                  activeColor: StyleSystem.primaryColor,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تقرير نهائي',
                        style: StyleSystem.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: StyleSystem.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ضع علامة إذا كان هذا التقرير النهائي وتم إنجاز المهمة بالكامل',
                        style: StyleSystem.bodySmall.copyWith(
                          color: StyleSystem.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _isSubmitting ? null : _submitProgress,
        icon: _isSubmitting 
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.send_rounded),
        label: Text(_isSubmitting ? 'جاري الإرسال...' : 'إرسال التقرير'),
        style: ElevatedButton.styleFrom(
          backgroundColor: StyleSystem.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Future<void> _submitProgress() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final hoursWorked = _hoursWorkedController.text.isNotEmpty 
          ? double.tryParse(_hoursWorkedController.text)
          : null;

      final success = await context.read<WorkerTaskProvider>().submitTaskProgress(
        taskId: widget.task.id,
        progressReport: _progressReportController.text.trim(),
        completionPercentage: _completionPercentage,
        hoursWorked: hoursWorked,
        notes: _notesController.text.trim().isNotEmpty 
            ? _notesController.text.trim() 
            : null,
        isFinalSubmission: _isFinalSubmission,
      );

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إرسال التقرير بنجاح'),
              backgroundColor: StyleSystem.successColor,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          final error = context.read<WorkerTaskProvider>().error;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error ?? 'فشل في إرسال التقرير'),
              backgroundColor: StyleSystem.errorColor,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}
