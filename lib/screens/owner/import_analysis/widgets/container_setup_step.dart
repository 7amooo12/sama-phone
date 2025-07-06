import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';

/// خطوة إعداد الحاوية - الخطوة الأولى في سير عمل استيراد الحاوية
class ContainerSetupStep extends StatefulWidget {
  final VoidCallback onNext;

  const ContainerSetupStep({
    super.key,
    required this.onNext,
  });

  @override
  State<ContainerSetupStep> createState() => _ContainerSetupStepState();
}

class _ContainerSetupStepState extends State<ContainerSetupStep> {
  final _formKey = GlobalKey<FormState>();
  final _containerNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _supplierNameController = TextEditingController();
  final _supplierContactController = TextEditingController();
  final _originCountryController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _containerNameController.dispose();
    _descriptionController.dispose();
    _supplierNameController.dispose();
    _supplierContactController.dispose();
    _originCountryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AccountantThemeConfig.cardShadows,
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen.withOpacity(0.3)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepHeader(),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildContainerInfoSection(),
                    const SizedBox(height: 24),
                    _buildSupplierInfoSection(),
                    const SizedBox(height: 32),
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.3);
  }

  /// بناء رأس الخطوة
  Widget _buildStepHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: AccountantThemeConfig.greenGradient,
            borderRadius: BorderRadius.circular(12),
            boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
          ),
          child: Icon(
            Icons.settings,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الخطوة 1: إعداد الحاوية',
                style: AccountantThemeConfig.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'أدخل المعلومات الأساسية للحاوية المراد استيرادها',
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: AccountantThemeConfig.white70,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// بناء قسم معلومات الحاوية
  Widget _buildContainerInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'معلومات الحاوية',
          style: AccountantThemeConfig.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        
        // اسم الحاوية
        _buildTextField(
          controller: _containerNameController,
          label: 'اسم الحاوية *',
          hint: 'مثال: حاوية يناير 2024',
          icon: Icons.inventory_2,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'يرجى إدخال اسم الحاوية';
            }
            return null;
          },
        ),
        
        const SizedBox(height: 16),
        
        // تاريخ الاستيراد
        _buildDateField(),
        
        const SizedBox(height: 16),
        
        // وصف اختياري
        _buildTextField(
          controller: _descriptionController,
          label: 'وصف الحاوية (اختياري)',
          hint: 'وصف مختصر للحاوية ومحتوياتها',
          icon: Icons.description,
          maxLines: 3,
        ),
      ],
    );
  }

  /// بناء قسم معلومات المورد
  Widget _buildSupplierInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'معلومات المورد (اختياري)',
          style: AccountantThemeConfig.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        
        // اسم المورد
        _buildTextField(
          controller: _supplierNameController,
          label: 'اسم المورد',
          hint: 'اسم الشركة أو المورد',
          icon: Icons.business,
        ),
        
        const SizedBox(height: 16),
        
        // معلومات الاتصال
        _buildTextField(
          controller: _supplierContactController,
          label: 'معلومات الاتصال',
          hint: 'رقم الهاتف أو البريد الإلكتروني',
          icon: Icons.contact_phone,
        ),
        
        const SizedBox(height: 16),
        
        // بلد المنشأ
        _buildTextField(
          controller: _originCountryController,
          label: 'بلد المنشأ',
          hint: 'البلد المصدر للبضائع',
          icon: Icons.public,
        ),
      ],
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
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue.withOpacity(0.3)),
      ),
      child: TextFormField(
        controller: controller,
        validator: validator,
        maxLines: maxLines,
        textDirection: TextDirection.rtl,
        style: AccountantThemeConfig.bodyLarge.copyWith(
          color: Colors.white,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: AccountantThemeConfig.bodyMedium.copyWith(
            color: Colors.white70,
          ),
          hintStyle: AccountantThemeConfig.bodyMedium.copyWith(
            color: Colors.white54,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.greenGradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: AccountantThemeConfig.primaryGreen,
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: AccountantThemeConfig.dangerRed,
              width: 2,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: AccountantThemeConfig.dangerRed,
              width: 2,
            ),
          ),
          filled: true,
          fillColor: AccountantThemeConfig.cardBackground1.withOpacity(0.5),
          errorStyle: AccountantThemeConfig.bodySmall.copyWith(
            color: AccountantThemeConfig.dangerRed,
          ),
        ),
      ),
    );
  }

  /// بناء حقل التاريخ
  Widget _buildDateField() {
    return InkWell(
      onTap: _selectDate,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue.withOpacity(0.3)),
          color: AccountantThemeConfig.cardBackground1.withOpacity(0.5),
        ),
        child: Row(
          children: [
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AccountantThemeConfig.blueGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.calendar_today,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تاريخ الاستيراد *',
                    style: AccountantThemeConfig.bodyMedium.copyWith(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                    style: AccountantThemeConfig.bodyLarge.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              color: Colors.white70,
            ),
          ],
        ),
      ),
    );
  }

  /// بناء أزرار الإجراءات
  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.greenGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
            ),
            child: ElevatedButton(
              onPressed: _validateAndNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'التالي',
                    style: AccountantThemeConfig.bodyLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// اختيار التاريخ
  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AccountantThemeConfig.primaryGreen,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  /// التحقق من صحة البيانات والانتقال للخطوة التالية
  void _validateAndNext() {
    if (_formKey.currentState!.validate()) {
      // حفظ البيانات (يمكن إضافة منطق حفظ البيانات هنا)
      widget.onNext();
    }
  }
}
