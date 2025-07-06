import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/accountant_theme_config.dart';

class NewTreasuryHighlightAnimation extends StatefulWidget {
  final Widget child;
  final bool isNewTreasury;
  final Duration animationDuration;
  final Duration highlightDuration;
  final VoidCallback? onAnimationComplete;

  const NewTreasuryHighlightAnimation({
    super.key,
    required this.child,
    this.isNewTreasury = false,
    this.animationDuration = const Duration(milliseconds: 600),
    this.highlightDuration = const Duration(seconds: 2),
    this.onAnimationComplete,
  });

  @override
  State<NewTreasuryHighlightAnimation> createState() => _NewTreasuryHighlightAnimationState();
}

class _NewTreasuryHighlightAnimationState extends State<NewTreasuryHighlightAnimation>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _glowController;
  late AnimationController _borderController;
  
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _borderAnimation;
  
  bool _animationStarted = false;

  @override
  void initState() {
    super.initState();
    
    _scaleController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _borderController = AnimationController(
      duration: widget.highlightDuration,
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));
    
    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));
    
    _borderAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _borderController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void didUpdateWidget(NewTreasuryHighlightAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isNewTreasury && !_animationStarted) {
      _startWelcomeAnimation();
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _glowController.dispose();
    _borderController.dispose();
    super.dispose();
  }

  void _startWelcomeAnimation() async {
    if (_animationStarted) return;
    
    setState(() {
      _animationStarted = true;
    });
    
    // Trigger haptic feedback for new treasury creation
    HapticFeedback.mediumImpact();
    
    // Stage 1: Scale-in animation
    await _scaleController.forward();
    
    // Stage 2: Pulsing glow effect (2-3 pulses)
    for (int i = 0; i < 3; i++) {
      await _glowController.forward();
      await _glowController.reverse();
      
      // Small delay between pulses
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    // Stage 3: Border highlight fade-out
    await _borderController.forward();
    
    // Animation complete
    widget.onAnimationComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isNewTreasury) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: Listenable.merge([
        _scaleAnimation,
        _glowAnimation,
        _borderAnimation,
      ]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AccountantThemeConfig.primaryGreen.withOpacity(
                  _borderAnimation.value * 0.8,
                ),
                width: 2.0 * _borderAnimation.value,
              ),
              boxShadow: [
                // Pulsing glow effect
                BoxShadow(
                  color: AccountantThemeConfig.primaryGreen.withOpacity(
                    _glowAnimation.value * 0.4,
                  ),
                  blurRadius: 20.0 * _glowAnimation.value,
                  spreadRadius: 5.0 * _glowAnimation.value,
                ),
                // Highlight border glow
                BoxShadow(
                  color: AccountantThemeConfig.primaryGreen.withOpacity(
                    _borderAnimation.value * 0.6,
                  ),
                  blurRadius: 10.0 * _borderAnimation.value,
                  spreadRadius: 2.0 * _borderAnimation.value,
                ),
              ],
            ),
            child: widget.child,
          ),
        );
      },
    );
  }
}

class NewTreasuryCreationNotifier extends ChangeNotifier {
  String? _newTreasuryId;
  DateTime? _creationTime;
  
  String? get newTreasuryId => _newTreasuryId;
  DateTime? get creationTime => _creationTime;
  
  bool isNewTreasury(String treasuryId) {
    if (_newTreasuryId == null || _creationTime == null) return false;
    
    // Consider treasury as "new" for 5 seconds after creation
    final now = DateTime.now();
    final timeDifference = now.difference(_creationTime!);
    
    return _newTreasuryId == treasuryId && 
           timeDifference.inSeconds < 5;
  }
  
  void markTreasuryAsNew(String treasuryId) {
    _newTreasuryId = treasuryId;
    _creationTime = DateTime.now();
    notifyListeners();
    
    // Auto-clear after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (_newTreasuryId == treasuryId) {
        clearNewTreasury();
      }
    });
  }
  
  void clearNewTreasury() {
    _newTreasuryId = null;
    _creationTime = null;
    notifyListeners();
  }
}

class TreasuryCreationSuccessIndicator extends StatefulWidget {
  final String treasuryName;
  final VoidCallback? onDismiss;

  const TreasuryCreationSuccessIndicator({
    super.key,
    required this.treasuryName,
    this.onDismiss,
  });

  @override
  State<TreasuryCreationSuccessIndicator> createState() => _TreasuryCreationSuccessIndicatorState();
}

class _TreasuryCreationSuccessIndicatorState extends State<TreasuryCreationSuccessIndicator>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));
    
    // Start animations
    _slideController.forward();
    _fadeController.forward();
    
    // Auto-dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _dismiss() async {
    await _fadeController.reverse();
    await _slideController.reverse();
    widget.onDismiss?.call();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AccountantThemeConfig.cardGradient,
            borderRadius: BorderRadius.circular(12),
            border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
            boxShadow: [
              BoxShadow(
                color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AccountantThemeConfig.primaryGreen,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'تم إنشاء الخزنة بنجاح',
                      style: AccountantThemeConfig.bodyMedium.copyWith(
                        color: AccountantThemeConfig.primaryGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      widget.treasuryName,
                      style: AccountantThemeConfig.bodySmall.copyWith(
                        color: AccountantThemeConfig.white70,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _dismiss,
                icon: Icon(
                  Icons.close_rounded,
                  color: AccountantThemeConfig.white60,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
