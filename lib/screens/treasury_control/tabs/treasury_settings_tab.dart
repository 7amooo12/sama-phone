import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../utils/accountant_theme_config.dart';
import '../../../utils/formatters.dart';
import '../../../providers/treasury_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../../providers/electronic_wallet_provider.dart';
import '../../../models/treasury_models.dart';
import '../../../models/wallet_model.dart';
import '../../../models/electronic_wallet_model.dart';

/// Treasury Settings and Information Tab
/// Handles treasury-specific settings, information editing, and advanced features
class TreasurySettingsTab extends StatefulWidget {
  final String treasuryId;
  final String treasuryType;

  const TreasurySettingsTab({
    super.key,
    required this.treasuryId,
    required this.treasuryType,
  });

  @override
  State<TreasurySettingsTab> createState() => _TreasurySettingsTabState();
}

class _TreasurySettingsTabState extends State<TreasurySettingsTab> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _accountNumberController = TextEditingController();
  final TextEditingController _accountHolderController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isEditing = false;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTreasuryData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _accountHolderController.dispose();
    super.dispose();
  }

  void _loadTreasuryData() {
    if (widget.treasuryType == 'treasury') {
      final treasuryProvider = context.read<TreasuryProvider>();
      final treasury = treasuryProvider.treasuryVaults
          .where((t) => t.id == widget.treasuryId)
          .firstOrNull;

      if (treasury != null) {
        _nameController.text = treasury.name;
        _bankNameController.text = treasury.bankName ?? '';
        _accountNumberController.text = treasury.accountNumber ?? '';
        _accountHolderController.text = treasury.accountHolderName ?? '';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Treasury Information Card
          _buildTreasuryInfoCard(),

          const SizedBox(height: 16),

          // Settings based on treasury type
          if (widget.treasuryType == 'treasury') ...[
            _buildTreasurySettings(),
            const SizedBox(height: 16),
          ] else if (widget.treasuryType == 'client_wallets') ...[
            _buildClientWalletsSettings(),
            const SizedBox(height: 16),
          ] else if (widget.treasuryType == 'electronic_wallets') ...[
            _buildElectronicWalletsSettings(),
            const SizedBox(height: 16),
          ],

          // Advanced Actions
          _buildAdvancedActions(),
        ],
      ),
    );
  }

  Widget _buildTreasuryInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: AccountantThemeConfig.accentBlue,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'معلومات ${_getTreasuryDisplayName()}',
                style: AccountantThemeConfig.headlineSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Treasury-specific information
          if (widget.treasuryType == 'treasury') ...[
            _buildTreasuryInfo(),
          ] else if (widget.treasuryType == 'client_wallets') ...[
            _buildClientWalletsInfo(),
          ] else if (widget.treasuryType == 'electronic_wallets') ...[
            _buildElectronicWalletsInfo(),
          ],
        ],
      ),
    );
  }

  String _getTreasuryDisplayName() {
    switch (widget.treasuryType) {
      case 'treasury':
        return 'الخزنة';
      case 'client_wallets':
        return 'محافظ العملاء';
      case 'electronic_wallets':
        return 'المحافظ الإلكترونية';
      default:
        return 'غير محدد';
    }
  }

  Widget _buildTreasuryInfo() {
    final treasuryProvider = context.watch<TreasuryProvider>();
    final treasury = treasuryProvider.treasuryVaults
        .where((t) => t.id == widget.treasuryId)
        .firstOrNull;

    if (treasury == null) {
      return Text(
        'لم يتم العثور على الخزنة',
        style: AccountantThemeConfig.bodyMedium.copyWith(
          color: AccountantThemeConfig.white70,
        ),
      );
    }

    return Column(
      children: [
        _buildInfoRow('الاسم:', treasury.name),
        _buildInfoRow('النوع:', treasury.treasuryType.nameAr),
        _buildInfoRow('العملة:', treasury.currency),
        _buildInfoRow('الرصيد:', Formatters.formatTreasuryBalance(treasury.balance, treasury.currencySymbol)),
        if (treasury.treasuryType == TreasuryType.bank) ...[
          _buildInfoRow('البنك:', treasury.bankName ?? 'غير محدد'),
          _buildInfoRow('رقم الحساب:', treasury.accountNumber ?? 'غير محدد'),
          _buildInfoRow('اسم صاحب الحساب:', treasury.accountHolderName ?? 'غير محدد'),
        ],
        _buildInfoRow('تاريخ الإنشاء:', '${treasury.createdAt.day}/${treasury.createdAt.month}/${treasury.createdAt.year}'),
      ],
    );
  }

  Widget _buildClientWalletsInfo() {
    final walletProvider = context.watch<WalletProvider>();
    final clientWallets = walletProvider.wallets.where((w) => w.role == 'client').toList();
    final totalBalance = clientWallets.fold<double>(0.0, (sum, w) => sum + w.balance);
    final activeWallets = clientWallets.where((w) => w.isActive).length;

    return Column(
      children: [
        _buildInfoRow('إجمالي المحافظ:', clientWallets.length.toString()),
        _buildInfoRow('المحافظ النشطة:', activeWallets.toString()),
        _buildInfoRow('إجمالي الأرصدة:', '${totalBalance.toStringAsFixed(2)} ج.م'),
        _buildInfoRow('متوسط الرصيد:', clientWallets.isNotEmpty
            ? '${(totalBalance / clientWallets.length).toStringAsFixed(2)} ج.م'
            : '0.00 ج.م'),
      ],
    );
  }

  Widget _buildElectronicWalletsInfo() {
    final walletProvider = context.watch<ElectronicWalletProvider>();
    final totalBalance = walletProvider.wallets.fold<double>(0.0, (sum, w) => sum + w.currentBalance);
    final vodafoneWallets = walletProvider.wallets
        .where((w) => w.walletType == ElectronicWalletType.vodafoneCash).length;
    final instapayWallets = walletProvider.wallets
        .where((w) => w.walletType == ElectronicWalletType.instaPay).length;

    return Column(
      children: [
        _buildInfoRow('إجمالي المحافظ:', walletProvider.wallets.length.toString()),
        _buildInfoRow('فودافون كاش:', vodafoneWallets.toString()),
        _buildInfoRow('إنستاباي:', instapayWallets.toString()),
        _buildInfoRow('إجمالي الأرصدة:', '${totalBalance.toStringAsFixed(2)} ج.م'),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: AccountantThemeConfig.white70,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTreasurySettings() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.edit_rounded,
                color: AccountantThemeConfig.primaryGreen,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'إعدادات الخزنة',
                style: AccountantThemeConfig.headlineSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (_isEditing) ...[
            _buildEditForm(),
          ] else ...[
            _buildEditButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildEditButton() {
    return ElevatedButton.icon(
      onPressed: () {
        setState(() {
          _isEditing = true;
        });
      },
      icon: const Icon(Icons.edit_rounded),
      label: const Text('تحرير معلومات الخزنة'),
      style: AccountantThemeConfig.primaryButtonStyle,
    );
  }

  Widget _buildEditForm() {
    final treasuryProvider = context.watch<TreasuryProvider>();
    final treasury = treasuryProvider.treasuryVaults
        .where((t) => t.id == widget.treasuryId)
        .firstOrNull;

    if (treasury == null) return const SizedBox.shrink();

    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Treasury name
          TextFormField(
            controller: _nameController,
            style: AccountantThemeConfig.bodyLarge.copyWith(
              color: Colors.white,
            ),
            decoration: InputDecoration(
              labelText: 'اسم الخزنة',
              labelStyle: AccountantThemeConfig.bodyMedium.copyWith(
                color: AccountantThemeConfig.white70,
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AccountantThemeConfig.primaryGreen,
                  width: 2,
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'يرجى إدخال اسم الخزنة';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          // Bank-specific fields
          if (treasury.treasuryType == TreasuryType.bank) ...[
            TextFormField(
              controller: _bankNameController,
              style: AccountantThemeConfig.bodyLarge.copyWith(
                color: Colors.white,
              ),
              decoration: InputDecoration(
                labelText: 'اسم البنك',
                labelStyle: AccountantThemeConfig.bodyMedium.copyWith(
                  color: AccountantThemeConfig.white70,
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AccountantThemeConfig.primaryGreen,
                    width: 2,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _accountNumberController,
              style: AccountantThemeConfig.bodyLarge.copyWith(
                color: Colors.white,
              ),
              decoration: InputDecoration(
                labelText: 'رقم الحساب',
                labelStyle: AccountantThemeConfig.bodyMedium.copyWith(
                  color: AccountantThemeConfig.white70,
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AccountantThemeConfig.primaryGreen,
                    width: 2,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _accountHolderController,
              style: AccountantThemeConfig.bodyLarge.copyWith(
                color: Colors.white,
              ),
              decoration: InputDecoration(
                labelText: 'اسم صاحب الحساب',
                labelStyle: AccountantThemeConfig.bodyMedium.copyWith(
                  color: AccountantThemeConfig.white70,
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AccountantThemeConfig.primaryGreen,
                    width: 2,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],

          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveChanges,
                  style: AccountantThemeConfig.primaryButtonStyle,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('حفظ التغييرات'),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _cancelEdit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('إلغاء'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClientWalletsSettings() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.people_rounded,
                color: AccountantThemeConfig.primaryGreen,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'إعدادات محافظ العملاء',
                style: AccountantThemeConfig.headlineSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Text(
            'إعدادات محافظ العملاء متاحة من خلال شاشة إدارة المحافظ الرئيسية',
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: AccountantThemeConfig.white70,
            ),
          ),

          const SizedBox(height: 16),

          ElevatedButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, '/wallet_management');
            },
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('فتح إدارة المحافظ'),
            style: AccountantThemeConfig.primaryButtonStyle,
          ),
        ],
      ),
    );
  }

  Widget _buildElectronicWalletsSettings() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.phone_android_rounded,
                color: AccountantThemeConfig.accentBlue,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'إعدادات المحافظ الإلكترونية',
                style: AccountantThemeConfig.headlineSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Text(
            'إعدادات المحافظ الإلكترونية متاحة من خلال شاشة إدارة المحافظ الإلكترونية الرئيسية',
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: AccountantThemeConfig.white70,
            ),
          ),

          const SizedBox(height: 16),

          ElevatedButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, '/electronic_wallet_management');
            },
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('فتح إدارة المحافظ الإلكترونية'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AccountantThemeConfig.accentBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedActions() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.admin_panel_settings_rounded,
                color: Colors.orange,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'إجراءات متقدمة',
                style: AccountantThemeConfig.headlineSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Archive button (only for treasuries)
          if (widget.treasuryType == 'treasury') ...[
            ElevatedButton.icon(
              onPressed: () => _showArchiveDialog(),
              icon: const Icon(Icons.archive_rounded),
              label: const Text('أرشفة الخزنة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Delete button
            ElevatedButton.icon(
              onPressed: () => _showDeleteDialog(),
              icon: const Icon(Icons.delete_forever_rounded),
              label: const Text('حذف الخزنة نهائياً'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ] else ...[
            Text(
              'الإجراءات المتقدمة متاحة فقط للخزائن العادية',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: AccountantThemeConfig.white70,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final treasuryProvider = context.read<TreasuryProvider>();
      final treasury = treasuryProvider.treasuryVaults
          .where((t) => t.id == widget.treasuryId)
          .firstOrNull;

      if (treasury == null) {
        throw Exception('الخزنة غير موجودة');
      }

      // Update treasury information
      await treasuryProvider.updateTreasuryInfo(
        treasuryId: widget.treasuryId,
        name: _nameController.text.trim(),
        bankName: treasury.treasuryType == TreasuryType.bank ? _bankNameController.text.trim() : null,
        accountNumber: treasury.treasuryType == TreasuryType.bank ? _accountNumberController.text.trim() : null,
        accountHolderName: treasury.treasuryType == TreasuryType.bank ? _accountHolderController.text.trim() : null,
      );

      setState(() {
        _isEditing = false;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم حفظ التغييرات بنجاح',
            style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
          ),
          backgroundColor: AccountantThemeConfig.primaryGreen,
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'فشل في حفظ التغييرات: $e',
            style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
    });
    _loadTreasuryData(); // Reload original data
  }

  void _showArchiveDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        content: Container(
          width: 350,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: AccountantThemeConfig.cardGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AccountantThemeConfig.cardShadows,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.archive_rounded,
                size: 48,
                color: Colors.orange,
              ),
              const SizedBox(height: 16),
              Text(
                'أرشفة الخزنة',
                style: AccountantThemeConfig.headlineSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'هل أنت متأكد من أرشفة هذه الخزنة؟ سيتم إخفاؤها من القوائم الرئيسية مع الاحتفاظ بجميع البيانات.',
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: AccountantThemeConfig.white70,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _archiveTreasury();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('أرشفة'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        content: Container(
          width: 350,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: AccountantThemeConfig.cardGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AccountantThemeConfig.cardShadows,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.warning_rounded,
                size: 48,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                'تحذير: حذف نهائي',
                style: AccountantThemeConfig.headlineSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'هل أنت متأكد من حذف هذه الخزنة نهائياً؟ سيتم فقدان جميع البيانات والمعاملات المرتبطة بها ولا يمكن التراجع عن هذا الإجراء.',
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: AccountantThemeConfig.white70,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _deleteTreasury();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('حذف نهائي'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _archiveTreasury() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final treasuryProvider = context.read<TreasuryProvider>();
      final treasury = treasuryProvider.treasuryVaults
          .where((t) => t.id == widget.treasuryId)
          .firstOrNull;

      if (treasury == null) {
        throw Exception('الخزنة غير موجودة');
      }

      if (treasury.isMainTreasury) {
        throw Exception('لا يمكن أرشفة الخزنة الرئيسية');
      }

      // Archive treasury by updating its status in the database
      await treasuryProvider.archiveTreasury(widget.treasuryId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم أرشفة الخزنة "${treasury.name}" بنجاح',
            style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
          ),
          backgroundColor: Colors.orange,
        ),
      );

      // Navigate back to treasury management screen
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'فشل في أرشفة الخزنة: $e',
            style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteTreasury() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final treasuryProvider = context.read<TreasuryProvider>();
      final treasury = treasuryProvider.treasuryVaults
          .where((t) => t.id == widget.treasuryId)
          .firstOrNull;

      if (treasury == null) {
        throw Exception('الخزنة غير موجودة');
      }

      if (treasury.isMainTreasury) {
        throw Exception('لا يمكن حذف الخزنة الرئيسية');
      }

      if (treasury.balance != 0) {
        throw Exception('لا يمكن حذف خزنة تحتوي على رصيد. يرجى تفريغ الخزنة أولاً');
      }

      // Delete treasury permanently
      await treasuryProvider.deleteTreasury(widget.treasuryId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم حذف الخزنة "${treasury.name}" نهائياً',
            style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );

      // Navigate back to treasury management screen
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'فشل في حذف الخزنة: $e',
            style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
