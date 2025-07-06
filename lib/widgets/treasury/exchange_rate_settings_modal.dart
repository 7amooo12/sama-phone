import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../utils/accountant_theme_config.dart';
import '../../providers/treasury_provider.dart';
import '../../models/treasury_models.dart';

class ExchangeRateSettingsModal extends StatefulWidget {
  const ExchangeRateSettingsModal({super.key});

  @override
  State<ExchangeRateSettingsModal> createState() => _ExchangeRateSettingsModalState();
}

class _ExchangeRateSettingsModalState extends State<ExchangeRateSettingsModal>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  
  final Map<String, TextEditingController> _rateControllers = {};
  final Map<String, bool> _hasChanges = {};
  bool _isLoading = false;
  String? _error;
  bool _isBulkUpdateMode = false;

  @override
  void initState() {
    super.initState();
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _initializeControllers();
    _slideController.forward();
    _fadeController.forward();
  }

  void _initializeControllers() {
    final treasuryProvider = context.read<TreasuryProvider>();
    for (final treasury in treasuryProvider.treasuryVaults) {
      _rateControllers[treasury.id] = TextEditingController(
        text: treasury.exchangeRateToEgp.toStringAsFixed(4),
      );
      _hasChanges[treasury.id] = false;
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    for (final controller in _rateControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: AnimatedBuilder(
        animation: Listenable.merge([_slideAnimation, _fadeAnimation]),
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: _buildModalContent(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildModalContent() {
    return Container(
      margin: const EdgeInsets.only(top: 100),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.mainBackgroundGradient,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AccountantThemeConfig.primaryGreen.withOpacity(0.1),
            Colors.transparent,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AccountantThemeConfig.primaryGreen,
                  AccountantThemeConfig.primaryGreen.withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
            ),
            child: const Icon(
              Icons.currency_exchange_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إدارة أسعار الصرف',
                  style: AccountantThemeConfig.headlineLarge.copyWith(
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'تحديث أسعار صرف العملات للخزائن',
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    color: AccountantThemeConfig.white70,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              _buildBulkUpdateToggle(),
              const SizedBox(width: 12),
              _buildCloseButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBulkUpdateToggle() {
    return Container(
      decoration: BoxDecoration(
        gradient: _isBulkUpdateMode 
            ? LinearGradient(
                colors: [
                  AccountantThemeConfig.accentBlue,
                  AccountantThemeConfig.accentBlue.withOpacity(0.8),
                ],
              )
            : LinearGradient(
                colors: [
                  AccountantThemeConfig.white60.withOpacity(0.2),
                  AccountantThemeConfig.white60.withOpacity(0.1),
                ],
              ),
        borderRadius: BorderRadius.circular(12),
        border: AccountantThemeConfig.glowBorder(
          _isBulkUpdateMode ? AccountantThemeConfig.accentBlue : AccountantThemeConfig.white60,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() {
              _isBulkUpdateMode = !_isBulkUpdateMode;
            });
            HapticFeedback.lightImpact();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isBulkUpdateMode ? Icons.done_all_rounded : Icons.edit_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  _isBulkUpdateMode ? 'تحديث جماعي' : 'تحديث فردي',
                  style: AccountantThemeConfig.bodySmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCloseButton() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.red.withOpacity(0.8),
            Colors.red.withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: AccountantThemeConfig.glowShadows(Colors.red),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _closeModal,
          child: const Icon(
            Icons.close_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }

  void _closeModal() async {
    await _fadeController.reverse();
    await _slideController.reverse();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Widget _buildContent() {
    return Column(
      children: [
        if (_error != null) _buildErrorMessage(),
        Expanded(
          child: _buildTreasuryList(),
        ),
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.red.withOpacity(0.1),
            Colors.red.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.red.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: Colors.red,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error!,
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.red,
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _error = null;
              });
            },
            icon: const Icon(
              Icons.close_rounded,
              color: Colors.red,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTreasuryList() {
    return Consumer<TreasuryProvider>(
      builder: (context, treasuryProvider, child) {
        if (treasuryProvider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                AccountantThemeConfig.primaryGreen,
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: treasuryProvider.treasuryVaults.length,
          itemBuilder: (context, index) {
            final treasury = treasuryProvider.treasuryVaults[index];
            return _buildTreasuryRateCard(treasury);
          },
        );
      },
    );
  }

  Widget _buildTreasuryRateCard(TreasuryVault treasury) {
    final controller = _rateControllers[treasury.id]!;
    final hasChanges = _hasChanges[treasury.id] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: hasChanges
            ? Border.all(
                color: AccountantThemeConfig.primaryGreen,
                width: 2,
              )
            : AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
        boxShadow: [
          ...AccountantThemeConfig.cardShadows,
          if (hasChanges)
            BoxShadow(
              color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
              blurRadius: 15,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: treasury.isMainTreasury
                          ? [
                              AccountantThemeConfig.primaryGreen,
                              AccountantThemeConfig.primaryGreen.withOpacity(0.8),
                            ]
                          : [
                              AccountantThemeConfig.accentBlue,
                              AccountantThemeConfig.accentBlue.withOpacity(0.8),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: AccountantThemeConfig.glowShadows(
                      treasury.isMainTreasury
                          ? AccountantThemeConfig.primaryGreen
                          : AccountantThemeConfig.accentBlue,
                    ),
                  ),
                  child: Icon(
                    treasury.isMainTreasury
                        ? Icons.account_balance_rounded
                        : Icons.account_balance_wallet_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        treasury.name,
                        style: AccountantThemeConfig.headlineSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            treasury.currencyFlag,
                            style: const TextStyle(fontSize: 18),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            treasury.currency,
                            style: AccountantThemeConfig.bodyMedium.copyWith(
                              color: AccountantThemeConfig.white70,
                            ),
                          ),
                          if (treasury.isMainTreasury) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AccountantThemeConfig.primaryGreen,
                                    AccountantThemeConfig.primaryGreen.withOpacity(0.8),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'رئيسية',
                                style: AccountantThemeConfig.bodySmall.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (hasChanges)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AccountantThemeConfig.primaryGreen,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _buildExchangeRateField(treasury, controller),
            const SizedBox(height: 12),
            _buildLastUpdatedInfo(treasury),
          ],
        ),
      ),
    );
  }

  Widget _buildExchangeRateField(TreasuryVault treasury, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'سعر الصرف مقابل الجنيه المصري',
          style: AccountantThemeConfig.bodyMedium.copyWith(
            color: AccountantThemeConfig.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          style: AccountantThemeConfig.bodyLarge.copyWith(color: Colors.white),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,4}')),
          ],
          decoration: AccountantThemeConfig.inputDecoration.copyWith(
            hintText: '1.0000',
            prefixIcon: const Icon(
              Icons.currency_exchange_rounded,
              color: Colors.white70,
            ),
            suffixText: 'ج.م',
            suffixStyle: AccountantThemeConfig.bodyMedium.copyWith(
              color: AccountantThemeConfig.primaryGreen,
              fontWeight: FontWeight.w600,
            ),
          ),
          onChanged: (value) {
            setState(() {
              _hasChanges[treasury.id] = value != treasury.exchangeRateToEgp.toStringAsFixed(4);
            });
          },
        ),
      ],
    );
  }

  Widget _buildLastUpdatedInfo(TreasuryVault treasury) {
    final now = DateTime.now();
    final timeString = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return Row(
      children: [
        Icon(
          Icons.access_time_rounded,
          size: 16,
          color: AccountantThemeConfig.white60,
        ),
        const SizedBox(width: 6),
        Text(
          'آخر تحديث: $timeString',
          style: AccountantThemeConfig.bodySmall.copyWith(
            color: AccountantThemeConfig.white60,
          ),
        ),
        const Spacer(),
        Text(
          'الرصيد: ${treasury.balance.toStringAsFixed(2)} ${treasury.currencySymbol}',
          style: AccountantThemeConfig.bodySmall.copyWith(
            color: AccountantThemeConfig.primaryGreen,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    final hasAnyChanges = _hasChanges.values.any((hasChange) => hasChange);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            AccountantThemeConfig.primaryGreen.withOpacity(0.05),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildCancelButton(),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: _buildSaveButton(hasAnyChanges),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelButton() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AccountantThemeConfig.white60.withOpacity(0.2),
            AccountantThemeConfig.white60.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.white60),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _closeModal,
          child: Center(
            child: Text(
              'إلغاء',
              style: AccountantThemeConfig.bodyLarge.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton(bool hasAnyChanges) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        gradient: hasAnyChanges
            ? LinearGradient(
                colors: [
                  AccountantThemeConfig.primaryGreen,
                  AccountantThemeConfig.primaryGreen.withOpacity(0.8),
                ],
              )
            : LinearGradient(
                colors: [
                  AccountantThemeConfig.white60.withOpacity(0.3),
                  AccountantThemeConfig.white60.withOpacity(0.2),
                ],
              ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: hasAnyChanges
            ? AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen)
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: hasAnyChanges ? _saveChanges : null,
          child: Center(
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isBulkUpdateMode ? Icons.done_all_rounded : Icons.save_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isBulkUpdateMode ? 'حفظ جميع التغييرات' : 'حفظ التغييرات',
                        style: AccountantThemeConfig.bodyLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveChanges() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final treasuryProvider = context.read<TreasuryProvider>();

      if (_isBulkUpdateMode) {
        // Bulk update all changed rates
        final updates = <String, double>{};
        for (final entry in _hasChanges.entries) {
          if (entry.value) {
            final rate = double.tryParse(_rateControllers[entry.key]!.text);
            if (rate != null && rate > 0) {
              updates[entry.key] = rate;
            }
          }
        }

        if (updates.isNotEmpty) {
          await treasuryProvider.updateExchangeRatesBulk(updates);
        }
      } else {
        // Individual updates
        for (final entry in _hasChanges.entries) {
          if (entry.value) {
            final rate = double.tryParse(_rateControllers[entry.key]!.text);
            if (rate != null && rate > 0) {
              await treasuryProvider.updateExchangeRate(entry.key, rate);
            }
          }
        }
      }

      // Reset change tracking
      for (final key in _hasChanges.keys) {
        _hasChanges[key] = false;
      }

      if (mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم تحديث أسعار الصرف بنجاح',
              style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
            ),
            backgroundColor: AccountantThemeConfig.primaryGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }

    } catch (e) {
      setState(() {
        _error = 'فشل في تحديث أسعار الصرف: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
