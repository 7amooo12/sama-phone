import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/client_orders_provider.dart';
import '../../utils/app_logger.dart';

/// شاشة عرض تاريخ الطلب والإشعارات
class OrderHistoryScreen extends StatefulWidget {

  const OrderHistoryScreen({
    super.key,
    required this.orderId,
    required this.orderNumber,
  });
  final String orderId;
  final String orderNumber;

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _orderHistory = [];
  final List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final orderProvider = Provider.of<ClientOrdersProvider>(context, listen: false);
      
      // جلب تاريخ الطلب
      _orderHistory = await orderProvider.getOrderHistory(widget.orderId);
      
      // جلب الإشعارات المتعلقة بالطلب (يمكن تحسينها لاحقاً)
      // _notifications = await orderProvider.getOrderNotifications(widget.orderId);
      
      AppLogger.info('✅ تم تحميل تاريخ الطلب: ${_orderHistory.length} سجل');
    } catch (e) {
      AppLogger.error('❌ خطأ في تحميل البيانات: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'تاريخ الطلب ${widget.orderNumber}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(
              icon: Icon(Icons.history),
              text: 'تاريخ الطلب',
            ),
            Tab(
              icon: Icon(Icons.notifications),
              text: 'الإشعارات',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('جاري تحميل البيانات...'),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOrderHistoryTab(),
                _buildNotificationsTab(),
              ],
            ),
    );
  }

  Widget _buildOrderHistoryTab() {
    if (_orderHistory.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'لا يوجد تاريخ متاح للطلب',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _orderHistory.length,
        itemBuilder: (context, index) {
          final historyItem = _orderHistory[index];
          return _buildHistoryCard(historyItem);
        },
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> historyItem) {
    final theme = Theme.of(context);
    final action = historyItem['action'] ?? '';
    final description = historyItem['description'] ?? '';
    final changedBy = historyItem['changed_by_name'] ?? 'النظام';
    final changedByRole = historyItem['changed_by_role'] ?? '';
    final createdAt = DateTime.parse(historyItem['created_at']);
    final oldStatus = historyItem['old_status'];
    final newStatus = historyItem['new_status'];

    // تحديد الأيقونة واللون حسب نوع العملية
    IconData icon;
    Color iconColor;
    
    switch (action) {
      case 'created':
        icon = Icons.add_circle;
        iconColor = Colors.green;
        break;
      case 'status_changed':
        icon = Icons.update;
        iconColor = Colors.blue;
        break;
      case 'payment_updated':
        icon = Icons.payment;
        iconColor = Colors.orange;
        break;
      case 'assigned':
        icon = Icons.person_add;
        iconColor = Colors.purple;
        break;
      case 'tracking_added':
        icon = Icons.link;
        iconColor = Colors.teal;
        break;
      case 'cancelled':
        icon = Icons.cancel;
        iconColor = Colors.red;
        break;
      case 'completed':
        icon = Icons.check_circle;
        iconColor = Colors.green;
        break;
      default:
        icon = Icons.info;
        iconColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // الأيقونة
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 24,
              ),
            ),
            
            const SizedBox(width: 12),
            
            // المحتوى
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // الوصف
                  Text(
                    description,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  
                  // تفاصيل التغيير
                  if (oldStatus != null && newStatus != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            oldStatus,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            newStatus,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  
                  const SizedBox(height: 8),
                  
                  // معلومات المستخدم والوقت
                  Row(
                    children: [
                      Icon(
                        Icons.person,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$changedBy${changedByRole.isNotEmpty ? ' ($changedByRole)' : ''}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('dd/MM/yyyy HH:mm').format(createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
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

  Widget _buildNotificationsTab() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'الإشعارات قيد التطوير',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'سيتم إضافة هذه الميزة قريباً',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
