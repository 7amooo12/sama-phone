import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/accountant_theme_config.dart';

/// Bank Account Input Fields Widget
/// Provides form fields for bank account information including account number,
/// initial balance, and optional account holder name
class BankAccountInputFields extends StatefulWidget {
  final TextEditingController accountNumberController;
  final TextEditingController initialBalanceController;
  final TextEditingController accountHolderController;
  final String currencyCode;

  const BankAccountInputFields({
    super.key,
    required this.accountNumberController,
    required this.initialBalanceController,
    required this.accountHolderController,
    required this.currencyCode,
  });

  @override
  State<BankAccountInputFields> createState() => _BankAccountInputFieldsState();
}

class _BankAccountInputFieldsState extends State<BankAccountInputFields>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _slideAnimation = Tween<double>(
      begin: 0.3,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _fadeAnimation = Tween<double>(
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.3),
            end: Offset.zero,
          ).animate(_slideAnimation),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: _buildAccountNumberField(),
          ),
        ),
        const SizedBox(height: 20),
        SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.4),
            end: Offset.zero,
          ).animate(_slideAnimation),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: _buildInitialBalanceField(),
          ),
        ),
        const SizedBox(height: 20),
        SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.5),
            end: Offset.zero,
          ).animate(_slideAnimation),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: _buildAccountHolderField(),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountNumberField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'رقم الحساب البنكي',
          style: AccountantThemeConfig.bodyLarge.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.accountNumberController,
          style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(20), // Limit to 20 digits
          ],
          decoration: AccountantThemeConfig.inputDecoration.copyWith(
            hintText: 'مثال: 1234567890123456',
            prefixIcon: const Icon(Icons.credit_card_rounded, color: Colors.white70),
            suffixIcon: IconButton(
              icon: const Icon(Icons.info_outline_rounded, color: Colors.white60),
              onPressed: () => _showAccountNumberInfo(context),
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'يرجى إدخال رقم الحساب البنكي';
            }
            if (value.trim().length < 8) {
              return 'رقم الحساب يجب أن يكون 8 أرقام على الأقل';
            }
            if (value.trim().length > 20) {
              return 'رقم الحساب لا يجب أن يزيد عن 20 رقم';
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
          'الرصيد الابتدائي',
          style: AccountantThemeConfig.bodyLarge.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.initialBalanceController,
          style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          decoration: AccountantThemeConfig.inputDecoration.copyWith(
            hintText: '0.00',
            prefixIcon: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white70),
            suffixText: widget.currencyCode,
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

  Widget _buildAccountHolderField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'اسم صاحب الحساب',
              style: AccountantThemeConfig.bodyLarge.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AccountantThemeConfig.white60.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'اختياري',
                style: AccountantThemeConfig.bodySmall.copyWith(
                  color: AccountantThemeConfig.white60,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.accountHolderController,
          style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
          decoration: AccountantThemeConfig.inputDecoration.copyWith(
            hintText: 'مثال: أحمد محمد علي',
            prefixIcon: const Icon(Icons.person_rounded, color: Colors.white70),
          ),
          validator: (value) {
            if (value != null && value.trim().isNotEmpty) {
              if (value.trim().length < 3) {
                return 'اسم صاحب الحساب يجب أن يكون 3 أحرف على الأقل';
              }
              if (value.trim().length > 50) {
                return 'اسم صاحب الحساب لا يجب أن يزيد عن 50 حرف';
              }
            }
            return null;
          },
        ),
      ],
    );
  }

  void _showAccountNumberInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AccountantThemeConfig.cardBackground1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'معلومات رقم الحساب',
          style: AccountantThemeConfig.headlineSmall.copyWith(
            color: Colors.white,
          ),
        ),
        content: Text(
          'يرجى إدخال رقم الحساب البنكي كما هو مكتوب في كشف الحساب أو البطاقة البنكية.\n\n'
          '• يجب أن يكون من 8 إلى 20 رقم\n'
          '• أرقام فقط بدون مسافات أو رموز\n'
          '• تأكد من صحة الرقم قبل الحفظ',
          style: AccountantThemeConfig.bodyMedium.copyWith(
            color: AccountantThemeConfig.white70,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'فهمت',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: AccountantThemeConfig.primaryGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
