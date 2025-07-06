import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../utils/accountant_theme_config.dart';
import '../../../utils/formatters.dart';
import '../../../providers/treasury_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../../providers/electronic_wallet_provider.dart';
import '../../../models/treasury_models.dart';
import '../../../models/electronic_wallet_model.dart';
import '../../../widgets/common/animated_balance_widget.dart';
import '../../../services/treasury_transaction_service.dart';

/// Treasury Balance Management Tab
/// Handles balance display, editing, and history for treasuries and wallet summaries
class TreasuryBalanceTab extends StatefulWidget {
  final String treasuryId;
  final String treasuryType;

  const TreasuryBalanceTab({
    super.key,
    required this.treasuryId,
    required this.treasuryType,
  });

  @override
  State<TreasuryBalanceTab> createState() => _TreasuryBalanceTabState();
}

class _TreasuryBalanceTabState extends State<TreasuryBalanceTab> {
  final TreasuryTransactionService _transactionService = TreasuryTransactionService();
  final TextEditingController _balanceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  
  bool _isEditing = false;
  bool _isLoading = false;
  List<TreasuryTransaction> _recentTransactions = [];

  @override
  void initState() {
    super.initState();
    _loadRecentTransactions();
    _refreshTreasuryData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh data when returning to this tab
    _refreshTreasuryData();
  }

