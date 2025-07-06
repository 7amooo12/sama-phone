import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smartbiztracker_new/screens/client/order_tracking_screen.dart';
import '../../utils/accountant_theme_config.dart';

class OrderSuccessScreen extends StatelessWidget {

  const OrderSuccessScreen({
    super.key,
    required this.orderId,
  });
  final String orderId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AccountantThemeConfig.luxuryBlack,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AccountantThemeConfig.mainBackgroundGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.1),

                // Success Animation
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AccountantThemeConfig.primaryGreen.withValues(alpha: 0.2),
                        AccountantThemeConfig.primaryGreen.withValues(alpha: 0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
                  ),
                  child: Center(
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: AccountantThemeConfig.greenGradient,
                        shape: BoxShape.circle,
                        boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ).animate()
                  .scale(duration: 800.ms, curve: Curves.elasticOut)
                  .then()
                  .shimmer(duration: 1000.ms, color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3)),

              const SizedBox(height: 40),

              // Success Title
              Text(
                'تم إنشاء طلبيتك بنجاح!',
                style: AccountantThemeConfig.headlineMedium.copyWith(
                  color: AccountantThemeConfig.primaryGreen,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.3),

              const SizedBox(height: 16),

              // Order ID
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AccountantThemeConfig.accentBlue.withValues(alpha: 0.15),
                      AccountantThemeConfig.accentBlue.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
                  boxShadow: [
                    BoxShadow(
                      color: AccountantThemeConfig.accentBlue.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      color: AccountantThemeConfig.accentBlue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'رقم الطلب: ',
                      style: AccountantThemeConfig.bodyMedium.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      orderId.substring(0, 8).toUpperCase(),
                      style: AccountantThemeConfig.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AccountantThemeConfig.accentBlue,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.3),

              const SizedBox(height: 32),

              // Success Message
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AccountantThemeConfig.accentBlue.withValues(alpha: 0.15),
                      AccountantThemeConfig.accentBlue.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
                  boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.accentBlue),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AccountantThemeConfig.accentBlue.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.info_outline,
                        color: AccountantThemeConfig.accentBlue,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'تم إرسال طلبك إلى فريق المبيعات',
                      style: AccountantThemeConfig.headlineMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'سيتم التواصل معك قريباً لتأكيد الطلب وترتيب عملية التسليم',
                      style: AccountantThemeConfig.bodyMedium.copyWith(
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 900.ms).slideY(begin: 0.3),

              const SizedBox(height: 32),

              // Features List
              _buildFeaturesList().animate().fadeIn(delay: 1100.ms).slideY(begin: 0.3),

              SizedBox(height: MediaQuery.of(context).size.height * 0.05),

              // Action Buttons
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => OrderTrackingScreen(orderId: orderId),
                          ),
                        );
                      },
                      icon: const Icon(Icons.track_changes_outlined),
                      label: Text(
                        'تتبع الطلب',
                        style: AccountantThemeConfig.bodyLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AccountantThemeConfig.primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                        shadowColor: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3),
                      ).copyWith(
                        overlayColor: WidgetStateProperty.all(
                          AccountantThemeConfig.primaryGreen.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 1300.ms).slideY(begin: 0.3),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.popUntil(context, (route) => route.isFirst);
                      },
                      icon: Icon(
                        Icons.home_outlined,
                        color: AccountantThemeConfig.accentBlue,
                      ),
                      label: Text(
                        'العودة للرئيسية',
                        style: AccountantThemeConfig.bodyLarge.copyWith(
                          color: AccountantThemeConfig.accentBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AccountantThemeConfig.accentBlue,
                        side: BorderSide(
                          color: AccountantThemeConfig.accentBlue,
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        backgroundColor: AccountantThemeConfig.accentBlue.withValues(alpha: 0.05),
                      ).copyWith(
                        overlayColor: WidgetStateProperty.all(
                          AccountantThemeConfig.accentBlue.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 1500.ms).slideY(begin: 0.3),
                ],
              ),

              // Bottom padding for scrollable content
              SizedBox(height: MediaQuery.of(context).size.height * 0.1),
            ],
          ), // Closing parenthesis for main Column
        ), // Closing parenthesis for Padding
      ), // Closing parenthesis for SingleChildScrollView
    ), // Closing parenthesis for SafeArea
  ), // Closing parenthesis for Container
); // Closing parenthesis for Scaffold
  }

  Widget _buildFeaturesList() {
    final features = [
      {
        'icon': Icons.security_outlined,
        'title': 'طلب آمن',
        'subtitle': 'تم تشفير بياناتك بأمان',
        'color': AccountantThemeConfig.primaryGreen,
      },
      {
        'icon': Icons.support_agent_outlined,
        'title': 'دعم فني',
        'subtitle': 'فريق الدعم متاح 24/7',
        'color': AccountantThemeConfig.accentBlue,
      },
      {
        'icon': Icons.local_shipping_outlined,
        'title': 'شحن سريع',
        'subtitle': 'توصيل في أسرع وقت ممكن',
        'color': AccountantThemeConfig.warningOrange,
      },
    ];

    return Column(
      children: features.map((feature) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                (feature['color'] as Color).withValues(alpha: 0.15),
                (feature['color'] as Color).withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: AccountantThemeConfig.glowBorder(feature['color'] as Color),
            boxShadow: [
              BoxShadow(
                color: (feature['color'] as Color).withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      (feature['color'] as Color).withValues(alpha: 0.3),
                      (feature['color'] as Color).withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: AccountantThemeConfig.glowBorder(feature['color'] as Color),
                ),
                child: Icon(
                  feature['icon'] as IconData,
                  color: feature['color'] as Color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      feature['title'] as String,
                      style: AccountantThemeConfig.labelLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      feature['subtitle'] as String,
                      style: AccountantThemeConfig.bodySmall.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      )).toList(),
    );
  }
}
