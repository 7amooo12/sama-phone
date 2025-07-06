import 'package:flutter/material.dart';
import '../../utils/accountant_theme_config.dart';
import '../../models/treasury_models.dart';

/// Bank Selector Widget
/// Allows users to select from predefined Egyptian banks or enter a custom bank name
class BankSelector extends StatefulWidget {
  final EgyptianBank? selectedBank;
  final String? customBankName;
  final ValueChanged<EgyptianBank?> onBankChanged;
  final ValueChanged<String?> onCustomBankNameChanged;

  const BankSelector({
    super.key,
    this.selectedBank,
    this.customBankName,
    required this.onBankChanged,
    required this.onCustomBankNameChanged,
  });

  @override
  State<BankSelector> createState() => _BankSelectorState();
}

class _BankSelectorState extends State<BankSelector>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final TextEditingController _customBankController = TextEditingController();
  bool _showCustomInput = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    // Initialize custom bank name if provided
    if (widget.customBankName != null) {
      _customBankController.text = widget.customBankName!;
      _showCustomInput = widget.selectedBank == EgyptianBank.other;
    }

    _animationController.forward();
  }

  @override
  void dispose() {
    _customBankController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'اختر البنك',
          style: AccountantThemeConfig.bodyLarge.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        FadeTransition(
          opacity: _fadeAnimation,
          child: _buildBankGrid(),
        ),
        if (_showCustomInput) ...[
          const SizedBox(height: 16),
          FadeTransition(
            opacity: _fadeAnimation,
            child: _buildCustomBankInput(),
          ),
        ],
      ],
    );
  }

  Widget _buildBankGrid() {
    return Container(
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
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 3.5,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: EgyptianBank.values.length,
        itemBuilder: (context, index) {
          final bank = EgyptianBank.values[index];
          final isSelected = widget.selectedBank == bank;
          
          return GestureDetector(
            onTap: () => _selectBank(bank),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? AccountantThemeConfig.greenGradient
                    : LinearGradient(
                        colors: [
                          AccountantThemeConfig.white60.withOpacity(0.1),
                          AccountantThemeConfig.white60.withOpacity(0.05),
                        ],
                      ),
                borderRadius: BorderRadius.circular(8),
                border: isSelected
                    ? Border.all(color: AccountantThemeConfig.primaryGreen, width: 2)
                    : Border.all(color: AccountantThemeConfig.white60, width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      bank.icon,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        bank.nameAr,
                        style: AccountantThemeConfig.bodySmall.copyWith(
                          color: isSelected ? Colors.white : AccountantThemeConfig.white70,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCustomBankInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'اسم البنك المخصص',
          style: AccountantThemeConfig.bodyMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _customBankController,
          style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
          decoration: AccountantThemeConfig.inputDecoration.copyWith(
            hintText: 'مثال: بنك الاستثمار العربي',
            prefixIcon: const Icon(Icons.business_rounded, color: Colors.white70),
          ),
          onChanged: (value) {
            widget.onCustomBankNameChanged(value.trim().isEmpty ? null : value.trim());
          },
          validator: (value) {
            if (_showCustomInput && (value == null || value.trim().isEmpty)) {
              return 'يرجى إدخال اسم البنك';
            }
            return null;
          },
        ),
      ],
    );
  }

  void _selectBank(EgyptianBank bank) {
    setState(() {
      _showCustomInput = bank == EgyptianBank.other;
    });

    widget.onBankChanged(bank);

    if (bank != EgyptianBank.other) {
      // Clear custom bank name when selecting a predefined bank
      _customBankController.clear();
      widget.onCustomBankNameChanged(null);
    }

    // Animate the change
    _animationController.reset();
    _animationController.forward();
  }
}
