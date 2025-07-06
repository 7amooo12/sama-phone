import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';

/// Custom loader widget with consistent styling
class CustomLoader extends StatefulWidget {
  final String? message;
  final double size;
  final Color? color;
  final bool showMessage;
  final EdgeInsetsGeometry? padding;

  const CustomLoader({
    super.key,
    this.message,
    this.size = 40.0,
    this.color,
    this.showMessage = true,
    this.padding,
  });

  @override
  State<CustomLoader> createState() => _CustomLoaderState();
}

class _CustomLoaderState extends State<CustomLoader>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));

    _scaleController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loaderColor = widget.color ?? AccountantThemeConfig.primaryGreen;
    
    return Container(
      padding: widget.padding ?? const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated loader
          AnimatedBuilder(
            animation: _rotationController,
            builder: (context, child) {
              return AnimatedBuilder(
                animation: _scaleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Transform.rotate(
                      angle: _rotationController.value * 2 * 3.14159,
                      child: Container(
                        width: widget.size,
                        height: widget.size,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              loaderColor,
                              loaderColor.withOpacity(0.3),
                              loaderColor,
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: loaderColor.withOpacity(0.3),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Container(
                            width: widget.size * 0.6,
                            height: widget.size * 0.6,
                            decoration: BoxDecoration(
                              color: AccountantThemeConfig.luxuryBlack,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.hourglass_empty_rounded,
                              color: loaderColor,
                              size: widget.size * 0.3,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          
          // Loading message
          if (widget.showMessage && widget.message != null) ...[
            const SizedBox(height: AccountantThemeConfig.defaultPadding),
            Text(
              widget.message!,
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// Full screen overlay loader
class FullScreenLoader extends StatelessWidget {
  final String? message;
  final bool isVisible;
  final Color? backgroundColor;

  const FullScreenLoader({
    super.key,
    this.message,
    this.isVisible = true,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return Container(
      color: backgroundColor ?? Colors.black.withOpacity(0.7),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(AccountantThemeConfig.largePadding),
          decoration: BoxDecoration(
            gradient: AccountantThemeConfig.cardGradient,
            borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
            border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
            boxShadow: AccountantThemeConfig.cardShadows,
          ),
          child: CustomLoader(
            message: message ?? 'جاري التحميل...',
            size: 60,
          ),
        ),
      ),
    );
  }
}

/// Small inline loader
class InlineLoader extends StatelessWidget {
  final String? message;
  final double size;
  final Color? color;

  const InlineLoader({
    super.key,
    this.message,
    this.size = 20.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              color ?? AccountantThemeConfig.primaryGreen,
            ),
          ),
        ),
        if (message != null) ...[
          const SizedBox(width: AccountantThemeConfig.smallPadding),
          Text(
            message!,
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: Colors.white70,
            ),
          ),
        ],
      ],
    );
  }
}

/// Card loader for loading states in cards
class CardLoader extends StatelessWidget {
  final double height;
  final String? message;

  const CardLoader({
    super.key,
    this.height = 200,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Center(
        child: CustomLoader(
          message: message ?? 'جاري تحميل البيانات...',
          size: 50,
        ),
      ),
    );
  }
}

/// Button loader for loading states in buttons
class ButtonLoader extends StatelessWidget {
  final Color? color;
  final double size;

  const ButtonLoader({
    super.key,
    this.color,
    this.size = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(
          color ?? Colors.white,
        ),
      ),
    );
  }
}
