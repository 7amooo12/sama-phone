import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smartbiztracker_new/config/constants.dart';
import 'package:smartbiztracker_new/config/routes.dart';
import 'package:smartbiztracker_new/models/user_model.dart';
import 'package:smartbiztracker_new/providers/auth_provider.dart';
import 'package:smartbiztracker_new/utils/color_extension.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:smartbiztracker_new/utils/style_system.dart';
import 'package:smartbiztracker_new/models/models.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:smartbiztracker_new/widgets/common/loading_overlay.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  UserRole _selectedRole = UserRole.client;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  
  // Robot animation and interaction variables
  late AnimationController _animationController;
  late WebViewController _webViewController;
  bool _isWebViewLoaded = false;
  bool _isRobotLoading = true;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  final List<double> _gyroscopeValues = [0, 0, 0];
  String _robotStatus = 'waiting';
  
  // Form Focus trackers for robot interaction
  final _nameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _phoneFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initWebView();
    _setupFocusListeners();
    _setupGyroscope();
  }
  
  void _initAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _animationController.forward();
  }
  
  void _initWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..loadRequest(Uri.parse('https://my.spline.design/genkubgreetingrobot-fPBEa36NwDk1RjClPxjur0T4/'))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isRobotLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isRobotLoading = false;
              _isWebViewLoaded = true;
            });
            _triggerRobotAnimation('wave');
          },
        ),
      );
  }
  
  void _setupFocusListeners() {
    _nameFocusNode.addListener(() {
      if (_nameFocusNode.hasFocus) {
        _updateRobotStatus('name');
      }
    });
    
    _emailFocusNode.addListener(() {
      if (_emailFocusNode.hasFocus) {
        _updateRobotStatus('email');
      }
    });
    
    _phoneFocusNode.addListener(() {
      if (_phoneFocusNode.hasFocus) {
        _updateRobotStatus('phone');
      }
    });
    
    _passwordFocusNode.addListener(() {
      if (_passwordFocusNode.hasFocus) {
        _updateRobotStatus('password');
      }
    });
    
    _confirmPasswordFocusNode.addListener(() {
      if (_confirmPasswordFocusNode.hasFocus) {
        _updateRobotStatus('confirm');
      }
    });
  }
  
  void _setupGyroscope() {
    _gyroscopeSubscription = gyroscopeEvents.listen((GyroscopeEvent event) {
      if (mounted) {
        setState(() {
          _gyroscopeValues[0] = event.x;
          _gyroscopeValues[1] = event.y;
          _gyroscopeValues[2] = event.z;
        });
        _updateRobotEyeTracking();
      }
    });
  }
  
  void _updateRobotStatus(String status) {
    setState(() {
      _robotStatus = status;
    });
    
    // Add animation trigger based on the field focused
    switch (status) {
      case 'name':
        _triggerRobotAnimation('look_curious');
        break;
      case 'email':
        _triggerRobotAnimation('nod');
        break;
      case 'phone':
        _triggerRobotAnimation('look_down');
        break;
      case 'password':
        _triggerRobotAnimation('look_around');
        break;
      case 'confirm':
        _triggerRobotAnimation('thumbs_up');
        break;
      case 'success':
        _triggerRobotAnimation('celebrate');
        break;
      case 'error':
        _triggerRobotAnimation('shake_head');
        break;
      default:
        _triggerRobotAnimation('idle');
    }
  }
  
  void _triggerRobotAnimation(String animation) {
    if (_isWebViewLoaded) {
      try {
        _webViewController.runJavaScript('''
          try {
            // This is a simplified example - the actual Spline API might differ
            if (window.spline && window.spline.triggerAnimation) {
              window.spline.triggerAnimation('$animation');
            } else if (window.splineApp) {
              // Alternative API that might be used
              window.splineApp.triggerAnimation('$animation');
            } else {
              // Generic interaction with the scene
              const scene = document.querySelector('spline-viewer');
              if (scene) {
                scene.dispatchEvent(new CustomEvent('animation', { detail: { name: '$animation' } }));
              }
            }
          } catch(e) { console.log('Robot animation error: ' + e); }
        ''');
      } catch (e) {
        debugPrint('Error triggering robot animation: $e');
      }
    }
  }
  
  void _updateRobotEyeTracking() {
    if (_isWebViewLoaded) {
      try {
        // Calculate eye position based on device tilt
        final double tiltX = _clamp(_gyroscopeValues[1] * 20, -50, 50);
        final double tiltY = _clamp(_gyroscopeValues[0] * 20, -50, 50);
        
        _webViewController.runJavaScript('''
          try {
            // Access Spline's eye tracking if available
            if (window.spline && window.spline.setEyePosition) {
              window.spline.setEyePosition($tiltX, $tiltY);
            } else if (window.splineApp && window.splineApp.setLookAt) {
              window.splineApp.setLookAt($tiltX, $tiltY, 0);
            }
          } catch(e) { console.log('Eye tracking error: ' + e); }
        ''');
      } catch (e) {
        // Silently handle errors
        debugPrint('Error updating robot eye tracking: $e');
      }
    }
  }
  
  double _clamp(double value, double min, double max) {
    return value < min ? min : (value > max ? max : value);
  }

  String? _validatePasswords() {
    if (_passwordController.text != _confirmPasswordController.text) {
      return AppConstants.validationPasswordsDontMatch;
    }
    return null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _phoneFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    
    _animationController.dispose();
    _gyroscopeSubscription?.cancel();
    
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<SupabaseProvider>(context, listen: false);
      final success = await authProvider.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
      );

      if (!mounted) return;

      if (success) {
        Navigator.pushReplacementNamed(context, '/waiting-approval');
      } else {
        setState(() {
          _errorMessage = authProvider.error ?? 'فشل في إنشاء الحساب';
        });
      }
    } catch (e) {
      AppLogger.error('Registration error: $e');
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: StyleSystem.darkModeGradient,
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(10),
                        child: Image.asset(
                          'assets/icons/app_logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Name Field
                      TextFormField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: StyleSystem.inputDecoration.copyWith(
                          labelText: 'الاسم',
                          prefixIcon: const Icon(Icons.person, color: Colors.white70),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'يرجى إدخال الاسم';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Email Field
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: Colors.white),
                        decoration: StyleSystem.inputDecoration.copyWith(
                          labelText: 'البريد الإلكتروني',
                          prefixIcon: const Icon(Icons.email, color: Colors.white70),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'يرجى إدخال البريد الإلكتروني';
                          }
                          if (!value.contains('@')) {
                            return 'يرجى إدخال بريد إلكتروني صحيح';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Phone Field
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: Colors.white),
                        decoration: StyleSystem.inputDecoration.copyWith(
                          labelText: 'رقم الهاتف',
                          prefixIcon: const Icon(Icons.phone, color: Colors.white70),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'يرجى إدخال رقم الهاتف';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Password Field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(color: Colors.white),
                        decoration: StyleSystem.inputDecoration.copyWith(
                          labelText: 'كلمة المرور',
                          prefixIcon: const Icon(Icons.lock, color: Colors.white70),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility : Icons.visibility_off,
                              color: Colors.white70,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'يرجى إدخال كلمة المرور';
                          }
                          if (value.length < 8) {
                            return 'كلمة المرور يجب أن تكون 8 أحرف على الأقل';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Confirm Password Field
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        style: const TextStyle(color: Colors.white),
                        decoration: StyleSystem.inputDecoration.copyWith(
                          labelText: 'تأكيد كلمة المرور',
                          prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                              color: Colors.white70,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword = !_obscureConfirmPassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'يرجى تأكيد كلمة المرور';
                          }
                          if (value != _passwordController.text) {
                            return 'كلمة المرور غير متطابقة';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 30),

                      // Error Message
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                      // Register Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _register,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: StyleSystem.primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'إنشاء حساب',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Login Link
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Text(
                          'لديك حساب بالفعل؟ سجل دخول',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
