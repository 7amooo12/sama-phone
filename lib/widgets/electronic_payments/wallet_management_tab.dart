import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/electronic_wallet_provider.dart';
import '../../providers/supabase_provider.dart';
import '../../models/electronic_wallet_model.dart';
import '../../models/electronic_wallet_transaction_model.dart';
import '../../services/electronic_wallet_service.dart';
import '../../services/auth_sync_service.dart';
import '../../utils/accountant_theme_config.dart';

/// Tab for managing electronic wallets (Vodafone Cash & InstaPay)
class WalletManagementTab extends StatefulWidget {
  const WalletManagementTab({super.key});

  @override
  State<WalletManagementTab> createState() => _WalletManagementTabState();
}

class _WalletManagementTabState extends State<WalletManagementTab> {
  @override
  Widget build(BuildContext context) {
    return Consumer<ElectronicWalletProvider>(
      builder: (context, walletProvider, child) {
        return Column(
          children: [
            const SizedBox(height: AccountantThemeConfig.defaultPadding),

            // Add Wallet Button
            Container(
              margin: const EdgeInsets.symmetric(horizontal: AccountantThemeConfig.defaultPadding),
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: AccountantThemeConfig.greenGradient,
                borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
              ),
              child: ElevatedButton.icon(
                onPressed: () => _showAddWalletDialog(),
                icon: const Icon(Icons.add),
                label: Text('إضافة محفظة جديدة', style: AccountantThemeConfig.labelLarge),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: AccountantThemeConfig.defaultPadding),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                  ),
                ),
              ),
            ),

            const SizedBox(height: AccountantThemeConfig.defaultPadding),

            // Wallets List
            Expanded(
              child: _buildWalletsList(walletProvider),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWalletsList(ElectronicWalletProvider walletProvider) {
    if (walletProvider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
        ),
      );
    }

    if (walletProvider.wallets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.account_balance_wallet_outlined,
              size: 64,
              color: Colors.white24,
            ),
            const SizedBox(height: 16),
            const Text(
              'لا توجد محافظ مسجلة',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showAddWalletDialog(),
              icon: const Icon(Icons.add),
              label: const Text('إضافة محفظة جديدة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    // Group wallets by type
    final vodafoneWallets = walletProvider.vodafoneWallets;
    final instapayWallets = walletProvider.instapayWallets;

    return RefreshIndicator(
      onRefresh: () async {
        await walletProvider.loadWallets();
      },
      color: const Color(0xFF10B981),
      backgroundColor: Colors.grey[900],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vodafone Cash Section
            if (vodafoneWallets.isNotEmpty) ...[
              _buildWalletTypeSection(
                'محافظ فودافون كاش',
                vodafoneWallets,
                const Color(0xFFE60012),
                Icons.phone_android,
              ),
              const SizedBox(height: 24),
            ],

            // InstaPay Section
            if (instapayWallets.isNotEmpty) ...[
              _buildWalletTypeSection(
                'محافظ إنستاباي',
                instapayWallets,
                const Color(0xFF1E88E5),
                Icons.credit_card,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWalletTypeSection(
    String title,
    List<ElectronicWalletModel> wallets,
    Color color,
    IconData icon,
  ) {
    final totalBalance = wallets.fold<double>(0.0, (sum, wallet) => sum + wallet.currentBalance);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'إجمالي الرصيد: ${totalBalance.toStringAsFixed(2)} ج.م',
                      style: TextStyle(
                        color: color.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${wallets.length} محفظة',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Wallet Cards
        ...wallets.map((wallet) => _buildWalletCard(wallet, color)),
      ],
    );
  }

  Widget _buildWalletCard(ElectronicWalletModel wallet, Color typeColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
        border: AccountantThemeConfig.glowBorder(typeColor),
        boxShadow: [
          BoxShadow(
            color: typeColor.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Compact Header
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    wallet.walletTypeIcon,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      wallet.walletName,
                      style: AccountantThemeConfig.bodyLarge.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      wallet.walletTypeDisplayName,
                      style: AccountantThemeConfig.bodySmall.copyWith(
                        color: typeColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(wallet.status).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getStatusColor(wallet.status).withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  wallet.statusDisplayName,
                  style: TextStyle(
                    color: _getStatusColor(wallet.status),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Compact Wallet Details
          Row(
            children: [
              Expanded(
                child: _buildCompactDetailItem(
                  'الهاتف',
                  wallet.formattedPhoneNumberRTL,
                  Icons.phone,
                  AccountantThemeConfig.accentBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCompactDetailItem(
                  'الرصيد',
                  wallet.formattedBalance,
                  Icons.account_balance_wallet,
                  AccountantThemeConfig.primaryGreen,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Compact Action Buttons
          Row(
            children: [
              Expanded(
                child: _buildCompactActionButton(
                  'تعديل',
                  Icons.edit,
                  typeColor,
                  () => _showEditWalletDialog(wallet),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactActionButton(
                  'الرصيد',
                  Icons.account_balance_wallet,
                  AccountantThemeConfig.warningOrange,
                  () => _showEditBalanceDialog(wallet),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactActionButton(
                  'المعاملات',
                  Icons.history,
                  AccountantThemeConfig.primaryGreen,
                  () => _showWalletTransactions(wallet),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: AccountantThemeConfig.dangerRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AccountantThemeConfig.dangerRed.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
                child: IconButton(
                  onPressed: () => _showDeleteWalletDialog(wallet),
                  icon: const Icon(Icons.delete, size: 16),
                  color: AccountantThemeConfig.dangerRed,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactDetailItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AccountantThemeConfig.bodySmall.copyWith(
                    fontSize: 9,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                Text(
                  value,
                  style: AccountantThemeConfig.bodySmall.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactActionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            child: Column(
              children: [
                Icon(icon, color: color, size: 14),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: AccountantThemeConfig.bodySmall.copyWith(
                    fontSize: 9,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: AccountantThemeConfig.bodySmall.copyWith(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AccountantThemeConfig.bodySmall.copyWith(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(ElectronicWalletStatus status) {
    switch (status) {
      case ElectronicWalletStatus.active:
        return const Color(0xFF10B981);
      case ElectronicWalletStatus.inactive:
        return const Color(0xFF6B7280);
      case ElectronicWalletStatus.suspended:
        return const Color(0xFFEF4444);
    }
  }

  void _showAddWalletDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final balanceController = TextEditingController(text: '0.0');
    final descriptionController = TextEditingController();

    ElectronicWalletType selectedType = ElectronicWalletType.vodafoneCash;
    const ElectronicWalletStatus selectedStatus = ElectronicWalletStatus.active;

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.transparent,
              contentPadding: EdgeInsets.zero,
              content: Container(
                decoration: AccountantThemeConfig.primaryCardDecoration,
                padding: const EdgeInsets.all(AccountantThemeConfig.largePadding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'إضافة محفظة جديدة',
                      style: AccountantThemeConfig.headlineMedium,
                    ),
                  const SizedBox(height: AccountantThemeConfig.defaultPadding),
                  // Form content
                  Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Wallet Type
                          DropdownButtonFormField<ElectronicWalletType>(
                            value: selectedType,
                            decoration: InputDecoration(
                              labelText: 'نوع المحفظة',
                              labelStyle: const TextStyle(color: Colors.white70),
                              filled: true,
                              fillColor: Colors.grey[800],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            dropdownColor: Colors.grey[800],
                            style: const TextStyle(color: Colors.white),
                            items: ElectronicWalletType.values.map((type) {
                              return DropdownMenuItem(
                                value: type,
                                child: Text(
                                  type == ElectronicWalletType.vodafoneCash
                                      ? 'فودافون كاش'
                                      : 'إنستاباي',
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedType = value!;
                              });
                            },
                          ),
                          const SizedBox(height: 16),

                          // Wallet Name
                          TextFormField(
                            controller: nameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'اسم المحفظة',
                              labelStyle: const TextStyle(color: Colors.white70),
                              filled: true,
                              fillColor: Colors.grey[800],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'يرجى إدخال اسم المحفظة';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Phone Number
                          TextFormField(
                            controller: phoneController,
                            style: const TextStyle(color: Colors.white),
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: 'رقم الهاتف',
                              labelStyle: const TextStyle(color: Colors.white70),
                              filled: true,
                              fillColor: Colors.grey[800],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              hintText: '01012345678',
                              hintStyle: const TextStyle(color: Colors.white38),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'يرجى إدخال رقم الهاتف';
                              }
                              if (!ElectronicWalletModel.isValidEgyptianPhoneNumber(value)) {
                                return 'رقم الهاتف غير صالح';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Initial Balance
                          TextFormField(
                            controller: balanceController,
                            style: const TextStyle(color: Colors.white),
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'الرصيد الابتدائي (ج.م)',
                              labelStyle: const TextStyle(color: Colors.white70),
                              filled: true,
                              fillColor: Colors.grey[800],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'يرجى إدخال الرصيد الابتدائي';
                              }
                              final balance = double.tryParse(value);
                              if (balance == null || balance < 0) {
                                return 'يرجى إدخال رصيد صالح';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Description
                          TextFormField(
                            controller: descriptionController,
                            style: const TextStyle(color: Colors.white),
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: 'الوصف (اختياري)',
                              labelStyle: const TextStyle(color: Colors.white70),
                              filled: true,
                              fillColor: Colors.grey[800],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AccountantThemeConfig.defaultPadding),
                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('إلغاء', style: AccountantThemeConfig.labelMedium.copyWith(color: Colors.white70)),
                      ),
                      const SizedBox(width: AccountantThemeConfig.smallPadding),
                      Container(
                        decoration: BoxDecoration(
                          gradient: AccountantThemeConfig.greenGradient,
                          borderRadius: BorderRadius.circular(AccountantThemeConfig.smallBorderRadius),
                        ),
                        child: ElevatedButton(
                          onPressed: () => _createWallet(
                            formKey,
                            selectedType,
                            nameController.text,
                            phoneController.text,
                            double.tryParse(balanceController.text) ?? 0.0,
                            selectedStatus,
                            descriptionController.text,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            elevation: 0,
                          ),
                          child: Text('إضافة', style: AccountantThemeConfig.labelMedium),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _createWallet(
    GlobalKey<FormState> formKey,
    ElectronicWalletType walletType,
    String walletName,
    String phoneNumber,
    double initialBalance,
    ElectronicWalletStatus status,
    String description,
  ) async {
    if (!formKey.currentState!.validate()) return;

    Navigator.of(context).pop();

    final walletProvider = Provider.of<ElectronicWalletProvider>(context, listen: false);
    final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);

    final wallet = await walletProvider.createWallet(
      walletType: walletType,
      phoneNumber: phoneNumber.trim(),
      walletName: walletName.trim(),
      initialBalance: initialBalance,
      status: status,
      description: description.trim().isEmpty ? null : description.trim(),
      createdBy: supabaseProvider.user?.id,
    );

    if (wallet != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إنشاء المحفظة بنجاح'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
      // Reload statistics
      walletProvider.loadStatistics();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(walletProvider.error ?? 'فشل في إنشاء المحفظة'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showEditWalletDialog(ElectronicWalletModel wallet) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: wallet.walletName);
    final descriptionController = TextEditingController(text: wallet.description ?? '');

    ElectronicWalletStatus selectedStatus = wallet.status;

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text(
              'تعديل المحفظة',
              style: TextStyle(color: Colors.white),
            ),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Wallet Name
                  TextFormField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'اسم المحفظة',
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: Colors.grey[800],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'يرجى إدخال اسم المحفظة';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                  // Status
                  DropdownButtonFormField<ElectronicWalletStatus>(
                  value: selectedStatus,
                  decoration: InputDecoration(
                    labelText: 'حالة المحفظة',
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: Colors.grey[800],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  dropdownColor: Colors.grey[800],
                  style: const TextStyle(color: Colors.white),
                  items: ElectronicWalletStatus.values.map((status) {
                    return DropdownMenuItem(
                      value: status,
                      child: Text(
                        status == ElectronicWalletStatus.active
                            ? 'نشط'
                            : status == ElectronicWalletStatus.inactive
                                ? 'غير نشط'
                                : 'معلق',
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedStatus = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),

                  // Description
                  TextFormField(
                  controller: descriptionController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'الوصف (اختياري)',
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: Colors.grey[800],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => _updateWallet(
                  formKey,
                  wallet.id,
                  nameController.text,
                  selectedStatus,
                  descriptionController.text,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                ),
                child: const Text('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateWallet(
    GlobalKey<FormState> formKey,
    String walletId,
    String walletName,
    ElectronicWalletStatus status,
    String description,
  ) async {
    if (!formKey.currentState!.validate()) return;

    Navigator.of(context).pop();

    final walletProvider = Provider.of<ElectronicWalletProvider>(context, listen: false);

    final updatedWallet = await walletProvider.updateWallet(
      walletId: walletId,
      walletName: walletName.trim(),
      status: status,
      description: description.trim().isEmpty ? null : description.trim(),
    );

    if (updatedWallet != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث المحفظة بنجاح'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
      // Reload statistics
      walletProvider.loadStatistics();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(walletProvider.error ?? 'فشل في تحديث المحفظة'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteWalletDialog(ElectronicWalletModel wallet) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'حذف المحفظة',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'هل أنت متأكد من حذف المحفظة "${wallet.walletName}"؟',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Text(
                'رقم الهاتف: ${wallet.formattedPhoneNumber}',
                style: const TextStyle(color: Colors.white70),
              ),
              Text(
                'الرصيد: ${wallet.formattedBalance}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              const Text(
                'تحذير: لا يمكن التراجع عن هذا الإجراء!',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => _deleteWallet(wallet.id),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteWallet(String walletId) async {
    Navigator.of(context).pop();

    final walletProvider = Provider.of<ElectronicWalletProvider>(context, listen: false);

    final success = await walletProvider.deleteWallet(walletId);

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف المحفظة بنجاح'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
      // Reload statistics
      walletProvider.loadStatistics();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(walletProvider.error ?? 'فشل في حذف المحفظة'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showEditBalanceDialog(ElectronicWalletModel wallet) {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();

    String operationType = 'add'; // 'add' or 'subtract'
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: Row(
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  color: const Color(0xFFF59E0B),
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'تعديل رصيد المحفظة',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ],
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Wallet Info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Color(wallet.walletTypeColor).withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              wallet.walletTypeIcon,
                              style: const TextStyle(fontSize: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    wallet.walletName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    wallet.formattedPhoneNumberRTL,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                    textDirection: TextDirection.ltr,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.account_balance_wallet,
                                color: Color(0xFF10B981),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'الرصيد الحالي: ${wallet.formattedBalance}',
                                style: const TextStyle(
                                  color: Color(0xFF10B981),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Operation Type Selection
                  const Text(
                    'نوع العملية:',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text(
                            'إضافة رصيد',
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                          value: 'add',
                          groupValue: operationType,
                          activeColor: const Color(0xFF10B981),
                          onChanged: (value) {
                            setState(() {
                              operationType = value!;
                            });
                          },
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text(
                            'خصم رصيد',
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                          value: 'subtract',
                          groupValue: operationType,
                          activeColor: Colors.red,
                          onChanged: (value) {
                            setState(() {
                              operationType = value!;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Amount Input
                  TextFormField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'المبلغ',
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: Icon(
                        Icons.attach_money,
                        color: operationType == 'add' ? const Color(0xFF10B981) : Colors.red,
                      ),
                      suffixText: 'ج.م',
                      suffixStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.grey[800],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: operationType == 'add' ? const Color(0xFF10B981) : Colors.red,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'يرجى إدخال المبلغ';
                      }
                      final amount = double.tryParse(value);
                      if (amount == null || amount <= 0) {
                        return 'يرجى إدخال مبلغ صحيح';
                      }
                      if (operationType == 'subtract' && amount > wallet.currentBalance) {
                        return 'المبلغ أكبر من الرصيد المتاح';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Description Input
                  TextFormField(
                    controller: descriptionController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'سبب التعديل (اختياري)',
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(
                        Icons.description,
                        color: Colors.white70,
                      ),
                      filled: true,
                      fillColor: Colors.grey[800],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFF59E0B)),
                      ),
                    ),
                  ),
                ],
              ),
              ),
            ),
            actions: [
              TextButton(
              onPressed: isLoading ? null : () => Navigator.of(context).pop(),
              child: const Text(
                'إلغاء',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            ElevatedButton.icon(
              onPressed: isLoading ? null : () async {
                if (formKey.currentState!.validate()) {
                  setState(() {
                    isLoading = true;
                  });

                  await _processBalanceEdit(
                    wallet,
                    double.parse(amountController.text),
                    operationType,
                    descriptionController.text.trim(),
                  );

                  setState(() {
                    isLoading = false;
                  });

                  Navigator.of(context).pop();
                }
              },
              icon: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(
                      operationType == 'add' ? Icons.add : Icons.remove,
                      size: 16,
                    ),
              label: Text(
                isLoading
                    ? 'جاري التحديث...'
                    : operationType == 'add'
                        ? 'إضافة رصيد'
                        : 'خصم رصيد',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: operationType == 'add' ? const Color(0xFF10B981) : Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _processBalanceEdit(
    ElectronicWalletModel wallet,
    double amount,
    String operationType,
    String description,
  ) async {
    final walletProvider = Provider.of<ElectronicWalletProvider>(context, listen: false);
    final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);

    // Set critical operation flag to prevent AuthSyncService interference
    AuthSyncService.setCriticalOperationInProgress(true);

    try {
      // Import the electronic wallet service
      final electronicWalletService = ElectronicWalletService();

      // Determine transaction type and final amount
      final transactionType = operationType == 'add'
          ? ElectronicWalletTransactionType.deposit
          : ElectronicWalletTransactionType.withdrawal;

      // Amount should always be positive - the database function handles the subtraction for withdrawals
      final finalAmount = amount;

      // Create description
      final finalDescription = description.isNotEmpty
          ? description
          : operationType == 'add'
              ? 'تعديل يدوي - إضافة رصيد'
              : 'تعديل يدوي - خصم رصيد';

      // Get current user ID for processedBy
      final currentUser = supabaseProvider.supabase.auth.currentUser;
      final processedBy = currentUser?.id;

      // Update wallet balance
      final transactionId = await electronicWalletService.updateWalletBalance(
        walletId: wallet.id,
        amount: finalAmount,
        transactionType: transactionType,
        description: finalDescription,
        processedBy: processedBy,
      );

      if (transactionId != null) {
        // Reload wallets and statistics
        await walletProvider.loadWallets();
        await walletProvider.loadStatistics();
        await walletProvider.loadAllTransactions();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                operationType == 'add'
                    ? 'تم إضافة ${amount.toStringAsFixed(2)} ج.م بنجاح'
                    : 'تم خصم ${amount.toStringAsFixed(2)} ج.م بنجاح',
              ),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      } else {
        throw Exception('فشل في تحديث رصيد المحفظة');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحديث الرصيد: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // Clear critical operation flag
      AuthSyncService.setCriticalOperationInProgress(false);
    }
  }

  void _showWalletTransactions(ElectronicWalletModel wallet) {
    Navigator.pushNamed(
      context,
      '/accountant/wallet-transactions',
      arguments: {
        'wallet': wallet,
      },
    );
  }
}
