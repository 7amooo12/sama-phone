import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/config/constants.dart';
import 'package:smartbiztracker_new/config/routes.dart';
import 'package:smartbiztracker_new/config/themes.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:smartbiztracker_new/utils/color_extension.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isLastPage = false;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'إدارة الأعمال الخاصة بك',
      description:
          'نظام متكامل يساعدك على إدارة أعمالك بكفاءة من خلال واجهة سهلة الاستخدام',
      animationAsset: 'assets/animations/business_management.json',
      bgColor: AppThemes.primaryColor,
    ),
    OnboardingPage(
      title: 'واجهات متعددة',
      description:
          'نظام متكامل يدعم أدوار متعددة: المدير، العميل، العامل، وصاحب العمل',
      animationAsset: 'assets/animations/multi_role.json',
      bgColor: AppThemes.secondaryColor,
    ),
    OnboardingPage(
      title: 'تتبع الطلبات والمنتجات',
      description:
          'مراقبة تقدم الطلبات والمنتجات وإدارة المخزون بشكل سهل ومباشر',
      animationAsset: 'assets/animations/product_tracking.json',
      bgColor: AppThemes.accentColor,
    ),
    OnboardingPage(
      title: 'هيا لنبدأ',
      description: 'قم بإنشاء حساب أو تسجيل الدخول للبدء في استخدام النظام',
      animationAsset: 'assets/animations/get_started.json',
      bgColor: AppThemes.successColor,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      final int page = _pageController.page?.round() ?? 0;
      if (page != _currentPage) {
        setState(() {
          _currentPage = page;
          _isLastPage = page == _pages.length - 1;
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _onGetStarted() async {
    // Save that onboarding is completed
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);

    if (mounted) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.white,
        child: Stack(
          children: [
            // Page view
            PageView.builder(
              controller: _pageController,
              itemCount: _pages.length,
              itemBuilder: (context, index) {
                return buildPage(_pages[index]);
              },
            ),

            // Skip button
            if (!_isLastPage)
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                right: 16,
                child: TextButton(
                  onPressed: () {
                    _pageController.animateToPage(
                      _pages.length - 1,
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: const Text(
                    'تخطي',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),

            // Page indicator & buttons
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Page indicator
                    SmoothPageIndicator(
                      controller: _pageController,
                      count: _pages.length,
                      effect: ExpandingDotsEffect(
                        dotHeight: 8,
                        dotWidth: 8,
                        activeDotColor: Colors.white,
                        dotColor: Colors.white.safeOpacity(0.5),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Next/Get Started button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLastPage
                            ? _onGetStarted
                            : () {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 500),
                                  curve: Curves.easeInOut,
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: _pages[_currentPage].bgColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          _isLastPage ? AppConstants.buttonRegister : 'التالي',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    // Login button (on last page)
                    if (_isLastPage)
                      Container(
                        margin: const EdgeInsets.only(top: 16),
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context)
                                .pushReplacementNamed(AppRoutes.login);
                          },
                          child: const Text(
                            'تسجيل الدخول',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildPage(OnboardingPage page) {
    return Container(
      color: page.bgColor,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animation
          Expanded(
            flex: 2,
            child: Center(
              child: Lottie.asset(
                page.animationAsset,
                width: MediaQuery.of(context).size.width * 0.8,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.image_not_supported_outlined,
                    size: 100,
                    color: Colors.white.safeOpacity(0.5),
                  );
                },
              ),
            ),
          ),
          // Title and description
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Text(
                  page.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  page.description,
                  style: TextStyle(
                    color: Colors.white.safeOpacity(0.9),
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingPage {
  OnboardingPage({
    required this.title,
    required this.description,
    required this.animationAsset,
    required this.bgColor,
  });
  final String title;
  final String description;
  final String animationAsset;
  final Color bgColor;
}
