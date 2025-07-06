import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/worker_task_model.dart';
import '../../providers/worker_task_provider.dart';
import '../../widgets/custom_app_bar.dart';
import '../../utils/style_system.dart';

class EnhancedTaskProgressSubmissionScreen extends StatefulWidget {

  const EnhancedTaskProgressSubmissionScreen({super.key, required this.task});
  final WorkerTaskModel task;

  @override
  State<EnhancedTaskProgressSubmissionScreen> createState() => _EnhancedTaskProgressSubmissionScreenState();
}

class _EnhancedTaskProgressSubmissionScreenState extends State<EnhancedTaskProgressSubmissionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _progressReportController = TextEditingController();
  final _hoursWorkedController = TextEditingController();
  final _notesController = TextEditingController();
  
  int _completionPercentage = 0;
  bool _isFinalSubmission = false;
  bool _isSubmitting = false;

  // File management
  final List<File> _attachmentFiles = [];
  final List<File> _evidenceFiles = [];
  final ImagePicker _imagePicker = ImagePicker();

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
              _buildFileUploadSection(),
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

  Widget _buildFileUploadSection() {
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
            'المرفقات والأدلة',
            style: StyleSystem.titleLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: StyleSystem.textPrimary,
            ),
          ),
          const SizedBox(height: 20),

          // Attachment Files Section
          _buildFileSection(
            title: 'مرفقات المهمة',
            subtitle: 'ملفات، مستندات، تقارير',
            icon: Icons.attach_file_rounded,
            files: _attachmentFiles,
            onAddFile: () => _pickFiles('attachment'),
            onRemoveFile: (index) => _removeFile('attachment', index),
          ),

          const SizedBox(height: 20),

          // Evidence Files Section
          _buildFileSection(
            title: 'أدلة الإنجاز',
            subtitle: 'صور، فيديوهات توضح العمل المنجز',
            icon: Icons.camera_alt_rounded,
            files: _evidenceFiles,
            onAddFile: () => _pickFiles('evidence'),
            onRemoveFile: (index) => _removeFile('evidence', index),
            showCameraOption: true,
          ),
        ],
      ),
    );
  }

  Widget _buildFileSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<File> files,
    required VoidCallback onAddFile,
    required Function(int) onRemoveFile,
    bool showCameraOption = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: StyleSystem.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: StyleSystem.primaryColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: StyleSystem.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: StyleSystem.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: StyleSystem.bodySmall.copyWith(
                      color: StyleSystem.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (showCameraOption) ...[
              IconButton(
                onPressed: () => _takePicture(),
                icon: Icon(Icons.camera_alt_rounded, color: StyleSystem.primaryColor),
                tooltip: 'التقاط صورة',
              ),
            ],
            IconButton(
              onPressed: onAddFile,
              icon: Icon(Icons.add_rounded, color: StyleSystem.primaryColor),
              tooltip: 'إضافة ملف',
            ),
          ],
        ),
        
        if (files.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...files.asMap().entries.map((entry) {
            final index = entry.key;
            final file = entry.value;
            return _buildFileItem(file, () => onRemoveFile(index));
          }),
        ],
      ],
    );
  }

  Widget _buildFileItem(File file, VoidCallback onRemove) {
    final fileName = file.path.split('/').last;
    final isImage = _isImageFile(file);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: StyleSystem.neutralLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: StyleSystem.neutralMedium.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isImage ? StyleSystem.successColor.withOpacity(0.1) : StyleSystem.infoColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              isImage ? Icons.image_rounded : Icons.description_rounded,
              color: isImage ? StyleSystem.successColor : StyleSystem.infoColor,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              fileName,
              style: StyleSystem.bodyMedium.copyWith(
                color: StyleSystem.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded, color: StyleSystem.errorColor, size: 20),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
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

  // File handling methods
  Future<void> _pickFiles(String type) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result != null) {
        final files = result.files.map((file) => File(file.path!)).toList();
        setState(() {
          if (type == 'attachment') {
            _attachmentFiles.addAll(files);
          } else {
            _evidenceFiles.addAll(files);
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل في اختيار الملفات: $e'),
          backgroundColor: StyleSystem.errorColor,
        ),
      );
    }
  }

  Future<void> _takePicture() async {
    try {
      final image = await _imagePicker.pickImage(source: ImageSource.camera);
      if (image != null) {
        setState(() {
          _evidenceFiles.add(File(image.path));
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل في التقاط الصورة: $e'),
          backgroundColor: StyleSystem.errorColor,
        ),
      );
    }
  }

  void _removeFile(String type, int index) {
    setState(() {
      if (type == 'attachment') {
        _attachmentFiles.removeAt(index);
      } else {
        _evidenceFiles.removeAt(index);
      }
    });
  }

  bool _isImageFile(File file) {
    final extension = file.path.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension);
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
        attachmentFiles: _attachmentFiles.isNotEmpty ? _attachmentFiles : null,
        evidenceFiles: _evidenceFiles.isNotEmpty ? _evidenceFiles : null,
      );

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إرسال التقرير والمرفقات بنجاح'),
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
