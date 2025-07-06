import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/accountant_theme_config.dart';
import '../../models/treasury_models.dart';

class ConnectionPointSelector extends StatefulWidget {
  final ConnectionPoint? selectedPoint;
  final Function(ConnectionPoint) onPointSelected;
  final bool isVisible;
  final double cardWidth;
  final double cardHeight;

  const ConnectionPointSelector({
    super.key,
    this.selectedPoint,
    required this.onPointSelected,
    this.isVisible = true,
    this.cardWidth = 200,
    this.cardHeight = 100,
  });

  @override
  State<ConnectionPointSelector> createState() => _ConnectionPointSelectorState();
}

class _ConnectionPointSelectorState extends State<ConnectionPointSelector>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    if (widget.isVisible) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(ConnectionPointSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _selectPoint(ConnectionPoint point) {
    HapticFeedback.lightImpact();
    widget.onPointSelected(point);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return const SizedBox.shrink();

    return SizedBox(
      width: widget.cardWidth,
      height: widget.cardHeight,
      child: Stack(
        children: [
          // Top connection point
          _buildConnectionPoint(
            ConnectionPoint.top,
            Alignment.topCenter,
            const Offset(0, -8),
          ),
          
          // Bottom connection point
          _buildConnectionPoint(
            ConnectionPoint.bottom,
            Alignment.bottomCenter,
            const Offset(0, 8),
          ),
          
          // Left connection point
          _buildConnectionPoint(
            ConnectionPoint.left,
            Alignment.centerLeft,
            const Offset(-8, 0),
          ),
          
          // Right connection point
          _buildConnectionPoint(
            ConnectionPoint.right,
            Alignment.centerRight,
            const Offset(8, 0),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionPoint(
    ConnectionPoint point,
    Alignment alignment,
    Offset offset,
  ) {
    final isSelected = widget.selectedPoint == point;
    
    return Align(
      alignment: alignment,
      child: Transform.translate(
        offset: offset,
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: isSelected ? 1.3 : _pulseAnimation.value,
              child: GestureDetector(
                onTap: () => _selectPoint(point),
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            colors: [
                              AccountantThemeConfig.primaryGreen,
                              AccountantThemeConfig.primaryGreen.withOpacity(0.8),
                            ],
                          )
                        : LinearGradient(
                            colors: [
                              AccountantThemeConfig.accentBlue.withOpacity(0.8),
                              AccountantThemeConfig.accentBlue.withOpacity(0.6),
                            ],
                          ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? AccountantThemeConfig.primaryGreen
                          : AccountantThemeConfig.accentBlue,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isSelected
                                ? AccountantThemeConfig.primaryGreen
                                : AccountantThemeConfig.accentBlue)
                            .withOpacity(0.4),
                        blurRadius: isSelected ? 12 : 8,
                        spreadRadius: isSelected ? 2 : 1,
                      ),
                    ],
                  ),
                  child: Icon(
                    _getIconForPoint(point),
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  IconData _getIconForPoint(ConnectionPoint point) {
    switch (point) {
      case ConnectionPoint.top:
        return Icons.keyboard_arrow_up_rounded;
      case ConnectionPoint.bottom:
        return Icons.keyboard_arrow_down_rounded;
      case ConnectionPoint.left:
        return Icons.keyboard_arrow_left_rounded;
      case ConnectionPoint.right:
        return Icons.keyboard_arrow_right_rounded;
      case ConnectionPoint.center:
        return Icons.center_focus_strong_rounded;
    }
  }
}

// Helper widget for easy integration with treasury cards
class TreasuryConnectionPointOverlay extends StatelessWidget {
  final bool showConnectionPoints;
  final ConnectionPoint? selectedSourcePoint;
  final ConnectionPoint? selectedTargetPoint;
  final Function(ConnectionPoint)? onSourcePointSelected;
  final Function(ConnectionPoint)? onTargetPointSelected;
  final bool isSource;
  final double cardWidth;
  final double cardHeight;

  const TreasuryConnectionPointOverlay({
    super.key,
    this.showConnectionPoints = false,
    this.selectedSourcePoint,
    this.selectedTargetPoint,
    this.onSourcePointSelected,
    this.onTargetPointSelected,
    this.isSource = true,
    this.cardWidth = 200,
    this.cardHeight = 100,
  });

  @override
  Widget build(BuildContext context) {
    if (!showConnectionPoints) return const SizedBox.shrink();

    return Positioned.fill(
      child: ConnectionPointSelector(
        selectedPoint: isSource ? selectedSourcePoint : selectedTargetPoint,
        onPointSelected: isSource
            ? onSourcePointSelected ?? (_) {}
            : onTargetPointSelected ?? (_) {},
        isVisible: showConnectionPoints,
        cardWidth: cardWidth,
        cardHeight: cardHeight,
      ),
    );
  }
}

// Connection point indicator for showing flow direction
class ConnectionFlowIndicator extends StatefulWidget {
  final ConnectionPoint connectionPoint;
  final bool isIncoming;
  final double cardWidth;
  final double cardHeight;

  const ConnectionFlowIndicator({
    super.key,
    required this.connectionPoint,
    this.isIncoming = true,
    this.cardWidth = 200,
    this.cardHeight = 100,
  });

  @override
  State<ConnectionFlowIndicator> createState() => _ConnectionFlowIndicatorState();
}

class _ConnectionFlowIndicatorState extends State<ConnectionFlowIndicator>
    with TickerProviderStateMixin {
  late AnimationController _flowController;
  late Animation<double> _flowAnimation;

  @override
  void initState() {
    super.initState();
    
    _flowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _flowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _flowController,
      curve: Curves.easeInOut,
    ));
    
    _flowController.repeat();
  }

  @override
  void dispose() {
    _flowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.cardWidth,
      height: widget.cardHeight,
      child: AnimatedBuilder(
        animation: _flowAnimation,
        builder: (context, child) {
          return CustomPaint(
            painter: FlowIndicatorPainter(
              connectionPoint: widget.connectionPoint,
              isIncoming: widget.isIncoming,
              animationValue: _flowAnimation.value,
            ),
          );
        },
      ),
    );
  }
}

class FlowIndicatorPainter extends CustomPainter {
  final ConnectionPoint connectionPoint;
  final bool isIncoming;
  final double animationValue;

  FlowIndicatorPainter({
    required this.connectionPoint,
    required this.isIncoming,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (isIncoming
              ? AccountantThemeConfig.primaryGreen
              : Colors.red)
          .withOpacity(0.6)
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = 3.0;

    // Calculate particle position based on connection point and animation
    Offset particlePosition;
    
    switch (connectionPoint) {
      case ConnectionPoint.top:
        particlePosition = Offset(
          center.dx,
          isIncoming
              ? (size.height * (1 - animationValue))
              : (size.height * animationValue),
        );
        break;
      case ConnectionPoint.bottom:
        particlePosition = Offset(
          center.dx,
          isIncoming
              ? (size.height * animationValue)
              : (size.height * (1 - animationValue)),
        );
        break;
      case ConnectionPoint.left:
        particlePosition = Offset(
          isIncoming
              ? (size.width * (1 - animationValue))
              : (size.width * animationValue),
          center.dy,
        );
        break;
      case ConnectionPoint.right:
        particlePosition = Offset(
          isIncoming
              ? (size.width * animationValue)
              : (size.width * (1 - animationValue)),
          center.dy,
        );
        break;
      case ConnectionPoint.center:
      default:
        particlePosition = center;
        break;
    }

    canvas.drawCircle(particlePosition, radius, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
