import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/screens/owner/import_analysis/import_analysis_main_screen.dart';
import 'package:smartbiztracker_new/screens/manufacturing/production_screen.dart';
import 'package:smartbiztracker_new/providers/import_analysis_provider.dart';
import 'package:smartbiztracker_new/services/supabase_service.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// تبويب تحليل الاستيراد الرئيسي مع واجهة مستخدم متقدمة
/// يتبع أنماط AccountantThemeConfig مع دعم RTL العربية والأداء المحسن
class ImportAnalysisTab extends StatefulWidget {
  const ImportAnalysisTab({super.key});

  @override
  State<ImportAnalysisTab> createState() => _ImportAnalysisTabState();
}

class _ImportAnalysisTabState extends State<ImportAnalysisTab> {

  @override
  Widget build(BuildContext context) {
    AppLogger.info('🔍 ImportAnalysisTab building...');

    // Test provider accessibility
    try {
      final testProvider = Provider.of<ImportAnalysisProvider>(context, listen: false);
      AppLogger.info('✅ ImportAnalysisProvider accessible in ImportAnalysisTab: ${testProvider.runtimeType}');
    } catch (e) {
      AppLogger.error('❌ ImportAnalysisProvider NOT accessible in ImportAnalysisTab: $e');
    }

    return Scaffold(
      backgroundColor: AccountantThemeConfig.backgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          _buildNavigationContent(),
        ],
      ),
    );
  }

  /// بناء SliverAppBar مع تدرج وتصميم احترافي
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: AccountantThemeConfig.mainBackgroundGradient,
        ),
        child: FlexibleSpaceBar(
          title: Text(
            'تحليل الاستيراد',
            style: AccountantThemeConfig.headlineMedium.copyWith(
              color: Colors.white,
              fontSize: 20,
            ),
          ),
          centerTitle: true,
          background: Container(
            decoration: const BoxDecoration(
              gradient: AccountantThemeConfig.mainBackgroundGradient,
            ),
            child: Stack(
              children: [
                // نمط الخلفية
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.1,
                    child: CustomPaint(
                      painter: _BackgroundPatternPainter(),
                      size: Size.infinite,
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

  /// بناء محتوى التنقل
  Widget _buildNavigationContent() {
    return SliverPadding(
      padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          const SizedBox(height: 24),

          // Main Navigation Card - Modernized
          Container(
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.cardGradient,
              borderRadius: BorderRadius.circular(AccountantThemeConfig.largeBorderRadius),
              border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
              boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _navigateToMainScreen(context),
                borderRadius: BorderRadius.circular(AccountantThemeConfig.largeBorderRadius),
                child: Container(
                  padding: const EdgeInsets.all(AccountantThemeConfig.largePadding),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: AccountantThemeConfig.greenGradient,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
                        ),
                        child: const Icon(
                          Icons.analytics_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'تحليل الاستيراد المتقدم',
                              style: AccountantThemeConfig.headlineSmall.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'نظام متطور لمعالجة وتحليل ملفات Excel الخاصة بقوائم التعبئة والشحن',
                              style: AccountantThemeConfig.bodyMedium.copyWith(
                                color: Colors.white70,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    gradient: AccountantThemeConfig.greenGradient,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
                                  ),
                                  child: Text(
                                    'انقر للدخول',
                                    style: AccountantThemeConfig.bodySmall.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.arrow_forward_ios,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.3, end: 0),

          const SizedBox(height: 24),

          // Manufacturing Tools Entry Point
          _buildManufacturingToolsCard(),

          const SizedBox(height: 24),

          // Production Entry Point
          _buildProductionCard(),

          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  /// بناء بطاقة أدوات التصنيع
  Widget _buildManufacturingToolsCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(AccountantThemeConfig.largeBorderRadius),
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.warningOrange),
        boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.warningOrange),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToManufacturingTools(context),
          borderRadius: BorderRadius.circular(AccountantThemeConfig.largeBorderRadius),
          child: Container(
            padding: const EdgeInsets.all(AccountantThemeConfig.largePadding),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AccountantThemeConfig.orangeGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.warningOrange),
                  ),
                  child: const Icon(
                    Icons.precision_manufacturing_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'أدوات التصنيع',
                        style: AccountantThemeConfig.headlineSmall.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'نظام إدارة أدوات التصنيع مع تتبع المخزون والإنتاج',
                        style: AccountantThemeConfig.bodyMedium.copyWith(
                          color: Colors.white70,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: AccountantThemeConfig.orangeGradient,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.warningOrange),
                            ),
                            child: Text(
                              'انقر للدخول',
                              style: AccountantThemeConfig.bodySmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.3, end: 0);
  }

  /// التنقل إلى الشاشة الرئيسية
  void _navigateToMainScreen(BuildContext context) {
    try {
      final provider = Provider.of<ImportAnalysisProvider>(context, listen: false);
      AppLogger.info('✅ ImportAnalysisProvider accessible: ${provider.runtimeType}');

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ImportAnalysisMainScreen(),
        ),
      );
    } catch (e) {
      AppLogger.error('❌ ImportAnalysisProvider not accessible: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في الوصول لمزود تحليل الاستيراد: $e'),
          backgroundColor: AccountantThemeConfig.dangerRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  /// التنقل إلى شاشة أدوات التصنيع
  void _navigateToManufacturingTools(BuildContext context) {
    try {
      AppLogger.info('🔧 Navigating to Manufacturing Tools...');
      Navigator.pushNamed(context, '/manufacturing-tools');
    } catch (e) {
      AppLogger.error('❌ Error navigating to Manufacturing Tools: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في الانتقال إلى أدوات التصنيع: $e'),
          backgroundColor: AccountantThemeConfig.dangerRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  /// التنقل إلى شاشة الإنتاج (من سياق المالك)
  void _navigateToProduction(BuildContext context) {
    try {
      AppLogger.info('🏭 Navigating to Production Screen from Owner context...');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ProductionScreen(isOwnerContext: true),
        ),
      );
    } catch (e) {
      AppLogger.error('❌ Error navigating to Production Screen: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في الانتقال إلى شاشة الإنتاج: $e'),
          backgroundColor: AccountantThemeConfig.dangerRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  /// بناء بطاقة الإنتاج
  Widget _buildProductionCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(AccountantThemeConfig.largeBorderRadius),
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
        boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.accentBlue),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToProduction(context),
          borderRadius: BorderRadius.circular(AccountantThemeConfig.largeBorderRadius),
          child: Container(
            padding: const EdgeInsets.all(AccountantThemeConfig.largePadding),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AccountantThemeConfig.blueGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.accentBlue),
                  ),
                  child: const Icon(
                    Icons.factory_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الإنتاج',
                        style: AccountantThemeConfig.headlineSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'عرض دفعات الإنتاج والإحصائيات',
                        style: AccountantThemeConfig.bodyMedium.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: AccountantThemeConfig.blueGradient,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.accentBlue),
                            ),
                            child: Text(
                              'انقر للدخول',
                              style: AccountantThemeConfig.bodySmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.3, end: 0);
  }
}

/// رسام نمط الخلفية المخصص
class _BackgroundPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    // رسم نمط هندسي متكرر
    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        // رسم دوائر صغيرة
        if ((x / spacing + y / spacing) % 3 == 0) {
          canvas.drawCircle(
            Offset(x, y),
            3,
            paint,
          );
        }
        // رسم مربعات صغيرة
        else if ((x / spacing + y / spacing) % 2 == 0) {
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset(x, y),
              width: 4,
              height: 4,
            ),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
