import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/electronic_wallet_provider.dart';
import '../../services/electronic_wallet_service.dart';
import '../../models/electronic_wallet_model.dart';
import '../../models/electronic_wallet_transaction_model.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../utils/app_logger.dart';
import '../../utils/accountant_theme_config.dart';
import 'package:intl/intl.dart';

/// Screen for displaying wallet transactions (approved electronic payments)
class WalletTransactionsScreen extends StatefulWidget {
  const WalletTransactionsScreen({super.key});

  @override
  State<WalletTransactionsScreen> createState() => _WalletTransactionsScreenState();
}

class _WalletTransactionsScreenState extends State<WalletTransactionsScreen> {
  ElectronicWalletModel? _wallet;
  List<ElectronicWalletTransactionModel> _transactions = [];
  bool _isLoading = true;
  String? _error;
  late final ElectronicWalletService _walletService;

  @override
  void initState() {
    super.initState();
    _walletService = ElectronicWalletService();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadArguments();
    });
  }

  void _loadArguments() {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && args['wallet'] != null) {
      _wallet = args['wallet'] as ElectronicWalletModel;
      _loadTransactions();
    } else {
      setState(() {
        _error = 'لم يتم تمرير بيانات المحفظة';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadTransactions() async {
    if (_wallet == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      AppLogger.info('🔄 Loading transactions for wallet: ${_wallet!.id}');
      final transactions = await _walletService.getWalletTransactions(_wallet!.id);

      setState(() {
        _transactions = transactions;
        _isLoading = false;
      });

      AppLogger.info('✅ Loaded ${transactions.length} transactions for wallet');
    } catch (e) {
      AppLogger.error('❌ Error loading wallet transactions: $e');
      setState(() {
        _error = 'فشل في تحميل المعاملات: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AccountantThemeConfig.backgroundColor,
        appBar: CustomAppBar(
          title: _wallet != null ? 'معاملات ${_wallet!.walletName}' : 'معاملات المحفظة',
          backgroundColor: AccountantThemeConfig.backgroundColor,
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: AccountantThemeConfig.primaryGreen,
        ),
      );
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_transactions.isEmpty) {
      return _buildEmptyState();
    }

    return _buildTransactionsList();
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: AccountantThemeConfig.errorRed,
            ),
            const SizedBox(height: 16),
            Text(
              'خطأ في تحميل المعاملات',
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
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadTransactions,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AccountantThemeConfig.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: AccountantThemeConfig.white30,
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
              'لم يتم العثور على معاملات لهذه المحفظة الإلكترونية',
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
    return RefreshIndicator(
      onRefresh: _loadTransactions,
      color: AccountantThemeConfig.primaryGreen,
      backgroundColor: AccountantThemeConfig.cardColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _transactions.length,
        itemBuilder: (context, index) {
          final transaction = _transactions[index];
          return _buildTransactionCard(transaction);
        },
      ),
    );
  }

  Widget _buildTransactionCard(ElectronicWalletTransactionModel transaction) {
    // Determine transaction type and styling
    final isCredit = transaction.transactionType == ElectronicWalletTransactionType.deposit ||
                     transaction.transactionType == ElectronicWalletTransactionType.refund;
    final isDebit = transaction.transactionType == ElectronicWalletTransactionType.withdrawal ||
                    transaction.transactionType == ElectronicWalletTransactionType.payment;

    final transactionColor = isCredit
        ? AccountantThemeConfig.primaryGreen
        : isDebit
            ? AccountantThemeConfig.errorRed
            : AccountantThemeConfig.accentBlue;

    final transactionIcon = isCredit
        ? Icons.add_circle_outline
        : isDebit
            ? Icons.remove_circle_outline
            : Icons.sync_alt;

    final transactionTypeText = _getTransactionTypeText(transaction.transactionType);
    final statusText = _getStatusText(transaction.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AccountantThemeConfig.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AccountantThemeConfig.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with transaction type and amount
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: transactionColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    transactionIcon,
                    color: transactionColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transactionTypeText,
                        style: AccountantThemeConfig.bodyLarge.copyWith(
                          color: transactionColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        statusText,
                        style: AccountantThemeConfig.bodySmall.copyWith(
                          color: _getStatusColor(transaction.status),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isCredit ? '+' : isDebit ? '-' : ''}${transaction.amount.toStringAsFixed(2)} ج.م',
                      style: AccountantThemeConfig.headlineSmall.copyWith(
                        color: transactionColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'الرصيد: ${transaction.balanceAfter.toStringAsFixed(2)} ج.م',
                      style: AccountantThemeConfig.bodySmall.copyWith(
                        color: AccountantThemeConfig.white70,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Transaction details
            if (transaction.description != null && transaction.description!.isNotEmpty) ...[
              _buildInfoRow('الوصف', transaction.description!),
              const SizedBox(height: 8),
            ],

            if (transaction.referenceId != null) ...[
              _buildInfoRow('رقم المرجع', transaction.referenceId!),
              const SizedBox(height: 8),
            ],

            // Wallet information
            if (transaction.walletName != null) ...[
              _buildInfoRow('المحفظة', transaction.walletName!),
              const SizedBox(height: 8),
            ],

            if (transaction.walletPhoneNumber != null) ...[
              _buildInfoRow('رقم المحفظة', transaction.walletPhoneNumber!),
              const SizedBox(height: 8),
            ],

            // Date information
            _buildInfoRow('تاريخ المعاملة', _formatDateTime(transaction.createdAt)),

            // Balance information
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AccountantThemeConfig.backgroundColor.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AccountantThemeConfig.borderColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildBalanceInfo('الرصيد السابق', transaction.balanceBefore),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.arrow_forward,
                    color: AccountantThemeConfig.white60,
                    size: 16,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildBalanceInfo('الرصيد الحالي', transaction.balanceAfter),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: AccountantThemeConfig.white70,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceInfo(String label, double amount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: AccountantThemeConfig.bodySmall.copyWith(
            color: AccountantThemeConfig.white70,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${amount.toStringAsFixed(2)} ج.م',
          style: AccountantThemeConfig.bodyMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _getTransactionTypeText(ElectronicWalletTransactionType type) {
    switch (type) {
      case ElectronicWalletTransactionType.deposit:
        return 'إيداع';
      case ElectronicWalletTransactionType.withdrawal:
        return 'سحب';
      case ElectronicWalletTransactionType.payment:
        return 'دفع';
      case ElectronicWalletTransactionType.refund:
        return 'استرداد';
      case ElectronicWalletTransactionType.transfer:
        return 'تحويل';
    }
  }

  String _getStatusText(ElectronicWalletTransactionStatus status) {
    switch (status) {
      case ElectronicWalletTransactionStatus.pending:
        return 'قيد الانتظار';
      case ElectronicWalletTransactionStatus.completed:
        return 'مكتملة';
      case ElectronicWalletTransactionStatus.failed:
        return 'فاشلة';
      case ElectronicWalletTransactionStatus.cancelled:
        return 'ملغية';
    }
  }

  Color _getStatusColor(ElectronicWalletTransactionStatus status) {
    switch (status) {
      case ElectronicWalletTransactionStatus.pending:
        return AccountantThemeConfig.warningYellow;
      case ElectronicWalletTransactionStatus.completed:
        return AccountantThemeConfig.primaryGreen;
      case ElectronicWalletTransactionStatus.failed:
        return AccountantThemeConfig.errorRed;
      case ElectronicWalletTransactionStatus.cancelled:
        return AccountantThemeConfig.white60;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    // Convert to local time if UTC to ensure proper timezone handling
    final localDateTime = dateTime.isUtc ? dateTime.toLocal() : dateTime;

    // Use Arabic locale for proper date/time formatting
    return DateFormat('dd/MM/yyyy - hh:mm a', 'ar').format(localDateTime);
  }
}
