import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/accountant_theme_config.dart';
import '../../utils/formatters.dart';

class AnimatedBalanceWidget extends StatefulWidget {
  final double balance;
  final String currencySymbol;
  final TextStyle textStyle;
  final Color? textColor;
  final Duration animationDuration;
  final bool showCurrencySymbol;
  final String? prefix;
  final String? suffix;
  final bool enableHapticFeedback;

  const AnimatedBalanceWidget({
    super.key,
    required this.balance,
    required this.currencySymbol,
    required this.textStyle,
    this.textColor,
    this.animationDuration = const Duration(milliseconds: 900),
    this.showCurrencySymbol = true,
    this.prefix,
    this.suffix,
    this.enableHapticFeedback = true,
  });

  @override
  State<AnimatedBalanceWidget> createState() => _AnimatedBalanceWidgetState();
}

class _AnimatedBalanceWidgetState extends State<AnimatedBalanceWidget>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  
  double _previousBalance = 0.0;
  double _currentBalance = 0.0;
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));
    
    _currentBalance = widget.balance;
    _previousBalance = widget.balance;
    
    // Start initial animation
    _fadeController.forward();
    _scaleController.forward();
  }

  @override
  void didUpdateWidget(AnimatedBalanceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (oldWidget.balance != widget.balance) {
      _updateBalance(oldWidget.balance, widget.balance);
    }
  }

  void _updateBalance(double oldBalance, double newBalance) {
    if (_isFirstLoad) {
      _isFirstLoad = false;
      return;
    }
    
    setState(() {
      _previousBalance = oldBalance;
      _currentBalance = newBalance;
    });
    
    // Trigger haptic feedback for balance changes
    if (widget.enableHapticFeedback) {
      if (newBalance > oldBalance) {
        HapticFeedback.lightImpact(); // Positive change
      } else if (newBalance < oldBalance) {
        HapticFeedback.mediumImpact(); // Negative change
      }
    }
    
    // Reset and restart animations
    _fadeController.reset();
    _scaleController.reset();
    
    _fadeController.forward();
    _scaleController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_fadeAnimation, _scaleAnimation]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: TweenAnimationBuilder<double>(
              duration: widget.animationDuration,
              tween: Tween<double>(
                begin: _previousBalance,
                end: _currentBalance,
              ),
              curve: Curves.easeOutCubic,
              builder: (context, animatedBalance, child) {
                final displayText = _buildDisplayText(animatedBalance);

                return Text(
                  displayText,
                  style: widget.textStyle.copyWith(
                    color: widget.textColor ?? widget.textStyle.color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                );
              },
            ),
          ),
        );
      },
    );
  }

  String _buildDisplayText(double balance) {
    final formattedBalance = Formatters.formatAnimatedBalance(balance);
    final parts = <String>[];

    if (widget.prefix != null) {
      parts.add(widget.prefix!);
    }

    parts.add(formattedBalance);

    if (widget.showCurrencySymbol) {
      parts.add(widget.currencySymbol);
    }

    if (widget.suffix != null) {
      parts.add(widget.suffix!);
    }

    return parts.join(' ');
  }
}

class AnimatedBalanceChangeIndicator extends StatefulWidget {
  final double oldBalance;
  final double newBalance;
  final String currencySymbol;
  final Duration displayDuration;

  const AnimatedBalanceChangeIndicator({
    super.key,
    required this.oldBalance,
    required this.newBalance,
    required this.currencySymbol,
    this.displayDuration = const Duration(seconds: 3),
  });

  @override
  State<AnimatedBalanceChangeIndicator> createState() => _AnimatedBalanceChangeIndicatorState();
}

class _AnimatedBalanceChangeIndicatorState extends State<AnimatedBalanceChangeIndicator>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _slideAnimation = Tween<double>(
      begin: -20.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
    
    _controller.forward();
    
    // Auto-hide after display duration
    Future.delayed(widget.displayDuration, () {
      if (mounted) {
        _controller.reverse();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final difference = widget.newBalance - widget.oldBalance;
    final isPositive = difference > 0;
    final isNegative = difference < 0;
    
    if (difference == 0) return const SizedBox.shrink();
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isPositive 
                    ? AccountantThemeConfig.primaryGreen.withOpacity(0.2)
                    : isNegative 
                        ? AccountantThemeConfig.dangerRed.withOpacity(0.2)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isPositive 
                      ? AccountantThemeConfig.primaryGreen
                      : isNegative 
                          ? AccountantThemeConfig.dangerRed
                          : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                    color: isPositive 
                        ? AccountantThemeConfig.primaryGreen
                        : AccountantThemeConfig.dangerRed,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${isPositive ? '+' : ''}${difference.toStringAsFixed(2)} ${widget.currencySymbol}',
                    style: AccountantThemeConfig.bodySmall.copyWith(
                      color: isPositive 
                          ? AccountantThemeConfig.primaryGreen
                          : AccountantThemeConfig.dangerRed,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