  @override
  void dispose() {
    _balanceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentTransactions() async {
    if (widget.treasuryType == 'treasury') {
      try {
        final transactions = await _transactionService.getRecentTransactions(
          treasuryId: widget.treasuryId,
          limit: 5,
        );
        setState(() {
          _recentTransactions = transactions;
        });
      } catch (e) {
        // Handle error silently for now
      }
    }
  }

  /// Refresh treasury data to ensure balance accuracy
  Future<void> _refreshTreasuryData() async {
    try {
      final treasuryProvider = context.read<TreasuryProvider>();
      await treasuryProvider.refreshAllData();
    } catch (e) {
      // Handle error silently to avoid disrupting UI
    }
  }

  /// Handle pull-to-refresh
  Future<void> _handleRefresh() async {
    try {
      await Future.wait([
        _refreshTreasuryData(),
        _loadRecentTransactions(),
      ]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'فشل في تحديث البيانات: $e',
              style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  double _getCurrentBalance({bool listen = true}) {
    switch (widget.treasuryType) {
      case 'treasury':
        final treasuryProvider = listen
            ? context.watch<TreasuryProvider>()
            : context.read<TreasuryProvider>();
        final treasury = treasuryProvider.treasuryVaults
            .where((t) => t.id == widget.treasuryId)
            .firstOrNull;
        return treasury?.balance ?? 0.0;
      case 'client_wallets':
        final walletProvider = listen
            ? context.watch<WalletProvider>()
            : context.read<WalletProvider>();
        return walletProvider.wallets
            .where((wallet) => wallet.role == 'client')
            .fold<double>(0.0, (sum, wallet) => sum + wallet.balance);
      case 'electronic_wallets':
        final walletProvider = listen
            ? context.watch<ElectronicWalletProvider>()
            : context.read<ElectronicWalletProvider>();
        return walletProvider.wallets
            .fold<double>(0.0, (sum, wallet) => sum + wallet.currentBalance);
      default:
        return 0.0;
    }
  }

  String _getCurrencySymbol({bool listen = true}) {
    switch (widget.treasuryType) {
      case 'treasury':
        final treasuryProvider = listen
            ? context.watch<TreasuryProvider>()
            : context.read<TreasuryProvider>();
        final treasury = treasuryProvider.treasuryVaults
            .where((t) => t.id == widget.treasuryId)
            .firstOrNull;
        return treasury?.currencySymbol ?? 'ج.م';
      default:
        return 'ج.م';
    }
  }

  bool _canEditBalance() {
    return widget.treasuryType == 'treasury';
  }

  @override
  Widget build(BuildContext context) {
    final currentBalance = _getCurrentBalance();
    final currencySymbol = _getCurrencySymbol();

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: AccountantThemeConfig.primaryGreen,
      backgroundColor: AccountantThemeConfig.cardColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Balance Card
            _buildCurrentBalanceCard(currentBalance, currencySymbol),

            const SizedBox(height: 20),

            // Balance Actions (only for treasuries)
            if (_canEditBalance()) ...[
              _buildBalanceActionsCard(),
              const SizedBox(height: 20),
            ],

            // Recent Transactions (only for treasuries)
            if (widget.treasuryType == 'treasury') ...[
              _buildRecentTransactionsCard(),
              const SizedBox(height: 20),
            ],

            // Statistics Card
            _buildStatisticsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentBalanceCard(double balance, String currencySymbol) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
                Icons.account_balance_wallet_rounded,
                color: AccountantThemeConfig.primaryGreen,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'الرصيد الحالي',
                style: AccountantThemeConfig.headlineSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Balance display
          AnimatedBalanceWidget(
            balance: balance,
            currencySymbol: currencySymbol,
            textStyle: AccountantThemeConfig.headlineLarge.copyWith(
              color: AccountantThemeConfig.primaryGreen,
              fontWeight: FontWeight.bold,
              fontSize: 32,
            ),
            animationDuration: const Duration(milliseconds: 1000),
          ),
          
          const SizedBox(height: 16),
          
          // Last updated info
          Row(
            children: [
              Icon(
                Icons.access_time_rounded,
                color: AccountantThemeConfig.white60,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'آخر تحديث: ${DateTime.now().toString().split('.')[0]}',
                style: AccountantThemeConfig.bodySmall.copyWith(
                  color: AccountantThemeConfig.white60,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceActionsCard() {
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
          Text(
            'إدارة الرصيد',
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 16),
          
          if (_isEditing) ...[
            _buildBalanceEditForm(),
          ] else ...[
            _buildBalanceActionButtons(),
          ],
        ],
      ),
    );
  }

  Widget _buildBalanceActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _showDepositDialog(),
            icon: const Icon(Icons.add_circle_rounded),
            label: const Text('إيداع'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AccountantThemeConfig.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        
        const SizedBox(width: 12),
        
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _showWithdrawalDialog(),
            icon: const Icon(Icons.remove_circle_rounded),
            label: const Text('سحب'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        
        const SizedBox(width: 12),
        
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _startBalanceEdit(),
            icon: const Icon(Icons.edit_rounded),
            label: const Text('تعديل'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AccountantThemeConfig.accentBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceEditForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _balanceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: AccountantThemeConfig.bodyLarge.copyWith(
              color: Colors.white,
            ),
            decoration: InputDecoration(
              labelText: 'الرصيد الجديد',
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
                return 'يرجى إدخال الرصيد';
              }
              if (double.tryParse(value) == null) {
                return 'يرجى إدخال رقم صحيح';
              }
              if (double.parse(value) < 0) {
                return 'لا يمكن أن يكون الرصيد سالباً';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 12),
          
          TextFormField(
            controller: _descriptionController,
            style: AccountantThemeConfig.bodyLarge.copyWith(
              color: Colors.white,
            ),
            decoration: InputDecoration(
              labelText: 'وصف التعديل',
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
                return 'يرجى إدخال وصف للتعديل';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveBalanceEdit,
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
                      : const Text('حفظ'),
                ),
              ),
              
              const SizedBox(width: 12),
              
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _cancelBalanceEdit,
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

  Widget _buildRecentTransactionsCard() {
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
                Icons.receipt_long_rounded,
                color: AccountantThemeConfig.accentBlue,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'آخر المعاملات',
                style: AccountantThemeConfig.headlineSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          if (_recentTransactions.isEmpty) ...[
            Center(
              child: Text(
                'لا توجد معاملات حديثة',
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: AccountantThemeConfig.white60,
                ),
              ),
            ),
          ] else ...[
            ..._recentTransactions.map((transaction) => _buildTransactionItem(transaction)),
          ],
        ],
      ),
    );
  }

  Widget _buildTransactionItem(TreasuryTransaction transaction) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            transaction.isCredit ? Icons.add_circle_rounded : Icons.remove_circle_rounded,
            color: transaction.isCredit ? AccountantThemeConfig.primaryGreen : Colors.red,
            size: 20,
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.transactionType.displayName,
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (transaction.description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    transaction.description!,
                    style: AccountantThemeConfig.bodySmall.copyWith(
                      color: AccountantThemeConfig.white60,
                    ),
                  ),
                ],
              ],
            ),
          ),

          Text(
            transaction.getFormattedAmount(_getCurrencySymbol(listen: false)),
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: transaction.isCredit ? AccountantThemeConfig.primaryGreen : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCard() {
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
          Text(
            'إحصائيات',
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Add statistics based on treasury type
          _buildStatisticsContent(),
        ],
      ),
    );
  }

