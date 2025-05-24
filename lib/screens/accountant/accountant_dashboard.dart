import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/config/routes.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:smartbiztracker_new/services/flask_api_service.dart';
import 'package:smartbiztracker_new/widgets/admin/order_management_widget.dart';
import 'package:smartbiztracker_new/widgets/common/custom_app_bar.dart';
import 'package:smartbiztracker_new/widgets/common/main_drawer.dart';
import 'package:smartbiztracker_new/screens/accountant/accountant_invoices_screen.dart';
import 'package:smartbiztracker_new/screens/accountant/accountant_products_screen.dart';
import 'package:smartbiztracker_new/widgets/accountant/invoice_summary_widget.dart';
import 'package:smartbiztracker_new/utils/style_system.dart';
import 'package:smartbiztracker_new/services/invoice_service.dart';
import 'package:smartbiztracker_new/models/flask_invoice_model.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

class AccountantDashboard extends StatefulWidget {
  const AccountantDashboard({super.key});

  @override
  State<AccountantDashboard> createState() => _AccountantDashboardState();
}

class _AccountantDashboardState extends State<AccountantDashboard> with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late TabController _tabController;
  int _selectedIndex = 0;
  DateTime? _lastBackPressTime; // لتتبع آخر ضغطة على زر العودة
  
  // بيانات للإحصائيات المالية والرسوم البيانية
  bool _isLoading = true;
  List<FlaskInvoiceModel> _recentInvoices = [];
  Map<String, double> _revenueByCategory = {};
  double _totalRevenue = 0;
  double _totalPending = 0;
  double _totalTax = 0;
  int _totalInvoices = 0;
  int _pendingInvoices = 0;
  int _paidInvoices = 0;
  int _canceledInvoices = 0;
  
  // تنسيق العملة والتاريخ
  final _currencyFormat = NumberFormat.currency(symbol: 'جنيه ', decimalDigits: 2);
  final _dateFormat = DateFormat('yyyy-MM-dd');
  final _invoiceService = InvoiceService();
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedIndex = _tabController.index;
      });
    });
    
    // تحميل البيانات المالية عند بدء الشاشة
    _loadFinancialData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // تحميل البيانات المالية من API
  Future<void> _loadFinancialData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // جلب الفواتير
      final invoices = await _invoiceService.getInvoices();
      
      // حساب الإحصائيات المالية
      double totalRevenue = 0;
      double totalPending = 0;
      double totalTax = 0;
      int pendingCount = 0;
      int paidCount = 0;
      int canceledCount = 0;
      Map<String, double> categoryRevenue = {};
      
      for (var invoice in invoices) {
        // إجمالي المبيعات
        totalRevenue += invoice.finalAmount;
        
        // إحصاءات حسب الحالة
        if (invoice.status == 'pending') {
          pendingCount++;
          totalPending += invoice.finalAmount;
        } else if (invoice.status == 'completed') {
          paidCount++;
        } else if (invoice.status == 'cancelled') {
          canceledCount++;
        }
        
        // احتساب الضريبة (افتراضياً 15%)
        totalTax += invoice.finalAmount * 0.15;
        
        // تصنيف الإيرادات حسب الفئة (إذا كانت متوفرة)
        if (invoice.items != null && invoice.items!.isNotEmpty) {
          for (var item in invoice.items!) {
            final category = item.category ?? 'أخرى';
            categoryRevenue[category] = (categoryRevenue[category] ?? 0) + item.total;
          }
        }
      }
      
      // حفظ البيانات المحسوبة في حالة الـ State
      setState(() {
        _recentInvoices = List.from(invoices)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        if (_recentInvoices.length > 5) {
          _recentInvoices = _recentInvoices.sublist(0, 5);
        }
        
        _totalRevenue = totalRevenue;
        _totalPending = totalPending;
        _totalTax = totalTax;
        _totalInvoices = invoices.length;
        _pendingInvoices = pendingCount;
        _paidInvoices = paidCount;
        _canceledInvoices = canceledCount;
        _revenueByCategory = categoryRevenue;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('خطأ في تحميل البيانات المالية: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Navigate to create new invoice
  void _navigateToAddInvoice() {
    Navigator.of(context).pushNamed(AppRoutes.createInvoice);
  }
  
  // Navigate to sales reports
  void _navigateToSalesReports() {
    Navigator.of(context).pushNamed(AppRoutes.salesReports);
  }
  
  // Navigate to tax management
  void _navigateToTaxManagement() {
    Navigator.of(context).pushNamed(AppRoutes.taxManagement);
  }
  
  // منطق التعامل مع زر العودة
  Future<bool> _onWillPop() async {
    // إذا كان مفتوح الدرج الجانبي، أغلقه عند الضغط على العودة بدلاً من إغلاق التطبيق
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
      return false;
    }
    
    // إذا كنا في شاشة غير الشاشة الرئيسية، عد إلى الشاشة الرئيسية بدلاً من إغلاق التطبيق
    if (_selectedIndex != 0) {
      _tabController.animateTo(0);
      return false;
    }
    
    // في الشاشة الرئيسية، يتطلب ضغطتين متتاليتين خلال ثانيتين للخروج من التطبيق
    final now = DateTime.now();
    if (_lastBackPressTime == null || 
        now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اضغط مرة أخرى للخروج من التطبيق'),
          duration: Duration(seconds: 2),
        ),
      );
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final supabaseProvider = Provider.of<SupabaseProvider>(context);
    final userModel = supabaseProvider.user;

    if (userModel == null) {
      // Handle case where user is not logged in
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      });
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Directionality(
        textDirection: Directionality.of(context),
      child: Scaffold(
        key: _scaffoldKey,
        appBar: CustomAppBar(
          title: 'لوحة تحكم المحاسب',
            // إضافة زر القائمة في الجهة اليمنى (اليسرى في واجهة RTL)
            leading: IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await FlaskApiService().logout();
                supabaseProvider.signOut();
                if (mounted) {
                  Navigator.of(context).pushReplacementNamed(AppRoutes.login);
                }
              },
              tooltip: 'تسجيل الخروج',
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.05),
                border: Border(
                  bottom: BorderSide(
                    color: theme.dividerColor,
                    width: 0.5,
                  ),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: theme.primaryColor,
                unselectedLabelColor: Colors.grey,
                indicatorColor: theme.primaryColor,
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(
                    icon: Icon(Icons.dashboard),
                    text: 'الرئيسية',
                  ),
                    Tab(
                      icon: Icon(Icons.receipt_long),
                      text: 'الفواتير',
                    ),
                  Tab(
                    icon: Icon(Icons.shopping_cart),
                    text: 'الطلبات',
                  ),
                  Tab(
                    icon: Icon(Icons.inventory),
                    text: 'المنتجات',
                  ),
                ],
              ),
            ),
          ),
        ),
        drawer: MainDrawer(
          onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
          currentRoute: AppRoutes.accountantDashboard,
        ),
        body: SafeArea(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Dashboard tab
              _buildDashboardTab(theme, userModel.name),
                
                // Invoices tab
                AccountantInvoicesScreen.withProviders(),
              
              // Orders tab - using Admin's order management with all features
              OrderManagementWidget(
                userRole: 'accountant',
                showHeader: false,
                showSearchBar: true,
                showFilterOptions: true,
                showStatusFilters: true,
                showStatusFilter: true,
                showDateFilter: true,
                isEmbedded: true,
              ),
              
              // Products tab
              const AccountantProductsScreen(),
            ],
            ),
          ),
        ),
      ),
    );
  }

  // Dashboard tab content with CustomScrollView for flexible layout
  Widget _buildDashboardTab(ThemeData theme, String userName) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadFinancialData,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
      slivers: [
        // Welcome section
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.primaryColor,
                          theme.colorScheme.secondary,
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: StyleSystem.shadowSmall,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.white.withOpacity(0.9),
                        child: const Icon(Icons.account_balance_wallet, color: Colors.indigo),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'مرحباً $userName',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                                      'نظرة عامة على الأداء المالي اليومي',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildQuickActionButton(
                        'إضافة فاتورة', 
                        Icons.add_chart, 
                        Colors.white,
                        _navigateToAddInvoice,
                      ),
                      _buildQuickActionButton(
                        'تقرير مبيعات', 
                        Icons.bar_chart, 
                        Colors.white,
                        _navigateToSalesReports,
                      ),
                      _buildQuickActionButton(
                        'الضرائب', 
                        Icons.account_balance, 
                        Colors.white,
                        _navigateToTaxManagement,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        
                // KPI Cards for key financial metrics
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        const Text(
                          'مؤشرات الأداء الرئيسية',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildKpiCard(
                                'إجمالي المبيعات',
                                _currencyFormat.format(_totalRevenue),
                                Icons.payments,
                                Colors.green.shade700,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildKpiCard(
                                'مبالغ معلقة',
                                _currencyFormat.format(_totalPending),
                                Icons.pending_actions,
                                Colors.orange.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildKpiCard(
                                'إجمالي الضرائب',
                                _currencyFormat.format(_totalTax),
                                Icons.account_balance,
                                Colors.indigo.shade700,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildKpiCard(
                                'فواتير مكتملة',
                                '$_paidInvoices/$_totalInvoices',
                                Icons.check_circle,
                                Colors.teal.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Revenue Breakdown Chart
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'توزيع الإيرادات حسب الفئة',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                _buildPieChart(),
                                const SizedBox(height: 16),
                                _buildChartLegend(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Invoice Status Summary
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ملخص حالة الفواتير',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildInvoiceStatusItem(
                                  'مكتملة',
                                  _paidInvoices,
                                  Colors.green,
                                ),
                                _buildInvoiceStatusItem(
                                  'معلقة',
                                  _pendingInvoices,
                                  Colors.orange,
                                ),
                                _buildInvoiceStatusItem(
                                  'ملغاة',
                                  _canceledInvoices,
                                  Colors.red,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Recent Transactions
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'أحدث المعاملات',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    _tabController.animateTo(1); // الانتقال إلى تبويب الفواتير
                                  },
                                  child: const Text('عرض الكل'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (_recentInvoices.isEmpty)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Text('لا توجد معاملات حديثة'),
                                ),
                              )
                            else
                              ...List.generate(
                                _recentInvoices.length,
                                (index) => _buildTransactionItem(
                                  _recentInvoices[index],
                                  isLast: index == _recentInvoices.length - 1,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Financial Health Card
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Card(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: theme.colorScheme.primary.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.health_and_safety,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'الصحة المالية',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildFinancialHealthIndicator(
                                    'معدل التحصيل',
                                    (_paidInvoices / (_totalInvoices > 0 ? _totalInvoices : 1) * 100).toInt(),
                                    theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildFinancialHealthIndicator(
                                    'نسبة السيولة',
                                    ((_totalRevenue - _totalPending) / (_totalRevenue > 0 ? _totalRevenue : 1) * 100).toInt(),
                                    Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Bottom padding
                const SliverToBoxAdapter(
                  child: SizedBox(height: 32),
                ),
              ],
            ),
          );
  }

  // KPI Card with title, value and icon
  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
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
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Pie Chart for revenue distribution by category
  Widget _buildPieChart() {
    // Generate colors for each category
    final List<Color> colors = [
      Colors.indigo,
      Colors.blue,
      Colors.teal,
      Colors.green,
      Colors.lime,
      Colors.orange,
      Colors.red,
      Colors.purple,
    ];
    
    // Extract category data and sort by value (descending)
    final categoryData = _revenueByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    // Calculate percentages for display
    final double totalRevenue = _totalRevenue > 0 ? _totalRevenue : 1;
    final List<PieChartSectionData> sections = [];
    
    for (var i = 0; i < categoryData.length; i++) {
      final category = categoryData[i];
      final percentage = (category.value / totalRevenue) * 100;
      final color = colors[i % colors.length];
      
      sections.add(
        PieChartSectionData(
          value: category.value,
          title: '${percentage.toStringAsFixed(1)}%',
          color: color,
          radius: 80,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      );
    }
    
    if (sections.isEmpty) {
      // No data case - display empty chart
      sections.add(
        PieChartSectionData(
          value: 1,
          title: '100%',
          color: Colors.grey.withOpacity(0.3),
          radius: 80,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      );
    }
    
    return SizedBox(
      height: 200,
      child: PieChart(
        PieChartData(
          sections: sections,
          centerSpaceRadius: 30,
          sectionsSpace: 2,
        ),
      ),
    );
  }
  
  // Legend for pie chart
  Widget _buildChartLegend() {
    final categoryData = _revenueByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final List<Color> colors = [
      Colors.indigo, Colors.blue, Colors.teal, Colors.green,
      Colors.lime, Colors.orange, Colors.red, Colors.purple,
    ];
    
    if (categoryData.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Text('لا توجد بيانات متاحة للعرض'),
        ),
      );
    }
    
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: List.generate(
        categoryData.length,
        (i) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: colors[i % colors.length],
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              categoryData[i].key,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
  
  // Invoice status item with circular indicator
  Widget _buildInvoiceStatusItem(String title, int count, Color color) {
    return Column(
      children: [
        Container(
          height: 80,
          width: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(
              color: color.withOpacity(0.5),
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
  
  // Transaction item for recent transaction list
  Widget _buildTransactionItem(FlaskInvoiceModel invoice, {bool isLast = false}) {
    final theme = Theme.of(context);
    final statusColor = invoice.status == 'completed'
        ? Colors.green
        : invoice.status == 'pending'
            ? Colors.orange
            : Colors.red;
    
    final statusText = invoice.status == 'completed'
        ? 'مكتملة'
        : invoice.status == 'pending'
            ? 'معلقة'
            : 'ملغاة';
    
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.primaryColor.withOpacity(0.1),
            ),
            child: Center(
              child: Icon(
                Icons.receipt,
                color: theme.primaryColor,
                size: 20,
              ),
            ),
          ),
          title: Row(
            children: [
              Text(
                'فاتورة #${invoice.invoiceNumber}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                _currencyFormat.format(invoice.finalAmount),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          subtitle: Row(
            children: [
              Text(invoice.customerName),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 10,
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _dateFormat.format(invoice.createdAt),
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          onTap: () {
            _tabController.animateTo(1); // الانتقال إلى تبويب الفواتير
            // هنا يمكن إضافة منطق للانتقال مباشرة إلى تفاصيل هذه الفاتورة
          },
        ),
        if (!isLast) const Divider(),
      ],
    );
  }
  
  // Financial Health Indicator
  Widget _buildFinancialHealthIndicator(String title, int percentage, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            Container(
              height: 12,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Container(
              height: 12,
              width: 200 * percentage / 100,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$percentage%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              // تقييم بناءً على النسبة
              percentage > 80 ? 'ممتاز' : percentage > 60 ? 'جيد' : percentage > 40 ? 'متوسط' : 'ضعيف',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  // Quick action button widget with improved styling
  Widget _buildQuickActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 