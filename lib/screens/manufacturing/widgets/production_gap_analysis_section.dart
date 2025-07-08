import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/models/manufacturing/production_batch.dart';
import 'package:smartbiztracker_new/models/product_model.dart';

/// قسم تحليل فجوة الإنتاج مع التحديثات الفورية
class ProductionGapAnalysisSection extends StatefulWidget {
  final int productId;
  final int batchId;
  final ProductModel? product;
  final double currentProduction;
  final bool isLoading;
  final ProductionGapAnalysis? gapAnalysis;
  final VoidCallback? onRefresh;
  final VoidCallback? onTargetUpdate;

  const ProductionGapAnalysisSection({
    super.key,
    required this.productId,
    required this.batchId,
    this.product,
    required this.currentProduction,
    this.isLoading = false,
    this.gapAnalysis,
    this.onRefresh,
    this.onTargetUpdate,
  });

  @override
  State<ProductionGapAnalysisSection> createState() => _ProductionGapAnalysisSectionState();
}

class _ProductionGapAnalysisSectionState extends State<ProductionGapAnalysisSection>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _progressAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _progressAnimationController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _progressAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
    ));

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressAnimationController,
      curve: Curves.easeOutCubic,
    ));
    
    _animationController.forward();
    _progressAnimationController.forward();
  }

  @override
  void didUpdateWidget(ProductionGapAnalysisSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gapAnalysis?.completionPercentage != widget.gapAnalysis?.completionPercentage) {
      _progressAnimationController.reset();
      _progressAnimationController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: AccountantThemeConfig.cardGradient,
            borderRadius: BorderRadius.circular(20),
            border: AccountantThemeConfig.glowBorder(
              widget.gapAnalysis?.statusColor.withOpacity(0.5) ?? 
              AccountantThemeConfig.primaryGreen.withOpacity(0.3)
            ),
            boxShadow: AccountantThemeConfig.cardShadows,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(),
              const SizedBox(height: 24),
              if (widget.isLoading)
                _buildLoadingState()
              else if (widget.gapAnalysis == null)
                _buildEmptyState()
              else ...[
                _buildGapAnalysisContent(),
                const SizedBox(height: 20),
                _buildActionButtons(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AccountantThemeConfig.primaryGreen,
                AccountantThemeConfig.primaryGreen.withOpacity(0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.analytics,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تحليل فجوة الإنتاج',
                style: AccountantThemeConfig.headlineSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'مقارنة الإنتاج الحالي بالهدف المطلوب',
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
        if (widget.onRefresh != null)
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: widget.onRefresh,
              icon: Icon(
                Icons.refresh,
                color: AccountantThemeConfig.primaryGreen,
              ),
              tooltip: 'تحديث البيانات',
            ),
          ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: [
        Container(
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
            ),
          ),
        ).animate().shimmer(duration: 1500.ms),
        const SizedBox(height: 20),
        Row(
          children: List.generate(2, (index) => 
            Expanded(
              child: Container(
                margin: EdgeInsets.only(right: index == 0 ? 16 : 0),
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
              ).animate(delay: (index * 200).ms).shimmer(duration: 1000.ms),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.analytics_outlined,
              size: 48,
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'لا توجد بيانات تحليل الفجوة',
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: Colors.white54,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'لم يتم العثور على بيانات الهدف المطلوب لهذا المنتج',
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white38,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: widget.onTargetUpdate,
            icon: Icon(Icons.flag),
            label: Text('تحديد الهدف'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AccountantThemeConfig.primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 800.ms).scale(begin: const Offset(0.8, 0.8));
  }

  Widget _buildGapAnalysisContent() {
    final gap = widget.gapAnalysis!;
    
    return Column(
      children: [
        _buildMainProgressCard(gap),
        const SizedBox(height: 20),
        _buildProductionMetrics(gap),
        const SizedBox(height: 20),
        _buildRemainingPiecesCard(gap),
      ],
    );
  }

  Widget _buildMainProgressCard(ProductionGapAnalysis gap) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            gap.statusColor.withOpacity(0.15),
            gap.statusColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: gap.statusColor.withOpacity(0.4),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: gap.statusColor.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'نسبة الإكمال',
                    style: AccountantThemeConfig.bodyLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${gap.completionPercentage.toStringAsFixed(1)}%',
                    style: AccountantThemeConfig.headlineLarge.copyWith(
                      color: gap.statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 36,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: gap.statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: gap.statusColor.withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      gap.isCompleted ? Icons.check_circle :
                      gap.isOverProduced ? Icons.trending_up :
                      Icons.pending_actions,
                      color: gap.statusColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        gap.statusText,
                        style: AccountantThemeConfig.bodyMedium.copyWith(
                          color: gap.statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildAnimatedProgressBar(gap),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  '${gap.currentProduction.toStringAsFixed(0)} وحدة',
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Flexible(
                child: Text(
                  '${gap.targetQuantity.toStringAsFixed(0)} وحدة',
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 800.ms, delay: 200.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildAnimatedProgressBar(ProductionGapAnalysis gap) {
    return Container(
      height: 16,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: AnimatedBuilder(
        animation: _progressAnimation,
        builder: (context, child) {
          final animatedProgress = (gap.completionPercentage / 100) * _progressAnimation.value;
          return FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: animatedProgress.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    gap.statusColor,
                    gap.statusColor.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: gap.statusColor.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductionMetrics(ProductionGapAnalysis gap) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            'الإنتاج الحالي',
            '${gap.currentProduction.toStringAsFixed(0)}',
            'وحدة',
            Icons.factory,
            AccountantThemeConfig.accentBlue,
            gap.currentProduction,
            gap.targetQuantity,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildTargetMetricCard(gap),
        ),
      ],
    );
  }

  Widget _buildTargetMetricCard(ProductionGapAnalysis gap) {
    // تحديد ما إذا كان الهدف من API أم لا (إذا كان مطابقاً لكمية المنتج)
    final isFromApi = widget.product != null &&
                     gap.targetQuantity == widget.product!.quantity.toDouble();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AccountantThemeConfig.primaryGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.flag,
                color: AccountantThemeConfig.primaryGreen,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'الهدف المطلوب',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (isFromApi) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AccountantThemeConfig.accentBlue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AccountantThemeConfig.accentBlue.withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_sync,
                    color: AccountantThemeConfig.accentBlue,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'API',
                    style: TextStyle(
                      color: AccountantThemeConfig.accentBlue,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  '${gap.targetQuantity.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'وحدة',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: 1.0, // الهدف دائماً 100%
            backgroundColor: Colors.white.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(
              AccountantThemeConfig.primaryGreen,
            ),
            minHeight: 4,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, String unit, IconData icon,
                         Color color, double currentValue, double maxValue) {
    final percentage = maxValue > 0 ? (currentValue / maxValue) : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: AccountantThemeConfig.headlineMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percentage.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ).animate().scaleX(duration: 1000.ms, curve: Curves.easeOutCubic),
        ],
      ),
    ).animate(delay: 300.ms).fadeIn(duration: 600.ms).slideY(begin: 0.3, end: 0);
  }

  Widget _buildRemainingPiecesCard(ProductionGapAnalysis gap) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: gap.statusColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              gap.isCompleted ? Icons.check_circle :
              gap.isOverProduced ? Icons.trending_up :
              Icons.pending_actions,
              size: 40,
              color: gap.statusColor,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            gap.remainingPiecesText,
            style: AccountantThemeConfig.headlineMedium.copyWith(
              color: gap.statusColor,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          if (!gap.isCompleted && !gap.isOverProduced) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.schedule,
                    color: Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'يحتاج ${gap.remainingPieces.toStringAsFixed(0)} وحدة إضافية',
                      style: AccountantThemeConfig.bodyMedium.copyWith(
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (gap.estimatedCompletionDate != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    color: AccountantThemeConfig.accentBlue,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'التاريخ المتوقع للإكمال',
                          style: AccountantThemeConfig.bodySmall.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                        Text(
                          '${gap.estimatedCompletionDate!.day}/${gap.estimatedCompletionDate!.month}/${gap.estimatedCompletionDate!.year}',
                          style: AccountantThemeConfig.bodyMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ).animate(delay: 400.ms).fadeIn(duration: 800.ms).slideY(begin: 0.3, end: 0);
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        if (widget.onTargetUpdate != null)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: widget.onTargetUpdate,
              icon: Icon(Icons.flag),
              label: Text('تحديث الهدف'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AccountantThemeConfig.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        if (widget.onTargetUpdate != null && widget.onRefresh != null)
          const SizedBox(width: 16),
        if (widget.onRefresh != null)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: widget.onRefresh,
              icon: Icon(Icons.refresh),
              label: Text('تحديث البيانات'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: BorderSide(color: Colors.white.withOpacity(0.3)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
      ],
    ).animate(delay: 600.ms).fadeIn(duration: 600.ms).slideY(begin: 0.3, end: 0);
  }
}
