import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../utils/accountant_theme_config.dart';
import '../../providers/treasury_provider.dart';
import '../../models/treasury_models.dart';
import '../../services/treasury_fund_transfer_service.dart';
import '../../utils/app_logger.dart';

class FundTransferModal extends StatefulWidget {
  final String? sourceTreasuryId;
  final String? targetTreasuryId;
  final VoidCallback? onTransferCompleted;

  const FundTransferModal({
    super.key,
    this.sourceTreasuryId,
    this.targetTreasuryId,
    this.onTransferCompleted,
  });

  @override
  State<FundTransferModal> createState() => _FundTransferModalState();
}

class _FundTransferModalState extends State<FundTransferModal>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _transferService = TreasuryFundTransferService();

  String? _selectedSourceTreasuryId;
  String? _selectedTargetTreasuryId;
  bool _isLoading = false;
  bool _isValidating = false;
  TransferValidationResult? _validationResult;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _selectedSourceTreasuryId = widget.sourceTreasuryId;
    _selectedTargetTreasuryId = widget.targetTreasuryId;
    _descriptionController.text = 'تحويل بين الخزائن';

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

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _validateTransfer() async {
    if (_selectedSourceTreasuryId == null || _selectedTargetTreasuryId == null) {
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      return;
    }

    setState(() {
      _isValidating = true;
      _validationResult = null;
    });

    try {
      final result = await _transferService.validateTransfer(
        sourceTreasuryId: _selectedSourceTreasuryId!,
        targetTreasuryId: _selectedTargetTreasuryId!,
        transferAmount: amount,
      );

      setState(() {
        _validationResult = result;
      });
    } catch (e) {
      AppLogger.error('Error validating transfer: $e');
    } finally {
      setState(() {
        _isValidating = false;
      });
    }
  }

  Future<void> _executeTransfer() async {
    if (!_formKey.currentState!.validate()) return;

    if (_validationResult == null || !_validationResult!.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'يرجى التحقق من صحة بيانات التحويل أولاً',
            style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final amount = double.parse(_amountController.text);
      await _transferService.executeTransfer(
        sourceTreasuryId: _selectedSourceTreasuryId!,
        targetTreasuryId: _selectedTargetTreasuryId!,
        transferAmount: amount,
        description: _descriptionController.text.trim(),
      );

      // Reload treasury data
      if (mounted) {
        await context.read<TreasuryProvider>().loadTreasuryVaults();
        
        Navigator.pop(context);
        widget.onTransferCompleted?.call();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم تنفيذ التحويل بنجاح',
              style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
            ),
            backgroundColor: AccountantThemeConfig.primaryGreen,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString(),
              style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.cardGradient,
              borderRadius: BorderRadius.circular(20),
              border: AccountantThemeConfig.glowBorder(),
              boxShadow: AccountantThemeConfig.cardShadows,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildTreasurySelectors(),
                          const SizedBox(height: 20),
                          _buildAmountField(),
                          const SizedBox(height: 16),
                          _buildDescriptionField(),
                          const SizedBox(height: 20),
                          if (_validationResult != null) ...[
                            _buildValidationResult(),
                            const SizedBox(height: 20),
                          ],
                          _buildActionButtons(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AccountantThemeConfig.primaryGreen.withValues(alpha: 0.8),
            AccountantThemeConfig.accentBlue.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.swap_horiz_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'تحويل الأموال بين الخزائن',
              style: AccountantThemeConfig.headlineSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.close_rounded,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTreasurySelectors() {
    return Consumer<TreasuryProvider>(
      builder: (context, treasuryProvider, child) {
        final treasuries = treasuryProvider.treasuryVaults;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'اختيار الخزائن',
              style: AccountantThemeConfig.bodyLarge.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Source Treasury
            _buildTreasuryDropdown(
              label: 'الخزنة المصدر',
              value: _selectedSourceTreasuryId,
              treasuries: treasuries.cast<TreasuryVault>(),
              onChanged: (value) {
                setState(() {
                  _selectedSourceTreasuryId = value;
                  _validationResult = null;
                });
                _validateTransfer();
              },
              icon: Icons.call_made_rounded,
              iconColor: Colors.red,
            ),

            const SizedBox(height: 16),

            // Target Treasury
            _buildTreasuryDropdown(
              label: 'الخزنة المستهدفة',
              value: _selectedTargetTreasuryId,
              treasuries: treasuries.cast<TreasuryVault>(),
              onChanged: (value) {
                setState(() {
                  _selectedTargetTreasuryId = value;
                  _validationResult = null;
                });
                _validateTransfer();
              },
              icon: Icons.call_received_rounded,
              iconColor: AccountantThemeConfig.primaryGreen,
            ),
          ],
        );
      },
    );
  }

  Widget _buildTreasuryDropdown({
    required String label,
    required String? value,
    required List<TreasuryVault> treasuries,
    required ValueChanged<String?> onChanged,
    required IconData icon,
    required Color iconColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AccountantThemeConfig.bodyMedium.copyWith(
            color: AccountantThemeConfig.white70,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
            ),
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: iconColor, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            dropdownColor: const Color(0xFF1E293B),
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white,
            ),
            items: treasuries.map((treasury) {
              return DropdownMenuItem<String>(
                value: treasury.id,
                child: Row(
                  children: [
                    Icon(
                      treasury.treasuryType == TreasuryType.bank
                          ? Icons.account_balance_rounded
                          : Icons.account_balance_wallet_rounded,
                      size: 16,
                      color: AccountantThemeConfig.white70,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        treasury.name,
                        style: AccountantThemeConfig.bodyMedium.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Text(
                      '${treasury.balance.toStringAsFixed(2)} ${treasury.currency}',
                      style: AccountantThemeConfig.bodySmall.copyWith(
                        color: AccountantThemeConfig.white60,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: onChanged,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'يرجى اختيار الخزنة';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAmountField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'مبلغ التحويل',
          style: AccountantThemeConfig.bodyLarge.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
          ],
          style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
          decoration: InputDecoration(
            prefixIcon: const Icon(
              Icons.attach_money_rounded,
              color: AccountantThemeConfig.primaryGreen,
            ),
            hintText: 'أدخل المبلغ المراد تحويله',
            hintStyle: AccountantThemeConfig.bodyMedium.copyWith(
              color: AccountantThemeConfig.white60,
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AccountantThemeConfig.primaryGreen,
                width: 2,
              ),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'يرجى إدخال مبلغ التحويل';
            }
            final amount = double.tryParse(value);
            if (amount == null || amount <= 0) {
              return 'يرجى إدخال مبلغ صحيح';
            }
            return null;
          },
          onChanged: (value) {
            // Validate transfer when amount changes
            if (value.isNotEmpty) {
              _validateTransfer();
            } else {
              setState(() {
                _validationResult = null;
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildDescriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'وصف التحويل',
          style: AccountantThemeConfig.bodyMedium.copyWith(
            color: AccountantThemeConfig.white70,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _descriptionController,
          style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
          maxLines: 2,
          decoration: InputDecoration(
            prefixIcon: const Icon(
              Icons.description_rounded,
              color: AccountantThemeConfig.accentBlue,
            ),
            hintText: 'أدخل وصف التحويل (اختياري)',
            hintStyle: AccountantThemeConfig.bodyMedium.copyWith(
              color: AccountantThemeConfig.white60,
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AccountantThemeConfig.accentBlue,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildValidationResult() {
    if (_validationResult == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _validationResult!.isValid
            ? AccountantThemeConfig.primaryGreen.withValues(alpha: 0.1)
            : Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _validationResult!.isValid
              ? AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3)
              : Colors.red.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _validationResult!.isValid
                    ? Icons.check_circle_rounded
                    : Icons.error_rounded,
                color: _validationResult!.isValid
                    ? AccountantThemeConfig.primaryGreen
                    : Colors.red,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _validationResult!.isValid ? 'التحويل صالح' : 'خطأ في التحويل',
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: _validationResult!.isValid
                      ? AccountantThemeConfig.primaryGreen
                      : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          // Show errors
          if (_validationResult!.errors.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...(_validationResult!.errors.map((error) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.close_rounded,
                    color: Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      error,
                      style: AccountantThemeConfig.bodySmall.copyWith(
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ))),
          ],

          // Show warnings
          if (_validationResult!.warnings.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...(_validationResult!.warnings.map((warning) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_rounded,
                    color: Colors.orange,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      warning,
                      style: AccountantThemeConfig.bodySmall.copyWith(
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ))),
          ],

          // Show transfer details if valid
          if (_validationResult!.isValid && _validationResult!.transferDetails != null) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.white24),
            const SizedBox(height: 8),
            Text(
              'تفاصيل التحويل',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _buildTransferDetailRow(
              'المبلغ المحول:',
              '${_validationResult!.transferDetails!.sourceAmount.toStringAsFixed(2)}',
            ),
            _buildTransferDetailRow(
              'المبلغ المستلم:',
              '${_validationResult!.transferDetails!.targetAmount.toStringAsFixed(2)}',
            ),
            _buildTransferDetailRow(
              'سعر الصرف:',
              _validationResult!.transferDetails!.exchangeRate.toStringAsFixed(4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTransferDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: AccountantThemeConfig.white70,
            ),
          ),
          Text(
            value,
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: Text(
              'إلغاء',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _isLoading ||
                      _isValidating ||
                      _validationResult == null ||
                      !_validationResult!.isValid
                ? null
                : _executeTransfer,
            style: ElevatedButton.styleFrom(
              backgroundColor: AccountantThemeConfig.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
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
                    'تنفيذ التحويل',
                    style: AccountantThemeConfig.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
