import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// Professional loading widget for warehouse reports with progress tracking
class WarehouseReportsLoader extends StatefulWidget {
  final String stage;
  final double progress;
  final String message;
  final String? subMessage;
  final int? currentItem;
  final int? totalItems;
  final bool showProgress;
  final VoidCallback? onCancel;

  const WarehouseReportsLoader({
    super.key,
    required this.stage,
    this.progress = 0.0,
    this.message = 'جاري تحميل التقارير...',
    this.subMessage,
    this.currentItem,
    this.totalItems,
    this.showProgress = true,
    this.onCancel,
  });

  @override
  State<WarehouseReportsLoader> createState() => _WarehouseReportsLoaderState();
}

class _WarehouseReportsLoaderState extends State<WarehouseReportsLoader>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _rotationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.linear,
    ));

    _pulseController.repeat(reverse: true);
    _rotationController.repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AccountantThemeConfig.mainBackgroundGradient,
      ),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: AccountantThemeConfig.cardGradient,
            borderRadius: BorderRadius.circular(20),
            border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
            boxShadow: [
              ...AccountantThemeConfig.cardShadows,
              BoxShadow(
                color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Loading Icon with Animation
              _buildAnimatedIcon(),
              
              const SizedBox(height: 24),
              
              // Main Message
              Text(
                widget.message,
                style: AccountantThemeConfig.headlineSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              
              if (widget.subMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  widget.subMessage!,
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    color: Colors.white.withOpacity(0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              
              const SizedBox(height: 24),
              
              // Progress Section
              if (widget.showProgress) _buildProgressSection(),
              
              // Stage Information
              _buildStageInfo(),
              
              // Cancel Button (if provided)
              if (widget.onCancel != null) ...[
                const SizedBox(height: 24),
                _buildCancelButton(),
              ],
            ],
          ),
        ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.8, 0.8)),
      ),
    );
  }

  Widget _buildAnimatedIcon() {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnimation, _rotationAnimation]),
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Transform.rotate(
            angle: _rotationAnimation.value * 2 * 3.14159,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AccountantThemeConfig.primaryGreen,
                    AccountantThemeConfig.accentBlue,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AccountantThemeConfig.primaryGreen.withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.analytics_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressSection() {
    return Column(
      children: [
        // Progress Bar
        Container(
          width: double.infinity,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: Colors.white.withOpacity(0.2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: widget.progress,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(
                AccountantThemeConfig.primaryGreen,
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Progress Text
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${(widget.progress * 100).toInt()}%',
              style: AccountantThemeConfig.bodySmall.copyWith(
                color: AccountantThemeConfig.primaryGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (widget.currentItem != null && widget.totalItems != null)
              Text(
                '${widget.currentItem}/${widget.totalItems}',
                style: AccountantThemeConfig.bodySmall.copyWith(
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildStageInfo() {
    final stageInfo = _getStageInfo(widget.stage);
    
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            stageInfo['icon'] as IconData,
            color: stageInfo['color'] as Color,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            stageInfo['text'] as String,
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelButton() {
    return TextButton.icon(
      onPressed: widget.onCancel,
      icon: const Icon(Icons.cancel_outlined, size: 18),
      label: const Text('إلغاء'),
      style: TextButton.styleFrom(
        foregroundColor: AccountantThemeConfig.warningOrange,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  Map<String, dynamic> _getStageInfo(String stage) {
    switch (stage) {
      case 'warehouses':
        return {
          'icon': Icons.warehouse_rounded,
          'color': AccountantThemeConfig.accentBlue,
          'text': 'تحميل بيانات المخازن',
        };
      case 'api_products':
        return {
          'icon': Icons.api_rounded,
          'color': AccountantThemeConfig.primaryGreen,
          'text': 'تحميل منتجات API',
        };
      case 'inventory':
        return {
          'icon': Icons.inventory_rounded,
          'color': AccountantThemeConfig.warningOrange,
          'text': 'تحليل المخزون',
        };
      case 'analysis':
        return {
          'icon': Icons.analytics_rounded,
          'color': AccountantThemeConfig.successGreen,
          'text': 'إجراء التحليل',
        };
      case 'finalizing':
        return {
          'icon': Icons.check_circle_rounded,
          'color': AccountantThemeConfig.successGreen,
          'text': 'إنهاء التقرير',
        };
      default:
        return {
          'icon': Icons.hourglass_empty_rounded,
          'color': Colors.white,
          'text': 'جاري المعالجة',
        };
    }
  }
}

/// Progress tracking service for warehouse reports
class WarehouseReportsProgressService {
  static final WarehouseReportsProgressService _instance = WarehouseReportsProgressService._internal();
  factory WarehouseReportsProgressService() => _instance;
  WarehouseReportsProgressService._internal();

  String _currentStage = '';
  double _currentProgress = 0.0;
  String _currentMessage = '';
  String? _currentSubMessage;
  int? _currentItem;
  int? _totalItems;

  // Getters
  String get currentStage => _currentStage;
  double get currentProgress => _currentProgress;
  String get currentMessage => _currentMessage;
  String? get currentSubMessage => _currentSubMessage;
  int? get currentItem => _currentItem;
  int? get totalItems => _totalItems;

  void updateProgress({
    String? stage,
    double? progress,
    String? message,
    String? subMessage,
    int? currentItem,
    int? totalItems,
  }) {
    if (stage != null) _currentStage = stage;
    if (progress != null) _currentProgress = progress.clamp(0.0, 1.0);
    if (message != null) _currentMessage = message;
    if (subMessage != null) _currentSubMessage = subMessage;
    if (currentItem != null) _currentItem = currentItem;
    if (totalItems != null) _totalItems = totalItems;

    AppLogger.info('📊 تحديث تقدم التقرير: $_currentStage - ${(_currentProgress * 100).toInt()}% - $_currentMessage');
  }

  void reset() {
    _currentStage = '';
    _currentProgress = 0.0;
    _currentMessage = '';
    _currentSubMessage = null;
    _currentItem = null;
    _totalItems = null;
  }
}
