import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ARChandelierWidget extends StatefulWidget {

  const ARChandelierWidget({
    super.key,
    required this.chandelierImage,
    required this.initialPosition,
    required this.initialScale,
    required this.initialRotation,
    required this.initialOpacity,
    required this.onPositionChanged,
    required this.onScaleChanged,
    required this.onRotationChanged,
    required this.onOpacityChanged,
    this.isInteractive = true,
  });
  final File chandelierImage;
  final Offset initialPosition;
  final double initialScale;
  final double initialRotation;
  final double initialOpacity;
  final Function(Offset) onPositionChanged;
  final Function(double) onScaleChanged;
  final Function(double) onRotationChanged;
  final Function(double) onOpacityChanged;
  final bool isInteractive;

  @override
  State<ARChandelierWidget> createState() => _ARChandelierWidgetState();
}

class _ARChandelierWidgetState extends State<ARChandelierWidget>
    with TickerProviderStateMixin {
  late AnimationController _scaleAnimationController;
  late AnimationController _rotationAnimationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  Offset _currentPosition = Offset.zero;
  double _currentScale = 1.0;
  double _currentRotation = 0.0;
  double _currentOpacity = 1.0;
  
  bool _isDragging = false;
  bool _isScaling = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeValues();
  }

  @override
  void dispose() {
    _scaleAnimationController.dispose();
    _rotationAnimationController.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _scaleAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _rotationAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _scaleAnimationController,
      curve: Curves.easeInOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.1,
    ).animate(CurvedAnimation(
      parent: _rotationAnimationController,
      curve: Curves.elasticOut,
    ));
  }

  void _initializeValues() {
    _currentPosition = widget.initialPosition;
    _currentScale = widget.initialScale;
    _currentRotation = widget.initialRotation;
    _currentOpacity = widget.initialOpacity;
  }

  void _onPanStart(DragStartDetails details) {
    if (!widget.isInteractive) return;
    
    setState(() => _isDragging = true);
    _scaleAnimationController.forward();
    HapticFeedback.lightImpact();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!widget.isInteractive || !_isDragging) return;
    
    setState(() {
      _currentPosition = details.localPosition;
    });
    
    widget.onPositionChanged(_currentPosition);
  }

  void _onPanEnd(DragEndDetails details) {
    if (!widget.isInteractive) return;
    
    setState(() => _isDragging = false);
    _scaleAnimationController.reverse();
    HapticFeedback.mediumImpact();
  }

  void _onScaleStart(ScaleStartDetails details) {
    if (!widget.isInteractive) return;
    
    setState(() => _isScaling = true);
    _rotationAnimationController.forward();
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (!widget.isInteractive || !_isScaling) return;
    
    // Update scale
    final newScale = (_currentScale * details.scale).clamp(0.1, 3.0);
    if (newScale != _currentScale) {
      setState(() => _currentScale = newScale);
      widget.onScaleChanged(_currentScale);
    }
    
    // Update rotation
    final newRotation = _currentRotation + details.rotation;
    if (newRotation != _currentRotation) {
      setState(() => _currentRotation = newRotation);
      widget.onRotationChanged(_currentRotation);
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (!widget.isInteractive) return;
    
    setState(() => _isScaling = false);
    _rotationAnimationController.reverse();
    HapticFeedback.heavyImpact();
  }

  void _onTap() {
    if (!widget.isInteractive) return;
    
    // Add a subtle bounce animation on tap
    _scaleAnimationController.forward().then((_) {
      _scaleAnimationController.reverse();
    });
    
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _currentPosition.dx - (100 * _currentScale / 2),
      top: _currentPosition.dy - (100 * _currentScale / 2),
      child: GestureDetector(
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd: _onScaleEnd,
        onTap: _onTap,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _scaleAnimationController,
            _rotationAnimationController,
          ]),
          builder: (context, child) {
            final animatedScale = _isDragging 
                ? _currentScale * _scaleAnimation.value
                : _currentScale;
            
            final animatedRotation = _isScaling
                ? _currentRotation + _rotationAnimation.value
                : _currentRotation;

            return Transform.scale(
              scale: animatedScale,
              child: Transform.rotate(
                angle: animatedRotation,
                child: Opacity(
                  opacity: _currentOpacity,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: _isDragging || _isScaling
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ]
                          : null,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        children: [
                          // Chandelier image
                          Image.file(
                            widget.chandelierImage,
                            width: 100,
                            height: 100,
                            fit: BoxFit.contain,
                          ),
                          
                          // Interactive overlay
                          if (widget.isInteractive && (_isDragging || _isScaling))
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.5),
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.open_with,
                                  color: Colors.white,
                                  size: 24,
                                ),
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
        ),
      ),
    );
  }
}

// Helper widget for AR controls overlay
class ARControlsOverlay extends StatelessWidget {

  const ARControlsOverlay({
    super.key,
    required this.scale,
    required this.rotation,
    required this.opacity,
    required this.onScaleChanged,
    required this.onRotationChanged,
    required this.onOpacityChanged,
    required this.onReset,
    required this.isVisible,
  });
  final double scale;
  final double rotation;
  final double opacity;
  final Function(double) onScaleChanged;
  final Function(double) onRotationChanged;
  final Function(double) onOpacityChanged;
  final VoidCallback onReset;
  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return Positioned(
      bottom: 100,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'التحكم في النجفة',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: onReset,
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  tooltip: 'إعادة تعيين',
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Scale control
            _buildSliderControl(
              'الحجم',
              Icons.zoom_in,
              scale,
              0.1,
              3.0,
              onScaleChanged,
            ),
            
            // Rotation control
            _buildSliderControl(
              'الدوران',
              Icons.rotate_right,
              rotation,
              -180,
              180,
              onRotationChanged,
            ),
            
            // Opacity control
            _buildSliderControl(
              'الشفافية',
              Icons.opacity,
              opacity,
              0.1,
              1.0,
              onOpacityChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderControl(
    String label,
    IconData icon,
    double value,
    double min,
    double max,
    Function(double) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          Expanded(
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
              activeColor: Colors.white,
              inactiveColor: Colors.white.withOpacity(0.3),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              value.toStringAsFixed(1),
              style: const TextStyle(color: Colors.white, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
