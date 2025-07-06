import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/widgets/common/custom_loader.dart';
import 'package:smartbiztracker_new/models/manufacturing/manufacturing_tool.dart';
import 'package:smartbiztracker_new/services/manufacturing/manufacturing_tools_service.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'dart:io';

/// شاشة إضافة أداة تصنيع جديدة مع نموذج شامل ومتقدم
class AddToolScreen extends StatefulWidget {
  const AddToolScreen({super.key});

  @override
  State<AddToolScreen> createState() => _AddToolScreenState();
}

class _AddToolScreenState extends State<AddToolScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ManufacturingToolsService _toolsService = ManufacturingToolsService();
  
  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _sizeController = TextEditingController();
  
  // Form state
  String _selectedUnit = 'قطعة';
  String? _selectedColor;
  File? _selectedImage;
  bool _isLoading = false;
  bool _isFormValid = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_validateForm);
    _quantityController.addListener(_validateForm);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _sizeController.dispose();
    super.dispose();
  }

  /// التحقق من صحة النموذج
  void _validateForm() {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (isValid != _isFormValid) {
      setState(() => _isFormValid = isValid);
    }
  }

  /// اختيار صورة من المعرض أو الكاميرا
  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      
      // إظهار خيارات اختيار الصورة
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => _buildImageSourceBottomSheet(),
      );
      
      if (source != null) {
        final XFile? image = await picker.pickImage(
          source: source,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 85,
        );
        
        if (image != null) {
          setState(() {
            _selectedImage = File(image.path);
          });
          AppLogger.info('✅ Image selected: ${image.path}');
        }
      }
    } catch (e) {
      AppLogger.error('❌ Error picking image: $e');
      _showErrorSnackBar('فشل في اختيار الصورة: $e');
    }
  }

  /// بناء قائمة خيارات مصدر الصورة
  Widget _buildImageSourceBottomSheet() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Text(
              'اختيار مصدر الصورة',
              style: AccountantThemeConfig.headlineSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt, color: Colors.white),
            title: Text(
              'الكاميرا',
              style: AccountantThemeConfig.bodyLarge.copyWith(color: Colors.white),
            ),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library, color: Colors.white),
            title: Text(
              'المعرض',
              style: AccountantThemeConfig.bodyLarge.copyWith(color: Colors.white),
            ),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// حفظ الأداة الجديدة
  Future<void> _saveTool() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() => _isLoading = true);

      // إنشاء طلب إضافة الأداة
      final request = CreateManufacturingToolRequest(
        name: _nameController.text.trim(),
        quantity: double.parse(_quantityController.text),
        unit: _selectedUnit,
        color: _selectedColor,
        size: _sizeController.text.trim().isEmpty ? null : _sizeController.text.trim(),
        imageUrl: null, // سيتم رفع الصورة لاحقاً إذا لزم الأمر
      );

      // حفظ الأداة
      final toolId = await _toolsService.addTool(request);
      
      AppLogger.info('✅ Tool saved successfully with ID: $toolId');
      
      if (mounted) {
        _showSuccessSnackBar('تم إضافة الأداة بنجاح');
        Navigator.pop(context, true);
      }
    } catch (e) {
      AppLogger.error('❌ Error saving tool: $e');
      if (mounted) {
        _showErrorSnackBar('فشل في حفظ الأداة: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// إظهار رسالة خطأ
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AccountantThemeConfig.dangerRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// إظهار رسالة نجاح
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AccountantThemeConfig.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AccountantThemeConfig.backgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          _buildForm(),
        ],
      ),
    );
  }

  /// بناء SliverAppBar
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: AccountantThemeConfig.mainBackgroundGradient,
        ),
        child: FlexibleSpaceBar(
          title: Text(
            'إضافة أداة جديدة',
            style: AccountantThemeConfig.headlineMedium.copyWith(
              color: Colors.white,
              fontSize: 20,
            ),
          ),
          centerTitle: true,
        ),
      ),
    );
  }

  /// بناء النموذج
  Widget _buildForm() {
    return SliverPadding(
      padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                
                // قسم الصورة
                _buildImageSection(),
                
                const SizedBox(height: 24),
                
                // اسم الأداة
                _buildNameField(),
                
                const SizedBox(height: 16),
                
                // الكمية والوحدة
                Row(
                  children: [
                    Expanded(flex: 2, child: _buildQuantityField()),
                    const SizedBox(width: 16),
                    Expanded(flex: 1, child: _buildUnitDropdown()),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // اللون والمقاس
                Row(
                  children: [
                    Expanded(child: _buildColorDropdown()),
                    const SizedBox(width: 16),
                    Expanded(child: _buildSizeField()),
                  ],
                ),
                
                const SizedBox(height: 32),
                
                // أزرار الحفظ والإلغاء
                _buildActionButtons(),
                
                const SizedBox(height: 24),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  /// بناء قسم الصورة
  Widget _buildImageSection() {
    return Container(
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Text(
              'صورة الأداة (اختيارية)',
              style: AccountantThemeConfig.bodyLarge.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 120,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  style: BorderStyle.solid,
                ),
              ),
              child: _selectedImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        _selectedImage!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_a_photo,
                          size: 48,
                          color: Colors.white54,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'اضغط لإضافة صورة',
                          style: AccountantThemeConfig.bodyMedium.copyWith(
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.3, end: 0);
  }

  /// بناء حقل اسم الأداة
  Widget _buildNameField() {
    return Container(
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: TextFormField(
        controller: _nameController,
        style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
        textDirection: TextDirection.rtl,
        decoration: InputDecoration(
          labelText: 'اسم الأداة *',
          labelStyle: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white70),
          hintText: 'أدخل اسم الأداة',
          hintStyle: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white54),
          prefixIcon: const Icon(Icons.build, color: Colors.white54),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'اسم الأداة مطلوب';
          }
          if (value.trim().length > 100) {
            return 'اسم الأداة يجب أن يكون أقل من 100 حرف';
          }
          return null;
        },
        inputFormatters: [
          LengthLimitingTextInputFormatter(100),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms, delay: 200.ms).slideX(begin: 0.3, end: 0);
  }

  /// بناء حقل الكمية
  Widget _buildQuantityField() {
    return Container(
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: TextFormField(
        controller: _quantityController,
        style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: 'الكمية *',
          labelStyle: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white70),
          hintText: '0',
          hintStyle: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white54),
          prefixIcon: const Icon(Icons.numbers, color: Colors.white54),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'الكمية مطلوبة';
          }
          final quantity = double.tryParse(value);
          if (quantity == null || quantity < 0) {
            return 'الكمية يجب أن تكون رقم صحيح أو عشري أكبر من أو يساوي صفر';
          }
          return null;
        },
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms, delay: 300.ms).slideX(begin: 0.3, end: 0);
  }

  /// بناء قائمة الوحدات
  Widget _buildUnitDropdown() {
    return Container(
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.warningOrange),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedUnit,
        style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
        dropdownColor: AccountantThemeConfig.cardColor,
        decoration: InputDecoration(
          labelText: 'الوحدة *',
          labelStyle: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white70),
          prefixIcon: const Icon(Icons.straighten, color: Colors.white54),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
        items: ToolUnits.availableUnits.map((unit) {
          return DropdownMenuItem(
            value: unit,
            child: Text(
              unit,
              style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
            ),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            setState(() => _selectedUnit = value);
          }
        },
      ),
    ).animate().fadeIn(duration: 600.ms, delay: 400.ms).slideX(begin: 0.3, end: 0);
  }

  /// بناء قائمة الألوان
  Widget _buildColorDropdown() {
    return Container(
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedColor,
        style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
        dropdownColor: AccountantThemeConfig.cardColor,
        decoration: InputDecoration(
          labelText: 'اللون (اختياري)',
          labelStyle: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white70),
          prefixIcon: const Icon(Icons.palette, color: Colors.white54),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
        items: [
          DropdownMenuItem<String>(
            value: null,
            child: Text(
              'بدون لون',
              style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white54),
            ),
          ),
          ...ToolColors.availableColors.map((color) {
            return DropdownMenuItem(
              value: color,
              child: Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: ToolColors.getColorValue(color),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white54),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    color,
                    style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
                  ),
                ],
              ),
            );
          }),
        ],
        onChanged: (value) {
          setState(() => _selectedColor = value);
        },
      ),
    ).animate().fadeIn(duration: 600.ms, delay: 500.ms).slideX(begin: 0.3, end: 0);
  }

  /// بناء حقل المقاس
  Widget _buildSizeField() {
    return Container(
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: TextFormField(
        controller: _sizeController,
        style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
        textDirection: TextDirection.rtl,
        decoration: InputDecoration(
          labelText: 'المقاس (اختياري)',
          labelStyle: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white70),
          hintText: 'مثال: كبير، متوسط، صغير',
          hintStyle: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white54),
          prefixIcon: const Icon(Icons.aspect_ratio, color: Colors.white54),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
        inputFormatters: [
          LengthLimitingTextInputFormatter(50),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms, delay: 600.ms).slideX(begin: 0.3, end: 0);
  }

  /// بناء أزرار العمل
  Widget _buildActionButtons() {
    return Row(
      children: [
        // زر الإلغاء
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
              elevation: 0,
            ),
            child: Text(
              'إلغاء',
              style: AccountantThemeConfig.bodyLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        
        const SizedBox(width: 16),
        
        // زر الحفظ
        Expanded(
          child: ElevatedButton(
            onPressed: (_isFormValid && !_isLoading) ? _saveTool : null,
            style: AccountantThemeConfig.primaryButtonStyle.copyWith(
              padding: MaterialStateProperty.all(
                const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'حفظ الأداة',
                    style: AccountantThemeConfig.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 600.ms, delay: 700.ms).slideY(begin: 0.3, end: 0);
  }
}
