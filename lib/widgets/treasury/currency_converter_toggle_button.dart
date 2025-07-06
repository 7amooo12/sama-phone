import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/accountant_theme_config.dart';
import '../../models/treasury_models.dart';
import 'currency_conversion_overlay.dart';

class CurrencyConverterToggleButton extends StatefulWidget {
  final TreasuryVault treasury;
  final List<TreasuryVault> allTreasuries;
  final VoidCallback? onPressed;

  const CurrencyConverterToggleButton({
    super.key,
    required this.treasury,
    required this.allTreasuries,
    this.onPressed,
  });

  @override
  State<CurrencyConverterToggleButton> createState() => _CurrencyConverterToggleButtonState();
}

class _CurrencyConverterToggleButtonState extends State<CurrencyConverterToggleButton>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotationAnimation;
  
  bool _showingOverlay = false;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.elasticOut,
    ));
    
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _handleTap() {
    if (_showingOverlay) {
      _removeOverlay();
    } else {
      _showOverlay();
    }
    
    // Trigger haptic feedback
    HapticFeedback.lightImpact();
    
    // Trigger rotation animation
    _rotationController.forward().then((_) {
      _rotationController.reverse();
    });
    
    // Call optional callback
    widget.onPressed?.call();
  }

  void _showOverlay() {
    if (_showingOverlay) return;
    
    setState(() {
      _showingOverlay = true;
    });
    
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: Material(
          color: Colors.black54,
          child: Center(
            child: CurrencyConversionOverlay(
              sourceTreasury: widget.treasury,
              allTreasuries: widget.allTreasuries,
              onComplete: _removeOverlay,
            ),
          ),
        ),
      ),
    );
    
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    if (!_showingOverlay) return;
    
    setState(() {
      _showingOverlay = false;
    });
    
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnimation, _rotationAnimation]),
      builder: (context, child) {
        return Transform.scale(
          scale: _showingOverlay ? 1.1 : _pulseAnimation.value,
          child: Transform.rotate(
            angle: _rotationAnimation.value * 0.5,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: _showingOverlay
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
                border: _showingOverlay
                    ? Border.all(
                        color: AccountantThemeConfig.primaryGreen,
                        width: 2,
                      )
                    : AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
                boxShadow: [
                  if (_showingOverlay)
                    ...AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen)
                  else
                    ...AccountantThemeConfig.glowShadows(AccountantThemeConfig.accentBlue),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: _handleTap,
                  child: Center(
                    child: Icon(
                      _showingOverlay 
                          ? Icons.close_rounded 
                          : Icons.currency_exchange_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Extension widget for easy integration with existing treasury cards
class TreasuryCurrencyConverterButton extends StatelessWidget {
  final TreasuryVault treasury;
  final List<TreasuryVault> allTreasuries;
  final Alignment alignment;
  final EdgeInsets margin;

  const TreasuryCurrencyConverterButton({
    super.key,
    required this.treasury,
    required this.allTreasuries,
    this.alignment = Alignment.topRight,
    this.margin = const EdgeInsets.all(8),
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: alignment == Alignment.topLeft || alignment == Alignment.topRight ? margin.top : null,
      bottom: alignment == Alignment.bottomLeft || alignment == Alignment.bottomRight ? margin.bottom : null,
      left: alignment == Alignment.topLeft || alignment == Alignment.bottomLeft ? margin.left : null,
      right: alignment == Alignment.topRight || alignment == Alignment.bottomRight ? margin.right : null,
      child: CurrencyConverterToggleButton(
        treasury: treasury,
        allTreasuries: allTreasuries,
      ),
    );
  }
}

// Helper widget for consistent positioning across different card types
class TreasuryCardCurrencyConverter extends StatelessWidget {
  final TreasuryVault treasury;
  final List<TreasuryVault> allTreasuries;
  final bool isMainTreasury;

  const TreasuryCardCurrencyConverter({
    super.key,
    required this.treasury,
    required this.allTreasuries,
    this.isMainTreasury = false,
  });

  @override
  Widget build(BuildContext context) {
    return TreasuryCurrencyConverterButton(
      treasury: treasury,
      allTreasuries: allTreasuries,
      alignment: isMainTreasury ? Alignment.topLeft : Alignment.topRight,
      margin: EdgeInsets.all(isMainTreasury ? 12 : 8),
    );
  }
}
