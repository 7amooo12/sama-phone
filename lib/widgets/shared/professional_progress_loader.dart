import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';

/// Professional progress loader widget with modern design
class ProfessionalProgressLoader extends StatefulWidget {
  final String message;
  final Color? color;
  final double size;
  final bool showMessage;

  const ProfessionalProgressLoader({
    super.key,
    this.message = 'جاري التحميل...',
    this.color,
    this.size = 50.0,
    this.showMessage = true,
  });

  @override
  State<ProfessionalProgressLoader> createState() => _ProfessionalProgressLoaderState();
}

class _ProfessionalProgressLoaderState extends State<ProfessionalProgressLoader>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _scaleController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.linear,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));

    _rotationController.repeat();
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
    final effectiveColor = widget.color ?? AccountantThemeConfig.primaryGreen;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Animated loader
        AnimatedBuilder(
          animation: Listenable.merge([_rotationAnimation, _scaleAnimation]),
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Transform.rotate(
                angle: _rotationAnimation.value * 2 * 3.14159,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        effectiveColor,
                        effectiveColor.withOpacity(0.3),
                        effectiveColor,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: effectiveColor.withOpacity(0.3),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: widget.size * 0.6,
                      height: widget.size * 0.6,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.hourglass_empty,
                        color: effectiveColor,
                        size: widget.size * 0.3,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),

        // Message
        if (widget.showMessage) ...[
          const SizedBox(height: 16),
          Text(
            widget.message,
            style: GoogleFonts.cairo(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.9),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

/// Simple circular progress indicator with SAMA branding
class SimpleProgressLoader extends StatelessWidget {
  final String? message;
  final Color? color;
  final double size;

  const SimpleProgressLoader({
    super.key,
    this.message,
    this.color,
    this.size = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AccountantThemeConfig.primaryGreen;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: 3.0,
            valueColor: AlwaysStoppedAnimation<Color>(effectiveColor),
            backgroundColor: effectiveColor.withOpacity(0.2),
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 8),
          Text(
            message!,
            style: GoogleFonts.cairo(
              fontSize: 12,
              color: Colors.white.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

/// Loading overlay for full screen loading states
class LoadingOverlay extends StatelessWidget {
  final String message;
  final bool isVisible;
  final Widget child;

  const LoadingOverlay({
    super.key,
    required this.child,
    this.message = 'جاري التحميل...',
    this.isVisible = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isVisible)
          Container(
            color: Colors.black.withOpacity(0.7),
            child: Center(
              child: ProfessionalProgressLoader(
                message: message,
              ),
            ),
          ),
      ],
    );
  }
}
