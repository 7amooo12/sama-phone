import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/electronic_payment_provider.dart';
import '../../providers/electronic_wallet_provider.dart';
import '../../widgets/electronic_payments/incoming_payments_tab.dart';
import '../../widgets/electronic_payments/wallet_management_tab.dart';
import '../../widgets/electronic_payments/payment_statistics_tab.dart';
import '../../widgets/common/custom_loader.dart';
import '../../utils/accountant_theme_config.dart';

/// Comprehensive Electronic Payment Management Screen
/// Features: Incoming Payments, Wallet Management, Statistics
class ElectronicPaymentManagementScreen extends StatefulWidget {
  const ElectronicPaymentManagementScreen({super.key});

  @override
  State<ElectronicPaymentManagementScreen> createState() => _ElectronicPaymentManagementScreenState();
}

class _ElectronicPaymentManagementScreenState extends State<ElectronicPaymentManagementScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final paymentProvider = Provider.of<ElectronicPaymentProvider>(context, listen: false);
      final walletProvider = Provider.of<ElectronicWalletProvider>(context, listen: false);

      // Load all data concurrently for better performance
      await Future.wait([
        paymentProvider.loadAllPayments(),
        paymentProvider.loadStatistics(),
        walletProvider.loadWallets(),
        walletProvider.loadStatistics(),
        walletProvider.loadAllTransactions(),
      ]);
    } catch (e) {
      setState(() {
        _error = 'حدث خطأ في تحميل البيانات: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
          child: CustomScrollView(
            slivers: [
              // Modern SliverAppBar with enhanced styling
              _buildModernSliverAppBar(),
              // Main content
              _buildMainContent(),
            ],
          ),
        ),
        floatingActionButton: _buildModernFloatingActionButton(),
      ),
    );
  }

  /// Modern SliverAppBar with gradient and enhanced styling
  Widget _buildModernSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: AccountantThemeConfig.mainBackgroundGradient,
        ),
        child: FlexibleSpaceBar(
          title: Text(
            'إدارة المدفوعات الإلكترونية',
            style: AccountantThemeConfig.headlineMedium.copyWith(
              fontWeight: FontWeight.bold,
              foreground: Paint()
                ..shader = AccountantThemeConfig.greenGradient.createShader(
                  const Rect.fromLTWH(0.0, 0.0, 300.0, 70.0),
                ),
            ),
          ),
          centerTitle: true,
          titlePadding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
          background: Container(
            decoration: const BoxDecoration(
              gradient: AccountantThemeConfig.mainBackgroundGradient,
            ),
            child: Stack(
              children: [
                // Background pattern
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.1,
                    child: CustomPaint(
                      painter: _PaymentPatternPainter(),
                    ),
                  ),
                ),
                // Floating icons animation
                Positioned(
                  top: 60,
                  right: 30,
                  child: Icon(
                    Icons.payment_rounded,
                    color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3),
                    size: 40,
                  ).animate(onPlay: (controller) => controller.repeat())
                    .scale(duration: 2000.ms, begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2))
                    .then()
                    .scale(duration: 2000.ms, begin: const Offset(1.2, 1.2), end: const Offset(0.8, 0.8)),
                ),
                Positioned(
                  top: 80,
                  left: 40,
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    color: AccountantThemeConfig.accentBlue.withValues(alpha: 0.3),
                    size: 35,
                  ).animate(onPlay: (controller) => controller.repeat())
                    .scale(duration: 2500.ms, begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1))
                    .then()
                    .scale(duration: 2500.ms, begin: const Offset(1.1, 1.1), end: const Offset(0.9, 0.9)),
                ),
              ],
            ),
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.greenGradient,
              borderRadius: BorderRadius.circular(8),
              boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
            ),
            child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
          ),
          onPressed: _loadInitialData,
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  /// Main content with enhanced error handling and loading states
  Widget _buildMainContent() {
    if (_isLoading) {
      return const SliverToBoxAdapter(
        child: CustomLoader(message: 'جاري تحميل بيانات المدفوعات...'),
      );
    }

    if (_error != null) {
      return SliverToBoxAdapter(
        child: _buildErrorState(),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          // Modern Tab Bar
          _buildModernTabBar(),
          const SizedBox(height: 24),

          // Tab Content
          _buildTabContent(),
        ]),
      ),
    );
  }

  /// Enhanced error state with modern styling
  Widget _buildErrorState() {
    return Container(
      height: 400,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AccountantThemeConfig.cardShadows,
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.dangerRed),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AccountantThemeConfig.dangerRed.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: AccountantThemeConfig.dangerRed,
            ),
          ).animate().scale(duration: 600.ms),
          const SizedBox(height: 24),
          Text(
            'حدث خطأ في تحميل البيانات',
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ).animate().fadeIn(delay: 300.ms),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _error!,
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: AccountantThemeConfig.dangerRed,
              ),
              textAlign: TextAlign.center,
            ),
          ).animate().fadeIn(delay: 500.ms),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadInitialData,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
            style: AccountantThemeConfig.primaryButtonStyle,
          ).animate().slideY(begin: 0.3, delay: 700.ms),
        ],
      ),
    );
  }



  /// Modern tab bar with enhanced styling
  Widget _buildModernTabBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AccountantThemeConfig.cardShadows,
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
      ),
      child: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(
            icon: Icon(Icons.payment_rounded, size: 22),
            text: 'المدفوعات الواردة',
          ),
          Tab(
            icon: Icon(Icons.account_balance_wallet_rounded, size: 22),
            text: 'إدارة المحافظ',
          ),
          Tab(
            icon: Icon(Icons.analytics_rounded, size: 22),
            text: 'الإحصائيات',
          ),
        ],
        indicator: BoxDecoration(
          gradient: AccountantThemeConfig.greenGradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.all(6),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        labelStyle: AccountantThemeConfig.bodyMedium.copyWith(
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: AccountantThemeConfig.bodyMedium,
        dividerColor: Colors.transparent,
      ),
    ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.3);
  }

  /// Tab content with enhanced container
  Widget _buildTabContent() {
    return Container(
      height: 600, // Fixed height for better layout
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AccountantThemeConfig.cardShadows,
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: TabBarView(
          controller: _tabController,
          children: const [
            IncomingPaymentsTab(),
            WalletManagementTab(),
            PaymentStatisticsTab(),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 600.ms).scale(begin: const Offset(0.95, 0.95));
  }

  /// Modern floating action button with enhanced styling
  Widget _buildModernFloatingActionButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.greenGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          ...AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
          BoxShadow(
            color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 2,
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _loadInitialData,
        backgroundColor: Colors.transparent,
        elevation: 0,
        icon: _isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.refresh_rounded, color: Colors.white),
        label: Text(
          _isLoading ? 'جاري التحديث...' : 'تحديث البيانات',
          style: AccountantThemeConfig.bodyMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ).animate().scale(delay: 800.ms, begin: const Offset(0.8, 0.8));
  }
}

/// Custom painter for background pattern
class _PaymentPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AccountantThemeConfig.primaryGreen.withValues(alpha: 0.1)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Draw payment-related pattern
    for (int i = 0; i < 5; i++) {
      final rect = Rect.fromLTWH(
        size.width * 0.1 + (i * size.width * 0.2),
        size.height * 0.3,
        size.width * 0.15,
        size.height * 0.4,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
