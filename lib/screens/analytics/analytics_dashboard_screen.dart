import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../models/analytics_dashboard_model.dart';
import '../../services/analytics_service.dart';
import '../../services/auth_service.dart';
import '../../utils/logger.dart';

class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AnalyticsDashboardScreen> createState() => _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> {
  final AnalyticsService _analyticsService = AnalyticsService();
  final AuthService _authService = AuthService();
  final AppLogger _logger = AppLogger();
  late Future<AnalyticsDashboardModel> _analyticsFuture;
  bool _isAdminOrOwner = false;
  final _currencyFormat = NumberFormat.currency(
    locale: 'ar_EG',
    symbol: '\$',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _checkUserRole();
    _loadAnalytics();
  }
  
  Future<void> _checkUserRole() async {
    final user = await _authService.getCurrentUser();
    if (user != null) {
      setState(() {
        // Admin or business owner roles should use the admin dashboard API
        _isAdminOrOwner = user.isAdmin || user.role == 'owner';
      });
      _logger.i('User is admin or owner: $_isAdminOrOwner');
      _loadAnalytics();
    }
  }
  
  void _loadAnalytics() {
    _logger.i('Loading analytics, isAdminOrOwner: $_isAdminOrOwner');
    setState(() {
      if (_isAdminOrOwner) {
        // Use admin dashboard API with API key protection
        _analyticsFuture = _analyticsService.getAdminDashboardAnalytics();
        _logger.i('Using admin dashboard analytics endpoint');
      } else {
        // Use regular analytics API
        _analyticsFuture = _analyticsService.getDashboardAnalytics();
        _logger.i('Using regular dashboard analytics endpoint');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      // دعم RTL للغة العربية
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('التحليلات والإحصائيات'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                _loadAnalytics();
              },
            ),
          ],
        ),
        body: FutureBuilder<AnalyticsDashboardModel>(
          future: _analyticsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 60, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'حدث خطأ أثناء تحميل البيانات\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        _loadAnalytics();
                      },
                      child: Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              );
            } else if (!snapshot.hasData) {
              return const Center(
                child: Text('لا توجد بيانات متاحة'),
              );
            }

            final analytics = snapshot.data!;
            return _buildDashboard(analytics);
          },
        ),
      ),
    );
  }

  Widget _buildDashboard(AnalyticsDashboardModel analytics) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeaderSection(analytics),
        const SizedBox(height: 20),
        _buildSummaryCards(analytics),
        const SizedBox(height: 24),
        _buildSalesChart(analytics.sales),
        const SizedBox(height: 24),
        _buildCategorySalesChart(analytics.sales),
        // Show inventory movement stats if available (admin dashboard API)
        if (analytics.inventory != null) ...[
          const SizedBox(height: 24),
          _buildInventoryMovementSection(analytics.inventory!),
        ],
        const SizedBox(height: 24),
        _buildProductsSection(analytics.products),
      ],
    );
  }
  
  Widget _buildHeaderSection(AnalyticsDashboardModel analytics) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).primaryColor.withOpacity(0.8),
              Theme.of(context).primaryColor,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'لوحة التحليلات',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _isAdminOrOwner ? 'مسؤول النظام' : 'مستخدم',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'نظرة عامة على أداء المتجر وحركة المبيعات',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: _buildHeaderStat(
                    title: 'إجمالي المبيعات',
                    value: _currencyFormat.format(analytics.sales.totalAmount),
                    icon: Icons.monetization_on,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildHeaderStat(
                    title: 'إجمالي المنتجات',
                    value: '${analytics.products.total}',
                    icon: Icons.inventory_2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHeaderStat({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(AnalyticsDashboardModel analytics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ملخص الأداء',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'المبيعات المكتملة',
                value: '${analytics.sales.completedInvoices}',
                icon: Icons.check_circle,
                color: Colors.green,
                subtitle: _currencyFormat.format(analytics.sales.totalAmount),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                title: 'المنتجات',
                value: '${analytics.products.total}',
                icon: Icons.inventory,
                color: Colors.blue,
                subtitle: '${analytics.products.outOfStock} نفذ من المخزون',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'المستخدمين',
                value: '${analytics.users.total}',
                icon: Icons.people,
                color: Colors.purple,
                subtitle: '${analytics.users.active} مستخدم نشط',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                title: 'الطلبات المعلقة',
                value: '${analytics.sales.pendingInvoices}',
                icon: Icons.pending_actions,
                color: Colors.orange,
                subtitle: 'بانتظار التنفيذ',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesChart(SalesStats salesStats) {
    // ترتيب البيانات من الأقدم للأحدث
    final dailyData = List<DailySales>.from(salesStats.daily);
    dailyData.sort((a, b) => a.date.compareTo(b.date));
    
    // التحقق من وجود مبيعات
    bool hasSales = dailyData.any((day) => day.sales > 0);
    
    if (!hasSales) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'المبيعات خلال آخر 7 أيام',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 200,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.show_chart, size: 60, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد مبيعات مسجلة خلال هذه الفترة',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // تهيئة بيانات الرسم البياني
    final spots = dailyData.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.sales);
    }).toList();

    // تهيئة أسماء الأيام للعرض
    final dateLabels = dailyData.map((e) {
      final date = DateTime.parse(e.date);
      return '${date.day}/${date.month}';
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'المبيعات خلال الأيام الماضية',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 250,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: true,
                horizontalInterval: 100,
                verticalInterval: 1,
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      if (value < 0 || value >= dateLabels.length || value % 3 != 0) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          dateLabels[value.toInt()],
                          style: const TextStyle(
                            color: Color(0xff68737d),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toInt().toString(),
                        style: const TextStyle(
                          color: Color(0xff68737d),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
                    },
                    reservedSize: 45,
                  ),
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: const Color(0xff37434d), width: 1),
              ),
              minX: 0,
              maxX: spots.length - 1.0,
              minY: 0,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: Theme.of(context).primaryColor,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Theme.of(context).primaryColor.withOpacity(0.2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySalesChart(SalesStats salesStats) {
    // تهيئة بيانات الرسم البياني
    final categorySales = salesStats.byCategory.toList();
    
    // التحقق من وجود مبيعات للفئات
    bool hasCategorySales = categorySales.any((category) => category.sales > 0);
    
    if (!hasCategorySales) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'توزيع المبيعات حسب الفئات',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 200,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pie_chart_outline, size: 60, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد مبيعات مسجلة للفئات',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    
    // ترتيب الفئات تنازلياً بحسب المبيعات
    categorySales.sort((a, b) => b.sales.compareTo(a.sales));
    
    // أخذ أعلى 5 فئات مبيعاً فقط إذا كان هناك أكثر من 5
    final topCategories = categorySales.length > 5
        ? categorySales.sublist(0, 5)
        : categorySales;
    
    // إزالة الفئات التي لا تحتوي على مبيعات
    final categoriesWithSales = topCategories.where((category) => category.sales > 0).toList();
    
    if (categoriesWithSales.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'توزيع المبيعات حسب الفئات',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 200,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pie_chart_outline, size: 60, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد مبيعات مسجلة للفئات',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    
    // حساب إجمالي المبيعات للحصول على النسب المئوية
    final totalCategorySales = categoriesWithSales.fold<double>(
        0, (sum, item) => sum + item.sales);
    
    // تهيئة بيانات PieChart
    final sections = categoriesWithSales.map((category) {
      final percentage = totalCategorySales > 0
          ? (category.sales / totalCategorySales) * 100
          : 0.0;
          
      // إنشاء لون عشوائي لكل فئة
      final color = Color.fromARGB(
        255,
        100 + (category.hashCode % 155),
        100 + ((category.hashCode * 2) % 155),
        100 + ((category.hashCode * 3) % 155),
      );
      
      return PieChartSectionData(
        value: category.sales,
        title: '${percentage.toStringAsFixed(1)}%',
        radius: 100,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        color: color,
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'توزيع المبيعات حسب الفئات',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 300,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Expanded(
                child: PieChart(
                  PieChartData(
                    sections: sections,
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    startDegreeOffset: 180,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: categoriesWithSales.asMap().entries.map((entry) {
                  final category = entry.value;
                  final color = Color.fromARGB(
                    255,
                    100 + (category.hashCode % 155),
                    100 + ((category.hashCode * 2) % 155),
                    100 + ((category.hashCode * 3) % 155),
                  );
                  
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${category.category}: ${_currencyFormat.format(category.sales)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Build a new section for inventory movement data
  Widget _buildInventoryMovementSection(InventoryStats inventory) {
    final movement = inventory.movement;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'حركة المخزون',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildMovementStat(
                        title: 'الإضافات',
                        value: movement.additions.toString(),
                        icon: Icons.add_circle,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMovementStat(
                        title: 'المسحوبات',
                        value: movement.reductions.toString(),
                        icon: Icons.remove_circle,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildMovementStat(
                  title: 'إجمالي التغيير في المخزون',
                  value: movement.totalQuantityChange.toString(),
                  icon: Icons.sync,
                  color: movement.totalQuantityChange >= 0 ? Colors.blue : Colors.orange,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildMovementStat({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildProductsSection(ProductStats productStats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'إحصائيات المنتجات',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildProductStat(
                  title: 'إجمالي المنتجات',
                  value: productStats.total.toString(),
                  icon: Icons.inventory_2,
                  color: Colors.blue,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Divider(),
                ),
                _buildProductStat(
                  title: 'المنتجات المرئية',
                  value: productStats.visible.toString(),
                  icon: Icons.visibility,
                  color: Colors.green,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Divider(),
                ),
                _buildProductStat(
                  title: 'نفذ من المخزون',
                  value: productStats.outOfStock.toString(),
                  icon: Icons.warning,
                  color: Colors.orange,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Divider(),
                ),
                _buildProductStat(
                  title: 'المنتجات المميزة',
                  value: productStats.featured.toString(),
                  icon: Icons.star,
                  color: Colors.amber,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildProductStat({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
} 