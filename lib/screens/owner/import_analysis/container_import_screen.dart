import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/providers/import_analysis_provider.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/widgets/common/custom_loader.dart';
import 'package:smartbiztracker_new/screens/owner/import_analysis/widgets/container_setup_step.dart';
import 'package:smartbiztracker_new/screens/owner/import_analysis/widgets/file_upload_step.dart';
import 'package:smartbiztracker_new/screens/owner/import_analysis/widgets/data_review_step.dart';
import 'package:smartbiztracker_new/screens/owner/import_analysis/widgets/export_save_step.dart';

/// شاشة استيراد الحاوية - سير عمل من 4 خطوات
/// Step 1: Container Setup → Step 2: File Upload & Processing → Step 3: Data Review & Validation → Step 4: Export & Save
class ContainerImportScreen extends StatefulWidget {
  const ContainerImportScreen({super.key});

  @override
  State<ContainerImportScreen> createState() => _ContainerImportScreenState();
}

class _ContainerImportScreenState extends State<ContainerImportScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animationController;
  int _currentStep = 0;
  
  final List<String> _stepTitles = [
    'إعداد الحاوية',
    'رفع ومعالجة الملف',
    'مراجعة والتحقق من البيانات',
    'تصدير وحفظ',
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AccountantThemeConfig.backgroundColor,
      body: Consumer<ImportAnalysisProvider>(
        builder: (context, provider, child) {
          return CustomScrollView(
            slivers: [
              _buildSliverAppBar(),
              _buildStepIndicator(),
              _buildContent(provider),
            ],
          );
        },
      ),
    );
  }

  /// بناء SliverAppBar مع تدرج احترافي
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
            'استيراد حاوية جديدة',
            style: AccountantThemeConfig.headlineMedium.copyWith(
              color: Colors.white,
              fontSize: 20,
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// بناء مؤشر الخطوات
  Widget _buildStepIndicator() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              'الخطوة ${_currentStep + 1} من ${_stepTitles.length}',
              style: AccountantThemeConfig.titleMedium.copyWith(
                color: AccountantThemeConfig.primaryGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _stepTitles[_currentStep],
              style: AccountantThemeConfig.bodyLarge.copyWith(
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: List.generate(_stepTitles.length, (index) {
                final isActive = index == _currentStep;
                final isCompleted = index < _currentStep;
                
                return Expanded(
                  child: Container(
                    height: 4,
                    margin: EdgeInsets.only(
                      right: index < _stepTitles.length - 1 ? 8 : 0,
                    ),
                    decoration: BoxDecoration(
                      color: isCompleted || isActive
                          ? AccountantThemeConfig.primaryGreen
                          : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.3),
    );
  }

  /// بناء المحتوى الرئيسي
  Widget _buildContent(ImportAnalysisProvider provider) {
    return SliverFillRemaining(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            // Step 1: Container Setup
            ContainerSetupStep(
              onNext: () => _nextStep(),
            ),
            
            // Step 2: File Upload & Processing
            FileUploadStep(
              provider: provider,
              onNext: () => _nextStep(),
              onBack: () => _previousStep(),
            ),
            
            // Step 3: Data Review & Validation
            DataReviewStep(
              provider: provider,
              onNext: () => _nextStep(),
              onBack: () => _previousStep(),
            ),
            
            // Step 4: Export & Save
            ExportSaveStep(
              provider: provider,
              onBack: () => _previousStep(),
              onComplete: () => _completeImport(),
            ),
          ],
        ),
      ),
    );
  }

  /// الانتقال للخطوة التالية
  void _nextStep() {
    if (_currentStep < _stepTitles.length - 1) {
      setState(() {
        _currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _animationController.forward();
    }
  }

  /// العودة للخطوة السابقة
  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _animationController.reverse();
    }
  }

  /// إكمال عملية الاستيراد
  void _completeImport() {
    // عرض رسالة نجاح
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('تم إكمال استيراد الحاوية بنجاح'),
        backgroundColor: AccountantThemeConfig.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );

    // العودة للشاشة الرئيسية
    Navigator.pop(context);
  }
}

/// نموذج بيانات إعداد الحاوية
class ContainerSetupData {
  final String containerName;
  final DateTime importDate;
  final String? description;
  final String? supplierName;
  final String? supplierContact;
  final String? originCountry;

  const ContainerSetupData({
    required this.containerName,
    required this.importDate,
    this.description,
    this.supplierName,
    this.supplierContact,
    this.originCountry,
  });

  Map<String, dynamic> toJson() {
    return {
      'container_name': containerName,
      'import_date': importDate.toIso8601String(),
      'description': description,
      'supplier_name': supplierName,
      'supplier_contact': supplierContact,
      'origin_country': originCountry,
    };
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
