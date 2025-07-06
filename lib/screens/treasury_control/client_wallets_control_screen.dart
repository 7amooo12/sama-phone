import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/accountant_theme_config.dart';
import '../../providers/wallet_provider.dart';
import '../../models/wallet_model.dart';
import '../../models/wallet_transaction_model.dart';
import '../../services/wallet_service.dart';
import '../../utils/app_logger.dart';
import '../../utils/formatters.dart';

class ClientWalletsControlScreen extends StatefulWidget {
  const ClientWalletsControlScreen({super.key});

  @override
  State<ClientWalletsControlScreen> createState() => _ClientWalletsControlScreenState();
}

class _ClientWalletsControlScreenState extends State<ClientWalletsControlScreen>
    with TickerProviderStateMixin {
  final _walletService = WalletService();
  
  List<WalletModel> _clientWallets = [];
  List<WalletTransactionModel> _transactions = [];
  Map<String, dynamic> _statistics = {};
  bool _isLoading = false;
  String? _error;
  WalletModel? _selectedWallet;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final walletProvider = context.read<WalletProvider>();
      await walletProvider.loadWalletsByRole('client');
      
      setState(() {
        _clientWallets = walletProvider.clientWallets;
      });

      // Load statistics
      await _loadStatistics();
      
      // Load recent transactions if a wallet is selected
      if (_selectedWallet != null) {
        await _loadWalletTransactions(_selectedWallet!.id);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStatistics() async {
    try {
      final totalBalance = _clientWallets.fold(0.0, (sum, wallet) => sum + wallet.balance);
      final activeWallets = _clientWallets.where((w) => w.status == WalletStatus.active).length;
      final suspendedWallets = _clientWallets.where((w) => w.status == WalletStatus.suspended).length;
      
      setState(() {
        _statistics = {
          'total_wallets': _clientWallets.length,
          'active_wallets': activeWallets,
          'suspended_wallets': suspendedWallets,
          'total_balance': totalBalance,
          'average_balance': _clientWallets.isNotEmpty ? totalBalance / _clientWallets.length : 0.0,
        };
      });
    } catch (e) {
      AppLogger.error('Error loading statistics: $e');
    }
  }

  Future<void> _loadWalletTransactions(String walletId) async {
    try {
      final transactions = await _walletService.getWalletTransactions(
        walletId: walletId,
        limit: 50,
      );
      
      setState(() {
        _transactions = transactions;
      });
    } catch (e) {
      AppLogger.error('Error loading wallet transactions: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AccountantThemeConfig.backgroundColor,
      appBar: _buildAppBar(),
      body: _isLoading
          ? _buildLoadingState()
          : _error != null
              ? _buildErrorState()
              : _buildContent(),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(
          Icons.arrow_back_ios_rounded,
          color: Colors.white,
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'إدارة محافظ العملاء',
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '${_clientWallets.length} محفظة عميل',
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: AccountantThemeConfig.white70,
            ),
          ),
        ],
      ),
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: AccountantThemeConfig.primaryGreen,
        labelColor: Colors.white,
        unselectedLabelColor: AccountantThemeConfig.white60,
        labelStyle: AccountantThemeConfig.bodyMedium.copyWith(
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: AccountantThemeConfig.bodyMedium,
        tabs: const [
          Tab(
            icon: Icon(Icons.account_balance_wallet_rounded, size: 20),
            text: 'المحافظ',
          ),
          Tab(
            icon: Icon(Icons.receipt_long_rounded, size: 20),
            text: 'المعاملات',
          ),
          Tab(
            icon: Icon(Icons.analytics_rounded, size: 20),
            text: 'الإحصائيات',
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(AccountantThemeConfig.primaryGreen),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: AccountantThemeConfig.cardGradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'حدث خطأ',
              style: AccountantThemeConfig.headlineSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: AccountantThemeConfig.white70,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(
                backgroundColor: AccountantThemeConfig.primaryGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildWalletsTab(),
        _buildTransactionsTab(),
        _buildStatisticsTab(),
      ],
    );
  }

  Widget _buildWalletsTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AccountantThemeConfig.primaryGreen,
      backgroundColor: Colors.grey[900],
      child: _clientWallets.isEmpty
          ? _buildEmptyWalletsState()
          : _buildWalletsList(),
    );
  }

  Widget _buildEmptyWalletsState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.account_balance_wallet_outlined,
              size: 64,
              color: AccountantThemeConfig.white60,
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد محافظ عملاء',
              style: AccountantThemeConfig.headlineSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'لم يتم العثور على محافظ للعملاء في النظام',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: AccountantThemeConfig.white70,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _clientWallets.length,
      itemBuilder: (context, index) {
        final wallet = _clientWallets[index];
        return _buildWalletCard(wallet);
      },
    );
  }

  Widget _buildWalletCard(WalletModel wallet) {
    final isSelected = _selectedWallet?.id == wallet.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? AccountantThemeConfig.primaryGreen
              : AccountantThemeConfig.accentBlue.withValues(alpha: 0.3),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected ? [
          BoxShadow(
            color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ] : AccountantThemeConfig.cardShadows,
      ),
      child: InkWell(
        onTap: () => _selectWallet(wallet),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AccountantThemeConfig.primaryGreen.withValues(alpha: 0.8),
                          AccountantThemeConfig.accentBlue.withValues(alpha: 0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
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
                          wallet.userName ?? 'عميل غير محدد',
                          style: AccountantThemeConfig.bodyLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (wallet.userEmail != null)
                          Text(
                            wallet.userEmail!,
                            style: AccountantThemeConfig.bodyMedium.copyWith(
                              color: AccountantThemeConfig.white70,
                            ),
                          ),
                        if (wallet.phoneNumber != null)
                          Text(
                            wallet.phoneNumber!,
                            style: AccountantThemeConfig.bodySmall.copyWith(
                              color: AccountantThemeConfig.white60,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(wallet.status).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getStatusText(wallet.status),
                      style: AccountantThemeConfig.bodySmall.copyWith(
                        color: _getStatusColor(wallet.status),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white24),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الرصيد الحالي',
                        style: AccountantThemeConfig.bodySmall.copyWith(
                          color: AccountantThemeConfig.white60,
                        ),
                      ),
                      Text(
                        '${wallet.balance.toStringAsFixed(2)} ${wallet.currency}',
                        style: AccountantThemeConfig.headlineSmall.copyWith(
                          color: AccountantThemeConfig.primaryGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (wallet.transactionCount != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'عدد المعاملات',
                          style: AccountantThemeConfig.bodySmall.copyWith(
                            color: AccountantThemeConfig.white60,
                          ),
                        ),
                        Text(
                          wallet.transactionCount.toString(),
                          style: AccountantThemeConfig.bodyLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              if (wallet.lastTransactionDate != null) ...[
                const SizedBox(height: 8),
                Text(
                  'آخر معاملة: ${_formatDate(wallet.lastTransactionDate!)}',
                  style: AccountantThemeConfig.bodySmall.copyWith(
                    color: AccountantThemeConfig.white60,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showWalletDetails(wallet),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AccountantThemeConfig.accentBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.visibility_rounded, size: 18),
                      label: const Text('التفاصيل'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showBalanceUpdateDialog(wallet),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AccountantThemeConfig.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.account_balance_rounded, size: 18),
                      label: const Text('تحديث الرصيد'),
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

  Widget _buildTransactionsTab() {
    if (_selectedWallet == null) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.touch_app_rounded,
                size: 64,
                color: AccountantThemeConfig.white60,
              ),
              const SizedBox(height: 16),
              Text(
                'اختر محفظة لعرض المعاملات',
                style: AccountantThemeConfig.headlineSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'انقر على إحدى المحافظ في التبويب الأول لعرض معاملاتها',
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: AccountantThemeConfig.white70,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadWalletTransactions(_selectedWallet!.id),
      color: AccountantThemeConfig.primaryGreen,
      backgroundColor: Colors.grey[900],
      child: Column(
        children: [
          _buildSelectedWalletHeader(),
          Expanded(
            child: _transactions.isEmpty
                ? _buildEmptyTransactionsState()
                : _buildTransactionsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedWalletHeader() {
    if (_selectedWallet == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: AccountantThemeConfig.primaryGreen,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedWallet!.userName ?? 'عميل غير محدد',
                  style: AccountantThemeConfig.bodyLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'رصيد: ${_selectedWallet!.balance.toStringAsFixed(2)} ${_selectedWallet!.currency}',
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    color: AccountantThemeConfig.white70,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${_transactions.length} معاملة',
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: AccountantThemeConfig.accentBlue,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTransactionsState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: AccountantThemeConfig.white60,
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد معاملات',
              style: AccountantThemeConfig.headlineSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'لا توجد معاملات لهذه المحفظة',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: AccountantThemeConfig.white70,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _transactions.length,
      itemBuilder: (context, index) {
        final transaction = _transactions[index];
        return _buildTransactionCard(transaction);
      },
    );
  }

  Widget _buildTransactionCard(WalletTransactionModel transaction) {
    final isCredit = transaction.transactionType == TransactionType.credit;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCredit
              ? AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3)
              : Colors.red.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isCredit ? AccountantThemeConfig.primaryGreen : Colors.red).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isCredit ? Icons.add_rounded : Icons.remove_rounded,
                  color: isCredit ? AccountantThemeConfig.primaryGreen : Colors.red,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.description,
                      style: AccountantThemeConfig.bodyLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _formatDate(transaction.createdAt),
                      style: AccountantThemeConfig.bodySmall.copyWith(
                        color: AccountantThemeConfig.white60,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isCredit ? '+' : '-'}${transaction.amount.toStringAsFixed(2)}',
                    style: AccountantThemeConfig.bodyLarge.copyWith(
                      color: isCredit ? AccountantThemeConfig.primaryGreen : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'الرصيد: ${transaction.balanceAfter.toStringAsFixed(2)}',
                    style: AccountantThemeConfig.bodySmall.copyWith(
                      color: AccountantThemeConfig.white60,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (transaction.referenceId != null) ...[
            const SizedBox(height: 8),
            Text(
              'مرجع: ${transaction.referenceId}',
              style: AccountantThemeConfig.bodySmall.copyWith(
                color: AccountantThemeConfig.white60,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatisticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatisticsOverview(),
          const SizedBox(height: 16),
          _buildWalletStatusChart(),
        ],
      ),
    );
  }

  Widget _buildStatisticsOverview() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'نظرة عامة على المحافظ',
            style: AccountantThemeConfig.bodyLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'إجمالي المحافظ',
                  _statistics['total_wallets']?.toString() ?? '0',
                  Icons.account_balance_wallet_rounded,
                  AccountantThemeConfig.accentBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'المحافظ النشطة',
                  _statistics['active_wallets']?.toString() ?? '0',
                  Icons.check_circle_rounded,
                  AccountantThemeConfig.primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'إجمالي الأرصدة',
                  '${(_statistics['total_balance'] as double?)?.toStringAsFixed(2) ?? '0.00'} ج.م',
                  Icons.account_balance_rounded,
                  AccountantThemeConfig.primaryGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'متوسط الرصيد',
                  '${(_statistics['average_balance'] as double?)?.toStringAsFixed(2) ?? '0.00'} ج.م',
                  Icons.trending_up_rounded,
                  AccountantThemeConfig.accentBlue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: AccountantThemeConfig.bodyLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            title,
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: AccountantThemeConfig.white70,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildWalletStatusChart() {
    final activeWallets = _statistics['active_wallets'] as int? ?? 0;
    final suspendedWallets = _statistics['suspended_wallets'] as int? ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AccountantThemeConfig.accentBlue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'حالة المحافظ',
            style: AccountantThemeConfig.bodyLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildStatusRow('نشطة', activeWallets, AccountantThemeConfig.primaryGreen),
          const SizedBox(height: 8),
          _buildStatusRow('معلقة', suspendedWallets, Colors.orange),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, int count, Color color) {
    final total = _statistics['total_wallets'] as int? ?? 1;
    final percentage = total > 0 ? (count / total * 100) : 0.0;

    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white,
            ),
          ),
        ),
        Text(
          '$count (${percentage.toStringAsFixed(1)}%)',
          style: AccountantThemeConfig.bodyMedium.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: _loadData,
      backgroundColor: AccountantThemeConfig.primaryGreen,
      child: const Icon(
        Icons.refresh_rounded,
        color: Colors.white,
      ),
    );
  }

  // Helper methods
  void _selectWallet(WalletModel wallet) {
    setState(() {
      _selectedWallet = wallet;
    });
    _loadWalletTransactions(wallet.id);
    _tabController.animateTo(1); // Switch to transactions tab
  }

  Color _getStatusColor(WalletStatus status) {
    switch (status) {
      case WalletStatus.active:
        return AccountantThemeConfig.primaryGreen;
      case WalletStatus.suspended:
        return Colors.orange;
      case WalletStatus.closed:
        return Colors.red;
    }
  }

  String _getStatusText(WalletStatus status) {
    switch (status) {
      case WalletStatus.active:
        return 'نشطة';
      case WalletStatus.suspended:
        return 'معلقة';
      case WalletStatus.closed:
        return 'مغلقة';
    }
  }

  String _formatDate(DateTime date) {
    // Convert to local time if UTC to ensure proper timezone handling
    final localDate = date.isUtc ? date.toLocal() : date;

    // Use the standard formatter for consistent date/time display across the app
    return Formatters.formatDateTime(localDate);
  }

  void _showWalletDetails(WalletModel wallet) {
    // TODO: Implement wallet details dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'سيتم تنفيذ تفاصيل المحفظة قريباً',
          style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
        ),
        backgroundColor: AccountantThemeConfig.accentBlue,
      ),
    );
  }

  void _showBalanceUpdateDialog(WalletModel wallet) {
    // TODO: Implement balance update dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'سيتم تنفيذ تحديث الرصيد قريباً',
          style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
        ),
        backgroundColor: AccountantThemeConfig.primaryGreen,
      ),
    );
  }
}
