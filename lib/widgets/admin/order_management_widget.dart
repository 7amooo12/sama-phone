import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/models/order_model.dart';
import 'package:smartbiztracker_new/services/stockwarehouse_api.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:smartbiztracker_new/screens/admin/order_detail_screen.dart';
import 'package:smartbiztracker_new/widgets/common/advanced_search_bar.dart';
import 'package:smartbiztracker_new/utils/tab_optimization_service.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';
import 'package:smartbiztracker_new/widgets/accountant/modern_widgets.dart';

class OrderManagementWidget extends StatefulWidget { // 'admin', 'owner', 'worker', 'client'

  const OrderManagementWidget({
    super.key,
    this.onAddOrder,
    this.showHeader = true,
    this.isEmbedded = false,
    this.maxHeight,
    this.showStatusFilter = true,
    this.showDateFilter = true,
    this.showFilterOptions = true,
    this.showSearchBar = true,
    this.showStatusFilters = true,
    this.userRole = 'admin',
  });
  final VoidCallback? onAddOrder;
  final bool showHeader;
  final bool isEmbedded;
  final double? maxHeight;
  final bool showStatusFilter;
  final bool showDateFilter;
  final bool showFilterOptions;
  final bool showSearchBar;
  final bool showStatusFilters;
  final String userRole;

  @override
  State<OrderManagementWidget> createState() => _OrderManagementWidgetState();
}

