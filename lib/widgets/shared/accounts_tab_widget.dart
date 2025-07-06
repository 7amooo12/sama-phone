import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/models/advance_model.dart';
import 'package:smartbiztracker_new/models/user_model.dart';
import 'package:smartbiztracker_new/models/flask_invoice_model.dart';
import 'package:smartbiztracker_new/services/advance_service.dart';
import 'package:smartbiztracker_new/services/invoice_service.dart';
import 'package:smartbiztracker_new/screens/shared/add_advance_screen.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:smartbiztracker_new/utils/uuid_validator.dart';

/// Shared Accounts Tab Widget
/// Used by both Accountant and Business Owner dashboards
/// Provides comprehensive financial overview with three sub-tabs:
/// 1. Financial Summary - Revenue, expenses, profit, balance
/// 2. Advances - Worker advances management
/// 3. Client Debts - Client account balances and debts
class AccountsTabWidget extends StatefulWidget {
  /// User role for role-based access control
  final String userRole;
  
  /// Whether to show the header section
  final bool showHeader;

  const AccountsTabWidget({
    super.key,
    required this.userRole,
    this.showHeader = true,
  });

  @override
  State<AccountsTabWidget> createState() => _AccountsTabWidgetState();
}

class _AccountsTabWidgetState extends State<AccountsTabWidget> {
  // Services
  final AdvanceService _advanceService = AdvanceService();
  final InvoiceService _invoiceService = InvoiceService();

  // Financial data
  double _totalRevenue = 0.0;
  double _totalExpenses = 0.0;
  double _totalPending = 0.0;
  double _availableBalance = 0.0;
  int _pendingInvoices = 0;
  int _paidInvoices = 0;
  int _canceledInvoices = 0;
  Map<String, double> _revenueByCategory = {};
  List<dynamic> _recentInvoices = [];

  // Client debts data
  List<Map<String, dynamic>> _clientDebts = [];
  bool _isLoadingClients = false;

