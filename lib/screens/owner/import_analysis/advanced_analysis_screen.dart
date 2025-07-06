import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';

/// شاشة التحليل المتقدم
class AdvancedAnalysisScreen extends StatefulWidget {
  const AdvancedAnalysisScreen({super.key});

  @override
  State<AdvancedAnalysisScreen> createState() => _AdvancedAnalysisScreenState();
}

class _AdvancedAnalysisScreenState extends State<AdvancedAnalysisScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AccountantThemeConfig.backgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          _buildContent(),
        ],
      ),
    );
  }

  /// بناء SliverAppBar مع تدرج احترافي
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 140,
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
            'التحليل المتقدم',
            style: AccountantThemeConfig.headlineMedium.copyWith(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
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
                // أيقونة مركزية
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 40),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: AccountantThemeConfig.glowShadows(Colors.white),
                    ),
                    child: const Icon(
                      Icons.analytics_rounded,
                      size: 48,
                      color: Colors.white,
                    ),
                  ).animate().scale(duration: 800.ms).fadeIn(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// بناء المحتوى
  Widget _buildContent() {
    return SliverPadding(
      padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          const SizedBox(height: 24),
          _buildComingSoonCard(),
          const SizedBox(height: 24),
          _buildFeaturePreviewCard(),
          const SizedBox(height: 24),
          _buildAnalyticsPreviewCards(),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  /// بناء بطاقة قريباً
  Widget _buildComingSoonCard() {
    return Container(
      padding: const EdgeInsets.all(AccountantThemeConfig.largePadding),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(AccountantThemeConfig.largeBorderRadius),
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
        boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
      ),
      child: Column(
        children: [
          // Hero Icon
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.greenGradient,
              borderRadius: BorderRadius.circular(50),
              boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
            ),
            child: const Icon(
              Icons.analytics_rounded,
              size: 60,
              color: Colors.white,
            ),
          ).animate().scale(duration: 800.ms, delay: 200.ms),

          const SizedBox(height: 24),

          Text(
            'التحليل المتقدم',
            style: AccountantThemeConfig.headlineSmall.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ).animate().fadeIn(delay: 400.ms),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.blueGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.accentBlue),
            ),
            child: Text(
              'قريباً',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ).animate().fadeIn(delay: 600.ms).scale(),

          const SizedBox(height: 20),

          Text(
            'هذه الميزة قيد التطوير وستكون متاحة قريباً',
            style: AccountantThemeConfig.bodyLarge.copyWith(
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 800.ms),

          const SizedBox(height: 12),

          Text(
            'ستتمكن من إجراء تحليلات وإحصائيات متقدمة للبيانات مع رسوم بيانية تفاعلية وتقارير شاملة',
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white60,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 1000.ms),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.3, end: 0);
  }

  /// بناء بطاقات معاينة التحليلات
  Widget _buildAnalyticsPreviewCards() {
    final analyticsFeatures = [
      {
        'title': 'تحليل البيانات الذكي',
        'description': 'معالجة تلقائية للبيانات مع كشف الأنماط والاتجاهات',
        'icon': Icons.psychology_rounded,
        'color': AccountantThemeConfig.accentBlue,
        'progress': 0.75,
      },
      {
        'title': 'الرسوم البيانية التفاعلية',
        'description': 'مخططات ديناميكية لعرض الإحصائيات والتحليلات',
        'icon': Icons.bar_chart_rounded,
        'color': AccountantThemeConfig.warningOrange,
        'progress': 0.60,
      },
      {
        'title': 'التقارير المخصصة',
        'description': 'إنشاء تقارير مفصلة حسب احتياجاتك',
        'icon': Icons.description_rounded,
        'color': AccountantThemeConfig.primaryGreen,
        'progress': 0.45,
      },
    ];

    return Column(
      children: analyticsFeatures.map((feature) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
        decoration: BoxDecoration(
          gradient: AccountantThemeConfig.cardGradient,
          borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
          border: AccountantThemeConfig.glowBorder(feature['color'] as Color),
          boxShadow: AccountantThemeConfig.cardShadows,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (feature['color'] as Color).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
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
                        style: AccountantThemeConfig.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        feature['description'] as String,
                        style: AccountantThemeConfig.bodyMedium.copyWith(
                          color: Colors.white70,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: (feature['color'] as Color).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${((feature['progress'] as double) * 100).toInt()}%',
                    style: AccountantThemeConfig.bodySmall.copyWith(
                      color: feature['color'] as Color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Progress Bar
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(3),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: feature['progress'] as double,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        feature['color'] as Color,
                        (feature['color'] as Color).withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 600.ms, delay: (analyticsFeatures.indexOf(feature) * 200).ms)
       .slideX(begin: 0.3, end: 0)).toList(),
    );
  }

  /// بناء بطاقة معاينة الميزات
  Widget _buildFeaturePreviewCard() {
    return Container(
      padding: const EdgeInsets.all(AccountantThemeConfig.largePadding),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(AccountantThemeConfig.largeBorderRadius),
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
        boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.accentBlue),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: AccountantThemeConfig.blueGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.accentBlue),
                ),
                child: const Icon(
                  Icons.preview_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'الميزات القادمة',
                style: AccountantThemeConfig.headlineSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildFeatureItem(
            Icons.bar_chart_rounded,
            'تحليل البيانات المتقدم',
            'رسوم بيانية تفاعلية وتحليلات شاملة',
          ),
          const SizedBox(height: 16),
          _buildFeatureItem(
            Icons.trending_up_rounded,
            'تقارير الأداء',
            'تتبع الأداء والاتجاهات عبر الزمن',
          ),
          const SizedBox(height: 16),
          _buildFeatureItem(
            Icons.insights_rounded,
            'رؤى ذكية',
            'توصيات مبنية على الذكاء الاصطناعي',
          ),
        ],
      ),
    ).animate().fadeIn(duration: 800.ms, delay: 200.ms).slideY(begin: 0.3, end: 0);
  }

  /// بناء عنصر ميزة
  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AccountantThemeConfig.accentBlue.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
            border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
          ),
          child: Icon(
            icon,
            color: AccountantThemeConfig.accentBlue,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AccountantThemeConfig.bodyLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: AccountantThemeConfig.white70,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// رسام نمط الخلفية المخصص
class _BackgroundPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    // رسم نمط هندسي متكرر
    const spacing = 50.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        // رسم دوائر صغيرة
        if ((x / spacing + y / spacing) % 3 == 0) {
          canvas.drawCircle(
            Offset(x, y),
            4,
            paint,
          );
        }
        // رسم مثلثات صغيرة
        else if ((x / spacing + y / spacing) % 2 == 0) {
          final path = Path();
          path.moveTo(x, y - 3);
          path.lineTo(x - 3, y + 3);
          path.lineTo(x + 3, y + 3);
          path.close();
          canvas.drawPath(path, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
