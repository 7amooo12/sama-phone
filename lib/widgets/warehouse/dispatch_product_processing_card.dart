import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/dispatch_product_processing_model.dart';
import '../../utils/accountant_theme_config.dart';
import '../../utils/app_logger.dart';

/// بطاقة معالجة منتج في طلب الصرف
/// تعرض معلومات المنتج مع إمكانية التفاعل لإكمال المعالجة
class DispatchProductProcessingCard extends StatefulWidget {
  final DispatchProductProcessingModel product;
  final VoidCallback? onProcessingStart;
  final VoidCallback? onProcessingComplete;
  final bool isEnabled;

  const DispatchProductProcessingCard({
    super.key,
    required this.product,
    this.onProcessingStart,
    this.onProcessingComplete,
    this.isEnabled = true,
  });

  @override
  State<DispatchProductProcessingCard> createState() => _DispatchProductProcessingCardState();
}

class _DispatchProductProcessingCardState extends State<DispatchProductProcessingCard>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _progressController;
  late AnimationController _glowController;
  
  late Animation<double> _scaleAnimation;
  late Animation<double> _progressAnimation;
  late Animation<double> _glowAnimation;

  bool _isPressed = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    
    // تهيئة المتحكمات
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // تهيئة الرسوم المتحركة
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));

    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));

    // بدء الرسوم المتحركة للتوهج إذا كان المنتج مكتملاً
    if (widget.product.isCompleted) {
      _glowController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _progressController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(DispatchProductProcessingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // تحديث الرسوم المتحركة عند تغيير حالة المنتج
    if (widget.product.isCompleted && !oldWidget.product.isCompleted) {
      _glowController.repeat(reverse: true);
    } else if (!widget.product.isCompleted && oldWidget.product.isCompleted) {
      _glowController.stop();
      _glowController.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_scaleAnimation, _glowAnimation]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: AccountantThemeConfig.cardGradient,
              border: Border.all(
                color: _getBorderColor(),
                width: 2,
              ),
              boxShadow: _buildBoxShadows(),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: widget.isEnabled ? _handleTap : null,
                onTapDown: widget.isEnabled ? _handleTapDown : null,
                onTapUp: widget.isEnabled ? _handleTapUp : null,
                onTapCancel: widget.isEnabled ? _handleTapCancel : null,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildCardContent(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// بناء محتوى البطاقة
  Widget _buildCardContent() {
    return Row(
      children: [
        // صورة المنتج
        _buildProductImage(),
        const SizedBox(width: 16),
        
        // معلومات المنتج
        Expanded(
          child: _buildProductInfo(),
        ),
        
        const SizedBox(width: 16),
        
        // زر المعالجة ومؤشر التقدم
        _buildActionSection(),
      ],
    );
  }

  /// بناء صورة المنتج
  Widget _buildProductImage() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withOpacity(0.1),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: widget.product.productImageUrl != null && 
               widget.product.productImageUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: widget.product.productImageUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => _buildImagePlaceholder(),
                errorWidget: (context, url, error) => _buildImagePlaceholder(),
              )
            : _buildImagePlaceholder(),
      ),
    );
  }

  /// بناء عنصر نائب للصورة
  Widget _buildImagePlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.inventory_2_rounded,
          color: Colors.white54,
          size: 32,
        ),
      ),
    );
  }

  /// بناء معلومات المنتج
  Widget _buildProductInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // اسم المنتج
        Text(
          widget.product.productName,
          style: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),

        const SizedBox(height: 8),

        // الكمية المطلوبة والمتاحة
        Row(
          children: [
            // الكمية المطلوبة
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AccountantThemeConfig.accentBlue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AccountantThemeConfig.accentBlue.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Text(
                'مطلوب: ${widget.product.requestedQuantity}',
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AccountantThemeConfig.accentBlue,
                ),
              ),
            ),

            const SizedBox(width: 8),

            // الكمية المتاحة
            if (widget.product.hasLocationData)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.product.canFulfillRequest
                      ? AccountantThemeConfig.primaryGreen.withOpacity(0.2)
                      : Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: widget.product.canFulfillRequest
                        ? AccountantThemeConfig.primaryGreen.withOpacity(0.3)
                        : Colors.orange.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  'متاح: ${widget.product.totalAvailableQuantity}',
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: widget.product.canFulfillRequest
                        ? AccountantThemeConfig.primaryGreen
                        : Colors.orange,
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 8),

        // معلومات المواقع
        _buildLocationInfo(),

        const SizedBox(height: 8),

        // حالة المعالجة
        _buildStatusChip(),
      ],
    );
  }

  /// بناء معلومات المواقع
  Widget _buildLocationInfo() {
    if (!widget.product.hasLocationData) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.grey.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search,
              size: 12,
              color: Colors.grey,
            ),
            const SizedBox(width: 4),
            Text(
              'جاري البحث عن المواقع...',
              style: GoogleFonts.cairo(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    if (widget.product.locationSearchError != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.red.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 12,
              color: Colors.red,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'خطأ في البحث',
                style: GoogleFonts.cairo(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Colors.red,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    if (widget.product.warehouseLocations == null || widget.product.warehouseLocations!.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.orange.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber,
              size: 12,
              color: Colors.orange,
            ),
            const SizedBox(width: 4),
            Text(
              'غير متوفر في أي مخزن',
              style: GoogleFonts.cairo(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Colors.orange,
              ),
            ),
          ],
        ),
      );
    }

    // عرض معلومات المواقع
    final locations = widget.product.warehouseLocations!;
    final primaryLocation = locations.first;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AccountantThemeConfig.primaryGreen.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.location_on,
            size: 12,
            color: AccountantThemeConfig.primaryGreen,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              locations.length == 1
                  ? primaryLocation.warehouseName
                  : '${primaryLocation.warehouseName} +${locations.length - 1}',
              style: GoogleFonts.cairo(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AccountantThemeConfig.primaryGreen,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (locations.length > 1)
            Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${locations.length}',
                style: GoogleFonts.cairo(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// بناء شريحة الحالة
  Widget _buildStatusChip() {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (widget.product.isCompleted) {
      statusColor = AccountantThemeConfig.primaryGreen;
      statusText = 'مكتمل';
      statusIcon = Icons.check_circle;
    } else if (widget.product.isProcessing || _isProcessing) {
      statusColor = const Color(0xFFF59E0B);
      statusText = 'قيد المعالجة';
      statusIcon = Icons.hourglass_empty;
    } else {
      statusColor = Colors.grey;
      statusText = 'في الانتظار';
      statusIcon = Icons.pending;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            statusIcon,
            size: 12,
            color: statusColor,
          ),
          const SizedBox(width: 4),
          Text(
            statusText,
            style: GoogleFonts.cairo(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  /// بناء قسم الإجراءات
  Widget _buildActionSection() {
    if (widget.product.isCompleted) {
      return _buildCompletedIndicator();
    }

    if (widget.product.isProcessing || _isProcessing) {
      return _buildProgressIndicator();
    }

    return _buildProcessButton();
  }

  /// بناء مؤشر الإكمال
  Widget _buildCompletedIndicator() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AccountantThemeConfig.greenGradient,
        boxShadow: [
          BoxShadow(
            color: AccountantThemeConfig.primaryGreen.withOpacity(_glowAnimation.value * 0.6),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Center(
        child: Icon(
          Icons.check,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }

  /// بناء مؤشر التقدم
  Widget _buildProgressIndicator() {
    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        children: [
          // دائرة التقدم
          Center(
            child: SizedBox(
              width: 50,
              height: 50,
              child: AnimatedBuilder(
                animation: _progressAnimation,
                builder: (context, child) {
                  return CircularProgressIndicator(
                    value: _progressAnimation.value,
                    strokeWidth: 4,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AccountantThemeConfig.primaryGreen,
                    ),
                  );
                },
              ),
            ),
          ),
          
          // نسبة التقدم
          Center(
            child: AnimatedBuilder(
              animation: _progressAnimation,
              builder: (context, child) {
                return Text(
                  '${(_progressAnimation.value * 100).toInt()}%',
                  style: GoogleFonts.cairo(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// بناء زر المعالجة
  Widget _buildProcessButton() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: widget.isEnabled 
            ? AccountantThemeConfig.greenGradient
            : LinearGradient(
                colors: [Colors.grey.shade600, Colors.grey.shade700],
              ),
        boxShadow: widget.isEnabled ? [
          BoxShadow(
            color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 1,
          ),
        ] : [],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: widget.isEnabled ? _startProcessing : null,
          customBorder: const CircleBorder(),
          child: const Center(
            child: Icon(
              Icons.play_arrow,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }

  /// الحصول على لون الحدود
  Color _getBorderColor() {
    if (widget.product.isCompleted) {
      return AccountantThemeConfig.primaryGreen.withOpacity(_glowAnimation.value);
    }
    if (widget.product.isProcessing || _isProcessing) {
      return const Color(0xFFF59E0B).withOpacity(0.6);
    }
    return Colors.white.withOpacity(0.1);
  }

  /// بناء ظلال الصندوق
  List<BoxShadow> _buildBoxShadows() {
    if (widget.product.isCompleted) {
      return [
        BoxShadow(
          color: AccountantThemeConfig.primaryGreen.withOpacity(_glowAnimation.value * 0.3),
          blurRadius: 20,
          spreadRadius: 2,
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ];
    }
    
    return [
      BoxShadow(
        color: Colors.black.withOpacity(0.2),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ];
  }

  /// معالجة النقر
  void _handleTap() {
    if (!widget.isEnabled || widget.product.isCompleted || _isProcessing) return;
    
    AppLogger.info('🎯 تم النقر على بطاقة المنتج: ${widget.product.productName}');
    _startProcessing();
  }

  /// معالجة بداية النقر
  void _handleTapDown(TapDownDetails details) {
    if (!widget.isEnabled) return;
    setState(() => _isPressed = true);
    _scaleController.forward();
  }

  /// معالجة نهاية النقر
  void _handleTapUp(TapUpDetails details) {
    if (!widget.isEnabled) return;
    setState(() => _isPressed = false);
    _scaleController.reverse();
  }

  /// معالجة إلغاء النقر
  void _handleTapCancel() {
    if (!widget.isEnabled) return;
    setState(() => _isPressed = false);
    _scaleController.reverse();
  }

  /// بدء المعالجة
  Future<void> _startProcessing() async {
    if (_isProcessing || widget.product.isCompleted) return;

    setState(() => _isProcessing = true);
    
    // تشغيل الاهتزاز
    HapticFeedback.mediumImpact();
    
    // إشعار الوالد ببدء المعالجة
    widget.onProcessingStart?.call();
    
    // تشغيل رسوم التقدم المتحركة
    _progressController.forward();
    
    // محاكاة عملية المعالجة
    await Future.delayed(const Duration(milliseconds: 2000));
    
    // إكمال المعالجة
    if (mounted) {
      setState(() => _isProcessing = false);
      
      // تشغيل الاهتزاز للإكمال
      HapticFeedback.heavyImpact();
      
      // إشعار الوالد بإكمال المعالجة
      widget.onProcessingComplete?.call();
      
      // بدء رسوم التوهج المتحركة
      _glowController.repeat(reverse: true);
    }
  }
}
