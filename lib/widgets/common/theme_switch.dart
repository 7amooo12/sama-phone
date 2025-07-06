import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/utils/style_system.dart';
import 'package:smartbiztracker_new/utils/theme_provider_new.dart';

/// ويدجت للتبديل بين الوضع الفاتح والوضع الداكن
class ThemeSwitch extends StatelessWidget {
  
  const ThemeSwitch({
    super.key,
    this.size = 40,
    this.lightModeColor,
    this.darkModeColor,
    this.backgroundColor,
    this.animationDuration = const Duration(milliseconds: 500),
    this.animationCurve = Curves.easeInOut,
    this.showText = false,
    this.lightModeText,
    this.darkModeText,
    this.textStyle,
    this.elevation = 0,
    this.borderRadius,
    this.padding = const EdgeInsets.all(8),
    this.onChanged,
  });
  final double size;
  final Color? lightModeColor;
  final Color? darkModeColor;
  final Color? backgroundColor;
  final Duration animationDuration;
  final Curve animationCurve;
  final bool showText;
  final String? lightModeText;
  final String? darkModeText;
  final TextStyle? textStyle;
  final double elevation;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onChanged;
  
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProviderNew>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final theme = Theme.of(context);
    
    final defaultLightModeColor = lightModeColor ?? Colors.amber;
    final defaultDarkModeColor = darkModeColor ?? Colors.indigo;
    final defaultBackgroundColor = backgroundColor ?? theme.cardColor;
    final defaultBorderRadius = borderRadius ?? BorderRadius.circular(size / 2);
    
    return InkWell(
      onTap: () {
        // Theme switching disabled - permanent dark mode
        if (onChanged != null) onChanged!();
      },
      borderRadius: defaultBorderRadius,
      child: AnimatedContainer(
        duration: animationDuration,
        curve: animationCurve,
        width: showText ? null : size,
        height: size,
        padding: padding,
        decoration: BoxDecoration(
          color: defaultBackgroundColor,
          borderRadius: defaultBorderRadius,
          boxShadow: elevation > 0
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1 * elevation),
                    blurRadius: 4 * elevation,
                    spreadRadius: 1 * elevation,
                    offset: Offset(0, 1 * elevation),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: animationDuration,
              curve: animationCurve,
              width: size - padding.horizontal,
              height: size - padding.vertical,
              decoration: BoxDecoration(
                color: isDarkMode ? defaultDarkModeColor : defaultLightModeColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: animationDuration,
                  child: isDarkMode
                      ? Icon(
                          Icons.dark_mode,
                          color: Colors.white,
                          size: (size - padding.horizontal) * 0.6,
                          key: const ValueKey('dark'),
                        )
                      : Icon(
                          Icons.light_mode,
                          color: Colors.white,
                          size: (size - padding.horizontal) * 0.6,
                          key: const ValueKey('light'),
                        ),
                ),
              ),
            ),
            if (showText) ...[
              const SizedBox(width: 8),
              AnimatedSwitcher(
                duration: animationDuration,
                child: Text(
                  isDarkMode
                      ? darkModeText ?? 'الوضع الداكن'
                      : lightModeText ?? 'الوضع الفاتح',
                  style: textStyle ??
                      StyleSystem.bodySmall.copyWith(
                        color: isDarkMode ? defaultDarkModeColor : defaultLightModeColor,
                        fontWeight: FontWeight.bold,
                      ),
                  key: ValueKey(isDarkMode ? 'dark_text' : 'light_text'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// ويدجت للتبديل بين الوضع الفاتح والوضع الداكن بتأثير متحرك
class AnimatedThemeSwitch extends StatefulWidget {
  
  const AnimatedThemeSwitch({
    super.key,
    this.size = 60,
    this.lightModeColor,
    this.darkModeColor,
    this.backgroundColor,
    this.animationDuration = const Duration(milliseconds: 800),
    this.animationCurve = Curves.elasticOut,
    this.showText = false,
    this.lightModeText,
    this.darkModeText,
    this.textStyle,
    this.elevation = 2,
    this.borderRadius,
    this.padding = const EdgeInsets.all(8),
    this.onChanged,
  });
  final double size;
  final Color? lightModeColor;
  final Color? darkModeColor;
  final Color? backgroundColor;
  final Duration animationDuration;
  final Curve animationCurve;
  final bool showText;
  final String? lightModeText;
  final String? darkModeText;
  final TextStyle? textStyle;
  final double elevation;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onChanged;
  
  @override
  State<AnimatedThemeSwitch> createState() => _AnimatedThemeSwitchState();
}

class _AnimatedThemeSwitchState extends State<AnimatedThemeSwitch> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;
  
  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    
    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: widget.animationCurve,
      ),
    );
    
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.8),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.8, end: 1.2),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 1.0),
        weight: 1,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: widget.animationCurve,
      ),
    );
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProviderNew>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final theme = Theme.of(context);
    
    final defaultLightModeColor = widget.lightModeColor ?? Colors.amber;
    final defaultDarkModeColor = widget.darkModeColor ?? Colors.indigo;
    final defaultBackgroundColor = widget.backgroundColor ?? theme.cardColor;
    final defaultBorderRadius = widget.borderRadius ?? BorderRadius.circular(widget.size / 2);
    
    return GestureDetector(
      onTap: () {
        // Theme switching disabled - permanent dark mode
        _controller.reset();
        _controller.forward();
        if (widget.onChanged != null) widget.onChanged!();
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Transform.rotate(
              angle: _rotationAnimation.value * 2 * 3.14159,
              child: Container(
                width: widget.showText ? null : widget.size,
                height: widget.size,
                padding: widget.padding,
                decoration: BoxDecoration(
                  color: defaultBackgroundColor,
                  borderRadius: defaultBorderRadius,
                  boxShadow: widget.elevation > 0
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1 * widget.elevation),
                            blurRadius: 4 * widget.elevation,
                            spreadRadius: 1 * widget.elevation,
                            offset: Offset(0, 1 * widget.elevation),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: widget.size - widget.padding.horizontal,
                      height: widget.size - widget.padding.vertical,
                      decoration: BoxDecoration(
                        color: isDarkMode ? defaultDarkModeColor : defaultLightModeColor,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: widget.animationDuration,
                          child: isDarkMode
                              ? Icon(
                                  Icons.dark_mode,
                                  color: Colors.white,
                                  size: (widget.size - widget.padding.horizontal) * 0.6,
                                  key: const ValueKey('dark'),
                                )
                              : Icon(
                                  Icons.light_mode,
                                  color: Colors.white,
                                  size: (widget.size - widget.padding.horizontal) * 0.6,
                                  key: const ValueKey('light'),
                                ),
                        ),
                      ),
                    ),
                    if (widget.showText) ...[
                      const SizedBox(width: 8),
                      AnimatedSwitcher(
                        duration: widget.animationDuration,
                        child: Text(
                          isDarkMode
                              ? widget.darkModeText ?? 'الوضع الداكن'
                              : widget.lightModeText ?? 'الوضع الفاتح',
                          style: widget.textStyle ??
                              StyleSystem.bodySmall.copyWith(
                                color: isDarkMode ? defaultDarkModeColor : defaultLightModeColor,
                                fontWeight: FontWeight.bold,
                              ),
                          key: ValueKey(isDarkMode ? 'dark_text' : 'light_text'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
