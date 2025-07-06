import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartbiztracker_new/config/routes.dart';
import 'package:smartbiztracker_new/models/user_model.dart';
import 'package:smartbiztracker_new/providers/auth_provider.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:smartbiztracker_new/widgets/common/custom_app_bar.dart';
import 'package:smartbiztracker_new/widgets/common/main_drawer.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smartbiztracker_new/utils/color_extension.dart';
import 'package:smartbiztracker_new/models/user_role.dart';
import 'package:intl/intl.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:smartbiztracker_new/services/profile_storage_service.dart';
import 'change_password_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool _isLoading = false;
  bool _isEditing = false;
  File? _imageFile;
  bool _isUploading = false;
  final _supabase = Supabase.instance.client;
  late final ProfileStorageService _profileStorageService;

  @override
  void initState() {
    super.initState();
    _profileStorageService = ProfileStorageService();
    _loadUserData();
  }

  void _loadUserData() {
    final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = supabaseProvider.user ?? authProvider.user;

    if (user != null) {
      _nameController.text = user.name;
      _phoneController.text = user.phoneNumber ?? '';

      // Debug logging to track phone number loading
      AppLogger.info('📱 ProfileScreen._loadUserData: Loading phone number - phoneNumber: "${user.phoneNumber}", phone: "${user.phone}"');
      AppLogger.info('📱 ProfileScreen._loadUserData: Phone controller set to: "${_phoneController.text}"');
    } else {
      AppLogger.warning('⚠️ ProfileScreen._loadUserData: No user data available');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // استخدام مزود Supabase أولاً
    final supabaseProvider = Provider.of<SupabaseProvider>(context);
    final supabaseUser = supabaseProvider.user;

    // استخدام مزود Auth كإجراء احتياطي
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userModel = supabaseUser ?? authProvider.user;

    if (userModel == null) {
      // Handle case where user is not logged in
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      });
      return Scaffold(
        backgroundColor: AccountantThemeConfig.luxuryBlack,
        body: Center(
          child: CircularProgressIndicator(
            color: AccountantThemeConfig.primaryGreen,
          ),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AccountantThemeConfig.luxuryBlack,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AccountantThemeConfig.mainBackgroundGradient,
        ),
        child: _isLoading
            ? _buildProfessionalLoadingIndicator()
            : _buildProfessionalProfileLayout(userModel),
      ),
      drawer: MainDrawer(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
        currentRoute: AppRoutes.profile,
      ),
    );
  }

  Widget _buildProfessionalLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: AccountantThemeConfig.primaryCardDecoration,
            child: Column(
              children: [
                CircularProgressIndicator(
                  color: AccountantThemeConfig.primaryGreen,
                  strokeWidth: 3,
                ),
                const SizedBox(height: 24),
                Text(
                  'جاري تحميل بيانات الملف الشخصي...',
                  style: AccountantThemeConfig.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionalProfileLayout(UserModel userModel) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Professional Header with SAMA Branding
        _buildProfessionalHeader(),

        // Profile Content
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Profile Image Section
                  _buildProfessionalProfileImage(userModel),

                  const SizedBox(height: 32),

                  // Profile Information Cards
                  _buildProfileInfoCards(userModel),

                  const SizedBox(height: 32),

                  // Action Buttons
                  _buildActionButtons(userModel),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfessionalHeader() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: AccountantThemeConfig.cardGradient,
          borderRadius: BorderRadius.circular(12),
          border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
          boxShadow: AccountantThemeConfig.cardShadows,
        ),
        child: IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.white),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [
              AccountantThemeConfig.primaryGreen,
              AccountantThemeConfig.secondaryGreen,
            ],
          ).createShader(bounds),
          child: Text(
            'SAMA',
            style: GoogleFonts.cairo(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: AccountantThemeConfig.mainBackgroundGradient,
          ),
          child: Center(
            child: Text(
              'الملف الشخصي',
              style: AccountantThemeConfig.headlineLarge.copyWith(
                fontSize: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfessionalProfileImage(UserModel userModel) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AccountantThemeConfig.primaryCardDecoration,
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AccountantThemeConfig.greenGradient,
                  boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 3,
                  ),
                ),
                child: _isUploading
                    ? Container(
                        width: 140,
                        height: 140,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                        ),
                        child: CircularProgressIndicator(
                          color: AccountantThemeConfig.primaryGreen,
                          strokeWidth: 3,
                        ),
                      )
                    : CircleAvatar(
                        radius: 70,
                        backgroundColor: AccountantThemeConfig.primaryGreen.withOpacity(0.1),
                        backgroundImage: _getProfileImage(userModel),
                        child: _getProfileImageWidget(userModel),
                      ),
              ),
              if (_isEditing)
                Container(
                  decoration: BoxDecoration(
                    gradient: AccountantThemeConfig.blueGradient,
                    shape: BoxShape.circle,
                    boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.accentBlue),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 24),
                    onPressed: _pickImage,
                    tooltip: 'تغيير الصورة',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            userModel.name,
            style: AccountantThemeConfig.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.greenGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
            ),
            child: Text(
              _getRoleText(userModel.role),
              style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfoCards(UserModel userModel) {
    return Column(
      children: [
        // Personal Information Card
        _buildInfoCard(
          title: 'المعلومات الشخصية',
          icon: Icons.person_rounded,
          children: [
            _buildProfessionalField(
              label: 'البريد الإلكتروني',
              value: userModel.email,
              icon: Icons.email_rounded,
              isEditable: false,
            ),
            const SizedBox(height: 16),
            _buildProfessionalField(
              label: 'الاسم',
              value: userModel.name,
              icon: Icons.badge_rounded,
              isEditable: _isEditing,
              controller: _nameController,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'الرجاء إدخال الاسم';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildProfessionalField(
              label: 'رقم الهاتف',
              value: userModel.phoneNumber ?? '',
              icon: Icons.phone_rounded,
              isEditable: _isEditing,
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  if (value.length < 10) {
                    return 'رقم الهاتف غير صحيح';
                  }
                }
                return null;
              },
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Account Information Card
        _buildInfoCard(
          title: 'معلومات الحساب',
          icon: Icons.account_circle_rounded,
          children: [
            _buildProfessionalField(
              label: 'الدور',
              value: _getRoleText(userModel.role),
              icon: Icons.work_rounded,
              isEditable: false,
            ),
            const SizedBox(height: 16),
            _buildProfessionalField(
              label: 'تاريخ الإنضمام',
              value: _formatDate(userModel.createdAt),
              icon: Icons.calendar_today_rounded,
              isEditable: false,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AccountantThemeConfig.primaryCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: AccountantThemeConfig.greenGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: AccountantThemeConfig.headlineSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }

  ImageProvider? _getProfileImage(UserModel userModel) {
    if (_imageFile != null) {
      return FileImage(_imageFile!);
    } else if (userModel.profileImage != null &&
        userModel.profileImage!.isNotEmpty) {
      return NetworkImage(userModel.profileImage!);
    }
    return null;
  }

  Widget? _getProfileImageWidget(UserModel userModel) {
    if (_imageFile != null ||
        (userModel.profileImage != null &&
            userModel.profileImage!.isNotEmpty)) {
      return null;
    }
    return Text(
      userModel.name.isNotEmpty ? userModel.name[0].toUpperCase() : 'U',
      style: GoogleFonts.cairo(
        fontSize: 40,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _buildProfessionalField({
    required String label,
    required String value,
    required IconData icon,
    bool isEditable = false,
    TextEditingController? controller,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: TextFormField(
        initialValue: isEditable ? null : value,
        controller: isEditable ? controller : null,
        keyboardType: keyboardType,
        validator: validator,
        enabled: isEditable,
        style: AccountantThemeConfig.bodyLarge,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: AccountantThemeConfig.bodyMedium.copyWith(
            color: Colors.white.withOpacity(0.7),
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
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
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          filled: false,
        ),
      ),
    );
  }

  Widget _buildActionButtons(UserModel userModel) {
    return Column(
      children: [
        if (_isEditing) ...[
          // Save and Cancel buttons when editing
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AccountantThemeConfig.greenGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _saveProfile,
                    icon: const Icon(Icons.save_rounded, color: Colors.white),
                    label: Text(
                      'حفظ التغييرات',
                      style: GoogleFonts.cairo(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AccountantThemeConfig.orangeGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.warningOrange),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Reload user data to reset any unsaved changes
                      _loadUserData();
                      setState(() {
                        _isEditing = false;
                        _imageFile = null;
                      });
                    },
                    icon: const Icon(Icons.cancel_rounded, color: Colors.white),
                    label: Text(
                      'إلغاء',
                      style: GoogleFonts.cairo(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ] else ...[
          // Action buttons when not editing
          _buildActionButton(
            label: 'تعديل الملف الشخصي',
            icon: Icons.edit_rounded,
            gradient: AccountantThemeConfig.blueGradient,
            glowColor: AccountantThemeConfig.accentBlue,
            onPressed: () {
              setState(() {
                _isEditing = true;
              });
            },
          ),

          const SizedBox(height: 16),

          _buildActionButton(
            label: 'تغيير كلمة المرور',
            icon: Icons.lock_rounded,
            gradient: AccountantThemeConfig.greenGradient,
            glowColor: AccountantThemeConfig.primaryGreen,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ChangePasswordScreen(),
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          _buildActionButton(
            label: 'تسجيل الخروج',
            icon: Icons.logout_rounded,
            gradient: LinearGradient(
              colors: [AccountantThemeConfig.dangerRed, AccountantThemeConfig.dangerRed.withOpacity(0.8)],
            ),
            glowColor: AccountantThemeConfig.dangerRed,
            onPressed: _showProfessionalSignOutDialog,
          ),
        ],
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required LinearGradient gradient,
    required Color glowColor,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AccountantThemeConfig.glowShadows(glowColor),
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        label: Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  String _getRoleText(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'مدير';
      case UserRole.owner:
        return 'صاحب عمل';
      case UserRole.client:
        return 'عميل';
      case UserRole.worker:
        return 'عامل';
      case UserRole.accountant:
        return 'محاسب';
      default:
        return 'مستخدم';
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'غير متوفر';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });

        // Show success feedback with professional styling
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم اختيار الصورة بنجاح',
              style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            backgroundColor: AccountantThemeConfig.primaryGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'فشل في اختيار الصورة',
            style: GoogleFonts.cairo(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          backgroundColor: AccountantThemeConfig.dangerRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<String?> _uploadImage(String userId) async {
    if (_imageFile == null) return null;

    try {
      // استخدام خدمة التخزين المحسنة
      final imageUrl = await _profileStorageService.updateProfileImage(
        userId,
        _imageFile!,
      );

      if (imageUrl == null) {
        throw Exception('فشل في رفع الصورة');
      }

      return imageUrl;
    } catch (e) {
      AppLogger.error('Error uploading image: $e');
      throw Exception('فشل في رفع الصورة: $e');
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userModel = supabaseProvider.user ?? authProvider.user;

    if (userModel == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      String? profileImageUrl = userModel.profileImage;

      // Upload new profile image if available
      if (_imageFile != null) {
        setState(() {
          _isUploading = true;
        });

        profileImageUrl = await _uploadImage(userModel.id);

        if (!mounted) return;

        setState(() {
          _isUploading = false;
        });
      }

      // Update user profile
      final phoneNumberValue = _phoneController.text.trim();
      AppLogger.info('📱 ProfileScreen._saveProfile: Updating phone number from "${userModel.phoneNumber}" to "$phoneNumberValue"');

      final updatedUser = userModel.copyWith(
        name: _nameController.text.trim(),
        phoneNumber: phoneNumberValue,
        profileImage: profileImageUrl,
        updatedAt: DateTime.now(),
      );

      AppLogger.info('📱 ProfileScreen._saveProfile: Updated user model - phone: "${updatedUser.phone}", phoneNumber: "${updatedUser.phoneNumber}"');

      // Update through AuthProvider (handles database update)
      await authProvider.updateUserProfile(updatedUser);

      // CRITICAL: Refresh SupabaseProvider to sync UI state
      await supabaseProvider.refreshUserData();

      if (!mounted) return;

      // CRITICAL FIX: Reload user data into controllers after successful update
      // This ensures the UI displays the updated values when switching back to non-editing mode
      _loadUserData();

      setState(() {
        _isLoading = false;
        _isEditing = false;
        _imageFile = null;
      });

      AppLogger.info('✅ ProfileScreen: User profile update completed - UI should now show updated data');

      // Show professional success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'تم تحديث الملف الشخصي بنجاح',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AccountantThemeConfig.primaryGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      // Show professional error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.error_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'حدث خطأ: $error',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AccountantThemeConfig.dangerRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _showProfessionalSignOutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: AccountantThemeConfig.primaryCardDecoration,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AccountantThemeConfig.dangerRed, AccountantThemeConfig.dangerRed.withOpacity(0.8)],
                  ),
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.dangerRed),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),

              const SizedBox(height: 24),

              // Title
              Text(
                'تسجيل الخروج',
                style: AccountantThemeConfig.headlineMedium,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Content
              Text(
                'هل أنت متأكد من رغبتك في تسجيل الخروج من التطبيق؟',
                style: AccountantThemeConfig.bodyLarge.copyWith(
                  color: Colors.white.withOpacity(0.8),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AccountantThemeConfig.orangeGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.warningOrange),
                      ),
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
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
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AccountantThemeConfig.dangerRed, AccountantThemeConfig.dangerRed.withOpacity(0.8)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.dangerRed),
                      ),
                      child: TextButton(
                        onPressed: () async {
                          Navigator.of(context).pop();

                          final authProvider = Provider.of<AuthProvider>(context, listen: false);
                          await authProvider.signOut();

                          if (mounted) {
                            Navigator.of(context).pushReplacementNamed(AppRoutes.login);
                          }
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'تسجيل الخروج',
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
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
    );
  }

}
