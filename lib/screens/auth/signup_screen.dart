import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/config/constants.dart';
import 'package:smartbiztracker_new/config/routes.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:smartbiztracker_new/widgets/custom_button.dart';
import 'package:smartbiztracker_new/widgets/custom_loader.dart';
import 'package:smartbiztracker_new/widgets/custom_text_field.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:smartbiztracker_new/models/user_model.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: AppConstants.mediumAnimation,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    // Start the animation
    _animationController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (_formKey.currentState!.validate()) {
      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);

      await supabaseProvider.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text.trim(),
        phone: '', // Add a phone field if needed
        role: UserRole.client, // Default role for new users
      );

      if (supabaseProvider.user != null && context.mounted) {
        // Show success message and navigate to waiting approval screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppConstants.signupSuccess),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.of(context).pushReplacementNamed(AppRoutes.waitingApproval);
      } else if (context.mounted && supabaseProvider.error != null) {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(supabaseProvider.error!),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إنشاء حساب جديد'),
        centerTitle: true,
      ),
      body: Consumer<SupabaseProvider>(
        builder: (context, supabaseProvider, _) {
          return SafeArea(
            child: Stack(
              children: [
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: AnimationLimiter(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: AnimationConfiguration.toStaggeredList(
                          duration: AppConstants.mediumAnimation,
                          childAnimationBuilder: (widget) => SlideAnimation(
                            horizontalOffset: 50.0,
                            child: FadeInAnimation(
                              child: widget,
                            ),
                          ),
                          children: [
                            // Title
                            FadeTransition(
                              opacity: _fadeAnimation,
                              child: Text(
                                'أنشئ حسابك الجديد',
                                textAlign: TextAlign.center,
                                style:
                                    Theme.of(context).textTheme.displayMedium,
                              ),
                            ),
                            const SizedBox(height: 30),

                            // Signup form
                            Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Name field
                                  CustomTextField(
                                    controller: _nameController,
                                    labelText: 'الاسم',
                                    prefixIcon: Icons.person,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'يرجى إدخال الاسم';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // Email field
                                  CustomTextField(
                                    controller: _emailController,
                                    labelText: 'البريد الإلكتروني',
                                    prefixIcon: Icons.email,
                                    keyboardType: TextInputType.emailAddress,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'يرجى إدخال البريد الإلكتروني';
                                      }

                                      final bool isValid = RegExp(
                                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                      ).hasMatch(value);

                                      if (!isValid) {
                                        return 'يرجى إدخال بريد إلكتروني صحيح';
                                      }

                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // Password field
                                  CustomTextField(
                                    controller: _passwordController,
                                    labelText: 'كلمة المرور',
                                    prefixIcon: Icons.lock,
                                    obscureText: true,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'يرجى إدخال كلمة المرور';
                                      }

                                      if (value.length < 6) {
                                        return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                                      }

                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // Confirm password field
                                  CustomTextField(
                                    controller: _confirmPasswordController,
                                    labelText: 'تأكيد كلمة المرور',
                                    prefixIcon: Icons.lock_outline,
                                    obscureText: true,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'يرجى تأكيد كلمة المرور';
                                      }

                                      if (value != _passwordController.text) {
                                        return 'كلمتا المرور غير متطابقتين';
                                      }

                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 24),

                                  // Signup button
                                  CustomButton(
                                    text: 'إنشاء حساب',
                                    onPressed: _signUp,
                                    isLoading: supabaseProvider.isLoading,
                                  ),
                                  const SizedBox(height: 16),

                                  // Login link
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: const Text(
                                      'لديك حساب بالفعل؟ تسجيل الدخول',
                                      style: TextStyle(
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Error message
                if (supabaseProvider.error != null)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Card(
                      color: Colors.red.shade400,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Text(
                          supabaseProvider.error!,
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),

                // Loading overlay
                if (supabaseProvider.isLoading)
                  const Positioned.fill(
                    child: CustomLoader(showText: true),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
