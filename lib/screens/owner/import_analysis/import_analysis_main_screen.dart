import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/screens/owner/import_analysis/container_import_screen.dart';
import 'package:smartbiztracker_new/screens/owner/import_analysis/container_management_screen.dart';
import 'package:smartbiztracker_new/screens/owner/import_analysis/advanced_analysis_screen.dart';
import 'package:smartbiztracker_new/screens/owner/import_analysis/debug_excel_screen.dart';
import 'package:smartbiztracker_new/providers/import_analysis_provider.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// الشاشة الرئيسية لتحليل الاستيراد - تطبيق كامل الشاشة
/// يتبع أنماط AccountantThemeConfig مع دعم RTL العربية والتصميم الاحترافي
class ImportAnalysisMainScreen extends StatefulWidget {
  const ImportAnalysisMainScreen({super.key});

  @override
  State<ImportAnalysisMainScreen> createState() => _ImportAnalysisMainScreenState();
}

class _ImportAnalysisMainScreenState extends State<ImportAnalysisMainScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppLogger.info('🔍 ImportAnalysisMainScreen building...');

    // Try to access provider with error handling
    try {
      final testProvider = Provider.of<ImportAnalysisProvider>(context, listen: false);
      AppLogger.info('✅ ImportAnalysisProvider accessible in ImportAnalysisMainScreen: ${testProvider.runtimeType}');
    } catch (e) {
      AppLogger.error('❌ ImportAnalysisProvider NOT accessible in ImportAnalysisMainScreen: $e');
      return Scaffold(
        backgroundColor: AccountantThemeConfig.backgroundColor,
        appBar: AppBar(
          title: const Text('خطأ في تحليل الاستيراد'),
          backgroundColor: Colors.red,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'خطأ في الوصول لمزود تحليل الاستيراد',
                style: AccountantThemeConfig.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'يرجى إعادة تشغيل التطبيق',
                style: AccountantThemeConfig.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('العودة'),
              ),
            ],
          ),
        ),
      );
    }

    return Consumer<ImportAnalysisProvider>(
      builder: (context, provider, child) {
        // Add error handling for provider issues
        if (provider.errorMessage != null) {
          return Scaffold(
            backgroundColor: AccountantThemeConfig.backgroundColor,
            appBar: AppBar(
              title: const Text('تحليل الاستيراد'),
              backgroundColor: AccountantThemeConfig.primaryGreen,
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'خطأ في تحميل مزود تحليل الاستيراد',
                    style: AccountantThemeConfig.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    provider.errorMessage!,
                    style: AccountantThemeConfig.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('العودة'),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: AccountantThemeConfig.backgroundColor,
          body: CustomScrollView(
            slivers: [
              _buildSliverAppBar(),
              _buildMainContent(),
            ],
          ),
        );
      },
    );
  }

  /// بناء SliverAppBar مع تدرج احترافي
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      actions: [
        IconButton(
          icon: const Icon(Icons.bug_report, color: Colors.white),
          onPressed: () => _navigateToScreen(context, const DebugExcelScreen()),
          tooltip: 'تشخيص Excel',
        ),
      ],
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: AccountantThemeConfig.mainBackgroundGradient,
        ),
        child: FlexibleSpaceBar(
          title: Text(
            'تحليل الاستيراد المتقدم',
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
                    ),
                    child: const Icon(
                      Icons.analytics,
                      size: 60,
                      color: Colors.white,
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

  /// بناء المحتوى الرئيسي
  Widget _buildMainContent() {
    return SliverPadding(
      padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          const SizedBox(height: 24),

          // وصف الخدمة
          _buildServiceDescription(),

          const SizedBox(height: 32),

          // بطاقات الإجراءات الرئيسية
          _buildActionCards(),

          const SizedBox(height: 32),

          // إحصائيات سريعة
          _buildQuickStats(),

          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  /// بناء وصف الخدمة
  Widget _buildServiceDescription() {
    return Container(
      padding: const EdgeInsets.all(AccountantThemeConfig.largePadding),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(AccountantThemeConfig.largeBorderRadius),
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
        boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AccountantThemeConfig.greenGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
                ),
                child: const Icon(
                  Icons.analytics_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'نظام تحليل الاستيراد الذكي',
                      style: AccountantThemeConfig.headlineSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: AccountantThemeConfig.blueGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'متطور وذكي',
                        style: AccountantThemeConfig.bodySmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'نظام متطور لمعالجة وتحليل ملفات Excel الخاصة بقوائم التعبئة والشحن. يدعم النظام معالجة البيانات باللغتين العربية والصينية، مع إنشاء تقارير ذكية وتحليلات متقدمة للحاويات المستوردة.',
            style: AccountantThemeConfig.bodyLarge.copyWith(
              color: Colors.white70,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          // Feature highlights
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildFeatureChip('معالجة ذكية', Icons.psychology_rounded),
              _buildFeatureChip('دعم العربية', Icons.language_rounded),
              _buildFeatureChip('تقارير متقدمة', Icons.assessment_rounded),
              _buildFeatureChip('تحليل البيانات', Icons.insights_rounded),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.3, end: 0);
  }

  /// بناء رقاقة الميزة
  Widget _buildFeatureChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.white70,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// بناء بطاقات الإجراءات الرئيسية
  Widget _buildActionCards() {
    final actions = [
      {
        'title': 'استيراد حاوية جديدة',
        'description': 'رفع ومعالجة ملف Excel جديد لحاوية استيراد',
        'icon': Icons.upload_file,
        'color': AccountantThemeConfig.primaryGreen,
        'route': const ContainerImportScreen(),
      },
      {
        'title': 'إدارة الحاويات المحفوظة',
        'description': 'عرض وإدارة الحاويات المحفوظة مسبقاً',
        'icon': Icons.inventory_2,
        'color': Colors.blue,
        'route': const ContainerManagementScreen(),
      },
      {
        'title': 'تحليل متقدم',
        'description': 'تحليلات وإحصائيات متقدمة للبيانات',
        'icon': Icons.analytics,
        'color': Colors.purple,
        'route': const AdvancedAnalysisScreen(),
      },
    ];

    return Column(
      children: actions.asMap().entries.map((entry) {
        final index = entry.key;
        final action = entry.value;
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildActionCard(
            title: action['title'] as String,
            description: action['description'] as String,
            icon: action['icon'] as IconData,
            color: action['color'] as Color,
            onTap: () => _navigateToScreen(context, action['route'] as Widget),
          ).animate(delay: (index * 200).ms)
              .fadeIn(duration: 500.ms)
              .slideX(begin: 0.3),
        );
      }).toList(),
    );
  }

  /// بناء بطاقة إجراء واحدة
  Widget _buildActionCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(AccountantThemeConfig.largeBorderRadius),
        border: AccountantThemeConfig.glowBorder(color),
        boxShadow: AccountantThemeConfig.glowShadows(color),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AccountantThemeConfig.largeBorderRadius),
          child: Container(
            padding: const EdgeInsets.all(AccountantThemeConfig.largePadding),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withOpacity(0.8)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AccountantThemeConfig.glowShadows(color),
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AccountantThemeConfig.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: AccountantThemeConfig.bodyMedium.copyWith(
                          color: Colors.white70,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'انقر للدخول',
                          style: AccountantThemeConfig.bodySmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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
          ),
        ),
      ),
    );
  }

  /// بناء الإحصائيات السريعة
  Widget _buildQuickStats() {
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
                  Icons.speed_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'إحصائيات سريعة',
                style: AccountantThemeConfig.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'الحاويات المعالجة',
                  '0',
                  Icons.inventory,
                  Colors.blue,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'العناصر المستوردة',
                  '0',
                  Icons.shopping_cart,
                  Colors.green,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'التقارير المنشأة',
                  '0',
                  Icons.description,
                  Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 700.ms).slideY(begin: 0.3, end: 0);
  }

  /// بناء عنصر إحصائية واحدة
  Widget _buildStatItem(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: AccountantThemeConfig.headlineSmall.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// التنقل إلى الشاشة - مبسط مع Provider عالمي
  void _navigateToScreen(BuildContext context, Widget route) {
    try {
      // التنقل المبسط - Provider متاح عالمياً
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => route,
        ),
      );
    } catch (e) {
      // في حالة عدم توفر Provider، عرض رسالة خطأ
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في التنقل: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
