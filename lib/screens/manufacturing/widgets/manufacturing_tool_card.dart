import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/models/manufacturing/manufacturing_tool.dart';
import 'package:smartbiztracker_new/utils/manufacturing/tool_colors.dart' as ToolColorUtils;

/// بطاقة أداة التصنيع مع مؤشرات المخزون الذكية والتفاعل المحسن
class ManufacturingToolCard extends StatefulWidget {
  final ManufacturingTool tool;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isDraggable;

  const ManufacturingToolCard({
    super.key,
    required this.tool,
    this.onTap,
    this.onLongPress,
    this.isDraggable = false,
  });

  @override
  State<ManufacturingToolCard> createState() => _ManufacturingToolCardState();
}

class _ManufacturingToolCardState extends State<ManufacturingToolCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// معالجة الضغط على البطاقة
  void _handleTap() {
    HapticFeedback.lightImpact();
    widget.onTap?.call();
  }

  /// معالجة الضغط المطول
  void _handleLongPress() {
    HapticFeedback.mediumImpact();
    widget.onLongPress?.call();
  }

  /// معالجة بداية الضغط
  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _animationController.forward();
  }

  /// معالجة إلغاء الضغط
  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _animationController.reverse();
  }

  /// معالجة انتهاء الضغط
  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final cardContent = _buildCardContent();

    if (widget.isDraggable) {
      return Draggable<ManufacturingTool>(
        data: widget.tool,
        feedback: Material(
          color: Colors.transparent,
          child: Transform.scale(
            scale: 1.1,
            child: Container(
              width: 160,
              height: 200,
              child: cardContent,
            ),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.5,
          child: cardContent,
        ),
        child: cardContent,
      );
    }

    return cardContent;
  }

  /// بناء محتوى البطاقة
  Widget _buildCardContent() {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTap: _handleTap,
            onLongPress: _handleLongPress,
            onTapDown: _handleTapDown,
            onTapCancel: _handleTapCancel,
            onTapUp: _handleTapUp,
            child: Container(
              decoration: BoxDecoration(
                gradient: AccountantThemeConfig.cardGradient,
                borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                border: AccountantThemeConfig.glowBorder(widget.tool.stockIndicatorColor),
                boxShadow: [
                  ...AccountantThemeConfig.cardShadows,
                  if (_isPressed)
                    BoxShadow(
                      color: widget.tool.stockIndicatorColor.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  Expanded(
                    flex: 2,
                    child: _buildImage(),
                  ),
                  Expanded(
                    flex: 2,
                    child: _buildContent(),
                  ),
                  _buildProgressIndicator(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// بناء رأس البطاقة مع الكمية
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // أيقونة الحالة
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: widget.tool.stockIndicatorColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              widget.tool.stockStatusIcon,
              color: widget.tool.stockIndicatorColor,
              size: 16,
            ),
          ),
          
          // الكمية والوحدة
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  widget.tool.stockIndicatorColor.withOpacity(0.8),
                  widget.tool.stockIndicatorColor,
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: widget.tool.stockIndicatorColor.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              '${widget.tool.quantity.toStringAsFixed(widget.tool.quantity.truncateToDouble() == widget.tool.quantity ? 0 : 1)} ${widget.tool.unit}',
              style: AccountantThemeConfig.bodySmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// بناء صورة الأداة
  Widget _buildImage() {
    return Expanded(
      flex: 2,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: widget.tool.imageUrl != null && widget.tool.imageUrl!.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: _getToolImageUrl(),
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[300],
                    child: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => _buildDefaultIcon(),
                ),
              )
            : _buildDefaultIcon(),
      ),
    );
  }

  /// Helper method to get properly formatted image URL for manufacturing tools
  String _getToolImageUrl() {
    if (widget.tool.imageUrl == null || widget.tool.imageUrl!.isEmpty) {
      return '';
    }

    final imageUrl = widget.tool.imageUrl!;
    if (imageUrl.startsWith('http')) {
      return imageUrl;
    } else {
      return 'https://samastock.pythonanywhere.com/static/uploads/$imageUrl';
    }
  }

  /// بناء أيقونة افتراضية
  Widget _buildDefaultIcon() {
    return Center(
      child: Icon(
        Icons.build_circle_outlined,
        size: 48,
        color: widget.tool.stockIndicatorColor.withOpacity(0.7),
      ),
    );
  }

  /// بناء محتوى البطاقة
  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // Prevent overflow by using minimum space
        children: [
          // اسم الأداة
          Text(
            widget.tool.name,
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textDirection: TextDirection.rtl,
          ),

          const SizedBox(height: 4),

          // معلومات إضافية
          Row(
            children: [
              if (widget.tool.color != null) ...[
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: ToolColors.getColorValue(widget.tool.color!),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white54, width: 1),
                  ),
                ),
                const SizedBox(width: 6),
              ],

              Expanded(
                child: Text(
                  widget.tool.stockStatusText,
                  style: AccountantThemeConfig.bodySmall.copyWith(
                    color: widget.tool.stockIndicatorColor,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1, // Limit to single line to prevent overflow
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// بناء مؤشر التقدم
  Widget _buildProgressIndicator() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 12), // Reduced top margin
      child: Column(
        mainAxisSize: MainAxisSize.min, // Use minimum space
        children: [
          // شريط التقدم
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(3),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeInOut,
                      width: constraints.maxWidth * (widget.tool.stockPercentage / 100),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            widget.tool.stockIndicatorColor.withOpacity(0.8),
                            widget.tool.stockIndicatorColor,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: [
                          BoxShadow(
                            color: widget.tool.stockIndicatorColor.withOpacity(0.4),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 4), // Reduced spacing

          // نسبة المخزون
          Text(
            '${widget.tool.stockPercentage.toStringAsFixed(0)}%',
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// بطاقة أداة مبسطة للعرض السريع
class SimpleManufacturingToolCard extends StatelessWidget {
  final ManufacturingTool tool;
  final VoidCallback? onTap;

  const SimpleManufacturingToolCard({
    super.key,
    required this.tool,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: AccountantThemeConfig.cardGradient,
          borderRadius: BorderRadius.circular(8),
          border: AccountantThemeConfig.glowBorder(tool.stockIndicatorColor),
        ),
        child: Row(
          children: [
            Icon(
              tool.stockStatusIcon,
              color: tool.stockIndicatorColor,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tool.name,
                    style: AccountantThemeConfig.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${tool.quantity} ${tool.unit}',
                    style: AccountantThemeConfig.bodySmall.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: tool.stockIndicatorColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${tool.stockPercentage.toStringAsFixed(0)}%',
                style: AccountantThemeConfig.bodySmall.copyWith(
                  color: tool.stockIndicatorColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
