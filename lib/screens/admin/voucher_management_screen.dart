import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/voucher_provider.dart';
import '../../providers/supabase_provider.dart';
import '../../models/voucher_model.dart';
import '../../models/client_voucher_model.dart';
import '../../widgets/voucher/voucher_creation_form.dart';
import '../../widgets/voucher/client_selection_modal.dart';
import '../../widgets/voucher/voucher_card.dart';
import '../../utils/app_logger.dart';
import '../../utils/accountant_theme_config.dart';

class VoucherManagementScreen extends StatefulWidget {
  const VoucherManagementScreen({super.key});

  @override
  State<VoucherManagementScreen> createState() => _VoucherManagementScreenState();
}

class _VoucherManagementScreenState extends State<VoucherManagementScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _fadeAnimationController;
  late AnimationController _slideAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Initialize animations
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeAnimationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideAnimationController,
      curve: Curves.easeInOut,
    ));

    _initializeData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fadeAnimationController.dispose();
    _slideAnimationController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    if (_isInitialized) return;

    try {
      AppLogger.info('Initializing voucher management screen data...');

      final voucherProvider = Provider.of<VoucherProvider>(context, listen: false);
      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);

      // Ensure users are loaded for voucher assignment
      AppLogger.info('Loading users for voucher assignment...');
      await supabaseProvider.fetchAllUsers();

      // Load voucher data
      AppLogger.info('Loading voucher data...');
      await voucherProvider.loadAllData();
      await voucherProvider.loadAllClientVouchers();

      setState(() {
        _isInitialized = true;
      });

      // Start animations after data is loaded
      _fadeAnimationController.forward();
      await Future.delayed(const Duration(milliseconds: 200));
      _slideAnimationController.forward();

      AppLogger.info('Voucher management screen initialization completed');
    } catch (e) {
      AppLogger.error('Error initializing voucher management screen: $e');
      setState(() {
        _isInitialized = true; // Set to true to prevent infinite loading
      });
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
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildVouchersTab(),
                      _buildAssignmentsTab(),
                      _buildStatisticsTab(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _tabController.index == 0 ? _buildCreateVoucherFAB() : null,
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AccountantThemeConfig.primaryGreen.withOpacity(0.9),
            AccountantThemeConfig.accentBlue.withOpacity(0.8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.local_offer,
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
                    'إدارة القسائم',
                    style: AccountantThemeConfig.headlineLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'إنشاء وإدارة قسائم الخصم',
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
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  );
                }
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Clear All Vouchers Button
                    if (voucherProvider.vouchers.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.red.withOpacity(0.3),
                          ),
                        ),
                        child: IconButton(
                          onPressed: () => _showClearAllVouchersDialog(),
                          icon: const Icon(Icons.delete_sweep, color: Colors.red),
                          tooltip: 'حذف جميع القسائم',
                        ),
                      ),
                    // Refresh Button
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        onPressed: () => voucherProvider.refresh(),
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        tooltip: 'تحديث',
                      ),
                    ),
                  ],
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
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: AccountantThemeConfig.primaryGreen,
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: AccountantThemeConfig.primaryGreen,
        unselectedLabelColor: Colors.white60,
        labelStyle: AccountantThemeConfig.bodyMedium.copyWith(
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: AccountantThemeConfig.bodyMedium,
        tabs: [
          Tab(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _tabController.index == 0
                    ? AccountantThemeConfig.primaryGreen.withOpacity(0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.local_offer, size: 20),
            ),
            text: 'القسائم',
          ),
          Tab(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _tabController.index == 1
                    ? AccountantThemeConfig.primaryGreen.withOpacity(0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.assignment, size: 20),
            ),
            text: 'التعيينات',
          ),
          Tab(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _tabController.index == 2
                    ? AccountantThemeConfig.primaryGreen.withOpacity(0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.analytics, size: 20),
            ),
            text: 'الإحصائيات',
          ),
        ],
      ),
    );
  }

  Widget _buildVouchersTab() {
    return Consumer<VoucherProvider>(
      builder: (context, voucherProvider, child) {
        if (voucherProvider.isLoading && !_isInitialized) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AccountantThemeConfig.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: CircularProgressIndicator(
                    color: AccountantThemeConfig.primaryGreen,
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'جاري تحميل القسائم...',
                  style: AccountantThemeConfig.bodyLarge.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          );
        }

        if (voucherProvider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.red.withOpacity(0.1),
                        Colors.red.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.red.withOpacity(0.3),
                    ),
                  ),
                  child: const Icon(Icons.error_outline, color: Colors.red, size: 64),
                ),
                const SizedBox(height: 20),
                Text(
                  'حدث خطأ في التحميل',
                  style: AccountantThemeConfig.headlineSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  voucherProvider.error?.toString() ?? 'خطأ غير معروف',
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.red,
                        Colors.red.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => voucherProvider.loadVouchers(),
                    icon: const Icon(Icons.refresh, color: Colors.white),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final vouchers = voucherProvider.vouchers;

        if (vouchers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AccountantThemeConfig.primaryGreen.withOpacity(0.1),
                        AccountantThemeConfig.primaryGreen.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
                    ),
                  ),
                  child: Icon(
                    Icons.local_offer_outlined,
                    color: AccountantThemeConfig.primaryGreen,
                    size: 64,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'لا توجد قسائم بعد',
                  style: AccountantThemeConfig.headlineSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'ابدأ بإنشاء قسيمة جديدة لعملائك',
                  style: AccountantThemeConfig.bodyLarge.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    gradient: AccountantThemeConfig.blueGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _createVoucher,
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: Text(
                      'إنشاء قسيمة جديدة',
                      style: AccountantThemeConfig.bodyMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => voucherProvider.loadVouchers(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: vouchers.length,
            itemBuilder: (context, index) {
              final voucher = vouchers[index];
              return TweenAnimationBuilder<double>(
                duration: Duration(milliseconds: 800 + (index * 100)),
                tween: Tween(begin: 0.0, end: 1.0),
                curve: Curves.easeInOut,
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(0, 30 * (1 - value)),
                    child: Opacity(
                      opacity: value,
                      child: child,
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: VoucherCard(
                    voucher: voucher,
                    onEdit: () => _editVoucher(voucher),
                    onDelete: () => _deleteVoucher(voucher),
                    onAssign: () => _assignVoucher(voucher),
                    onToggleStatus: () => _toggleVoucherStatus(voucher),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildAssignmentsTab() {
    return Consumer<VoucherProvider>(
      builder: (context, voucherProvider, child) {
        if (voucherProvider.isLoading && !_isInitialized) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.green),
          );
        }

        final assignments = voucherProvider.allClientVouchers;

        if (assignments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AccountantThemeConfig.accentBlue.withOpacity(0.1),
                        AccountantThemeConfig.accentBlue.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AccountantThemeConfig.accentBlue.withOpacity(0.3),
                    ),
                  ),
                  child: Icon(
                    Icons.assignment_outlined,
                    color: AccountantThemeConfig.accentBlue,
                    size: 64,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'لا توجد تعيينات قسائم بعد',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'قم بتعيين القسائم للعملاء لتظهر هنا',
                  style: GoogleFonts.cairo(
                    color: Colors.grey.shade400,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => voucherProvider.loadAllClientVouchers(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: assignments.length,
            itemBuilder: (context, index) {
              final assignment = assignments[index];
              return TweenAnimationBuilder<double>(
                duration: Duration(milliseconds: 800 + (index * 100)),
                tween: Tween(begin: 0.0, end: 1.0),
                curve: Curves.easeInOut,
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(0, 30 * (1 - value)),
                    child: Opacity(
                      opacity: value,
                      child: child,
                    ),
                  );
                },
                child: _buildAssignmentCard(assignment),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildStatisticsTab() {
    return Consumer<VoucherProvider>(
      builder: (context, voucherProvider, child) {
        if (voucherProvider.isLoading && !_isInitialized) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.green),
          );
        }

        final stats = voucherProvider.statistics;

        return RefreshIndicator(
          onRefresh: () => voucherProvider.loadStatistics(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildStatCard('إجمالي القسائم', stats['totalVouchers']?.toString() ?? '0', Icons.local_offer),
                const SizedBox(height: 12),
                _buildStatCard('القسائم النشطة', stats['activeVouchers']?.toString() ?? '0', Icons.check_circle),
                const SizedBox(height: 12),
                _buildStatCard('القسائم المستخدمة', stats['usedVouchers']?.toString() ?? '0', Icons.shopping_cart),
                const SizedBox(height: 12),
                _buildStatCard('إجمالي التعيينات', stats['totalAssignments']?.toString() ?? '0', Icons.assignment),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAssignmentCard(ClientVoucherModel assignment) {
    final statusColor = _getStatusColor(assignment.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: statusColor.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Status Avatar
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    statusColor,
                    statusColor.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                _getStatusIcon(assignment.status),
                color: Colors.white,
                size: 24,
              ),
            ),

            const SizedBox(width: 16),

            // Assignment Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    assignment.voucherCode,
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    assignment.clientName ?? assignment.clientEmail ?? 'عميل غير معروف',
                    style: GoogleFonts.cairo(
                      color: Colors.grey.shade300,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'تاريخ التعيين: ${assignment.formattedAssignedDate}',
                    style: GoogleFonts.cairo(
                      color: Colors.grey.shade400,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    statusColor,
                    statusColor.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                assignment.status.displayName,
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: AccountantThemeConfig.primaryGreen.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AccountantThemeConfig.primaryGreen,
                    AccountantThemeConfig.primaryGreen.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.cairo(
                      color: Colors.grey.shade300,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateVoucherFAB() {
    return Container(
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.blueGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AccountantThemeConfig.primaryGreen.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: AccountantThemeConfig.primaryGreen.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: _createVoucher,
        backgroundColor: Colors.transparent,
        elevation: 0,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'إنشاء قسيمة',
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(ClientVoucherStatus status) {
    switch (status) {
      case ClientVoucherStatus.active:
        return Colors.green;
      case ClientVoucherStatus.used:
        return Colors.blue;
      case ClientVoucherStatus.expired:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(ClientVoucherStatus status) {
    switch (status) {
      case ClientVoucherStatus.active:
        return Icons.check_circle;
      case ClientVoucherStatus.used:
        return Icons.shopping_cart;
      case ClientVoucherStatus.expired:
        return Icons.access_time;
    }
  }

  void _createVoucher() {
    showDialog(
      context: context,
      builder: (context) => VoucherCreationForm(
        onVoucherCreated: (voucher) {
          Navigator.of(context).pop();
          _showAssignmentDialog(voucher);
        },
      ),
    );
  }

  void _editVoucher(VoucherModel voucher) {
    showDialog(
      context: context,
      builder: (context) => VoucherCreationForm(
        voucher: voucher,
        onVoucherCreated: (updatedVoucher) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم تحديث القسيمة بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }

  void _deleteVoucher(VoucherModel voucher) {
    showDialog(
      context: context,
      builder: (dialogContext) => _VoucherDeletionDialog(
        voucher: voucher,
        onResult: (result) {
          // Safely show SnackBar only if widget is still mounted
          if (mounted) {
            _showDeletionResult(result);
          }
        },
      ),
    );
  }

  void _showClearAllVouchersDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => _ClearAllVouchersDialog(
        onResult: (result) {
          if (mounted) {
            _showDeletionResult(result);
          }
        },
      ),
    );
  }

  void _showDeletionResult(Map<String, dynamic> result) {
    if (!mounted) return;

    final success = (result['success'] as bool?) == true;
    final message = (result['message'] as String?) ?? (success ? 'تم حذف القسيمة بنجاح' : 'فشل في حذف القسيمة');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green : Colors.red,
        duration: const Duration(seconds: 4),
        action: !success && (result['suggestedAction'] as String?) == 'deactivate'
            ? SnackBarAction(
                label: 'إلغاء التفعيل',
                textColor: Colors.white,
                onPressed: () => _showDeactivateOption(result),
              )
            : null,
      ),
    );
  }

  void _showDeactivateOption(Map<String, dynamic> result) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('إلغاء تفعيل القسيمة', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'لا يمكن حذف القسيمة لوجود تعيينات نشطة.',
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(
              'التعيينات النشطة: ${(result['activeAssignments'] as num?)?.toInt() ?? 0}',
              style: const TextStyle(color: Colors.orange),
            ),
            Text(
              'التعيينات المستخدمة: ${(result['usedAssignments'] as num?)?.toInt() ?? 0}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            const Text(
              'هل تريد إلغاء تفعيل القسيمة بدلاً من حذفها؟',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _deactivateVoucherSafely((result['voucherId'] as String?) ?? '');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('إلغاء التفعيل'),
          ),
        ],
      ),
    );
  }

  Future<void> _deactivateVoucherSafely(String voucherId) async {
    if (!mounted) return;

    final voucherProvider = Provider.of<VoucherProvider>(context, listen: false);
    final success = await voucherProvider.deactivateVoucher(voucherId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'تم إلغاء تفعيل القسيمة بنجاح'
              : voucherProvider.error ?? 'فشل في إلغاء تفعيل القسيمة'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _assignVoucher(VoucherModel voucher) {
    _showAssignmentDialog(voucher);
  }

  Future<void> _showAssignmentDialog(VoucherModel voucher) async {
    // Ensure users are loaded before showing the dialog
    final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
    if (supabaseProvider.allUsers.isEmpty) {
      AppLogger.info('Users not loaded, fetching before showing assignment dialog...');
      await supabaseProvider.fetchAllUsers();
    }

    showDialog(
      context: context,
      builder: (context) => ClientSelectionModal(
        voucher: voucher,
        onClientsSelected: (clientIds) async {
          Navigator.of(context).pop();

          final voucherProvider = Provider.of<VoucherProvider>(context, listen: false);
          final success = await voucherProvider.assignVouchersToClients(voucher.id, clientIds);

          if (mounted) {
            if (success) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('تم تعيين القسيمة لـ ${clientIds.length} عميل بنجاح'),
                  backgroundColor: Colors.green,
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(voucherProvider.error ?? 'فشل في تعيين القسيمة'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _toggleVoucherStatus(VoucherModel voucher) async {
    final voucherProvider = Provider.of<VoucherProvider>(context, listen: false);
    final success = await voucherProvider.deactivateVoucher(voucher.id);
    
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(voucher.isActive ? 'تم إلغاء تفعيل القسيمة' : 'تم تفعيل القسيمة'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(voucherProvider.error ?? 'فشل في تغيير حالة القسيمة'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// Enhanced voucher deletion dialog with constraint handling
class _VoucherDeletionDialog extends StatefulWidget {

  const _VoucherDeletionDialog({
    required this.voucher,
    required this.onResult,
  });
  final VoucherModel voucher;
  final Function(Map<String, dynamic>) onResult;

  @override
  State<_VoucherDeletionDialog> createState() => _VoucherDeletionDialogState();
}

class _VoucherDeletionDialogState extends State<_VoucherDeletionDialog> {
  bool _isLoading = false;
  Map<String, dynamic>? _preCheckResult;

  @override
  void initState() {
    super.initState();
    _performPreDeletionCheck();
  }

  Future<void> _performPreDeletionCheck() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final voucherProvider = Provider.of<VoucherProvider>(context, listen: false);

      // Perform a dry-run check to see if deletion is possible
      final result = await voucherProvider.deleteVoucher(widget.voucher.id);

      setState(() {
        _preCheckResult = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _preCheckResult = {
          'success': false,
          'canDelete': false,
          'reason': 'check_error',
          'message': 'فشل في فحص القسيمة: ${e.toString()}',
        };
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey.shade900,
      title: const Text('حذف القسيمة', style: TextStyle(color: Colors.white)),
      content: _buildContent(),
      actions: _buildActions(),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'جاري فحص القسيمة...',
            style: TextStyle(color: Colors.white),
          ),
        ],
      );
    }

    if (_preCheckResult == null) {
      return const Text(
        'فشل في فحص القسيمة',
        style: TextStyle(color: Colors.red),
      );
    }

    final canDelete = (_preCheckResult!['canDelete'] as bool?) == true;
    final activeAssignments = (_preCheckResult!['activeAssignments'] as num?)?.toInt() ?? 0;
    final usedAssignments = (_preCheckResult!['usedAssignments'] as num?)?.toInt() ?? 0;
    final totalAssignments = (_preCheckResult!['totalAssignments'] as num?)?.toInt() ?? 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'هل أنت متأكد من حذف القسيمة "${widget.voucher.name}"؟',
          style: const TextStyle(color: Colors.white),
        ),
        const SizedBox(height: 16),

        if (totalAssignments > 0) ...[
          const Text(
            'معلومات التعيينات:',
            style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'إجمالي التعيينات: $totalAssignments',
            style: const TextStyle(color: Colors.white),
          ),
          Text(
            'التعيينات النشطة: $activeAssignments',
            style: TextStyle(
              color: activeAssignments > 0 ? Colors.red : Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'التعيينات المستخدمة: $usedAssignments',
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
        ],

        if (!canDelete) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'لا يمكن الحذف',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  (_preCheckResult!['message'] as String?) ?? 'يوجد تعيينات نشطة',
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 8),
                const Text(
                  'يمكنك إلغاء تفعيل القسيمة بدلاً من حذفها.',
                  style: TextStyle(color: Colors.orange),
                ),
              ],
            ),
          ),
        ] else if (usedAssignments > 0) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'تحذير',
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'سيتم حذف سجل $usedAssignments تعيين مستخدم.',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _buildActions() {
    if (_isLoading || _preCheckResult == null) {
      return [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
      ];
    }

    final canDelete = (_preCheckResult!['canDelete'] as bool?) == true;

    return [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('إلغاء'),
      ),

      if (!canDelete) ...[
        ElevatedButton(
          onPressed: () => _deactivateVoucher(),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          child: const Text('إلغاء التفعيل'),
        ),
      ] else ...[
        ElevatedButton(
          onPressed: () => _confirmDeletion(),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('حذف'),
        ),
      ],
    ];
  }

  Future<void> _deactivateVoucher() async {
    Navigator.of(context).pop();

    final voucherProvider = Provider.of<VoucherProvider>(context, listen: false);
    final success = await voucherProvider.deactivateVoucher(widget.voucher.id);

    widget.onResult({
      'success': success,
      'action': 'deactivate',
      'message': success
          ? 'تم إلغاء تفعيل القسيمة بنجاح'
          : voucherProvider.error ?? 'فشل في إلغاء تفعيل القسيمة',
    });
  }

  Future<void> _confirmDeletion() async {
    Navigator.of(context).pop();

    final voucherProvider = Provider.of<VoucherProvider>(context, listen: false);
    final result = await voucherProvider.deleteVoucher(widget.voucher.id, forceDelete: true);

    widget.onResult({
      ...result,
      'action': 'delete',
      'voucherId': widget.voucher.id,
    });
  }
}

class _ClearAllVouchersDialog extends StatefulWidget {

  const _ClearAllVouchersDialog({
    required this.onResult,
  });
  final Function(Map<String, dynamic>) onResult;

  @override
  State<_ClearAllVouchersDialog> createState() => _ClearAllVouchersDialogState();
}

class _ClearAllVouchersDialogState extends State<_ClearAllVouchersDialog> {
  bool _isDeleting = false;
  bool _forceDelete = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey.shade900,
      title: const Row(
        children: [
          Icon(Icons.delete_sweep, color: Colors.red, size: 28),
          SizedBox(width: 8),
          Text(
            'حذف جميع القسائم',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '⚠️ هذا الإجراء خطير ولا يمكن التراجع عنه!',
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'هل أنت متأكد من حذف جميع القسائم من النظام؟',
            style: TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'تحذير شديد',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'سيتم حذف جميع القسائم وتعييناتها نهائياً من قاعدة البيانات. هذا الإجراء لا يمكن التراجع عنه.',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _forceDelete,
            onChanged: (value) => setState(() => _forceDelete = value ?? false),
            title: const Text(
              'حذف قسري (تجاهل التعيينات النشطة)',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            subtitle: const Text(
              'سيتم حذف جميع القسائم حتى لو كانت لها تعيينات نشطة',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
            activeColor: Colors.red,
            checkColor: Colors.white,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isDeleting ? null : () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _isDeleting ? null : _deleteAllVouchers,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: _isDeleting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(_forceDelete ? 'حذف قسري للكل' : 'حذف الكل'),
        ),
      ],
    );
  }

  Future<void> _deleteAllVouchers() async {
    setState(() {
      _isDeleting = true;
    });

    try {
      final voucherProvider = Provider.of<VoucherProvider>(context, listen: false);
      final result = await voucherProvider.deleteAllVouchers(forceDelete: _forceDelete);

      if (mounted) {
        Navigator.of(context).pop();
        widget.onResult(result);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        widget.onResult({
          'success': false,
          'message': 'خطأ في حذف جميع القسائم: ${e.toString()}',
          'error': e.toString(),
        });
      }
    }
  }
}
