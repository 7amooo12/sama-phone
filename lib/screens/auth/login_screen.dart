import 'package:flutter/material.dart';
import 'dart:async';
import 'package:smartbiztracker_new/config/routes.dart';
import 'package:smartbiztracker_new/models/models.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartbiztracker_new/screens/auth/register_screen.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:smartbiztracker_new/widgets/common/loading_overlay.dart';
import 'package:smartbiztracker_new/services/email_confirmation_service.dart';
import 'package:smartbiztracker_new/services/supabase_service.dart';
import 'package:smartbiztracker_new/screens/auth/waiting_approval_screen.dart';
import 'package:smartbiztracker_new/widgets/effects/animated_background.dart';
import 'package:smartbiztracker_new/widgets/effects/animated_login_card.dart';
import 'package:smartbiztracker_new/widgets/forms/animated_input_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _logoController;
  late Animation<double> _logoAnimation;
  String? _errorMessage;
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isBiometricAvailable = false;
  bool _rememberMe = false;
  bool _isInitializing = true;
  String? _lastEmail;
  bool _showQuickLogin = false;

  // Focus nodes for interactivity
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
    _checkBiometricAvailability();
    _loadSavedCredentials();

    // Add performance monitoring
    AppLogger.info('🚀 Login screen initialized - lightweight version');
  }

  void _initializeAnimation() {
    // Single lightweight fade animation
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    // Logo animation controller
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _logoAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOut,
    ));

    // Start animations
    _fadeController.forward();
    _logoController.forward();
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();

      if (mounted) {
        setState(() {
          _isBiometricAvailable = canCheckBiometrics && isDeviceSupported;
        });

        if (_isBiometricAvailable) {
          final availableBiometrics = await _localAuth.getAvailableBiometrics();

          // Check if fingerprint or face authentication is available (iOS uses face or fingerprint)
          final hasBiometrics = availableBiometrics.contains(BiometricType.fingerprint) ||
                               availableBiometrics.contains(BiometricType.face) ||
                               availableBiometrics.contains(BiometricType.strong) ||
                               availableBiometrics.contains(BiometricType.weak);

          // Update the state if no biometrics are available
          if (!hasBiometrics && mounted) {
            setState(() {
              _isBiometricAvailable = false;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isBiometricAvailable = false;
        });
      }
    }
  }



  Future<void> _loadSavedCredentials() async {
    setState(() => _isInitializing = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('saved_email');
      final hasPassword = prefs.getBool('has_saved_password') ?? false;

      if (savedEmail != null && savedEmail.isNotEmpty) {
        setState(() {
          _emailController.text = savedEmail;
          _lastEmail = savedEmail;
          _showQuickLogin = hasPassword;
          _rememberMe = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading saved credentials: $e');
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  Future<void> _saveCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_email', _emailController.text);
      await prefs.setBool('has_saved_password', true);
      await prefs.setBool('remember_me', true);
    } catch (e) {
      debugPrint('Error saving credentials: $e');
    }
  }

  Future<bool> _authenticateWithBiometrics() async {
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'قم بالمصادقة للدخول إلى حسابك',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      return authenticated;
    } catch (e) {
      // Show more specific error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في المصادقة البيومترية: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    _logoController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<SupabaseProvider>(context, listen: false);

      AppLogger.info('🔄 LoginScreen: Starting login process for: ${_emailController.text.trim()}');

      final success = await authProvider.signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );

      AppLogger.info('📋 LoginScreen: Sign-in result: $success');

      if (!success) {
        if (!mounted) return;

        // Get specific error message from provider
        final errorMessage = authProvider.error ?? 'فشل تسجيل الدخول. تحقق من بياناتك وحاول مرة أخرى.';
        AppLogger.error('❌ LoginScreen: Sign-in failed with error: $errorMessage');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final user = authProvider.user;
      AppLogger.info('👤 LoginScreen: User object after sign-in: ${user != null ? '${user.email} (${user.role})' : 'null'}');

      if (user == null) {
        if (!mounted) return;

        final errorMessage = authProvider.error ?? 'حدث خطأ أثناء تسجيل الدخول - لم يتم العثور على بيانات المستخدم';
        AppLogger.error('❌ LoginScreen: User is null after successful sign-in. Error: $errorMessage');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // فحص حالة الموافقة - الأدمن دائماً موافق عليه
      if (!user.isApproved && !user.isAdmin()) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/waiting-approval');
        return;
      }

      // Save credentials if remember me is checked
      if (_rememberMe) {
        await _saveCredentials();
      }

      if (!mounted) return;

      // Navigate based on user role - clear all previous routes
      String routeName;
      switch (user.role) {
        case UserRole.admin:
          routeName = AppRoutes.adminDashboard;
          break;
        case UserRole.owner:
          routeName = '/owner/dashboard';
          break;
        case UserRole.worker:
          routeName = '/worker/dashboard';
          break;
        case UserRole.accountant:
          routeName = '/accountant/dashboard';
          break;
        case UserRole.warehouseManager:
          routeName = AppRoutes.warehouseManagerDashboard;
          break;
        case UserRole.client:
          routeName = '/client/dashboard';
          break;
        default:
          routeName = '/menu';
      }

      AppLogger.info('🚀 LoginScreen: Navigating to $routeName for user role: ${user.role}');

      Navigator.pushNamedAndRemoveUntil(
        context,
        routeName,
        (route) => false, // Remove all previous routes
      );

      AppLogger.info('✅ LoginScreen: Navigation completed successfully');
    } catch (e) {
      AppLogger.error('Login error: $e');
      if (!mounted) return;

      // فحص ما إذا كان المستخدم في انتظار الموافقة
      if (e is PendingApprovalException) {
        _navigateToWaitingApproval();
        return;
      }

      // فحص ما إذا كانت المشكلة متعلقة بتأكيد البريد الإلكتروني
      if (e.toString().contains('Email not confirmed') ||
          e.toString().contains('لم يتم تأكيد البريد الإلكتروني')) {
        _showEmailConfirmationDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleBiometricLogin() async {
    if (_lastEmail == null || _lastEmail!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب تسجيل الدخول أولاً باستخدام كلمة المرور'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final authenticated = await _authenticateWithBiometrics();
    if (!authenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('فشلت المصادقة البيومترية'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Set the email from saved credentials
    _emailController.text = _lastEmail!;

    // Use the new biometric login method instead of regular login
    final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
    try {
      final success = await supabaseProvider.signInWithBiometric(_lastEmail!);

      if (success && mounted) {
        // Get the user role after successful login
        final userRole = supabaseProvider.user?.role;

        // Navigate to appropriate dashboard based on user role
        String routeName;
        switch (userRole) {
          case UserRole.admin:
            routeName = AppRoutes.adminDashboard;
            break;
          case UserRole.owner:
            routeName = AppRoutes.ownerDashboard;
            break;
          case UserRole.worker:
            routeName = AppRoutes.workerDashboard;
            break;
          case UserRole.accountant:
            routeName = AppRoutes.accountantDashboard;
            break;
          case UserRole.warehouseManager:
            routeName = AppRoutes.warehouseManagerDashboard;
            break;
          case UserRole.client:
          default:
            routeName = AppRoutes.clientDashboard;
            break;
        }

        // Navigate to the appropriate dashboard
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            routeName,
            (route) => false,
          );
        }
      } else if (mounted) {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(supabaseProvider.error ?? 'فشل تسجيل الدخول باستخدام البصمة'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء تسجيل الدخول بالبصمة: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// التنقل إلى شاشة انتظار الموافقة
  void _navigateToWaitingApproval() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => WaitingApprovalScreen(
          email: _emailController.text.trim(),
        ),
      ),
    );
  }

  /// عرض حوار تأكيد البريد الإلكتروني
  void _showEmailConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.email, color: Colors.orange),
            SizedBox(width: 8),
            Text('تأكيد البريد الإلكتروني'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'حسابك موافق عليه من الإدارة لكن يحتاج لتأكيد البريد الإلكتروني.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Text(
              'البريد الإلكتروني: ${_emailController.text}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'يمكنك:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('• إعادة إرسال بريد التأكيد'),
            const Text('• التواصل مع الإدارة لتفعيل الحساب يدوياً'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _resendConfirmationEmail();
            },
            child: const Text('إعادة إرسال'),
          ),
        ],
      ),
    );
  }

  /// إعادة إرسال بريد التأكيد
  Future<void> _resendConfirmationEmail() async {
    try {
      final success = await EmailConfirmationService.resendConfirmationEmail(
        _emailController.text.trim(),
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إعادة إرسال بريد التأكيد بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل في إعادة إرسال بريد التأكيد'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final supabaseProvider = Provider.of<SupabaseProvider>(context);
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;

    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        body: AnimatedBackground(
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: AnimatedLoginCard(
                  maxWidth: screenSize.width > 600 ? 400 : screenSize.width - 32,
                  maxHeight: screenSize.height * 0.9,
                  child: _buildLoginContent(supabaseProvider),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginContent(SupabaseProvider supabaseProvider) {
    return Padding(
      padding: const EdgeInsets.all(24.0), // Reduced padding to save space
      child: Form(
        key: _formKey,
        child: SingleChildScrollView( // Added scroll view to prevent overflow
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo container with gradient border and inner lighting
              _buildAnimatedLogo(),

              const SizedBox(height: 24), // Reduced spacing

              // Title with gradient text
              _buildGradientTitle(),

              const SizedBox(height: 6), // Reduced spacing

              // Subtitle
              _buildSubtitle(),

              const SizedBox(height: 24), // Reduced spacing

              // Email input field
              AnimatedInputField(
                controller: _emailController,
                focusNode: _emailFocusNode,
                labelText: 'البريد الإلكتروني',
                hintText: 'أدخل بريدك الإلكتروني',
                prefixIcon: Icons.email,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'البريد الإلكتروني مطلوب';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                    return 'البريد الإلكتروني غير صحيح';
                  }
                  return null;
                },
              ),

              // Password input field
              AnimatedInputField(
                controller: _passwordController,
                focusNode: _passwordFocusNode,
                labelText: 'كلمة المرور',
                hintText: 'أدخل كلمة المرور',
                prefixIcon: Icons.lock,
                obscureText: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.white.withOpacity(0.6),
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'كلمة المرور مطلوبة';
                  }
                  if (value.length < 6) {
                    return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16), // Reduced spacing

              // Remember me checkbox
              _buildRememberMeCheckbox(),

              const SizedBox(height: 20), // Reduced spacing

              // Submit button
              AnimatedSubmitButton(
                text: 'تسجيل الدخول',
                isLoading: _isLoading,
                onPressed: _login,
              ),

              const SizedBox(height: 16), // Reduced spacing

              // Biometric login option
              if (_isBiometricAvailable) _buildBiometricButton(),

              const SizedBox(height: 16), // Reduced spacing

              // Register link
              _buildRegisterLink(),

              const SizedBox(height: 16), // Bottom padding for scroll
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedLogo() {
    return AnimatedBuilder(
      animation: _logoController,
      builder: (context, child) {
        return Transform.scale(
          scale: _logoAnimation.value,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Colors.purple.shade400,
                  Colors.purple.shade600,
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(
              Icons.store,
              color: Colors.white,
              size: 30,
            ),
          ),
        );
      },
    );
  }

  Widget _buildGradientTitle() {
    return ShaderMask(
      shaderCallback: (bounds) {
        return LinearGradient(
          colors: [
            Colors.white,
            Colors.purple.shade200,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(bounds);
      },
      child: const Text(
        'مرحباً', // Updated from 'مرحباً بعودتك' to just 'مرحباً'
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          fontFamily: 'Cairo',
          color: Colors.white,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildSubtitle() {
    return Text(
      'سجل دخولك للمتابعة إلى متجر سما',
      style: TextStyle(
        fontSize: 16,
        color: Colors.white.withValues(alpha: 0.6),
        fontFamily: 'Cairo',
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildRememberMeCheckbox() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _rememberMe = !_rememberMe;
        });
      },
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: _rememberMe
                  ? Colors.purple.shade600
                  : Colors.transparent,
              border: Border.all(
                color: Colors.purple.shade400,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: _rememberMe
                ? const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 16,
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Text(
            'تذكرني',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBiometricButton() {
    return Center(
      child: GestureDetector(
        onTap: _handleBiometricLogin,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.purple.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.purple.shade400,
              width: 2,
            ),
          ),
          child: Icon(
            Icons.fingerprint,
            color: Colors.purple.shade300,
            size: 30,
          ),
        ),
      ),
    );
  }



  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'ليس لديك حساب؟ ',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 14,
            fontFamily: 'Cairo',
          ),
        ),
        GestureDetector(
          onTap: () {
            Navigator.pushNamed(context, '/register');
          },
          child: Text(
            'إنشاء حساب جديد',
            style: TextStyle(
              color: Colors.purple.shade300,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFamily: 'Cairo',
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }


}
