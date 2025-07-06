import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:percent_indicator/percent_indicator.dart';

/// Enhanced loading widget with multiple loading states and animations
class EnhancedLoadingWidget extends StatefulWidget {
  const EnhancedLoadingWidget({
    super.key,
    this.loadingType = LoadingType.spinner,
    this.progress = 0.0,
    this.message = 'جاري التحميل...',
    this.subMessage,
    this.color,
    this.backgroundColor,
    this.size = LoadingSize.medium,
    this.showPercentage = true,
    this.animationDuration = const Duration(milliseconds: 300),
  });

  final LoadingType loadingType;
  final double progress; // 0.0 to 1.0
  final String message;
  final String? subMessage;
  final Color? color;
  final Color? backgroundColor;
  final LoadingSize size;
  final bool showPercentage;
  final Duration animationDuration;

  @override
  State<EnhancedLoadingWidget> createState() => _EnhancedLoadingWidgetState();
}

class _EnhancedLoadingWidgetState extends State<EnhancedLoadingWidget>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _progressController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    
    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _progressController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.linear,
    ));

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: widget.progress,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));

    _rotationController.repeat();
    _pulseController.repeat(reverse: true);
    _progressController.forward();
  }

  @override
  void didUpdateWidget(EnhancedLoadingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _progressAnimation = Tween<double>(
        begin: oldWidget.progress,
        end: widget.progress,
      ).animate(CurvedAnimation(
        parent: _progressController,
        curve: Curves.easeInOut,
      ));
      _progressController.reset();
      _progressController.forward();
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.color ?? const Color(0xFF10B981);
    final bgColor = widget.backgroundColor ?? Colors.grey.shade800;
    final sizeConfig = _getSizeConfig();

    return Container(
      padding: EdgeInsets.all(sizeConfig.padding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Loading indicator based on type
          _buildLoadingIndicator(primaryColor, bgColor, sizeConfig),

          SizedBox(height: sizeConfig.spacing),

          // Main message
          Text(
            widget.message,
            style: TextStyle(
              fontSize: sizeConfig.titleFontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: 'Cairo',
            ),
            textAlign: TextAlign.center,
          ),

          if (widget.subMessage != null) ...[
            SizedBox(height: sizeConfig.spacing / 2),
            Text(
              widget.subMessage!,
              style: TextStyle(
                fontSize: sizeConfig.subtitleFontSize,
                color: Colors.grey.shade400,
                fontFamily: 'Cairo',
              ),
              textAlign: TextAlign.center,
            ),
          ],

          // Progress indicator for progress type
          if (widget.loadingType == LoadingType.progress) ...[
            SizedBox(height: sizeConfig.spacing),
            _buildProgressIndicator(primaryColor, bgColor, sizeConfig),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator(Color primaryColor, Color bgColor, SizeConfig sizeConfig) {
    switch (widget.loadingType) {
      case LoadingType.spinner:
        return SpinKitFadingCircle(
          size: sizeConfig.iconSize,
          color: primaryColor,
        );

      case LoadingType.pulse:
        return AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                width: sizeConfig.iconSize,
                height: sizeConfig.iconSize,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: primaryColor,
                    width: 3,
                  ),
                ),
                child: Icon(
                  Icons.analytics,
                  color: primaryColor,
                  size: sizeConfig.iconSize * 0.5,
                ),
              ),
            );
          },
        );

      case LoadingType.rotation:
        return AnimatedBuilder(
          animation: _rotationAnimation,
          builder: (context, child) {
            return Transform.rotate(
              angle: _rotationAnimation.value * 2 * 3.14159,
              child: Container(
                width: sizeConfig.iconSize,
                height: sizeConfig.iconSize,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryColor,
                      primaryColor.withOpacity(0.3),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.refresh,
                  color: Colors.white,
                  size: sizeConfig.iconSize * 0.5,
                ),
              ),
            );
          },
        );

      case LoadingType.progress:
        return AnimatedBuilder(
          animation: _progressAnimation,
          builder: (context, child) {
            return CircularPercentIndicator(
              radius: sizeConfig.iconSize / 2,
              lineWidth: 8.0,
              percent: _progressAnimation.value,
              center: widget.showPercentage
                  ? Text(
                      '${(_progressAnimation.value * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: sizeConfig.percentageFontSize,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                        fontFamily: 'Cairo',
                      ),
                    )
                  : Icon(
                      Icons.hourglass_empty,
                      color: primaryColor,
                      size: sizeConfig.iconSize * 0.3,
                    ),
              progressColor: primaryColor,
              backgroundColor: bgColor,
              circularStrokeCap: CircularStrokeCap.round,
              animation: true,
              animationDuration: widget.animationDuration.inMilliseconds,
            );
          },
        );

      case LoadingType.dots:
        return SpinKitThreeBounce(
          size: sizeConfig.iconSize * 0.3,
          color: primaryColor,
        );
    }
  }

  Widget _buildProgressIndicator(Color primaryColor, Color bgColor, SizeConfig sizeConfig) {
    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          height: 6,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(3),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: _progressAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primaryColor,
                    primaryColor.withOpacity(0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        );
      },
    );
  }

  SizeConfig _getSizeConfig() {
    switch (widget.size) {
      case LoadingSize.small:
        return SizeConfig(
          iconSize: 40,
          padding: 16,
          spacing: 12,
          titleFontSize: 14,
          subtitleFontSize: 12,
          percentageFontSize: 12,
        );
      case LoadingSize.medium:
        return SizeConfig(
          iconSize: 60,
          padding: 24,
          spacing: 16,
          titleFontSize: 16,
          subtitleFontSize: 14,
          percentageFontSize: 14,
        );
      case LoadingSize.large:
        return SizeConfig(
          iconSize: 80,
          padding: 32,
          spacing: 20,
          titleFontSize: 18,
          subtitleFontSize: 16,
          percentageFontSize: 16,
        );
    }
  }
}

class SizeConfig {
  final double iconSize;
  final double padding;
  final double spacing;
  final double titleFontSize;
  final double subtitleFontSize;
  final double percentageFontSize;

  SizeConfig({
    required this.iconSize,
    required this.padding,
    required this.spacing,
    required this.titleFontSize,
    required this.subtitleFontSize,
    required this.percentageFontSize,
  });
}

enum LoadingType {
  spinner,
  pulse,
  rotation,
  progress,
  dots,
}

enum LoadingSize {
  small,
  medium,
  large,
}
