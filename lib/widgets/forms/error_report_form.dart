import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smartbiztracker_new/utils/style_system.dart';
import 'package:smartbiztracker_new/widgets/custom_text_field.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ErrorReportForm extends StatefulWidget {
  final Function(Map<String, dynamic>) onSubmit;
  final bool isLoading;

  const ErrorReportForm({
    Key? key,
    required this.onSubmit,
    this.isLoading = false,
  }) : super(key: key);

  @override
  State<ErrorReportForm> createState() => _ErrorReportFormState();
}

class _ErrorReportFormState extends State<ErrorReportForm> {
  final _formKey = GlobalKey<FormState>();
  final _errorTitleController = TextEditingController();
  final _errorDescriptionController = TextEditingController();
  final _locationController = TextEditingController();
  String _selectedPriority = 'متوسط';
  XFile? _screenshot;
  bool _agreeToTerms = false;
  final ImagePicker _picker = ImagePicker();

  // Priority options
  final List<String> _priorities = ['منخفض', 'متوسط', 'عالي', 'عاجل'];

  // Steps progress
  int _currentStep = 0;
  
  @override
  void dispose() {
    _errorTitleController.dispose();
    _errorDescriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      setState(() {
        _screenshot = image;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشلت عملية اختيار الصورة')),
      );
    }
  }

  void _submitForm() {
    if (_formKey.currentState!.validate() && _agreeToTerms) {
      final errorReport = {
        'title': _errorTitleController.text,
        'description': _errorDescriptionController.text,
        'location': _locationController.text,
        'priority': _selectedPriority,
        'screenshot': _screenshot?.path,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      widget.onSubmit(errorReport);
    } else if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى الموافقة على الشروط والأحكام')),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(StyleSystem.radiusLarge),
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
            color: isDark 
              ? Colors.black.withOpacity(0.2)
              : Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
            // عنوان النموذج
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(StyleSystem.radiusLarge),
                  topRight: Radius.circular(StyleSystem.radiusLarge),
                            ),
              ),
              child: Text(
                'الإبلاغ عن خطأ',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.primaryColor,
                  fontWeight: FontWeight.bold,
                        ),
                textAlign: TextAlign.center,
                    ),
            ).animate().fadeIn(duration: 300.ms),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // عنوان الخطأ
                  CustomTextField(
                    controller: _errorTitleController,
                    labelText: 'عنوان الخطأ',
                    hintText: 'أدخل عنواناً موجزاً للخطأ',
                    prefixIcon: Icons.error_outline,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'يرجى إدخال عنوان الخطأ';
                      }
                      return null;
                    },
                  ).animate().fadeIn(duration: 300.ms).moveX(begin: 20, end: 0),
                  
                  const SizedBox(height: 16),
                  
                  // وصف الخطأ
                  CustomTextField(
                    controller: _errorDescriptionController,
                    labelText: 'وصف الخطأ',
                    hintText: 'اشرح الخطأ بالتفصيل',
                    maxLines: 4,
                    prefixIcon: Icons.description_outlined,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'يرجى إدخال وصف الخطأ';
                      }
                      return null;
                    },
                  ).animate().fadeIn(duration: 300.ms, delay: 100.ms).moveX(begin: 20, end: 0),
                  
                  const SizedBox(height: 16),
                  
                  // موقع الخطأ
                  CustomTextField(
                    controller: _locationController,
                    labelText: 'موقع الخطأ',
                    hintText: 'أين حدث الخطأ في التطبيق؟',
                    prefixIcon: Icons.location_on_outlined,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'يرجى تحديد موقع الخطأ';
                      }
                      return null;
                    },
                  ).animate().fadeIn(duration: 300.ms, delay: 200.ms).moveX(begin: 20, end: 0),

                  const SizedBox(height: 16),
                  
                  // مستوى الأولوية
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(StyleSystem.radiusMedium),
                      border: Border.all(
                        color: isDark 
                          ? StyleSystem.textTertiaryDark.withOpacity(0.3)
                          : Colors.grey[300]!,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedPriority,
                        isExpanded: true,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        borderRadius: BorderRadius.circular(StyleSystem.radiusMedium),
                        dropdownColor: theme.cardColor,
                        items: _priorities.map((priority) {
                          return DropdownMenuItem(
                            value: priority,
                            child: Text(
                              priority,
                              style: theme.textTheme.bodyMedium,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                          setState(() {
                              _selectedPriority = value;
                          });
                          }
                        },
                      ),
                    ),
                  ).animate().fadeIn(duration: 300.ms, delay: 300.ms).moveX(begin: 20, end: 0),

                  const SizedBox(height: 24),
                
                  // إضافة لقطة شاشة
                InkWell(
                  onTap: _pickImage,
                  child: Container(
                      padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(StyleSystem.radiusMedium),
                      border: Border.all(
                          color: isDark 
                            ? StyleSystem.textTertiaryDark.withOpacity(0.3)
                            : Colors.grey[300]!,
                          style: BorderStyle.solid,
                        ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                            Icons.add_a_photo_outlined,
                            size: 32,
                            color: theme.primaryColor,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _screenshot != null 
                              ? 'تم اختيار الصورة' 
                              : 'إضافة لقطة شاشة',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.primaryColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                  ).animate().fadeIn(duration: 300.ms, delay: 400.ms).moveX(begin: 20, end: 0),

                  const SizedBox(height: 24),
                
                  // الموافقة على الشروط
                      CheckboxListTile(
                        value: _agreeToTerms,
                        onChanged: (value) {
                          setState(() {
                        _agreeToTerms = value ?? false;
                          });
                        },
                    title: Text(
                      'أوافق على سياسة الخصوصية وشروط الاستخدام',
                      style: theme.textTheme.bodySmall,
                        ),
                    activeColor: theme.primaryColor,
                    contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                  ).animate().fadeIn(duration: 300.ms, delay: 500.ms),

                  const SizedBox(height: 24),

                  // زر الإرسال
                  ElevatedButton(
                    onPressed: widget.isLoading ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(StyleSystem.radiusMedium),
                      ),
                    ),
                    child: widget.isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                        )
                      : const Text('إرسال البلاغ'),
                  ).animate().fadeIn(duration: 300.ms, delay: 600.ms).moveY(begin: 10, end: 0),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }
} 