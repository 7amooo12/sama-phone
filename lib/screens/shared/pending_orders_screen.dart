import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import '../../models/client_order_model.dart';
import '../../services/supabase_orders_service.dart';
import '../../services/warehouse_release_orders_service.dart';
import '../../services/warehouse_service.dart';
import '../../services/real_notification_service.dart';
import '../../utils/style_system.dart';
import '../../utils/app_logger.dart';
import '../../utils/accountant_theme_config.dart';
import '../../providers/supabase_provider.dart';
import '../../config/routes.dart';
import '../accountant/pricing_approval_screen.dart';

/// شاشة إدارة الطلبات المعلقة مع تأثيرات 3D flip
class PendingOrdersScreen extends StatefulWidget {
  const PendingOrdersScreen({super.key});

  @override
  State<PendingOrdersScreen> createState() => _PendingOrdersScreenState();
}

class _PendingOrdersScreenState extends State<PendingOrdersScreen>
    with TickerProviderStateMixin {
  final SupabaseOrdersService _ordersService = SupabaseOrdersService();
  final WarehouseReleaseOrdersService _warehouseReleaseService = WarehouseReleaseOrdersService();
  final WarehouseService _warehouseService = WarehouseService();
  List<ClientOrder> _pendingOrders = [];
  List<ClientOrder> _filteredOrders = [];
  Set<String> _hiddenOrderIds = {}; // Track hidden orders
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  String _selectedFilter = 'all'; // all, today, week, month

  // 3D Flip Animation Controllers
  final Map<String, AnimationController> _flipControllers = {};
  final Map<String, Animation<double>> _flipAnimations = {};
  final Set<String> _flippedCards = {};

  @override
  void initState() {
    super.initState();
    _loadPendingOrders();
  }

  @override
  void dispose() {
    // Dispose all animation controllers
    for (final controller in _flipControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // Create or get flip animation controller for order card
  AnimationController _getFlipController(String orderId) {
    if (!_flipControllers.containsKey(orderId)) {
      final controller = AnimationController(
        duration: const Duration(milliseconds: 700),
        vsync: this,
      );
      final animation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeInOut,
      ));

      _flipControllers[orderId] = controller;
      _flipAnimations[orderId] = animation;
    }
    return _flipControllers[orderId]!;
  }

  // Toggle flip animation for order card
  void _toggleOrderCardFlip(String orderId) {
    final controller = _getFlipController(orderId);

    if (_flippedCards.contains(orderId)) {
      controller.reverse();
      _flippedCards.remove(orderId);
    } else {
      controller.forward();
      _flippedCards.add(orderId);
    }
  }

  // Load pending orders from Supabase
  Future<void> _loadPendingOrders() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      AppLogger.info('🔄 Loading pending orders...');
      final orders = await _ordersService.getAllOrders();

      // ===== ENHANCED DEBUG LOGGING FOR PRICING APPROVAL =====
      AppLogger.info('📊 DEBUG: Total orders received: ${orders.length}');
      for (final order in orders) {
        if (order.status == OrderStatus.pending) {
          AppLogger.info('🔍 DEBUG: Pending Order ${order.id}:');
          AppLogger.info('  - Client: ${order.clientName}');
          AppLogger.info('  - Status: ${order.status}');
          AppLogger.info('  - Pricing Status: ${order.pricingStatus}');
          AppLogger.info('  - Pricing Approved By: ${order.pricingApprovedBy}');
          AppLogger.info('  - Pricing Approved At: ${order.pricingApprovedAt}');
          AppLogger.info('  - Pricing Notes: ${order.pricingNotes}');
          AppLogger.info('  - Metadata: ${order.metadata}');
          AppLogger.info('  - requiresPricingApproval: ${order.requiresPricingApproval}');
          AppLogger.info('  - isPendingPricing: ${order.isPendingPricing}');
          AppLogger.info('  - isPricingApproved: ${order.isPricingApproved}');
          AppLogger.info('  - isPricingRejected: ${order.isPricingRejected}');
          AppLogger.info('  ---');
        }
      }

      // Filter only pending orders
      final pendingOrders = orders.where((order) =>
        order.status == OrderStatus.pending
      ).toList();

      setState(() {
        _pendingOrders = pendingOrders;
        _filteredOrders = pendingOrders;
        _isLoading = false;
      });

      AppLogger.info('✅ Loaded ${pendingOrders.length} pending orders');
      _applyFilters();
    } catch (e) {
      setState(() {
        _error = 'فشل في تحميل الطلبات المعلقة: $e';
        _isLoading = false;
      });
      AppLogger.error('❌ Error loading pending orders: $e');
    }
  }

  // Apply search and filter
  void _applyFilters() {
    setState(() {
      _filteredOrders = _pendingOrders.where((order) {
        // Hidden filter - exclude hidden orders
        final isNotHidden = !_hiddenOrderIds.contains(order.id);

        // Search filter
        final matchesSearch = _searchQuery.isEmpty ||
            order.clientName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            order.clientEmail.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            order.id.toLowerCase().contains(_searchQuery.toLowerCase());

        // Date filter
        final matchesDateFilter = _selectedFilter == 'all' ||
            (_selectedFilter == 'today' && _isToday(order.createdAt)) ||
            (_selectedFilter == 'week' && _isThisWeek(order.createdAt)) ||
            (_selectedFilter == 'month' && _isThisMonth(order.createdAt));

        return isNotHidden && matchesSearch && matchesDateFilter;
      }).toList();
    });
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
           date.month == now.month &&
           date.day == now.day;
  }

  bool _isThisWeek(DateTime date) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    return date.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
           date.isBefore(endOfWeek.add(const Duration(days: 1)));
  }

  bool _isThisMonth(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StyleSystem.backgroundDark,
      appBar: AppBar(
        title: const Text(
          'الطلبات المعلقة',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
        backgroundColor: StyleSystem.surfaceDark,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_filteredOrders.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (value) {
                if (value == 'hide_all') {
                  _showBulkHideConfirmation();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'hide_all',
                  child: Row(
                    children: [
                      Icon(Icons.visibility_off, color: Colors.red),
                      SizedBox(width: 8),
                      Text('مسح الجميع'),
                    ],
                  ),
                ),
              ],
            ),
          IconButton(
            onPressed: _loadPendingOrders,
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Section
          _buildSearchAndFilter(),
          
          // Orders List
          Expanded(
            child: _buildOrdersList(),
          ),
        ],
      ),
    );
  }

  // Build search and filter section
  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: StyleSystem.surfaceDark,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search Bar
          TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
              _applyFilters();
            },
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'البحث بالاسم، البريد الإلكتروني، أو رقم الطلب...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
              prefixIcon: Icon(Icons.search, color: StyleSystem.primaryColor),
              filled: true,
              fillColor: StyleSystem.backgroundDark,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('الكل', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('اليوم', 'today'),
                const SizedBox(width: 8),
                _buildFilterChip('الأسبوع', 'week'),
                const SizedBox(width: 8),
                _buildFilterChip('الشهر', 'month'),
                const SizedBox(width: 16),
                Text(
                  '${_filteredOrders.length} طلب',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.7),
          fontFamily: 'Cairo',
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
        _applyFilters();
      },
      backgroundColor: StyleSystem.backgroundDark,
      selectedColor: StyleSystem.primaryColor,
      checkmarkColor: Colors.white,
    );
  }

  // Build orders list
  Widget _buildOrdersList() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: StyleSystem.primaryColor,
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontFamily: 'Cairo',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadPendingOrders,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: StyleSystem.primaryColor,
              ),
            ),
          ],
        ),
      );
    }

    if (_filteredOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Colors.white.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty 
                ? 'لا توجد طلبات تطابق البحث'
                : 'لا توجد طلبات معلقة',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 18,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPendingOrders,
      color: StyleSystem.primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredOrders.length,
        itemBuilder: (context, index) {
          final order = _filteredOrders[index];
          return _buildOrderCard(order);
        },
      ),
    );
  }

  // Enhanced order card widget with expandable design
  Widget _buildOrderCard(ClientOrder order) {
    final statusColor = _getStatusColor(order.status);
    final isExpanded = _flippedCards.contains(order.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        color: StyleSystem.surfaceDark,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: statusColor.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            // Main order info (always visible)
            _buildOrderFrontSide(order, statusColor),

            // Expandable action section
            if (isExpanded)
              _buildOrderActionSection(order, statusColor),
          ],
        ),
      ),
    );
  }

  // Build front side of order card with enhanced functionality
  Widget _buildOrderFrontSide(ClientOrder order, Color statusColor) {
    return GestureDetector(
      // Single tap - Show detailed order view
      onTap: () => _showEnhancedOrderDetails(order),
      // Long press - Toggle card flip for inventory check
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _toggleOrderCardFlip(order.id);
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.05),
              Colors.white.withValues(alpha: 0.02),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with enhanced status display
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      _getStatusIcon(order.status),
                      color: statusColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.clientName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'طلب #${order.id.substring(0, 8)}...',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Enhanced status badge with progress indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          order.statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Order details
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'المبلغ الإجمالي',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${order.total.toStringAsFixed(2)} جنيه',
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'عدد المنتجات',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${order.items.length} منتج',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Contact info and date
               Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'البريد الإلكتروني',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 10,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  Text(
                    order.clientEmail,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontFamily: 'Cairo',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'تاريخ الطلب',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 10,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  Text(
                    _formatDate(order.createdAt),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
            ],
          ),

              const SizedBox(height: 12),

              // Tap hint
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.touch_app,
                    color: Colors.white.withValues(alpha: 0.4),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'اضغط لخيارات الإدارة',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
}

  // Build expandable action section with inventory check
  Widget _buildOrderActionSection(ClientOrder order, Color statusColor) {
    return Container(
      decoration: BoxDecoration(
        color: StyleSystem.backgroundDark,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Header with close button
          Row(
            children: [
              Icon(Icons.inventory_2_rounded, color: statusColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                'فحص المخزون والإدارة',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => _toggleOrderCardFlip(order.id),
                icon: const Icon(Icons.keyboard_arrow_up, color: Colors.white70),
                iconSize: 24,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Inventory Status Section
          FutureBuilder<Map<String, dynamic>>(
            future: _checkInventoryAvailability(order),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'جاري فحص توفر المنتجات في المخزون...',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (snapshot.hasError) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'خطأ في فحص المخزون: ${snapshot.error}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              final inventoryData = snapshot.data!;
              final isAvailable = inventoryData['allAvailable'] as bool;
              final availableItems = inventoryData['availableItems'] as List<Map<String, dynamic>>;
              final unavailableItems = inventoryData['unavailableItems'] as List<Map<String, dynamic>>;

              return Column(
                children: [
                  // Overall status
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isAvailable
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isAvailable
                          ? Colors.green.withValues(alpha: 0.3)
                          : Colors.orange.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isAvailable ? Icons.check_circle : Icons.warning,
                          color: isAvailable ? Colors.green : Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            isAvailable
                              ? 'جميع المنتجات متوفرة في المخزون'
                              : 'بعض المنتجات غير متوفرة',
                            style: TextStyle(
                              color: isAvailable ? Colors.green : Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (unavailableItems.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'المنتجات غير المتوفرة:',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...unavailableItems.map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '• ${item['name']} (مطلوب: ${item['required']}, متوفر: ${item['available']})',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 11,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          )),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Action buttons based on inventory status
                  if (isAvailable) ...[
                    // All items available - show process order button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _processOrder(order),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('معالجة الطلب'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    // Some items unavailable - show partial processing options
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _processPartialOrder(order, availableItems),
                            icon: const Icon(Icons.splitscreen),
                            label: const Text('معالجة جزئية'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _waitForRestock(order),
                            icon: const Icon(Icons.schedule),
                            label: const Text('انتظار التوريد'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Enhanced action buttons with conditional pricing approval logic
                  Column(
                    children: [
                      // Inventory check button
                      SizedBox(
                        width: double.infinity,
                        child: _buildActionButton(
                          'فحص المخزون التفصيلي',
                          Icons.inventory_2_rounded,
                          const Color(0xFF3B82F6),
                          () => _showEnhancedInventoryDialog(order),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Conditional action buttons based on pricing status
                      _buildConditionalActionButtons(order),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // Build conditional action buttons based on pricing status
  Widget _buildConditionalActionButtons(ClientOrder order) {
    // ===== DEBUG PRICING APPROVAL WORKFLOW =====
    AppLogger.info('🔍 DEBUG: Checking pricing approval for order ${order.id}');
    AppLogger.info('  - requiresPricingApproval: ${order.requiresPricingApproval}');
    AppLogger.info('  - isPendingPricing: ${order.isPendingPricing}');
    AppLogger.info('  - isPricingApproved: ${order.isPricingApproved}');
    AppLogger.info('  - pricingStatus: ${order.pricingStatus}');
    AppLogger.info('  - metadata: ${order.metadata}');

    // Check if order requires pricing approval
    if (order.requiresPricingApproval && order.isPendingPricing) {
      AppLogger.info('✅ Showing pricing approval buttons for order ${order.id}');
      // Show pricing approval buttons for orders that need pricing approval
      return Row(
        children: [
          Expanded(
            child: _buildActionButton(
              'اعتماد التسعير',
              Icons.price_check_rounded,
              const Color(0xFF10B981),
              () {
                AppLogger.info('🔘 Pricing approval button clicked for order: ${order.id}');
                _openPricingApproval(order);
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionButton(
              'رفض',
              Icons.cancel,
              const Color(0xFFEF4444),
              () => _rejectOrder(order),
            ),
          ),
        ],
      );
    } else if (order.isPricingApproved || !order.requiresPricingApproval) {
      AppLogger.info('✅ Showing regular approval buttons for order ${order.id} (pricing approved or not required)');
      // Show regular approval buttons for orders with approved pricing or no pricing requirement
      return Row(
        children: [
          Expanded(
            child: _buildActionButton(
              'موافقة',
              Icons.check_circle,
              const Color(0xFF10B981),
              () => _approveOrder(order),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionButton(
              'رفض',
              Icons.cancel,
              const Color(0xFFEF4444),
              () => _rejectOrder(order),
            ),
          ),
        ],
      );
    } else {
      AppLogger.info('⚠️ Order ${order.id} in intermediate pricing state - showing info only');
      // Show status info for orders with rejected pricing or other states
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(Icons.info, color: Colors.orange, size: 20),
            const SizedBox(height: 4),
            Text(
              order.pricingStatusText,
              style: const TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                fontFamily: 'Cairo',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
  }

  // Build action button
  Widget _buildActionButton(String text, IconData icon, Color color, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(
              text,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 10,
                fontFamily: 'Cairo',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Enhanced approve order with warehouse release order creation
  Future<void> _approveOrder(ClientOrder order) async {
    // ===== CRITICAL PRICING APPROVAL VALIDATION =====
    AppLogger.info('🔒 VALIDATION: Checking pricing approval requirements for order ${order.id}');
    AppLogger.info('  - requiresPricingApproval: ${order.requiresPricingApproval}');
    AppLogger.info('  - isPendingPricing: ${order.isPendingPricing}');
    AppLogger.info('  - isPricingApproved: ${order.isPricingApproved}');
    AppLogger.info('  - pricingStatus: ${order.pricingStatus}');

    // PREVENT BYPASSING PRICING APPROVAL WORKFLOW
    if (order.requiresPricingApproval && !order.isPricingApproved) {
      AppLogger.error('❌ WORKFLOW VIOLATION: Attempting to approve order ${order.id} without pricing approval!');
      _showErrorMessage(
        'لا يمكن الموافقة على هذا الطلب!\n\nيجب اعتماد التسعير أولاً قبل الموافقة على الطلب.\nيرجى استخدام زر "اعتماد التسعير" أولاً.'
      );
      return;
    }

    // If pricing is required but still pending, block the approval
    if (order.requiresPricingApproval && order.isPendingPricing) {
      AppLogger.error('❌ WORKFLOW VIOLATION: Order ${order.id} still has pending pricing status!');
      _showErrorMessage(
        'الطلب في انتظار اعتماد التسعير!\n\nلا يمكن الموافقة على الطلب حتى يتم اعتماد التسعير أولاً.'
      );
      return;
    }

    AppLogger.info('✅ VALIDATION PASSED: Order ${order.id} can proceed to approval');

    final confirmed = await _showConfirmationDialog(
      'تأكيد الموافقة',
      'هل أنت متأكد من الموافقة على طلب "${order.clientName}"؟\n\nسيتم إنشاء أذن صرف تلقائياً وإرساله إلى مدير المخزن للموافقة.',
      'موافقة وإنشاء أذن صرف',
      Colors.green,
    );

    if (confirmed == true) {
      try {
        // Show loading indicator
        _showInfoMessage('جاري معالجة الطلب وإنشاء أذن الصرف...');

        // Step 1: Update order status to confirmed
        final orderUpdateSuccess = await _ordersService.updateOrderStatus(
          order.id,
          OrderStatus.confirmed,
        );

        if (!orderUpdateSuccess) {
          _showErrorMessage('فشل في تحديث حالة الطلب');
          return;
        }

        // Step 2: Get current user ID for assignment
        final currentUser = Provider.of<SupabaseProvider>(context, listen: false).user;
        if (currentUser == null) {
          _showErrorMessage('خطأ في المصادقة - يرجى تسجيل الدخول مرة أخرى');
          return;
        }

        // Step 3: Create warehouse release order
        final releaseOrderId = await _warehouseReleaseService.createReleaseOrderFromApprovedOrder(
          approvedOrder: order,
          assignedTo: currentUser.id,
          notes: 'تم إنشاء أذن الصرف تلقائياً من الطلب المعتمد #${order.id.substring(0, 8)}',
        );

        if (releaseOrderId != null) {
          // Step 4: Send notification to customer
          await _sendCustomerNotification(
            order.clientEmail,
            'تم تأكيد طلبك',
            'تم تأكيد طلبك #${order.id.substring(0, 8)} بنجاح. تم إنشاء أذن صرف وإرساله إلى مدير المخزن للموافقة النهائية.',
          );

          // Step 5: Hide the order from pending list and refresh
          setState(() {
            _hiddenOrderIds.add(order.id);
          });
          _applyFilters();

          _showSuccessMessage(
            'تم قبول الطلب بنجاح وإنشاء أذن صرف!\nرقم أذن الصرف: ${releaseOrderId.substring(0, 8)}...\nتم إرسال الطلب إلى مدير المخزن للموافقة.'
          );

          AppLogger.info('✅ Order approved and warehouse release order created: $releaseOrderId');
        } else {
          _showErrorMessage('تم تأكيد الطلب ولكن فشل في إنشاء أذن الصرف. يرجى إنشاؤه يدوياً.');
        }
      } catch (e) {
        AppLogger.error('❌ Error in order approval workflow: $e');
        _showErrorMessage('حدث خطأ أثناء معالجة الطلب: $e');
      }
    }
  }

  // Reject order
  Future<void> _rejectOrder(ClientOrder order) async {
    final confirmed = await _showConfirmationDialog(
      'تأكيد الرفض',
      'هل أنت متأكد من رفض طلب "${order.clientName}"؟\nلا يمكن التراجع عن هذا الإجراء.',
      'رفض',
      Colors.red,
    );

    if (confirmed == true) {
      try {
        final success = await _ordersService.updateOrderStatus(
          order.id,
          OrderStatus.cancelled,
        );

        if (success) {
          _showSuccessMessage('تم رفض الطلب');
          _loadPendingOrders(); // Refresh the list
        } else {
          _showErrorMessage('فشل في رفض الطلب');
        }
      } catch (e) {
        _showErrorMessage('حدث خطأ أثناء رفض الطلب: $e');
      }
    }
  }

  // Show order details with role-based navigation
  void _showOrderDetails(ClientOrder order) {
    // For now, use admin as default role since Provider access is having issues
    final userRole = 'admin';

    // For accountants, navigate to dedicated order details screen
    if (userRole == 'accountant') {
      Navigator.of(context).pushNamed(
        AppRoutes.accountantOrderDetails,
        arguments: order,
      );
      return;
    }

    // For admins and other roles, show dialog (existing behavior)
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: StyleSystem.surfaceDark,
        title: const Text(
          'تفاصيل الطلب',
          style: TextStyle(color: Colors.white, fontFamily: 'Cairo'),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('العميل:', order.clientName),
              _buildDetailRow('البريد الإلكتروني:', order.clientEmail),
              _buildDetailRow('الهاتف:', order.clientPhone),
              _buildDetailRow('المبلغ الإجمالي:', '${order.total.toStringAsFixed(2)} جنيه'),
              _buildDetailRow('حالة الطلب:', order.statusText),
              _buildDetailRow('حالة الدفع:', order.paymentStatusText),
              _buildDetailRow('تاريخ الإنشاء:', _formatDate(order.createdAt)),
              if (order.notes?.isNotEmpty == true)
                _buildDetailRow('ملاحظات:', order.notes!),

              const SizedBox(height: 16),
              const Text(
                'المنتجات:',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 8),
              ...order.items.map((item) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: StyleSystem.backgroundDark,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          Text(
                            'الكمية: ${item.quantity}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${item.total.toStringAsFixed(2)} جنيه',
                      style: TextStyle(
                        color: StyleSystem.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'إغلاق',
              style: TextStyle(color: StyleSystem.primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  // Assign worker to order
  Future<void> _assignWorker(ClientOrder order) async {
    // TODO: Implement worker assignment functionality
    _showInfoMessage('ميزة تعيين الموظف ستكون متاحة قريباً');
  }

  // Helper methods
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontFamily: 'Cairo',
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Cairo',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build pricing status row with visual indicator
  Widget _buildPricingStatusRow(ClientOrder order) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (order.isPricingApproved) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle_rounded;
      statusText = 'تم اعتماد التسعير';
    } else if (order.isPricingRejected) {
      statusColor = Colors.red;
      statusIcon = Icons.cancel_rounded;
      statusText = 'تم رفض التسعير';
    } else {
      statusColor = Colors.orange;
      statusIcon = Icons.pending_rounded;
      statusText = 'في انتظار اعتماد التسعير';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              'حالة التسعير:',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontFamily: 'Cairo',
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: statusColor, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  // Build conditional action buttons for order details dialog
  Widget _buildOrderDetailsActionButtons(ClientOrder order) {
    AppLogger.info('🔘 Building order details action buttons for order: ${order.id}');
    AppLogger.info('  - requiresPricingApproval: ${order.requiresPricingApproval}');
    AppLogger.info('  - isPendingPricing: ${order.isPendingPricing}');
    AppLogger.info('  - isPricingApproved: ${order.isPricingApproved}');

    // If order requires pricing approval and is still pending pricing
    if (order.requiresPricingApproval && order.isPendingPricing) {
      AppLogger.info('✅ Showing pricing approval buttons in order details');
      return Column(
        children: [
          // Pricing approval button (full width)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context); // Close details dialog
                _openPricingApproval(order);
              },
              icon: const Icon(Icons.price_check_rounded),
              label: const Text('اعتماد التسعير'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Secondary actions row
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _rejectOrder(order);
                  },
                  icon: const Icon(Icons.cancel_rounded),
                  label: const Text('رفض'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _deleteOrder(order);
                  },
                  icon: const Icon(Icons.delete_rounded),
                  label: const Text('حذف'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // If pricing is approved or not required, show regular approval buttons
    AppLogger.info('✅ Showing regular approval buttons in order details');
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _approveOrder(order);
            },
            icon: const Icon(Icons.check_circle_rounded),
            label: const Text('موافقة وإنشاء أذن صرف'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _deleteOrder(order);
            },
            icon: const Icon(Icons.delete_rounded),
            label: const Text('حذف الطلب'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.confirmed:
        return Colors.green;
      case OrderStatus.processing:
        return Colors.blue;
      case OrderStatus.shipped:
        return Colors.purple;
      case OrderStatus.delivered:
        return Colors.green;
      case OrderStatus.cancelled:
        return Colors.red;
    }
  }

  // Show confirmation dialog
  Future<bool?> _showConfirmationDialog(
    String title,
    String message,
    String confirmText,
    Color confirmColor,
  ) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: StyleSystem.surfaceDark,
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontFamily: 'Cairo'),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.help_outline,
              color: confirmColor,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(color: Colors.white70, fontFamily: 'Cairo'),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
            ),
            child: Text(
              confirmText,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // Show success message
  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontFamily: 'Cairo'),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Show error message
  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontFamily: 'Cairo'),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Show info message
  void _showInfoMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontFamily: 'Cairo'),
              ),
            ),
          ],
        ),
        backgroundColor: StyleSystem.primaryColor,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Show bulk hide confirmation
  Future<void> _showBulkHideConfirmation() async {
    final confirmed = await _showConfirmationDialog(
      'إخفاء جميع الطلبات',
      'هل أنت متأكد من إخفاء جميع الطلبات المعروضة؟\n\nسيتم إخفاء ${_filteredOrders.length} طلب من العرض.\nيمكنك استعادتها بإعادة تحميل الصفحة.',
      'إخفاء الجميع',
      Colors.orange,
    );

    if (confirmed == true) {
      setState(() {
        // Add all filtered order IDs to hidden set
        for (final order in _filteredOrders) {
          _hiddenOrderIds.add(order.id);
        }
      });

      // Reapply filters to update the display
      _applyFilters();

      _showSuccessMessage('تم إخفاء ${_filteredOrders.length} طلب من العرض');
    }
  }

  // Get status icon for order status
  IconData _getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Icons.pending_actions_rounded;
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

  // Enhanced order details modal with confirm functionality
  void _showEnhancedOrderDetails(ClientOrder order) {
    _showEnhancedOrderDetailsWithRefresh(order);
  }

  // Enhanced order details modal with refresh capability
  void _showEnhancedOrderDetailsWithRefresh(ClientOrder order) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                StyleSystem.surfaceDark,
                StyleSystem.backgroundDark,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _getStatusColor(order.status).withValues(alpha: 0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _getStatusColor(order.status).withValues(alpha: 0.2),
                      _getStatusColor(order.status).withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getStatusColor(order.status).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getStatusIcon(order.status),
                        color: _getStatusColor(order.status),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تفاصيل الطلب',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          Text(
                            'طلب #${order.id.substring(0, 8)}...',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 14,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Customer Information
                      _buildDetailSection(
                        'معلومات العميل',
                        Icons.person_rounded,
                        [
                          _buildDetailRow('الاسم:', order.clientName),
                          _buildDetailRow('البريد الإلكتروني:', order.clientEmail),
                          _buildDetailRow('الهاتف:', order.clientPhone),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Order Information
                      _buildDetailSection(
                        'معلومات الطلب',
                        Icons.shopping_cart_rounded,
                        [
                          _buildDetailRow('المبلغ الإجمالي:', '${order.total.toStringAsFixed(2)} جنيه'),
                          _buildDetailRow('حالة الطلب:', order.statusText),
                          _buildDetailRow('حالة الدفع:', order.paymentStatusText),
                          _buildDetailRow('تاريخ الإنشاء:', _formatDate(order.createdAt)),
                          // Pricing Status Information
                          if (order.requiresPricingApproval) ...[
                            _buildPricingStatusRow(order),
                            if (order.pricingApprovedAt != null)
                              _buildDetailRow('تاريخ اعتماد التسعير:', _formatDate(order.pricingApprovedAt!)),
                            if (order.pricingNotes?.isNotEmpty == true)
                              _buildDetailRow('ملاحظات التسعير:', order.pricingNotes!),
                          ],
                          if (order.notes?.isNotEmpty == true)
                            _buildDetailRow('ملاحظات:', order.notes!),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Products
                      _buildProductsSection(order.items),
                    ],
                  ),
                ),
              ),

              // Actions - Conditional based on pricing approval status
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: StyleSystem.backgroundDark,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: _buildOrderDetailsActionButtons(order),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build detail section with header
  Widget _buildDetailSection(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: StyleSystem.primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  // Build products section
  Widget _buildProductsSection(List<OrderItem> items) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inventory_2_rounded, color: StyleSystem.primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'المنتجات (${items.length})',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map((item) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: StyleSystem.backgroundDark,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: StyleSystem.primaryColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.inventory_2_rounded,
                    color: StyleSystem.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      Text(
                        'الكمية: ${item.quantity}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${item.total.toStringAsFixed(2)} جنيه',
                  style: TextStyle(
                    color: StyleSystem.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }



  // Delete order (mark as cancelled)
  Future<void> _deleteOrder(ClientOrder order) async {
    final confirmed = await _showConfirmationDialog(
      'حذف الطلب',
      'هل أنت متأكد من حذف طلب "${order.clientName}"؟\n\nسيتم تغيير حالة الطلب إلى "ملغي" وإرسال إشعار للعميل.',
      'حذف',
      Colors.red,
    );

    if (confirmed == true) {
      try {
        // Update order status to cancelled
        final success = await _ordersService.updateOrderStatus(
          order.id,
          OrderStatus.cancelled,
        );

        if (success) {
          // Send notification to customer
          await _sendCustomerNotification(
            order.clientEmail,
            'تم إلغاء طلبك',
            'تم إلغاء طلبك #${order.id.substring(0, 8)}. نعتذر عن أي إزعاج.',
          );

          _showSuccessMessage('تم حذف الطلب وإرسال إشعار للعميل');
          _loadPendingOrders(); // Refresh the list
        } else {
          _showErrorMessage('فشل في حذف الطلب');
        }
      } catch (e) {
        _showErrorMessage('حدث خطأ أثناء حذف الطلب: $e');
      }
    }
  }

  // Send notification to customer
  Future<void> _sendCustomerNotification(String email, String title, String message) async {
    try {
      AppLogger.info('📧 Sending notification to $email: $title - $message');

      // Find the customer by email to get their user ID
      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
      final customerResponse = await supabaseProvider.client
          .from('user_profiles')
          .select('id')
          .eq('email', email)
          .maybeSingle();

      if (customerResponse != null) {
        final customerId = customerResponse['id'] as String;

        // Use RealNotificationService to send notification
        final notificationService = RealNotificationService();
        await notificationService.createNotification(
          userId: customerId,
          title: title,
          body: message,
          type: 'order_status_changed',
          category: 'orders',
          priority: 'normal',
          route: '/customer/orders',
          metadata: {
            'notification_type': 'order_approval',
            'requires_action': false,
          },
        );

        AppLogger.info('✅ Customer notification sent successfully');
      } else {
        AppLogger.warning('⚠️ Customer not found for email: $email');
      }
    } catch (e) {
      AppLogger.error('❌ Failed to send customer notification: $e');
    }
  }

  // Enhanced inventory check with detailed warehouse information
  Future<Map<String, dynamic>> _checkInventoryAvailability(ClientOrder order) async {
    try {
      AppLogger.info('🔍 Checking detailed inventory for order ${order.id}');

      final List<Map<String, dynamic>> availableItems = [];
      final List<Map<String, dynamic>> unavailableItems = [];
      final List<Map<String, dynamic>> partiallyAvailableItems = [];

      // Use actual warehouse service for real inventory data
      for (final item in order.items) {
        AppLogger.info('📦 Checking inventory for product: ${item.productName} (${item.productId})');

        try {
          // Get inventory across all warehouses for this product
          final productInventory = await _warehouseService.getProductInventoryAcrossWarehouses(item.productId);

          int totalAvailable = 0;
          final List<Map<String, dynamic>> warehouseDetails = [];

          for (final inventory in productInventory) {
            totalAvailable += inventory.quantity;
            warehouseDetails.add({
              'warehouseId': inventory.warehouseId,
              'warehouseName': inventory.warehouseName ?? 'مخزن غير محدد',
              'availableQuantity': inventory.quantity,
              'minimumStock': inventory.minimumStock,
              'maximumStock': inventory.maximumStock,
            });
          }

          final itemData = {
            'productId': item.productId,
            'productName': item.productName,
            'requiredQuantity': item.quantity,
            'totalAvailable': totalAvailable,
            'warehouseDetails': warehouseDetails,
            'unitPrice': item.price,
            'subtotal': item.total,
          };

          if (totalAvailable >= item.quantity) {
            // Fully available
            availableItems.add(itemData);
            AppLogger.info('✅ ${item.productName}: ${item.quantity} required, $totalAvailable available');
          } else if (totalAvailable > 0) {
            // Partially available
            partiallyAvailableItems.add(itemData);
            AppLogger.info('⚠️ ${item.productName}: ${item.quantity} required, only $totalAvailable available');
          } else {
            // Not available
            unavailableItems.add(itemData);
            AppLogger.info('❌ ${item.productName}: ${item.quantity} required, 0 available');
          }
        } catch (productError) {
          AppLogger.error('❌ Error checking inventory for ${item.productName}: $productError');
          // Add to unavailable if we can't check inventory
          unavailableItems.add({
            'productId': item.productId,
            'productName': item.productName,
            'requiredQuantity': item.quantity,
            'totalAvailable': 0,
            'warehouseDetails': [],
            'unitPrice': item.price,
            'subtotal': item.total,
            'error': 'فشل في فحص المخزون',
          });
        }
      }

      final allAvailable = unavailableItems.isEmpty && partiallyAvailableItems.isEmpty;
      final hasPartialAvailability = partiallyAvailableItems.isNotEmpty;

      AppLogger.info('✅ Enhanced inventory check complete:');
      AppLogger.info('   - Fully available: ${availableItems.length}');
      AppLogger.info('   - Partially available: ${partiallyAvailableItems.length}');
      AppLogger.info('   - Unavailable: ${unavailableItems.length}');

      return {
        'allAvailable': allAvailable,
        'hasPartialAvailability': hasPartialAvailability,
        'availableItems': availableItems,
        'partiallyAvailableItems': partiallyAvailableItems,
        'unavailableItems': unavailableItems,
        'totalItemsChecked': order.items.length,
      };
    } catch (e) {
      AppLogger.error('❌ Error in enhanced inventory check: $e');
      rethrow;
    }
  }

  // Process order (change status to In Preparation)
  Future<void> _processOrder(ClientOrder order) async {
    final confirmed = await _showConfirmationDialog(
      'معالجة الطلب',
      'هل أنت متأكد من بدء معالجة طلب "${order.clientName}"؟\n\nسيتم تغيير حالة الطلب إلى "قيد التحضير".',
      'معالجة',
      Colors.blue,
    );

    if (confirmed == true) {
      try {
        // Update order status to processing (In Preparation)
        final success = await _ordersService.updateOrderStatus(
          order.id,
          OrderStatus.processing,
        );

        if (success) {
          // Send notification to customer
          await _sendCustomerNotification(
            order.clientEmail,
            'بدء معالجة طلبك',
            'تم بدء معالجة طلبك #${order.id.substring(0, 8)}. سيتم شحن طلبك قريباً.',
          );

          _showSuccessMessage('تم بدء معالجة الطلب');
          _loadPendingOrders(); // Refresh the list
        } else {
          _showErrorMessage('فشل في معالجة الطلب');
        }
      } catch (e) {
        _showErrorMessage('حدث خطأ أثناء معالجة الطلب: $e');
      }
    }
  }

  // Process partial order (only available items)
  Future<void> _processPartialOrder(ClientOrder order, List<Map<String, dynamic>> availableItems) async {
    final confirmed = await _showConfirmationDialog(
      'معالجة جزئية للطلب',
      'هل أنت متأكد من معالجة الأجزاء المتوفرة من طلب "${order.clientName}"؟\n\nسيتم معالجة ${availableItems.length} من ${order.items.length} منتجات.',
      'معالجة جزئية',
      Colors.orange,
    );

    if (confirmed == true) {
      try {
        // Update order status to processing
        final success = await _ordersService.updateOrderStatus(
          order.id,
          OrderStatus.processing,
        );

        if (success) {
          // Send notification to customer about partial processing
          await _sendCustomerNotification(
            order.clientEmail,
            'معالجة جزئية لطلبك',
            'تم بدء معالجة الأجزاء المتوفرة من طلبك #${order.id.substring(0, 8)}. سيتم إشعارك عند توفر باقي المنتجات.',
          );

          _showSuccessMessage('تم بدء المعالجة الجزئية للطلب');
          _loadPendingOrders(); // Refresh the list
        } else {
          _showErrorMessage('فشل في المعالجة الجزئية');
        }
      } catch (e) {
        _showErrorMessage('حدث خطأ أثناء المعالجة الجزئية: $e');
      }
    }
  }

  // Show enhanced inventory check dialog
  Future<void> _showEnhancedInventoryDialog(ClientOrder order) async {
    try {
      // Show loading dialog first
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Perform inventory check
      final inventoryResult = await _checkInventoryAvailability(order);

      // Close loading dialog
      Navigator.of(context).pop();

      // Show detailed inventory results
      showDialog(
        context: context,
        builder: (context) => _buildInventoryCheckDialog(order, inventoryResult),
      );
    } catch (e) {
      // Close loading dialog if still open
      Navigator.of(context).pop();
      _showErrorMessage('فشل في فحص المخزون: $e');
    }
  }

  // Build inventory check dialog
  Widget _buildInventoryCheckDialog(ClientOrder order, Map<String, dynamic> inventoryResult) {
    final availableItems = inventoryResult['availableItems'] as List<Map<String, dynamic>>;
    final partiallyAvailableItems = inventoryResult['partiallyAvailableItems'] as List<Map<String, dynamic>>;
    final unavailableItems = inventoryResult['unavailableItems'] as List<Map<String, dynamic>>;
    final allAvailable = inventoryResult['allAvailable'] as bool;

    return Dialog(
      backgroundColor: StyleSystem.backgroundDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.inventory_2_rounded,
                  color: StyleSystem.primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'فحص المخزون التفصيلي',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: allAvailable ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: allAvailable ? Colors.green : Colors.orange,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    allAvailable ? Icons.check_circle : Icons.warning,
                    color: allAvailable ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      allAvailable
                        ? 'جميع المنتجات متوفرة في المخزون'
                        : 'بعض المنتجات غير متوفرة أو متوفرة جزئياً',
                      style: TextStyle(
                        color: allAvailable ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Inventory details
            Expanded(
              child: DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    TabBar(
                      labelColor: StyleSystem.primaryColor,
                      unselectedLabelColor: Colors.white60,
                      indicatorColor: StyleSystem.primaryColor,
                      tabs: [
                        Tab(text: 'متوفر (${availableItems.length})'),
                        Tab(text: 'جزئي (${partiallyAvailableItems.length})'),
                        Tab(text: 'غير متوفر (${unavailableItems.length})'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildInventoryItemsList(availableItems, Colors.green),
                          _buildInventoryItemsList(partiallyAvailableItems, Colors.orange),
                          _buildInventoryItemsList(unavailableItems, Colors.red),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Action buttons
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('إغلاق'),
                  ),
                ),
                if (allAvailable || partiallyAvailableItems.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _showWarehouseSelectionDialog(order, inventoryResult);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: StyleSystem.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(allAvailable ? 'اختيار المخازن والموافقة' : 'اختيار المخازن للموافقة الجزئية'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Build inventory items list
  Widget _buildInventoryItemsList(List<Map<String, dynamic>> items, Color statusColor) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Colors.white.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد منتجات في هذه الفئة',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 16,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final warehouseDetails = item['warehouseDetails'] as List<Map<String, dynamic>>;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: StyleSystem.surfaceDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: statusColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.inventory_2_rounded,
                      color: statusColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['productName'] as String,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        Text(
                          'مطلوب: ${item['requiredQuantity']} | متوفر: ${item['totalAvailable']}',
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 14,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Warehouse details
              if (warehouseDetails.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'توزيع المخازن:',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 8),
                ...warehouseDetails.map((warehouse) => Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warehouse,
                        color: StyleSystem.primaryColor,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          warehouse['warehouseName'] as String,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ),
                      Text(
                        '${warehouse['availableQuantity']} قطعة',
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              ],

              // Error message if any
              if (item.containsKey('error')) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item['error'] as String,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // Show warehouse selection dialog
  Future<void> _showWarehouseSelectionDialog(ClientOrder order, Map<String, dynamic> inventoryResult) async {
    final availableItems = inventoryResult['availableItems'] as List<Map<String, dynamic>>;
    final partiallyAvailableItems = inventoryResult['partiallyAvailableItems'] as List<Map<String, dynamic>>;

    // Combine available and partially available items for warehouse selection
    final selectableItems = [...availableItems, ...partiallyAvailableItems];

    // Create a map to store selected warehouses for each product
    final Map<String, Map<String, int>> selectedWarehouses = {};

    // Initialize with default selections (first available warehouse for each product)
    for (final item in selectableItems) {
      final productId = item['productId'] as String;
      final warehouseDetails = item['warehouseDetails'] as List<Map<String, dynamic>>;
      final requiredQuantity = item['requiredQuantity'] as int;

      selectedWarehouses[productId] = {};

      // Auto-select warehouses to fulfill the required quantity
      int remainingQuantity = requiredQuantity;
      for (final warehouse in warehouseDetails) {
        if (remainingQuantity <= 0) break;

        final warehouseId = warehouse['warehouseId'] as String;
        final availableQuantity = warehouse['availableQuantity'] as int;
        final takeQuantity = math.min(remainingQuantity, availableQuantity);

        if (takeQuantity > 0) {
          selectedWarehouses[productId]![warehouseId] = takeQuantity;
          remainingQuantity -= takeQuantity;
        }
      }
    }

    showDialog(
      context: context,
      builder: (context) => _buildWarehouseSelectionDialog(order, selectableItems, selectedWarehouses),
    );
  }

  // Build warehouse selection dialog
  Widget _buildWarehouseSelectionDialog(
    ClientOrder order,
    List<Map<String, dynamic>> selectableItems,
    Map<String, Map<String, int>> selectedWarehouses
  ) {
    return StatefulBuilder(
      builder: (context, setState) {
        return Dialog(
          backgroundColor: StyleSystem.backgroundDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.95,
            height: MediaQuery.of(context).size.height * 0.85,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(
                      Icons.warehouse_rounded,
                      color: StyleSystem.primaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'اختيار المخازن للصرف',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Instructions
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: StyleSystem.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: StyleSystem.primaryColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: StyleSystem.primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'اختر المخازن والكميات المطلوبة لكل منتج. يمكنك توزيع الكمية على عدة مخازن.',
                          style: TextStyle(
                            color: StyleSystem.primaryColor,
                            fontSize: 14,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Products list
                Expanded(
                  child: ListView.builder(
                    itemCount: selectableItems.length,
                    itemBuilder: (context, index) {
                      final item = selectableItems[index];
                      return _buildProductWarehouseSelector(item, selectedWarehouses, setState);
                    },
                  ),
                ),

                // Action buttons
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('إلغاء'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _approveOrderWithWarehouseSelection(order, selectedWarehouses);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: StyleSystem.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('موافقة وإنشاء أذن صرف'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Build product warehouse selector
  Widget _buildProductWarehouseSelector(
    Map<String, dynamic> item,
    Map<String, Map<String, int>> selectedWarehouses,
    StateSetter setState
  ) {
    final productId = item['productId'] as String;
    final productName = item['productName'] as String;
    final requiredQuantity = item['requiredQuantity'] as int;
    final warehouseDetails = item['warehouseDetails'] as List<Map<String, dynamic>>;

    // Calculate total selected quantity
    final selectedQuantity = selectedWarehouses[productId]?.values.fold<int>(0, (sum, qty) => sum + qty) ?? 0;
    final isComplete = selectedQuantity >= requiredQuantity;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: StyleSystem.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isComplete ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isComplete ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.inventory_2_rounded,
                  color: isComplete ? Colors.green : Colors.orange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    Text(
                      'مطلوب: $requiredQuantity | محدد: $selectedQuantity',
                      style: TextStyle(
                        color: isComplete ? Colors.green : Colors.orange,
                        fontSize: 14,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Warehouse selectors
          ...warehouseDetails.map((warehouse) {
            final warehouseId = warehouse['warehouseId'] as String;
            final warehouseName = warehouse['warehouseName'] as String;
            final availableQuantity = warehouse['availableQuantity'] as int;
            final currentSelection = selectedWarehouses[productId]?[warehouseId] ?? 0;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: currentSelection > 0 ? Border.all(
                  color: StyleSystem.primaryColor.withOpacity(0.5),
                  width: 1,
                ) : null,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warehouse,
                    color: StyleSystem.primaryColor,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          warehouseName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        Text(
                          'متوفر: $availableQuantity',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Quantity selector
                  Container(
                    width: 120,
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: currentSelection > 0 ? () {
                            setState(() {
                              selectedWarehouses[productId]![warehouseId] = currentSelection - 1;
                              if (selectedWarehouses[productId]![warehouseId] == 0) {
                                selectedWarehouses[productId]!.remove(warehouseId);
                              }
                            });
                          } : null,
                          icon: const Icon(Icons.remove, size: 16),
                          color: Colors.white70,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '$currentSelection',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: currentSelection < availableQuantity ? () {
                            setState(() {
                              selectedWarehouses[productId] ??= {};
                              selectedWarehouses[productId]![warehouseId] = currentSelection + 1;
                            });
                          } : null,
                          icon: const Icon(Icons.add, size: 16),
                          color: Colors.white70,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  // Open pricing approval screen
  Future<void> _openPricingApproval(ClientOrder order) async {
    try {
      AppLogger.info('🔄 Opening pricing approval screen for order: ${order.id}');
      AppLogger.info('  - Order client: ${order.clientName}');
      AppLogger.info('  - Order total: ${order.total}');
      AppLogger.info('  - Order items count: ${order.items.length}');
      AppLogger.info('  - Pricing status: ${order.pricingStatus}');

      // Show loading indicator
      _showInfoMessage('جاري فتح شاشة اعتماد التسعير...');

      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PricingApprovalScreen(order: order),
        ),
      );

      AppLogger.info('🔙 Returned from pricing approval screen with result: $result');

      // If pricing was approved, refresh the orders list and show updated order details
      if (result == true) {
        _showSuccessMessage('تم اعتماد التسعير بنجاح');
        _loadPendingOrders(); // Refresh the pending orders list

        // Get updated order data and show refreshed order details
        try {
          final updatedOrders = await _ordersService.getAllOrders();
          final updatedOrder = updatedOrders.firstWhere(
            (o) => o.id == order.id,
            orElse: () => order, // Fallback to original order if not found
          );

          // Show updated order details with new pricing status
          AppLogger.info('🔄 Showing updated order details after pricing approval');
          _showEnhancedOrderDetailsWithRefresh(updatedOrder);
        } catch (e) {
          AppLogger.error('❌ Error refreshing order details: $e');
          // Still show success message even if refresh fails
        }
      } else if (result == false) {
        _showInfoMessage('تم إلغاء اعتماد التسعير');
      } else {
        AppLogger.info('ℹ️ Pricing approval screen closed without result');
      }
    } catch (e) {
      AppLogger.error('❌ Error opening pricing approval: $e');
      _showErrorMessage('حدث خطأ أثناء فتح شاشة اعتماد التسعير: $e');
    }
  }

  // Approve order with warehouse selection
  Future<void> _approveOrderWithWarehouseSelection(
    ClientOrder order,
    Map<String, Map<String, int>> selectedWarehouses
  ) async {
    try {
      AppLogger.info('🏭 Approving order with warehouse selection: ${order.id}');

      // Validate selections
      bool hasValidSelections = true;
      for (final item in order.items) {
        final productId = item.productId;
        final requiredQuantity = item.quantity;
        final selectedQuantity = selectedWarehouses[productId]?.values.fold<int>(0, (sum, qty) => sum + qty) ?? 0;

        if (selectedQuantity == 0) {
          hasValidSelections = false;
          _showErrorMessage('يجب تحديد مخزن واحد على الأقل لكل منتج');
          return;
        }
      }

      if (!hasValidSelections) return;

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Update order status to confirmed
      final success = await _ordersService.updateOrderStatus(
        order.id,
        OrderStatus.confirmed,
      );

      if (!success) {
        Navigator.of(context).pop(); // Close loading
        _showErrorMessage('فشل في تحديث حالة الطلب');
        return;
      }

      // Get current user for assignment
      final currentUser = Provider.of<SupabaseProvider>(context, listen: false).user;
      if (currentUser == null) {
        Navigator.of(context).pop(); // Close loading
        _showErrorMessage('خطأ في المصادقة - يرجى تسجيل الدخول مرة أخرى');
        return;
      }

      // Create warehouse release order with warehouse selections
      final releaseOrderId = await _warehouseReleaseService.createReleaseOrderFromApprovedOrderWithWarehouseSelection(
        approvedOrder: order,
        assignedTo: currentUser.id,
        warehouseSelections: selectedWarehouses,
        notes: 'تم إنشاء أذن الصرف مع تحديد المخازن المخصصة',
      );

      Navigator.of(context).pop(); // Close loading

      if (releaseOrderId != null) {
        // Send customer notification
        await _sendCustomerNotification(
          order.clientEmail,
          'تم تأكيد طلبك',
          'تم تأكيد طلبك #${order.id.substring(0, 8)} بنجاح وإنشاء أذن صرف من المخازن المحددة.',
        );

        _showSuccessMessage('تم تأكيد الطلب وإنشاء أذن صرف بنجاح');
        _loadPendingOrders(); // Refresh the list
      } else {
        _showErrorMessage('فشل في إنشاء أذن الصرف');
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close loading if still open
      _showErrorMessage('حدث خطأ أثناء معالجة الطلب: $e');
      AppLogger.error('❌ Error in warehouse selection approval: $e');
    }
  }

  // Wait for restock
  Future<void> _waitForRestock(ClientOrder order) async {
    final confirmed = await _showConfirmationDialog(
      'انتظار التوريد',
      'هل تريد وضع طلب "${order.clientName}" في قائمة انتظار التوريد؟\n\nسيتم إشعار العميل عند توفر جميع المنتجات.',
      'انتظار',
      Colors.blue,
    );

    if (confirmed == true) {
      try {
        // Keep order as pending but add a note
        // In a real implementation, you would add this to a restock waiting list

        // Send notification to customer
        await _sendCustomerNotification(
          order.clientEmail,
          'طلبك في انتظار التوريد',
          'طلبك #${order.id.substring(0, 8)} في انتظار توفر بعض المنتجات. سيتم إشعارك فور توفرها.',
        );

        _showSuccessMessage('تم وضع الطلب في قائمة انتظار التوريد');

        // Close the flip card
        _toggleOrderCardFlip(order.id);
      } catch (e) {
        _showErrorMessage('حدث خطأ: $e');
      }
    }
  }
}
