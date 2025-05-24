import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import 'package:smartbiztracker_new/config/constants.dart';
import 'package:smartbiztracker_new/config/routes.dart';
import 'package:smartbiztracker_new/models/models.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:smartbiztracker_new/utils/animated_route.dart';
import 'package:smartbiztracker_new/widgets/common/animated_widgets.dart';
import 'package:smartbiztracker_new/utils/responsive_builder.dart';
import 'package:smartbiztracker_new/utils/style_system.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartbiztracker_new/screens/auth/forgot_password_screen.dart';
import 'package:smartbiztracker_new/screens/auth/register_screen.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:smartbiztracker_new/widgets/common/loading_overlay.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  late AnimationController _animationController;
  String? _errorMessage;
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isBiometricAvailable = false;
  bool _rememberMe = false;
  bool _isInitializing = true;
  String? _lastEmail;
  bool _showQuickLogin = false;
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final List<String> _backgroundImages = [
    'assets/images/login_bg1.jpg',
    'assets/images/login_bg2.jpg',
    'assets/images/login_bg3.jpg',
  ];
  
  // Focus nodes for interactivity
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animationController.forward();
    _checkBiometricAvailability();
    _loadSavedCredentials();
    
    // Auto-advance background images
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        _startBackgroundSlideshow();
      }
    });
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

  void _startBackgroundSlideshow() {
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted && _pageController.hasClients) {
        final nextPage = (_currentPage + 1) % _backgroundImages.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(seconds: 1),
          curve: Curves.easeInOut,
        );
        _startBackgroundSlideshow();
      }
    });
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
    _animationController.dispose();
    _pageController.dispose();
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
      final success = await authProvider.signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (!success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل تسجيل الدخول. تحقق من بياناتك وحاول مرة أخرى.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final user = authProvider.user;
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حدث خطأ أثناء تسجيل الدخول'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (!user.isApproved) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/waiting-approval');
        return;
      }

      if (!mounted) return;
      
      // Navigate based on user role
      switch (user.role) {
        case UserRole.admin:
          Navigator.pushReplacementNamed(context, AppRoutes.adminDashboard);
          break;
        case UserRole.owner:
          Navigator.pushReplacementNamed(context, '/owner/dashboard');
          break;
        case UserRole.worker:
          Navigator.pushReplacementNamed(context, '/worker/dashboard');
          break;
        case UserRole.accountant:
          Navigator.pushReplacementNamed(context, '/accountant/dashboard');
          break;
        case UserRole.client:
          Navigator.pushReplacementNamed(context, '/client/dashboard');
          break;
        default:
          Navigator.pushReplacementNamed(context, '/menu');
      }
    } catch (e) {
      AppLogger.error('Login error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    final supabaseProvider = Provider.of<SupabaseProvider>(context);
    final theme = Theme.of(context);

    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        body: ResponsiveBuilder(
          builder: (context, sizeInfo) {
            // اختيار تخطيط متجاوب حسب حجم الشاشة واتجاهها
            final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
            
            return Stack(
              children: [
                // Animated Background
                Positioned.fill(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) => setState(() => _currentPage = index),
                    itemCount: _backgroundImages.length,
                    itemBuilder: (context, index) {
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          // Background Image or Gradient
                          _backgroundImages.isNotEmpty
                              ? Image.asset(
                                  _backgroundImages[index],
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: StyleSystem.elegantGradient,
                                      ),
                                    ),
                                  ),
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: StyleSystem.elegantGradient,
                                    ),
                                  ),
                                ),
                          // Overlay with gradient for better text readability
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withOpacity(0.6),
                                  Colors.black.withOpacity(0.8),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                
                // Page Indicator
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _backgroundImages.length,
                      (index) => Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentPage == index
                              ? StyleSystem.primaryColor
                              : Colors.white.withOpacity(0.4),
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Main Content
                SafeArea(
                  child: isLandscape 
                    ? _buildLandscapeLayout(supabaseProvider, theme, sizeInfo)
                    : _buildPortraitLayout(supabaseProvider, theme, sizeInfo),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
  
  Widget _buildPortraitLayout(SupabaseProvider supabaseProvider, ThemeData theme, ScreenSizeInfo sizeInfo) {
    return SingleChildScrollView(
      child: Container(
        height: sizeInfo.screenSize.height -
            MediaQuery.of(context).padding.top -
            MediaQuery.of(context).padding.bottom,
        padding: EdgeInsets.all(sizeInfo.isMobile ? 20 : 32),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: sizeInfo.isMobile ? double.infinity : 500,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Logo
                AnimatedAppear(
                  offset: const Offset(0, -30),
                  child: PulseAnimation(
                    duration: const Duration(milliseconds: 2000),
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(50),
                        boxShadow: StyleSystem.shadowLarge,
                      ),
                      padding: const EdgeInsets.all(15),
                      child: Image.asset(
                        'assets/icons/app_logo.png',
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.business,
                            size: 50,
                            color: StyleSystem.primaryColor,
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Title
                AnimatedAppear(
                  offset: const Offset(0, -30),
                  delay: const Duration(milliseconds: 200),
                  child: Column(
                    children: [
                      Text(
                        'SAMA',
                        style: StyleSystem.displayMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'تسجيل الدخول للوصول إلى حسابك',
                        style: StyleSystem.titleMedium.copyWith(
                          color: Colors.white.withAlpha(230),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Show quick login or login form
                if (_showQuickLogin && _isBiometricAvailable && !_isInitializing)
                  _buildQuickLoginSection()
                else
                  Expanded(
                    child: _buildLoginForm(supabaseProvider, theme),
                  ),
                
                // Additional options (Register)
                if (!_showQuickLogin || !_isBiometricAvailable || _isInitializing)
                  Column(
                    children: [
                      _buildRegisterLink(theme),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildLandscapeLayout(SupabaseProvider supabaseProvider, ThemeData theme, ScreenSizeInfo sizeInfo) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(sizeInfo.isMobile ? 20 : 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 900,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Logo and Title Section (Left side on landscape)
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // App Logo
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(50),
                          boxShadow: StyleSystem.shadowLarge,
                        ),
                        padding: const EdgeInsets.all(15),
                        child: Image.asset(
                          'assets/icons/app_logo.png',
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.business,
                              size: 50,
                              color: StyleSystem.primaryColor,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      Text(
                        'SAMA',
                        style: StyleSystem.displayMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'تسجيل الدخول للوصول إلى حسابك',
                        style: StyleSystem.titleMedium.copyWith(
                          color: Colors.white.withAlpha(230),
                        ),
                      ),
                      
                      if (_showQuickLogin && _isBiometricAvailable && !_isInitializing)
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: _buildQuickLoginSection(),
                        ),
                    ],
                  ),
                ),
                
                // Form Section (Right side on landscape)
                if (!_showQuickLogin || !_isBiometricAvailable || _isInitializing)
                  Expanded(
                    flex: 3,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Login Form
                          _buildLoginForm(supabaseProvider, theme),
                          const SizedBox(height: 16),
                          
                          // Additional options
                          _buildRegisterLink(theme),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildQuickLoginSection() {
    return AnimatedAppear(
      delay: const Duration(milliseconds: 350),
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: StyleSystem.primaryColor.withOpacity(0.2),
              blurRadius: 15,
              spreadRadius: -5,
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              'مرحباً بعودتك',
              style: StyleSystem.titleMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'تسجيل دخول سريع كـ $_lastEmail',
              style: StyleSystem.bodyMedium.copyWith(
                color: Colors.white.withOpacity(0.9),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // زر تسجيل الدخول بالبصمة
                InkWell(
                  onTap: _handleBiometricLogin,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: StyleSystem.primaryColor.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(35),
                      boxShadow: [
                        BoxShadow(
                          color: StyleSystem.primaryColor.withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: -2,
                        ),
                      ],
                    ),
                    child: Icon(
                      // رمز مختلف بناءً على نوع البصمة المتاحة
                      Theme.of(context).platform == TargetPlatform.iOS
                          ? Icons.face // Face ID لنظام iOS
                          : Icons.fingerprint, // بصمة الإصبع لنظام Android
                      color: Colors.white,
                      size: 35,
                    ),
                  ).animate(onPlay: (controller) {
                    controller.repeat(reverse: true);
                  })
                    .shimmer(
                      duration: 2.seconds, 
                      color: Colors.white,
                    ),
                ),
                const SizedBox(width: 20),
                // زر تسجيل الدخول كمستخدم آخر
                InkWell(
                  onTap: () {
                    setState(() {
                      _showQuickLogin = false;
                    });
                  },
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(35),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.person_add,
                      color: Colors.white,
                      size: 35,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'تسجيل بالبصمة',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 40),
                const Text(
                  'مستخدم آخر',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginForm(SupabaseProvider supabaseProvider, ThemeData theme) {
    return AnimatedAppear(
      delay: const Duration(milliseconds: 400),
      offset: const Offset(0, 50),
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          // Add shake animation on error
          return Transform.translate(
            offset: Offset(
              sin(_animationController.value * 10 * 3.14159) * 10,
              0,
            ),
            child: child,
          );
        },
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(16),
            boxShadow: StyleSystem.shadowMedium,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تسجيل الدخول',
                  style: StyleSystem.headlineMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: StyleSystem.primaryColor,
                  ),
                ),
                const SizedBox(height: 20),

                // Email
                TextFormField(
                  controller: _emailController,
                  focusNode: _emailFocusNode,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(color: Colors.black87),
                  decoration: InputDecoration(
                    labelText: 'البريد الإلكتروني',
                    labelStyle: const TextStyle(color: Colors.black54),
                    prefixIcon: Icon(
                      Icons.email_outlined,
                      color: StyleSystem.primaryColor,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: StyleSystem.primaryColor, width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return AppConstants.validationRequiredField;
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                      return AppConstants.validationInvalidEmail;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: _passwordController,
                  focusNode: _passwordFocusNode,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  style: const TextStyle(color: Colors.black87),
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور',
                    labelStyle: const TextStyle(color: Colors.black54),
                    prefixIcon: Icon(
                      Icons.lock_outline,
                      color: StyleSystem.primaryColor,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: StyleSystem.neutralMedium,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: StyleSystem.primaryColor, width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return AppConstants.validationRequiredField;
                    }
                    if (value.length < 6) {
                      return AppConstants.validationPasswordLength;
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _login(),
                ),
                
                const SizedBox(height: 4),
                
                // Remember me checkbox & Forgot Password
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: _rememberMe,
                          onChanged: (value) {
                            setState(() {
                              _rememberMe = value ?? false;
                            });
                          },
                          activeColor: StyleSystem.primaryColor,
                        ),
                        Text(
                          'تذكرني',
                          style: StyleSystem.bodySmall,
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          AnimatedRoute(
                            page: const ForgotPasswordScreen(),
                            type: PageTransitionType.rightToLeftWithFade,
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: StyleSystem.primaryColor,
                      ),
                      child: const Text('نسيت كلمة المرور؟'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Login Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: supabaseProvider.isLoading ? null : _login,
                    style: StyleSystem.primaryButtonStyle.copyWith(
                      backgroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                        if (states.contains(MaterialState.disabled)) {
                          return StyleSystem.primaryColor.withOpacity(0.5);
                        }
                        return StyleSystem.primaryColor;
                      }),
                      elevation: MaterialStateProperty.resolveWith<double>((states) {
                        if (states.contains(MaterialState.disabled)) return 0;
                        if (states.contains(MaterialState.pressed)) return 0;
                        return 3; // Higher elevation for better visual appeal
                      }),
                    ),
                    child: supabaseProvider.isLoading
                        ? const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            strokeWidth: 3,
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.login, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'تسجيل الدخول',
                                style: StyleSystem.titleMedium.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ).animate()
                  .fadeIn(duration: const Duration(milliseconds: 300))
                  .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1)),
                
                // Or divider
                if (_isBiometricAvailable)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: Colors.grey.withOpacity(0.5),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'أو',
                            style: StyleSystem.bodySmall.copyWith(
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: Colors.grey.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // Biometric login option
                if (_isBiometricAvailable)
                  Center(
                    child: TextButton.icon(
                      onPressed: _handleBiometricLogin,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('تسجيل الدخول باستخدام البصمة'),
                      style: TextButton.styleFrom(
                        foregroundColor: StyleSystem.secondaryColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterLink(ThemeData theme) {
    return AnimatedAppear(
      delay: const Duration(milliseconds: 500),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'ليس لديك حساب؟',
            style: StyleSystem.bodyMedium.copyWith(
              color: Colors.white,
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const RegisterScreen(),
                ),
              );
            },
            child: Text(
              'إنشاء حساب',
              style: StyleSystem.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