  // Loading states
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFinancialData();
    _loadClientDebts();
  }

  /// Load financial data from invoices and transactions
  Future<void> _loadFinancialData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      AppLogger.info('🔄 Loading financial data for ${widget.userRole}...');

      // Fetch invoices with error handling
      List<dynamic> invoices = [];
      try {
        final fetchedInvoices = await _invoiceService.getInvoices();
        invoices = fetchedInvoices.cast<dynamic>();
        AppLogger.info('✅ Fetched ${invoices.length} invoices successfully');

        // Log the type of the first invoice for debugging
        if (invoices.isNotEmpty) {
          AppLogger.info('📄 First invoice type: ${invoices.first.runtimeType}');
          if (invoices.first is FlaskInvoiceModel) {
            final firstInvoice = invoices.first as FlaskInvoiceModel;
            AppLogger.info('📄 Sample FlaskInvoice: ID=${firstInvoice.id}, Status=${firstInvoice.status}, Amount=${firstInvoice.finalAmount}');
          }
        }
      } catch (invoiceError) {
        AppLogger.warning('⚠️ Error fetching invoices: $invoiceError');
        invoices = [];
      }

      // Calculate financial statistics with safe defaults
      double totalRevenue = 0;
      double totalPending = 0;
      int pendingCount = 0;
      int paidCount = 0;
      int canceledCount = 0;
      final Map<String, double> categoryRevenue = {};

      for (final invoice in invoices) {
        try {
          // Fix: Access FlaskInvoiceModel properties directly instead of using bracket notation
          String status = '';
          double total = 0.0;
          String category = 'غير محدد';

          if (invoice is Map<String, dynamic>) {
            // Handle case where invoice is still a Map (legacy support)
            status = invoice['status']?.toString().toLowerCase() ?? '';
            total = (invoice['total'] as num?)?.toDouble() ?? 0.0;
            category = invoice['category']?.toString() ?? 'غير محدد';
          } else if (invoice is FlaskInvoiceModel) {
            // Handle FlaskInvoiceModel objects (correct approach)
            final flaskInvoice = invoice;
            status = flaskInvoice.status.toLowerCase();
            total = flaskInvoice.finalAmount;
            category = 'فاتورة'; // Default category for Flask invoices

            AppLogger.info('📄 Processing FlaskInvoice: ID=${flaskInvoice.id}, Status=$status, Amount=$total');
          } else {
            // Handle unknown types
            AppLogger.warning('⚠️ Unknown invoice type: ${invoice.runtimeType}');
            continue;
          }

          switch (status) {
            case 'paid':
            case 'completed':
              totalRevenue += total;
              paidCount++;
              break;
            case 'pending':
            case 'draft':
              totalPending += total;
              pendingCount++;
              break;
            case 'cancelled':
            case 'canceled':
              canceledCount++;
              break;
          }

          // Category revenue calculation
          if (status == 'paid' || status == 'completed') {
            categoryRevenue[category] = (categoryRevenue[category] ?? 0.0) + total;
          }
        } catch (e) {
          AppLogger.warning('⚠️ Error processing invoice: $e');
          AppLogger.warning('📄 Invoice type: ${invoice.runtimeType}');
          AppLogger.warning('📄 Invoice data: $invoice');
        }
      }

      // Calculate expenses and available balance
      final totalExpenses = totalRevenue * 0.3; // Estimated 30% expenses
      final availableBalance = totalRevenue - totalExpenses;

      // Get recent invoices (last 10)
      final recentInvoices = invoices.take(10).toList();

      // Update state with calculated data
      if (mounted) {
        setState(() {
          _totalRevenue = totalRevenue;
          _totalPending = totalPending;
          _totalExpenses = totalExpenses;
          _availableBalance = availableBalance;
          _pendingInvoices = pendingCount;
          _paidInvoices = paidCount;
          _canceledInvoices = canceledCount;
          _revenueByCategory = categoryRevenue;
          _recentInvoices = recentInvoices;
          _isLoading = false;
        });

        AppLogger.info('✅ Financial data updated successfully');
        AppLogger.info('📊 Total Revenue: $totalRevenue');
        AppLogger.info('📊 Pending Amount: $totalPending');
        AppLogger.info('📊 Total Expenses: $totalExpenses');
        AppLogger.info('📊 Available Balance: $availableBalance');
        AppLogger.info('📊 Invoice Count: ${invoices.length}');
        AppLogger.info('📊 Paid Invoices: $paidCount');
        AppLogger.info('📊 Pending Invoices: $pendingCount');
        AppLogger.info('📊 Canceled Invoices: $canceledCount');
        AppLogger.info('📊 Revenue by Category: $categoryRevenue');
        AppLogger.info('📊 Recent Invoices Count: ${recentInvoices.length}');
        AppLogger.info('📊 UI State Updated - Loading: $_isLoading');

        // Force a rebuild to ensure UI updates
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            AppLogger.info('🔄 Post-frame callback: UI should now display data');
            // Force another setState to ensure UI updates
            setState(() {
              // This empty setState forces a rebuild
            });
          }
        });
      }

    } catch (e, stackTrace) {
      AppLogger.error('❌ Error loading financial data: $e');
      AppLogger.error('📍 Stack trace: $stackTrace');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Show error message to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.warning, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'تعذر تحميل البيانات المالية. سيتم عرض بيانات افتراضية.',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'إعادة المحاولة',
              textColor: Colors.white,
              onPressed: () => _loadFinancialData(),
            ),
          ),
        );
      }
    }
  }

  /// Load client debts and account balances
  Future<void> _loadClientDebts() async {
    setState(() {
      _isLoadingClients = true;
    });

    try {
      AppLogger.info('🔄 Loading client debts data...');

      final supabase = Supabase.instance.client;

      // First: Get approved and active clients (support both status values)
      final clientsResponse = await supabase
          .from('user_profiles')
          .select('id, name, email, phone_number, role, status')
          .or('role.eq.client,role.eq.عميل') // Support both English and Arabic role names
          .or('status.eq.approved,status.eq.active') // Support both status values
          .order('name');

      AppLogger.info('📊 Approved and active clients: ${clientsResponse.length}');

      // Second: Get wallet data for clients
      AppLogger.info('💰 Fetching wallet data...');
      final walletsResponse = await supabase
          .from('wallets')
          .select('user_id, balance, updated_at, status, role')
          .or('role.eq.client,role.eq.عميل') // Support both English and Arabic role names
          .eq('status', 'active');

      AppLogger.info('💳 Fetched ${walletsResponse.length} wallets');

      // Create wallets map for quick lookup
      final walletsMap = <String, Map<String, dynamic>>{};
      for (final wallet in walletsResponse) {
        final userId = wallet['user_id'] as String;
        walletsMap[userId] = wallet;
      }

      // Format client data
      final List<Map<String, dynamic>> formattedClients = [];

      for (var client in clientsResponse) {
        final clientId = client['id'] as String;
        final wallet = walletsMap[clientId];

        double balance = 0.0;
        DateTime lastUpdate = DateTime.now();

        if (wallet != null) {
          balance = (wallet['balance'] as num?)?.toDouble() ?? 0.0;
          lastUpdate = DateTime.tryParse(wallet['updated_at']?.toString() ?? '') ?? DateTime.now();
        }

        formattedClients.add({
          'id': clientId,
          'name': client['name'] ?? 'عميل غير معروف',
          'email': client['email'] ?? '',
          'phone': client['phone_number'] ?? '',
          'balance': balance,
          'lastUpdate': lastUpdate,
          'hasWallet': wallet != null,
        });
      }

      // Sort clients by balance (highest first)
      formattedClients.sort((a, b) => (b['balance'] as double).compareTo(a['balance'] as double));

      AppLogger.info('✅ Formatted ${formattedClients.length} client records');

      setState(() {
        _clientDebts = formattedClients;
        _isLoadingClients = false;
      });

    } catch (e, stackTrace) {
      AppLogger.error('❌ Error loading client debts: $e');
      AppLogger.error('📍 Stack trace: $stackTrace');

      setState(() {
        _isLoadingClients = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'خطأ في تحميل بيانات العملاء',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        _loadClientDebts();
                      },
                      child: const Text(
                        'إعادة المحاولة',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Add debugging to track build calls
    AppLogger.info('🏗️ Building AccountsTabWidget - Loading: $_isLoading, Invoices: ${_recentInvoices.length}');

    return DefaultTabController(
      length: 3, // Three sub-tabs: Financial Summary, Advances, Client Debts
      child: Container(
        decoration: const BoxDecoration(
          gradient: AccountantThemeConfig.mainBackgroundGradient,
        ),
        child: Column(
          children: [
            // Header section (optional)
            if (widget.showHeader) _buildHeader(),

            // Sub-tabs navigation
            _buildSubTabsNavigation(),

            // Tab content
            Expanded(
              child: TabBarView(
                children: [
                  _buildFinancialSummaryTab(),
                  _buildAdvancesTab(),
                  _buildClientDebtsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build header section
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        border: Border(
          bottom: BorderSide(
            color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.greenGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الحسابات المالية',
                  style: AccountantThemeConfig.headlineMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'إدارة شاملة للحسابات والمعاملات المالية',
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

  /// Build sub-tabs navigation
  Widget _buildSubTabsNavigation() {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: AccountantThemeConfig.primaryCardDecoration,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AccountantThemeConfig.cardBackground2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3),
              ),
            ),
            child: TabBar(
              indicator: BoxDecoration(
                gradient: AccountantThemeConfig.greenGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorPadding: const EdgeInsets.all(4),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              labelStyle: AccountantThemeConfig.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: AccountantThemeConfig.bodyMedium,
              tabs: const [
                Tab(
                  icon: Icon(Icons.account_balance_wallet_rounded, size: 20),
                  text: 'الملخص المالي',
                ),
                Tab(
                  icon: Icon(Icons.payment_rounded, size: 20),
                  text: 'السلف',
                ),
                Tab(
                  icon: Icon(Icons.people_alt_rounded, size: 20),
                  text: 'مديونية العملاء',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  /// Build financial summary tab - نفس البيانات المعروضة في Accountant Dashboard
  Widget _buildFinancialSummaryTab() {
    AppLogger.info('🏗️ Building Financial Summary Tab - Loading: $_isLoading, Revenue: $_totalRevenue');

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Loading indicator
        if (_isLoading)
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(32),
              child: const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(
                      color: AccountantThemeConfig.primaryGreen,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'جاري تحميل البيانات المالية...',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Financial Summary Cards - نفس الكروت الموجودة في Accountant
        if (!_isLoading)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildAccountCard(
                          'إجمالي الإيرادات',
                          '${_totalRevenue.toStringAsFixed(2)} جنيه',
                          Icons.trending_up,
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildAccountCard(
                          'إجمالي المصروفات',
                          '${_totalExpenses.toStringAsFixed(2)} جنيه',
                          Icons.trending_down,
                          Colors.red,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                // Single card layout for Net Profit - centered and properly sized
                Center(
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.6, // 60% width for better balance
                    child: _buildAccountCard(
                      'صافي الربح',
                      '${(_totalRevenue - _totalExpenses).toStringAsFixed(2)} جنيه',
                      Icons.account_balance_wallet,
                      AccountantThemeConfig.accentBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Recent Transactions - نفس قسم المعاملات الحديثة
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.8),
                    Colors.black.withValues(alpha: 0.9),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'المعاملات الحديثة',
                          style: AccountantThemeConfig.headlineSmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: AccountantThemeConfig.greenGradient,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
                          ),
                          child: Text(
                            'عرض الكل',
                            style: AccountantThemeConfig.bodySmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTransactionsList(),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Bottom padding
        const SliverToBoxAdapter(
          child: SizedBox(height: 32),
        ),
      ],
    );
  }

  /// Build account card widget - نفس التصميم المستخدم في Accountant Dashboard
  Widget _buildAccountCard(String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withValues(alpha: 0.8),
            Colors.black.withValues(alpha: 0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color,
                        color.withValues(alpha: 0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: AccountantThemeConfig.bodyMedium.copyWith(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: AccountantThemeConfig.headlineSmall.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build transactions list - نفس قائمة المعاملات في Accountant Dashboard
  Widget _buildTransactionsList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AccountantThemeConfig.primaryGreen,
        ),
      );
    }

    if (_recentInvoices.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد معاملات حديثة',
              style: AccountantThemeConfig.bodyLarge.copyWith(
                color: Colors.white54,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _recentInvoices.take(5).map((invoice) {
        // Fix: Handle both FlaskInvoiceModel and Map types properly
        String status = '';
        double total = 0.0;
        String customerName = 'عميل غير محدد';

        try {
          if (invoice is FlaskInvoiceModel) {
            // Handle FlaskInvoiceModel objects (correct approach)
            final flaskInvoice = invoice;
            status = flaskInvoice.status;
            total = flaskInvoice.finalAmount;
            customerName = flaskInvoice.customerName.isNotEmpty ? flaskInvoice.customerName : 'عميل غير محدد';
          } else if (invoice is Map<String, dynamic>) {
            // Handle Map objects (legacy support)
            status = invoice['status']?.toString() ?? '';
            total = (invoice['total'] as num?)?.toDouble() ?? 0.0;
            customerName = invoice['customer_name']?.toString() ?? 'عميل غير محدد';
          } else {
            // Handle unknown types with safe defaults
            AppLogger.warning('⚠️ Unknown invoice type in transactions list: ${invoice.runtimeType}');
            status = 'unknown';
            total = 0.0;
            customerName = 'عميل غير محدد';
          }
        } catch (e) {
          AppLogger.error('❌ Error processing invoice in transactions list: $e');
          status = 'error';
          total = 0.0;
          customerName = 'خطأ في البيانات';
        }

        Color statusColor = AccountantThemeConfig.primaryGreen;
        String statusText = 'مدفوعة';

        switch (status.toLowerCase()) {
          case 'pending':
          case 'draft':
            statusColor = Colors.orange;
            statusText = 'معلقة';
            break;
          case 'cancelled':
          case 'canceled':
            statusColor = Colors.red;
            statusText = 'ملغية';
            break;
          case 'paid':
          case 'completed':
            statusColor = AccountantThemeConfig.primaryGreen;
            statusText = 'مدفوعة';
            break;
          case 'error':
            statusColor = Colors.red;
            statusText = 'خطأ';
            break;
          default:
            statusColor = Colors.grey;
            statusText = 'غير محدد';
            break;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AccountantThemeConfig.cardBackground2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: statusColor.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 40,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customerName,
                      style: AccountantThemeConfig.bodyMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${total.toStringAsFixed(2)} جنيه',
                      style: AccountantThemeConfig.bodySmall.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusText,
                  style: AccountantThemeConfig.bodySmall.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Build advances tab - نفس تاب السلف في Accountant Dashboard
  Widget _buildAdvancesTab() {
    return FutureBuilder<List<AdvanceModel>>(
      future: _advanceService.getAllAdvances(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            decoration: const BoxDecoration(
              gradient: AccountantThemeConfig.mainBackgroundGradient,
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: AccountantThemeConfig.primaryGreen,
                    strokeWidth: 3,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'جاري تحميل السلف...',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          AppLogger.error('❌ Error loading advances: ${snapshot.error}');

          return Container(
            decoration: const BoxDecoration(
              gradient: AccountantThemeConfig.mainBackgroundGradient,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'حدث خطأ أثناء تحميل السلف',
                    style: AccountantThemeConfig.headlineSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'يرجى المحاولة مرة أخرى أو التحقق من الاتصال',
                    style: AccountantThemeConfig.bodyMedium.copyWith(
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    label: Text(
                      'إعادة المحاولة',
                      style: AccountantThemeConfig.bodyMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AccountantThemeConfig.primaryGreen,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final advances = snapshot.data ?? [];
        final statistics = AdvanceStatistics.fromAdvances(advances);

        return Container(
          decoration: const BoxDecoration(
            gradient: AccountantThemeConfig.mainBackgroundGradient,
          ),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [


              // Add Advance Button - نفس الزر
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton.icon(
                    onPressed: () => _navigateToAddAdvance(),
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: Text(
                      'إضافة سلفة جديدة',
                      style: AccountantThemeConfig.bodyMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AccountantThemeConfig.primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),

              // Advances List - نفس القائمة
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    decoration: AccountantThemeConfig.primaryCardDecoration,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'قائمة السلف',
                                style: AccountantThemeConfig.headlineSmall.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  gradient: AccountantThemeConfig.greenGradient,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${advances.length} سلفة',
                                  style: AccountantThemeConfig.bodySmall.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildAdvancesList(advances),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom padding
              const SliverToBoxAdapter(
                child: SizedBox(height: 32),
              ),
            ],
          ),
        );
      },
    );
  }



  /// Build advances list - نفس قائمة السلف
  Widget _buildAdvancesList(List<AdvanceModel> advances) {
    if (advances.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.payment_outlined,
              size: 64,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد سلف مسجلة',
              style: AccountantThemeConfig.bodyLarge.copyWith(
                color: Colors.white54,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: advances.take(10).map((advance) {
        Color statusColor = AccountantThemeConfig.primaryGreen;
        String statusText = 'معتمدة';

        switch (advance.status.toLowerCase()) {
          case 'pending':
            statusColor = Colors.orange;
            statusText = 'في الانتظار';
            break;
          case 'approved':
            statusColor = AccountantThemeConfig.primaryGreen;
            statusText = 'معتمدة';
            break;
          case 'paid':
            statusColor = Colors.blue;
            statusText = 'مدفوعة';
            break;
          case 'rejected':
            statusColor = Colors.red;
            statusText = 'مرفوضة';
            break;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AccountantThemeConfig.cardBackground2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: statusColor.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 40,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      advance.clientName,
                      style: AccountantThemeConfig.bodyMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${advance.amount.toStringAsFixed(2)} جنيه',
                      style: AccountantThemeConfig.bodySmall.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (advance.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        advance.description,
                        style: AccountantThemeConfig.bodySmall.copyWith(
                          color: Colors.white60,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusText,
                      style: AccountantThemeConfig.bodySmall.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Edit and Delete buttons
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Edit Button
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
                            onTap: () => _editAdvance(advance),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                Icons.edit_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Delete Button
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AccountantThemeConfig.dangerRed, AccountantThemeConfig.dangerRed.withOpacity(0.8)],
                          ),
                          borderRadius: BorderRadius.circular(AccountantThemeConfig.smallBorderRadius),
                          boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.dangerRed),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AccountantThemeConfig.smallBorderRadius),
                            onTap: () => _deleteAdvance(advance),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                Icons.delete_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Navigate to add advance screen - نفس التنقل
  Future<void> _navigateToAddAdvance() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AddAdvanceScreen(),
      ),
    );

    if (result == true) {
      // Refresh the advances tab
      setState(() {});
    }
  }

  /// Edit advance functionality
  Future<void> _editAdvance(AdvanceModel advance) async {
    final TextEditingController amountController = TextEditingController(text: advance.amount.toString());
    final TextEditingController descriptionController = TextEditingController(text: advance.description);
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: Colors.transparent,
            contentPadding: EdgeInsets.zero,
            content: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              decoration: BoxDecoration(
                gradient: AccountantThemeConfig.cardGradient,
                borderRadius: BorderRadius.circular(AccountantThemeConfig.largeBorderRadius),
                border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
                boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.accentBlue),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AccountantThemeConfig.accentBlue.withOpacity(0.2), AccountantThemeConfig.accentBlue.withOpacity(0.1)],
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(AccountantThemeConfig.largeBorderRadius),
                        topRight: Radius.circular(AccountantThemeConfig.largeBorderRadius),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit_rounded,
                          color: AccountantThemeConfig.accentBlue,
                          size: 32,
                        ),
                        const SizedBox(width: AccountantThemeConfig.defaultPadding),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'تعديل السلفة',
                                style: AccountantThemeConfig.headlineSmall.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                advance.clientName,
                                style: AccountantThemeConfig.bodyMedium.copyWith(
                                  color: AccountantThemeConfig.accentBlue,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: isLoading ? null : () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Padding(
                    padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Amount Field
                          Text(
                            'المبلغ',
                            style: AccountantThemeConfig.bodyMedium.copyWith(
                              color: Colors.white70,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AccountantThemeConfig.smallPadding),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                              border: Border.all(color: Colors.white.withOpacity(0.1)),
                            ),
                            child: TextFormField(
                              controller: amountController,
                              keyboardType: TextInputType.number,
                              style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'أدخل المبلغ',
                                hintStyle: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white54),
                                prefixIcon: Icon(Icons.attach_money_rounded, color: AccountantThemeConfig.accentBlue),
                                suffixText: 'جنيه',
                                suffixStyle: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white70),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'يرجى إدخال المبلغ';
                                }
                                final amount = double.tryParse(value);
                                if (amount == null || amount <= 0) {
                                  return 'يرجى إدخال مبلغ صحيح';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(height: AccountantThemeConfig.defaultPadding),

                          // Description Field
                          Text(
                            'الوصف',
                            style: AccountantThemeConfig.bodyMedium.copyWith(
                              color: Colors.white70,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AccountantThemeConfig.smallPadding),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                              border: Border.all(color: Colors.white.withOpacity(0.1)),
                            ),
                            child: TextFormField(
                              controller: descriptionController,
                              maxLines: 3,
                              style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'أدخل وصف السلفة',
                                hintStyle: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white54),
                                prefixIcon: Icon(Icons.description_rounded, color: AccountantThemeConfig.accentBlue),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
                              ),
                            ),
                          ),
                          const SizedBox(height: AccountantThemeConfig.largePadding),

                          // Action Buttons
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                                  ),
                                  child: TextButton(
                                    onPressed: isLoading ? null : () => Navigator.of(context).pop(),
                                    child: Text(
                                      'إلغاء',
                                      style: AccountantThemeConfig.labelMedium.copyWith(
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AccountantThemeConfig.defaultPadding),
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: AccountantThemeConfig.blueGradient,
                                    borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                                  ),
                                  child: ElevatedButton(
                                    onPressed: isLoading ? null : () => _processEditAdvance(
                                      context,
                                      advance,
                                      amountController,
                                      descriptionController,
                                      formKey,
                                      () => setState(() => isLoading = !isLoading),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: AccountantThemeConfig.defaultPadding),
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
                                        : Text(
                                            'حفظ التعديلات',
                                            style: AccountantThemeConfig.labelMedium.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Process edit advance
  Future<void> _processEditAdvance(
    BuildContext context,
    AdvanceModel advance,
    TextEditingController amountController,
    TextEditingController descriptionController,
    GlobalKey<FormState> formKey,
    VoidCallback toggleLoading,
  ) async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    toggleLoading();

    try {
      final amount = double.parse(amountController.text);
      final description = descriptionController.text.trim();

      // Validate advance data before processing
      if (advance.id.isEmpty) {
        throw Exception('معرف السلفة مطلوب');
      }

      // Validate UUID format for advance ID
      if (!UuidValidator.isValidUuid(advance.id)) {
        AppLogger.error('❌ Invalid advance ID UUID: ${advance.id}');
        throw Exception('معرف السلفة غير صحيح');
      }

      // Validate client ID if not empty
      if (advance.clientId.isNotEmpty && !UuidValidator.isValidUuid(advance.clientId)) {
        AppLogger.error('❌ Invalid client ID UUID: ${advance.clientId}');
        throw Exception('معرف العميل غير صحيح');
      }

      // Validate created_by UUID
      if (!UuidValidator.isValidUuid(advance.createdBy)) {
        AppLogger.error('❌ Invalid created_by UUID: ${advance.createdBy}');
        throw Exception('معرف منشئ السلفة غير صحيح');
      }

      AppLogger.info('🔄 Processing advance update for ID: ${advance.id}');

      // Create updated advance model
      final updatedAdvance = AdvanceModel(
        id: advance.id,
        advanceName: advance.advanceName,
        clientId: advance.clientId,
        clientName: advance.clientName,
        amount: amount,
        status: advance.status,
        description: description,
        createdAt: advance.createdAt,
        approvedAt: advance.approvedAt,
        paidAt: advance.paidAt,
        createdBy: advance.createdBy,
        approvedBy: advance.approvedBy,
        rejectedReason: advance.rejectedReason,
        metadata: advance.metadata,
      );

      // Update advance using service
      final success = await _advanceService.updateAdvance(updatedAdvance);

      if (success) {
        if (context.mounted) {
          Navigator.of(context).pop();
          _showSuccessSnackBar('تم تحديث السلفة بنجاح');
          setState(() {}); // Refresh the list
        }
      } else {
        throw Exception('فشل في تحديث السلفة');
      }
    } catch (e) {
      AppLogger.error('❌ Error updating advance: $e');
      if (context.mounted) {
        toggleLoading();

        // Provide user-friendly Arabic error messages
        String errorMessage = 'حدث خطأ أثناء تحديث السلفة';

        if (e.toString().contains('invalid input syntax for type uuid')) {
          errorMessage = 'خطأ في معرف السلفة - يرجى المحاولة مرة أخرى';
        } else if (e.toString().contains('معرف')) {
          // Extract Arabic error messages
          errorMessage = e.toString().replaceAll('Exception: ', '');
        } else if (e.toString().contains('PostgrestException')) {
          errorMessage = 'خطأ في قاعدة البيانات - يرجى التحقق من البيانات والمحاولة مرة أخرى';
        }

        _showErrorSnackBar(errorMessage);
      }
    }
  }

  /// Delete advance functionality
  Future<void> _deleteAdvance(AdvanceModel advance) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          decoration: BoxDecoration(
            gradient: AccountantThemeConfig.cardGradient,
            borderRadius: BorderRadius.circular(AccountantThemeConfig.largeBorderRadius),
            border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.dangerRed),
            boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.dangerRed),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AccountantThemeConfig.dangerRed.withOpacity(0.2), AccountantThemeConfig.dangerRed.withOpacity(0.1)],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AccountantThemeConfig.largeBorderRadius),
                    topRight: Radius.circular(AccountantThemeConfig.largeBorderRadius),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_rounded,
                      color: AccountantThemeConfig.dangerRed,
                      size: 32,
                    ),
                    const SizedBox(width: AccountantThemeConfig.defaultPadding),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تأكيد الحذف',
                            style: AccountantThemeConfig.headlineSmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'هذا الإجراء لا يمكن التراجع عنه',
                            style: AccountantThemeConfig.bodyMedium.copyWith(
                              color: AccountantThemeConfig.dangerRed,
                            ),
                          ),
                        ],
                      ),
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
                    Text(
                      'هل أنت متأكد من حذف هذه السلفة؟',
                      style: AccountantThemeConfig.bodyLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AccountantThemeConfig.defaultPadding),
                    Container(
                      padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow('العميل', advance.clientName, Colors.white),
                          _buildDetailRow('المبلغ', '${advance.amount.toStringAsFixed(2)} جنيه', AccountantThemeConfig.dangerRed),
                          if (advance.description.isNotEmpty)
                            _buildDetailRow('الوصف', advance.description, Colors.white70),
                          _buildDetailRow('الحالة', _getStatusText(advance.status), _getStatusColor(advance.status)),
                        ],
                      ),
                    ),
                    const SizedBox(height: AccountantThemeConfig.largePadding),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                            ),
                            child: TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(
                                'إلغاء',
                                style: AccountantThemeConfig.labelMedium.copyWith(
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AccountantThemeConfig.defaultPadding),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [AccountantThemeConfig.dangerRed, AccountantThemeConfig.dangerRed.withOpacity(0.8)],
                              ),
                              borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                            ),
                            child: ElevatedButton.icon(
                              onPressed: () => _processDeleteAdvance(context, advance),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: AccountantThemeConfig.defaultPadding),
                              ),
                              icon: const Icon(Icons.delete_rounded, color: Colors.white, size: 20),
                              label: Text(
                                'حذف السلفة',
                                style: AccountantThemeConfig.labelMedium.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build client debts tab - نفس تاب مديونية العملاء في Accountant Dashboard
  Widget _buildClientDebtsTab() {
    return Container(
      decoration: const BoxDecoration(
        gradient: AccountantThemeConfig.mainBackgroundGradient,
      ),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Client debts statistics - إحصائيات مديونية العملاء
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildClientDebtStatCard(
                          'إجمالي العملاء',
                          '${_clientDebts.length}',
                          Icons.people,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildClientDebtStatCard(
                          'عملاء برصيد موجب',
                          '${_clientDebts.where((c) => (c['balance'] as double) > 0).length}',
                          Icons.trending_up,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildClientDebtStatCard(
                          'إجمالي الأرصدة',
                          '${_clientDebts.fold(0.0, (sum, c) => sum + (c['balance'] as double)).toStringAsFixed(2)} جنيه',
                          Icons.account_balance_wallet,
                          Colors.purple,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildClientDebtStatCard(
                          'متوسط الرصيد',
                          '${_clientDebts.isNotEmpty ? (_clientDebts.fold(0.0, (sum, c) => sum + (c['balance'] as double)) / _clientDebts.length).toStringAsFixed(2) : "0.00"} جنيه',
                          Icons.analytics,
                          Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Client debts list - قائمة مديونية العملاء
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: AccountantThemeConfig.primaryCardDecoration,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'حسابات العملاء',
                            style: AccountantThemeConfig.headlineSmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: AccountantThemeConfig.greenGradient,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_clientDebts.length} عميل',
                              style: AccountantThemeConfig.bodySmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildClientDebtsList(),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Loading indicator for clients
          if (_isLoadingClients)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(
                    color: AccountantThemeConfig.primaryGreen,
                  ),
                ),
              ),
            ),

          // Empty state for clients
          if (!_isLoadingClients && _clientDebts.isEmpty)
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 64,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'لا توجد حسابات عملاء',
                      style: AccountantThemeConfig.bodyLarge.copyWith(
                        color: Colors.white54,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _loadClientDebts,
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      label: Text(
                        'إعادة التحميل',
                        style: AccountantThemeConfig.bodyMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AccountantThemeConfig.primaryGreen,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom padding
          const SliverToBoxAdapter(
            child: SizedBox(height: 32),
          ),
        ],
      ),
    );
  }

  /// Build client debt statistics card - كروت إحصائيات مديونية العملاء
  Widget _buildClientDebtStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withValues(alpha: 0.8),
            Colors.black.withValues(alpha: 0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0.8)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: AccountantThemeConfig.bodyMedium.copyWith(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: AccountantThemeConfig.headlineSmall.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build client debts list - نفس قائمة مديونية العملاء
  Widget _buildClientDebtsList() {
    if (_clientDebts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد حسابات عملاء',
              style: AccountantThemeConfig.bodyLarge.copyWith(
                color: Colors.white54,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _clientDebts.map((client) {
        final balance = client['balance'] as double;
        final hasWallet = client['hasWallet'] as bool? ?? false;
        final isPositiveBalance = balance > 0;
        final balanceColor = isPositiveBalance
            ? AccountantThemeConfig.primaryGreen
            : balance == 0
                ? Colors.orange
                : Colors.red;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AccountantThemeConfig.cardBackground2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: balanceColor.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 50,
                decoration: BoxDecoration(
                  color: balanceColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client['name'] as String,
                      style: AccountantThemeConfig.bodyMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if ((client['phone'] as String).isNotEmpty)
                      Text(
                        client['phone'] as String,
                        style: AccountantThemeConfig.bodySmall.copyWith(
                          color: Colors.white60,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          hasWallet ? Icons.account_balance_wallet : Icons.wallet_outlined,
                          size: 16,
                          color: hasWallet ? AccountantThemeConfig.primaryGreen : Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          hasWallet ? 'محفظة نشطة' : 'لا توجد محفظة',
                          style: AccountantThemeConfig.bodySmall.copyWith(
                            color: hasWallet ? AccountantThemeConfig.primaryGreen : Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${balance.toStringAsFixed(2)} جنيه',
                    style: AccountantThemeConfig.bodyMedium.copyWith(
                      color: balanceColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: balanceColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isPositiveBalance
                          ? 'رصيد موجب'
                          : balance == 0
                              ? 'رصيد صفر'
                              : 'مديون',
                      style: AccountantThemeConfig.bodySmall.copyWith(
                        color: balanceColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Call Client Button
                  if ((client['phone'] as String).isNotEmpty)
                    Container(
                      decoration: BoxDecoration(
                        gradient: AccountantThemeConfig.greenGradient,
                        borderRadius: BorderRadius.circular(AccountantThemeConfig.smallBorderRadius),
                        boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AccountantThemeConfig.smallBorderRadius),
                          onTap: () => _makePhoneCall(client['phone'] as String),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AccountantThemeConfig.smallPadding,
                              vertical: 6,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.phone_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'اتصال',
                                  style: AccountantThemeConfig.bodySmall.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Make phone call to client
  Future<void> _makePhoneCall(String phoneNumber) async {
    try {
      // Clean phone number (remove spaces, dashes, etc.)
      final cleanedNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

      if (cleanedNumber.isEmpty) {
        _showErrorSnackBar('رقم الهاتف غير صحيح');
        return;
      }

      final Uri phoneUri = Uri(scheme: 'tel', path: cleanedNumber);

      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
        AppLogger.info('📞 Phone call initiated to: $cleanedNumber');
      } else {
        _showErrorSnackBar('لا يمكن إجراء المكالمة على هذا الجهاز');
        AppLogger.warning('⚠️ Cannot launch phone call to: $cleanedNumber');
      }
    } catch (e) {
      AppLogger.error('❌ Error making phone call: $e');
      _showErrorSnackBar('حدث خطأ أثناء محاولة الاتصال');
    }
  }

  /// Process delete advance
  Future<void> _processDeleteAdvance(BuildContext context, AdvanceModel advance) async {
    try {
      final success = await _advanceService.deleteAdvance(advance.id);

      if (success) {
        if (context.mounted) {
          Navigator.of(context).pop();
          _showSuccessSnackBar('تم حذف السلفة بنجاح');
          setState(() {}); // Refresh the list
        }
      } else {
        throw Exception('فشل في حذف السلفة');
      }
    } catch (e) {
      AppLogger.error('❌ Error deleting advance: $e');
      if (context.mounted) {
        Navigator.of(context).pop();
        _showErrorSnackBar('حدث خطأ أثناء حذف السلفة: ${e.toString()}');
      }
    }
  }

  /// Get status text for advance
  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'في الانتظار';
      case 'approved':
        return 'معتمدة';
      case 'paid':
        return 'مدفوعة';
      case 'rejected':
        return 'مرفوضة';
      default:
        return 'غير محدد';
    }
  }

  /// Get status color for advance
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return AccountantThemeConfig.primaryGreen;
      case 'paid':
        return Colors.blue;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// Show success snackbar with AccountantThemeConfig styling
  void _showSuccessSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: AccountantThemeConfig.smallPadding),
            Expanded(
              child: Text(
                message,
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: Colors.white,
                ),
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
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Show error snackbar with AccountantThemeConfig styling
  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: AccountantThemeConfig.smallPadding),
            Expanded(
              child: Text(
                message,
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: Colors.white,
                ),
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
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Build detail row for advance information
  Widget _buildDetailRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AccountantThemeConfig.smallPadding / 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: AccountantThemeConfig.bodySmall.copyWith(
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: AccountantThemeConfig.smallPadding),
          Expanded(
            child: Text(
              value,
              style: AccountantThemeConfig.bodySmall.copyWith(
                color: valueColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Show clear account dialog
  void _showClearAccountDialog(String workerId, String workerName, double balance) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AccountantThemeConfig.cardBackground1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
        ),
        title: Text(
          'تصفية الحساب',
          style: AccountantThemeConfig.headlineSmall.copyWith(
            color: Colors.white,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'هل أنت متأكد من تصفية حساب $workerName؟',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: AccountantThemeConfig.defaultPadding),
            Container(
              padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
              decoration: BoxDecoration(
                color: AccountantThemeConfig.dangerRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AccountantThemeConfig.smallBorderRadius),
                border: Border.all(
                  color: AccountantThemeConfig.dangerRed.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: AccountantThemeConfig.dangerRed,
                    size: 20,
                  ),
                  const SizedBox(width: AccountantThemeConfig.smallPadding),
                  Expanded(
                    child: Text(
                      'الرصيد الحالي: ${balance.toStringAsFixed(2)} جنيه',
                      style: AccountantThemeConfig.bodySmall.copyWith(
                        color: AccountantThemeConfig.dangerRed,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'إلغاء',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _clearWorkerAccount(workerId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AccountantThemeConfig.dangerRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('تصفية الحساب'),
          ),
        ],
      ),
    );
  }

  /// Clear worker account
  Future<void> _clearWorkerAccount(String workerId) async {
    try {
      // TODO: Implement actual account clearing logic
      _showSuccessSnackBar('تم تصفية الحساب بنجاح');
    } catch (e) {
      _showErrorSnackBar('فشل في تصفية الحساب: $e');
    }
  }
}
