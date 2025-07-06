import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/accountant_theme_config.dart';
import '../../models/treasury_models.dart';

class AnimatedCurrencyConverter extends StatefulWidget {
  final TreasuryVault treasury;
  final bool showConverter;
  final VoidCallback? onToggle;
  final Duration animationDuration;

  const AnimatedCurrencyConverter({
    super.key,
    required this.treasury,
    this.showConverter = false,
    this.onToggle,
    this.animationDuration = const Duration(milliseconds: 300),
  });

  @override
  State<AnimatedCurrencyConverter> createState() => _AnimatedCurrencyConverterState();
}

class _AnimatedCurrencyConverterState extends State<AnimatedCurrencyConverter>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _rotationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _rotationAnimation;
  
  bool _showEgpEquivalent = false;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void didUpdateWidget(AnimatedCurrencyConverter oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (oldWidget.showConverter != widget.showConverter) {
      if (widget.showConverter) {
        _fadeController.forward();
      } else {
        _fadeController.reverse();
        _showEgpEquivalent = false;
      }
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  void _toggleCurrency() {
    if (widget.onToggle != null) {
      // Trigger haptic feedback
      HapticFeedback.lightImpact();
      
      // Rotate the icon
      _rotationController.forward().then((_) {
        _rotationController.reverse();
      });
      
      setState(() {
        _showEgpEquivalent = !_showEgpEquivalent;
      });
      
      widget.onToggle!();
    }
  }

  double get _egpEquivalent {
    return widget.treasury.balance * widget.treasury.exchangeRateToEgp;
  }

  bool get _shouldShowConverter {
    return widget.treasury.exchangeRateToEgp != 1.0 && 
           widget.treasury.currencySymbol != 'ج.م';
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldShowConverter) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AccountantThemeConfig.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Toggle button
                GestureDetector(
                  onTap: _toggleCurrency,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AccountantThemeConfig.primaryGreen.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedBuilder(
                          animation: _rotationAnimation,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _rotationAnimation.value * 3.14159, // 180 degrees
                              child: const Text(
                                '🔄',
                                style: TextStyle(fontSize: 14),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'تحويل العملة',
                          style: AccountantThemeConfig.bodySmall.copyWith(
                            color: AccountantThemeConfig.primaryGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Currency display with crossfade animation
                AnimatedCrossFade(
                  duration: widget.animationDuration,
                  crossFadeState: _showEgpEquivalent 
                      ? CrossFadeState.showSecond 
                      : CrossFadeState.showFirst,
                  firstChild: _buildOriginalCurrency(),
                  secondChild: _buildEgpEquivalent(),
                ),
                
                const SizedBox(height: 4),
                
                // Exchange rate and timestamp
                _buildExchangeRateInfo(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOriginalCurrency() {
    return Column(
      children: [
        Text(
          'العملة الأصلية',
          style: AccountantThemeConfig.bodySmall.copyWith(
            color: AccountantThemeConfig.white60,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${widget.treasury.balance.toStringAsFixed(2)} ${widget.treasury.currencySymbol}',
          style: AccountantThemeConfig.bodyMedium.copyWith(
            color: AccountantThemeConfig.primaryGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildEgpEquivalent() {
    return Column(
      children: [
        Text(
          'المعادل بالجنيه المصري',
          style: AccountantThemeConfig.bodySmall.copyWith(
            color: AccountantThemeConfig.white60,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${_egpEquivalent.toStringAsFixed(2)} ج.م',
          style: AccountantThemeConfig.bodyMedium.copyWith(
            color: AccountantThemeConfig.accentBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildExchangeRateInfo() {
    final now = DateTime.now();
    final timeString = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    
    return Column(
      children: [
        Text(
          'سعر الصرف: ${widget.treasury.exchangeRateToEgp.toStringAsFixed(4)}',
          style: AccountantThemeConfig.bodySmall.copyWith(
            color: AccountantThemeConfig.white70,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.access_time_rounded,
              size: 12,
              color: AccountantThemeConfig.white60,
            ),
            const SizedBox(width: 4),
            Text(
              'آخر تحديث: $timeString',
              style: AccountantThemeConfig.bodySmall.copyWith(
                color: AccountantThemeConfig.white60,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class CurrencyConverterToggleButton extends StatefulWidget {
  final TreasuryVault treasury;
  final VoidCallback? onPressed;

  const CurrencyConverterToggleButton({
    super.key,
    required this.treasury,
    this.onPressed,
  });

  @override
  State<CurrencyConverterToggleButton> createState() => _CurrencyConverterToggleButtonState();
}

class _CurrencyConverterToggleButtonState extends State<CurrencyConverterToggleButton>
    with SingleTickerProviderStateMixin {
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
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    // Start pulsing animation
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  bool get _shouldShow {
    return widget.treasury.exchangeRateToEgp != 1.0 && 
           widget.treasury.currencySymbol != 'ج.م';
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldShow) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onPressed?.call();
            },
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AccountantThemeConfig.primaryGreen,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AccountantThemeConfig.primaryGreen.withOpacity(0.4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  '🔄',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
