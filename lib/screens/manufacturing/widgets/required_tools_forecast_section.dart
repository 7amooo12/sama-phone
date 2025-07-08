import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/models/manufacturing/production_batch.dart';

/// قسم توقعات الأدوات المطلوبة للإنتاج المتبقي
class RequiredToolsForecastSection extends StatefulWidget {
  final int productId;
  final double remainingPieces;
  final bool isLoading;
  final RequiredToolsForecast? forecast;
  final VoidCallback? onRefresh;
  final Function(int toolId)? onToolTap;
  final VoidCallback? onProcureTools;
  final Function(List<RequiredToolItem> tools)? onBulkProcurement;

  const RequiredToolsForecastSection({
    super.key,
    required this.productId,
    required this.remainingPieces,
    this.isLoading = false,
    this.forecast,
    this.onRefresh,
    this.onToolTap,
    this.onProcureTools,
    this.onBulkProcurement,
  });

  @override
  State<RequiredToolsForecastSection> createState() => _RequiredToolsForecastSectionState();
}

class _RequiredToolsForecastSectionState extends State<RequiredToolsForecastSection>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
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
    
    _animationController.forward();
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
            border: AccountantThemeConfig.glowBorder(Colors.white.withOpacity(0.3)),
            boxShadow: AccountantThemeConfig.cardShadows,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(),
              const SizedBox(height: 24),
              if (widget.isLoading)
                _buildLoadingState()
              else if (widget.forecast == null)
                _buildEmptyState()
              else if (widget.remainingPieces <= 0)
                _buildCompletedState()
              else if (!_isValidForecast(widget.forecast!))
                _buildErrorState()
              else ...[
                _buildForecastSummary(),
                const SizedBox(height: 24),
                _buildToolsList(),
                if (widget.forecast!.hasUnavailableTools) ...[
                  const SizedBox(height: 20),
                  _buildUnavailableToolsWarning(),
                ],
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
                Colors.purple,
                Colors.purple.withOpacity(0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.psychology,
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
                'الأدوات المطلوبة للإكمال',
                style: AccountantThemeConfig.headlineSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'توقعات الأدوات اللازمة لإنتاج ${widget.remainingPieces.toStringAsFixed(0)} وحدة',
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
                color: Colors.purple,
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
        // Loading header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'جاري تحليل متطلبات الأدوات...',
                      style: AccountantThemeConfig.bodyMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'حساب الأدوات المطلوبة لإنتاج ${widget.remainingPieces.toStringAsFixed(0)} وحدة',
                      style: AccountantThemeConfig.bodySmall.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 600.ms),
        const SizedBox(height: 20),

        // Loading skeleton for tools list
        ...List.generate(3, (index) =>
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 16,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 12,
                            width: 120,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 60,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ).animate(delay: (index * 200).ms).shimmer(duration: 1500.ms),
        ),

        // Loading timeout warning
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'إذا استغرق التحميل وقتاً طويلاً، تحقق من الاتصال بالإنترنت',
                  style: AccountantThemeConfig.bodySmall.copyWith(
                    color: Colors.orange,
                  ),
                ),
              ),
            ],
          ),
        ).animate(delay: 3000.ms).fadeIn(duration: 600.ms),
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
              Icons.psychology_outlined,
              size: 48,
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'لا توجد توقعات أدوات',
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: Colors.white54,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _getEmptyStateMessage(),
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white38,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          _buildEmptyStateActions(),
        ],
      ),
    ).animate().fadeIn(duration: 800.ms).scale(begin: const Offset(0.8, 0.8));
  }

  String _getEmptyStateMessage() {
    if (widget.remainingPieces <= 0) {
      return 'تم إكمال الإنتاج - لا توجد حاجة لأدوات إضافية';
    }
    return 'لم يتم العثور على وصفات إنتاج لهذا المنتج أو حدث خطأ في تحميل البيانات';
  }

  Widget _buildEmptyStateActions() {
    return Column(
      children: [
        if (widget.onRefresh != null)
          ElevatedButton.icon(
            onPressed: widget.onRefresh,
            icon: Icon(Icons.refresh),
            label: Text('إعادة تحميل'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _showTroubleshootingDialog(),
          icon: Icon(Icons.help_outline),
          label: Text('استكشاف الأخطاء'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: BorderSide(color: Colors.white.withOpacity(0.3)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  void _showTroubleshootingDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AccountantThemeConfig.cardColor,
        title: Row(
          children: [
            Icon(Icons.help_outline, color: Colors.blue, size: 24),
            const SizedBox(width: 12),
            Text(
              'استكشاف الأخطاء',
              style: AccountantThemeConfig.headlineSmall.copyWith(color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الأسباب المحتملة لعدم ظهور توقعات الأدوات:',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildTroubleshootingItem(
              '• لا توجد وصفات إنتاج محددة لهذا المنتج',
              'تأكد من إضافة وصفات الإنتاج في إعدادات المنتج',
            ),
            _buildTroubleshootingItem(
              '• تم إكمال الإنتاج بالفعل',
              'لا توجد حاجة لأدوات إضافية',
            ),
            _buildTroubleshootingItem(
              '• مشكلة في الاتصال بقاعدة البيانات',
              'تحقق من الاتصال بالإنترنت وحاول مرة أخرى',
            ),
            _buildTroubleshootingItem(
              '• خطأ في حساب القطع المتبقية',
              'تحقق من بيانات تحليل فجوة الإنتاج',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('حسناً', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  Widget _buildTroubleshootingItem(String title, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            description,
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.withOpacity(0.15),
            Colors.green.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle,
              size: 48,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'تم إكمال الإنتاج',
            style: AccountantThemeConfig.headlineMedium.copyWith(
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'لا توجد حاجة لأدوات إضافية',
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 800.ms).scale(begin: const Offset(0.8, 0.8));
  }

  Widget _buildForecastSummary() {
    final forecast = widget.forecast!;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            forecast.canCompleteProduction
                ? Colors.green.withOpacity(0.15)
                : Colors.red.withOpacity(0.15),
            forecast.canCompleteProduction
                ? Colors.green.withOpacity(0.05)
                : Colors.red.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: forecast.canCompleteProduction
              ? Colors.green.withOpacity(0.4)
              : Colors.red.withOpacity(0.4),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: forecast.canCompleteProduction
                      ? Colors.green.withOpacity(0.2)
                      : Colors.red.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  forecast.canCompleteProduction ? Icons.check_circle : Icons.warning,
                  color: forecast.canCompleteProduction ? Colors.green : Colors.red,
                  size: 32,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      forecast.canCompleteProduction
                          ? 'يمكن إكمال الإنتاج'
                          : 'لا يمكن إكمال الإنتاج',
                      style: AccountantThemeConfig.headlineSmall.copyWith(
                        color: forecast.canCompleteProduction ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      forecast.canCompleteProduction
                          ? 'جميع الأدوات متوفرة بالكميات المطلوبة'
                          : 'بعض الأدوات غير متوفرة أو بكميات غير كافية',
                      style: AccountantThemeConfig.bodyMedium.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildSummaryMetric(
                  'عدد الأدوات',
                  '${forecast.toolsCount}',
                  'أداة',
                  Icons.build_circle,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryMetric(
                  'القطع المتبقية',
                  '${forecast.remainingPieces.toStringAsFixed(0)}',
                  'وحدة',
                  Icons.pending_actions,
                  Colors.orange,
                ),
              ),
            ],
          ),
          if (forecast.totalCost > 0) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.attach_money,
                    color: Colors.amber,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'التكلفة المتوقعة',
                        style: AccountantThemeConfig.bodyMedium.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                      Text(
                        '${forecast.totalCost.toStringAsFixed(2)} ريال',
                        style: AccountantThemeConfig.bodyLarge.copyWith(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 800.ms, delay: 200.ms).slideY(begin: 0.2, end: 0);
  }





  Widget _buildSummaryMetric(String label, String value, String unit, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: AccountantThemeConfig.bodyLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (unit.isNotEmpty)
                  TextSpan(
                    text: ' $unit',
                    style: AccountantThemeConfig.bodySmall.copyWith(
                      color: Colors.white70,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolsList() {
    final forecast = widget.forecast!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.list_alt,
              color: Colors.purple,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'تفاصيل الأدوات المطلوبة',
              style: AccountantThemeConfig.bodyLarge.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...forecast.requiredTools.asMap().entries.map((entry) {
          final index = entry.key;
          final tool = entry.value;
          return _buildToolItem(tool, index);
        }).toList(),
      ],
    );
  }

  Widget _buildToolItem(RequiredToolItem tool, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tool.availabilityColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onToolTap != null ? () => widget.onToolTap!(tool.toolId) : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: tool.availabilityColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        tool.statusIcon,
                        color: tool.availabilityColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tool.toolName,
                            style: AccountantThemeConfig.bodyLarge.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'الوحدة: ${tool.unit}',
                            style: AccountantThemeConfig.bodySmall.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: tool.availabilityColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: tool.availabilityColor.withOpacity(0.5),
                        ),
                      ),
                      child: Text(
                        tool.availabilityText,
                        style: AccountantThemeConfig.bodySmall.copyWith(
                          color: tool.availabilityColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildToolMetric(
                              'لكل وحدة',
                              '${tool.quantityPerUnit.toStringAsFixed(2)} ${tool.unit}',
                              Icons.precision_manufacturing,
                              Colors.blue,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.white.withOpacity(0.1),
                          ),
                          Expanded(
                            child: _buildToolMetric(
                              'إجمالي مطلوب',
                              tool.quantityText,
                              Icons.inventory_2,
                              Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildToolMetric(
                              'متوفر حالياً',
                              tool.availableStockText,
                              Icons.storage,
                              Colors.green,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.white.withOpacity(0.1),
                          ),
                          Expanded(
                            child: _buildToolMetric(
                              'النقص',
                              tool.shortfall > 0 ? '${tool.shortfall.toStringAsFixed(1)} ${tool.unit}' : 'لا يوجد',
                              Icons.warning,
                              tool.shortfall > 0 ? Colors.red : Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Professional metrics row
                      Row(
                        children: [
                          Expanded(
                            child: _buildToolMetric(
                              'نسبة التوفر',
                              '${tool.availabilityPercentage.toStringAsFixed(1)}%',
                              Icons.pie_chart,
                              tool.availabilityPercentage >= 100 ? Colors.green :
                              tool.availabilityPercentage >= 50 ? Colors.orange : Colors.red,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.white.withOpacity(0.1),
                          ),
                          Expanded(
                            child: _buildToolMetric(
                              'مستوى الخطورة',
                              '${tool.riskLevel}/5',
                              Icons.speed,
                              tool.riskLevel <= 2 ? Colors.green :
                              tool.riskLevel <= 3 ? Colors.orange : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Action recommendation
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: tool.availabilityColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: tool.availabilityColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.recommend,
                        color: tool.availabilityColor,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tool.actionRecommendation,
                          style: AccountantThemeConfig.bodySmall.copyWith(
                            color: tool.availabilityColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (tool.estimatedProcurementDays > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${tool.estimatedProcurementDays} أيام',
                            style: AccountantThemeConfig.bodySmall.copyWith(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (tool.estimatedCost != null && tool.estimatedCost! > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.attach_money,
                          color: Colors.amber,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'التكلفة المتوقعة: ${tool.estimatedCost!.toStringAsFixed(2)} ريال',
                          style: AccountantThemeConfig.bodySmall.copyWith(
                            color: Colors.amber,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ).animate(delay: (index * 150).ms).fadeIn(duration: 600.ms).slideX(begin: 0.3, end: 0);
  }

  Widget _buildToolMetric(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(
          icon,
          color: color,
          size: 20,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: AccountantThemeConfig.bodySmall.copyWith(
            color: Colors.white70,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AccountantThemeConfig.bodyMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildUnavailableToolsWarning() {
    final forecast = widget.forecast!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.red.withOpacity(0.15),
            Colors.red.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.warning,
                  color: Colors.red,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'أدوات غير متوفرة (${forecast.unavailableToolsCount})',
                  style: AccountantThemeConfig.bodyLarge.copyWith(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'الأدوات التالية غير متوفرة أو بكميات غير كافية:',
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            forecast.unavailableTools.join(', '),
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.3, end: 0);
  }



  Widget _buildActionButtons() {
    final forecast = widget.forecast!;

    return Column(
      children: [
        // Primary action buttons
        Row(
          children: [
            if (widget.onProcureTools != null && forecast.hasUnavailableTools)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: widget.onProcureTools,
                  icon: Icon(Icons.shopping_cart),
                  label: Text('شراء الأدوات'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            if (widget.onBulkProcurement != null && forecast.highPriorityTools.isNotEmpty) ...[
              if (widget.onProcureTools != null && forecast.hasUnavailableTools)
                const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => widget.onBulkProcurement!(forecast.highPriorityTools),
                  icon: Icon(Icons.priority_high),
                  label: Text('شراء عاجل'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        // Secondary action buttons
        if (widget.onRefresh != null)
          OutlinedButton.icon(
            onPressed: widget.onRefresh,
            icon: Icon(Icons.refresh),
            label: Text('تحديث البيانات'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: BorderSide(color: Colors.white.withOpacity(0.3)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
      ],
    ).animate(delay: 600.ms).fadeIn(duration: 600.ms).slideY(begin: 0.3, end: 0);
  }

  /// التحقق من صحة بيانات التوقعات
  bool _isValidForecast(RequiredToolsForecast forecast) {
    try {
      // التحقق من البيانات الأساسية
      if (forecast.productId <= 0) return false;
      if (forecast.remainingPieces < 0) return false;

      // التحقق من تناسق البيانات
      if (forecast.requiredTools.isEmpty && forecast.remainingPieces > 0) {
        // قد يكون هذا صحيحاً إذا لم توجد وصفات إنتاج
        return true;
      }

      // التحقق من صحة بيانات الأدوات
      for (final tool in forecast.requiredTools) {
        if (tool.toolId <= 0) return false;
        if (tool.toolName.isEmpty) return false;
        if (tool.quantityPerUnit < 0) return false;
        if (tool.totalQuantityNeeded < 0) return false;
        if (tool.availableStock < 0) return false;
        if (tool.shortfall < 0) return false;

        // التحقق من تناسق حالة التوفر
        final expectedShortfall = tool.totalQuantityNeeded - tool.availableStock;
        if (expectedShortfall > 0 && tool.shortfall == 0) return false;
        if (expectedShortfall <= 0 && tool.shortfall > 0) return false;

        // التحقق من تناسق حالة التوفر مع النص
        if (tool.isAvailable && tool.shortfall > 0) return false;
        if (!tool.isAvailable && tool.shortfall == 0) return false;
      }

      // التحقق من تناسق إمكانية الإكمال
      final hasUnavailableTools = forecast.requiredTools.any((tool) => !tool.isAvailable);
      if (forecast.canCompleteProduction && hasUnavailableTools) return false;
      if (!forecast.canCompleteProduction && !hasUnavailableTools && forecast.requiredTools.isNotEmpty) return false;

      // التحقق من التكلفة الإجمالية
      if (forecast.totalCost < 0) return false;

      return true;
    } catch (e) {
      return false;
    }
  }

  Widget _buildErrorState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.red.withOpacity(0.15),
            Colors.red.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'خطأ في بيانات التوقعات',
            style: AccountantThemeConfig.headlineMedium.copyWith(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'تم اكتشاف تناقض في بيانات توقعات الأدوات. يرجى إعادة تحميل البيانات أو التواصل مع الدعم الفني.',
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: widget.onRefresh,
                  icon: Icon(Icons.refresh),
                  label: Text('إعادة تحميل'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showErrorDetailsDialog(),
                  icon: Icon(Icons.info_outline),
                  label: Text('تفاصيل الخطأ'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: BorderSide(color: Colors.red.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 800.ms).scale(begin: const Offset(0.8, 0.8));
  }

  void _showErrorDetailsDialog() {
    final forecast = widget.forecast;
    if (forecast == null) return;

    final errors = <String>[];

    // فحص الأخطاء المحتملة
    if (forecast.productId <= 0) {
      errors.add('معرف المنتج غير صحيح: ${forecast.productId}');
    }

    if (forecast.remainingPieces < 0) {
      errors.add('القطع المتبقية لا يمكن أن تكون سالبة: ${forecast.remainingPieces}');
    }

    for (int i = 0; i < forecast.requiredTools.length; i++) {
      final tool = forecast.requiredTools[i];
      if (tool.toolId <= 0) {
        errors.add('معرف الأداة ${i + 1} غير صحيح: ${tool.toolId}');
      }
      if (tool.toolName.isEmpty) {
        errors.add('اسم الأداة ${i + 1} فارغ');
      }
      if (tool.quantityPerUnit < 0) {
        errors.add('كمية الأداة ${tool.toolName} لكل وحدة سالبة: ${tool.quantityPerUnit}');
      }
      if (tool.isAvailable && tool.shortfall > 0) {
        errors.add('تناقض في حالة الأداة ${tool.toolName}: متوفرة ولكن يوجد نقص');
      }
    }

    final hasUnavailableTools = forecast.requiredTools.any((tool) => !tool.isAvailable);
    if (forecast.canCompleteProduction && hasUnavailableTools) {
      errors.add('تناقض: يمكن إكمال الإنتاج رغم وجود أدوات غير متوفرة');
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AccountantThemeConfig.cardColor,
        title: Row(
          children: [
            Icon(Icons.bug_report, color: Colors.red, size: 24),
            const SizedBox(width: 12),
            Text(
              'تفاصيل الخطأ',
              style: AccountantThemeConfig.headlineSmall.copyWith(color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الأخطاء المكتشفة في بيانات التوقعات:',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              constraints: BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: errors.isEmpty
                    ? [Text(
                        'لم يتم العثور على أخطاء محددة. قد تكون المشكلة في تنسيق البيانات.',
                        style: AccountantThemeConfig.bodySmall.copyWith(color: Colors.white70),
                      )]
                    : errors.map((error) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: Text(
                          '• $error',
                          style: AccountantThemeConfig.bodySmall.copyWith(
                            color: Colors.red,
                          ),
                        ),
                      )).toList(),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('حسناً', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }
}
