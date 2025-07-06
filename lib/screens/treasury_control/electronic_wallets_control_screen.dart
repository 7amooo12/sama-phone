import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/accountant_theme_config.dart';
import '../../providers/electronic_wallet_provider.dart';
import '../../models/electronic_wallet_model.dart';
import '../../models/electronic_wallet_transaction_model.dart';
import '../../services/electronic_wallet_service.dart';
import '../../utils/app_logger.dart';
import '../../utils/formatters.dart';

class ElectronicWalletsControlScreen extends StatefulWidget {
  const ElectronicWalletsControlScreen({super.key});

  @override
  State<ElectronicWalletsControlScreen> createState() => _ElectronicWalletsControlScreenState();
}

class _ElectronicWalletsControlScreenState extends State<ElectronicWalletsControlScreen>
    with TickerProviderStateMixin {
  final _walletService = ElectronicWalletService();
  
  List<ElectronicWalletModel> _vodafoneWallets = [];
  List<ElectronicWalletModel> _instapayWallets = [];
  List<ElectronicWalletTransactionModel> _transactions = [];
  Map<String, dynamic> _statistics = {};
  bool _isLoading = false;
  String? _error;
  ElectronicWalletModel? _selectedWallet;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
      final walletProvider = context.read<ElectronicWalletProvider>();
      await walletProvider.loadWallets();
      
      setState(() {
        _vodafoneWallets = walletProvider.vodafoneWallets;
        _instapayWallets = walletProvider.instapayWallets;
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
      final allWallets = [..._vodafoneWallets, ..._instapayWallets];
      final totalBalance = allWallets.fold(0.0, (sum, wallet) => sum + wallet.currentBalance);
      final activeWallets = allWallets.where((w) => w.status == ElectronicWalletStatus.active).length;
      final inactiveWallets = allWallets.where((w) => w.status == ElectronicWalletStatus.inactive).length;
      
      setState(() {
        _statistics = {
          'total_wallets': allWallets.length,
          'vodafone_wallets': _vodafoneWallets.length,
          'instapay_wallets': _instapayWallets.length,
          'active_wallets': activeWallets,
          'inactive_wallets': inactiveWallets,
          'total_balance': totalBalance,
          'average_balance': allWallets.isNotEmpty ? totalBalance / allWallets.length : 0.0,
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
            'إدارة المحافظ الإلكترونية',
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '${_vodafoneWallets.length + _instapayWallets.length} محفظة إلكترونية',
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
        isScrollable: true,
        tabs: const [
          Tab(
            icon: Icon(Icons.phone_android_rounded, size: 20),
            text: 'فودافون كاش',
          ),
          Tab(
            icon: Icon(Icons.credit_card_rounded, size: 20),
            text: 'إنستاباي',
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
        _buildVodafoneWalletsTab(),
        _buildInstapayWalletsTab(),
        _buildTransactionsTab(),
        _buildStatisticsTab(),
      ],
    );
  }

  Widget _buildVodafoneWalletsTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AccountantThemeConfig.primaryGreen,
      backgroundColor: Colors.grey[900],
      child: _vodafoneWallets.isEmpty
          ? _buildEmptyWalletsState('فودافون كاش')
          : _buildWalletsList(_vodafoneWallets, const Color(0xFFE60012)),
    );
  }

  Widget _buildInstapayWalletsTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AccountantThemeConfig.primaryGreen,
      backgroundColor: Colors.grey[900],
      child: _instapayWallets.isEmpty
          ? _buildEmptyWalletsState('إنستاباي')
          : _buildWalletsList(_instapayWallets, const Color(0xFF1E88E5)),
    );
  }

  Widget _buildEmptyWalletsState(String walletType) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              walletType == 'فودافون كاش' 
                  ? Icons.phone_android_outlined
                  : Icons.credit_card_outlined,
              size: 64,
              color: AccountantThemeConfig.white60,
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد محافظ $walletType',
              style: AccountantThemeConfig.headlineSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'لم يتم العثور على محافظ $walletType في النظام',
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

  Widget _buildWalletsList(List<ElectronicWalletModel> wallets, Color themeColor) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: wallets.length,
      itemBuilder: (context, index) {
        final wallet = wallets[index];
        return _buildWalletCard(wallet, themeColor);
      },
    );
  }

  Widget _buildWalletCard(ElectronicWalletModel wallet, Color themeColor) {
    final isSelected = _selectedWallet?.id == wallet.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? AccountantThemeConfig.primaryGreen
              : themeColor.withValues(alpha: 0.3),
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
                      color: themeColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      wallet.walletType == ElectronicWalletType.vodafoneCash
                          ? Icons.phone_android_rounded
                          : Icons.credit_card_rounded,
                      color: themeColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          wallet.walletName,
                          style: AccountantThemeConfig.bodyLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          wallet.formattedPhoneNumberRTL,
                          style: AccountantThemeConfig.bodyMedium.copyWith(
                            color: AccountantThemeConfig.white70,
                          ),
                          textDirection: TextDirection.ltr,
                        ),
                        if (wallet.description != null)
                          Text(
                            wallet.description!,
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
                        wallet.formattedBalance,
                        style: AccountantThemeConfig.headlineSmall.copyWith(
                          color: themeColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'نوع المحفظة',
                        style: AccountantThemeConfig.bodySmall.copyWith(
                          color: AccountantThemeConfig.white60,
                        ),
                      ),
                      Text(
                        wallet.walletTypeDisplayName,
                        style: AccountantThemeConfig.bodyLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'تم الإنشاء: ${_formatDate(wallet.createdAt)}',
                style: AccountantThemeConfig.bodySmall.copyWith(
                  color: AccountantThemeConfig.white60,
                ),
              ),
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
                        backgroundColor: themeColor,
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
                'انقر على إحدى المحافظ في التبويبات الأولى لعرض معاملاتها',
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

    final themeColor = _selectedWallet!.walletType == ElectronicWalletType.vodafoneCash
        ? const Color(0xFFE60012)
        : const Color(0xFF1E88E5);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: themeColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: themeColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _selectedWallet!.walletType == ElectronicWalletType.vodafoneCash
                  ? Icons.phone_android_rounded
                  : Icons.credit_card_rounded,
              color: themeColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedWallet!.walletName,
                  style: AccountantThemeConfig.bodyLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'رصيد: ${_selectedWallet!.formattedBalance}',
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
              color: themeColor,
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

  Widget _buildTransactionCard(ElectronicWalletTransactionModel transaction) {
    final isCredit = transaction.transactionType == ElectronicWalletTransactionType.deposit ||
                     transaction.transactionType == ElectronicWalletTransactionType.refund;

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
                      transaction.description ?? 'معاملة إلكترونية',
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
                    '${isCredit ? '+' : '-'}${transaction.amount.toStringAsFixed(2)} ج.م',
                    style: AccountantThemeConfig.bodyLarge.copyWith(
                      color: isCredit ? AccountantThemeConfig.primaryGreen : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'الرصيد: ${transaction.balanceAfter.toStringAsFixed(2)} ج.م',
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
          _buildWalletTypeChart(),
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
            'نظرة عامة على المحافظ الإلكترونية',
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

  Widget _buildWalletTypeChart() {
    final vodafoneWallets = _statistics['vodafone_wallets'] as int? ?? 0;
    final instapayWallets = _statistics['instapay_wallets'] as int? ?? 0;

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
            'توزيع المحافظ حسب النوع',
            style: AccountantThemeConfig.bodyLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildTypeRow('فودافون كاش', vodafoneWallets, const Color(0xFFE60012)),
          const SizedBox(height: 8),
          _buildTypeRow('إنستاباي', instapayWallets, const Color(0xFF1E88E5)),
        ],
      ),
    );
  }

  Widget _buildTypeRow(String label, int count, Color color) {
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
  void _selectWallet(ElectronicWalletModel wallet) {
    setState(() {
      _selectedWallet = wallet;
    });
    _loadWalletTransactions(wallet.id);
    _tabController.animateTo(2); // Switch to transactions tab
  }

  Color _getStatusColor(ElectronicWalletStatus status) {
    switch (status) {
      case ElectronicWalletStatus.active:
        return AccountantThemeConfig.primaryGreen;
      case ElectronicWalletStatus.suspended:
        return Colors.orange;
      case ElectronicWalletStatus.inactive:
        return Colors.red;
    }
  }

  String _getStatusText(ElectronicWalletStatus status) {
    switch (status) {
      case ElectronicWalletStatus.active:
        return 'نشطة';
      case ElectronicWalletStatus.suspended:
        return 'معلقة';
      case ElectronicWalletStatus.inactive:
        return 'غير نشطة';
    }
  }

  String _formatDate(DateTime date) {
    // Convert to local time if UTC to ensure proper timezone handling
    final localDate = date.isUtc ? date.toLocal() : date;

    // Use the standard formatter for consistent date/time display across the app
    return Formatters.formatDateTime(localDate);
  }

  void _showWalletDetails(ElectronicWalletModel wallet) {
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

  void _showBalanceUpdateDialog(ElectronicWalletModel wallet) {
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
