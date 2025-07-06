import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/distributors_provider.dart';
import '../../models/distribution_center_model.dart';
import '../../models/distributor_model.dart';
import '../../widgets/custom_text_field.dart';
import '../../utils/validators.dart';

/// Comprehensive screen for adding new distributors to a distribution center
class AddDistributorScreen extends StatefulWidget {
  const AddDistributorScreen({
    super.key,
    required this.center,
  });

  final DistributionCenterModel center;

  @override
  State<AddDistributorScreen> createState() => _AddDistributorScreenState();
}

class _AddDistributorScreenState extends State<AddDistributorScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isLoading = false;

  // Form Controllers - Simplified to essential fields only
  final _nameController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _showroomNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _emailController = TextEditingController();
  final _nationalIdController = TextEditingController();

  String _selectedStatus = 'active';

  final List<Map<String, String>> _statusOptions = [
    {'value': 'active', 'label': 'نشط'},
    {'value': 'inactive', 'label': 'غير نشط'},
    {'value': 'suspended', 'label': 'معلق'},
    {'value': 'pending', 'label': 'قيد المراجعة'},
  ];

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _contactPhoneController.dispose();
    _showroomNameController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _nationalIdController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A0A0A), // Professional luxurious black
              Color(0xFF1A1A2E), // Darkened blue-black
              Color(0xFF16213E), // Deep blue-black
              Color(0xFF0F0F23), // Rich dark blue
            ],
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom App Bar
              _buildCustomAppBar(),

              // Form Content
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: _buildFormContent(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          // Back Button
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: 28,
            ),
          ),

          const SizedBox(width: 16),

          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      Colors.blue.shade200,
                      Colors.white,
                    ],
                  ).createShader(bounds),
                  child: Text(
                    'إضافة موزع جديد',
                    style: GoogleFonts.cairo(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.6),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  widget.center.name,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildFormContent() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Required Fields Section
            _buildSectionHeader('المعلومات الأساسية', Icons.person, true),
            const SizedBox(height: 16),

            // Name Field
            CustomTextField(
              controller: _nameController,
              labelText: 'اسم الموزع',
              hintText: 'أدخل اسم الموزع',
              prefixIcon: Icons.person,
              validator: Validators.required,
              textInputAction: TextInputAction.next,
            ),

            const SizedBox(height: 16),

            // Contact Phone Field
            CustomTextField(
              controller: _contactPhoneController,
              labelText: 'رقم الهاتف',
              hintText: 'أدخل رقم الهاتف',
              prefixIcon: Icons.phone,
              keyboardType: TextInputType.phone,
              validator: Validators.phone,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ],
            ),

            const SizedBox(height: 16),

            // Showroom Name Field
            CustomTextField(
              controller: _showroomNameController,
              labelText: 'اسم المعرض',
              hintText: 'أدخل اسم المعرض',
              prefixIcon: Icons.store,
              validator: Validators.required,
              textInputAction: TextInputAction.next,
            ),

            const SizedBox(height: 16),

            // Status Dropdown
            _buildStatusDropdown(),

            const SizedBox(height: 32),

            // Location Information Section
            _buildSectionHeader('معلومات الموقع', Icons.location_on, false),
            const SizedBox(height: 16),

            // Address Field
            CustomTextField(
              controller: _addressController,
              labelText: 'العنوان',
              hintText: 'أدخل عنوان الموزع',
              prefixIcon: Icons.location_on,
              maxLines: 2,
              textInputAction: TextInputAction.next,
            ),

            const SizedBox(height: 16),

            // Email Field
            CustomTextField(
              controller: _emailController,
              labelText: 'البريد الإلكتروني',
              hintText: 'أدخل البريد الإلكتروني',
              prefixIcon: Icons.email,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  return Validators.email(value);
                }
                return null;
              },
              textInputAction: TextInputAction.next,
            ),

            const SizedBox(height: 16),

            // National ID Field
            CustomTextField(
              controller: _nationalIdController,
              labelText: 'الرقم القومي',
              hintText: 'أدخل الرقم القومي',
              prefixIcon: Icons.badge,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(14),
              ],
            ),

            const SizedBox(height: 48),

            // Save Button
            _buildSaveButton(),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
  Widget _buildSectionHeader(String title, IconData icon, bool isRequired) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                Colors.blue.withOpacity(0.8),
                Colors.indigo.withOpacity(0.8),
              ],
            ),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ),

        if (isRequired)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'مطلوب',
              style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatusDropdown() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.15),
            Colors.white.withOpacity(0.05),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedStatus,
        decoration: InputDecoration(
          labelText: 'حالة الموزع',
          labelStyle: GoogleFonts.cairo(
            color: Colors.white.withOpacity(0.8),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(
            Icons.flag,
            color: Colors.white.withOpacity(0.7),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        dropdownColor: const Color(0xFF1A1A2E),
        style: GoogleFonts.cairo(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        items: _statusOptions.map((option) {
          return DropdownMenuItem<String>(
            value: option['value'],
            child: Text(
              option['label']!,
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _selectedStatus = value!;
          });
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'يرجى اختيار حالة الموزع';
          }
          return null;
        },
      ),
    );
  }


  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveDistributor,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.withOpacity(0.9),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
          shadowColor: Colors.green.withOpacity(0.4),
        ),
        child: _isLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'جاري الحفظ...',
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.save, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'حفظ الموزع',
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
  Future<void> _saveDistributor() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final distributor = DistributorModel(
        id: '', // Will be generated by the provider
        distributionCenterId: widget.center.id,
        name: _nameController.text.trim(),
        contactPhone: _contactPhoneController.text.trim(),
        showroomName: _showroomNameController.text.trim(),
        showroomAddress: _addressController.text.trim().isNotEmpty
            ? _addressController.text.trim()
            : null,
        email: _emailController.text.trim().isNotEmpty
            ? _emailController.text.trim()
            : null,
        nationalId: _nationalIdController.text.trim().isNotEmpty
            ? _nationalIdController.text.trim()
            : null,
        status: DistributorStatus.fromString(_selectedStatus),
        // Use default values for removed financial/contract fields
        commissionRate: 0.0,
        creditLimit: 0.0,
        contractStartDate: null,
        contractEndDate: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final provider = context.read<DistributorsProvider>();
      final success = await provider.addDistributor(distributor);

      if (success && mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'تم إضافة الموزع بنجاح',
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );

        // Navigate back
        Navigator.of(context).pop();
      } else if (mounted) {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    provider.error ?? 'فشل في إضافة الموزع',
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'حدث خطأ غير متوقع: $e',
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
