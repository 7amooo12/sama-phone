import 'package:flutter/material.dart';
import '../../utils/accountant_theme_config.dart';
import '../../models/treasury_models.dart';

/// Payment Method Selector Widget
/// Allows users to choose between cash-based and bank-based treasury types
class PaymentMethodSelector extends StatefulWidget {
  final TreasuryType selectedType;
  final ValueChanged<TreasuryType> onTypeChanged;

  const PaymentMethodSelector({
    super.key,
    required this.selectedType,
    required this.onTypeChanged,
  });

  @override
  State<PaymentMethodSelector> createState() => _PaymentMethodSelectorState();
}

class _PaymentMethodSelectorState extends State<PaymentMethodSelector>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'نوع الخزنة',
          style: AccountantThemeConfig.bodyLarge.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.3),
            end: Offset.zero,
          ).animate(_slideAnimation),
          child: FadeTransition(
            opacity: _slideAnimation,
            child: _buildTabSelector(),
          ),
        ),
      ],
    );
  }

  Widget _buildTabSelector() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AccountantThemeConfig.white60.withOpacity(0.1),
            AccountantThemeConfig.white60.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AccountantThemeConfig.white60.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabOption(
              type: TreasuryType.cash,
              icon: Icons.account_balance_wallet_rounded,
              title: 'خزنة نقدية',
              subtitle: 'عملات نقدية',
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: AccountantThemeConfig.white60.withOpacity(0.3),
          ),
          Expanded(
            child: _buildTabOption(
              type: TreasuryType.bank,
              icon: Icons.account_balance_rounded,
              title: 'حساب بنكي',
              subtitle: 'بطاقة أو حساب',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabOption({
    required TreasuryType type,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = widget.selectedType == type;
    
    return GestureDetector(
      onTap: () => _selectType(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: isSelected
              ? AccountantThemeConfig.blueGradient
              : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: isSelected
                      ? Colors.white
                      : AccountantThemeConfig.white70,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AccountantThemeConfig.bodyMedium.copyWith(
                        color: isSelected
                            ? Colors.white
                            : AccountantThemeConfig.white70,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: AccountantThemeConfig.bodySmall.copyWith(
                        color: isSelected
                            ? Colors.white.withOpacity(0.8)
                            : AccountantThemeConfig.white60,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectType(TreasuryType type) {
    if (widget.selectedType != type) {
      widget.onTypeChanged(type);
      
      // Add a subtle animation feedback
      _animationController.reset();
      _animationController.forward();
    }
  }
}
