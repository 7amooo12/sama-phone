import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/supabase_provider.dart';
import '../../models/wallet_transaction_model.dart';
import '../../utils/accountant_theme_config.dart';
import '../../widgets/common/custom_loader.dart';
import '../../config/routes.dart';

/// Wallet View Screen for Workers and Clients (Read-only)
class WalletViewScreen extends StatefulWidget {
  const WalletViewScreen({super.key});

  @override
  State<WalletViewScreen> createState() => _WalletViewScreenState();
}

class _WalletViewScreenState extends State<WalletViewScreen> {
  @override
  void initState() {
    super.initState();
    _loadWalletData();
  }

  void _loadWalletData() {
    final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    
    if (supabaseProvider.user != null) {
      walletProvider.loadUserWallet(supabaseProvider.user!.id);
      walletProvider.loadUserTransactions(supabaseProvider.user!.id);
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
          child: CustomScrollView(
            slivers: [
              // Modern SliverAppBar with gradient
              SliverAppBar(
                expandedHeight: 120,
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
                      'محفظتي',
                      style: AccountantThemeConfig.headlineMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        foreground: Paint()
                          ..shader = AccountantThemeConfig.greenGradient.createShader(
                            const Rect.fromLTWH(0.0, 0.0, 200.0, 70.0),
                          ),
                      ),
                    ),
                    centerTitle: true,
                    titlePadding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
                  ),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              // Wallet content
              _buildWalletContent(),
            ],
          ),
        ),
      ),
    );
  }

  /// Modern wallet content with enhanced styling
  Widget _buildWalletContent() {
    return Consumer2<WalletProvider, SupabaseProvider>(
      builder: (context, walletProvider, supabaseProvider, child) {
        if (walletProvider.isLoading) {
          return const SliverToBoxAdapter(
            child: CustomLoader(message: 'جاري تحميل المحفظة...'),
          );
        }

        if (walletProvider.error != null) {
          return SliverToBoxAdapter(
            child: _buildErrorState(walletProvider.error!),
          );
        }

        final wallet = walletProvider.currentUserWallet;

        if (wallet == null) {
          return SliverToBoxAdapter(
            child: _buildNoWalletState(),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Wallet Balance Card
              _buildModernWalletBalanceCard(wallet),
              const SizedBox(height: 24),

              // Quick Actions Row
              _buildQuickActionsRow(wallet),
              const SizedBox(height: 24),

              // Payment Button (for clients only)
              if (wallet.role == 'client') ...[
                _buildModernPaymentCard(),
                const SizedBox(height: 24),
              ],

              // Wallet Statistics
              _buildWalletStatisticsCard(wallet),
              const SizedBox(height: 24),

              // Wallet Info
              _buildModernWalletInfoCard(wallet),
              const SizedBox(height: 24),

              // Transactions Section
              _buildTransactionsSection(walletProvider.transactions),
            ]),
          ),
        );
      },
    );
  }

  /// Modern error state with AccountantThemeConfig styling
  Widget _buildErrorState(String error) {
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
            'حدث خطأ في تحميل المحفظة',
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ).animate().fadeIn(delay: 300.ms),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: AccountantThemeConfig.dangerRed,
              ),
              textAlign: TextAlign.center,
            ),
          ).animate().fadeIn(delay: 500.ms),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadWalletData,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
            style: AccountantThemeConfig.primaryButtonStyle,
          ).animate().slideY(begin: 0.3, delay: 700.ms),
        ],
      ),
    );
  }

  /// Modern no wallet state
  Widget _buildNoWalletState() {
    return Container(
      height: 500,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AccountantThemeConfig.cardShadows,
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AccountantThemeConfig.accentBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.account_balance_wallet_outlined,
              size: 64,
              color: AccountantThemeConfig.accentBlue,
            ),
          ).animate().scale(duration: 600.ms),
          const SizedBox(height: 24),
          Text(
            'لم يتم العثور على محفظة',
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ).animate().fadeIn(delay: 300.ms),
          const SizedBox(height: 12),
          Text(
            'يرجى التواصل مع الإدارة لإنشاء محفظة جديدة',
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 500.ms),
        ],
      ),
    );
  }

  Widget _buildModernWalletBalanceCard(wallet) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.greenGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          ...AccountantThemeConfig.cardShadows,
          BoxShadow(
            color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.4),
            blurRadius: 25,
            offset: const Offset(0, 12),
            spreadRadius: 2,
          ),
        ],
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      wallet?.statusDisplayName?.toString() ?? 'نشط',
                      style: AccountantThemeConfig.bodySmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'الرصيد الحالي',
            style: AccountantThemeConfig.bodyLarge.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            wallet?.formattedBalance?.toString() ?? '0.00 ج.م',
            style: AccountantThemeConfig.headlineLarge.copyWith(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  wallet.role == 'client' ? Icons.person_rounded : Icons.engineering_rounded,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  wallet?.roleDisplayName?.toString() ?? 'غير محدد',
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  wallet?.currency?.toString() ?? 'ج.م',
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.3);
  }

  /// Quick actions row with modern buttons
  Widget _buildQuickActionsRow(wallet) {
    return Row(
      children: [
        Expanded(
          child: _buildQuickActionButton(
            icon: Icons.refresh_rounded,
            title: 'تحديث',
            subtitle: 'الرصيد',
            color: AccountantThemeConfig.accentBlue,
            onTap: _loadWalletData,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildQuickActionButton(
            icon: Icons.history_rounded,
            title: 'السجل',
            subtitle: 'المعاملات',
            color: AccountantThemeConfig.secondaryGreen,
            onTap: () {
              // Scroll to transactions section
            },
          ),
        ),
        if (wallet.role == 'client') ...[
          const SizedBox(width: 12),
          Expanded(
            child: _buildQuickActionButton(
              icon: Icons.payment_rounded,
              title: 'دفع',
              subtitle: 'إلكتروني',
              color: AccountantThemeConfig.warningOrange,
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.paymentMethodSelection);
              },
            ),
          ),
        ],
      ],
    );
  }

  /// Quick action button widget
  Widget _buildQuickActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AccountantThemeConfig.cardShadows,
        border: AccountantThemeConfig.glowBorder(color),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withValues(alpha: 0.8),
                        color.withValues(alpha: 0.6),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AccountantThemeConfig.bodySmall.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.8, 0.8));
  }

  /// Modern wallet statistics card
  Widget _buildWalletStatisticsCard(wallet) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AccountantThemeConfig.cardShadows,
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: AccountantThemeConfig.blueGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.analytics_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'إحصائيات المحفظة',
                style: AccountantThemeConfig.headlineSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'تاريخ الإنشاء',
                  wallet?.createdAt != null
                      ? '${wallet.createdAt.day}/${wallet.createdAt.month}/${wallet.createdAt.year}'
                      : 'غير محدد',
                  Icons.calendar_today_rounded,
                  AccountantThemeConfig.primaryGreen,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatItem(
                  'آخر تحديث',
                  wallet?.updatedAt != null
                      ? '${wallet.updatedAt.day}/${wallet.updatedAt.month}/${wallet.updatedAt.year}'
                      : 'غير محدد',
                  Icons.update_rounded,
                  AccountantThemeConfig.accentBlue,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.3);
  }

  /// Stat item widget
  Widget _buildStatItem(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernWalletInfoCard(dynamic wallet) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AccountantThemeConfig.cardShadows,
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.secondaryGreen),
      ),
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
                      AccountantThemeConfig.secondaryGreen,
                      AccountantThemeConfig.secondaryGreen.withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'معلومات المحفظة',
                style: AccountantThemeConfig.headlineSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildModernInfoRow(
            'رقم المحفظة',
            wallet?.id?.toString().substring(0, 8) ?? 'غير محدد',
            Icons.tag_rounded,
            AccountantThemeConfig.primaryGreen,
          ),
          const SizedBox(height: 16),
          _buildModernInfoRow(
            'العملة',
            wallet?.currency?.toString() ?? 'ج.م',
            Icons.monetization_on_rounded,
            AccountantThemeConfig.accentBlue,
          ),
          const SizedBox(height: 16),
          _buildModernInfoRow(
            'نوع المحفظة',
            wallet?.roleDisplayName?.toString() ?? 'غير محدد',
            Icons.account_circle_rounded,
            AccountantThemeConfig.warningOrange,
          ),
        ],
      ),
    ).animate().fadeIn(delay: 600.ms).slideX(begin: -0.3);
  }

  /// Modern info row with icon and styling
  Widget _buildModernInfoRow(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white70,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Modern payment card for clients
  Widget _buildModernPaymentCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AccountantThemeConfig.warningOrange,
            AccountantThemeConfig.warningOrange.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          ...AccountantThemeConfig.cardShadows,
          BoxShadow(
            color: AccountantThemeConfig.warningOrange.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
            spreadRadius: 2,
          ),
        ],
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.warningOrange),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.payment_rounded,
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
                      'الدفع الإلكتروني',
                      style: AccountantThemeConfig.headlineSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'فودافون كاش • إنستاباي',
                      style: AccountantThemeConfig.bodyMedium.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.paymentMethodSelection);
              },
              icon: const Icon(Icons.arrow_forward_rounded, size: 20),
              label: Text(
                'ابدأ الدفع الآن',
                style: AccountantThemeConfig.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AccountantThemeConfig.warningOrange,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms).scale(begin: const Offset(0.9, 0.9));
  }

  /// Modern transactions section
  Widget _buildTransactionsSection(List<WalletTransactionModel> transactions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Transactions header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AccountantThemeConfig.cardGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AccountantThemeConfig.cardShadows,
            border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: AccountantThemeConfig.blueGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
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
                      'سجل المعاملات',
                      style: AccountantThemeConfig.headlineSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${transactions.length} معاملة',
                      style: AccountantThemeConfig.bodyMedium.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _loadWalletData,
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: Colors.white70,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: 800.ms),
        const SizedBox(height: 16),
        // Transactions list
        _buildModernTransactionsList(transactions),
      ],
    );
  }

  Widget _buildModernTransactionsList(List<WalletTransactionModel> transactions) {
    if (transactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          gradient: AccountantThemeConfig.cardGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AccountantThemeConfig.cardShadows,
          border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AccountantThemeConfig.accentBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                size: 48,
                color: AccountantThemeConfig.accentBlue,
              ),
            ).animate().scale(duration: 600.ms),
            const SizedBox(height: 24),
            Text(
              'لا توجد معاملات',
              style: AccountantThemeConfig.headlineSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ).animate().fadeIn(delay: 300.ms),
            const SizedBox(height: 12),
            Text(
              'ستظهر معاملاتك هنا عند إجرائها\nجميع العمليات المالية ستكون مسجلة بالتفصيل',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 500.ms),
          ],
        ),
      );
    }

    return Column(
      children: transactions.asMap().entries.map((entry) {
        final index = entry.key;
        final transaction = entry.value;
        return _buildModernTransactionCard(transaction, index);
      }).toList(),
    );
  }

  Widget _buildModernTransactionCard(WalletTransactionModel transaction, int index) {
    final isCredit = transaction.isCredit;
    final transactionColor = isCredit
        ? AccountantThemeConfig.primaryGreen
        : AccountantThemeConfig.dangerRed;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AccountantThemeConfig.cardShadows,
        border: AccountantThemeConfig.glowBorder(transactionColor.withValues(alpha: 0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Show transaction details
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Transaction icon
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        transactionColor.withValues(alpha: 0.8),
                        transactionColor.withValues(alpha: 0.6),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: transactionColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    isCredit ? Icons.add_rounded : Icons.remove_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                // Transaction details
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AccountantThemeConfig.accentBlue.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              transaction.typeDisplayName,
                              style: AccountantThemeConfig.bodySmall.copyWith(
                                color: AccountantThemeConfig.accentBlue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${transaction.formattedDate} ${transaction.formattedTime}',
                            style: AccountantThemeConfig.bodySmall.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                      if (transaction.referenceType != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'مرجع: ${transaction.referenceType.toString().split('.').last}',
                          style: AccountantThemeConfig.bodySmall.copyWith(
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Amount and status
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
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: transaction.status == TransactionStatus.completed
                            ? AccountantThemeConfig.primaryGreen.withValues(alpha: 0.2)
                            : AccountantThemeConfig.warningOrange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: transaction.status == TransactionStatus.completed
                              ? AccountantThemeConfig.primaryGreen.withValues(alpha: 0.4)
                              : AccountantThemeConfig.warningOrange.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        transaction.statusDisplayName,
                        style: AccountantThemeConfig.bodySmall.copyWith(
                          color: transaction.status == TransactionStatus.completed
                              ? AccountantThemeConfig.primaryGreen
                              : AccountantThemeConfig.warningOrange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: 100 * index)).slideX(begin: 0.3);
  }


}
