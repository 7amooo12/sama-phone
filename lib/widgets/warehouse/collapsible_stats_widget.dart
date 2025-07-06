import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';

/// ويدجت إحصائيات قابلة للطي والتوسيع
class CollapsibleStatsWidget extends StatefulWidget {
  final String title;
  final List<Widget> children;
  final bool initiallyExpanded;
  final IconData? icon;
  final Color? accentColor;

  const CollapsibleStatsWidget({
    Key? key,
    required this.title,
    required this.children,
    this.initiallyExpanded = true,
    this.icon,
    this.accentColor,
  }) : super(key: key);

  @override
  State<CollapsibleStatsWidget> createState() => _CollapsibleStatsWidgetState();
}

class _CollapsibleStatsWidgetState extends State<CollapsibleStatsWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;
  late Animation<double> _iconRotationAnimation;
  bool _isExpanded = true;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    
    _iconRotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.5,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    if (_isExpanded) {
      _animationController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpansion() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.accentColor ?? AccountantThemeConfig.primaryGreen;
    
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: AccountantThemeConfig.primaryCardDecoration.copyWith(
        boxShadow: AccountantThemeConfig.glowShadows(accentColor),
      ),
      child: Column(
        children: [
          // رأس القسم القابل للنقر
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _toggleExpansion,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // أيقونة القسم
                    if (widget.icon != null) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          widget.icon!,
                          color: accentColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    
                    // عنوان القسم
                    Expanded(
                      child: Text(
                        widget.title,
                        style: AccountantThemeConfig.headlineSmall,
                      ),
                    ),
                    
                    // أيقونة التوسيع/الطي
                    AnimatedBuilder(
                      animation: _iconRotationAnimation,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _iconRotationAnimation.value * 3.14159,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: accentColor,
                              size: 20,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // المحتوى القابل للطي
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: FadeTransition(
              opacity: _expandAnimation,
              child: Container(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: 16,
                ),
                child: Column(
                  children: widget.children,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ويدجت بطاقة إحصائية للاستخدام داخل CollapsibleStatsWidget مع تصميم متجاوب
class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  const StatCard({
    Key? key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // استخدام MediaQuery مباشرة بدلاً من LayoutBuilder لتجنب مشاكل intrinsic dimensions
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    // تحديد الأحجام بناءً على حجم الشاشة
    final cardPadding = isSmallScreen ? 8.0 : isTablet ? 10.0 : 12.0;
    final iconSize = isSmallScreen ? 16.0 : isTablet ? 18.0 : 20.0;
    final iconPadding = isSmallScreen ? 6.0 : 8.0;
    final spacing = isSmallScreen ? 8.0 : 12.0;
    final valueFontSize = isSmallScreen ? 14.0 : isTablet ? 16.0 : 18.0;
    final titleFontSize = isSmallScreen ? 10.0 : isTablet ? 11.0 : 12.0;
    final subtitleFontSize = isSmallScreen ? 8.0 : isTablet ? 9.0 : 10.0;

    return Container(
      padding: EdgeInsets.all(cardPadding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.1),
            color.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // أيقونة البطاقة
          Container(
            padding: EdgeInsets.all(iconPadding),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: iconSize,
            ),
          ),

          SizedBox(width: spacing),

          // محتوى البطاقة مع تقييد الارتفاع
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: GoogleFonts.cairo(
                    fontSize: valueFontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontSize: titleFontSize,
                    color: Colors.white.withOpacity(0.7),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle!,
                    style: GoogleFonts.cairo(
                      fontSize: subtitleFontSize,
                      color: color.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ويدجت شبكة الإحصائيات للاستخدام داخل CollapsibleStatsWidget مع تصميم متجاوب
class StatsGrid extends StatelessWidget {
  final List<StatCard> cards;
  final int crossAxisCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final double childAspectRatio;

  const StatsGrid({
    Key? key,
    required this.cards,
    this.crossAxisCount = 2,
    this.crossAxisSpacing = 12,
    this.mainAxisSpacing = 12,
    this.childAspectRatio = 2.5,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // استخدام MediaQuery مباشرة بدلاً من LayoutBuilder لتجنب مشاكل intrinsic dimensions
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    // تحديد المعاملات بناءً على حجم الشاشة
    final responsiveCrossAxisCount = isSmallScreen ? 1 : crossAxisCount;
    final responsiveSpacing = isSmallScreen ? 8.0 : isTablet ? 10.0 : crossAxisSpacing;
    final responsiveMainSpacing = isSmallScreen ? 8.0 : isTablet ? 10.0 : mainAxisSpacing;

    // تحديد نسبة العرض إلى الارتفاع بناءً على حجم الشاشة
    double responsiveAspectRatio;
    if (isSmallScreen) {
      responsiveAspectRatio = 3.5; // أطول للشاشات الصغيرة
    } else if (isTablet) {
      responsiveAspectRatio = 3.0; // متوسط للأجهزة اللوحية
    } else {
      responsiveAspectRatio = childAspectRatio; // الافتراضي للشاشات الكبيرة
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: responsiveCrossAxisCount,
      crossAxisSpacing: responsiveSpacing,
      mainAxisSpacing: responsiveMainSpacing,
      childAspectRatio: responsiveAspectRatio,
      children: cards,
    );
  }
}

/// ويدجت صف الإحصائيات للاستخدام داخل CollapsibleStatsWidget مع تصميم متجاوب
class StatsRow extends StatelessWidget {
  final List<StatCard> cards;
  final double spacing;

  const StatsRow({
    Key? key,
    required this.cards,
    this.spacing = 12,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // استخدام MediaQuery مباشرة بدلاً من LayoutBuilder لتجنب مشاكل intrinsic dimensions
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    // تحديد المسافة بناءً على حجم الشاشة
    final responsiveSpacing = isSmallScreen ? 6.0 : isTablet ? 8.0 : spacing;

    // للشاشات الصغيرة، استخدم تخطيط عمودي
    if (isSmallScreen) {
      return Column(
        children: cards
            .asMap()
            .entries
            .map((entry) {
              final index = entry.key;
              final card = entry.value;

              return [
                card,
                if (index < cards.length - 1) SizedBox(height: responsiveSpacing),
              ];
            })
            .expand((widgets) => widgets)
            .toList(),
      );
    }

    // للشاشات الكبيرة والمتوسطة، استخدم تخطيط أفقي
    return Row(
      children: cards
          .asMap()
          .entries
          .map((entry) {
            final index = entry.key;
            final card = entry.value;

            return [
              Expanded(child: card),
              if (index < cards.length - 1) SizedBox(width: responsiveSpacing),
            ];
          })
          .expand((widgets) => widgets)
          .toList(),
    );
  }
}
