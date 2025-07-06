import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/supabase_provider.dart';
import '../../widgets/custom_button.dart';
import '../../utils/app_logger.dart';
import '../../utils/accountant_theme_config.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    required String? Function(String?) validator,
    required IconData prefixIcon,
  }) {
    return Container(
      decoration: AccountantThemeConfig.primaryCardDecoration.copyWith(
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue.withOpacity(0.3)),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        textDirection: TextDirection.rtl,
        style: AccountantThemeConfig.bodyLarge.copyWith(
          color: Colors.white,
        ),
        decoration: InputDecoration(
          labelText: label,
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
              gradient: AccountantThemeConfig.blueGradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              prefixIcon,
              color: Colors.white,
              size: 20,
            ),
          ),
          suffixIcon: IconButton(
            icon: Icon(
              obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              color: Colors.white70,
            ),
            onPressed: onToggleVisibility,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          filled: true,
          fillColor: AccountantThemeConfig.cardBackground1,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: AccountantThemeConfig.accentBlue.withOpacity(0.3),
              width: 1,
            ),
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
          errorStyle: AccountantThemeConfig.bodySmall.copyWith(
            color: AccountantThemeConfig.dangerRed,
          ),
        ),
        validator: validator,
      ),
    );
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);

      // تحديث كلمة المرور
      final success = await supabaseProvider.updatePassword(_newPasswordController.text);

      if (success && mounted) {
        // عرض رسالة نجاح
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Container(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'تم تحديث كلمة المرور بنجاح',
                      style: AccountantThemeConfig.bodyMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            backgroundColor: AccountantThemeConfig.primaryGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );

        // العودة للشاشة السابقة
        Navigator.of(context).pop();
      } else if (mounted) {
        setState(() {
          _errorMessage = supabaseProvider.error ?? 'فشل في تغيير كلمة المرور';
        });
      }
    } catch (e) {
      AppLogger.error('Error changing password: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'حدث خطأ أثناء تغيير كلمة المرور';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AccountantThemeConfig.luxuryBlack,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AccountantThemeConfig.mainBackgroundGradient,
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              // Custom App Bar
              SliverAppBar(
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
                    border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: true,
                  title: Text(
                    'تغيير كلمة المرور',
                    style: AccountantThemeConfig.headlineSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: AccountantThemeConfig.mainBackgroundGradient,
                    ),
                  ),
                ),
              ),

              // Main Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header Card
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: AccountantThemeConfig.primaryCardDecoration.copyWith(
                            border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
                            boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: AccountantThemeConfig.greenGradient,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(
                                  Icons.lock_reset_rounded,
                                  size: 40,
                                  color: Colors.white,
                                ),
                              ).animate().scale(delay: 200.ms),

                              const SizedBox(height: 16),

                              Text(
                                'تحديث كلمة المرور',
                                style: AccountantThemeConfig.headlineMedium.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ).animate().fadeIn(delay: 300.ms),

                              const SizedBox(height: 8),

                              Text(
                                'أدخل كلمة المرور الحالية والجديدة لتحديث حسابك',
                                style: AccountantThemeConfig.bodyMedium.copyWith(
                                  color: Colors.white70,
                                ),
                                textAlign: TextAlign.center,
                              ).animate().fadeIn(delay: 400.ms),
                            ],
                          ),
                        ).animate().slideY(begin: 0.3, delay: 100.ms),

                        const SizedBox(height: 32),

                // كلمة المرور الحالية
                _buildPasswordField(
                  label: 'كلمة المرور الحالية',
                  controller: _currentPasswordController,
                  obscureText: _obscureCurrentPassword,
                  onToggleVisibility: () {
                    setState(() {
                      _obscureCurrentPassword = !_obscureCurrentPassword;
                    });
                  },
                  prefixIcon: Icons.lock_outline,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'يرجى إدخال كلمة المرور الحالية';
                    }
                    return null;
                  },
                ).animate().slideX(begin: 0.3, delay: 500.ms),

                const SizedBox(height: 24),

                // كلمة المرور الجديدة
                _buildPasswordField(
                  label: 'كلمة المرور الجديدة',
                  controller: _newPasswordController,
                  obscureText: _obscureNewPassword,
                  onToggleVisibility: () {
                    setState(() {
                      _obscureNewPassword = !_obscureNewPassword;
                    });
                  },
                  prefixIcon: Icons.lock_reset,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'يرجى إدخال كلمة المرور الجديدة';
                    }
                    if (value.length < 6) {
                      return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                    }
                    return null;
                  },
                ).animate().slideX(begin: 0.3, delay: 600.ms),

                const SizedBox(height: 24),

                // تأكيد كلمة المرور الجديدة
                _buildPasswordField(
                  label: 'تأكيد كلمة المرور الجديدة',
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  onToggleVisibility: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                  prefixIcon: Icons.check_circle_outline,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'يرجى تأكيد كلمة المرور الجديدة';
                    }
                    if (value != _newPasswordController.text) {
                      return 'كلمة المرور غير متطابقة';
                    }
                    return null;
                  },
                ).animate().slideX(begin: 0.3, delay: 700.ms),

                const SizedBox(height: 32),

                // رسالة الخطأ
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      gradient: AccountantThemeConfig.redGradient,
                      borderRadius: BorderRadius.circular(16),
                      border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.dangerRed),
                      boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.dangerRed),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.error_outline,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: AccountantThemeConfig.bodyMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ).animate().shake(delay: 800.ms),

                // زر تغيير كلمة المرور
                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: _isLoading
                        ? AccountantThemeConfig.cardGradient
                        : AccountantThemeConfig.greenGradient,
                    borderRadius: BorderRadius.circular(16),
                    border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
                    boxShadow: _isLoading
                        ? AccountantThemeConfig.cardShadows
                        : AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _changePassword,
                    icon: _isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                            ),
                          )
                        : const Icon(Icons.security_update_good, color: Colors.white),
                    label: Text(
                      _isLoading ? 'جاري التحديث...' : 'تحديث كلمة المرور',
                      style: AccountantThemeConfig.bodyLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ).animate().slideY(begin: 0.3, delay: 800.ms),

                const SizedBox(height: 16),

                // زر الإلغاء
                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white30,
                      width: 1,
                    ),
                  ),
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white70),
                    label: Text(
                      'إلغاء',
                      style: AccountantThemeConfig.bodyLarge.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 900.ms),

                const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
