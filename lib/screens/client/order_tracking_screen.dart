import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'package:smartbiztracker_new/models/client_order_model.dart';
import 'package:smartbiztracker_new/providers/client_orders_provider.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/widgets/common/custom_loader.dart';
import 'package:smartbiztracker_new/widgets/common/optimized_image.dart';
import 'package:smartbiztracker_new/widgets/common/elegant_search_bar.dart';
import 'package:smartbiztracker_new/widgets/voucher/voucher_order_details_widget.dart';

class OrderTrackingScreen extends StatefulWidget {

  const OrderTrackingScreen({
    super.key,
    this.orderId,
  });
  final String? orderId;

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  String _searchQuery = '';
  List<ClientOrder> _filteredOrders = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrders();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    final orderProvider = Provider.of<ClientOrdersProvider>(context, listen: false);
    final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);

    final user = supabaseProvider.user;
    if (user != null) {
      await orderProvider.loadClientOrders(user.id);

      // إذا كان هناك orderId محدد، تحميل تفاصيله
      if (widget.orderId != null) {
        await orderProvider.loadOrderDetails(widget.orderId!);
      }

      // Initialize filtered orders
      _updateFilteredOrders(orderProvider.orders);
    }
  }

  /// Search functionality with debouncing
  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1500), () {
      setState(() {
        _searchQuery = query.trim().toLowerCase();
        _isSearching = _searchQuery.isNotEmpty;
      });
      _performSearch();
    });
  }

  /// Clear search and reset filters
  void _clearSearch() {
    _searchController.clear();
    _debounceTimer?.cancel();
    setState(() {
      _searchQuery = '';
      _isSearching = false;
    });
    final orderProvider = Provider.of<ClientOrdersProvider>(context, listen: false);
    _updateFilteredOrders(orderProvider.orders);
  }

  /// Perform search filtering
  void _performSearch() {
    final orderProvider = Provider.of<ClientOrdersProvider>(context, listen: false);
    if (_searchQuery.isEmpty) {
      _updateFilteredOrders(orderProvider.orders);
      return;
    }

    final filtered = orderProvider.orders.where((order) {
      // Search in product names within order items
      final productMatches = order.items.any((item) =>
          item.productName.toLowerCase().contains(_searchQuery));

      // Search in order ID
      final orderIdMatches = order.id.toLowerCase().contains(_searchQuery);

      // Search in order status
      final statusMatches = order.statusText.toLowerCase().contains(_searchQuery);

      return productMatches || orderIdMatches || statusMatches;
    }).toList();

    _updateFilteredOrders(filtered);
  }

  /// Update filtered orders list
  void _updateFilteredOrders(List<ClientOrder> orders) {
    setState(() {
      _filteredOrders = List.from(orders);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AccountantThemeConfig.mainBackgroundGradient,
        ),
        child: CustomScrollView(
          slivers: [
            // Modern SliverAppBar with SAMA branding
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
                    'تتبع الطلبات',
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
            // Advanced Search Bar
            _buildSearchBar(),
            // Orders content
            _buildOrdersContent(),
          ],
        ),
      ),
    );
  }

  /// Modern search bar with AccountantThemeConfig styling
  Widget _buildSearchBar() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AccountantThemeConfig.cardGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AccountantThemeConfig.cardShadows,
          border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
        ),
        child: ElegantSearchBar(
          controller: _searchController,
          hintText: 'البحث في الطلبات بالمنتج أو رقم الطلب...',
          prefixIcon: Icons.search_rounded,
          onChanged: _onSearchChanged,
          onClear: _clearSearch,
          backgroundColor: Colors.transparent,
          textColor: Colors.white,
          hintColor: Colors.white.withOpacity(0.6),
          iconColor: AccountantThemeConfig.primaryGreen,
          borderColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2),
    );
  }

  Widget _buildOrdersContent() {
    return Consumer<ClientOrdersProvider>(
      builder: (context, orderProvider, child) {
        if (orderProvider.isLoading) {
          return const SliverToBoxAdapter(
            child: CustomLoader(message: 'جاري تحميل الطلبات...'),
          );
        }

        if (orderProvider.error != null) {
          return SliverToBoxAdapter(
            child: _buildErrorState(orderProvider.error!),
          );
        }

        if (orderProvider.orders.isEmpty) {
          return SliverToBoxAdapter(
            child: _buildEmptyState(),
          );
        }

        // Initialize filtered orders if empty and not searching
        if (_filteredOrders.isEmpty && !_isSearching) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _updateFilteredOrders(orderProvider.orders);
          });
        }

        // Use filtered orders for display
        final ordersToShow = _filteredOrders.isEmpty && _isSearching
            ? <ClientOrder>[]
            : _filteredOrders.isEmpty
                ? orderProvider.orders
                : _filteredOrders;

        if (ordersToShow.isEmpty && _isSearching) {
          return SliverToBoxAdapter(
            child: _buildNoSearchResultsState(),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final order = ordersToShow[index];
                return _buildModernOrderCard(order, index);
              },
              childCount: ordersToShow.length,
            ),
          ),
        );
      },
    );
  }

  /// No search results state with AccountantThemeConfig styling
  Widget _buildNoSearchResultsState() {
    return Container(
      height: 400,
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
              Icons.search_off_rounded,
              size: 64,
              color: AccountantThemeConfig.accentBlue,
            ),
          ).animate().scale(duration: 600.ms),
          const SizedBox(height: 24),
          Text(
            'لا توجد نتائج للبحث',
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ).animate().fadeIn(delay: 300.ms),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'لم يتم العثور على طلبات تحتوي على "${_searchQuery}"\nجرب البحث بكلمات مختلفة',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
          ).animate().fadeIn(delay: 500.ms),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _clearSearch,
            icon: const Icon(Icons.clear_rounded),
            label: const Text('مسح البحث'),
            style: AccountantThemeConfig.secondaryButtonStyle,
          ).animate().slideY(begin: 0.3, delay: 700.ms),
        ],
      ),
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
            'حدث خطأ في تحميل الطلبات',
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
            onPressed: _loadOrders,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
            style: AccountantThemeConfig.primaryButtonStyle,
          ).animate().slideY(begin: 0.3, delay: 700.ms),
        ],
      ),
    );
  }

  /// Modern empty state with AccountantThemeConfig styling
  Widget _buildEmptyState() {
    return Container(
      height: 500,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.greenGradient,
              shape: BoxShape.circle,
              boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
            ),
            child: const Icon(
              Icons.shopping_bag_outlined,
              size: 80,
              color: Colors.white,
            ),
          ).animate().scale(duration: 800.ms),
          const SizedBox(height: 32),
          Text(
            'لا توجد طلبات',
            style: AccountantThemeConfig.headlineMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ).animate().fadeIn(delay: 300.ms),
          const SizedBox(height: 16),
          Text(
            'لم تقم بإنشاء أي طلبات بعد\nابدأ بتصفح المنتجات وإضافة طلبك الأول',
            style: AccountantThemeConfig.bodyLarge.copyWith(
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 500.ms),
        ],
      ),
    );
  }

  /// Modern order card with professional styling and pricing approval awareness
  Widget _buildModernOrderCard(ClientOrder order, int index) {
    final statusColor = _getModernStatusColor(order.status);
    final bool shouldShowPrices = _shouldShowPricesForOrder(order);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AccountantThemeConfig.cardShadows,
        border: AccountantThemeConfig.glowBorder(statusColor),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showOrderDetails(order),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with order info and status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  gradient: AccountantThemeConfig.greenGradient,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '#${order.id.substring(0, 8).toUpperCase()}',
                                  style: AccountantThemeConfig.labelMedium.copyWith(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.access_time_rounded,
                                size: 16,
                                color: Colors.white70,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatDate(order.createdAt),
                                style: AccountantThemeConfig.bodySmall.copyWith(
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                          // Add voucher badge if this is a voucher order
                          const SizedBox(height: 8),
                          VoucherOrderDetailsWidget(
                            order: order,
                            isCompact: true,
                            showFullDetails: false,
                          ),
                        ],
                      ),
                    ),
                    _buildModernStatusChip(order.status),
                  ],
                ),

                const SizedBox(height: 16),

                // Order summary with enhanced styling
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'عدد المنتجات',
                            style: AccountantThemeConfig.bodySmall.copyWith(
                              color: Colors.white60,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.shopping_bag_outlined,
                                size: 16,
                                color: AccountantThemeConfig.primaryGreen,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${order.items.length} منتج',
                                style: AccountantThemeConfig.bodyMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'إجمالي المبلغ',
                            style: AccountantThemeConfig.bodySmall.copyWith(
                              color: Colors.white60,
                            ),
                          ),
                          const SizedBox(height: 4),
                          shouldShowPrices
                              ? Text(
                                  AccountantThemeConfig.formatCurrency(order.total),
                                  style: AccountantThemeConfig.headlineSmall.copyWith(
                                    color: AccountantThemeConfig.primaryGreen,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : _buildOrderCardPendingPrice(order),
                        ],
                      ),
                    ],
                  ),
                ),

                // Pricing status indicator for orders requiring pricing approval
                if (order.requiresPricingApproval && !shouldShowPrices) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AccountantThemeConfig.warningOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AccountantThemeConfig.warningOrange.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.pending_actions_rounded,
                          size: 16,
                          color: AccountantThemeConfig.warningOrange,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'في انتظار اعتماد التسعير من المحاسب',
                            style: AccountantThemeConfig.bodySmall.copyWith(
                              color: AccountantThemeConfig.warningOrange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Tracking links section
                if (order.trackingLinks.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.track_changes_rounded,
                              size: 16,
                              color: AccountantThemeConfig.primaryGreen,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'روابط المتابعة متاحة',
                              style: AccountantThemeConfig.bodyMedium.copyWith(
                                color: AccountantThemeConfig.primaryGreen,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Action buttons with modern styling
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showOrderDetails(order),
                        icon: const Icon(Icons.visibility_outlined, size: 18),
                        label: const Text('عرض التفاصيل'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AccountantThemeConfig.primaryGreen,
                          side: BorderSide(color: AccountantThemeConfig.primaryGreen),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    if (order.trackingLinks.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _openLatestTrackingLink(order.trackingLinks),
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          label: const Text('تتبع الطلب'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AccountantThemeConfig.primaryGreen,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: (index * 100).ms).slideY(begin: 0.3);
  }

  /// Get modern status color based on order status
  Color _getModernStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return AccountantThemeConfig.pendingColor;
      case OrderStatus.confirmed:
        return AccountantThemeConfig.accentBlue;
      case OrderStatus.processing:
        return Colors.purple;
      case OrderStatus.shipped:
        return Colors.teal;
      case OrderStatus.delivered:
        return AccountantThemeConfig.completedColor;
      case OrderStatus.cancelled:
        return AccountantThemeConfig.canceledColor;
    }
  }

  /// Modern status chip with enhanced styling
  Widget _buildModernStatusChip(OrderStatus status) {
    final statusColor = _getModernStatusColor(status);
    final statusText = _getStatusText(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [statusColor, statusColor.withValues(alpha: 0.8)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AccountantThemeConfig.glowShadows(statusColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getStatusIcon(status),
            size: 16,
            color: Colors.white,
          ),
          const SizedBox(width: 6),
          Text(
            statusText,
            style: AccountantThemeConfig.labelMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Get status icon for modern design
  IconData _getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Icons.pending_rounded;
      case OrderStatus.confirmed:
        return Icons.check_circle_rounded;
      case OrderStatus.processing:
        return Icons.settings_rounded;
      case OrderStatus.shipped:
        return Icons.local_shipping_rounded;
      case OrderStatus.delivered:
        return Icons.done_all_rounded;
      case OrderStatus.cancelled:
        return Icons.cancel_rounded;
    }
  }

  Widget _buildStatusChip(OrderStatus status, ThemeData theme) {
    Color backgroundColor;
    Color textColor;
    Color borderColor;

    switch (status) {
      case OrderStatus.pending:
        backgroundColor = Colors.orange.withOpacity(0.1);
        textColor = Colors.orange;
        borderColor = Colors.orange;
        break;
      case OrderStatus.confirmed:
        backgroundColor = Colors.blue.withOpacity(0.1);
        textColor = Colors.blue;
        borderColor = Colors.blue;
        break;
      case OrderStatus.processing:
        backgroundColor = Colors.purple.withOpacity(0.1);
        textColor = Colors.purple;
        borderColor = Colors.purple;
        break;
      case OrderStatus.shipped:
        backgroundColor = Colors.teal.withOpacity(0.1);
        textColor = Colors.teal;
        borderColor = Colors.teal;
        break;
      case OrderStatus.delivered:
        backgroundColor = Colors.green.withOpacity(0.1);
        textColor = Colors.green;
        borderColor = Colors.green;
        break;
      case OrderStatus.cancelled:
        backgroundColor = Colors.red.withOpacity(0.1);
        textColor = Colors.red;
        borderColor = Colors.red;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Text(
        _getStatusText(status),
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildTrackingLink(TrackingLink link, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _openTrackingLink(link.url),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.green.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.link,
                size: 16,
                color: Colors.green,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      link.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (link.description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        link.description,
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(link.createdAt),
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.open_in_new,
                size: 16,
                color: Colors.green,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'في انتظار التأكيد';
      case OrderStatus.confirmed:
        return 'تم التأكيد';
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showOrderDetails(ClientOrder order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _OrderDetailsSheet(order: order),
    );
  }

  Future<void> _openTrackingLink(String url) async {
    try {
      // Validate URL before parsing
      if (url.isEmpty || url == 'null' || url.trim().isEmpty) {
        throw 'رابط غير صالح';
      }

      // Ensure URL has a proper scheme
      String validUrl = url.trim();
      if (!validUrl.startsWith('http://') && !validUrl.startsWith('https://')) {
        validUrl = 'https://$validUrl';
      }

      final uri = Uri.parse(validUrl);

      // Additional validation for the URI
      if (uri.host.isEmpty) {
        throw 'رابط غير صالح - لا يحتوي على مضيف';
      }

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $validUrl';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('لا يمكن فتح الرابط: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _openLatestTrackingLink(List<TrackingLink> links) {
    if (links.isNotEmpty) {
      // ترتيب الروابط حسب التاريخ والحصول على الأحدث
      final sortedLinks = List<TrackingLink>.from(links);
      sortedLinks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _openTrackingLink(sortedLinks.first.url);
    }
  }

  /// Determines if prices should be shown for a specific order (for order cards)
  bool _shouldShowPricesForOrder(ClientOrder orderToCheck) {
    // Show prices if:
    // 1. Order doesn't require pricing approval, OR
    // 2. Pricing has been approved
    return !orderToCheck.requiresPricingApproval || orderToCheck.isPricingApproved;
  }

  /// Widget to show when order card total is pending approval
  Widget _buildOrderCardPendingPrice(ClientOrder order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Pending pricing indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AccountantThemeConfig.warningOrange.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: AccountantThemeConfig.warningOrange.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 12,
                color: AccountantThemeConfig.warningOrange,
              ),
              const SizedBox(width: 4),
              Text(
                'في انتظار التسعير',
                style: AccountantThemeConfig.labelSmall.copyWith(
                  color: AccountantThemeConfig.warningOrange,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Current total
        Text(
          '${order.total.toStringAsFixed(0)} ج.م',
          style: AccountantThemeConfig.headlineSmall.copyWith(
            color: AccountantThemeConfig.primaryGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _OrderDetailsSheet extends StatelessWidget {

  const _OrderDetailsSheet({required this.order});
  final ClientOrder order;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        gradient: AccountantThemeConfig.mainBackgroundGradient,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Modern handle
          Container(
            width: 50,
            height: 5,
            margin: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.greenGradient,
              borderRadius: BorderRadius.circular(3),
            ),
          ),

          // Modern header with SAMA branding
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              gradient: AccountantThemeConfig.cardGradient,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              boxShadow: AccountantThemeConfig.cardShadows,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تفاصيل الطلب',
                      style: AccountantThemeConfig.headlineMedium.copyWith(
                        foreground: Paint()
                          ..shader = AccountantThemeConfig.greenGradient.createShader(
                            const Rect.fromLTWH(0.0, 0.0, 200.0, 70.0),
                          ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '#${order.id.substring(0, 8).toUpperCase()}',
                      style: AccountantThemeConfig.bodyMedium.copyWith(
                        fontFamily: 'monospace',
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    iconSize: 24,
                  ),
                ),
              ],
            ),
          ),

          // Modern content with enhanced product display
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Order status and info card
                  _buildModernOrderInfoCard(),

                  const SizedBox(height: 20),

                  // Voucher order details (if applicable)
                  VoucherOrderDetailsWidget(
                    order: order,
                    showFullDetails: true,
                    isCompact: false,
                  ),

                  const SizedBox(height: 20),

                  // Products section with images
                  _buildModernProductsSection(),

                  const SizedBox(height: 20),

                  // Order summary card
                  _buildModernOrderSummaryCard(),

                  if (order.shippingAddress != null) ...[
                    const SizedBox(height: 20),
                    _buildModernShippingCard(),
                  ],

                  if (order.notes != null) ...[
                    const SizedBox(height: 20),
                    _buildModernNotesCard(),
                  ],

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Modern order info card with status and details
  Widget _buildModernOrderInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AccountantThemeConfig.cardShadows,
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
                  gradient: AccountantThemeConfig.greenGradient,
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
                      'معلومات الطلب',
                      style: AccountantThemeConfig.headlineSmall.copyWith(
                        color: AccountantThemeConfig.primaryGreen,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(order.createdAt),
                      style: AccountantThemeConfig.bodySmall.copyWith(
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('الحالة', order.statusText, Icons.info_outline_rounded),
          const SizedBox(height: 8),
          _buildInfoRow('حالة الدفع', order.paymentStatusText, Icons.payment_rounded),
          // Show pricing status if order requires pricing approval
          if (order.requiresPricingApproval) ...[
            const SizedBox(height: 8),
            _buildPricingStatusRow(),
          ],
        ],
      ),
    );
  }

  /// Modern products section with enhanced product cards and images
  Widget _buildModernProductsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
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
                  Icons.shopping_bag_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'المنتجات (${order.items.length})',
                style: AccountantThemeConfig.headlineSmall.copyWith(
                  color: AccountantThemeConfig.accentBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...order.items.map((item) => _buildModernProductCard(item)),
        ],
      ),
    );
  }

  /// Enhanced product card with image display (RTL layout)
  Widget _buildModernProductCard(OrderItem item) {
    // Check if prices should be visible based on pricing approval status
    final bool shouldShowPrices = _shouldShowPrices();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          // Product details (right side for RTL)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: AccountantThemeConfig.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'الكمية: ${item.quantity}',
                        style: AccountantThemeConfig.bodySmall.copyWith(
                          color: AccountantThemeConfig.primaryGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: shouldShowPrices
                          ? Text(
                              'السعر: ${AccountantThemeConfig.formatCurrency(item.price)}',
                              style: AccountantThemeConfig.bodyMedium.copyWith(
                                color: Colors.white70,
                              ),
                              overflow: TextOverflow.ellipsis,
                            )
                          : _buildPricePendingChip(item),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                shouldShowPrices
                    ? Text(
                        'المجموع: ${AccountantThemeConfig.formatCurrency(item.price * item.quantity)}',
                        style: AccountantThemeConfig.bodyLarge.copyWith(
                          color: AccountantThemeConfig.primaryGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : _buildSubtotalPendingMessage(),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Product image (left side for RTL)
          _buildProductImage(item),
        ],
      ),
    );
  }

  /// Product image with proper loading and error handling
  Widget _buildProductImage(OrderItem item) {
    // Try to get image URL from item (this would need to be implemented based on your data structure)
    final imageUrl = _getProductImageUrl(item);

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: imageUrl.isNotEmpty
            ? OptimizedImage(
                imageUrl: imageUrl,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                placeholder: Container(
                  decoration: BoxDecoration(
                    gradient: AccountantThemeConfig.cardGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
                errorWidget: _buildProductPlaceholder(),
              )
            : _buildProductPlaceholder(),
      ),
    );
  }

  /// Get product image URL from OrderItem
  String _getProductImageUrl(OrderItem item) {
    if (item.productImage.isNotEmpty) {
      final imageUrl = item.productImage;

      // If it's already a complete URL, return it
      if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
        return imageUrl;
      }

      // If it's a relative path, construct the full URL
      if (imageUrl.startsWith('/')) {
        return 'https://samastock.pythonanywhere.com$imageUrl';
      }

      // If it's just a filename, add the full path
      return 'https://samastock.pythonanywhere.com/static/uploads/$imageUrl';
    }

    return '';
  }

  /// Product image placeholder
  Widget _buildProductPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3),
            AccountantThemeConfig.primaryGreen.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Icon(
          Icons.inventory_2_rounded,
          color: Colors.white70,
          size: 32,
        ),
      ),
    );
  }

  /// Helper method to build info rows
  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: AccountantThemeConfig.primaryGreen,
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: AccountantThemeConfig.bodyMedium.copyWith(
            color: Colors.white70,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AccountantThemeConfig.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  /// Modern order summary card with pricing approval awareness
  Widget _buildModernOrderSummaryCard() {
    final bool shouldShowPrices = _shouldShowPrices();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AccountantThemeConfig.cardShadows,
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
                  gradient: AccountantThemeConfig.greenGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.calculate_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'ملخص الطلب',
                style: AccountantThemeConfig.headlineSmall.copyWith(
                  color: AccountantThemeConfig.primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: shouldShowPrices
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'إجمالي المبلغ',
                        style: AccountantThemeConfig.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        AccountantThemeConfig.formatCurrency(order.total),
                        style: AccountantThemeConfig.headlineMedium.copyWith(
                          color: AccountantThemeConfig.primaryGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )
                : _buildTotalPendingMessage(),
          ),
        ],
      ),
    );
  }

  /// Modern shipping address card
  Widget _buildModernShippingCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
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
                  Icons.location_on_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'عنوان الشحن',
                style: AccountantThemeConfig.headlineSmall.copyWith(
                  color: AccountantThemeConfig.accentBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              order.shippingAddress!,
              style: AccountantThemeConfig.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  /// Modern notes card
  Widget _buildModernNotesCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AccountantThemeConfig.cardShadows,
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.warningOrange),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: AccountantThemeConfig.orangeGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.note_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'ملاحظات',
                style: AccountantThemeConfig.headlineSmall.copyWith(
                  color: AccountantThemeConfig.warningOrange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              order.notes!,
              style: AccountantThemeConfig.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// Determines if prices should be shown based on pricing approval status (for detailed view)
  bool _shouldShowPrices() {
    // Show prices if:
    // 1. Order doesn't require pricing approval, OR
    // 2. Pricing has been approved
    return !order.requiresPricingApproval || order.isPricingApproved;
  }

  /// Widget to show when individual item price is pending approval
  Widget _buildPricePendingChip(OrderItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Pending pricing indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AccountantThemeConfig.warningOrange.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AccountantThemeConfig.warningOrange.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 14,
                color: AccountantThemeConfig.warningOrange,
              ),
              const SizedBox(width: 4),
              Text(
                'في انتظار التسعير',
                style: AccountantThemeConfig.bodySmall.copyWith(
                  color: AccountantThemeConfig.warningOrange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Current price
        Text(
          'السعر: ${AccountantThemeConfig.formatCurrency(item.price)}',
          style: AccountantThemeConfig.bodyMedium.copyWith(
            color: Colors.white70,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// Widget to show when item subtotal is pending approval
  Widget _buildSubtotalPendingMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AccountantThemeConfig.accentBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AccountantThemeConfig.accentBlue.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: AccountantThemeConfig.accentBlue,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'سيتم تحديد المجموع بعد اعتماد التسعير',
              style: AccountantThemeConfig.bodySmall.copyWith(
                color: AccountantThemeConfig.accentBlue,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Widget to show when total amount is pending approval
  Widget _buildTotalPendingMessage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.pending_actions_rounded,
              size: 20,
              color: AccountantThemeConfig.warningOrange,
            ),
            const SizedBox(width: 8),
            Text(
              'في انتظار اعتماد التسعير',
              style: AccountantThemeConfig.bodyLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: AccountantThemeConfig.warningOrange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AccountantThemeConfig.warningOrange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AccountantThemeConfig.warningOrange.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            'سيتم عرض الأسعار والمجموع النهائي بعد مراجعة واعتماد التسعير من قبل المحاسب',
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white70,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  /// Build pricing status row for order info card
  Widget _buildPricingStatusRow() {
    final IconData icon;
    final String statusText;
    final Color statusColor;

    if (order.isPricingApproved) {
      icon = Icons.check_circle_rounded;
      statusText = 'تم اعتماد التسعير';
      statusColor = AccountantThemeConfig.completedColor;
    } else if (order.isPricingRejected) {
      icon = Icons.cancel_rounded;
      statusText = 'تم رفض التسعير';
      statusColor = AccountantThemeConfig.canceledColor;
    } else {
      icon = Icons.schedule_rounded;
      statusText = 'في انتظار اعتماد التسعير';
      statusColor = AccountantThemeConfig.warningOrange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: statusColor,
          ),
          const SizedBox(width: 8),
          Text(
            'حالة التسعير',
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white70,
            ),
          ),
          const Spacer(),
          Text(
            statusText,
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: statusColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
