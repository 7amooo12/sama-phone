import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/warehouse_release_order_model.dart';
import '../../services/warehouse_release_orders_service.dart';
import '../../providers/supabase_provider.dart';
import '../../utils/app_logger.dart';
import '../../utils/accountant_theme_config.dart';
import '../../widgets/accountant/modern_widgets.dart';
import '../../widgets/warehouse/clear_all_data_dialog.dart';

/// شاشة أذون صرف المخزون
/// تعمل مثل نظام الفواتير مع إدارة شاملة لأذون الصرف
/// تدعم واجهات مختلفة حسب دور المستخدم
class WarehouseReleaseOrdersScreen extends StatefulWidget {
  final String? userRole;

  const WarehouseReleaseOrdersScreen({
    super.key,
    this.userRole,
  });

  @override
  State<WarehouseReleaseOrdersScreen> createState() => _WarehouseReleaseOrdersScreenState();
}

class _WarehouseReleaseOrdersScreenState extends State<WarehouseReleaseOrdersScreen>
    with TickerProviderStateMixin {
  final WarehouseReleaseOrdersService _releaseOrdersService = WarehouseReleaseOrdersService();

  List<WarehouseReleaseOrderModel> _releaseOrders = [];
  List<WarehouseReleaseOrderModel> _filteredOrders = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  WarehouseReleaseOrderStatus? _selectedStatus;

  // Animation controllers for cards
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Role-based access control
  String get _userRole => widget.userRole ?? 'accountant';
  bool get _isAccountant => _userRole == 'accountant';
  bool get _isWarehouseManager => _userRole == 'warehouseManager' || _userRole == 'warehouse_manager';
  bool get _canApproveOrders => _isWarehouseManager;
  bool get _canClearAllData => _isAccountant || _isWarehouseManager;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadReleaseOrders();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
  }

  /// تحميل أذون الصرف
  Future<void> _loadReleaseOrders() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      AppLogger.info('🔄 Loading warehouse release orders...');
      final orders = await _releaseOrdersService.getAllReleaseOrders();
      
      setState(() {
        _releaseOrders = orders;
        _filteredOrders = orders;
        _isLoading = false;
      });

      _fadeController.forward();
      _applyFilters();
      AppLogger.info('✅ Loaded ${orders.length} warehouse release orders');
    } catch (e) {
      setState(() {
        _error = 'فشل في تحميل أذون الصرف: $e';
        _isLoading = false;
      });
      AppLogger.error('❌ Error loading warehouse release orders: $e');
    }
  }

  /// تطبيق الفلاتر
  void _applyFilters() {
    setState(() {
      _filteredOrders = _releaseOrders.where((order) {
        // Search filter
        final matchesSearch = _searchQuery.isEmpty ||
            order.clientName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            order.clientEmail.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            order.releaseOrderNumber.toLowerCase().contains(_searchQuery.toLowerCase());

        // Status filter
        final matchesStatus = _selectedStatus == null || order.status == _selectedStatus;

        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AccountantThemeConfig.mainBackgroundGradient,
        ),
        child: RefreshIndicator(
          onRefresh: _loadReleaseOrders,
          color: AccountantThemeConfig.primaryGreen,
          backgroundColor: AccountantThemeConfig.cardBackground1,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(), // Enable pull-to-refresh
            slivers: [
              // Compact header with search and filters
              SliverToBoxAdapter(
                child: _buildCompactHeader(),
              ),

              // Release orders list
              _buildSliverReleaseOrdersList(),
            ],
          ),
        ),
      ),
    );
  }

  /// بناء الهيدر المضغوط مع البحث والفلاتر
  Widget _buildCompactHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12), // Reduced padding
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(AccountantThemeConfig.largeBorderRadius),
          bottomRight: Radius.circular(AccountantThemeConfig.largeBorderRadius),
        ),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Column(
        children: [
          // Compact title row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8), // Reduced padding
                decoration: BoxDecoration(
                  gradient: AccountantThemeConfig.greenGradient,
                  borderRadius: BorderRadius.circular(8), // Smaller radius
                  boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
                ),
                child: const Icon(
                  Icons.local_shipping_rounded,
                  color: Colors.white,
                  size: 20, // Smaller icon
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'أذون صرف المخزون',
                  style: AccountantThemeConfig.headlineSmall.copyWith( // Smaller text
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Action buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_canClearAllData)
                    _buildClearAllButton(),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _loadReleaseOrders,
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                    tooltip: 'تحديث',
                    padding: const EdgeInsets.all(8), // Smaller button
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12), // Reduced spacing

          // Compact search bar
          TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
              _applyFilters();
            },
            style: const TextStyle(color: Colors.white, fontSize: 14), // Smaller text
            decoration: InputDecoration(
              hintText: 'البحث برقم أذن الصرف أو اسم العميل...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: AccountantThemeConfig.primaryGreen,
                size: 20, // Smaller icon
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12), // Reduced padding
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                borderSide: BorderSide(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
                borderSide: BorderSide(
                  color: AccountantThemeConfig.primaryGreen,
                  width: 2,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12), // Reduced spacing

          // Compact status filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCompactStatusFilterChip('الكل', null),
                const SizedBox(width: 6),
                _buildCompactStatusFilterChip('انتظار', WarehouseReleaseOrderStatus.pendingWarehouseApproval),
                const SizedBox(width: 6),
                _buildCompactStatusFilterChip('موافق', WarehouseReleaseOrderStatus.approvedByWarehouse),
                const SizedBox(width: 6),
                _buildCompactStatusFilterChip('مكتمل', WarehouseReleaseOrderStatus.completed),
                const SizedBox(width: 6),
                _buildCompactStatusFilterChip('مرفوض', WarehouseReleaseOrderStatus.rejected),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Smaller padding
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16), // Smaller radius
                  ),
                  child: Text(
                    '${_filteredOrders.length}',
                    style: AccountantThemeConfig.bodySmall.copyWith(
                      color: Colors.white70,
                      fontSize: 12, // Smaller text
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// بناء فلتر الحالة المضغوط
  Widget _buildCompactStatusFilterChip(String label, WarehouseReleaseOrderStatus? status) {
    final isSelected = _selectedStatus == status;
    return FilterChip(
      label: Text(
        label,
        style: AccountantThemeConfig.bodySmall.copyWith(
          color: isSelected ? Colors.white : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12, // Smaller text
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedStatus = selected ? status : null;
        });
        _applyFilters();
      },
      backgroundColor: Colors.white.withOpacity(0.1),
      selectedColor: AccountantThemeConfig.primaryGreen,
      checkmarkColor: Colors.white,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // Compact size
      visualDensity: VisualDensity.compact, // Compact density
      side: BorderSide(
        color: isSelected
            ? AccountantThemeConfig.primaryGreen
            : Colors.white.withOpacity(0.3),
        width: 1,
      ),
    );
  }

  /// بناء فلتر الحالة (الطريقة الأصلية - محفوظة للتوافق)
  Widget _buildStatusFilterChip(String label, WarehouseReleaseOrderStatus? status) {
    final isSelected = _selectedStatus == status;
    return FilterChip(
      label: Text(
        label,
        style: AccountantThemeConfig.bodySmall.copyWith(
          color: isSelected ? Colors.white : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedStatus = selected ? status : null;
        });
        _applyFilters();
      },
      backgroundColor: Colors.white.withOpacity(0.1),
      selectedColor: AccountantThemeConfig.primaryGreen,
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: isSelected
            ? AccountantThemeConfig.primaryGreen
            : Colors.white.withOpacity(0.3),
        width: 1,
      ),
    );
  }

  /// بناء زر مسح جميع البيانات
  Widget _buildClearAllButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.redGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.dangerRed),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showClearAllDataDialog,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.delete_forever_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'مسح الكل',
                  style: AccountantThemeConfig.labelMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }





  /// بناء قائمة أذون الصرف كـ Sliver مع حالات تحميل محسنة
  Widget _buildSliverReleaseOrdersList() {
    if (_isLoading) {
      return SliverToBoxAdapter(
        child: _buildEnhancedLoadingState(),
      );
    }

    if (_error != null) {
      return SliverToBoxAdapter(
        child: _buildEnhancedErrorState(_error!),
      );
    }

    if (_filteredOrders.isEmpty) {
      return SliverToBoxAdapter(
        child: _buildEnhancedEmptyState(),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final order = _filteredOrders[index];
            return FadeTransition(
              opacity: _fadeAnimation,
              child: AnimatedContainer(
                duration: Duration(milliseconds: 300 + (index * 50)),
                curve: Curves.easeOutBack,
                child: _buildReleaseOrderCard(order, index),
              ),
            );
          },
          childCount: _filteredOrders.length,
        ),
      ),
    );
  }

  /// بناء قائمة أذون الصرف مع حالات تحميل محسنة (الطريقة الأصلية - محفوظة للتوافق)
  Widget _buildReleaseOrdersList() {
    if (_isLoading) {
      return _buildEnhancedLoadingState();
    }

    if (_error != null) {
      return _buildEnhancedErrorState(_error!);
    }

    if (_filteredOrders.isEmpty) {
      return _buildEnhancedEmptyState();
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: RefreshIndicator(
        onRefresh: _loadReleaseOrders,
        color: AccountantThemeConfig.primaryGreen,
        backgroundColor: AccountantThemeConfig.cardBackground1,
        child: ListView.builder(
          padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
          itemCount: _filteredOrders.length,
          itemBuilder: (context, index) {
            final order = _filteredOrders[index];
            return AnimatedContainer(
              duration: Duration(milliseconds: 300 + (index * 50)),
              curve: Curves.easeOutBack,
              child: _buildReleaseOrderCard(order, index),
            );
          },
        ),
      ),
    );
  }

  /// بناء بطاقة أذن الصرف
  Widget _buildReleaseOrderCard(WarehouseReleaseOrderModel order, int index) {
    final statusColor = _getStatusColor(order.status);

    return Container(
      margin: const EdgeInsets.only(bottom: AccountantThemeConfig.defaultPadding),
      decoration: AccountantThemeConfig.primaryCardDecoration.copyWith(
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          ...AccountantThemeConfig.cardShadows,
          BoxShadow(
            color: statusColor.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showReleaseOrderDetails(order),
          borderRadius: BorderRadius.circular(AccountantThemeConfig.largeBorderRadius),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    // Status indicator
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: statusColor.withOpacity(0.3),
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

                    // Order info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.releaseOrderNumber,
                            style: AccountantThemeConfig.bodyLarge.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            order.clientName,
                            style: AccountantThemeConfig.bodyMedium.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Amount
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${order.finalAmount.toStringAsFixed(2)} جنيه',
                          style: AccountantThemeConfig.bodyLarge.copyWith(
                            color: AccountantThemeConfig.primaryGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          order.statusText,
                          style: AccountantThemeConfig.bodySmall.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Order details
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoChip(
                        Icons.inventory_2_rounded,
                        '${order.totalItems} صنف',
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildInfoChip(
                        Icons.shopping_cart_rounded,
                        '${order.totalQuantity} قطعة',
                        Colors.purple,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildInfoChip(
                        Icons.access_time_rounded,
                        _formatDate(order.createdAt),
                        Colors.orange,
                      ),
                    ),
                  ],
                ),

                // Role-based action buttons
                if (_shouldShowActionButtons(order))
                  _buildActionButtons(order),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// بناء معلومة صغيرة
  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: 14,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: AccountantThemeConfig.bodySmall.copyWith(
                color: Colors.white,
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// تحديد ما إذا كان يجب عرض أزرار الإجراءات
  bool _shouldShowActionButtons(WarehouseReleaseOrderModel order) {
    // المحاسبون: عرض فقط للمراجعة (بدون أزرار إجراءات)
    if (_isAccountant) {
      return false;
    }

    // مديرو المخازن: عرض أزرار الإجراءات للأذون القابلة للمعالجة
    if (_isWarehouseManager) {
      return _canApproveOrder(order) ||
             _canStartProcessing(order) ||
             _canCompleteShipping(order) ||
             _canConfirmDelivery(order) ||
             _canRejectOrder(order);
    }

    return false;
  }

  /// تحديد ما إذا كان يمكن الموافقة على الأذن
  bool _canApproveOrder(WarehouseReleaseOrderModel order) {
    return _isWarehouseManager &&
           order.status == WarehouseReleaseOrderStatus.pendingWarehouseApproval;
  }

  /// تحديد ما إذا كان يمكن بدء المعالجة
  bool _canStartProcessing(WarehouseReleaseOrderModel order) {
    return _isWarehouseManager &&
           order.status == WarehouseReleaseOrderStatus.approvedByWarehouse;
  }

  /// تحديد ما إذا كان يمكن إكمال الشحن
  bool _canCompleteShipping(WarehouseReleaseOrderModel order) {
    return _isWarehouseManager &&
           order.status == WarehouseReleaseOrderStatus.approvedByWarehouse;
  }

  /// تحديد ما إذا كان يمكن تأكيد التسليم
  bool _canConfirmDelivery(WarehouseReleaseOrderModel order) {
    return _isWarehouseManager &&
           order.status == WarehouseReleaseOrderStatus.readyForDelivery;
  }

  /// تحديد ما إذا كان يمكن رفض الأذن
  bool _canRejectOrder(WarehouseReleaseOrderModel order) {
    return _isWarehouseManager &&
           (order.status == WarehouseReleaseOrderStatus.pendingWarehouseApproval ||
            order.status == WarehouseReleaseOrderStatus.approvedByWarehouse);
  }

  /// بناء أزرار الإجراءات
  Widget _buildActionButtons(WarehouseReleaseOrderModel order) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          // الصف الأول: الموافقة والرفض
          if (_canApproveOrder(order) || _canRejectOrder(order))
            Row(
              children: [
                if (_canApproveOrder(order)) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _approveReleaseOrder(order),
                      icon: const Icon(Icons.check_circle_rounded, size: 18),
                      label: const Text('موافقة الأذن'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AccountantThemeConfig.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                if (_canRejectOrder(order)) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _rejectReleaseOrder(order),
                      icon: const Icon(Icons.cancel_rounded, size: 18),
                      label: const Text('رفض'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),

          // الصف الثاني: المعالجة والإكمال
          if (_canStartProcessing(order) || _canCompleteShipping(order)) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (_canCompleteShipping(order)) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _completeShipping(order),
                      icon: const Icon(Icons.local_shipping_rounded, size: 18),
                      label: const Text('إكمال وشحن'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],

          // الصف الثالث: تأكيد التسليم
          if (_canConfirmDelivery(order)) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _confirmDelivery(order),
                    icon: const Icon(Icons.done_all_rounded, size: 18),
                    label: const Text('تم التسليم'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AccountantThemeConfig.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// الحصول على لون الحالة
  Color _getStatusColor(WarehouseReleaseOrderStatus status) {
    switch (status) {
      case WarehouseReleaseOrderStatus.pendingWarehouseApproval:
        return Colors.orange;
      case WarehouseReleaseOrderStatus.approvedByWarehouse:
        return AccountantThemeConfig.primaryGreen;
      case WarehouseReleaseOrderStatus.readyForDelivery:
        return Colors.blue;
      case WarehouseReleaseOrderStatus.completed:
        return Colors.green.shade700;
      case WarehouseReleaseOrderStatus.rejected:
        return Colors.red;
      case WarehouseReleaseOrderStatus.cancelled:
        return Colors.grey;
    }
  }

  /// الحصول على أيقونة الحالة
  IconData _getStatusIcon(WarehouseReleaseOrderStatus status) {
    switch (status) {
      case WarehouseReleaseOrderStatus.pendingWarehouseApproval:
        return Icons.pending_actions_rounded;
      case WarehouseReleaseOrderStatus.approvedByWarehouse:
        return Icons.check_circle_rounded;
      case WarehouseReleaseOrderStatus.readyForDelivery:
        return Icons.local_shipping_rounded;
      case WarehouseReleaseOrderStatus.completed:
        return Icons.done_all_rounded;
      case WarehouseReleaseOrderStatus.rejected:
        return Icons.cancel_rounded;
      case WarehouseReleaseOrderStatus.cancelled:
        return Icons.block_rounded;
    }
  }

  /// تنسيق التاريخ
  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm', 'ar').format(date);
  }

  /// عرض تفاصيل أذن الصرف
  void _showReleaseOrderDetails(WarehouseReleaseOrderModel order) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 800),
          decoration: AccountantThemeConfig.primaryCardDecoration,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AccountantThemeConfig.greenGradient,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AccountantThemeConfig.largeBorderRadius),
                    topRight: Radius.circular(AccountantThemeConfig.largeBorderRadius),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.local_shipping_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تفاصيل أذن الصرف',
                            style: AccountantThemeConfig.headlineSmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            order.releaseOrderNumber,
                            style: AccountantThemeConfig.bodyMedium.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
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
                      // Customer info
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

                      // Order info
                      _buildDetailSection(
                        'معلومات الطلب',
                        Icons.receipt_long_rounded,
                        [
                          _buildDetailRow('رقم أذن الصرف:', order.releaseOrderNumber),
                          _buildDetailRow('الطلب الأصلي:', order.originalOrderId.substring(0, 8) + '...'),
                          _buildDetailRow('الحالة:', order.statusText),
                          _buildDetailRow('تاريخ الإنشاء:', _formatDate(order.createdAt)),
                          if (order.approvedAt != null)
                            _buildDetailRow('تاريخ الموافقة:', _formatDate(order.approvedAt!)),
                          if (order.completedAt != null)
                            _buildDetailRow('تاريخ الإكمال:', _formatDate(order.completedAt!)),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Items
                      _buildItemsSection(order.items),

                      const SizedBox(height: 20),

                      // Financial summary
                      _buildFinancialSummary(order),
                    ],
                  ),
                ),
              ),

              // Role-based action buttons
              if (_shouldShowActionButtons(order))
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(AccountantThemeConfig.largeBorderRadius),
                      bottomRight: Radius.circular(AccountantThemeConfig.largeBorderRadius),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (_canRejectOrder(order)) ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _rejectReleaseOrder(order);
                            },
                            icon: const Icon(Icons.cancel_rounded),
                            label: const Text('رفض'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (_canApproveOrder(order)) ...[
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _approveReleaseOrder(order);
                            },
                            icon: const Icon(Icons.check_circle_rounded),
                            label: const Text('موافقة وإكمال'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AccountantThemeConfig.primaryGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// بناء قسم التفاصيل
  Widget _buildDetailSection(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AccountantThemeConfig.primaryGreen, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: AccountantThemeConfig.bodyLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
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

  /// بناء صف التفاصيل
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white70,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// بناء قسم العناصر
  Widget _buildItemsSection(List<WarehouseReleaseOrderItem> items) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inventory_2_rounded, color: AccountantThemeConfig.primaryGreen, size: 20),
              const SizedBox(width: 8),
              Text(
                'المنتجات (${items.length})',
                style: AccountantThemeConfig.bodyLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map((item) => _buildItemCard(item)),
        ],
      ),
    );
  }

  /// بناء بطاقة المنتج
  Widget _buildItemCard(WarehouseReleaseOrderItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Product image placeholder
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AccountantThemeConfig.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Icon(
              Icons.inventory_2_rounded,
              color: AccountantThemeConfig.primaryGreen,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),

          // Product details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'الكمية: ${item.quantity}',
                      style: AccountantThemeConfig.bodySmall.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'السعر: ${item.unitPrice.toStringAsFixed(2)} جنيه',
                      style: AccountantThemeConfig.bodySmall.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Total
          Text(
            '${item.subtotal.toStringAsFixed(2)} جنيه',
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: AccountantThemeConfig.primaryGreen,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// بناء الملخص المالي
  Widget _buildFinancialSummary(WarehouseReleaseOrderModel order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AccountantThemeConfig.greenGradient.colors.map((c) => c.withOpacity(0.1)).toList(),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calculate_rounded, color: AccountantThemeConfig.primaryGreen, size: 20),
              const SizedBox(width: 8),
              Text(
                'الملخص المالي',
                style: AccountantThemeConfig.bodyLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildFinancialRow('المجموع الفرعي:', '${order.totalAmount.toStringAsFixed(2)} جنيه'),
          if (order.discount > 0)
            _buildFinancialRow('الخصم:', '${order.discount.toStringAsFixed(2)} جنيه', isDiscount: true),
          const Divider(color: Colors.white24),
          _buildFinancialRow(
            'المجموع النهائي:',
            '${order.finalAmount.toStringAsFixed(2)} جنيه',
            isTotal: true,
          ),
        ],
      ),
    );
  }

  /// بناء صف مالي
  Widget _buildFinancialRow(String label, String value, {bool isDiscount = false, bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: isTotal ? Colors.white : Colors.white70,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: isDiscount
                  ? Colors.red
                  : isTotal
                      ? AccountantThemeConfig.primaryGreen
                      : Colors.white,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  /// موافقة أذن الصرف
  Future<void> _approveReleaseOrder(WarehouseReleaseOrderModel order) async {
    final confirmed = await _showConfirmationDialog(
      'تأكيد الموافقة',
      'هل أنت متأكد من الموافقة على أذن الصرف "${order.releaseOrderNumber}"؟\n\nسيتم تحديث الحالة إلى "موافق عليه من المخزن" وسيصبح جاهزاً للمعالجة.',
      'موافقة الأذن',
      AccountantThemeConfig.primaryGreen,
    );

    if (confirmed == true) {
      try {
        final currentUser = Provider.of<SupabaseProvider>(context, listen: false).user;
        if (currentUser == null) {
          _showErrorMessage('خطأ في المصادقة');
          return;
        }

        // تحديث الحالة إلى "موافق عليه من المخزن" وليس مكتمل
        final success = await _releaseOrdersService.updateReleaseOrderStatus(
          releaseOrderId: order.id,
          newStatus: WarehouseReleaseOrderStatus.approvedByWarehouse,
          warehouseManagerId: currentUser.id,
          warehouseManagerName: currentUser.name,
        );

        if (success) {
          _showSuccessMessage('تم الموافقة على أذن الصرف - جاهز للمعالجة');
          _loadReleaseOrders();
        } else {
          _showErrorMessage('فشل في الموافقة على أذن الصرف');
        }
      } catch (e) {
        _showErrorMessage('حدث خطأ: $e');
      }
    }
  }

  /// إكمال الشحن مع خصم المخزون الذكي
  Future<void> _completeShipping(WarehouseReleaseOrderModel order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AccountantThemeConfig.cardBackground1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AccountantThemeConfig.largeBorderRadius),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AccountantThemeConfig.blueGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.local_shipping_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'إكمال الشحن',
              style: AccountantThemeConfig.headlineSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'هل تريد إكمال شحن أذن الصرف؟',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'سيتم تنفيذ الإجراءات التالية:',
                    style: AccountantThemeConfig.bodySmall.copyWith(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• خصم المنتجات من المخزون تلقائياً',
                    style: AccountantThemeConfig.bodySmall.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  Text(
                    '• تحديث حالة الطلب إلى "مكتمل"',
                    style: AccountantThemeConfig.bodySmall.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  Text(
                    '• إرسال إشعار للعميل والمحاسب',
                    style: AccountantThemeConfig.bodySmall.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'رقم الأذن: ${order.releaseOrderNumber}',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'العميل: ${order.clientName}',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white70,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'إلغاء',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.local_shipping_rounded, size: 18),
            label: const Text('إكمال الشحن'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final currentUser = Provider.of<SupabaseProvider>(context, listen: false).user;
        if (currentUser == null) {
          _showErrorMessage('خطأ في المصادقة');
          return;
        }

        // إكمال معالجة جميع عناصر أذن الصرف مع الخصم الذكي
        final success = await _releaseOrdersService.processAllReleaseOrderItems(
          releaseOrderId: order.id,
          warehouseManagerId: currentUser.id,
          notes: 'تم إكمال الشحن بواسطة ${currentUser.name}',
        );

        if (success) {
          _showSuccessMessage('تم إكمال الشحن وخصم المخزون بنجاح');
          _loadReleaseOrders();
        } else {
          _showErrorMessage('فشل في إكمال الشحن');
        }
      } catch (e) {
        _showErrorMessage('حدث خطأ: $e');
      }
    }
  }

  /// تأكيد التسليم
  Future<void> _confirmDelivery(WarehouseReleaseOrderModel order) async {
    final deliveryNotes = await _showDeliveryConfirmationDialog();
    if (deliveryNotes != null) {
      try {
        final currentUser = Provider.of<SupabaseProvider>(context, listen: false).user;
        if (currentUser == null) {
          _showErrorMessage('خطأ في المصادقة');
          return;
        }

        final success = await _releaseOrdersService.confirmDelivery(
          releaseOrderId: order.id,
          warehouseManagerId: currentUser.id,
          warehouseManagerName: currentUser.name,
          deliveryNotes: deliveryNotes.isNotEmpty ? deliveryNotes : null,
        );

        if (success) {
          _showSuccessMessage('تم تأكيد التسليم بنجاح');
          _loadReleaseOrders();
        } else {
          _showErrorMessage('فشل في تأكيد التسليم');
        }
      } catch (e) {
        _showErrorMessage('حدث خطأ: $e');
      }
    }
  }

  /// رفض أذن الصرف
  Future<void> _rejectReleaseOrder(WarehouseReleaseOrderModel order) async {
    final reason = await _showRejectDialog();
    if (reason != null && reason.isNotEmpty) {
      try {
        final currentUser = Provider.of<SupabaseProvider>(context, listen: false).user;
        if (currentUser == null) {
          _showErrorMessage('خطأ في المصادقة');
          return;
        }

        final success = await _releaseOrdersService.updateReleaseOrderStatus(
          releaseOrderId: order.id,
          newStatus: WarehouseReleaseOrderStatus.rejected,
          warehouseManagerId: currentUser.id,
          warehouseManagerName: currentUser.name,
          rejectionReason: reason,
        );

        if (success) {
          _showSuccessMessage('تم رفض أذن الصرف');
          _loadReleaseOrders();
        } else {
          _showErrorMessage('فشل في رفض أذن الصرف');
        }
      } catch (e) {
        _showErrorMessage('حدث خطأ: $e');
      }
    }
  }

  /// عرض حوار التأكيد
  Future<bool?> _showConfirmationDialog(
    String title,
    String message,
    String confirmText,
    Color confirmColor,
  ) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AccountantThemeConfig.cardBackground1,
        title: Text(
          title,
          style: AccountantThemeConfig.headlineSmall.copyWith(
            color: Colors.white,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.help_outline_rounded,
              color: confirmColor,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'إلغاء',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white70,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  /// عرض حوار الرفض
  Future<String?> _showRejectDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AccountantThemeConfig.cardBackground1,
        title: Text(
          'رفض أذن الصرف',
          style: AccountantThemeConfig.headlineSmall.copyWith(
            color: Colors.white,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cancel_rounded,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'يرجى إدخال سبب الرفض:',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'اكتب سبب الرفض هنا...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: Colors.red,
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'إلغاء',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white70,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('رفض'),
          ),
        ],
      ),
    );
  }

  /// عرض حوار تأكيد التسليم
  Future<String?> _showDeliveryConfirmationDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AccountantThemeConfig.cardBackground1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AccountantThemeConfig.largeBorderRadius),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AccountantThemeConfig.greenGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.done_all_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'تأكيد التسليم',
              style: AccountantThemeConfig.headlineSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'هل تؤكد تسليم هذا الطلب للعميل؟',
              style: AccountantThemeConfig.bodyLarge.copyWith(
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'ملاحظات التسليم (اختيارية):',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              maxLines: 3,
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white,
              ),
              decoration: InputDecoration(
                hintText: 'أدخل أي ملاحظات حول التسليم...',
                hintStyle: AccountantThemeConfig.bodyMedium.copyWith(
                  color: Colors.white54,
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: AccountantThemeConfig.primaryGreen,
                    width: 2,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: AccountantThemeConfig.primaryGreen.withOpacity(0.5),
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: AccountantThemeConfig.primaryGreen,
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'إلغاء',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white70,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AccountantThemeConfig.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('تأكيد التسليم'),
          ),
        ],
      ),
    );
  }

  /// عرض رسالة نجاح
  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AccountantThemeConfig.primaryGreen,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// عرض رسالة خطأ
  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// بناء حالة تحميل محسنة مع تأثيرات بصرية
  Widget _buildEnhancedLoadingState() {
    return Container(
      padding: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
      child: Column(
        children: [
          // Skeleton cards
          Expanded(
            child: ListView.builder(
              itemCount: 6,
              itemBuilder: (context, index) {
                return _buildSkeletonCard(index);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// بناء بطاقة هيكلية للتحميل
  Widget _buildSkeletonCard(int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: AccountantThemeConfig.defaultPadding),
      decoration: AccountantThemeConfig.primaryCardDecoration,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header skeleton
            Row(
              children: [
                _buildShimmerContainer(40, 40, isCircular: true),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildShimmerContainer(120, 16),
                      const SizedBox(height: 8),
                      _buildShimmerContainer(80, 14),
                    ],
                  ),
                ),
                _buildShimmerContainer(60, 20),
              ],
            ),

            const SizedBox(height: 16),

            // Content skeleton
            Row(
              children: [
                Expanded(child: _buildShimmerContainer(double.infinity, 12)),
                const SizedBox(width: 8),
                Expanded(child: _buildShimmerContainer(double.infinity, 12)),
                const SizedBox(width: 8),
                Expanded(child: _buildShimmerContainer(double.infinity, 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// بناء حاوية متحركة للتحميل
  Widget _buildShimmerContainer(double width, double height, {bool isCircular = false}) {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1 + (_fadeAnimation.value * 0.05)),
            borderRadius: BorderRadius.circular(isCircular ? height / 2 : 8),
          ),
        );
      },
    );
  }

  /// بناء حالة خطأ محسنة
  Widget _buildEnhancedErrorState(String error) {
    // Check if this is a database schema error
    final isDatabaseError = error.contains('PGRST200') ||
                           error.contains('relationship') ||
                           error.contains('schema cache');

    return Center(
      child: Container(
        margin: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
        padding: const EdgeInsets.all(24),
        decoration: AccountantThemeConfig.primaryCardDecoration.copyWith(
          border: Border.all(
            color: Colors.red.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Error icon with animation
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 1000),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Transform.scale(
                  scale: 0.8 + (value * 0.2),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(
                        color: Colors.red.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.error_outline_rounded,
                      color: Colors.red,
                      size: 48,
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            Text(
              isDatabaseError ? 'إعداد قاعدة البيانات مطلوب' : 'خطأ في التحميل',
              style: AccountantThemeConfig.headlineSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              isDatabaseError
                  ? 'يبدو أن جداول أذون الصرف غير موجودة في قاعدة البيانات.\nيرجى تطبيق migration قاعدة البيانات أولاً.'
                  : error,
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  onPressed: _loadReleaseOrders,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('إعادة المحاولة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AccountantThemeConfig.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: () {
                    // Copy error to clipboard
                    Clipboard.setData(ClipboardData(text: error));
                    _showSuccessMessage('تم نسخ تفاصيل الخطأ');
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('نسخ الخطأ'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white70,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// بناء حالة فارغة محسنة
  Widget _buildEnhancedEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(AccountantThemeConfig.defaultPadding),
        padding: const EdgeInsets.all(32),
        decoration: AccountantThemeConfig.primaryCardDecoration,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Empty state illustration
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 1200),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, -10 + (value * 10)),
                  child: Opacity(
                    opacity: value,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AccountantThemeConfig.primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(
                          color: AccountantThemeConfig.primaryGreen.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.local_shipping_outlined,
                        color: AccountantThemeConfig.primaryGreen,
                        size: 64,
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            Text(
              _searchQuery.isNotEmpty ? 'لا توجد نتائج' : 'لا توجد أذون صرف',
              style: AccountantThemeConfig.headlineSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              _searchQuery.isNotEmpty
                  ? 'لم يتم العثور على أذون صرف تطابق البحث'
                  : 'لم يتم إنشاء أي أذون صرف بعد.\nسيتم إنشاؤها تلقائياً عند الموافقة على الطلبات.',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),

            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                  });
                  _applyFilters();
                },
                icon: const Icon(Icons.clear_rounded),
                label: const Text('مسح البحث'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AccountantThemeConfig.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// عرض حوار مسح جميع البيانات
  Future<void> _showClearAllDataDialog() async {
    try {
      // عرض حوار التأكيد
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => ClearAllDataDialog(
            requestCount: _releaseOrders.length,
            onConfirm: () async {
              Navigator.of(context).pop(); // إغلاق الحوار
              await _clearAllReleaseOrders();
            },
            onCancel: () {
              Navigator.of(context).pop(); // إغلاق الحوار
            },
          ),
        );
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في عرض حوار مسح البيانات: $e');
      if (mounted) {
        _showErrorMessage('خطأ في تحميل بيانات الأذون');
      }
    }
  }

  /// مسح جميع أذون الصرف
  Future<void> _clearAllReleaseOrders() async {
    try {
      // عرض مؤشر التحميل
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: AccountantThemeConfig.cardBackground1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AccountantThemeConfig.largeBorderRadius),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AccountantThemeConfig.primaryGreen),
                ),
                const SizedBox(height: 16),
                Text(
                  'جاري مسح جميع أذون الصرف...',
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'يتم التنظيف من جميع المصادر\nيرجى الانتظار، لا تغلق التطبيق',
                  textAlign: TextAlign.center,
                  style: AccountantThemeConfig.bodySmall.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      AppLogger.info('🗑️ بدء مسح شامل لجميع أذون الصرف...');

      // استخدام الدالة الجديدة للمسح الشامل
      final success = await _releaseOrdersService.clearAllReleaseOrders();

      // إغلاق مؤشر التحميل
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (success) {
        // إعادة تحميل البيانات للتأكد من المسح الكامل
        await _loadReleaseOrders();

        // التحقق من النتيجة النهائية
        if (_releaseOrders.isEmpty) {
          _showSuccessMessage('تم مسح جميع أذون الصرف بنجاح\nتم التنظيف من جميع المصادر');
          AppLogger.info('✅ تم المسح الشامل بنجاح - لا توجد أذون صرف متبقية');
        } else {
          _showWarningMessage('تم مسح معظم أذون الصرف\nتبقى ${_releaseOrders.length} أذن صرف');
          AppLogger.warning('⚠️ تبقى ${_releaseOrders.length} أذن صرف بعد المسح');
        }
      } else {
        _showErrorMessage('فشل في مسح أذون الصرف\nيرجى المحاولة مرة أخرى');
        AppLogger.error('❌ فشل في المسح الشامل');
      }
    } catch (e) {
      // إغلاق مؤشر التحميل في حالة الخطأ
      if (mounted) {
        Navigator.of(context).pop();
      }
      _showErrorMessage('حدث خطأ أثناء مسح البيانات: $e');
      AppLogger.error('❌ خطأ في مسح أذون الصرف: $e');
    }
  }

  /// عرض رسالة تحذير
  void _showWarningMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: AccountantThemeConfig.warningOrange,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }
}
