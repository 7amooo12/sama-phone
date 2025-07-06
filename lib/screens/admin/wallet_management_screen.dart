import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/supabase_provider.dart';
import '../../models/wallet_model.dart';
import '../../models/wallet_transaction_model.dart';
import '../../utils/wallet_balance_sync.dart';
import '../../utils/accountant_theme_config.dart';
import '../../widgets/common/custom_app_bar.dart';

/// Wallet Management Screen for Admin/Accountant users
class WalletManagementScreen extends StatefulWidget {
  const WalletManagementScreen({super.key});

  @override
  State<WalletManagementScreen> createState() => _WalletManagementScreenState();
}

class _WalletManagementScreenState extends State<WalletManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final String _selectedTransactionType = 'credit';

  // Filter states
  String _selectedFilter = 'all'; // all, credit, debit
  String _searchQuery = '';
  bool _showFilters = false;

  // Statistics expansion state
  bool _isStatisticsExpanded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _loadData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      walletProvider.loadAllWallets();
      walletProvider.loadStatistics();
    });
  }

  /// Refresh all wallet data with enhanced synchronization
  Future<void> _refreshAllData() async {
    try {
      // Use the wallet balance sync utility for comprehensive refresh
      await context.refreshWalletBalances();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث أرصدة المحافظ بنجاح'),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحديث الأرصدة: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: AccountantThemeConfig.mainBackgroundGradient,
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Custom App Bar with AccountantThemeConfig styling
                Container(
                  padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
                  decoration: BoxDecoration(
                    gradient: AccountantThemeConfig.cardGradient,
                    boxShadow: AccountantThemeConfig.cardShadows,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_ios),
                        color: Colors.white,
                      ),
                      Expanded(
                        child: Text(
                          'إدارة المحافظ',
                          style: AccountantThemeConfig.headlineMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: AccountantThemeConfig.greenGradient,
                          borderRadius: BorderRadius.circular(AccountantThemeConfig.smallBorderRadius),
                          boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
                        ),
                        child: IconButton(
                          onPressed: _refreshAllData,
                          icon: const Icon(Icons.refresh),
                          color: Colors.white,
                          tooltip: 'تحديث الأرصدة',
                        ),
                      ),
                    ],
                  ),
                ),
                // Main Content
                Expanded(
                  child: Consumer<WalletProvider>(
                    builder: (context, walletProvider, child) {
                      if (walletProvider.isLoading) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(AccountantThemeConfig.largePadding),
                                decoration: AccountantThemeConfig.primaryCardDecoration,
                                child: CircularProgressIndicator(
                                  color: AccountantThemeConfig.primaryGreen,
                                  strokeWidth: 3,
                                ),
                              ),
                              const SizedBox(height: AccountantThemeConfig.defaultPadding),
                              Text(
                                'جاري تحميل بيانات المحافظ...',
                                style: AccountantThemeConfig.bodyLarge.copyWith(
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      if (walletProvider.error != null) {
                        return Center(
                          child: Container(
                            margin: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
                            padding: const EdgeInsets.all(AccountantThemeConfig.largePadding),
                            decoration: BoxDecoration(
                              gradient: AccountantThemeConfig.cardGradient,
                              borderRadius: BorderRadius.circular(AccountantThemeConfig.largeBorderRadius),
                              border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.dangerRed),
                              boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.dangerRed),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.error_outline_rounded,
                                  size: 64,
                                  color: AccountantThemeConfig.dangerRed,
                                ),
                                const SizedBox(height: AccountantThemeConfig.defaultPadding),
                                Text(
                                  'خطأ في تحميل البيانات',
                                  style: AccountantThemeConfig.headlineSmall.copyWith(
                                    color: AccountantThemeConfig.dangerRed,
                                  ),
                                ),
                                const SizedBox(height: AccountantThemeConfig.smallPadding),
                                Text(
                                  walletProvider.error!,
                                  style: AccountantThemeConfig.bodyMedium.copyWith(
                                    color: Colors.white70,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: AccountantThemeConfig.defaultPadding),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: AccountantThemeConfig.greenGradient,
                                    borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                                  ),
                                  child: ElevatedButton.icon(
                                    onPressed: _loadData,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AccountantThemeConfig.largePadding,
                                        vertical: AccountantThemeConfig.defaultPadding,
                                      ),
                                    ),
                                    icon: const Icon(Icons.refresh, color: Colors.white),
                                    label: Text(
                                      'إعادة المحاولة',
                                      style: AccountantThemeConfig.labelLarge.copyWith(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return Column(
                        children: [
                          // Statistics Cards
                          _buildStatisticsCards(walletProvider),

                          // Tab Bar with AccountantThemeConfig styling
                          Container(
                            margin: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
                            decoration: BoxDecoration(
                              gradient: AccountantThemeConfig.cardGradient,
                              borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                              border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
                              boxShadow: AccountantThemeConfig.cardShadows,
                            ),
                            child: TabBar(
                              controller: _tabController,
                              tabs: const [
                                Tab(
                                  icon: Icon(Icons.people_rounded),
                                  text: 'العملاء',
                                ),
                                Tab(
                                  icon: Icon(Icons.engineering_rounded),
                                  text: 'العمال',
                                ),
                                Tab(
                                  icon: Icon(Icons.receipt_long_rounded),
                                  text: 'المعاملات',
                                ),
                              ],
                              indicatorColor: AccountantThemeConfig.primaryGreen,
                              indicatorWeight: 3,
                              indicatorSize: TabBarIndicatorSize.tab,
                              indicator: BoxDecoration(
                                gradient: AccountantThemeConfig.greenGradient,
                                borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                              ),
                              labelColor: Colors.white,
                              unselectedLabelColor: Colors.white54,
                              labelStyle: AccountantThemeConfig.labelMedium.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              unselectedLabelStyle: AccountantThemeConfig.labelMedium,
                            ),
                          ),

                          // Tab Content
                          Expanded(
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                _buildWalletList(walletProvider.clientWallets, 'client'),
                                _buildWalletList(walletProvider.workerWallets, 'worker'),
                                _buildTransactionsList(walletProvider),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsCards(WalletProvider walletProvider) {
    // Use real-time calculated totals instead of cached statistics
    final realTimeClientTotal = walletProvider.totalClientBalance;
    final realTimeWorkerTotal = walletProvider.totalWorkerBalance;
    final totalBalance = realTimeClientTotal + realTimeWorkerTotal;

    return Container(
      padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
      child: Column(
        children: [
          // Clickable Total Balance Card
          GestureDetector(
            onTap: () {
              setState(() {
                _isStatisticsExpanded = !_isStatisticsExpanded;
              });
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AccountantThemeConfig.largePadding),
              margin: const EdgeInsets.only(bottom: AccountantThemeConfig.defaultPadding),
              decoration: BoxDecoration(
                gradient: AccountantThemeConfig.greenGradient,
                borderRadius: BorderRadius.circular(AccountantThemeConfig.largeBorderRadius),
                boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                      const SizedBox(width: AccountantThemeConfig.smallPadding),
                      Text(
                        'إجمالي الأرصدة',
                        style: AccountantThemeConfig.headlineSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: AccountantThemeConfig.smallPadding),
                      AnimatedRotation(
                        turns: _isStatisticsExpanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: Icon(
                          Icons.expand_more_rounded,
                          color: Colors.white.withValues(alpha: 0.8),
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AccountantThemeConfig.smallPadding),
                  Text(
                    AccountantThemeConfig.formatCurrency(totalBalance),
                    style: AccountantThemeConfig.headlineLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 28,
                    ),
                  ),
                  const SizedBox(height: AccountantThemeConfig.smallPadding),
                  Text(
                    'اضغط لعرض التفاصيل',
                    style: AccountantThemeConfig.bodySmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Collapsible Individual Statistics Cards
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _isStatisticsExpanded ? null : 0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: _isStatisticsExpanded ? 1.0 : 0.0,
              child: _isStatisticsExpanded
                  ? Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                title: 'أرصدة العملاء',
                                value: AccountantThemeConfig.formatCurrency(realTimeClientTotal),
                                icon: Icons.people_rounded,
                                color: AccountantThemeConfig.primaryGreen,
                                count: walletProvider.activeClientCount,
                                countLabel: 'عميل نشط',
                              ),
                            ),
                            const SizedBox(width: AccountantThemeConfig.defaultPadding),
                            Expanded(
                              child: _buildStatCard(
                                title: 'أرصدة العمال',
                                value: AccountantThemeConfig.formatCurrency(realTimeWorkerTotal),
                                icon: Icons.engineering_rounded,
                                color: AccountantThemeConfig.accentBlue,
                                count: walletProvider.activeWorkerCount,
                                countLabel: 'عامل نشط',
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    int? count,
    String? countLabel,
  }) {
    return Container(
      constraints: const BoxConstraints(
        minHeight: 120,
        maxHeight: 160,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
        border: AccountantThemeConfig.glowBorder(color),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AccountantThemeConfig.successGreen.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  Icons.trending_up_rounded,
                  color: AccountantThemeConfig.successGreen,
                  size: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Flexible(
            child: Text(
              title,
              style: AccountantThemeConfig.bodySmall.copyWith(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 11,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 6),
          Flexible(
            child: Text(
              value,
              style: AccountantThemeConfig.headlineSmall.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (count != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$count ${countLabel ?? 'محفظة نشطة'}',
                style: AccountantThemeConfig.bodySmall.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWalletList(List<WalletModel> wallets, String type) {
    if (wallets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type == 'client' ? Icons.people_outline : Icons.engineering_outlined,
              size: 64,
              color: Colors.white24,
            ),
            const SizedBox(height: 16),
            Text(
              type == 'client' ? 'لا توجد محافظ عملاء' : 'لا توجد محافظ عمال',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: wallets.length,
      itemBuilder: (context, index) {
        final wallet = wallets[index];
        return _buildWalletCard(wallet);
      },
    );
  }

  Widget _buildWalletCard(WalletModel wallet) {
    final statusColor = wallet.isActive
        ? AccountantThemeConfig.primaryGreen
        : AccountantThemeConfig.dangerRed;

    return Container(
      margin: const EdgeInsets.only(bottom: AccountantThemeConfig.defaultPadding),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
        border: AccountantThemeConfig.glowBorder(statusColor),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
          onTap: () => _showWalletDetails(wallet),
          child: Padding(
            padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AccountantThemeConfig.smallPadding),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            statusColor.withOpacity(0.2),
                            statusColor.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                        border: Border.all(
                          color: statusColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        wallet.role == 'client' ? Icons.person_rounded : Icons.engineering_rounded,
                        color: statusColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            wallet.userName ?? 'غير محدد',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            wallet.userEmail ?? 'غير محدد',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          wallet.formattedBalanceWithLabel,
                          style: TextStyle(
                            color: wallet.hasDebt
                                ? Colors.red
                                : wallet.balance > 0
                                    ? const Color(0xFF10B981)
                                    : Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: wallet.isActive
                                ? const Color(0xFF10B981).withOpacity(0.2)
                                : Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            wallet.statusDisplayName,
                            style: TextStyle(
                              color: wallet.isActive
                                  ? const Color(0xFF10B981)
                                  : Colors.red,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showTransactionDialog(wallet, 'credit'),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('إيداع'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: wallet.balance > 0
                            ? () => _showTransactionDialog(wallet, 'debit')
                            : null,
                        icon: const Icon(Icons.remove, size: 16),
                        label: const Text('سحب'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _showWalletDetails(wallet),
                      icon: const Icon(Icons.info_outline),
                      color: Colors.white70,
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

  Widget _buildTransactionsList(WalletProvider walletProvider) {
    final allTransactions = walletProvider.transactions;

    // Apply filters
    final filteredTransactions = _filterTransactions(allTransactions);

    return Column(
      children: [
        // Search and Filter Bar
        _buildSearchAndFilterBar(),

        // Transactions List
        Expanded(
          child: _buildFilteredTransactionsList(filteredTransactions),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Container(
      margin: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
      padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Column(
        children: [
          // Search Bar
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'البحث في المعاملات...',
                      hintStyle: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white54),
                      prefixIcon: Icon(Icons.search_rounded, color: AccountantThemeConfig.primaryGreen),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AccountantThemeConfig.defaultPadding,
                        vertical: AccountantThemeConfig.defaultPadding,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(width: AccountantThemeConfig.defaultPadding),
              Container(
                decoration: BoxDecoration(
                  gradient: _showFilters
                      ? AccountantThemeConfig.greenGradient
                      : AccountantThemeConfig.blueGradient,
                  borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                ),
                child: IconButton(
                  onPressed: () {
                    setState(() {
                      _showFilters = !_showFilters;
                    });
                  },
                  icon: Icon(
                    _showFilters ? Icons.filter_list_off_rounded : Icons.filter_list_rounded,
                    color: Colors.white,
                  ),
                  tooltip: _showFilters ? 'إخفاء الفلاتر' : 'إظهار الفلاتر',
                ),
              ),
            ],
          ),

          // Filter Options
          if (_showFilters) ...[
            const SizedBox(height: AccountantThemeConfig.defaultPadding),
            Row(
              children: [
                Text(
                  'فلترة حسب النوع:',
                  style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white70),
                ),
                const SizedBox(width: AccountantThemeConfig.defaultPadding),
                Expanded(
                  child: Row(
                    children: [
                      _buildFilterChip('الكل', 'all'),
                      const SizedBox(width: AccountantThemeConfig.smallPadding),
                      _buildFilterChip('إيداع', 'credit'),
                      const SizedBox(width: AccountantThemeConfig.smallPadding),
                      _buildFilterChip('سحب', 'debit'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AccountantThemeConfig.defaultPadding,
          vertical: AccountantThemeConfig.smallPadding,
        ),
        decoration: BoxDecoration(
          gradient: isSelected
              ? AccountantThemeConfig.greenGradient
              : null,
          color: isSelected
              ? null
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AccountantThemeConfig.smallBorderRadius),
          border: Border.all(
            color: isSelected
                ? AccountantThemeConfig.primaryGreen
                : Colors.white.withOpacity(0.2),
          ),
        ),
        child: Text(
          label,
          style: AccountantThemeConfig.bodySmall.copyWith(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  List<WalletTransactionModel> _filterTransactions(List<WalletTransactionModel> transactions) {
    var filtered = transactions;

    // Apply type filter
    if (_selectedFilter != 'all') {
      filtered = filtered.where((transaction) {
        if (_selectedFilter == 'credit') return transaction.isCredit;
        if (_selectedFilter == 'debit') return !transaction.isCredit;
        return true;
      }).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((transaction) {
        return transaction.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               (transaction.userName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      }).toList();
    }

    return filtered;
  }

  Widget _buildFilteredTransactionsList(List<WalletTransactionModel> transactions) {
    if (transactions.isEmpty) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
          padding: const EdgeInsets.all(AccountantThemeConfig.largePadding),
          decoration: AccountantThemeConfig.transparentCardDecoration,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AccountantThemeConfig.largePadding),
                decoration: BoxDecoration(
                  color: AccountantThemeConfig.neutralColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AccountantThemeConfig.largeBorderRadius),
                ),
                child: Icon(
                  _searchQuery.isNotEmpty || _selectedFilter != 'all'
                      ? Icons.search_off_rounded
                      : Icons.receipt_long_rounded,
                  size: 64,
                  color: AccountantThemeConfig.neutralColor,
                ),
              ),
              const SizedBox(height: AccountantThemeConfig.defaultPadding),
              Text(
                _searchQuery.isNotEmpty || _selectedFilter != 'all'
                    ? 'لا توجد نتائج'
                    : 'لا توجد معاملات',
                style: AccountantThemeConfig.headlineSmall.copyWith(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: AccountantThemeConfig.smallPadding),
              Text(
                _searchQuery.isNotEmpty || _selectedFilter != 'all'
                    ? 'جرب تغيير معايير البحث أو الفلترة'
                    : 'ستظهر جميع المعاملات المالية هنا',
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: Colors.white54,
                ),
                textAlign: TextAlign.center,
              ),
              if (_searchQuery.isNotEmpty || _selectedFilter != 'all') ...[
                const SizedBox(height: AccountantThemeConfig.defaultPadding),
                Container(
                  decoration: BoxDecoration(
                    gradient: AccountantThemeConfig.blueGradient,
                    borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                  ),
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                        _selectedFilter = 'all';
                        _searchController.clear();
                      });
                    },
                    icon: const Icon(Icons.clear_all_rounded, color: Colors.white),
                    label: Text(
                      'مسح الفلاتر',
                      style: AccountantThemeConfig.labelMedium.copyWith(color: Colors.white),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AccountantThemeConfig.defaultPadding,
                        vertical: AccountantThemeConfig.smallPadding,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        final walletProvider = Provider.of<WalletProvider>(context, listen: false);
        await walletProvider.loadAllWallets();
      },
      color: AccountantThemeConfig.primaryGreen,
      backgroundColor: AccountantThemeConfig.cardBackground1,
      child: ListView.builder(
        padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
        itemCount: transactions.length,
        itemBuilder: (context, index) {
          final transaction = transactions[index];
          return AnimatedContainer(
            duration: AccountantThemeConfig.animationDuration,
            curve: Curves.easeInOut,
            child: _buildTransactionCard(transaction, index),
          );
        },
      ),
    );
  }

  Widget _buildTransactionCard(WalletTransactionModel transaction, int index) {
    final transactionColor = transaction.isCredit
        ? AccountantThemeConfig.primaryGreen
        : AccountantThemeConfig.dangerRed;

    final transactionIcon = transaction.isCredit
        ? Icons.add_circle_rounded
        : Icons.remove_circle_rounded;

    // Determine transaction status and color
    final isCompleted = true; // Assuming all transactions are completed for now
    final statusColor = isCompleted
        ? AccountantThemeConfig.completedColor
        : AccountantThemeConfig.pendingColor;

    return Container(
      margin: EdgeInsets.only(
        bottom: AccountantThemeConfig.defaultPadding,
        top: index == 0 ? AccountantThemeConfig.smallPadding : 0,
      ),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
        border: AccountantThemeConfig.glowBorder(transactionColor),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
          onTap: () => _showTransactionDetails(transaction),
          child: Padding(
            padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
            child: Row(
              children: [
                // Transaction Icon with enhanced styling
                Container(
                  padding: const EdgeInsets.all(AccountantThemeConfig.smallPadding),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        transactionColor.withOpacity(0.2),
                        transactionColor.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                    border: Border.all(
                      color: transactionColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    transactionIcon,
                    color: transactionColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AccountantThemeConfig.defaultPadding),

                // Transaction Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Transaction Description
                      Text(
                        transaction.description,
                        style: AccountantThemeConfig.bodyLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AccountantThemeConfig.smallPadding),

                      // Enhanced transaction info with client name
                      Text(
                        _buildTransactionSubtitle(transaction),
                        style: AccountantThemeConfig.bodySmall.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: AccountantThemeConfig.smallPadding),

                      // Transaction Tags Row
                      Row(
                        children: [
                          // Transaction Status
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AccountantThemeConfig.smallPadding,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(AccountantThemeConfig.smallBorderRadius),
                              border: Border.all(
                                color: statusColor.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              isCompleted ? 'مكتملة' : 'معلقة',
                              style: AccountantThemeConfig.bodySmall.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),

                          // Electronic Payment Tag
                          if (transaction.referenceType?.toString().contains('electronic_payment') == true) ...[
                            const SizedBox(width: AccountantThemeConfig.smallPadding),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AccountantThemeConfig.smallPadding,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AccountantThemeConfig.accentBlue.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(AccountantThemeConfig.smallBorderRadius),
                                border: Border.all(
                                  color: AccountantThemeConfig.accentBlue.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                'دفعة إلكترونية',
                                style: AccountantThemeConfig.bodySmall.copyWith(
                                  color: AccountantThemeConfig.accentBlue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Transaction Amount and Arrow
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      transaction.formattedAmount,
                      style: AccountantThemeConfig.headlineSmall.copyWith(
                        color: transactionColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AccountantThemeConfig.smallPadding),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white54,
                      size: 16,
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

  void _showCreateTransactionDialog() {
    // Implementation for creating new transactions
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'إنشاء معاملة جديدة',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'سيتم إضافة هذه الميزة قريباً',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  void _showTransactionDialog(WalletModel wallet, String type) {
    final TextEditingController amountController = TextEditingController();
    final TextEditingController noteController = TextEditingController();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    bool isLoading = false; // Move outside the builder to persist state

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing during loading
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: Colors.grey[900],
            title: Row(
              children: [
                Icon(
                  type == 'credit' ? Icons.add_circle : Icons.remove_circle,
                  color: type == 'credit' ? const Color(0xFF10B981) : Colors.red,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  type == 'credit' ? 'إيداع في المحفظة' : 'سحب من المحفظة',
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
              ],
            ),
            content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Wallet info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: const Color(0xFF10B981).withOpacity(0.2),
                        child: Icon(
                          wallet.role == 'client' ? Icons.person : Icons.engineering,
                          color: const Color(0xFF10B981),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              wallet.userName ?? 'غير محدد',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'الرصيد الحالي: ${wallet.formattedBalance}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Amount input
                TextFormField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'المبلغ',
                    labelStyle: const TextStyle(color: Colors.white70),
                    prefixIcon: Icon(
                      Icons.attach_money,
                      color: type == 'credit' ? const Color(0xFF10B981) : Colors.red,
                    ),
                    suffixText: 'جنيه',
                    suffixStyle: const TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.white30),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.white30),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: type == 'credit' ? const Color(0xFF10B981) : Colors.red,
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
                    if (type == 'debit' && amount > wallet.balance) {
                      return 'المبلغ أكبر من الرصيد المتاح';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Note input
                TextFormField(
                  controller: noteController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'ملاحظة',
                    labelStyle: const TextStyle(color: Colors.white70),
                    prefixIcon: const Icon(
                      Icons.note_alt,
                      color: Colors.white70,
                    ),
                    hintText: 'أدخل ملاحظة حول هذه المعاملة...',
                    hintStyle: const TextStyle(color: Colors.white54),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.white30),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.white30),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.white70),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'يرجى إدخال ملاحظة';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text(
                'إلغاء',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            ElevatedButton(
              onPressed: isLoading ? null : () => _processTransaction(
                context,
                wallet,
                type,
                amountController,
                noteController,
                formKey,
                () => setState(() => isLoading = !isLoading), // Pass loading state toggle
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: type == 'credit' ? const Color(0xFF10B981) : Colors.red,
                foregroundColor: Colors.white,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(type == 'credit' ? 'إيداع' : 'سحب'),
            ),
          ],
          );
        },
      ),
    );
  }

  Future<void> _processTransaction(
    BuildContext context,
    WalletModel wallet,
    String type,
    TextEditingController amountController,
    TextEditingController noteController,
    GlobalKey<FormState> formKey,
    VoidCallback toggleLoading,
  ) async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    // Set loading state
    toggleLoading();

    try {
      final amount = double.parse(amountController.text);
      final note = noteController.text.trim();

      // Get current user ID for createdBy with error handling
      String? currentUserId;
      try {
        currentUserId = context.read<SupabaseProvider>().user?.id;
      } catch (e) {
        throw Exception('خطأ في الوصول لبيانات المستخدم: $e');
      }

      if (currentUserId == null || currentUserId.isEmpty) {
        throw Exception('لم يتم العثور على المستخدم الحالي - يرجى تسجيل الدخول مرة أخرى');
      }

      // Determine transaction type
      final transactionType = type == 'credit'
          ? TransactionType.credit
          : TransactionType.debit;

      // Create transaction using WalletProvider with error handling
      WalletProvider? walletProvider;
      try {
        walletProvider = context.read<WalletProvider>();
      } catch (e) {
        throw Exception('خطأ في الوصول لخدمة المحافظ: $e');
      }

      if (walletProvider == null) {
        throw Exception('خدمة المحافظ غير متاحة');
      }

      // Add timeout to prevent indefinite hanging
      final success = await walletProvider.createTransaction(
        walletId: wallet.id,
        userId: wallet.userId,
        transactionType: transactionType,
        amount: amount,
        description: note,
        createdBy: currentUserId,
        referenceType: ReferenceType.adminAdjustment,
        metadata: {
          'admin_action': type,
          'admin_id': currentUserId,
          'wallet_owner': wallet.userName,
          'timestamp': DateTime.now().toIso8601String(),
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('انتهت مهلة العملية - يرجى المحاولة مرة أخرى');
        },
      );

      if (success) {
        // Close dialog first - check if context is still valid
        if (context.mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }

        // Refresh wallet data and statistics in background
        // Don't await this to prevent UI blocking
        walletProvider.refreshAll().then((_) {
          // Force immediate UI update to show new totals
          walletProvider?.forceUpdate();
        }).catchError((error) {
          // Log error but don't crash the app
          print('Error refreshing wallet data: $error');
        });

        // Show success message - check if context is still valid
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Color(0xFF10B981),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      type == 'credit'
                          ? 'تم إيداع ${amount.toStringAsFixed(2)} جنيه بنجاح'
                          : 'تم سحب ${amount.toStringAsFixed(2)} جنيه بنجاح',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF10B981),
              duration: const Duration(seconds: 3),
            ),
          );
        }

      } else {
        throw Exception(walletProvider.error ?? 'فشل في إنشاء المعاملة');
      }

    } catch (e) {
      // Reset loading state
      if (context.mounted) {
        toggleLoading();
      }

      // Show error message - check if context is still valid
      if (context.mounted) {
        // Provide user-friendly error messages
        String errorMessage = e.toString();
        if (errorMessage.contains('timeout') || errorMessage.contains('انتهت مهلة')) {
          errorMessage = 'انتهت مهلة العملية - يرجى التحقق من الاتصال والمحاولة مرة أخرى';
        } else if (errorMessage.contains('network') || errorMessage.contains('connection')) {
          errorMessage = 'خطأ في الاتصال - يرجى التحقق من الإنترنت';
        } else if (errorMessage.contains('المستخدم الحالي')) {
          errorMessage = 'خطأ في المصادقة - يرجى تسجيل الدخول مرة أخرى';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.error,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    errorMessage,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'إغلاق',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
    }
  }

  void _showWalletDetails(WalletModel wallet) {
    // Implementation for showing wallet details
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'تفاصيل المحفظة',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'المالك: ${wallet.userName}',
              style: const TextStyle(color: Colors.white),
            ),
            Text(
              'الرصيد: ${wallet.formattedBalance}',
              style: const TextStyle(color: Colors.white),
            ),
            Text(
              'الحالة: ${wallet.statusDisplayName}',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  /// Build enhanced transaction subtitle with client information
  String _buildTransactionSubtitle(WalletTransactionModel transaction) {
    final parts = <String>[];

    // Add transaction type
    parts.add(transaction.typeDisplayName);

    // Add client name if available
    if (transaction.userName != null && transaction.userName!.isNotEmpty) {
      if (transaction.transactionType.toString().contains('credit')) {
        parts.add('من: ${transaction.userName}');
      } else {
        parts.add('إلى: ${transaction.userName}');
      }
    }

    // Add date
    parts.add(transaction.formattedDate);

    return parts.join(' • ');
  }

  /// Show transaction details dialog
  void _showTransactionDetails(WalletTransactionModel transaction) {
    final transactionColor = transaction.isCredit
        ? AccountantThemeConfig.primaryGreen
        : AccountantThemeConfig.dangerRed;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          decoration: BoxDecoration(
            gradient: AccountantThemeConfig.cardGradient,
            borderRadius: BorderRadius.circular(AccountantThemeConfig.largeBorderRadius),
            border: AccountantThemeConfig.glowBorder(transactionColor),
            boxShadow: AccountantThemeConfig.glowShadows(transactionColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [transactionColor.withOpacity(0.2), transactionColor.withOpacity(0.1)],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AccountantThemeConfig.largeBorderRadius),
                    topRight: Radius.circular(AccountantThemeConfig.largeBorderRadius),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      transaction.isCredit ? Icons.add_circle_rounded : Icons.remove_circle_rounded,
                      color: transactionColor,
                      size: 32,
                    ),
                    const SizedBox(width: AccountantThemeConfig.defaultPadding),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تفاصيل المعاملة',
                            style: AccountantThemeConfig.headlineSmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            transaction.isCredit ? 'إيداع' : 'سحب',
                            style: AccountantThemeConfig.bodyMedium.copyWith(
                              color: transactionColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    ),
                  ],
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('المبلغ', transaction.formattedAmount, transactionColor),
                    _buildDetailRow('الوصف', transaction.description, Colors.white),
                    _buildDetailRow('التاريخ', transaction.formattedDate, Colors.white70),
                    if (transaction.userName != null)
                      _buildDetailRow('المستخدم', transaction.userName!, Colors.white70),
                    _buildDetailRow('النوع', transaction.typeDisplayName, Colors.white70),
                    if (transaction.referenceType != null)
                      _buildDetailRow('المرجع', transaction.referenceType.toString(), Colors.white70),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AccountantThemeConfig.smallPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: valueColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
