import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/config/routes.dart';
import 'package:smartbiztracker_new/models/user_model.dart';
import 'package:smartbiztracker_new/providers/auth_provider.dart';
import 'package:smartbiztracker_new/widgets/common/custom_app_bar.dart';
import 'package:smartbiztracker_new/widgets/common/main_drawer.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smartbiztracker_new/utils/color_extension.dart';
import 'package:smartbiztracker_new/models/user_role.dart';
import 'package:intl/intl.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

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

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user != null) {
      _nameController.text = user.name;
      _phoneController.text = user.phoneNumber;
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
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final userModel = authProvider.user;

    if (userModel == null) {
      // Handle case where user is not logged in
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      });
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: CustomAppBar(
          title: 'الملف الشخصي',
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
        ),
      ),
      drawer: MainDrawer(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
        currentRoute: AppRoutes.profile,
      ),
      body: _isLoading
          ? _buildLoadingIndicator()
          : _buildProfileForm(theme, userModel),
      floatingActionButton: _isEditing
          ? FloatingActionButton(
              onPressed: _saveProfile,
              child: const Icon(Icons.save),
            )
          : FloatingActionButton(
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
              child: const Icon(Icons.edit),
            ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/animations/loading.json',
            width: 200,
            height: 200,
          ),
          const SizedBox(height: 16),
          const Text('جاري تحميل بيانات الملف الشخصي...'),
        ],
      ),
    );
  }

  Widget _buildProfileForm(ThemeData theme, UserModel userModel) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Hero(
              tag: 'user_profile_pic',
              child: _buildProfileImage(theme, userModel),
            ),
            const SizedBox(height: 32),

            // Email (Read-only)
            _buildProfileField(
              label: 'البريد الإلكتروني',
              value: userModel.email,
              isEditable: false,
            ),
            const SizedBox(height: 20),

            // Name
            _buildProfileField(
              label: 'الاسم',
              value: userModel.name,
              isEditable: _isEditing,
              controller: _nameController,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'الرجاء إدخال الاسم';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Phone Number
            _buildProfileField(
              label: 'رقم الهاتف',
              value: userModel.phoneNumber,
              isEditable: _isEditing,
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  // Simple phone validation
                  if (value.length < 10) {
                    return 'رقم الهاتف غير صحيح';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Role (Read-only)
            _buildProfileField(
              label: 'الدور',
              value: _getRoleText(userModel.role),
              isEditable: false,
            ),
            const SizedBox(height: 20),

            // Created At (Read-only)
            _buildProfileField(
              label: 'تاريخ الإنضمام',
              value: _formatDate(userModel.createdAt),
              isEditable: false,
            ),
            TextFormField(
              initialValue: _getRoleText(userModel.role),
              readOnly: true,
              enabled: false,
              decoration: InputDecoration(
                labelText: 'الدور',
                prefixIcon: const Icon(Icons.badge),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                fillColor: theme.colorScheme.surface,
                filled: true,
              ),
            ),
            const SizedBox(height: 20),

            // Created At (Read-only)
            TextFormField(
              initialValue: _formatDate(userModel.createdAt),
              readOnly: true,
              enabled: false,
              decoration: InputDecoration(
                labelText: 'تاريخ الإنضمام',
                prefixIcon: const Icon(Icons.date_range),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                fillColor: theme.colorScheme.surface,
                filled: true,
              ),
            ),
            const SizedBox(height: 32),

            // Only show when not editing
            if (!_isEditing)
              ElevatedButton.icon(
                onPressed: () {
                  // Handle sign out
                  _showSignOutDialog();
                },
                icon: const Icon(Icons.logout),
                label: const Text('تسجيل الخروج'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade800,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

            // Cancel button when editing
            if (_isEditing)
              TextButton(
                onPressed: () {
                  setState(() {
                    _isEditing = false;
                    _imageFile = null;

                    // Reset to original values
                    _nameController.text = userModel.name;
                    _phoneController.text = userModel.phoneNumber;
                  });
                },
                child: const Text('إلغاء'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileImage(ThemeData theme, UserModel userModel) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: theme.colorScheme.primary,
              width: 3,
            ),
          ),
          child: _isUploading
              ? Container(
                  width: 120,
                  height: 120,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                  ),
                  child: const CircularProgressIndicator(),
                )
              : CircleAvatar(
                  radius: 60,
                  backgroundColor: theme.colorScheme.primary.safeOpacity(0.1),
                  backgroundImage: _getProfileImage(userModel),
                  child: _getProfileImageWidget(userModel),
                ),
        ),
        if (_isEditing)
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.camera_alt, color: Colors.white),
              onPressed: _pickImage,
            ),
          ),
      ],
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
      style: const TextStyle(
        fontSize: 40,
        fontWeight: FontWeight.bold,
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

  Widget _buildProfileField({
    required String label,
    required String value,
    bool isEditable = false,
    TextEditingController? controller,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        initialValue: isEditable ? null : value,
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          enabled: isEditable,
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      AppLogger.error('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل في اختيار الصورة')),
      );
    }
  }

  Future<String?> _uploadImage() async {
    if (_imageFile == null) return null;

    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}${_imageFile!.path.split('.').last}';
      final filePath = 'profile_images/$fileName';

      await _supabase.storage.from('public').upload(
        filePath,
        _imageFile!,
        fileOptions: const FileOptions(cacheControl: '3600'),
      );

      return _supabase.storage.from('public').getPublicUrl(filePath);
    } catch (e) {
      AppLogger.error('Error uploading image: $e');
      throw Exception('فشل في رفع الصورة');
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userModel = authProvider.user;

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

        profileImageUrl = await _uploadImage();

        if (!mounted) return;

        setState(() {
          _isUploading = false;
        });
      }

      // Update user profile
      final updatedUser = userModel.copyWith(
        name: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        profileImage: profileImageUrl,
        updatedAt: DateTime.now(),
      );

      await authProvider.updateUserProfile(updatedUser);

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isEditing = false;
        _imageFile = null;
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديث الملف الشخصي بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد من رغبتك في تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();

              final authProvider =
                  Provider.of<AuthProvider>(context, listen: false);
              await authProvider.signOut();

              if (mounted) {
                Navigator.of(context).pushReplacementNamed(AppRoutes.login);
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
  }

  void _navigateBack() {
    FocusScope.of(context).unfocus();
    
    Navigator.of(context).pop();
  }
}
