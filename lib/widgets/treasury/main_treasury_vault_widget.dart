import 'package:flutter/material.dart';
import '../../models/treasury_models.dart';
import '../../utils/accountant_theme_config.dart';
import 'animated_balance_widget.dart';
import 'currency_converter_toggle_button.dart';

class MainTreasuryVaultWidget extends StatefulWidget {
  final TreasuryVault treasury;
  final List<TreasuryVault> allTreasuries;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool isConnectionMode;

  const MainTreasuryVaultWidget({
    super.key,
    required this.treasury,
    required this.allTreasuries,
    this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.isConnectionMode = false,
  });

  @override
  State<MainTreasuryVaultWidget> createState() => _MainTreasuryVaultWidgetState();
}

class _MainTreasuryVaultWidgetState extends State<MainTreasuryVaultWidget>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late AnimationController _scaleController;
  late Animation<double> _glowAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    _glowController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));
    
    _glowController.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(MainTreasuryVaultWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
        _scaleController.forward();
      } else {
        _scaleController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_glowAnimation, _scaleAnimation]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            child: Container(
              height: 180, // Increased from 150 to 180 (20% increase for better content fit)
              margin: const EdgeInsets.symmetric(horizontal: 16), // Reduced margin for more width
              decoration: BoxDecoration(
                gradient: AccountantThemeConfig.cardGradient,
                borderRadius: BorderRadius.circular(20),
                border: widget.isSelected
                    ? Border.all(
                        color: AccountantThemeConfig.primaryGreen,
                        width: 3,
                      )
                    : AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
                boxShadow: [
                  ...AccountantThemeConfig.cardShadows,
                  if (widget.isConnectionMode)
                    BoxShadow(
                      color: AccountantThemeConfig.primaryGreen.withOpacity(_glowAnimation.value),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                ],
              ),
              child: Stack(
                children: [
                  // Background pattern
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: CustomPaint(
                        painter: _TreasuryPatternPainter(),
                      ),
                    ),
                  ),
                  
                  // Main content
                  Padding(
                    padding: const EdgeInsets.all(20), // Optimized padding for better space utilization
                    child: Row(
                      children: [
                        // Treasury icon with glow effect
                        Container(
                          width: 90, // Slightly reduced for better balance
                          height: 90, // Slightly reduced for better balance
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AccountantThemeConfig.primaryGreen,
                                AccountantThemeConfig.primaryGreen.withOpacity(0.7),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AccountantThemeConfig.primaryGreen.withOpacity(0.4),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.account_balance_rounded,
                            color: Colors.white,
                            size: 45, // Proportionally adjusted
                          ),
                        ),

                        const SizedBox(width: 20), // Optimized spacing
                        
                        // Treasury info
                        Expanded(
                          flex: 2, // Give more space to treasury info
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                widget.treasury.name,
                                style: AccountantThemeConfig.headlineSmall.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2, // Allow wrapping for long names
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'الخزنة الرئيسية',
                                style: AccountantThemeConfig.bodyMedium.copyWith(
                                  color: AccountantThemeConfig.white70,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Text(
                                    widget.treasury.currencyFlag,
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      widget.treasury.currency,
                                      style: AccountantThemeConfig.bodySmall.copyWith(
                                        color: AccountantThemeConfig.white60,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        // Balance display
                        Expanded(
                          flex: 1, // Give controlled space to balance
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'الرصيد الحالي',
                                style: AccountantThemeConfig.bodySmall.copyWith(
                                  color: AccountantThemeConfig.white60,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: AnimatedBalanceWidget(
                                    balance: widget.treasury.balance,
                                    currencySymbol: '',
                                    textStyle: AccountantThemeConfig.headlineMedium.copyWith(
                                      color: AccountantThemeConfig.primaryGreen,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    showCurrencySymbol: false,
                                    animationDuration: const Duration(milliseconds: 900),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.treasury.currencySymbol,
                                style: AccountantThemeConfig.bodyMedium.copyWith(
                                  color: AccountantThemeConfig.primaryGreen,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Connection points
                  if (widget.isConnectionMode) ...[
                    _buildConnectionPoint(Alignment.topCenter),
                    _buildConnectionPoint(Alignment.bottomCenter),
                    _buildConnectionPoint(Alignment.centerLeft),
                    _buildConnectionPoint(Alignment.centerRight),
                  ],
                  
                  // Currency converter button
                  TreasuryCardCurrencyConverter(
                    treasury: widget.treasury,
                    allTreasuries: widget.allTreasuries,
                    isMainTreasury: true,
                  ),

                  // Selection indicator
                  if (widget.isSelected)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: AccountantThemeConfig.primaryGreen,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: AccountantThemeConfig.primaryGreen.withOpacity(0.5),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
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

  Widget _buildConnectionPoint(Alignment alignment) {
    return Align(
      alignment: alignment,
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          return Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? AccountantThemeConfig.primaryGreen
                  : Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AccountantThemeConfig.primaryGreen,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AccountantThemeConfig.primaryGreen.withOpacity(_glowAnimation.value),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TreasuryPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Draw subtle geometric pattern
    final path = Path();
    
    // Draw diagonal lines
    for (double i = 0; i < size.width + size.height; i += 30) {
      path.moveTo(i, 0);
      path.lineTo(i - size.height, size.height);
    }
    
    canvas.drawPath(path, paint);
    
    // Draw circles
    paint.style = PaintingStyle.fill;
    paint.color = Colors.white.withOpacity(0.02);
    
    for (double x = 20; x < size.width; x += 40) {
      for (double y = 20; y < size.height; y += 40) {
        canvas.drawCircle(Offset(x, y), 3, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
