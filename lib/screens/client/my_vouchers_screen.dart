import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/voucher_provider.dart';
import '../../providers/supabase_provider.dart';
import '../../models/client_voucher_model.dart';
import '../../widgets/voucher/voucher_card.dart';
import '../../utils/accountant_theme_config.dart';
import '../../config/routes.dart';

class MyVouchersScreen extends StatefulWidget {
  const MyVouchersScreen({super.key});

  @override
  State<MyVouchersScreen> createState() => _MyVouchersScreenState();
}

class _MyVouchersScreenState extends State<MyVouchersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Defer initialization until after the build phase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    if (_isInitialized) return;

    try {
      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
      final voucherProvider = Provider.of<VoucherProvider>(context, listen: false);

      final currentUser = supabaseProvider.user;
      if (currentUser != null) {
        await voucherProvider.loadClientVouchers(currentUser.id);
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      // Handle any initialization errors gracefully
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    }
  }

  Future<void> _refreshVouchers() async {
    final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
    final voucherProvider = Provider.of<VoucherProvider>(context, listen: false);
    
    final currentUser = supabaseProvider.user;
    if (currentUser != null) {
      await voucherProvider.loadClientVouchers(currentUser.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AccountantThemeConfig.luxuryBlack,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AccountantThemeConfig.mainBackgroundGradient,
        ),
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Tab Bar
            _buildTabBar(),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildActiveVouchersTab(),
                  _buildUsedVouchersTab(),
                  _buildExpiredVouchersTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.greenGradient,
        boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.2),
                    Colors.white.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: AccountantThemeConfig.glowBorder(
                  Colors.white.withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(
                Icons.local_offer_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'قسائمي',
                    style: AccountantThemeConfig.headlineMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'قسائم الخصم المتاحة لك',
                    style: AccountantThemeConfig.bodyLarge.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
            Consumer<VoucherProvider>(
              builder: (context, voucherProvider, child) {
                if (voucherProvider.isLoading) {
                  return Container(
                    width: 48,
                    height: 48,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.2),
                          Colors.white.withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  );
                }
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.2),
                        Colors.white.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: AccountantThemeConfig.glowBorder(
                      Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: IconButton(
                    onPressed: _refreshVouchers,
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                    tooltip: 'تحديث القسائم',
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AccountantThemeConfig.cardBackground1.withValues(alpha: 0.8),
            AccountantThemeConfig.cardBackground2.withValues(alpha: 0.8),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: AccountantThemeConfig.primaryGreen,
        indicatorWeight: 3,
        labelColor: AccountantThemeConfig.primaryGreen,
        unselectedLabelColor: Colors.white60,
        labelStyle: AccountantThemeConfig.bodyMedium.copyWith(
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: AccountantThemeConfig.bodyMedium,
        tabs: const [
          Tab(
            icon: Icon(Icons.check_circle_rounded),
            text: 'نشطة',
          ),
          Tab(
            icon: Icon(Icons.shopping_cart_rounded),
            text: 'مستخدمة',
          ),
          Tab(
            icon: Icon(Icons.access_time_rounded),
            text: 'منتهية الصلاحية',
          ),
        ],
      ),
    );
  }

  Widget _buildActiveVouchersTab() {
    return Consumer<VoucherProvider>(
      builder: (context, voucherProvider, child) {
        if (voucherProvider.isLoading && !_isInitialized) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.green),
          );
        }

        if (voucherProvider.error != null) {
          return _buildErrorState(voucherProvider.error!);
        }

        final activeVouchers = voucherProvider.activeClientVouchers;

        if (activeVouchers.isEmpty) {
          return _buildEmptyState(
            icon: Icons.local_offer,
            title: 'لا توجد قسائم نشطة',
            subtitle: 'ستظهر هنا القسائم المتاحة للاستخدام',
          );
        }

        return RefreshIndicator(
          onRefresh: _refreshVouchers,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: activeVouchers.length,
            itemBuilder: (context, index) {
              final clientVoucher = activeVouchers[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildVoucherCardSafe(clientVoucher),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildUsedVouchersTab() {
    return Consumer<VoucherProvider>(
      builder: (context, voucherProvider, child) {
        if (voucherProvider.isLoading && !_isInitialized) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.green),
          );
        }

        final usedVouchers = voucherProvider.usedClientVouchers;

        if (usedVouchers.isEmpty) {
          return _buildEmptyState(
            icon: Icons.shopping_cart,
            title: 'لا توجد قسائم مستخدمة',
            subtitle: 'ستظهر هنا القسائم التي استخدمتها',
          );
        }

        return RefreshIndicator(
          onRefresh: _refreshVouchers,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: usedVouchers.length,
            itemBuilder: (context, index) {
              final clientVoucher = usedVouchers[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildUsedVoucherCard(clientVoucher),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildExpiredVouchersTab() {
    return Consumer<VoucherProvider>(
      builder: (context, voucherProvider, child) {
        if (voucherProvider.isLoading && !_isInitialized) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.green),
          );
        }

        final expiredVouchers = voucherProvider.expiredClientVouchers;

        if (expiredVouchers.isEmpty) {
          return _buildEmptyState(
            icon: Icons.access_time,
            title: 'لا توجد قسائم منتهية الصلاحية',
            subtitle: 'ستظهر هنا القسائم المنتهية الصلاحية',
          );
        }

        return RefreshIndicator(
          onRefresh: _refreshVouchers,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: expiredVouchers.length,
            itemBuilder: (context, index) {
              final clientVoucher = expiredVouchers[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildVoucherCardSafe(clientVoucher),
              );
            },
          ),
        );
      },
    );
  }

  /// Safe voucher card builder that handles null voucher data
  Widget _buildVoucherCardSafe(ClientVoucherModel clientVoucher) {
    // Check if voucher data is available
    if (clientVoucher.voucher == null) {
      return _buildMissingVoucherCard(clientVoucher);
    }

    // Use the regular VoucherCard for valid voucher data, passing the complete ClientVoucherModel
    return VoucherCard(
      clientVoucher: clientVoucher,
      isClientView: true,
      showActions: false,
    );
  }

  /// Build a card for client vouchers with missing voucher data
  Widget _buildMissingVoucherCard(ClientVoucherModel clientVoucher) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: AccountantThemeConfig.glowBorder(
          AccountantThemeConfig.warningOrange.withValues(alpha: 0.5),
        ),
        boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.warningOrange),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with warning
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AccountantThemeConfig.warningOrange,
                        AccountantThemeConfig.warningOrange.withValues(alpha: 0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.warning_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'بيانات القسيمة غير متوفرة',
                    style: AccountantThemeConfig.headlineSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AccountantThemeConfig.warningOrange,
                        AccountantThemeConfig.warningOrange.withValues(alpha: 0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'بيانات ناقصة',
                    style: AccountantThemeConfig.bodySmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Available information from ClientVoucherModel
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AccountantThemeConfig.warningOrange.withValues(alpha: 0.1),
                    AccountantThemeConfig.warningOrange.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: AccountantThemeConfig.glowBorder(
                  AccountantThemeConfig.warningOrange.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (clientVoucher.voucherCode.isNotEmpty) ...[
                    _buildInfoRow('كود القسيمة', clientVoucher.voucherCode),
                    const SizedBox(height: 12),
                  ],
                  if (clientVoucher.voucherName.isNotEmpty) ...[
                    _buildInfoRow('اسم القسيمة', clientVoucher.voucherName),
                    const SizedBox(height: 12),
                  ],
                  _buildInfoRow('الحالة', _getStatusDisplayName(clientVoucher.status)),
                  const SizedBox(height: 12),
                  _buildInfoRow('تاريخ التعيين', clientVoucher.formattedAssignedDate),
                  if (clientVoucher.discountAmount > 0) ...[
                    const SizedBox(height: 12),
                    _buildInfoRow('مبلغ الخصم', '${clientVoucher.discountAmount.toStringAsFixed(2)} ج.م'),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Action button
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AccountantThemeConfig.warningOrange,
                    AccountantThemeConfig.warningOrange.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.warningOrange),
              ),
              child: ElevatedButton.icon(
                onPressed: _refreshVouchers,
                icon: const Icon(Icons.refresh_rounded, size: 18, color: Colors.white),
                label: Text(
                  'إعادة تحميل البيانات',
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
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
          width: 100,
          child: Text(
            label,
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: Colors.white70,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  String _getStatusDisplayName(ClientVoucherStatus status) {
    switch (status) {
      case ClientVoucherStatus.active:
        return 'نشط';
      case ClientVoucherStatus.used:
        return 'مستخدم';
      case ClientVoucherStatus.expired:
        return 'منتهي الصلاحية';
    }
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: AccountantThemeConfig.cardGradient,
          borderRadius: BorderRadius.circular(20),
          border: AccountantThemeConfig.glowBorder(
            AccountantThemeConfig.accentBlue.withValues(alpha: 0.3),
          ),
          boxShadow: AccountantThemeConfig.cardShadows,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AccountantThemeConfig.accentBlue.withValues(alpha: 0.2),
                    AccountantThemeConfig.accentBlue.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                icon,
                size: 64,
                color: AccountantThemeConfig.accentBlue,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: AccountantThemeConfig.headlineSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: AccountantThemeConfig.bodyLarge.copyWith(
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: AccountantThemeConfig.cardGradient,
          borderRadius: BorderRadius.circular(20),
          border: AccountantThemeConfig.glowBorder(
            AccountantThemeConfig.dangerRed.withValues(alpha: 0.3),
          ),
          boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.dangerRed),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AccountantThemeConfig.dangerRed.withValues(alpha: 0.2),
                    AccountantThemeConfig.dangerRed.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: AccountantThemeConfig.dangerRed,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'حدث خطأ',
              style: AccountantThemeConfig.headlineSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              error,
              style: AccountantThemeConfig.bodyLarge.copyWith(
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AccountantThemeConfig.primaryGreen,
                    AccountantThemeConfig.primaryGreen.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
              ),
              child: ElevatedButton.icon(
                onPressed: _refreshVouchers,
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                label: Text(
                  'إعادة المحاولة',
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsedVoucherCard(ClientVoucherModel clientVoucher) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: AccountantThemeConfig.glowBorder(
          AccountantThemeConfig.accentBlue.withValues(alpha: 0.5),
        ),
        boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.accentBlue),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Voucher info
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AccountantThemeConfig.accentBlue,
                        AccountantThemeConfig.accentBlue.withValues(alpha: 0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clientVoucher.voucherName,
                        style: AccountantThemeConfig.headlineSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        clientVoucher.voucherCode,
                        style: AccountantThemeConfig.bodyMedium.copyWith(
                          color: AccountantThemeConfig.primaryGreen,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AccountantThemeConfig.accentBlue,
                        AccountantThemeConfig.accentBlue.withValues(alpha: 0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'مستخدم',
                    style: AccountantThemeConfig.bodySmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Usage details
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AccountantThemeConfig.accentBlue.withValues(alpha: 0.1),
                    AccountantThemeConfig.accentBlue.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: AccountantThemeConfig.glowBorder(
                  AccountantThemeConfig.accentBlue.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: AccountantThemeConfig.accentBlue,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'تم الاستخدام بنجاح',
                        style: AccountantThemeConfig.bodyMedium.copyWith(
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'تاريخ الاستخدام',
                              style: AccountantThemeConfig.bodySmall.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              clientVoucher.formattedUsedDate ?? 'غير محدد',
                              style: AccountantThemeConfig.bodyMedium.copyWith(
                                color: AccountantThemeConfig.accentBlue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'مبلغ الخصم',
                              style: AccountantThemeConfig.bodySmall.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${clientVoucher.discountAmount.toStringAsFixed(2)} ج.م',
                              style: AccountantThemeConfig.bodyMedium.copyWith(
                                color: AccountantThemeConfig.primaryGreen,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
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
    );
  }

}
