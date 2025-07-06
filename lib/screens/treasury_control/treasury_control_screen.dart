import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/accountant_theme_config.dart';
import '../../providers/treasury_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/electronic_wallet_provider.dart';
import '../../models/treasury_models.dart';
import 'tabs/treasury_balance_tab.dart';
import 'tabs/treasury_transactions_tab.dart';
import 'tabs/treasury_connections_tab.dart';
import 'tabs/treasury_settings_tab.dart';

/// Treasury Control Screen
/// Comprehensive control interface for managing individual treasuries
class TreasuryControlScreen extends StatefulWidget {
  final String treasuryId;
  final String treasuryType; // 'treasury', 'client_wallets', 'electronic_wallets'

  const TreasuryControlScreen({
    super.key,
    required this.treasuryId,
    required this.treasuryType,
  });

  @override
  State<TreasuryControlScreen> createState() => _TreasuryControlScreenState();
}

class _TreasuryControlScreenState extends State<TreasuryControlScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  String? _error;

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
      switch (widget.treasuryType) {
        case 'treasury':
          await context.read<TreasuryProvider>().loadTreasuryVaults();
          break;
        case 'client_wallets':
          await context.read<WalletProvider>().loadAllWallets();
          break;
        case 'electronic_wallets':
          await context.read<ElectronicWalletProvider>().loadWallets();
          break;
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

  String _getTreasuryName() {
    switch (widget.treasuryType) {
      case 'treasury':
        final treasuryProvider = context.read<TreasuryProvider>();
        final treasury = treasuryProvider.treasuryVaults
            .where((t) => t.id == widget.treasuryId)
            .firstOrNull;
        return treasury?.name ?? 'خزنة غير معروفة';
      case 'client_wallets':
        return 'محافظ العملاء';
      case 'electronic_wallets':
        return 'المحافظ الإلكترونية';
      default:
        return 'غير محدد';
    }
  }

  String _getTreasuryTypeDisplay() {
    switch (widget.treasuryType) {
      case 'treasury':
        final treasuryProvider = context.read<TreasuryProvider>();
        final treasury = treasuryProvider.treasuryVaults
            .where((t) => t.id == widget.treasuryId)
            .firstOrNull;
        return treasury?.treasuryType.nameAr ?? 'خزنة';
      case 'client_wallets':
        return 'ملخص المحافظ';
      case 'electronic_wallets':
        return 'ملخص المحافظ الإلكترونية';
      default:
        return 'غير محدد';
    }
  }

  IconData _getTreasuryIcon() {
    switch (widget.treasuryType) {
      case 'treasury':
        final treasuryProvider = context.read<TreasuryProvider>();
        final treasury = treasuryProvider.treasuryVaults
            .where((t) => t.id == widget.treasuryId)
            .firstOrNull;
        return treasury?.treasuryType == TreasuryType.bank
            ? Icons.account_balance_rounded
            : Icons.account_balance_wallet_rounded;
      case 'client_wallets':
        return Icons.people_rounded;
      case 'electronic_wallets':
        return Icons.phone_android_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: AccountantThemeConfig.mainBackgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom AppBar
              _buildCustomAppBar(),
              
              // Tab Bar
              _buildTabBar(),
              
              // Tab Content
              Expanded(
                child: _isLoading
                    ? _buildLoadingWidget()
                    : _error != null
                        ? _buildErrorWidget()
                        : _buildTabContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomAppBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Back button
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.arrow_back_ios_rounded,
              color: Colors.white,
            ),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Treasury icon and info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getTreasuryIcon(),
              color: AccountantThemeConfig.primaryGreen,
              size: 24,
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Treasury name and type
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getTreasuryName(),
                  style: AccountantThemeConfig.headlineSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getTreasuryTypeDisplay(),
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    color: AccountantThemeConfig.white70,
                  ),
                ),
              ],
            ),
          ),
          
          // Refresh button
          IconButton(
            onPressed: _loadData,
            icon: Icon(
              Icons.refresh_rounded,
              color: Colors.white,
            ),
            style: IconButton.styleFrom(
              backgroundColor: AccountantThemeConfig.accentBlue.withValues(alpha: 0.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: AccountantThemeConfig.cardGradient,
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: AccountantThemeConfig.white60,
        labelStyle: AccountantThemeConfig.bodyMedium.copyWith(
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: AccountantThemeConfig.bodyMedium,
        tabs: const [
          Tab(
            icon: Icon(Icons.account_balance_rounded, size: 20),
            text: 'الرصيد',
          ),
          Tab(
            icon: Icon(Icons.receipt_long_rounded, size: 20),
            text: 'المعاملات',
          ),
          Tab(
            icon: Icon(Icons.hub_rounded, size: 20),
            text: 'الاتصالات',
          ),
          Tab(
            icon: Icon(Icons.settings_rounded, size: 20),
            text: 'الإعدادات',
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TabBarView(
        controller: _tabController,
        children: [
          TreasuryBalanceTab(
            treasuryId: widget.treasuryId,
            treasuryType: widget.treasuryType,
          ),
          TreasuryTransactionsTab(
            treasuryId: widget.treasuryId,
            treasuryType: widget.treasuryType,
          ),
          TreasuryConnectionsTab(
            treasuryId: widget.treasuryId,
            treasuryType: widget.treasuryType,
          ),
          TreasurySettingsTab(
            treasuryId: widget.treasuryId,
            treasuryType: widget.treasuryType,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              AccountantThemeConfig.primaryGreen,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'جاري تحميل البيانات...',
            style: AccountantThemeConfig.bodyLarge.copyWith(
              color: AccountantThemeConfig.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: AccountantThemeConfig.white60,
            ),
            const SizedBox(height: 16),
            Text(
              'حدث خطأ في تحميل البيانات',
              style: AccountantThemeConfig.headlineSmall.copyWith(
                color: AccountantThemeConfig.white70,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'خطأ غير معروف',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: AccountantThemeConfig.white60,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadData,
              style: AccountantThemeConfig.primaryButtonStyle,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}
