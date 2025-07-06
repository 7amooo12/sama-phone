import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

class ARTutorialOverlay extends StatefulWidget {

  const ARTutorialOverlay({
    super.key,
    required this.onComplete,
    required this.showTutorial,
  });
  final VoidCallback onComplete;
  final bool showTutorial;

  @override
  State<ARTutorialOverlay> createState() => _ARTutorialOverlayState();
}

class _ARTutorialOverlayState extends State<ARTutorialOverlay>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;
  
  int _currentStep = 0;
  final int _totalSteps = 4;

  final List<TutorialStep> _steps = [
    TutorialStep(
      title: 'مرحباً بك في تجربة AR',
      description: 'ستتعلم كيفية وضع النجفة في مساحتك باستخدام الواقع المعزز',
      icon: Icons.view_in_ar,
      position: TutorialPosition.center,
    ),
    TutorialStep(
      title: 'اضغط لوضع النجفة',
      description: 'اضغط في أي مكان على الشاشة لوضع النجفة في ذلك الموقع',
      icon: Icons.touch_app,
      position: TutorialPosition.center,
    ),
    TutorialStep(
      title: 'اسحب لتحريك النجفة',
      description: 'اسحب النجفة لتحريكها إلى الموقع المطلوب',
      icon: Icons.pan_tool,
      position: TutorialPosition.center,
    ),
    TutorialStep(
      title: 'استخدم أدوات التحكم',
      description: 'استخدم الأزرار السفلية للتحكم في الحجم والدوران والشفافية',
      icon: Icons.tune,
      position: TutorialPosition.bottom,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    if (widget.showTutorial) {
      _startTutorial();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  void _startTutorial() {
    _animationController.forward();
  }

  void _nextStep() {
    HapticFeedback.lightImpact();
    
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
    } else {
      _completeTutorial();
    }
  }

  void _previousStep() {
    HapticFeedback.lightImpact();
    
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  void _completeTutorial() {
    _animationController.reverse().then((_) {
      widget.onComplete();
    });
  }

  void _skipTutorial() {
    HapticFeedback.mediumImpact();
    _completeTutorial();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showTutorial) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Container(
            color: Colors.black.withOpacity(0.8),
            child: Stack(
              children: [
                // Tutorial content
                _buildTutorialContent(),
                
                // Skip button
                Positioned(
                  top: 60,
                  right: 20,
                  child: TextButton(
                    onPressed: _skipTutorial,
                    child: const Text(
                      'تخطي',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                
                // Progress indicator
                Positioned(
                  top: 60,
                  left: 20,
                  child: _buildProgressIndicator(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTutorialContent() {
    final step = _steps[_currentStep];
    
    final Widget content = AnimationLimiter(
      child: Column(
        mainAxisAlignment: step.position == TutorialPosition.center
            ? MainAxisAlignment.center
            : MainAxisAlignment.end,
        children: [
          AnimationConfiguration.synchronized(
            child: SlideAnimation(
              verticalOffset: 50,
              child: FadeInAnimation(
                child: Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icon with pulse animation
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.purple.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                step.icon,
                                size: 40,
                                color: Colors.purple,
                              ),
                            ),
                          );
                        },
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Title
                      Text(
                        step.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Description
                      Text(
                        step.description,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black54,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Navigation buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Previous button
                          if (_currentStep > 0)
                            TextButton.icon(
                              onPressed: _previousStep,
                              icon: const Icon(Icons.arrow_back),
                              label: const Text('السابق'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.grey[600],
                              ),
                            )
                          else
                            const SizedBox.shrink(),
                          
                          // Next/Complete button
                          ElevatedButton.icon(
                            onPressed: _nextStep,
                            icon: Icon(_currentStep == _totalSteps - 1
                                ? Icons.check
                                : Icons.arrow_forward),
                            label: Text(_currentStep == _totalSteps - 1
                                ? 'ابدأ'
                                : 'التالي'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          if (step.position == TutorialPosition.bottom)
            const SizedBox(height: 100),
        ],
      ),
    );

    return content;
  }

  Widget _buildProgressIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_totalSteps, (index) {
        final isActive = index <= _currentStep;
        final isCurrent = index == _currentStep;
        
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isCurrent ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.white.withOpacity(0.3),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

class TutorialStep {

  TutorialStep({
    required this.title,
    required this.description,
    required this.icon,
    required this.position,
  });
  final String title;
  final String description;
  final IconData icon;
  final TutorialPosition position;
}

enum TutorialPosition {
  center,
  bottom,
}

// Helper widget for AR instructions
class ARInstructionsWidget extends StatelessWidget {

  const ARInstructionsWidget({
    super.key,
    required this.instruction,
    required this.icon,
    required this.isVisible,
  });
  final String instruction;
  final IconData icon;
  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              instruction,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
