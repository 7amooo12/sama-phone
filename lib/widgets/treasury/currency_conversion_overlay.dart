import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../utils/accountant_theme_config.dart';
import '../../models/treasury_models.dart';

class CurrencyConversionOverlay extends StatefulWidget {
  final TreasuryVault sourceTreasury;
  final List<TreasuryVault> allTreasuries;
  final VoidCallback onComplete;
  final Duration displayDuration;

  const CurrencyConversionOverlay({
    super.key,
    required this.sourceTreasury,
    required this.allTreasuries,
    required this.onComplete,
    this.displayDuration = const Duration(seconds: 5),
  });

  @override
  State<CurrencyConversionOverlay> createState() => _CurrencyConversionOverlayState();
}

class _CurrencyConversionOverlayState extends State<CurrencyConversionOverlay>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _countdownController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _countdownAnimation;
  
  Timer? _displayTimer;
  int _remainingSeconds = 5;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _countdownController = AnimationController(
      duration: widget.displayDuration,
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));
    
    _countdownAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _countdownController,
      curve: Curves.linear,
    ));
    
    _startAnimations();
    _startCountdown();
  }

  void _startAnimations() {
    _fadeController.forward();
    _scaleController.forward();
    _countdownController.forward();
  }

  void _startCountdown() {
    _remainingSeconds = widget.displayDuration.inSeconds;
    _displayTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _remainingSeconds--;
      });
      
      if (_remainingSeconds <= 0) {
        timer.cancel();
        _closeOverlay();
      }
    });
  }

  void _closeOverlay() async {
    _displayTimer?.cancel();
    await _fadeController.reverse();
    await _scaleController.reverse();
    widget.onComplete();
  }

  @override
  void dispose() {
    _displayTimer?.cancel();
    _fadeController.dispose();
    _scaleController.dispose();
    _countdownController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_fadeAnimation, _scaleAnimation]),
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: _buildOverlayContent(),
          ),
        );
      },
    );
  }

  Widget _buildOverlayContent() {
    final otherCurrencies = widget.allTreasuries
        .where((t) => t.currency != widget.sourceTreasury.currency)
        .toList();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AccountantThemeConfig.primaryGreen.withOpacity(0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: AccountantThemeConfig.primaryGreen.withOpacity(0.2),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildSourceBalance(),
          const SizedBox(height: 20),
          _buildConversionList(otherCurrencies),
          const SizedBox(height: 16),
          _buildCountdownIndicator(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AccountantThemeConfig.primaryGreen,
                AccountantThemeConfig.primaryGreen.withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
          ),
          child: const Icon(
            Icons.currency_exchange_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تحويل العملة',
                style: AccountantThemeConfig.headlineSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'عرض الرصيد بجميع العملات',
                style: AccountantThemeConfig.bodySmall.copyWith(
                  color: AccountantThemeConfig.white70,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: _closeOverlay,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.close_rounded,
              color: Colors.red,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSourceBalance() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AccountantThemeConfig.accentBlue.withOpacity(0.2),
            AccountantThemeConfig.accentBlue.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
      ),
      child: Row(
        children: [
          Text(
            widget.sourceTreasury.currencyFlag,
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.sourceTreasury.name,
                  style: AccountantThemeConfig.bodyLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${widget.sourceTreasury.balance.toStringAsFixed(2)} ${widget.sourceTreasury.currencySymbol}',
                  style: AccountantThemeConfig.headlineSmall.copyWith(
                    color: AccountantThemeConfig.accentBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversionList(List<TreasuryVault> otherCurrencies) {
    if (otherCurrencies.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AccountantThemeConfig.white60.withOpacity(0.1),
              AccountantThemeConfig.white60.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'لا توجد عملات أخرى للتحويل',
          style: AccountantThemeConfig.bodyMedium.copyWith(
            color: AccountantThemeConfig.white70,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      children: otherCurrencies.map((treasury) {
        final convertedAmount = _convertCurrency(
          widget.sourceTreasury.balance,
          widget.sourceTreasury.exchangeRateToEgp,
          treasury.exchangeRateToEgp,
        );
        
        return _buildConversionItem(treasury, convertedAmount);
      }).toList(),
    );
  }

  double _convertCurrency(double amount, double fromRate, double toRate) {
    // Convert to EGP first, then to target currency
    final egpAmount = amount * fromRate;
    return egpAmount / toRate;
  }

  Widget _buildConversionItem(TreasuryVault targetTreasury, double convertedAmount) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AccountantThemeConfig.primaryGreen.withOpacity(0.1),
            AccountantThemeConfig.primaryGreen.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
      ),
      child: Row(
        children: [
          Text(
            targetTreasury.currencyFlag,
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              targetTreasury.currency,
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: AccountantThemeConfig.white70,
              ),
            ),
          ),
          Text(
            '${convertedAmount.toStringAsFixed(2)} ${targetTreasury.currencySymbol}',
            style: AccountantThemeConfig.bodyLarge.copyWith(
              color: AccountantThemeConfig.primaryGreen,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownIndicator() {
    return AnimatedBuilder(
      animation: _countdownAnimation,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                value: _countdownAnimation.value,
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AccountantThemeConfig.primaryGreen,
                ),
                backgroundColor: AccountantThemeConfig.white60.withOpacity(0.3),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'إغلاق تلقائي خلال $_remainingSeconds ثانية',
              style: AccountantThemeConfig.bodySmall.copyWith(
                color: AccountantThemeConfig.white70,
              ),
            ),
          ],
        );
      },
    );
  }
}
