import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smartbiztracker_new/utils/style_system.dart';
import 'package:smartbiztracker_new/models/error_report_model.dart';
import 'package:smartbiztracker_new/models/product_return_model.dart';
import 'package:smartbiztracker_new/services/error_reports_service.dart';
import 'package:smartbiztracker_new/services/product_returns_service.dart';
import 'package:smartbiztracker_new/services/real_notification_service.dart';

class ErrorReportsReturnsScreen extends StatefulWidget {
  const ErrorReportsReturnsScreen({super.key});

  @override
  State<ErrorReportsReturnsScreen> createState() => _ErrorReportsReturnsScreenState();
}

class _ErrorReportsReturnsScreenState extends State<ErrorReportsReturnsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final ErrorReportsService _errorReportsService = ErrorReportsService();
  final ProductReturnsService _returnsService = ProductReturnsService();
  final RealNotificationService _notificationService = RealNotificationService();
  
  List<ErrorReport> _errorReports = [];
  List<ProductReturn> _productReturns = [];
  bool _isLoadingReports = true;
  bool _isLoadingReturns = true;
  String _searchQuery = '';
  String _selectedStatus = 'all';

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
    // Debug: Check current user authentication
    final user = Supabase.instance.client.auth.currentUser;
    print('🔐 Current user: ${user?.id ?? 'Not authenticated'}');
    print('🔐 User email: ${user?.email ?? 'No email'}');
    print('🔐 User metadata: ${user?.userMetadata ?? 'No metadata'}');

    await Future.wait([
      _loadErrorReports(),
      _loadProductReturns(),
    ]);
  }

  Future<void> _loadErrorReports() async {
    setState(() => _isLoadingReports = true);
    try {
      final reports = await _errorReportsService.getAllErrorReports();
      setState(() {
        _errorReports = reports;
        _isLoadingReports = false;
      });
    } catch (e) {
      setState(() => _isLoadingReports = false);
      _showErrorSnackBar('فشل في تحميل تقارير الأخطاء: $e');
    }
  }

  Future<void> _loadProductReturns() async {
    print('🔄 ErrorReportsReturnsScreen: Starting to load product returns...');
    setState(() => _isLoadingReturns = true);
    try {
      final returns = await _returnsService.getAllProductReturns();
      print('✅ ErrorReportsReturnsScreen: Loaded ${returns.length} product returns');
      setState(() {
        _productReturns = returns;
        _isLoadingReturns = false;
      });
    } catch (e) {
      print('❌ ErrorReportsReturnsScreen: Error loading product returns: $e');
      setState(() => _isLoadingReturns = false);
      _showErrorSnackBar('فشل في تحميل طلبات الإرجاع: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StyleSystem.backgroundDark,
      body: Column(
        children: [
          // Header with search and filters
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
        children: [
          // Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      StyleSystem.primaryColor,
                      StyleSystem.secondaryColor,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.report_problem_rounded,
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
                      'إدارة التقارير والمرتجعات',
                      style: StyleSystem.titleLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'عرض وإدارة تقارير الأخطاء وطلبات الإرجاع',
                      style: StyleSystem.bodyMedium.copyWith(
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Search and filter row
          Row(
            children: [
              // Search field
              Expanded(
                flex: 2,
                child: _buildSearchField(),
              ),
              
              const SizedBox(width: 12),
              
              // Status filter
              Expanded(
                child: _buildStatusFilter(),
              ),
              
              const SizedBox(width: 12),
              
              // Refresh button
              _buildRefreshButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: StyleSystem.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: StyleSystem.primaryColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: TextField(
        onChanged: (value) => setState(() => _searchQuery = value),
        style: StyleSystem.bodyMedium.copyWith(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'البحث...',
          hintStyle: StyleSystem.bodyMedium.copyWith(
            color: Colors.white.withOpacity(0.6),
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: StyleSystem.primaryColor,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: StyleSystem.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: StyleSystem.primaryColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedStatus,
          onChanged: (value) => setState(() => _selectedStatus = value!),
          dropdownColor: StyleSystem.surfaceDark,
          style: StyleSystem.bodyMedium.copyWith(color: Colors.white),
          icon: Icon(
            Icons.arrow_drop_down,
            color: StyleSystem.primaryColor,
          ),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('جميع الحالات')),
            DropdownMenuItem(value: 'pending', child: Text('قيد المراجعة')),
            DropdownMenuItem(value: 'resolved', child: Text('تم الحل')),
            DropdownMenuItem(value: 'rejected', child: Text('مرفوض')),
          ],
        ),
      ),
    );
  }

  Widget _buildRefreshButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            StyleSystem.primaryColor,
            StyleSystem.secondaryColor,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        onPressed: _loadData,
        icon: const Icon(
          Icons.refresh_rounded,
          color: Colors.white,
        ),
        tooltip: 'تحديث البيانات',
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: StyleSystem.surfaceDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              StyleSystem.primaryColor,
              StyleSystem.secondaryColor,
            ],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withOpacity(0.6),
        labelStyle: StyleSystem.labelMedium.copyWith(
          fontWeight: FontWeight.bold,
        ),
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 18),
                const SizedBox(width: 8),
                Text('تقارير الأخطاء (${_errorReports.length})'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.assignment_return_rounded, size: 18),
                const SizedBox(width: 8),
                Text('طلبات الإرجاع (${_productReturns.length})'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorReportsTab() {
    if (_isLoadingReports) {
      return _buildLoadingWidget('جاري تحميل تقارير الأخطاء...');
    }

    final filteredReports = _filterErrorReports();

    if (filteredReports.isEmpty) {
      return _buildEmptyWidget(
        'لا توجد تقارير أخطاء',
        'لم يتم العثور على أي تقارير أخطاء مطابقة للبحث',
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
    print('🎨 UI: Building product returns tab - isLoading: $_isLoadingReturns, total returns: ${_productReturns.length}');

    if (_isLoadingReturns) {
      print('🎨 UI: Showing loading widget');
      return _buildLoadingWidget('جاري تحميل طلبات الإرجاع...');
    }

    final filteredReturns = _filterProductReturns();
    print('🎨 UI: After filtering: ${filteredReturns.length} returns to display');

    if (filteredReturns.isEmpty) {
      print('🎨 UI: Showing empty widget - no returns to display');
      return _buildEmptyWidget(
        'لا توجد طلبات إرجاع',
        'لم يتم العثور على أي طلبات إرجاع مطابقة للبحث',
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

  Widget _buildLoadingWidget(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: StyleSystem.primaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: StyleSystem.bodyMedium.copyWith(
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget(String title, String subtitle, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
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
            style: StyleSystem.titleLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: StyleSystem.bodyMedium.copyWith(
              color: Colors.white.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  List<ErrorReport> _filterErrorReports() {
    final filtered = _errorReports.where((report) {
      final matchesSearch = _searchQuery.isEmpty ||
          report.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          report.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          report.customerName.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesStatus = _selectedStatus == 'all' ||
          report.status.toLowerCase() == _selectedStatus;

      return matchesSearch && matchesStatus;
    }).toList();

    // Sort by creation date (newest first)
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered;
  }

  List<ProductReturn> _filterProductReturns() {
    print('🔍 ErrorReportsReturnsScreen: Filtering ${_productReturns.length} product returns');
    print('🔍 Search query: "$_searchQuery", Selected status: "$_selectedStatus"');

    final filtered = _productReturns.where((returnRequest) {
      final matchesSearch = _searchQuery.isEmpty ||
          returnRequest.productName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          returnRequest.customerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          returnRequest.reason.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesStatus = _selectedStatus == 'all' ||
          returnRequest.status.toLowerCase() == _selectedStatus;

      final matches = matchesSearch && matchesStatus;
      if (!matches) {
        print('❌ Filtered out: ${returnRequest.productName} (search: $matchesSearch, status: $matchesStatus)');
      }
      return matches;
    }).toList();

    // Sort by creation date (newest first)
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    print('✅ ErrorReportsReturnsScreen: After filtering: ${filtered.length} product returns');
    return filtered;
  }

  Widget _buildErrorReportCard(ErrorReport report, int index) {
    final Color statusColor = _getStatusColor(report.status);
    final IconData statusIcon = _getStatusIcon(report.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            StyleSystem.surfaceDark,
            StyleSystem.surfaceDark.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1.5,
        ),
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              report.title,
                              style: StyleSystem.titleMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'بواسطة: ${report.customerName}',
                              style: StyleSystem.bodySmall.copyWith(
                                color: Colors.white.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withOpacity(0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            statusIcon,
                            size: 16,
                            color: statusColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _getStatusText(report.status),
                            style: StyleSystem.labelMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Description preview
                Text(
                  report.description,
                  style: StyleSystem.bodyMedium.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 16),

                // Footer with date and priority
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 16,
                          color: Colors.white.withOpacity(0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(report.createdAt),
                          style: StyleSystem.bodySmall.copyWith(
                            color: Colors.white.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getPriorityColor(report.priority).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getPriorityColor(report.priority).withOpacity(0.5),
                        ),
                      ),
                      child: Text(
                        _getPriorityText(report.priority),
                        style: StyleSystem.labelSmall.copyWith(
                          color: _getPriorityColor(report.priority),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate(delay: (index * 100).ms).fadeIn(duration: 400.ms).slideY(begin: 0.2);
  }

  Widget _buildProductReturnCard(ProductReturn returnRequest, int index) {
    final Color statusColor = _getStatusColor(returnRequest.status);
    final IconData statusIcon = _getStatusIcon(returnRequest.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            StyleSystem.surfaceDark,
            StyleSystem.surfaceDark.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showProductReturnDetails(returnRequest),
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
                            Icons.assignment_return_rounded,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              returnRequest.productName,
                              style: StyleSystem.titleMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'بواسطة: ${returnRequest.customerName}',
                              style: StyleSystem.bodySmall.copyWith(
                                color: Colors.white.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withOpacity(0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            statusIcon,
                            size: 16,
                            color: statusColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _getStatusText(returnRequest.status),
                            style: StyleSystem.labelMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Return reason
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: StyleSystem.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: StyleSystem.primaryColor.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: StyleSystem.primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'سبب الإرجاع: ${returnRequest.reason}',
                          style: StyleSystem.bodyMedium.copyWith(
                            color: Colors.white.withOpacity(0.9),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Footer with date and order number
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 16,
                          color: Colors.white.withOpacity(0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(returnRequest.createdAt),
                          style: StyleSystem.bodySmall.copyWith(
                            color: Colors.white.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                    if (returnRequest.orderNumber?.isNotEmpty ?? false)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.5),
                          ),
                        ),
                        child: Text(
                          'طلب #${returnRequest.orderNumber}',
                          style: StyleSystem.labelSmall.copyWith(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate(delay: (index * 100).ms).fadeIn(duration: 400.ms).slideY(begin: 0.2);
  }

  // Helper methods for status, priority, and formatting
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'قيد المراجعة':
        return Colors.amber;
      case 'resolved':
      case 'تم الحل':
        return Colors.green;
      case 'rejected':
      case 'مرفوض':
        return Colors.red;
      case 'approved':
      case 'موافق عليه':
        return Colors.blue;
      case 'processing':
      case 'قيد المعالجة':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'قيد المراجعة':
        return Icons.hourglass_empty_rounded;
      case 'resolved':
      case 'تم الحل':
        return Icons.check_circle_rounded;
      case 'rejected':
      case 'مرفوض':
        return Icons.cancel_rounded;
      case 'approved':
      case 'موافق عليه':
        return Icons.verified_rounded;
      case 'processing':
      case 'قيد المعالجة':
        return Icons.settings_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }



  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
      case 'عالي':
        return Colors.red;
      case 'medium':
      case 'متوسط':
        return Colors.orange;
      case 'low':
      case 'منخفض':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getPriorityText(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return 'عالي';
      case 'medium':
        return 'متوسط';
      case 'low':
        return 'منخفض';
      default:
        return priority;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showErrorReportDetails(ErrorReport report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ErrorReportDetailsSheet(
        report: report,
        onStatusUpdate: (newStatus) {
          _updateErrorReportStatus(report, newStatus);
        },
        onResponseSubmit: (response) {
          _addErrorReportResponse(report, response);
        },
        onStatusAndResponseUpdate: (status, response) {
          _updateErrorReportWithResponse(report, status, response);
        },
      ),
    );
  }

  void _showProductReturnDetails(ProductReturn returnRequest) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ProductReturnDetailsSheet(
        returnRequest: returnRequest,
        onStatusUpdate: (newStatus) {
          _updateProductReturnStatus(returnRequest, newStatus);
        },
        onResponseSubmit: (response) {
          _addProductReturnResponse(returnRequest, response);
        },
        onStatusAndResponseUpdate: (status, response) {
          _updateProductReturnWithResponse(returnRequest, status, response);
        },
      ),
    );
  }

  Future<void> _updateErrorReportStatus(ErrorReport report, String newStatus) async {
    try {
      await _errorReportsService.updateErrorReportStatus(report.id, newStatus);

      // Send notification to customer
      try {
        await _notificationService.createNotification(
          userId: report.customerId,
          title: 'تحديث حالة تقرير الخطأ',
          body: 'تم تحديث حالة تقرير الخطأ "${report.title}" إلى: ${_getStatusText(newStatus)}',
          type: 'customer_service_update',
          category: 'customer_service',
          priority: 'normal',
          route: '/customer/requests',
          referenceId: report.id,
          referenceType: 'error_report',
          metadata: {
            'old_status': report.status,
            'new_status': newStatus,
            'report_title': report.title,
          },
        );
      } catch (notificationError) {
        print('Failed to send notification: $notificationError');
      }

      await _loadErrorReports();
      _showSuccessSnackBar('تم تحديث حالة التقرير بنجاح');
    } catch (e) {
      _showErrorSnackBar('فشل في تحديث حالة التقرير: $e');
    }
  }

  Future<void> _updateProductReturnStatus(ProductReturn returnRequest, String newStatus) async {
    try {
      await _returnsService.updateProductReturnStatus(returnRequest.id, newStatus);

      // Send notification to customer
      try {
        await _notificationService.createNotification(
          userId: returnRequest.customerId,
          title: 'تحديث حالة طلب الإرجاع',
          body: 'تم تحديث حالة طلب إرجاع المنتج "${returnRequest.productName}" إلى: ${_getStatusText(newStatus)}',
          type: RealNotificationService.typeCustomerServiceUpdate,
          category: RealNotificationService.categoryCustomerService,
          priority: RealNotificationService.priorityNormal,
          route: '/customer/requests',
          referenceId: returnRequest.id,
          referenceType: 'product_return',
          metadata: {
            'old_status': returnRequest.status,
            'new_status': newStatus,
            'product_name': returnRequest.productName,
            'order_number': returnRequest.orderNumber,
          },
        );
      } catch (notificationError) {
        print('Failed to send notification: $notificationError');
      }

      await _loadProductReturns();
      _showSuccessSnackBar('تم تحديث حالة طلب الإرجاع بنجاح');
    } catch (e) {
      _showErrorSnackBar('فشل في تحديث حالة طلب الإرجاع: $e');
    }
  }

  Future<void> _addErrorReportResponse(ErrorReport report, String response) async {
    try {
      await _errorReportsService.addAdminResponse(report.id, response);

      // Send notification to customer
      try {
        await _notificationService.createNotification(
          userId: report.customerId,
          title: 'رد جديد على تقرير الخطأ',
          body: 'تم إضافة رد جديد من الإدارة على تقرير الخطأ "${report.title}"',
          type: 'customer_service_response',
          category: 'customer_service',
          priority: 'normal',
          route: '/customer/requests',
          referenceId: report.id,
          referenceType: 'error_report',
          metadata: {
            'report_title': report.title,
            'response_preview': response.length > 50 ? '${response.substring(0, 50)}...' : response,
          },
        );
      } catch (notificationError) {
        print('Failed to send notification: $notificationError');
      }

      await _loadErrorReports();
      _showSuccessSnackBar('تم إضافة الرد بنجاح');
    } catch (e) {
      _showErrorSnackBar('فشل في إضافة الرد: $e');
    }
  }

  Future<void> _updateErrorReportWithResponse(ErrorReport report, String status, String response) async {
    try {
      await _errorReportsService.updateErrorReportWithResponse(report.id, status, response);
      await _loadErrorReports();
      _showSuccessSnackBar('تم تحديث الحالة وإضافة الرد بنجاح');
    } catch (e) {
      _showErrorSnackBar('فشل في تحديث التقرير: $e');
    }
  }

  Future<void> _addProductReturnResponse(ProductReturn returnRequest, String response) async {
    try {
      await _returnsService.addAdminResponse(returnRequest.id, response);

      // Send notification to customer
      try {
        await _notificationService.createNotification(
          userId: returnRequest.customerId,
          title: 'رد جديد على طلب الإرجاع',
          body: 'تم إضافة رد جديد من الإدارة على طلب إرجاع المنتج "${returnRequest.productName}"',
          type: 'customer_service_response',
          category: 'customer_service',
          priority: 'normal',
          route: '/customer/requests',
          referenceId: returnRequest.id,
          referenceType: 'product_return',
          metadata: {
            'product_name': returnRequest.productName,
            'order_number': returnRequest.orderNumber,
            'response_preview': response.length > 50 ? '${response.substring(0, 50)}...' : response,
          },
        );
      } catch (notificationError) {
        print('Failed to send notification: $notificationError');
      }

      await _loadProductReturns();
      _showSuccessSnackBar('تم إضافة الرد بنجاح');
    } catch (e) {
      _showErrorSnackBar('فشل في إضافة الرد: $e');
    }
  }

  Future<void> _updateProductReturnWithResponse(ProductReturn returnRequest, String status, String response) async {
    try {
      await _returnsService.updateProductReturnWithResponse(returnRequest.id, status, response);

      // Send notification to customer
      try {
        await _notificationService.createNotification(
          userId: returnRequest.customerId,
          title: 'تحديث طلب الإرجاع مع رد الإدارة',
          body: 'تم تحديث حالة طلب إرجاع المنتج "${returnRequest.productName}" إلى: ${_getStatusText(status)} مع إضافة رد من الإدارة',
          type: 'customer_service_update',
          category: 'customer_service',
          priority: 'normal',
          route: '/customer/requests',
          referenceId: returnRequest.id,
          referenceType: 'product_return',
          metadata: {
            'old_status': returnRequest.status,
            'new_status': status,
            'product_name': returnRequest.productName,
            'order_number': returnRequest.orderNumber,
            'response_preview': response.length > 50 ? '${response.substring(0, 50)}...' : response,
          },
        );
      } catch (notificationError) {
        print('Failed to send notification: $notificationError');
      }

      await _loadProductReturns();
      _showSuccessSnackBar('تم تحديث الحالة وإضافة الرد بنجاح');
    } catch (e) {
      _showErrorSnackBar('فشل في تحديث طلب الإرجاع: $e');
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'قيد المراجعة';
      case 'processing':
        return 'قيد المعالجة';
      case 'resolved':
        return 'تم الحل';
      case 'rejected':
        return 'مرفوض';
      case 'approved':
        return 'موافق عليه';
      case 'completed':
        return 'مكتمل';
      default:
        return status;
    }
  }


}

// Error Report Details Sheet
class _ErrorReportDetailsSheet extends StatefulWidget {

  const _ErrorReportDetailsSheet({
    required this.report,
    required this.onStatusUpdate,
    required this.onResponseSubmit,
    required this.onStatusAndResponseUpdate,
  });
  final ErrorReport report;
  final Function(String) onStatusUpdate;
  final Function(String) onResponseSubmit;
  final Function(String, String) onStatusAndResponseUpdate;

  @override
  State<_ErrorReportDetailsSheet> createState() => _ErrorReportDetailsSheetState();
}

class _ErrorReportDetailsSheetState extends State<_ErrorReportDetailsSheet> {
  final TextEditingController _responseController = TextEditingController();
  String _selectedStatus = '';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.report.status;
    if (widget.report.adminResponse != null) {
      _responseController.text = widget.report.adminResponse!;
    }
  }

  @override
  void dispose() {
    _responseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            StyleSystem.surfaceDark,
            StyleSystem.backgroundDark,
          ],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: StyleSystem.primaryColor.withOpacity(0.6),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'تفاصيل تقرير الخطأ',
                  style: StyleSystem.titleLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white24),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Report Info
                  _buildDetailSection(
                    'معلومات التقرير',
                    [
                      'العنوان: ${widget.report.title}',
                      'المرسل: ${widget.report.customerName}',
                      'الموقع: ${widget.report.location}',
                      'الأولوية: ${_getPriorityText(widget.report.priority)}',
                      'الحالة: ${_getStatusText(widget.report.status)}',
                      'التاريخ: ${_formatDate(widget.report.createdAt)}',
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Description
                  _buildDetailSection(
                    'وصف المشكلة',
                    [widget.report.description],
                  ),

                  if (widget.report.adminNotes != null && widget.report.adminNotes!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildDetailSection(
                      'ملاحظات الإدارة',
                      [widget.report.adminNotes!],
                    ),
                  ],

                  if (widget.report.adminResponse != null && widget.report.adminResponse!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildDetailSection(
                      'رد الإدارة السابق',
                      [widget.report.adminResponse!],
                    ),
                  ],

                  const SizedBox(height: 30),

                  // Admin Response Section
                  _buildAdminResponseSection(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: StyleSystem.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: StyleSystem.primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: StyleSystem.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: StyleSystem.primaryColor.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                item,
                style: StyleSystem.bodyMedium.copyWith(
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            )).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildAdminResponseSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: StyleSystem.surfaceDark.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: StyleSystem.primaryColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'إدارة التقرير',
            style: StyleSystem.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: StyleSystem.primaryColor,
            ),
          ),
          const SizedBox(height: 16),

          // Status Selection
          Text(
            'تحديث الحالة:',
            style: StyleSystem.bodyMedium.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildStatusButton('processing', 'قيد المعالجة', Colors.blue),
              const SizedBox(width: 8),
              _buildStatusButton('resolved', 'تم الحل', Colors.green),
              const SizedBox(width: 8),
              _buildStatusButton('rejected', 'مرفوض', Colors.red),
            ],
          ),

          const SizedBox(height: 16),

          // Admin Response
          Text(
            'رد الإدارة:',
            style: StyleSystem.bodyMedium.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _responseController,
            maxLines: 4,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'اكتب ردك على التقرير...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
              filled: true,
              fillColor: StyleSystem.backgroundDark.withOpacity(0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: StyleSystem.primaryColor.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: StyleSystem.primaryColor.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: StyleSystem.primaryColor),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitResponse,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: StyleSystem.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.send),
                  label: Text(_isSubmitting ? 'جاري الإرسال...' : 'إرسال الرد'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitStatusAndResponse,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.done_all),
                  label: const Text('تحديث وإرسال'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusButton(String status, String label, Color color) {
    final isSelected = _selectedStatus == status;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedStatus = status;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected ? color : color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: color,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : color,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  void _submitResponse() async {
    if (_responseController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى كتابة رد قبل الإرسال')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await widget.onResponseSubmit(_responseController.text.trim());
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل في إرسال الرد: $e')),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _submitStatusAndResponse() async {
    if (_responseController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى كتابة رد قبل الإرسال')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await widget.onStatusAndResponseUpdate(_selectedStatus, _responseController.text.trim());
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل في تحديث التقرير: $e')),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  String _getPriorityText(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return 'عالي';
      case 'medium':
        return 'متوسط';
      case 'low':
        return 'منخفض';
      default:
        return priority;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'قيد المراجعة';
      case 'resolved':
        return 'تم الحل';
      case 'rejected':
        return 'مرفوض';
      case 'processing':
        return 'قيد المعالجة';
      default:
        return status;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// Product Return Details Sheet
class _ProductReturnDetailsSheet extends StatefulWidget {

  const _ProductReturnDetailsSheet({
    required this.returnRequest,
    required this.onStatusUpdate,
    required this.onResponseSubmit,
    required this.onStatusAndResponseUpdate,
  });
  final ProductReturn returnRequest;
  final Function(String) onStatusUpdate;
  final Function(String) onResponseSubmit;
  final Function(String, String) onStatusAndResponseUpdate;

  @override
  State<_ProductReturnDetailsSheet> createState() => _ProductReturnDetailsSheetState();
}

class _ProductReturnDetailsSheetState extends State<_ProductReturnDetailsSheet> {
  final TextEditingController _responseController = TextEditingController();
  String _selectedStatus = '';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.returnRequest.status;
    if (widget.returnRequest.adminResponse != null) {
      _responseController.text = widget.returnRequest.adminResponse!;
    }
  }

  @override
  void dispose() {
    _responseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            StyleSystem.surfaceDark,
            StyleSystem.backgroundDark,
          ],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: StyleSystem.primaryColor.withOpacity(0.6),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'تفاصيل طلب الإرجاع',
                  style: StyleSystem.titleLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white24),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Return Info
                  _buildDetailSection(
                    'معلومات الطلب',
                    [
                      'المنتج: ${widget.returnRequest.productName}',
                      'العميل: ${widget.returnRequest.customerName}',
                      'رقم الطلب: ${widget.returnRequest.orderNumber ?? "غير محدد"}',
                      'الحالة: ${_getStatusText(widget.returnRequest.status)}',
                      'التاريخ: ${_formatDate(widget.returnRequest.createdAt)}',
                      if (widget.returnRequest.phone != null) 'الهاتف: ${widget.returnRequest.phone}',
                      'يملك فاتورة: ${widget.returnRequest.hasReceipt ? "نعم" : "لا"}',
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Return reason
                  _buildDetailSection(
                    'سبب الإرجاع',
                    [widget.returnRequest.reason],
                  ),

                  if (widget.returnRequest.adminResponse != null && widget.returnRequest.adminResponse!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildDetailSection(
                      'رد الإدارة السابق',
                      [widget.returnRequest.adminResponse!],
                    ),
                  ],

                  const SizedBox(height: 30),

                  // Admin Response Section
                  _buildAdminResponseSection(context),

                  if (widget.returnRequest.adminNotes != null && widget.returnRequest.adminNotes!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildDetailSection(
                      'ملاحظات الإدارة',
                      [widget.returnRequest.adminNotes!],
                    ),
                  ],

                  if (widget.returnRequest.refundAmount != null) ...[
                    const SizedBox(height: 20),
                    _buildDetailSection(
                      'مبلغ الاسترداد',
                      ['${widget.returnRequest.refundAmount!.toStringAsFixed(2)} ر.س'],
                    ),
                  ],

                  const SizedBox(height: 30),

                  // Admin Response Section
                  _buildAdminResponseSection(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: StyleSystem.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: StyleSystem.primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: StyleSystem.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: StyleSystem.primaryColor.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                item,
                style: StyleSystem.bodyMedium.copyWith(
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            )).toList(),
          ),
        ),
      ],
    );
  }



  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'قيد المراجعة';
      case 'approved':
        return 'موافق عليه';
      case 'rejected':
        return 'مرفوض';
      case 'processing':
        return 'قيد المعالجة';
      case 'completed':
        return 'مكتمل';
      default:
        return status;
    }
  }

  Widget _buildAdminResponseSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: StyleSystem.surfaceDark.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: StyleSystem.primaryColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'إدارة طلب الإرجاع',
            style: StyleSystem.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: StyleSystem.primaryColor,
            ),
          ),
          const SizedBox(height: 16),

          // Status Selection
          Text(
            'تحديث الحالة:',
            style: StyleSystem.bodyMedium.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildStatusButton('processing', 'قيد المعالجة', Colors.blue),
              const SizedBox(width: 8),
              _buildStatusButton('approved', 'موافق عليه', Colors.green),
              const SizedBox(width: 8),
              _buildStatusButton('rejected', 'مرفوض', Colors.red),
            ],
          ),

          const SizedBox(height: 16),

          // Admin Response
          Text(
            'رد الإدارة:',
            style: StyleSystem.bodyMedium.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _responseController,
            maxLines: 4,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'اكتب ردك على طلب الإرجاع...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
              filled: true,
              fillColor: StyleSystem.backgroundDark.withOpacity(0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: StyleSystem.primaryColor.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: StyleSystem.primaryColor.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: StyleSystem.primaryColor),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitResponse,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: StyleSystem.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.send),
                  label: Text(_isSubmitting ? 'جاري الإرسال...' : 'إرسال الرد'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitStatusAndResponse,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.done_all),
                  label: const Text('تحديث وإرسال'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusButton(String status, String label, Color color) {
    final isSelected = _selectedStatus == status;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedStatus = status;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected ? color : color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: color,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : color,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  void _submitResponse() async {
    if (_responseController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى كتابة رد قبل الإرسال')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await widget.onResponseSubmit(_responseController.text.trim());
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل في إرسال الرد: $e')),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _submitStatusAndResponse() async {
    if (_responseController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى كتابة رد قبل الإرسال')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await widget.onStatusAndResponseUpdate(_selectedStatus, _responseController.text.trim());
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل في تحديث طلب الإرجاع: $e')),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }



  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
