import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smartbiztracker_new/utils/style_system.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:smartbiztracker_new/services/error_reports_service.dart';
import 'package:smartbiztracker_new/services/product_returns_service.dart';
import 'package:smartbiztracker_new/models/error_report_model.dart';
import 'package:smartbiztracker_new/models/product_return_model.dart';
import 'package:smartbiztracker_new/widgets/common/custom_app_bar.dart';
import 'package:smartbiztracker_new/widgets/shared/custom_loader.dart';
import 'package:smartbiztracker_new/utils/logger.dart';
import 'package:smartbiztracker_new/screens/customer/customer_requests_screen_helpers.dart';
import 'package:intl/intl.dart';

class CustomerRequestsScreen extends StatefulWidget {
  const CustomerRequestsScreen({super.key});

  @override
  State<CustomerRequestsScreen> createState() => _CustomerRequestsScreenState();
}

class _CustomerRequestsScreenState extends State<CustomerRequestsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final ErrorReportsService _errorReportsService = ErrorReportsService();
  final ProductReturnsService _returnsService = ProductReturnsService();

  List<ErrorReport> _errorReports = [];
  List<ProductReturn> _productReturns = [];
  bool _isLoadingReports = false;
  bool _isLoadingReturns = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCustomerRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomerRequests() async {
    await Future.wait([
      _loadErrorReports(),
      _loadProductReturns(),
    ]);
  }

  Future<void> _loadErrorReports() async {
    setState(() {
      _isLoadingReports = true;
    });

    try {
      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
      final user = supabaseProvider.user;

      if (user != null) {
        final reports = await _errorReportsService.getErrorReportsByCustomer(user.id);
        setState(() {
          _errorReports = reports;
        });
      }
    } catch (e) {
      AppLogger.error('Error loading error reports: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في تحميل تقارير الأخطاء: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoadingReports = false;
      });
    }
  }

  Future<void> _loadProductReturns() async {
    setState(() {
      _isLoadingReturns = true;
    });

    try {
      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
      final user = supabaseProvider.user;

      if (user != null) {
        final returns = await _returnsService.getProductReturnsByCustomer(user.id);
        setState(() {
          _productReturns = returns;
        });
      }
    } catch (e) {
      AppLogger.error('Error loading product returns: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في تحميل طلبات الإرجاع: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoadingReturns = false;
      });
    }
  }

  List<ErrorReport> _filterErrorReports() {
    if (_searchQuery.isEmpty) return _errorReports;
    return _errorReports.where((report) {
      return report.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             report.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             report.status.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  List<ProductReturn> _filterProductReturns() {
    if (_searchQuery.isEmpty) return _productReturns;
    return _productReturns.where((returnRequest) {
      return returnRequest.productName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             returnRequest.reason.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             returnRequest.status.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             (returnRequest.orderNumber?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StyleSystem.backgroundDark,
      appBar: CustomAppBar(
        title: 'طلباتي',
        backgroundColor: StyleSystem.backgroundDark,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Header with search
          _buildHeader(),
          
          // Tab bar
          _buildTabBar(),
          
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildErrorReportsTab(),
                _buildProductReturnsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            StyleSystem.surfaceDark,
            StyleSystem.backgroundDark,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: StyleSystem.primaryColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          const Text(
            'طلباتي ومراجعاتي',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ).animate().fadeIn(duration: 400.ms).moveY(begin: -10, end: 0),

          const SizedBox(height: 8),

          Text(
            'تابع حالة طلبات الإرجاع وتقارير الأخطاء الخاصة بك',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.7),
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 100.ms).moveY(begin: -10, end: 0),

          const SizedBox(height: 16),

          // Search bar
          Container(
            decoration: BoxDecoration(
              color: StyleSystem.surfaceDark,
              borderRadius: BorderRadius.circular(StyleSystem.radiusMedium),
              border: Border.all(
                color: StyleSystem.primaryColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'البحث في الطلبات...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                prefixIcon: Icon(
                  Icons.search,
                  color: StyleSystem.primaryColor,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 200.ms).moveY(begin: -10, end: 0),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: StyleSystem.surfaceDark,
        borderRadius: BorderRadius.circular(StyleSystem.radiusMedium),
        border: Border.all(
          color: StyleSystem.primaryColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: LinearGradient(
            colors: [StyleSystem.primaryColor, StyleSystem.secondaryColor],
          ),
          borderRadius: BorderRadius.circular(StyleSystem.radiusMedium),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withOpacity(0.7),
        labelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: 14,
        ),
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 18),
                const SizedBox(width: 8),
                const Text('تقارير الأخطاء'),
                if (_errorReports.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: StyleSystem.primaryColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_errorReports.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.assignment_return, size: 18),
                const SizedBox(width: 8),
                const Text('طلبات الإرجاع'),
                if (_productReturns.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: StyleSystem.primaryColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_productReturns.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 300.ms).moveY(begin: -10, end: 0);
  }

  Widget _buildErrorReportsTab() {
    if (_isLoadingReports) {
      return const Center(
        child: CustomLoader(message: 'جاري تحميل تقارير الأخطاء...'),
      );
    }

    final filteredReports = _filterErrorReports();

    if (filteredReports.isEmpty) {
      return _buildEmptyWidget(
        'لا توجد تقارير أخطاء',
        _searchQuery.isEmpty
          ? 'لم تقم بإرسال أي تقارير أخطاء بعد'
          : 'لم يتم العثور على تقارير أخطاء مطابقة للبحث',
        Icons.error_outline_rounded,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadErrorReports,
      color: StyleSystem.primaryColor,
      backgroundColor: StyleSystem.surfaceDark,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredReports.length,
        itemBuilder: (context, index) {
          final report = filteredReports[index];
          return _buildErrorReportCard(report, index);
        },
      ),
    );
  }

  Widget _buildProductReturnsTab() {
    if (_isLoadingReturns) {
      return const Center(
        child: CustomLoader(message: 'جاري تحميل طلبات الإرجاع...'),
      );
    }

    final filteredReturns = _filterProductReturns();

    if (filteredReturns.isEmpty) {
      return _buildEmptyWidget(
        'لا توجد طلبات إرجاع',
        _searchQuery.isEmpty
          ? 'لم تقم بإرسال أي طلبات إرجاع بعد'
          : 'لم يتم العثور على طلبات إرجاع مطابقة للبحث',
        Icons.assignment_return_rounded,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadProductReturns,
      color: StyleSystem.primaryColor,
      backgroundColor: StyleSystem.surfaceDark,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredReturns.length,
        itemBuilder: (context, index) {
          final returnRequest = filteredReturns[index];
          return _buildProductReturnCard(returnRequest, index);
        },
      ),
    );
  }

  Widget _buildEmptyWidget(String title, String subtitle, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  StyleSystem.primaryColor.withOpacity(0.1),
                  StyleSystem.secondaryColor.withOpacity(0.1),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 64,
              color: StyleSystem.primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.8, 0.8));
  }

  Widget _buildErrorReportCard(ErrorReport report, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            StyleSystem.surfaceDark,
            StyleSystem.surfaceDark.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getStatusColor(report.status).withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _getStatusColor(report.status).withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showErrorReportDetails(report),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                StyleSystem.primaryColor,
                                StyleSystem.secondaryColor,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.error_outline_rounded,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                report.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'الأولوية: ${_getPriorityText(report.priority)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    _buildStatusChip(report.status),
                  ],
                ),

                const SizedBox(height: 16),

                // Description
                Text(
                  report.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 16),

                // Footer with date and admin response indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 16,
                          color: Colors.white.withOpacity(0.5),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(report.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                    if (report.adminResponse != null && report.adminResponse!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: StyleSystem.primaryColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: StyleSystem.primaryColor.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.admin_panel_settings,
                              size: 14,
                              color: StyleSystem.primaryColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'رد الإدارة',
                              style: TextStyle(
                                fontSize: 11,
                                color: StyleSystem.primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms, delay: (index * 100).ms).moveX(begin: 20, end: 0);
  }

  Widget _buildProductReturnCard(ProductReturn returnRequest, int index) {
    return CustomerRequestsHelpers.buildProductReturnCard(
      returnRequest,
      index,
      _showProductReturnDetails,
    );
  }

  Widget _buildStatusChip(String status) {
    return CustomerRequestsHelpers.buildStatusChip(status);
  }

  Color _getStatusColor(String status) {
    return CustomerRequestsHelpers.getStatusColor(status);
  }

  String _getStatusText(String status) {
    return CustomerRequestsHelpers.getStatusText(status);
  }

  String _getPriorityText(String priority) {
    return CustomerRequestsHelpers.getPriorityText(priority);
  }

  String _formatDate(DateTime date) {
    return CustomerRequestsHelpers.formatDate(date);
  }

  void _showErrorReportDetails(ErrorReport report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ErrorReportDetailsSheet(report: report),
    );
  }

  void _showProductReturnDetails(ProductReturn returnRequest) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ProductReturnDetailsSheet(returnRequest: returnRequest),
    );
  }
}

// Error Report Details Sheet
class _ErrorReportDetailsSheet extends StatelessWidget {
  final ErrorReport report;

  const _ErrorReportDetailsSheet({required this.report});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: StyleSystem.backgroundDark,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      StyleSystem.primaryColor,
                      StyleSystem.secondaryColor,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'تفاصيل تقرير الخطأ',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            CustomerRequestsHelpers.formatDate(report.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    CustomerRequestsHelpers.buildStatusChip(report.status),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailSection('عنوان التقرير', report.title),
                      const SizedBox(height: 16),
                      _buildDetailSection('وصف المشكلة', report.description),
                      const SizedBox(height: 16),
                      _buildDetailSection('موقع الخطأ', report.location),
                      const SizedBox(height: 16),
                      _buildDetailSection('الأولوية', CustomerRequestsHelpers.getPriorityText(report.priority)),

                      if (report.adminResponse != null && report.adminResponse!.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: StyleSystem.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: StyleSystem.primaryColor.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.admin_panel_settings,
                                    color: StyleSystem.primaryColor,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'رد الإدارة',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: StyleSystem.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                              if (report.adminResponseDate != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  CustomerRequestsHelpers.formatDate(report.adminResponseDate!),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.6),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              Text(
                                report.adminResponse!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: StyleSystem.primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: StyleSystem.surfaceDark,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          child: Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

// Product Return Details Sheet
class _ProductReturnDetailsSheet extends StatelessWidget {
  final ProductReturn returnRequest;

  const _ProductReturnDetailsSheet({required this.returnRequest});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: StyleSystem.backgroundDark,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      StyleSystem.primaryColor,
                      StyleSystem.secondaryColor,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.assignment_return, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'تفاصيل طلب الإرجاع',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            CustomerRequestsHelpers.formatDate(returnRequest.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    CustomerRequestsHelpers.buildStatusChip(returnRequest.status),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailSection('اسم المنتج', returnRequest.productName),
                      const SizedBox(height: 16),
                      if (returnRequest.orderNumber != null && returnRequest.orderNumber!.isNotEmpty) ...[
                        _buildDetailSection('رقم الطلب', returnRequest.orderNumber!),
                        const SizedBox(height: 16),
                      ],
                      _buildDetailSection('سبب الإرجاع', returnRequest.reason),
                      const SizedBox(height: 16),
                      if (returnRequest.phone != null && returnRequest.phone!.isNotEmpty) ...[
                        _buildDetailSection('رقم الهاتف', returnRequest.phone!),
                        const SizedBox(height: 16),
                      ],
                      if (returnRequest.datePurchased != null) ...[
                        _buildDetailSection('تاريخ الشراء', CustomerRequestsHelpers.formatDate(returnRequest.datePurchased!)),
                        const SizedBox(height: 16),
                      ],
                      _buildDetailSection('يملك فاتورة', returnRequest.hasReceipt ? 'نعم' : 'لا'),

                      if (returnRequest.adminResponse != null && returnRequest.adminResponse!.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: StyleSystem.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: StyleSystem.primaryColor.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.admin_panel_settings,
                                    color: StyleSystem.primaryColor,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'رد الإدارة',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: StyleSystem.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                              if (returnRequest.adminResponseDate != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  CustomerRequestsHelpers.formatDate(returnRequest.adminResponseDate!),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.6),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              Text(
                                returnRequest.adminResponse!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      if (returnRequest.refundAmount != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.green.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.attach_money,
                                color: Colors.green,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'مبلغ الاسترداد: ${returnRequest.refundAmount!.toStringAsFixed(2)} ريال',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: StyleSystem.primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: StyleSystem.surfaceDark,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          child: Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