  Widget _buildStatisticsContent() {
    switch (widget.treasuryType) {
      case 'client_wallets':
        return _buildClientWalletsStatistics();
      case 'electronic_wallets':
        return _buildElectronicWalletsStatistics();
      default:
        return _buildTreasuryStatistics();
    }
  }

  Widget _buildClientWalletsStatistics() {
    final walletProvider = context.watch<WalletProvider>();
    final clientWallets = walletProvider.wallets.where((w) => w.role == 'client').toList();
    final activeWallets = clientWallets.where((w) => w.isActive).length;
    final averageBalance = clientWallets.isNotEmpty 
        ? clientWallets.fold<double>(0.0, (sum, w) => sum + w.balance) / clientWallets.length
        : 0.0;

    return Column(
      children: [
        _buildStatItem('إجمالي المحافظ', clientWallets.length.toString()),
        _buildStatItem('المحافظ النشطة', activeWallets.toString()),
        _buildStatItem('متوسط الرصيد', '${averageBalance.toStringAsFixed(2)} ج.م'),
      ],
    );
  }

  Widget _buildElectronicWalletsStatistics() {
    final walletProvider = context.watch<ElectronicWalletProvider>();
    final vodafoneWallets = walletProvider.wallets
        .where((w) => w.walletType == ElectronicWalletType.vodafoneCash).length;
    final instapayWallets = walletProvider.wallets
        .where((w) => w.walletType == ElectronicWalletType.instaPay).length;

    return Column(
      children: [
        _buildStatItem('فودافون كاش', vodafoneWallets.toString()),
        _buildStatItem('إنستاباي', instapayWallets.toString()),
        _buildStatItem('إجمالي المحافظ', walletProvider.wallets.length.toString()),
      ],
    );
  }

