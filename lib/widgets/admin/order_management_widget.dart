import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/models/order_model.dart';
import 'package:smartbiztracker_new/services/stockwarehouse_api.dart';
import 'package:smartbiztracker_new/widgets/common/elegant_search_bar.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:smartbiztracker_new/widgets/orders/shared_order_details_dialog.dart';
import 'package:smartbiztracker_new/widgets/common/advanced_search_bar.dart';
import 'package:smartbiztracker_new/utils/tab_optimization_service.dart';

class OrderManagementWidget extends StatefulWidget {
  final VoidCallback? onAddOrder;
  final bool showHeader;
  final bool isEmbedded;
  final double? maxHeight;
  final bool showStatusFilter;
  final bool showDateFilter;
  final bool showFilterOptions;
  final bool showSearchBar;
  final bool showStatusFilters;
  final String userRole; // 'admin', 'owner', 'worker', 'client'

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
  late final StockWarehouseApiService _stockWarehouseApi;
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  
  // Track which tabs have been loaded to prevent blank screens
  Map<int, bool> _tabsLoaded = {};
  
  // List of possible order statuses
  final List<String> _orderStatuses = [
    'الكل',
    'قيد الانتظار',
    'قيد التنفيذ',
    'تم التجهيز',
    'تم التسليم',
    'ملغي'
  ];

