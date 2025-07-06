import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/treasury_provider.dart';
import '../../models/treasury_models.dart';
import '../../utils/accountant_theme_config.dart';
import 'payment_method_selector.dart';
import 'bank_selector.dart';
import 'bank_account_input_fields.dart';

class CreateTreasuryModal extends StatefulWidget {
  final Function(String)? onTreasuryCreated;

  const CreateTreasuryModal({
    super.key,
    this.onTreasuryCreated,
  });

  @override
  State<CreateTreasuryModal> createState() => _CreateTreasuryModalState();
}

class _CreateTreasuryModalState extends State<CreateTreasuryModal>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _exchangeRateController = TextEditingController();
  final _initialBalanceController = TextEditingController();

  // Bank account controllers
  final _accountNumberController = TextEditingController();
  final _accountHolderController = TextEditingController();

  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  // Treasury type and currency
  TreasuryType _selectedTreasuryType = TreasuryType.cash;
  SupportedCurrency _selectedCurrency = SupportedCurrency.egp;

  // Bank selection
  EgyptianBank? _selectedBank;
  String? _customBankName;

  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
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

    // Set default exchange rate
    _exchangeRateController.text = '1.0000';

    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _nameController.dispose();
    _exchangeRateController.dispose();
    _initialBalanceController.dispose();
    _accountNumberController.dispose();
    _accountHolderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          gradient: AccountantThemeConfig.mainBackgroundGradient,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildNameField(),
                      const SizedBox(height: 20),
                      _buildPaymentMethodSelector(),
                      const SizedBox(height: 20),
                      if (_selectedTreasuryType == TreasuryType.cash) ...[
                        _buildCurrencySelector(),
                        const SizedBox(height: 20),
                        _buildExchangeRateField(),
                        const SizedBox(height: 20),
                        _buildInitialBalanceField(),
                      ] else ...[
                        _buildBankSelector(),
                        const SizedBox(height: 20),
                        _buildBankAccountFields(),
                      ],
                      const SizedBox(height: 32),
                      _buildCreateButton(),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        _buildErrorMessage(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.greenGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.account_balance_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إنشاء خزنة فرعية جديدة',
                  style: AccountantThemeConfig.headlineSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'أضف خزنة فرعية بعملة مختلفة',
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    color: AccountantThemeConfig.white70,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _closeModal,
            icon: const Icon(
              Icons.close_rounded,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'اسم الخزنة',
          style: AccountantThemeConfig.bodyLarge.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _nameController,
          style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
          decoration: AccountantThemeConfig.inputDecoration.copyWith(
            hintText: 'مثال: خزنة الدولار الأمريكي',
            prefixIcon: const Icon(Icons.label_rounded, color: Colors.white70),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'يرجى إدخال اسم الخزنة';
            }
            if (value.trim().length < 3) {
              return 'يجب أن يكون اسم الخزنة 3 أحرف على الأقل';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildCurrencySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'العملة',
          style: AccountantThemeConfig.bodyLarge.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            gradient: AccountantThemeConfig.cardGradient,
            borderRadius: BorderRadius.circular(12),
            border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
          ),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 3.5,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            padding: const EdgeInsets.all(12),
            itemCount: SupportedCurrency.values.length,
            itemBuilder: (context, index) {
              final currency = SupportedCurrency.values[index];
              final isSelected = _selectedCurrency == currency;
              
              return GestureDetector(
                onTap: () => _selectCurrency(currency),
                child: Container(
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        currency.flag,
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          currency.nameAr,
                          style: AccountantThemeConfig.bodySmall.copyWith(
                            color: isSelected ? Colors.white : AccountantThemeConfig.white70,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildExchangeRateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'سعر الصرف مقابل الجنيه المصري',
              style: AccountantThemeConfig.bodyLarge.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _showExchangeRateHelp,
              child: Icon(
                Icons.help_outline_rounded,
                color: AccountantThemeConfig.white70,
                size: 20,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _exchangeRateController,
          style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,4}')),
          ],
          decoration: AccountantThemeConfig.inputDecoration.copyWith(
            hintText: '1.0000',
            prefixIcon: const Icon(Icons.currency_exchange_rounded, color: Colors.white70),
            suffixText: 'ج.م',
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'يرجى إدخال سعر الصرف';
            }
            final rate = double.tryParse(value);
            if (rate == null || rate <= 0) {
              return 'يرجى إدخال سعر صرف صحيح';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildInitialBalanceField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الرصيد الابتدائي (اختياري)',
          style: AccountantThemeConfig.bodyLarge.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _initialBalanceController,
          style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          decoration: AccountantThemeConfig.inputDecoration.copyWith(
            hintText: '0.00',
            prefixIcon: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white70),
            suffixText: _selectedCurrency.code,
          ),
          validator: (value) {
            if (value != null && value.trim().isNotEmpty) {
              final balance = double.tryParse(value);
              if (balance == null || balance < 0) {
                return 'يرجى إدخال رصيد صحيح';
              }
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildCreateButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _createTreasury,
      style: AccountantThemeConfig.primaryButtonStyle.copyWith(
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
      child: _isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Text(
              'إنشاء الخزنة',
              style: AccountantThemeConfig.bodyLarge.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AccountantThemeConfig.dangerRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AccountantThemeConfig.dangerRed),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: AccountantThemeConfig.dangerRed,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: AccountantThemeConfig.dangerRed,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSelector() {
    return PaymentMethodSelector(
      selectedType: _selectedTreasuryType,
      onTypeChanged: (type) {
        setState(() {
          _selectedTreasuryType = type;
          // Reset bank-related fields when switching to cash
          if (type == TreasuryType.cash) {
            _selectedBank = null;
            _customBankName = null;
            _accountNumberController.clear();
            _accountHolderController.clear();
          }
        });
      },
    );
  }

  Widget _buildBankSelector() {
    return BankSelector(
      selectedBank: _selectedBank,
      customBankName: _customBankName,
      onBankChanged: (bank) {
        setState(() {
          _selectedBank = bank;
        });
      },
      onCustomBankNameChanged: (name) {
        setState(() {
          _customBankName = name;
        });
      },
    );
  }

  Widget _buildBankAccountFields() {
    return BankAccountInputFields(
      accountNumberController: _accountNumberController,
      initialBalanceController: _initialBalanceController,
      accountHolderController: _accountHolderController,
      currencyCode: 'EGP', // Bank accounts are always in EGP for now
    );
  }

  void _selectCurrency(SupportedCurrency currency) {
    setState(() {
      _selectedCurrency = currency;
    });

    // Update exchange rate placeholder based on currency
    if (currency == SupportedCurrency.egp) {
      _exchangeRateController.text = '1.0000';
    } else {
      _exchangeRateController.clear();
    }
  }

  void _showExchangeRateHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AccountantThemeConfig.cardColor,
        title: Text(
          'سعر الصرف',
          style: AccountantThemeConfig.headlineSmall.copyWith(color: Colors.white),
        ),
        content: Text(
          'أدخل كم جنيه مصري يساوي وحدة واحدة من العملة المختارة.\n\nمثال: إذا كان الدولار = 30 جنيه، أدخل 30.0000',
          style: AccountantThemeConfig.bodyMedium.copyWith(color: AccountantThemeConfig.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'فهمت',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: AccountantThemeConfig.primaryGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createTreasury() async {
    if (!_formKey.currentState!.validate()) return;

    // Additional validation for bank treasury
    if (_selectedTreasuryType == TreasuryType.bank) {
      if (_selectedBank == null) {
        setState(() {
          _error = 'يرجى اختيار البنك';
        });
        return;
      }

      if (_selectedBank == EgyptianBank.other &&
          (_customBankName == null || _customBankName!.trim().isEmpty)) {
        setState(() {
          _error = 'يرجى إدخال اسم البنك المخصص';
        });
        return;
      }

      if (_accountNumberController.text.trim().isEmpty) {
        setState(() {
          _error = 'يرجى إدخال رقم الحساب البنكي';
        });
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final treasuryProvider = context.read<TreasuryProvider>();

      final newTreasury = await treasuryProvider.createTreasuryVault(
        name: _nameController.text.trim(),
        currency: _selectedTreasuryType == TreasuryType.cash
            ? _selectedCurrency.code
            : 'EGP', // Bank accounts are always in EGP
        exchangeRate: _selectedTreasuryType == TreasuryType.cash
            ? double.parse(_exchangeRateController.text)
            : 1.0, // Bank accounts have 1.0 exchange rate
        initialBalance: _initialBalanceController.text.trim().isEmpty
            ? 0.0
            : double.parse(_initialBalanceController.text),
        treasuryType: _selectedTreasuryType,
        bankName: _selectedTreasuryType == TreasuryType.bank
            ? (_selectedBank == EgyptianBank.other
                ? _customBankName
                : _selectedBank?.nameAr)
            : null,
        accountNumber: _selectedTreasuryType == TreasuryType.bank
            ? _accountNumberController.text.trim()
            : null,
        accountHolderName: _selectedTreasuryType == TreasuryType.bank
            ? (_accountHolderController.text.trim().isEmpty
                ? null
                : _accountHolderController.text.trim())
            : null,
      );

      if (mounted) {
        Navigator.pop(context);

        // Call the callback with the new treasury ID
        widget.onTreasuryCreated?.call(newTreasury.id);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم إنشاء الخزنة بنجاح',
              style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
            ),
            backgroundColor: AccountantThemeConfig.primaryGreen,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _closeModal() {
    _slideController.reverse().then((_) {
      if (mounted) {
        Navigator.pop(context);
      }
    });
  }
}
