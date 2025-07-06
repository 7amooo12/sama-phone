import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/models/warehouse_model.dart';
import 'package:smartbiztracker_new/providers/warehouse_provider.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// حوار إضافة أو تعديل مخزن
class AddWarehouseDialog extends StatefulWidget {
  final WarehouseModel? warehouse; // للتعديل
  final Function(WarehouseModel) onWarehouseAdded;

  const AddWarehouseDialog({
    super.key,
    this.warehouse,
    required this.onWarehouseAdded,
  });

  @override
  State<AddWarehouseDialog> createState() => _AddWarehouseDialogState();
}

class _AddWarehouseDialogState extends State<AddWarehouseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  bool _isLoading = false;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    
    // إذا كان في وضع التعديل، املأ الحقول
    if (widget.warehouse != null) {
      _nameController.text = widget.warehouse!.name;
      _addressController.text = widget.warehouse!.address;
      _descriptionController.text = widget.warehouse!.description ?? '';
      _isActive = widget.warehouse!.isActive;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.warehouse != null;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        decoration: AccountantThemeConfig.primaryCardDecoration,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // رأس الحوار
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AccountantThemeConfig.greenGradient,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isEditing ? Icons.edit_outlined : Icons.add_business_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isEditing ? 'تعديل المخزن' : 'إضافة مخزن جديد',
                      style: GoogleFonts.cairo(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            
            // محتوى الحوار
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // اسم المخزن
                      _buildTextField(
                        controller: _nameController,
                        label: 'اسم المخزن',
                        hint: 'أدخل اسم المخزن',
                        icon: Icons.warehouse_outlined,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'يرجى إدخال اسم المخزن';
                          }
                          if (value.trim().length < 3) {
                            return 'يجب أن يكون اسم المخزن 3 أحرف على الأقل';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // عنوان المخزن
                      _buildTextField(
                        controller: _addressController,
                        label: 'عنوان المخزن',
                        hint: 'أدخل عنوان المخزن',
                        icon: Icons.location_on_outlined,
                        maxLines: 2,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'يرجى إدخال عنوان المخزن';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // وصف المخزن (اختياري)
                      _buildTextField(
                        controller: _descriptionController,
                        label: 'وصف المخزن (اختياري)',
                        hint: 'أدخل وصف للمخزن',
                        icon: Icons.description_outlined,
                        maxLines: 3,
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // حالة المخزن (للتعديل فقط)
                      if (isEditing) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.toggle_on_outlined,
                                color: AccountantThemeConfig.primaryGreen,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'حالة المخزن',
                                  style: GoogleFonts.cairo(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Switch(
                                value: _isActive,
                                onChanged: (value) {
                                  setState(() {
                                    _isActive = value;
                                  });
                                },
                                activeColor: AccountantThemeConfig.primaryGreen,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      
                      // أزرار الإجراءات
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'إلغاء',
                                style: GoogleFonts.cairo(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _saveWarehouse,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AccountantThemeConfig.primaryGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      isEditing ? 'تحديث' : 'إضافة',
                                      style: GoogleFonts.cairo(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// بناء حقل نص
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          maxLines: maxLines,
          style: GoogleFonts.cairo(
            fontSize: 16,
            color: Colors.white,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.cairo(
              color: Colors.white54,
            ),
            prefixIcon: Icon(
              icon,
              color: AccountantThemeConfig.primaryGreen,
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.1),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.1),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AccountantThemeConfig.primaryGreen,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AccountantThemeConfig.warningOrange,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// حفظ المخزن
  Future<void> _saveWarehouse() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final warehouseProvider = Provider.of<WarehouseProvider>(context, listen: false);
      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
      final currentUser = supabaseProvider.user;

      if (currentUser == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      bool success;
      
      if (widget.warehouse != null) {
        // تعديل مخزن موجود
        success = await warehouseProvider.updateWarehouse(
          warehouseId: widget.warehouse!.id,
          name: _nameController.text.trim(),
          address: _addressController.text.trim(),
          description: _descriptionController.text.trim().isEmpty 
              ? null 
              : _descriptionController.text.trim(),
          isActive: _isActive,
        );
      } else {
        // إضافة مخزن جديد
        success = await warehouseProvider.createWarehouse(
          name: _nameController.text.trim(),
          address: _addressController.text.trim(),
          description: _descriptionController.text.trim().isEmpty 
              ? null 
              : _descriptionController.text.trim(),
          createdBy: currentUser.id,
        );
      }

      if (success && mounted) {
        Navigator.of(context).pop();
        
        // إشعار بالنجاح
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.warehouse != null 
                  ? 'تم تحديث المخزن بنجاح' 
                  : 'تم إضافة المخزن بنجاح',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: AccountantThemeConfig.primaryGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );

        // استدعاء callback
        if (widget.warehouse != null) {
          // في حالة التعديل، قم بإنشاء نموذج محدث
          final updatedWarehouse = widget.warehouse!.copyWith(
            name: _nameController.text.trim(),
            address: _addressController.text.trim(),
            description: _descriptionController.text.trim().isEmpty 
                ? null 
                : _descriptionController.text.trim(),
            isActive: _isActive,
            updatedAt: DateTime.now(),
          );
          widget.onWarehouseAdded(updatedWarehouse);
        }
      } else if (mounted) {
        // إشعار بالفشل
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.warehouse != null 
                  ? 'فشل في تحديث المخزن' 
                  : 'فشل في إضافة المخزن',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: AccountantThemeConfig.warningOrange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      AppLogger.error('خطأ في حفظ المخزن: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'حدث خطأ: ${e.toString()}',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