  @override
  void initState() {
    super.initState();

    // Configure timeago for Arabic
    timeago.setLocaleMessages('ar', timeago.ArMessages());

    // Get StockWarehouseApiService instance
    _stockWarehouseApi = Provider.of<StockWarehouseApiService>(context, listen: false);

    // Initialize tab controller for status filters with optimizations
    _tabController = TabOptimizationService.enhanceTabController(
      TabController(length: _orderStatuses.length, vsync: this)
    );
    
    // Apply memory optimizations
    TabOptimizationService.applyMemoryOptimizations();
    
    // Initialize tabs loaded state to ensure content always loads
    for (int i = 0; i < _orderStatuses.length; i++) {
      _tabsLoaded[i] = i == 0; // Mark only first tab as pre-loaded
    }
    
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final tabIndex = _tabController.index;
        
        // Update selected status
        setState(() {
          _selectedStatus = tabIndex == 0 ? null : _orderStatuses[tabIndex];
          
          // Mark this tab as loaded if it hasn't been loaded yet
          if (_tabsLoaded[tabIndex] != true) {
            _tabsLoaded[tabIndex] = true;
          }
          
          _filterOrders();
        });
      }
    });

    // Pre-fetch first tab's data immediately
    _loadOrders();
    
    // Add post-frame callback to ensure UI is responsive
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Pre-initialize widgets for first few tabs
      final initialWidgets = _orderStatuses.take(2).map((status) {
        return _buildTabContent(status);
      }).toList();
      TabOptimizationService.preInitializeWidgets(initialWidgets);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // Load orders from API with optimizations to prevent blank screens
  Future<void> _loadOrders() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final cachedOrders = _stockWarehouseApi.cachedOrders;
      
      if (cachedOrders != null && cachedOrders.isNotEmpty) {
        setState(() {
          _allOrders = cachedOrders.values.toList();
          _filterOrders();
          _isLoading = false;
        });
        
        try {
          final updatedOrders = await _stockWarehouseApi.getOrders();
          if (mounted) {
            setState(() {
              _allOrders = updatedOrders;
              _filterOrders();
            });
          }
        } catch (e) {
          debugPrint('تحذير: فشل تحديث الطلبات في الخلفية: $e');
        }
      } else {
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
        if (order.items != null && order.items.isNotEmpty) {
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
    final theme = Theme.of(context);

    Widget content = Column(
      children: [
        if (widget.showHeader)
          // Header with title
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.shopping_cart,
                  size: 32,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 16),
                Text(
                  'إدارة الطلبات',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),

        // Search bar
        if (widget.showSearchBar)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                AdvancedSearchBar(
                  controller: _searchController,
                  hintText: 'البحث في الطلبات...',
                  accentColor: theme.colorScheme.primary,
                  onChanged: _onSearchChanged,
                  onSubmitted: _onSearchChanged,
                  showSearchAnimation: true,
                ),
              ],
            ),
          ),

        // Status filter tabs (if enabled)
        if (widget.showStatusFilter && widget.showStatusFilters)
          Container(
            color: theme.colorScheme.surface,
            child: Column(
              children: [
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  indicatorColor: theme.colorScheme.primary,
                  labelColor: theme.colorScheme.primary,
                  unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.7),
                  tabs: _orderStatuses.map((status) => Tab(text: status)).toList(),
                ),
                // Use optimized TabBarView
                Expanded(
                  child: TabOptimizationService.optimizedTabBarView(
                    controller: _tabController,
                    children: _orderStatuses.map((status) => 
                      TabOptimizationService.optimizedTabContent(
                        child: _buildTabContent(status),
                        deferRendering: true,
                        deferDuration: const Duration(milliseconds: 100),
                        loadingPlaceholder: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'جاري تحميل $status...',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ).toList(),
                    keepAlive: true,
                    deferRendering: true,
                  ),
                ),
              ],
            ),
          ),

        // Date filter (if enabled)
        if (widget.showDateFilter && widget.showFilterOptions)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: _buildDatePickerButton(
                    label: 'من تاريخ',
                    date: _startDate,
                    onPressed: () => _selectDate(context, true),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDatePickerButton(
                    label: 'إلى تاريخ',
                    date: _endDate,
                    onPressed: () => _selectDate(context, false),
                  ),
                ),
                if (_startDate != null || _endDate != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: 'مسح التواريخ',
                    onPressed: () {
                      setState(() {
                        _startDate = null;
                        _endDate = null;
                        _filterOrders();
                      });
                    },
                  ),
              ],
            ),
          ),

        // Order statistics cards
        if (widget.showFilterOptions)
          SizedBox(
            height: 120,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildSummaryCard(
                  'إجمالي الطلبات',
                  '${_allOrders.length}',
                  Icons.shopping_cart,
                  theme.colorScheme.primary,
                ),
                _buildSummaryCard(
                  'قيد الانتظار',
                  '${_allOrders.where((o) => o.status == 'قيد الانتظار').length}',
                  Icons.pending_actions,
                  Colors.orange,
                ),
                _buildSummaryCard(
                  'قيد التنفيذ',
                  '${_allOrders.where((o) => o.status == 'قيد التنفيذ').length}',
                  Icons.hourglass_bottom,
                  Colors.blue,
                ),
                _buildSummaryCard(
                  'تم التسليم',
                  '${_allOrders.where((o) => o.status == 'تم التسليم').length}',
                  Icons.check_circle,
                  Colors.green,
                ),
                _buildSummaryCard(
                  'ملغي',
                  '${_allOrders.where((o) => o.status == 'ملغي').length}',
                  Icons.cancel,
                  Colors.red,
                ),
              ],
            ),
          ),

        // API connection info
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isLoading ? Icons.sync : Icons.cloud_done, 
                  color: _isLoading ? Colors.orange : theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isLoading 
                        ? 'جاري تحميل الطلبات...' 
                        : _error != null
                            ? 'حدث خطأ: $_error'
                            : 'تم تحميل ${_filteredOrders.length} طلب من أصل ${_allOrders.length}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _isLoading 
                          ? Colors.orange 
                          : _error != null 
                              ? Colors.red 
                              : theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (!_isLoading)
                  TextButton.icon(
                    onPressed: _loadOrders,
                    icon: Icon(
                      Icons.refresh,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    label: Text(
                      'تحديث',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 12,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                      minimumSize: const Size(0, 30),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Orders list
        Expanded(
          child: _isLoading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('جاري تحميل الطلبات...'),
                    ],
                  ),
                )
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 48,
                          ),
                          SizedBox(height: 16),
                          Text('حدث خطأ: $_error'),
                          SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadOrders,
                            child: const Text('إعادة المحاولة'),
                          ),
                        ],
                      ),
                    )
                  : _filteredOrders.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.shopping_cart_outlined,
                                size: 64,
                                color: theme.colorScheme.primary.withOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              const Text('لا توجد طلبات مطابقة للبحث'),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadOrders,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredOrders.length,
                            itemBuilder: (context, index) {
                              final order = _filteredOrders[index];
                              return _buildOrderCard(order, theme);
                            },
                          ),
                        ),
        ),
      ],
    );

    // If this is embedded in a parent widget, we might need to constrain its height
    if (widget.isEmbedded && widget.maxHeight != null) {
      content = SizedBox(
        height: widget.maxHeight,
        child: content,
      );
    }

    return content;
  }

  // Build date picker button
  Widget _buildDatePickerButton({
    required String label,
    required DateTime? date,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            date != null ? _dateFormat.format(date) : 'اختر التاريخ',
            style: TextStyle(
              fontWeight: date != null ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // Date picker function
  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final initialDate = isStartDate ? _startDate ?? DateTime.now() : _endDate ?? DateTime.now();
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          // If end date is before start date, update end date
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
          // If start date is after end date, update start date
          if (_startDate != null && _startDate!.isAfter(_endDate!)) {
            _startDate = _endDate;
          }
        }
        _filterOrders();
      });
    }
  }

  // Build summary card
  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: color,
            size: 28,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  // Build order card
  Widget _buildOrderCard(OrderModel order, ThemeData theme) {
    // Get color for order status
    final statusColor = _getStatusColor(order.status);
    
    // Format the order date
    final formattedDate = DateFormat('yyyy/MM/dd - HH:mm').format(order.createdAt);
    
    // Calculate relative time (e.g., "2 hours ago")
    final timeAgo = timeago.format(order.createdAt, locale: 'ar');
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: statusColor.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () async {
          // Show order details when tapped
          try {
            // Extract numeric part or use the order ID
            int orderId;
            try {
              // Try to extract numeric part from orderNumber
              final numericPart = order.orderNumber.replaceAll(RegExp(r'[^0-9]'), '');
              if (numericPart.isNotEmpty) {
                orderId = int.parse(numericPart);
              } else {
                // If no numeric part, try using the ID directly 
                orderId = int.parse(order.id);
              }
            } catch (e) {
              // If all parsing fails, use a fallback (the raw orderNumber might be the ID)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('جاري محاولة الحصول على تفاصيل الطلب بطريقة بديلة...')),
              );
              orderId = int.parse(order.id);
            }
            
            final orderDetails = await _stockWarehouseApi.getOrderDetail(orderId);
            if (!mounted) return;
            
            if (orderDetails != null) {
              // Use the shared dialog
              showDialog(
                context: context,
                builder: (context) => SharedOrderDetailsDialog(
                  order: orderDetails,
                  userRole: widget.userRole,
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('لا يمكن الحصول على تفاصيل الطلب')),
              );
            }
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('حدث خطأ: $e')),
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order header with number and status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.receipt, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'طلب #${order.orderNumber}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withOpacity(0.5)),
                    ),
                    child: Text(
                      order.status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              
              const Divider(height: 24),
              
              // Customer info
              Row(
                children: [
                  Icon(
                    Icons.person,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.customerName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (order.customerPhone != null && order.customerPhone!.isNotEmpty)
                    TextButton.icon(
                      onPressed: () {
                        // Implement phone call functionality
                      },
                      icon: const Icon(Icons.phone, size: 16),
                      label: Text(order.customerPhone!),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Order summary
              Row(
                children: [
                  // Order items count
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.shopping_basket,
                          size: 16,
                          color: theme.colorScheme.secondary,
                        ),
                        const SizedBox(width: 8),
                        Text('${order.items.length} منتج'),
                      ],
                    ),
                  ),
                  
                  // Order total amount
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.attach_money,
                          size: 16,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${order.totalAmount.toStringAsFixed(2)} جنيه',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              // Thumbnail preview of items with images
              if (order.items.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    ...order.items.take(3).map((item) {
                      if (item.imageUrl != null && item.imageUrl!.isNotEmpty) {
                        return Container(
                          width: 60,
                          height: 60,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: Image.network(
                              item.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.image_not_supported),
                                );
                              },
                            ),
                          ),
                        );
                      } else {
                        return Container(
                          width: 60,
                          height: 60,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              item.productName.substring(0, item.productName.length > 2 ? 2 : item.productName.length),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        );
                      }
                    }).toList(),
                    
                    if (order.items.length > 3)
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.colorScheme.primary.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '+${order.items.length - 3}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              
              const SizedBox(height: 12),
              
              // Order date and time
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formattedDate,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    timeAgo,
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
              
              // Action buttons (if not client view)
              if (widget.userRole != 'client')
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () async {
                          // Show order details for accountant or admin
                          try {
                            // Extract numeric part or use the order ID
                            int orderId;
                            try {
                              // Try to extract numeric part from orderNumber
                              final numericPart = order.orderNumber.replaceAll(RegExp(r'[^0-9]'), '');
                              if (numericPart.isNotEmpty) {
                                orderId = int.parse(numericPart);
                              } else {
                                // If no numeric part, try using the ID directly 
                                orderId = int.parse(order.id);
                              }
                            } catch (e) {
                              // If all parsing fails, use a fallback (the raw orderNumber might be the ID)
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('جاري محاولة الحصول على تفاصيل الطلب بطريقة بديلة...')),
                              );
                              orderId = int.parse(order.id);
                            }
                            
                            final orderDetails = await _stockWarehouseApi.getOrderDetail(orderId);
                            if (!mounted) return;
                            
                            if (orderDetails != null) {
                              // Use the shared dialog
                              showDialog(
                                context: context,
                                builder: (context) => SharedOrderDetailsDialog(
                                  order: orderDetails,
                                  userRole: widget.userRole,
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('لا يمكن الحصول على تفاصيل الطلب')),
                              );
                            }
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('حدث خطأ: $e')),
                            );
                          }
                        },
                        icon: const Icon(Icons.visibility, size: 16),
                        label: const Text('التفاصيل'),
                      ),
                      const SizedBox(width: 8),
                      if (widget.userRole == 'admin')
                        TextButton.icon(
                          onPressed: () {
                            // Implement update status action
                          },
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('تحديث الحالة'),
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
  
  // Print order details
  void _printOrderDetails(OrderModel order) {
    // هنا يمكن إضافة منطق لطباعة تفاصيل الطلب
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('جاري إرسال الطلب للطباعة...')),
    );
  }
  
  // Helper method to get color for order status
  Color _getStatusColor(String status) {
    switch (status) {
      case 'قيد الانتظار':
        return Colors.orange;
      case 'قيد التنفيذ':
        return Colors.blue;
      case 'تم التجهيز':
        return Colors.purple;
      case 'تم التسليم':
        return Colors.green;
      case 'ملغي':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Helper method to build tab content
  Widget _buildTabContent(String status) {
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(8),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildOrdersList(status),
      ),
    );
  }

  // Helper method to build orders list for a specific status
  Widget _buildOrdersList(String status) {
    final filteredByStatus = status == 'الكل'
        ? _filteredOrders
        : _filteredOrders.where((order) => order.status == status).toList();

    return ListView.builder(
      itemCount: filteredByStatus.length,
      itemBuilder: (context, index) => _buildOrderCard(filteredByStatus[index], Theme.of(context)),
    );
  }
} 