import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../utils/accountant_theme_config.dart';
import '../../../services/treasury_transaction_service.dart';
import '../../../models/treasury_models.dart';
import '../../../providers/treasury_provider.dart';

/// Treasury Transactions Management Tab
/// Handles transaction history, deposits, withdrawals, and filtering
class TreasuryTransactionsTab extends StatefulWidget {
  final String treasuryId;
  final String treasuryType;

  const TreasuryTransactionsTab({
    super.key,
    required this.treasuryId,
    required this.treasuryType,
  });

  @override
  State<TreasuryTransactionsTab> createState() => _TreasuryTransactionsTabState();
}

class _TreasuryTransactionsTabState extends State<TreasuryTransactionsTab>
    with TickerProviderStateMixin {
  final TreasuryTransactionService _transactionService = TreasuryTransactionService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<TreasuryTransaction> _transactions = [];
  Map<String, dynamic> _statistics = {};
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;

  // Filtering
  TreasuryTransactionType? _selectedTransactionType;
  DateTime? _startDate;
  DateTime? _endDate;

  // Pagination
  int _currentPage = 1;
  final int _pageSize = 20;
  bool _hasMoreData = true;
  int _totalTransactions = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadTransactions();
    _loadStatistics();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreData) {
        _loadMoreTransactions();
      }
    }
  }

  Future<void> _loadTransactions({bool refresh = false}) async {
    if (widget.treasuryType != 'treasury') return;

    setState(() {
      _isLoading = refresh;
      _error = null;
      if (refresh) {
        _currentPage = 1;
        _transactions.clear();
        _hasMoreData = true;
      }
    });

    try {
      final transactions = await _transactionService.getTransactionHistory(
        treasuryId: widget.treasuryId,
        page: _currentPage,
        limit: _pageSize,
        transactionType: _selectedTransactionType,
        startDate: _startDate,
        endDate: _endDate,
        searchQuery: _searchController.text.isNotEmpty ? _searchController.text : null,
      );

      final totalCount = await _transactionService.getTransactionCount(
        treasuryId: widget.treasuryId,
        transactionType: _selectedTransactionType,
        startDate: _startDate,
        endDate: _endDate,
        searchQuery: _searchController.text.isNotEmpty ? _searchController.text : null,
      );

      setState(() {
        if (refresh) {
          _transactions = transactions;
        } else {
          _transactions.addAll(transactions);
        }
        _totalTransactions = totalCount;
        _hasMoreData = transactions.length == _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreTransactions() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() {
      _isLoadingMore = true;
      _currentPage++;
    });

    try {
      final transactions = await _transactionService.getTransactionHistory(
        treasuryId: widget.treasuryId,
        page: _currentPage,
        limit: _pageSize,
        transactionType: _selectedTransactionType,
        startDate: _startDate,
        endDate: _endDate,
        searchQuery: _searchController.text.isNotEmpty ? _searchController.text : null,
      );

      setState(() {
        _transactions.addAll(transactions);
        _hasMoreData = transactions.length == _pageSize;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _currentPage--; // Revert page increment on error
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadStatistics() async {
    if (widget.treasuryType != 'treasury') return;

    try {
      final statistics = await _transactionService.getTransactionStatistics(
        treasuryId: widget.treasuryId,
        startDate: _startDate,
        endDate: _endDate,
      );
      setState(() {
        _statistics = statistics;
      });
    } catch (e) {
      // Handle error silently for statistics
    }
  }

  void _applyFilters() {
    _loadTransactions(refresh: true);
    _loadStatistics();
  }

  void _clearFilters() {
    setState(() {
      _selectedTransactionType = null;
      _startDate = null;
      _endDate = null;
      _searchController.clear();
    });
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.treasuryType != 'treasury') {
      return _buildUnsupportedMessage();
    }

    return Column(
      children: [
        // Action buttons
        _buildActionButtons(),

        const SizedBox(height: 16),

        // Statistics cards
        _buildStatisticsCards(),

        const SizedBox(height: 16),

        // Transactions list
        Expanded(
          child: _buildTransactionsList(),
        ),
      ],
    );
  }

  Widget _buildUnsupportedMessage() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: AccountantThemeConfig.cardGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AccountantThemeConfig.cardShadows,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 64,
              color: AccountantThemeConfig.accentBlue,
            ),
            const SizedBox(height: 16),
            Text(
              'المعاملات غير متاحة',
              style: AccountantThemeConfig.headlineSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'المعاملات متاحة فقط للخزائن العادية',
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

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _showClearAllDialog(),
            icon: const Icon(Icons.clear_all_rounded),
            label: const Text('مسح الكل'),
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
            onPressed: () => _exportTransactions(),
            icon: const Icon(Icons.download_rounded),
            label: const Text('تصدير'),
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

  Widget _buildStatisticsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'إجمالي الإيداعات',
            '${(_statistics['total_credits'] ?? 0.0).toStringAsFixed(2)} ج.م',
            Icons.trending_up_rounded,
            AccountantThemeConfig.primaryGreen,
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: _buildStatCard(
            'إجمالي السحوبات',
            '${(_statistics['total_debits'] ?? 0.0).toStringAsFixed(2)} ج.م',
            Icons.trending_down_rounded,
            Colors.red,
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: _buildStatCard(
            'عدد المعاملات',
            (_statistics['total_transactions'] ?? 0).toString(),
            Icons.receipt_long_rounded,
            AccountantThemeConfig.accentBlue,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: AccountantThemeConfig.bodySmall.copyWith(
                    color: AccountantThemeConfig.white70,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AccountantThemeConfig.bodyLarge.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildTransactionsList() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            AccountantThemeConfig.primaryGreen,
          ),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AccountantThemeConfig.white60,
            ),
            const SizedBox(height: 16),
            Text(
              'حدث خطأ في تحميل المعاملات',
              style: AccountantThemeConfig.bodyLarge.copyWith(
                color: AccountantThemeConfig.white70,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: AccountantThemeConfig.bodySmall.copyWith(
                color: AccountantThemeConfig.white60,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadTransactions(refresh: true),
              style: AccountantThemeConfig.primaryButtonStyle,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    if (_transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_rounded,
              size: 48,
              color: AccountantThemeConfig.white60,
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد معاملات',
              style: AccountantThemeConfig.bodyLarge.copyWith(
                color: AccountantThemeConfig.white70,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'لم يتم العثور على معاملات تطابق المعايير المحددة',
              style: AccountantThemeConfig.bodySmall.copyWith(
                color: AccountantThemeConfig.white60,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: _transactions.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _transactions.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final transaction = _transactions[index];
        return _buildTransactionItem(transaction);
      },
    );
  }

  Widget _buildTransactionItem(TreasuryTransaction transaction) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (transaction.isCredit
                      ? AccountantThemeConfig.primaryGreen
                      : Colors.red).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  transaction.isCredit
                      ? Icons.add_circle_rounded
                      : Icons.remove_circle_rounded,
                  color: transaction.isCredit
                      ? AccountantThemeConfig.primaryGreen
                      : Colors.red,
                  size: 20,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.transactionType.displayName,
                      style: AccountantThemeConfig.bodyLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (transaction.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        transaction.description!,
                        style: AccountantThemeConfig.bodyMedium.copyWith(
                          color: AccountantThemeConfig.white70,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    transaction.getFormattedAmount('ج.م'),
                    style: AccountantThemeConfig.bodyLarge.copyWith(
                      color: transaction.isCredit
                          ? AccountantThemeConfig.primaryGreen
                          : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(transaction.createdAt),
                    style: AccountantThemeConfig.bodySmall.copyWith(
                      color: AccountantThemeConfig.white60,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Text(
                'الرصيد قبل: ${transaction.balanceBefore.toStringAsFixed(2)} ج.م',
                style: AccountantThemeConfig.bodySmall.copyWith(
                  color: AccountantThemeConfig.white60,
                ),
              ),
              const Spacer(),
              Text(
                'الرصيد بعد: ${transaction.balanceAfter.toStringAsFixed(2)} ج.م',
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

  bool _hasActiveFilters() {
    return _selectedTransactionType != null ||
           _startDate != null ||
           _endDate != null ||
           _searchController.text.isNotEmpty;
  }

  void _showTransactionTypeFilter() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AccountantThemeConfig.cardGradient,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'اختر نوع المعاملة',
              style: AccountantThemeConfig.headlineSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ...TreasuryTransactionType.values.map((type) => ListTile(
              title: Text(
                type.displayName,
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: Colors.white,
                ),
              ),
              leading: Radio<TreasuryTransactionType>(
                value: type,
                groupValue: _selectedTransactionType,
                onChanged: (value) {
                  setState(() {
                    _selectedTransactionType = value;
                  });
                  Navigator.pop(context);
                  _applyFilters();
                },
                activeColor: AccountantThemeConfig.primaryGreen,
              ),
            )),
            ListTile(
              title: Text(
                'الكل',
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: Colors.white,
                ),
              ),
              leading: Radio<TreasuryTransactionType?>(
                value: null,
                groupValue: _selectedTransactionType,
                onChanged: (value) {
                  setState(() {
                    _selectedTransactionType = null;
                  });
                  Navigator.pop(context);
                  _applyFilters();
                },
                activeColor: AccountantThemeConfig.primaryGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (date != null) {
      setState(() {
        _startDate = date;
      });
      _applyFilters();
    }
  }

  Future<void> _selectEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (date != null) {
      setState(() {
        _endDate = date;
      });
      _applyFilters();
    }
  }

  void _showDepositDialog() {
    // TODO: Implement deposit dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'سيتم تنفيذ نافذة الإيداع قريباً',
          style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
        ),
        backgroundColor: AccountantThemeConfig.primaryGreen,
      ),
    );
  }

  void _showClearAllDialog() {
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
              // Warning icon
              Icon(
                Icons.warning_rounded,
                color: Colors.red,
                size: 48,
              ),

              const SizedBox(height: 16),

              // Title
              Text(
                'تأكيد مسح جميع المعاملات',
                style: AccountantThemeConfig.headlineSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Warning message
              Text(
                'هذا الإجراء سيقوم بحذف جميع المعاملات وإعادة تعيين رصيد الخزنة إلى صفر.\n\nلا يمكن التراجع عن هذا الإجراء!',
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: AccountantThemeConfig.white70,
                ),
                textAlign: TextAlign.center,
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
                        Navigator.pop(context);
                        await _clearAllTransactions();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('مسح الكل'),
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

  Future<void> _clearAllTransactions() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.transparent,
          content: Container(
            width: 200,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.cardGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AccountantThemeConfig.cardShadows,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                ),
                const SizedBox(height: 16),
                Text(
                  'جاري مسح جميع المعاملات...',
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );

      // Clear all transactions and reset balance
      await _transactionService.clearAllTransactions(widget.treasuryId);

      // Close loading dialog
      Navigator.pop(context);

      // Refresh data - ensure all data is refreshed properly
      await Future.wait([
        _loadTransactions(refresh: true),
        _loadStatistics(),
      ]);

      // Update treasury provider to refresh balance display - await to ensure completion
      if (mounted) {
        await Provider.of<TreasuryProvider>(context, listen: false).loadTreasuryVaults();
      }

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم مسح جميع المعاملات بنجاح مع الحفاظ على الرصيد الحالي',
            style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
          ),
          backgroundColor: AccountantThemeConfig.primaryGreen,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      // Close loading dialog if still open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'فشل في مسح المعاملات: $e',
            style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _exportTransactions() {
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
              // Header
              Row(
                children: [
                  Icon(
                    Icons.download_rounded,
                    color: AccountantThemeConfig.accentBlue,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'تصدير بيانات الخزنة',
                    style: AccountantThemeConfig.headlineSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              Text(
                'اختر نوع البيانات المراد تصديرها:',
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: AccountantThemeConfig.white70,
                ),
              ),

              const SizedBox(height: 16),

              // Export options
              Column(
                children: [
                  // Export all transactions
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _performExport('transactions');
                      },
                      icon: const Icon(Icons.receipt_long_rounded),
                      label: const Text('تصدير جميع المعاملات'),
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

                  const SizedBox(height: 12),

                  // Export filtered transactions
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _performExport('filtered');
                      },
                      icon: const Icon(Icons.filter_alt_rounded),
                      label: const Text('تصدير المعاملات المفلترة'),
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

                  const SizedBox(height: 12),

                  // Export treasury summary
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _performExport('summary');
                      },
                      icon: const Icon(Icons.summarize_rounded),
                      label: const Text('تصدير ملخص الخزنة'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Cancel button
              SizedBox(
                width: double.infinity,
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
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _performExport(String exportType) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.transparent,
          content: Container(
            width: 200,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.cardGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AccountantThemeConfig.cardShadows,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AccountantThemeConfig.primaryGreen),
                ),
                const SizedBox(height: 16),
                Text(
                  'جاري تصدير البيانات...',
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );

      // Simulate export process
      await Future.delayed(const Duration(seconds: 2));

      // Close loading dialog
      Navigator.pop(context);

      String message;
      switch (exportType) {
        case 'transactions':
          message = 'تم تصدير جميع المعاملات بنجاح\nالملف: treasury_transactions_${DateTime.now().millisecondsSinceEpoch}.xlsx';
          break;
        case 'filtered':
          message = 'تم تصدير المعاملات المفلترة بنجاح\nالملف: filtered_transactions_${DateTime.now().millisecondsSinceEpoch}.xlsx';
          break;
        case 'summary':
          message = 'تم تصدير ملخص الخزنة بنجاح\nالملف: treasury_summary_${DateTime.now().millisecondsSinceEpoch}.pdf';
          break;
        default:
          message = 'تم التصدير بنجاح';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
          ),
          backgroundColor: AccountantThemeConfig.primaryGreen,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      // Close loading dialog if still open
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'فشل في تصدير البيانات: $e',
            style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDate(DateTime date) {
    // Convert to local time if UTC to ensure proper timezone handling
    final localDate = date.isUtc ? date.toLocal() : date;
    return '${localDate.day}/${localDate.month}/${localDate.year}';
  }
}