  Widget _buildTreasuryStatistics() {
    return Column(
      children: [
        _buildStatItem('نوع الخزنة', widget.treasuryType),
        _buildStatItem('معرف الخزنة', widget.treasuryId.substring(0, 8)),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
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
          Text(
            value,
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _startBalanceEdit() {
    setState(() {
      _isEditing = true;
      _balanceController.text = _getCurrentBalance(listen: false).toString();
      _descriptionController.clear();
    });
  }

  void _cancelBalanceEdit() {
    setState(() {
      _isEditing = false;
      _balanceController.clear();
      _descriptionController.clear();
    });
  }

  Future<void> _saveBalanceEdit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final newBalance = double.parse(_balanceController.text);
      final description = _descriptionController.text;

      await context.read<TreasuryProvider>().updateTreasuryBalance(
        treasuryId: widget.treasuryId,
        newBalance: newBalance,
        transactionType: 'balance_adjustment',
        description: description,
      );

      await _loadRecentTransactions();

      setState(() {
        _isEditing = false;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم تحديث الرصيد بنجاح',
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
            'فشل في تحديث الرصيد: $e',
            style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDepositDialog() {
    final TextEditingController amountController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        content: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: AccountantThemeConfig.cardGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AccountantThemeConfig.cardShadows,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Icon(
                      Icons.add_circle_rounded,
                      color: AccountantThemeConfig.primaryGreen,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'إيداع في الخزنة',
                      style: AccountantThemeConfig.headlineSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Amount field
                TextFormField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: AccountantThemeConfig.bodyLarge.copyWith(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'مبلغ الإيداع',
                    labelStyle: AccountantThemeConfig.bodyMedium.copyWith(
                      color: AccountantThemeConfig.white70,
                    ),
                    prefixText: 'ج.م ',
                    prefixStyle: AccountantThemeConfig.bodyMedium.copyWith(
                      color: AccountantThemeConfig.primaryGreen,
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AccountantThemeConfig.primaryGreen, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'يرجى إدخال مبلغ الإيداع';
                    }
                    final amount = double.tryParse(value);
                    if (amount == null || amount <= 0) {
                      return 'يرجى إدخال مبلغ صحيح أكبر من صفر';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Description field
                TextFormField(
                  controller: descriptionController,
                  style: AccountantThemeConfig.bodyLarge.copyWith(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'وصف الإيداع',
                    labelStyle: AccountantThemeConfig.bodyMedium.copyWith(
                      color: AccountantThemeConfig.white70,
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AccountantThemeConfig.primaryGreen, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'يرجى إدخال وصف للإيداع';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 24),

                // Action buttons
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
                        onPressed: () async {
                          if (formKey.currentState!.validate()) {
                            Navigator.pop(context);
                            await _processDeposit(
                              double.parse(amountController.text),
                              descriptionController.text,
                            );
                          }
                        },
                        style: AccountantThemeConfig.primaryButtonStyle,
                        child: const Text('إيداع'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showWithdrawalDialog() {
    final TextEditingController amountController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final currentBalance = _getCurrentBalance(listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        content: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: AccountantThemeConfig.cardGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AccountantThemeConfig.cardShadows,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Icon(
                      Icons.remove_circle_rounded,
                      color: Colors.red,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'سحب من الخزنة',
                      style: AccountantThemeConfig.headlineSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Current balance info
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'الرصيد الحالي: ${Formatters.formatTreasuryBalance(currentBalance, _getCurrencySymbol(listen: false))}',
                    style: AccountantThemeConfig.bodyMedium.copyWith(
                      color: AccountantThemeConfig.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 16),

                // Amount field
                TextFormField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: AccountantThemeConfig.bodyLarge.copyWith(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'مبلغ السحب',
                    labelStyle: AccountantThemeConfig.bodyMedium.copyWith(
                      color: AccountantThemeConfig.white70,
                    ),
                    prefixText: '${_getCurrencySymbol(listen: false)} ',
                    prefixStyle: AccountantThemeConfig.bodyMedium.copyWith(
                      color: Colors.red,
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.red, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'يرجى إدخال مبلغ السحب';
                    }
                    final amount = double.tryParse(value);
                    if (amount == null || amount <= 0) {
                      return 'يرجى إدخال مبلغ صحيح أكبر من صفر';
                    }
                    if (amount > currentBalance) {
                      return 'مبلغ السحب أكبر من الرصيد المتاح';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Description field
                TextFormField(
                  controller: descriptionController,
                  style: AccountantThemeConfig.bodyLarge.copyWith(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'وصف السحب',
                    labelStyle: AccountantThemeConfig.bodyMedium.copyWith(
                      color: AccountantThemeConfig.white70,
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.red, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'يرجى إدخال وصف للسحب';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 24),

                // Action buttons
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
                        onPressed: () async {
                          if (formKey.currentState!.validate()) {
                            Navigator.pop(context);
                            await _processWithdrawal(
                              double.parse(amountController.text),
                              descriptionController.text,
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('سحب'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _processDeposit(double amount, String description) async {
    if (widget.treasuryType != 'treasury') return;

    try {
      setState(() {
        _isLoading = true;
      });

      final treasuryProvider = context.read<TreasuryProvider>();
      final currentBalance = _getCurrentBalance(listen: false);
      final newBalance = currentBalance + amount;

      await treasuryProvider.updateTreasuryBalance(
        treasuryId: widget.treasuryId,
        newBalance: newBalance,
        transactionType: 'credit',
        description: description,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم إيداع ${Formatters.formatTreasuryBalance(amount, _getCurrencySymbol(listen: false))} بنجاح',
            style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
          ),
          backgroundColor: AccountantThemeConfig.primaryGreen,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'فشل في الإيداع: $e',
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

  Future<void> _processWithdrawal(double amount, String description) async {
    if (widget.treasuryType != 'treasury') return;

    try {
      setState(() {
        _isLoading = true;
      });

      final treasuryProvider = context.read<TreasuryProvider>();
      final currentBalance = _getCurrentBalance(listen: false);
      final newBalance = currentBalance - amount;

      await treasuryProvider.updateTreasuryBalance(
        treasuryId: widget.treasuryId,
        newBalance: newBalance,
        transactionType: 'debit',
        description: description,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم سحب ${Formatters.formatTreasuryBalance(amount, _getCurrencySymbol(listen: false))} بنجاح',
            style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'فشل في السحب: $e',
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
