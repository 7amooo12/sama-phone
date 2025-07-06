import 'package:flutter/material.dart';
import '../services/smart_order_api.dart';
import '../widgets/dashboard_chart.dart';
import 'package:intl/intl.dart' as intl;
import 'dart:io';

class OrdersDashboardScreen extends StatefulWidget {
  const OrdersDashboardScreen({super.key});

  @override
  _OrdersDashboardScreenState createState() => _OrdersDashboardScreenState();
}

class _OrdersDashboardScreenState extends State<OrdersDashboardScreen> {
  final SmartOrderApiService _apiService = SmartOrderApiService();
  bool _isLoading = true;
  String? _error;
  OrdersAnalyticsModel? _analytics;
  bool _isRetrying = false;
  
  // فلترة
  String? _selectedStatus;
  int _selectedDays = 30;
  String? _searchQuery;
  int? _selectedWarehouseId;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final analytics = await _apiService.getOrdersAnalytics(
        status: _selectedStatus,
        days: _selectedDays,
        search: _searchQuery,
        warehouseId: _selectedWarehouseId,
      );
      
      if (mounted) {
        setState(() {
          _analytics = analytics;
          _isLoading = false;
          _isRetrying = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          String errorMessage = e.toString();
          
          // تحسين رسائل الخطأ لتكون أكثر وضوحاً للمستخدم
          if (e is SocketException || errorMessage.contains('SocketException')) {
            errorMessage = 'لا يمكن الاتصال بالخادم. يرجى التحقق من اتصالك بالإنترنت والمحاولة مرة أخرى.';
          } else if (errorMessage.contains('timed out')) {
            errorMessage = 'انتهت مهلة الاتصال بالخادم. يرجى المحاولة مرة أخرى لاحقاً.';
          } else if (errorMessage.contains('Unauthorized')) {
            errorMessage = 'غير مصرح لك بالوصول إلى هذه البيانات. يرجى تسجيل الدخول مرة أخرى.';
          }
          
          _error = errorMessage;
          _isLoading = false;
          _isRetrying = false;
        });
      }
    }
  }

  // محاولة إعادة الاتصال تلقائياً
  Future<void> _retryWithDelay() async {
    if (_isRetrying) return;
    
    setState(() {
      _isRetrying = true;
    });
    
    // انتظر 3 ثوان قبل إعادة المحاولة
    await Future.delayed(const Duration(seconds: 3));
    _fetchData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة الطلبات', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchData,
            tooltip: 'تحديث البيانات',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'جاري تحميل البيانات...',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            )
          : _error != null
              ? _buildErrorView()
              : _buildDashboard(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 24),
            const Text(
              'حدثت مشكلة أثناء تحميل البيانات',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                _error!,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isRetrying ? null : _fetchData,
              icon: const Icon(Icons.refresh),
              label: Text(_isRetrying ? 'جاري إعادة المحاولة...' : 'إعادة المحاولة'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
            ),
            if (!_isRetrying) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: _retryWithDelay,
                child: const Text('إعادة المحاولة تلقائياً بعد 3 ثوان'),
              ),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('العودة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    if (_analytics == null) {
      return const Center(child: Text('لا توجد بيانات'));
    }

    return RefreshIndicator(
      onRefresh: _fetchData,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFilters(),
              const SizedBox(height: 24),
              _buildStatsSummary(),
              const SizedBox(height: 24),
              _buildDailyOrdersChart(),
              const SizedBox(height: 24),
              _buildOrdersList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    if (_analytics == null || _analytics!.filters.isEmpty) {
      return const SizedBox.shrink();
    }
    
    final List<String> statuses = List<String>.from(_analytics!.filters['statuses']);
    final List<Map<String, dynamic>> warehouses = List<Map<String, dynamic>>.from(
      _analytics!.filters['warehouses'].map((w) => Map<String, dynamic>.from(w))
    );
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'تصفية النتائج',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                // حقل البحث
                SizedBox(
                  width: 200,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'بحث...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (value) {
                      _searchQuery = value.isEmpty ? null : value;
                    },
                    onSubmitted: (_) => _fetchData(),
                  ),
                ),
                
                // اختيار الحالة
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'الحالة',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    value: _selectedStatus,
                    onChanged: (value) {
                      setState(() {
                        _selectedStatus = value;
                      });
                      _fetchData();
                    },
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('جميع الحالات'),
                      ),
                      ...statuses.map((status) => DropdownMenuItem(
                        value: status,
                        child: Text(status),
                      )),
                    ],
                  ),
                ),
                
                // اختيار المستودع
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<int?>(
                    decoration: InputDecoration(
                      labelText: 'المستودع',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    value: _selectedWarehouseId,
                    onChanged: (value) {
                      setState(() {
                        _selectedWarehouseId = value;
                      });
                      _fetchData();
                    },
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('جميع المستودعات'),
                      ),
                      ...warehouses.map((warehouse) => DropdownMenuItem(
                        value: warehouse['id'],
                        child: Text(warehouse['name']),
                      )),
                    ],
                  ),
                ),
                
                // اختيار الفترة الزمنية
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<int>(
                    decoration: InputDecoration(
                      labelText: 'الفترة الزمنية',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    value: _selectedDays,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedDays = value;
                        });
                        _fetchData();
                      }
                    },
                    items: const [
                      DropdownMenuItem(value: 7, child: Text('آخر 7 أيام')),
                      DropdownMenuItem(value: 30, child: Text('آخر 30 يوم')),
                      DropdownMenuItem(value: 90, child: Text('آخر 3 أشهر')),
                      DropdownMenuItem(value: 365, child: Text('آخر سنة')),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSummary() {
    if (_analytics == null) {
      return const SizedBox.shrink();
    }
    
    final orderStats = _analytics!.stats['orders'];
    final customerStats = _analytics!.stats['customers'];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ملخص الإحصائيات',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.5,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildStatCard(
              'إجمالي الطلبات',
              orderStats['total'].toString(),
              Colors.blue,
              Icons.shopping_bag,
            ),
            _buildStatCard(
              'متوسط وقت الإنجاز',
              '${orderStats['avg_completion_days']} يوم',
              Colors.amber,
              Icons.timer,
            ),
            _buildStatCard(
              'عدد العملاء',
              customerStats['total'].toString(),
              Colors.green,
              Icons.people,
            ),
            _buildStatCard(
              'الطلبات لكل عميل',
              customerStats['orders_per_customer'].toString(),
              Colors.purple,
              Icons.person_outline,
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'الطلبات حسب الحالة',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildStatusBreakdown(),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Icon(icon, color: color),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBreakdown() {
    if (_analytics == null) {
      return const SizedBox.shrink();
    }
    
    final byStatus = _analytics!.stats['orders']['by_status'] as Map<String, dynamic>;
    final total = _analytics!.stats['orders']['total'] as int;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: byStatus.entries.map((entry) {
            final status = entry.key;
            final count = entry.value as int;
            final percentage = total > 0 ? (count / total * 100).toStringAsFixed(1) : '0';
            
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        status,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text('$count ($percentage%)'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: total > 0 ? count / total : 0,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation(_getColorForStatus(status)),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Color _getColorForStatus(String status) {
    switch (status) {
      case 'قيد المعالجة':
        return Colors.blue;
      case 'تحت التصنيع':
        return Colors.orange;
      case 'تم التجهيز':
        return Colors.green;
      case 'تم التسليم':
        return Colors.purple;
      case 'تالف / هوالك':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildDailyOrdersChart() {
    if (_analytics == null) {
      return const SizedBox.shrink();
    }
    
    final dailyOrders = List<Map<String, dynamic>>.from(_analytics!.stats['daily_orders']);
    
    if (dailyOrders.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // تجهيز البيانات للرسم البياني
    dailyOrders.sort((a, b) => a['date'].compareTo(b['date']));
    
    final List<double> values = dailyOrders.map((day) => (day['orders'] as int).toDouble()).toList();
    final List<String> labels = dailyOrders.map((day) {
      final date = DateTime.parse(day['date']);
      return intl.DateFormat('MM/dd').format(date);
    }).toList();
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'الطلبات اليومية',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            AspectRatio(
              aspectRatio: 1.7,
              child: DashboardChart(
                values: values,
                labels: labels,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersList() {
    if (_analytics == null || _analytics!.orders.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: Colors.grey,
              ),
              SizedBox(height: 16),
              Text(
                'لا توجد طلبات مطابقة للفلتر',
                style: TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'حاول تغيير معايير البحث أو إزالة الفلاتر',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'أحدث الطلبات',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _analytics!.orders.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final order = _analytics!.orders[index];
            return _buildOrderListItem(order);
          },
        ),
      ],
    );
  }

  Widget _buildOrderListItem(Map<String, dynamic> order) {
    // تنسيق التاريخ
    final createdAt = DateTime.parse(order['created_at']);
    final formattedDate = intl.DateFormat('dd/MM/yyyy HH:mm').format(createdAt);
    
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getColorForStatus(order['status']),
          child: Text(
            '${order['progress']}%',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
        title: Text(
          '${order['order_number']} - ${order['customer_name']}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('الحالة: ${order['status']}'),
            Text('المستودع: ${order['warehouse_name']}'),
            Text('التاريخ: $formattedDate'),
            // Display items count if available, changed to make it clear that items details are available
            order['items'] != null && order['items'] is List ? 
              Text('العناصر: ${(order['items'] as List).length} (مع التفاصيل)') :
              Text('العناصر: ${order['items_count']} (انقر للتفاصيل)'),
          ],
        ),
        isThreeLine: true,
        onTap: () {
          _showOrderDetails(order['id']);
        },
      ),
    );
  }

  Future<void> _showOrderDetails(int orderId) async {
    try {
      // عرض مؤشر التحميل
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('جاري تحميل تفاصيل الطلب...'),
              ],
            ),
          );
        },
      );
      
      // Always fetch detailed order information when showing order details
      final orderDetail = await _apiService.getOrderDetail(orderId);
      
      // إغلاق مؤشر التحميل
      if (mounted) {
        Navigator.of(context).pop();
      }
      
      // عرض تفاصيل الطلب
      if (mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (context) {
            final order = orderDetail.order;
            return Container(
              padding: const EdgeInsets.all(16),
              height: MediaQuery.of(context).size.height * 0.8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'تفاصيل الطلب #${order['order_number']}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView(
                      children: [
                        _buildDetailItem('العميل', order['customer']['name']),
                        _buildDetailItem('الهاتف', order['customer']['phone']),
                        _buildDetailItem('البريد الإلكتروني', order['customer']['email']),
                        _buildDetailItem('العنوان', order['customer']['address']),
                        _buildDetailItem('المستودع', order['warehouse']['name']),
                        _buildDetailItem('الحالة', order['status']),
                        _buildDetailItem('تاريخ الإنشاء', _formatDate(order['created_at'])),
                        if (order['delivery_date'] != null)
                          _buildDetailItem('تاريخ التسليم المتوقع', _formatDate(order['delivery_date'])),
                        if (order['completed_at'] != null)
                          _buildDetailItem('تاريخ الإكمال', _formatDate(order['completed_at'])),
                        _buildDetailItem('نسبة الإكمال', '${order['overall_progress']}%'),
                        
                        const SizedBox(height: 16),
                        const Text('العناصر', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const Divider(),
                        
                        ...List.generate(
                          order['items'].length,
                          (index) {
                            final item = order['items'][index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['name'],
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8),
                                    Text('الكمية: ${item['quantity_completed']}/${item['quantity_requested']}'),
                                    Text('التقدم: ${item['progress']}%'),
                                    if (item['worker_name'] != null)
                                      Text('العامل: ${item['worker_name']}'),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      }
    } catch (e) {
      // إغلاق مؤشر التحميل إذا كان مفتوحاً
      Navigator.of(context, rootNavigator: true).pop();
      
      // عرض رسالة الخطأ
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في تحميل تفاصيل الطلب: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'إعادة المحاولة',
            onPressed: () => _showOrderDetails(orderId),
            textColor: Colors.white,
          ),
        ),
      );
    }
  }
  
  String _formatDate(String dateStr) {
    final date = DateTime.parse(dateStr);
    // Convert to local time if UTC to ensure proper timezone handling
    final localDate = date.isUtc ? date.toLocal() : date;
    return intl.DateFormat('dd/MM/yyyy HH:mm').format(localDate);
  }
  
  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
} 