import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:smartbiztracker_new/providers/client_orders_provider.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:smartbiztracker_new/models/client_order_model.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/widgets/common/custom_loader.dart';
import 'package:smartbiztracker_new/config/routes.dart';
import 'package:smartbiztracker_new/widgets/voucher/voucher_order_details_widget.dart';

/// Professional Track Latest Order Screen for SmartBizTracker Client Interface
/// 
/// This screen provides a focused, single-order tracking experience similar to modern
/// e-commerce platforms. It displays the most recent order with comprehensive details,
/// progress tracking, and professional styling using AccountantThemeConfig.
class TrackLatestOrderScreen extends StatefulWidget {
  const TrackLatestOrderScreen({super.key});

  @override
  State<TrackLatestOrderScreen> createState() => _TrackLatestOrderScreenState();
}

class _TrackLatestOrderScreenState extends State<TrackLatestOrderScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  bool _isLoading = true;
  String? _error;
  ClientOrder? _latestOrder;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadLatestOrder();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
  }

  Future<void> _loadLatestOrder() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
      final user = supabaseProvider.user;
      
      if (user == null) {
        setState(() {
          _error = 'المستخدم غير مسجل الدخول';
          _isLoading = false;
        });
        return;
      }

      final ordersProvider = Provider.of<ClientOrdersProvider>(context, listen: false);
      await ordersProvider.loadClientOrders(user.id);

      if (ordersProvider.orders.isNotEmpty) {
        // Get the most recent order (orders are typically sorted by creation date)
        _latestOrder = ordersProvider.orders.first;
        
        // Start animations
        _fadeController.forward();
        await Future.delayed(const Duration(milliseconds: 200));
        _slideController.forward();
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'حدث خطأ في تحميل الطلب: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AccountantThemeConfig.luxuryBlack,
      appBar: _buildAppBar(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AccountantThemeConfig.mainBackgroundGradient,
        ),
        child: _buildBody(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: AccountantThemeConfig.cardGradient,
            borderRadius: BorderRadius.circular(12),
            border: AccountantThemeConfig.glowBorder(
              AccountantThemeConfig.accentBlue.withValues(alpha: 0.3),
            ),
          ),
          child: const Icon(
            Icons.arrow_back_ios_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        'تتبع آخر طلب',
        style: AccountantThemeConfig.headlineMedium.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AccountantThemeConfig.primaryGreen.withValues(alpha: 0.2),
                  AccountantThemeConfig.primaryGreen.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: AccountantThemeConfig.glowBorder(
                AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3),
              ),
            ),
            child: const Icon(
              Icons.refresh_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          onPressed: _loadLatestOrder,
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CustomLoader(message: 'جاري تحميل آخر طلب...'),
      );
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_latestOrder == null) {
      return _buildEmptyState();
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: _buildOrderContent(),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: AccountantThemeConfig.cardGradient,
          borderRadius: BorderRadius.circular(20),
          border: AccountantThemeConfig.glowBorder(
            AccountantThemeConfig.warningOrange.withValues(alpha: 0.3),
          ),
          boxShadow: AccountantThemeConfig.cardShadows,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AccountantThemeConfig.warningOrange.withValues(alpha: 0.2),
                    AccountantThemeConfig.warningOrange.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'حدث خطأ',
              style: AccountantThemeConfig.headlineSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _error ?? 'خطأ غير معروف',
              style: AccountantThemeConfig.bodyLarge.copyWith(
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadLatestOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ).copyWith(
                backgroundColor: WidgetStateProperty.all(Colors.transparent),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AccountantThemeConfig.primaryGreen,
                      AccountantThemeConfig.primaryGreen.withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Text(
                  'إعادة المحاولة',
                  style: AccountantThemeConfig.bodyLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
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
        margin: const EdgeInsets.all(24),
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
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AccountantThemeConfig.accentBlue.withValues(alpha: 0.2),
                    AccountantThemeConfig.accentBlue.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.shopping_cart_outlined,
                size: 48,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'لا توجد طلبات',
              style: AccountantThemeConfig.headlineSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'لم تقم بإنشاء أي طلبات بعد\nابدأ بتصفح المنتجات وإضافة طلبك الأول',
              style: AccountantThemeConfig.bodyLarge.copyWith(
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushNamed(AppRoutes.clientProductsBrowser);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ).copyWith(
                backgroundColor: WidgetStateProperty.all(Colors.transparent),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AccountantThemeConfig.primaryGreen,
                      AccountantThemeConfig.primaryGreen.withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Text(
                  'تصفح المنتجات',
                  style: AccountantThemeConfig.bodyLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOrderSummaryCard(),
          const SizedBox(height: 20),
          _buildProgressTimeline(),
          const SizedBox(height: 20),
          _buildProductDetailsSection(),
          const SizedBox(height: 20),
          _buildStatusUpdatesSection(),
          const SizedBox(height: 20),
          _buildActionButtonsSection(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildOrderSummaryCard() {
    final order = _latestOrder!;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: AccountantThemeConfig.glowBorder(
          AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3),
        ),
        boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
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
                      AccountantThemeConfig.primaryGreen,
                      AccountantThemeConfig.primaryGreen.withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
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
                      'طلب رقم #${order.id.substring(0, 8)}',
                      style: AccountantThemeConfig.headlineSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(order.createdAt),
                      style: AccountantThemeConfig.bodyMedium.copyWith(
                        color: Colors.white70,
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
                      _getStatusColor(order.status),
                      _getStatusColor(order.status).withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getStatusText(order.status),
                  style: AccountantThemeConfig.bodySmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
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
                AccountantThemeConfig.accentBlue.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Total amount section with pricing approval logic
                _shouldShowPrices()
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'إجمالي المبلغ',
                            style: AccountantThemeConfig.bodyMedium.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AccountantThemeConfig.formatCurrency(order.total),
                            style: AccountantThemeConfig.headlineSmall.copyWith(
                              color: AccountantThemeConfig.primaryGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'إجمالي المبلغ',
                            style: AccountantThemeConfig.bodyMedium.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AccountantThemeConfig.warningOrange.withValues(alpha: 0.2),
                                  AccountantThemeConfig.warningOrange.withValues(alpha: 0.1),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'في انتظار اعتماد التسعير',
                              style: AccountantThemeConfig.bodySmall.copyWith(
                                color: AccountantThemeConfig.warningOrange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'عدد المنتجات',
                      style: AccountantThemeConfig.bodyMedium.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${order.items.length}',
                      style: AccountantThemeConfig.headlineSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressTimeline() {
    final order = _latestOrder!;
    final stages = _getOrderStages();
    final currentStageIndex = _getCurrentStageIndex(order.status);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: AccountantThemeConfig.glowBorder(
          AccountantThemeConfig.accentBlue.withValues(alpha: 0.3),
        ),
        boxShadow: AccountantThemeConfig.cardShadows,
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
                      AccountantThemeConfig.accentBlue,
                      AccountantThemeConfig.accentBlue.withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.timeline_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'تتبع حالة الطلب',
                style: AccountantThemeConfig.headlineSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ...stages.asMap().entries.map((entry) {
            final index = entry.key;
            final stage = entry.value;
            final isCompleted = index <= currentStageIndex;
            final isCurrent = index == currentStageIndex;
            final isLast = index == stages.length - 1;

            return Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: isCompleted
                            ? LinearGradient(
                                colors: [
                                  AccountantThemeConfig.primaryGreen,
                                  AccountantThemeConfig.primaryGreen.withValues(alpha: 0.8),
                                ],
                              )
                            : LinearGradient(
                                colors: [
                                  Colors.grey.withValues(alpha: 0.3),
                                  Colors.grey.withValues(alpha: 0.2),
                                ],
                              ),
                        borderRadius: BorderRadius.circular(20),
                        border: isCurrent
                            ? AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen)
                            : null,
                      ),
                      child: Icon(
                        isCompleted ? Icons.check_rounded : stage['icon'] as IconData,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stage['title'] as String,
                            style: AccountantThemeConfig.bodyLarge.copyWith(
                              color: isCompleted ? Colors.white : Colors.white60,
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          if (stage['description'] != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              stage['description'] as String,
                              style: AccountantThemeConfig.bodySmall.copyWith(
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (!isLast) ...[
                  const SizedBox(height: 16),
                  Container(
                    margin: const EdgeInsets.only(right: 20),
                    width: 2,
                    height: 24,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: isCompleted
                            ? [
                                AccountantThemeConfig.primaryGreen.withValues(alpha: 0.6),
                                AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3),
                              ]
                            : [
                                Colors.grey.withValues(alpha: 0.3),
                                Colors.grey.withValues(alpha: 0.1),
                              ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildProductDetailsSection() {
    final order = _latestOrder!;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: AccountantThemeConfig.glowBorder(
          AccountantThemeConfig.accentBlue.withValues(alpha: 0.3),
        ),
        boxShadow: AccountantThemeConfig.cardShadows,
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
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.inventory_2_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'تفاصيل المنتجات',
                style: AccountantThemeConfig.headlineSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Check if this is a voucher order
          if (order.metadata != null && order.metadata!['isVoucherOrder'] == true) ...[
            VoucherOrderDetailsWidget(
              order: order,
              showFullDetails: true,
              isCompact: false,
            ),
          ] else ...[
            ...order.items.map((item) => _buildProductItem(item)).toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildProductItem(OrderItem item) {
    // Check if prices should be visible based on pricing approval status
    final bool shouldShowPrices = _shouldShowPrices();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
          AccountantThemeConfig.accentBlue.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AccountantThemeConfig.primaryGreen.withValues(alpha: 0.2),
                  AccountantThemeConfig.primaryGreen.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.shopping_bag_rounded,
              color: Colors.white70,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: AccountantThemeConfig.bodyLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'الكمية: ${item.quantity}',
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          // Price section with pricing approval logic
          shouldShowPrices
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      AccountantThemeConfig.formatCurrency(item.price),
                      style: AccountantThemeConfig.bodyLarge.copyWith(
                        color: AccountantThemeConfig.primaryGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'المجموع: ${AccountantThemeConfig.formatCurrency(item.total)}',
                      style: AccountantThemeConfig.bodySmall.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                )
              : _buildPendingPriceIndicator(),
        ],
      ),
    );
  }

  Widget _buildStatusUpdatesSection() {
    final order = _latestOrder!;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: AccountantThemeConfig.glowBorder(
          AccountantThemeConfig.accentBlue.withValues(alpha: 0.3),
        ),
        boxShadow: AccountantThemeConfig.cardShadows,
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
                      AccountantThemeConfig.warningOrange,
                      AccountantThemeConfig.warningOrange.withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.update_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'آخر التحديثات',
                style: AccountantThemeConfig.headlineSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildStatusUpdate(
            'تم إنشاء الطلب',
            order.createdAt,
            Icons.add_shopping_cart_rounded,
            AccountantThemeConfig.primaryGreen,
          ),
          if (order.updatedAt != null) ...[
            const SizedBox(height: 12),
            _buildStatusUpdate(
              'آخر تحديث للطلب',
              order.updatedAt!,
              Icons.update_rounded,
              AccountantThemeConfig.accentBlue,
            ),
          ],
          // Show pricing status if order requires pricing approval
          if (order.requiresPricingApproval) ...[
            const SizedBox(height: 12),
            if (order.isPricingApproved && order.pricingApprovedAt != null) ...[
              _buildStatusUpdate(
                'تم اعتماد التسعير',
                order.pricingApprovedAt!,
                Icons.price_check_rounded,
                AccountantThemeConfig.secondaryGreen,
              ),
            ] else if (order.isPricingRejected) ...[
              _buildStatusUpdate(
                'تم رفض التسعير',
                order.updatedAt ?? order.createdAt,
                Icons.cancel_rounded,
                Colors.red,
              ),
            ] else ...[
              _buildPendingPricingStatusUpdate(),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildStatusUpdate(String title, DateTime dateTime, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.1),
            color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: AccountantThemeConfig.glowBorder(
          color.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
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
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(dateTime),
                  style: AccountantThemeConfig.bodySmall.copyWith(
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

  Widget _buildActionButtonsSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: AccountantThemeConfig.glowBorder(
          AccountantThemeConfig.accentBlue.withValues(alpha: 0.3),
        ),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الإجراءات المتاحة',
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  'تصفح المنتجات',
                  Icons.shopping_bag_rounded,
                  AccountantThemeConfig.primaryGreen,
                  () {
                    Navigator.of(context).pushNamed(AppRoutes.clientProductsBrowser);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  'جميع الطلبات',
                  Icons.list_alt_rounded,
                  AccountantThemeConfig.accentBlue,
                  () {
                    Navigator.of(context).pushNamed(AppRoutes.clientTracking);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: _buildActionButton(
              'تواصل مع خدمة العملاء',
              Icons.support_agent_rounded,
              AccountantThemeConfig.secondaryGreen,
              () {
                Navigator.of(context).pushNamed(AppRoutes.customerService);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String title, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ).copyWith(
        backgroundColor: WidgetStateProperty.all(Colors.transparent),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color,
              color.withValues(alpha: 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods
  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return AccountantThemeConfig.warningOrange;
      case OrderStatus.confirmed:
        return AccountantThemeConfig.accentBlue;
      case OrderStatus.processing:
        return AccountantThemeConfig.secondaryGreen;
      case OrderStatus.shipped:
        return AccountantThemeConfig.primaryGreen;
      case OrderStatus.delivered:
        return AccountantThemeConfig.primaryGreen;
      case OrderStatus.cancelled:
        return Colors.red;
    }
  }

  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'في الانتظار';
      case OrderStatus.confirmed:
        return 'مؤكد';
      case OrderStatus.processing:
        return 'قيد التجهيز';
      case OrderStatus.shipped:
        return 'تم الشحن';
      case OrderStatus.delivered:
        return 'تم التسليم';
      case OrderStatus.cancelled:
        return 'ملغي';
    }
  }

  List<Map<String, dynamic>> _getOrderStages() {
    return [
      {
        'title': 'تم استلام الطلب',
        'description': 'تم إنشاء الطلب بنجاح',
        'icon': Icons.receipt_rounded,
      },
      {
        'title': 'تأكيد الطلب',
        'description': 'جاري مراجعة وتأكيد الطلب',
        'icon': Icons.check_circle_rounded,
      },
      {
        'title': 'قيد التجهيز',
        'description': 'جاري تجهيز المنتجات',
        'icon': Icons.inventory_rounded,
      },
      {
        'title': 'تم الشحن',
        'description': 'تم شحن الطلب',
        'icon': Icons.local_shipping_rounded,
      },
      {
        'title': 'تم التسليم',
        'description': 'تم تسليم الطلب بنجاح',
        'icon': Icons.done_all_rounded,
      },
    ];
  }

  int _getCurrentStageIndex(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 0;
      case OrderStatus.confirmed:
        return 1;
      case OrderStatus.processing:
        return 2;
      case OrderStatus.shipped:
        return 3;
      case OrderStatus.delivered:
        return 4;
      case OrderStatus.cancelled:
        return 0; // Show as first stage for cancelled orders
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// Determines if prices should be shown based on pricing approval status
  bool _shouldShowPrices() {
    final order = _latestOrder;
    if (order == null) return false;

    // Show prices if:
    // 1. Order doesn't require pricing approval, OR
    // 2. Pricing has been approved
    return !order.requiresPricingApproval || order.isPricingApproved;
  }

  /// Build pending price indicator when prices are hidden
  Widget _buildPendingPriceIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AccountantThemeConfig.warningOrange.withValues(alpha: 0.2),
            AccountantThemeConfig.warningOrange.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AccountantThemeConfig.warningOrange.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Icon(
            Icons.schedule_rounded,
            color: AccountantThemeConfig.warningOrange,
            size: 16,
          ),
          const SizedBox(height: 4),
          Text(
            'في انتظار اعتماد التسعير',
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: AccountantThemeConfig.warningOrange,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Build pending pricing status update for status updates section
  Widget _buildPendingPricingStatusUpdate() {
    return Container(
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
          AccountantThemeConfig.warningOrange.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
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
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.schedule_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'في انتظار اعتماد التسعير',
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'سيتم عرض الأسعار بعد اعتماد المحاسب',
                  style: AccountantThemeConfig.bodySmall.copyWith(
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
}