class _OrderManagementWidgetState extends State<OrderManagementWidget> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String? _error;
  List<OrderModel> _allOrders = [];
  List<OrderModel> _filteredOrders = [];
  String? _selectedStatus;
  DateTime? _startDate;
  DateTime? _endDate;
  late TabController _tabController;
  final StockWarehouseApiService _stockWarehouseApi = StockWarehouseApiService();
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  // Track which tabs have been loaded to prevent blank screens
  final Map<int, bool> _tabsLoaded = {};

  // List of possible order statuses - updated to match API
  final List<String> _orderStatuses = [
    'الكل',
    'قيد المعالجة',
    'تحت التصنيع',
    'تم التجهيز',
    'تم التسليم',
    'تالف / هوالك'
  ];

  @override
  void initState() {
    super.initState();

    // Configure timeago for Arabic
    timeago.setLocaleMessages('ar', timeago.ArMessages());

    // Initialize tab controller with optimizations
    _tabController = TabController(length: _orderStatuses.length, vsync: this);

    // Apply memory optimizations
    _tabController = TabOptimizationService.enhanceTabController(_tabController);

    // Pre-initialize filtered orders to prevent white screen
    _filteredOrders = [];

    // Initialize tabs loaded state
    for (int i = 0; i < _orderStatuses.length; i++) {
      _tabsLoaded[i] = i == 0;
    }

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final tabIndex = _tabController.index;

        setState(() {
          _selectedStatus = tabIndex == 0 ? null : _orderStatuses[tabIndex];
          if (_tabsLoaded[tabIndex] != true) {
            _tabsLoaded[tabIndex] = true;
          }
          _filterOrders();
        });
      }
    });

    // Pre-fetch first tab's data
    _loadOrders();

    // Ensure UI is responsive
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Use cached data if available
      final cachedOrders = Provider.of<StockWarehouseApiService>(context, listen: false).cachedOrders;

      if (cachedOrders.isNotEmpty) {
        setState(() {
          _allOrders = cachedOrders.values.toList();
          _filterOrders();
          _isLoading = false;
        });

        // Load fresh data in background
        _stockWarehouseApi.getOrders().then((updatedOrders) {
          if (mounted) {
            setState(() {
              _allOrders = updatedOrders;
              _filterOrders();
            });
          }
        }).catchError((e) {
          debugPrint('Warning: Failed to update orders in background: $e');
        });
      } else {
        // Show loading state with empty list to prevent white screen
        setState(() {
          _isLoading = true;
          _filteredOrders = [];
        });

        final orders = await _stockWarehouseApi.getOrders();

        if (mounted) {
          setState(() {
            _allOrders = orders;
            _filterOrders();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
          _filteredOrders = [];
        });
      }
    }
  }

  // Filter orders based on search query, status, and date
  void _filterOrders() {
    // تطبيق فلتر البحث
    var filtered = _allOrders;

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((order) {
        final query = _searchQuery.toLowerCase();

        // البحث بالرقم أو اسم العميل أو الهاتف
        if (order.orderNumber.toLowerCase().contains(query) ||
            order.customerName.toLowerCase().contains(query) ||
            (order.customerPhone != null && order.customerPhone!.toLowerCase().contains(query))) {
          return true;
        }

        // البحث بالمنتجات
        if (order.items.isNotEmpty) {
          for (final item in order.items) {
            if (item.productName.toLowerCase().contains(query)) {
              return true;
            }
          }
        }

        // البحث بالعنوان
        if (order.shippingAddress != null &&
            order.shippingAddress!.toLowerCase().contains(query)) {
          return true;
        }

        return false;
      }).toList();
    }

    // تطبيق فلتر الحالة
    if (_selectedStatus != null && _selectedStatus != 'الكل') {
      filtered = filtered.where((order) => order.status == _selectedStatus).toList();
    }

    // تطبيق فلتر التاريخ
    if (_startDate != null) {
      filtered = filtered.where((order) => order.createdAt.isAfter(_startDate!)).toList();
    }

    if (_endDate != null) {
      // إضافة يوم واحد إلى تاريخ النهاية لتضمين اليوم كاملًا
      final nextDay = _endDate!.add(const Duration(days: 1));
      filtered = filtered.where((order) => order.createdAt.isBefore(nextDay)).toList();
    }

    setState(() {
      _filteredOrders = filtered;
    });
  }

  // Handle search changes
  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _filterOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Container(
        decoration: const BoxDecoration(
          gradient: AccountantThemeConfig.mainBackgroundGradient,
        ),
        child: Column(
          children: [
            if (widget.showHeader) _buildModernHeader(),
            if (widget.showSearchBar) _buildModernSearchBar(),
            if (widget.showStatusFilters) _buildModernStatusFilters(),
            // Use Expanded only when not embedded in another flex container
            // When isEmbedded is false, this widget is used standalone and needs Expanded
            // When isEmbedded is true, the parent container handles the flex behavior
            widget.isEmbedded
                ? _buildOrdersContent()
                : Expanded(child: _buildOrdersContent()),
          ],
        ),
      ),
    );
  }

  /// Build the main orders content (loading, error, empty, or list)
  Widget _buildOrdersContent() {
    return _isLoading && _filteredOrders.isEmpty
        ? ModernAccountantWidgets.buildModernLoader(
            message: 'جاري تحميل الطلبات...',
            color: AccountantThemeConfig.primaryGreen,
          )
        : _error != null
            ? ModernAccountantWidgets.buildEmptyState(
                icon: Icons.error_outline_rounded,
                title: 'حدث خطأ',
                subtitle: _error!,
                actionText: 'إعادة المحاولة',
                onActionPressed: _loadOrders,
              )
            : _filteredOrders.isEmpty
                ? ModernAccountantWidgets.buildEmptyState(
                    icon: Icons.shopping_cart_outlined,
                    title: 'لا توجد طلبات',
                    subtitle: 'لم يتم العثور على طلبات تطابق المعايير المحددة',
                  )
                : _buildModernOrdersList();
  }

  Widget _buildModernOrdersList() {
    return ListView.builder(
      padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
      itemCount: _filteredOrders.length,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        final order = _filteredOrders[index];
        return _buildSafeWidget(() => AnimatedContainer(
          duration: Duration(milliseconds: 800 + (index * 100)),
          curve: Curves.easeInOut,
          child: _buildModernOrderCard(order, index),
        ));
      },
    );
  }

  // Safe widget wrapper to prevent crashes
  Widget _buildSafeWidget(Widget Function() builder) {
    try {
      return builder();
    } catch (e) {
      debugPrint('⚠️ خطأ في بناء ويدجت الطلب: $e');
      return _buildErrorPlaceholder();
    }
  }

  // Error placeholder widget
  Widget _buildErrorPlaceholder() {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AccountantThemeConfig.dangerRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AccountantThemeConfig.dangerRed.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning,
            color: AccountantThemeConfig.dangerRed,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'تعذر تحميل هذا الطلب. يرجى المحاولة مرة أخرى.',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  // Modern Header
  Widget _buildModernHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.blueGradient,
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.shopping_cart_rounded,
              size: 28,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: AccountantThemeConfig.defaultPadding),
          Text(
            'إدارة الطلبات',
            style: AccountantThemeConfig.headlineMedium.copyWith(
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // Modern Search Bar
  Widget _buildModernSearchBar() {
    return Container(
      padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.1),
              Colors.white.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
          border: Border.all(color: AccountantThemeConfig.accentBlue.withOpacity(0.3)),
        ),
        child: TextField(
          controller: _searchController,
          style: AccountantThemeConfig.bodyMedium,
          decoration: InputDecoration(
            hintText: 'البحث في الطلبات...',
            hintStyle: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white.withOpacity(0.6),
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: AccountantThemeConfig.accentBlue,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear_rounded,
                      color: AccountantThemeConfig.neutralColor,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AccountantThemeConfig.defaultPadding,
              vertical: 14,
            ),
          ),
          onChanged: _onSearchChanged,
          onSubmitted: _onSearchChanged,
        ),
      ),
    );
  }

  // Modern Status Filters
  Widget _buildModernStatusFilters() {
    return Container(
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicator: BoxDecoration(
          gradient: AccountantThemeConfig.greenGradient,
          borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
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
        tabs: _orderStatuses.map((status) => Tab(
          text: status,
          icon: _getStatusIcon(status),
        )).toList(),
      ),
    );
  }

  // Modern Order Card with responsive design
  Widget _buildModernOrderCard(OrderModel order, int index) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isTablet = screenWidth > 768;
        final isLargePhone = screenWidth > 600;

        // Responsive sizing
        final cardPadding = isTablet ? AccountantThemeConfig.largePadding :
                           isLargePhone ? AccountantThemeConfig.defaultPadding :
                           AccountantThemeConfig.smallPadding;
        final borderRadius = isTablet ? AccountantThemeConfig.largeBorderRadius :
                            AccountantThemeConfig.defaultBorderRadius;
        final iconSize = isTablet ? 20.0 : isLargePhone ? 18.0 : 16.0;
        final spacing = isTablet ? AccountantThemeConfig.defaultPadding :
                       AccountantThemeConfig.smallPadding;

        return Container(
          margin: const EdgeInsets.only(bottom: AccountantThemeConfig.defaultPadding),
          decoration: BoxDecoration(
            gradient: AccountantThemeConfig.cardGradient,
            borderRadius: BorderRadius.circular(borderRadius),
            border: AccountantThemeConfig.glowBorder(_getStatusColor(order.status)),
            boxShadow: AccountantThemeConfig.glowShadows(_getStatusColor(order.status)),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(borderRadius),
            child: InkWell(
              onTap: () => _showOrderDetails(order),
              borderRadius: BorderRadius.circular(borderRadius),
              child: Padding(
                padding: EdgeInsets.all(cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                // Modern Header Row with responsive design
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'طلب #${order.orderNumber}',
                        style: isTablet ? AccountantThemeConfig.headlineSmall :
                               AccountantThemeConfig.headlineSmall.copyWith(fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: spacing / 2),
                    Flexible(
                      child: _buildResponsiveStatusChip(order.status, isTablet, isLargePhone),
                    ),
                  ],
                ),

                const SizedBox(height: AccountantThemeConfig.defaultPadding),

                // Customer Info
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AccountantThemeConfig.accentBlue.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.person_rounded,
                        size: 16,
                        color: AccountantThemeConfig.accentBlue,
                      ),
                    ),
                    const SizedBox(width: AccountantThemeConfig.smallPadding),
                    Expanded(
                      child: Text(
                        order.customerName,
                        style: AccountantThemeConfig.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AccountantThemeConfig.smallPadding),

                // Date and Total
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AccountantThemeConfig.neutralColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.calendar_today_rounded,
                        size: 16,
                        color: AccountantThemeConfig.neutralColor,
                      ),
                    ),
                    const SizedBox(width: AccountantThemeConfig.smallPadding),
                    Text(
                      _formatDate(order.createdAt),
                      style: AccountantThemeConfig.bodyMedium,
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AccountantThemeConfig.primaryGreen.withValues(alpha: 0.2),
                            AccountantThemeConfig.primaryGreen.withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        AccountantThemeConfig.formatCurrency(order.totalAmount),
                        style: AccountantThemeConfig.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AccountantThemeConfig.primaryGreen,
                        ),
                      ),
                    ),
                  ],
                ),

                // Items Count
                if (order.items.isNotEmpty) ...[
                  const SizedBox(height: AccountantThemeConfig.smallPadding),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AccountantThemeConfig.warningOrange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.inventory_2_rounded,
                          size: 16,
                          color: AccountantThemeConfig.warningOrange,
                        ),
                      ),
                      const SizedBox(width: AccountantThemeConfig.smallPadding),
                      Text(
                        '${order.items.length} منتج',
                        style: AccountantThemeConfig.bodyMedium.copyWith(
                          color: AccountantThemeConfig.warningOrange,
                        ),
                      ),
                    ],
                  ),
                ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Helper Methods
  Widget _getStatusIcon(String status) {
    switch (status) {
      case 'الكل':
        return const Icon(Icons.all_inclusive_rounded, size: 16);
      case 'قيد المعالجة':
        return const Icon(Icons.pending_actions_rounded, size: 16);
      case 'تحت التصنيع':
        return const Icon(Icons.build_rounded, size: 16);
      case 'تم التجهيز':
        return const Icon(Icons.check_circle_rounded, size: 16);
      case 'تم التسليم':
        return const Icon(Icons.local_shipping_rounded, size: 16);
      case 'تالف / هوالك':
        return const Icon(Icons.error_rounded, size: 16);
      default:
        return const Icon(Icons.help_rounded, size: 16);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'قيد المعالجة':
        return AccountantThemeConfig.pendingColor;
      case 'تحت التصنيع':
        return AccountantThemeConfig.accentBlue;
      case 'تم التجهيز':
        return AccountantThemeConfig.primaryGreen;
      case 'تم التسليم':
        return AccountantThemeConfig.completedColor;
      case 'تالف / هوالك':
        return AccountantThemeConfig.dangerRed;
      default:
        return AccountantThemeConfig.neutralColor;
    }
  }

  // Responsive status chip
  Widget _buildResponsiveStatusChip(String status, bool isTablet, bool isLargePhone) {
    final color = _getStatusColor(status);
    final fontSize = isTablet ? 12.0 : isLargePhone ? 11.0 : 10.0;
    final horizontalPadding = isTablet ? 12.0 : isLargePhone ? 10.0 : 8.0;
    final verticalPadding = isTablet ? 8.0 : isLargePhone ? 6.0 : 4.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.1)],
        ),
        borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        boxShadow: AccountantThemeConfig.glowShadows(color),
      ),
      child: Text(
        status,
        style: AccountantThemeConfig.labelMedium.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: fontSize,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'اليوم ${_dateFormat.add_Hm().format(date)}';
    } else if (difference.inDays == 1) {
      return 'أمس ${_dateFormat.add_Hm().format(date)}';
    } else if (difference.inDays < 7) {
      return 'منذ ${difference.inDays} أيام';
    } else {
      return _dateFormat.format(date);
    }
  }

  // Show order details
  void _showOrderDetails(OrderModel order) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => OrderDetailScreen(order: order),
      ),
    );
  }
}