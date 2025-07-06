import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/services/advance_service.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';

class AddAdvanceScreen extends StatefulWidget {
  const AddAdvanceScreen({super.key});

  @override
  State<AddAdvanceScreen> createState() => _AddAdvanceScreenState();
}

class _AddAdvanceScreenState extends State<AddAdvanceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _advanceNameController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  final _advanceService = AdvanceService();
  
  final TextEditingController _clientNameController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _advanceNameController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _clientNameController.dispose();
    super.dispose();
  }

  Future<void> _createAdvance() async {
    if (!_formKey.currentState!.validate()) {
      _showErrorSnackBar('يرجى ملء جميع الحقول المطلوبة');
      return;
    }

    try {
      setState(() => _isLoading = true);

      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
      final currentUser = supabaseProvider.user;

      if (currentUser == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      final advance = await _advanceService.createAdvanceWithClientName(
        advanceName: _advanceNameController.text.trim(),
        clientName: _clientNameController.text.trim(),
        amount: double.parse(_amountController.text.trim()),
        description: _descriptionController.text.trim(),
        createdBy: currentUser.id,
      );

      if (mounted) {
        _showSuccessSnackBar('تم إنشاء السلفة "${advance.advanceName}" بنجاح');
        Navigator.of(context).pop(true); // إرجاع true للإشارة إلى النجاح
      }
    } catch (e) {
      AppLogger.error('Error creating advance: $e');

      if (mounted) {
        _showErrorSnackBar('فشل في إنشاء السلفة: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Show success snackbar with AccountantThemeConfig styling
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: AccountantThemeConfig.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
        ),
        margin: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
      ),
    );
  }

  /// Show error snackbar with AccountantThemeConfig styling
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: AccountantThemeConfig.dangerRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
        ),
        margin: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AccountantThemeConfig.mainBackgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom App Bar
              _buildCustomAppBar(),

              // Main Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header Card
                        _buildHeaderCard(),

                        const SizedBox(height: AccountantThemeConfig.defaultPadding),

                        // Form Card
                        _buildFormCard(),

                        const SizedBox(height: AccountantThemeConfig.largePadding),

                        // Create Button
                        _buildCreateButton(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build custom app bar with AccountantThemeConfig styling
  Widget _buildCustomAppBar() {
    return Container(
      padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.blueGradient,
              borderRadius: BorderRadius.circular(AccountantThemeConfig.smallBorderRadius),
              boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.accentBlue),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(AccountantThemeConfig.smallBorderRadius),
                onTap: () => Navigator.of(context).pop(),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AccountantThemeConfig.defaultPadding),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إضافة سلفة جديدة',
                  style: AccountantThemeConfig.headlineSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'إنشاء سلفة جديدة للعميل',
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build header card with AccountantThemeConfig styling
  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(AccountantThemeConfig.largePadding),
      decoration: AccountantThemeConfig.primaryCardDecoration,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.greenGradient,
              borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
              boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: AccountantThemeConfig.defaultPadding),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إنشاء سلفة جديدة',
                  style: AccountantThemeConfig.headlineSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'أدخل تفاصيل السلفة للعميل',
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build form card with AccountantThemeConfig styling
  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(AccountantThemeConfig.largePadding),
      decoration: AccountantThemeConfig.primaryCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تفاصيل السلفة',
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AccountantThemeConfig.largePadding),

          // اسم السلفة
          _buildInputField(
            label: 'اسم السلفة',
            controller: _advanceNameController,
            icon: Icons.label_rounded,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'يرجى إدخال اسم السلفة';
              }
              return null;
            },
          ),

          const SizedBox(height: AccountantThemeConfig.defaultPadding),

          // اسم العميل
          _buildInputField(
            label: 'اسم العميل',
            controller: _clientNameController,
            icon: Icons.person_rounded,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'يرجى إدخال اسم العميل';
              }
              return null;
            },
          ),

          const SizedBox(height: AccountantThemeConfig.defaultPadding),

          // المبلغ
          _buildInputField(
            label: 'المبلغ (جنيه)',
            controller: _amountController,
            icon: Icons.payments_rounded,
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'يرجى إدخال المبلغ';
              }
              final amount = double.tryParse(value.trim());
              if (amount == null || amount <= 0) {
                return 'يرجى إدخال مبلغ صحيح';
              }
              return null;
            },
          ),

          const SizedBox(height: AccountantThemeConfig.defaultPadding),

          // الوصف
          _buildInputField(
            label: 'الوصف (اختياري)',
            controller: _descriptionController,
            icon: Icons.description_rounded,
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  /// Build create button with AccountantThemeConfig styling
  Widget _buildCreateButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.greenGradient,
        borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
        boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
          onTap: _isLoading ? null : _createAdvance,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: AccountantThemeConfig.defaultPadding),
            child: _isLoading
                ? const Center(
                    child: SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'إنشاء السلفة',
                        style: AccountantThemeConfig.bodyLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  /// Build input field with AccountantThemeConfig styling
  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AccountantThemeConfig.bodyMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AccountantThemeConfig.smallPadding),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            validator: validator,
            style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
            decoration: InputDecoration(
              prefixIcon: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AccountantThemeConfig.blueGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AccountantThemeConfig.defaultPadding,
                vertical: AccountantThemeConfig.defaultPadding,
              ),
              hintStyle: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white54,
              ),
              errorStyle: AccountantThemeConfig.bodySmall.copyWith(
                color: AccountantThemeConfig.dangerRed,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
