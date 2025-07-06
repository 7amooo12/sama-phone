import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartbiztracker_new/models/warehouse_model.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';

/// بطاقة مخزن مخصصة لمدير المخزن
/// تعرض معلومات المخزن مع تأثيرات بصرية فاخرة
class WarehouseCard extends StatefulWidget {
  final WarehouseModel warehouse;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final int? productCount;
  final int? totalQuantity;
  final int? totalCartons; // إجمالي عدد الكراتين

  const WarehouseCard({
    super.key,
    required this.warehouse,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.productCount,
    this.totalQuantity,
    this.totalCartons,
  });

  @override
  State<WarehouseCard> createState() => _WarehouseCardState();
}

class _WarehouseCardState extends State<WarehouseCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 0.4,
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

  void _onHoverChanged(bool isHovered) {
    setState(() {
      _isHovered = isHovered;
    });
    
    if (isHovered) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: MouseRegion(
            onEnter: (_) => _onHoverChanged(true),
            onExit: (_) => _onHoverChanged(false),
            child: GestureDetector(
              onTap: widget.onTap,
              child: Container(
                decoration: BoxDecoration(
                  gradient: AccountantThemeConfig.cardGradient,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isHovered
                        ? AccountantThemeConfig.primaryGreen.withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.1),
                    width: 1.5,
                  ),
                  boxShadow: [
                    // الظل الأساسي
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                    // التوهج الأخضر عند التمرير
                    if (_isHovered)
                      BoxShadow(
                        color: AccountantThemeConfig.primaryGreen.withValues(alpha: _glowAnimation.value),
                        blurRadius: 20,
                        offset: const Offset(0, 0),
                      ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // رأس البطاقة مع أيقونة المخزن - متجاوب
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final screenWidth = MediaQuery.of(context).size.width;
                          final isTablet = screenWidth > 768;
                          final isLargePhone = screenWidth > 600;

                          // Responsive sizing
                          final headerPadding = isTablet ? 20.0 : isLargePhone ? 16.0 : 12.0;
                          final iconSize = isTablet ? 52.0 : isLargePhone ? 48.0 : 44.0;
                          final iconRadius = isTablet ? 14.0 : 12.0;
                          final iconInnerSize = isTablet ? 32.0 : isLargePhone ? 28.0 : 24.0;
                          final titleFontSize = isTablet ? 18.0 : isLargePhone ? 16.0 : 14.0;
                          final statusFontSize = isTablet ? 11.0 : 10.0;
                          final spacing = isTablet ? 16.0 : 12.0;

                          return Container(
                            padding: EdgeInsets.all(headerPadding),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AccountantThemeConfig.primaryGreen.withValues(alpha: 0.8),
                                  AccountantThemeConfig.secondaryGreen.withValues(alpha: 0.6),
                                ],
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: iconSize,
                                  height: iconSize,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(iconRadius),
                                  ),
                                  child: Icon(
                                    Icons.warehouse_rounded,
                                    color: Colors.white,
                                    size: iconInnerSize,
                                  ),
                                ),
                                SizedBox(width: spacing),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        widget.warehouse.name,
                                        style: GoogleFonts.cairo(
                                          fontSize: titleFontSize,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        maxLines: isTablet ? 2 : 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: isTablet ? 6 : 4),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: isTablet ? 10 : 8,
                                          vertical: isTablet ? 4 : 2
                                        ),
                                        decoration: BoxDecoration(
                                          color: widget.warehouse.isActive
                                              ? Colors.green.withValues(alpha: 0.3)
                                              : Colors.orange.withValues(alpha: 0.3),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          widget.warehouse.isActive ? 'نشط' : 'غير نشط',
                                          style: GoogleFonts.cairo(
                                            fontSize: statusFontSize,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      
                      // محتوى البطاقة - متجاوب
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final screenWidth = MediaQuery.of(context).size.width;
                            final isTablet = screenWidth > 768;
                            final isLargePhone = screenWidth > 600;

                            // Responsive sizing
                            final contentPadding = isTablet ? 20.0 : isLargePhone ? 16.0 : 12.0;
                            final iconSize = isTablet ? 18.0 : 16.0;
                            final addressFontSize = isTablet ? 13.0 : 12.0;
                            final spacing = isTablet ? 16.0 : 12.0;

                            return Padding(
                              padding: EdgeInsets.all(contentPadding),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // العنوان - مع تحسين overflow
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on_outlined,
                                        size: iconSize,
                                        color: AccountantThemeConfig.primaryGreen,
                                      ),
                                      SizedBox(width: isTablet ? 6 : 4),
                                      Expanded(
                                        child: Text(
                                          widget.warehouse.address,
                                          style: GoogleFonts.cairo(
                                            fontSize: addressFontSize,
                                            color: Colors.white70,
                                          ),
                                          maxLines: isTablet ? 2 : 1, // تقليل عدد الأسطر لتوفير مساحة
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),

                                  SizedBox(height: spacing * 0.75), // تقليل المسافة

                                  // إحصائيات المخزن - متجاوبة ومحسنة مع منع overflow
                                  Expanded(
                                    child: Container(
                                      padding: EdgeInsets.all(isTablet ? 8.0 : 4.0), // تقليل الحشو أكثر لتوفير مساحة
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(isTablet ? 12.0 : 8.0),
                                        border: Border.all(
                                          color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.2),
                                          width: 1,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // الصف الأول - المنتجات والكمية
                                          Flexible(
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                _buildResponsiveStatItem(
                                                  'المنتجات',
                                                  '${widget.productCount ?? 0}',
                                                  Icons.inventory_2_outlined,
                                                  isTablet,
                                                  isLargePhone,
                                                ),
                                                _buildResponsiveStatItem(
                                                  'الكمية الإجمالية',
                                                  '${widget.totalQuantity ?? 0}',
                                                  Icons.numbers_outlined,
                                                  isTablet,
                                                  isLargePhone,
                                                ),
                                              ],
                                            ),
                                          ),

                                          // فاصل مبسط
                                          SizedBox(height: isTablet ? 6 : 4), // تقليل المسافة
                                          Container(
                                            height: 1,
                                            color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.2),
                                          ),
                                          SizedBox(height: isTablet ? 6 : 4), // تقليل المسافة

                                          // الصف الثاني - إجمالي الكراتين
                                          Flexible(
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                _buildResponsiveStatItem(
                                                  'إجمالي الكراتين',
                                                  '${widget.totalCartons ?? 0}',
                                                  Icons.all_inbox_outlined,
                                                  isTablet,
                                                  isLargePhone,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  SizedBox(height: spacing * 0.3), // تقليل المسافة قبل الأزرار

                                  // أزرار الإجراءات - محسنة لمنع overflow مع تحسين الحجم
                                  LayoutBuilder(
                                    builder: (context, actionConstraints) {
                                      final availableWidth = actionConstraints.maxWidth;
                                      final actionScreenWidth = MediaQuery.of(context).size.width;
                                      final actionIsTablet = actionScreenWidth > 768;
                                      final actionIsLargePhone = actionScreenWidth > 600;

                                      // Responsive spacing and sizing - محسن للمساحة المتاحة
                                      final actionSpacing = actionIsTablet ? 6.0 : actionIsLargePhone ? 4.0 : 3.0; // تقليل المسافة
                                      final iconButtonSize = actionIsTablet ? 28.0 : actionIsLargePhone ? 24.0 : 20.0; // تقليل حجم الأزرار

                                      // Calculate available space for action button with better distribution
                                      final iconButtonsWidth = (iconButtonSize * 2) + (actionSpacing * 2);
                                      final actionButtonWidth = availableWidth - iconButtonsWidth - (actionSpacing * 2);

                                      return Container(
                                        height: actionIsTablet ? 32.0 : actionIsLargePhone ? 28.0 : 24.0, // تقليل ارتفاع الأزرار
                                        child: Row(
                                          children: [
                                            // Action button with calculated width
                                            Expanded(
                                              flex: 2, // استخدام flex بدلاً من width محدد
                                              child: _buildResponsiveActionButton(
                                                icon: Icons.visibility_outlined,
                                                label: 'عرض',
                                                onTap: widget.onTap,
                                                isTablet: actionIsTablet,
                                                isLargePhone: actionIsLargePhone,
                                              ),
                                            ),
                                            SizedBox(width: actionSpacing),
                                            _buildResponsiveIconButton(
                                              icon: Icons.edit_outlined,
                                              onTap: widget.onEdit,
                                              color: AccountantThemeConfig.accentBlue,
                                              size: iconButtonSize,
                                              isTablet: actionIsTablet,
                                            ),
                                            SizedBox(width: actionSpacing),
                                            _buildResponsiveIconButton(
                                              icon: Icons.delete_outline,
                                              onTap: widget.onDelete,
                                              color: AccountantThemeConfig.warningOrange,
                                              size: iconButtonSize,
                                              isTablet: actionIsTablet,
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// بناء عنصر إحصائي
  Widget _buildStatItem(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: AccountantThemeConfig.primaryGreen,
              ),
              const SizedBox(width: 4),
              Text(
                value,
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AccountantThemeConfig.primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 9,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// بناء عنصر إحصائي متجاوب مع تحسين منع overflow
  Widget _buildResponsiveStatItem(String label, String value, IconData icon, bool isTablet, bool isLargePhone) {
    final iconSize = isTablet ? 14.0 : isLargePhone ? 13.0 : 12.0; // تقليل حجم الأيقونة
    final valueFontSize = isTablet ? 14.0 : isLargePhone ? 13.0 : 12.0; // تقليل حجم النص
    final labelFontSize = isTablet ? 9.0 : 8.0; // تقليل حجم التسمية
    final spacing = isTablet ? 4.0 : 3.0; // تقليل المسافة

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: iconSize,
                color: AccountantThemeConfig.primaryGreen,
              ),
              SizedBox(width: spacing),
              Flexible(
                child: Text(
                  value,
                  style: GoogleFonts.cairo(
                    fontSize: valueFontSize,
                    fontWeight: FontWeight.bold,
                    color: AccountantThemeConfig.primaryGreen,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: isTablet ? 3 : 2), // تقليل المسافة
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: labelFontSize,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
            maxLines: isTablet ? 2 : 1, // تقليل عدد الأسطر لتوفير مساحة
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// بناء زر إجراء
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: AccountantThemeConfig.primaryGreen,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AccountantThemeConfig.primaryGreen,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// بناء زر أيقونة
  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback? onTap,
    required Color color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: color,
          ),
        ),
      ),
    );
  }

  /// بناء زر إجراء متجاوب محسن مع تحسين الحجم
  Widget _buildResponsiveActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    required bool isTablet,
    required bool isLargePhone,
  }) {
    final fontSize = isTablet ? 9.0 : isLargePhone ? 8.0 : 7.0; // تقليل حجم الخط
    final iconSize = isTablet ? 12.0 : isLargePhone ? 11.0 : 10.0; // تقليل حجم الأيقونة
    final verticalPadding = isTablet ? 4.0 : isLargePhone ? 3.0 : 2.0; // تقليل الحشو

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6), // تقليل نصف القطر
        child: Container(
          height: double.infinity, // استخدام الارتفاع الكامل المتاح
          padding: EdgeInsets.symmetric(vertical: verticalPadding, horizontal: 2), // تقليل الحشو الأفقي
          decoration: BoxDecoration(
            color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: iconSize,
                color: AccountantThemeConfig.primaryGreen,
              ),
              const SizedBox(width: 2), // تقليل المسافة أكثر
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.cairo(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                    color: AccountantThemeConfig.primaryGreen,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// بناء زر أيقونة متجاوب مع تحسين الحجم
  Widget _buildResponsiveIconButton({
    required IconData icon,
    required VoidCallback? onTap,
    required Color color,
    required double size,
    required bool isTablet,
  }) {
    final iconSize = isTablet ? 14.0 : 12.0; // تقليل حجم الأيقونة
    final borderRadius = isTablet ? 8.0 : 6.0; // تقليل نصف القطر

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: Icon(
            icon,
            size: iconSize,
            color: color,
          ),
        ),
      ),
    );
  }
}
