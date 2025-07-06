import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/accountant_theme_config.dart';
import '../../models/treasury_models.dart';
import '../../services/treasury_audit_service.dart';
import '../../utils/app_logger.dart';

class TreasuryAuditTrailScreen extends StatefulWidget {
  final String? entityId;
  final TreasuryAuditEntityType? entityType;

  const TreasuryAuditTrailScreen({
    super.key,
    this.entityId,
    this.entityType,
  });

  @override
  State<TreasuryAuditTrailScreen> createState() => _TreasuryAuditTrailScreenState();
}

class _TreasuryAuditTrailScreenState extends State<TreasuryAuditTrailScreen>
    with TickerProviderStateMixin {
  final _auditService = TreasuryAuditService();
  
  List<TreasuryAuditLog> _auditLogs = [];
  Map<String, dynamic> _statistics = {};
  bool _isLoading = false;
  String? _error;

  // Filters
  TreasuryAuditEntityType? _selectedEntityType;
  TreasuryAuditActionType? _selectedActionType;
  TreasuryAuditSeverity? _selectedSeverity;
  DateTime? _startDate;
  DateTime? _endDate;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedEntityType = widget.entityType;
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _auditService.getAuditTrail(
          entityType: _selectedEntityType,
          entityId: widget.entityId,
          actionType: _selectedActionType,
          severity: _selectedSeverity,
          startDate: _startDate,
          endDate: _endDate,
          limit: 100,
        ),
        _auditService.getAuditStatistics(
          startDate: _startDate ?? DateTime.now().subtract(const Duration(days: 30)),
          endDate: _endDate ?? DateTime.now(),
        ),
      ]);

      setState(() {
        _auditLogs = results[0] as List<TreasuryAuditLog>;
        _statistics = results[1] as Map<String, dynamic>;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AccountantThemeConfig.backgroundColor,
      appBar: _buildAppBar(),
      body: _isLoading
          ? _buildLoadingState()
          : _error != null
              ? _buildErrorState()
              : _buildContent(),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(
          Icons.arrow_back_ios_rounded,
          color: Colors.white,
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'سجل المراجعة',
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            widget.entityType != null 
                ? 'مراجعة ${widget.entityType!.nameAr}'
                : 'جميع العمليات',
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: AccountantThemeConfig.white70,
            ),
          ),
        ],
      ),
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: AccountantThemeConfig.primaryGreen,
        labelColor: Colors.white,
        unselectedLabelColor: AccountantThemeConfig.white60,
        labelStyle: AccountantThemeConfig.bodyMedium.copyWith(
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: AccountantThemeConfig.bodyMedium,
        tabs: const [
          Tab(
            icon: Icon(Icons.list_rounded, size: 20),
            text: 'السجل',
          ),
          Tab(
            icon: Icon(Icons.analytics_rounded, size: 20),
            text: 'الإحصائيات',
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(AccountantThemeConfig.primaryGreen),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: AccountantThemeConfig.cardGradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'حدث خطأ',
              style: AccountantThemeConfig.headlineSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: AccountantThemeConfig.white70,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(
                backgroundColor: AccountantThemeConfig.primaryGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildAuditLogTab(),
        _buildStatisticsTab(),
      ],
    );
  }

  Widget _buildAuditLogTab() {
    return Column(
      children: [
        _buildFiltersSection(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            color: AccountantThemeConfig.primaryGreen,
            backgroundColor: Colors.grey[900],
            child: _auditLogs.isEmpty
                ? _buildEmptyState()
                : _buildAuditLogsList(),
          ),
        ),
      ],
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AccountantThemeConfig.accentBlue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.filter_list_rounded,
                color: AccountantThemeConfig.accentBlue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'تصفية النتائج',
                style: AccountantThemeConfig.bodyLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _clearFilters,
                child: Text(
                  'مسح الكل',
                  style: AccountantThemeConfig.bodySmall.copyWith(
                    color: AccountantThemeConfig.accentBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildFilterChip(
                'نوع الكيان',
                _selectedEntityType?.nameAr ?? 'الكل',
                () => _showEntityTypeFilter(),
              ),
              _buildFilterChip(
                'نوع العملية',
                _selectedActionType?.nameAr ?? 'الكل',
                () => _showActionTypeFilter(),
              ),
              _buildFilterChip(
                'الأهمية',
                _selectedSeverity?.nameAr ?? 'الكل',
                () => _showSeverityFilter(),
              ),
              _buildFilterChip(
                'التاريخ',
                _getDateRangeText(),
                () => _showDateRangeFilter(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label: ',
              style: AccountantThemeConfig.bodySmall.copyWith(
                color: AccountantThemeConfig.white60,
              ),
            ),
            Text(
              value,
              style: AccountantThemeConfig.bodySmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_rounded,
              size: 64,
              color: AccountantThemeConfig.white60,
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد سجلات',
              style: AccountantThemeConfig.headlineSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'لا توجد سجلات مراجعة تطابق المعايير المحددة',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: AccountantThemeConfig.white70,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditLogsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _auditLogs.length,
      itemBuilder: (context, index) {
        final log = _auditLogs[index];
        return _buildAuditLogCard(log);
      },
    );
  }

  Widget _buildAuditLogCard(TreasuryAuditLog log) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: log.severity.severityColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: log.severity.severityColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  log.actionIcon,
                  color: log.severity.severityColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log.actionDescription,
                      style: AccountantThemeConfig.bodyLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${log.entityType.nameAr} • ${log.actionType.nameAr}',
                      style: AccountantThemeConfig.bodyMedium.copyWith(
                        color: AccountantThemeConfig.white70,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: log.severity.severityColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  log.severity.nameAr,
                  style: AccountantThemeConfig.bodySmall.copyWith(
                    color: log.severity.severityColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (log.userEmail != null)
                Row(
                  children: [
                    const Icon(
                      Icons.person_rounded,
                      color: AccountantThemeConfig.white60,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      log.userEmail!,
                      style: AccountantThemeConfig.bodySmall.copyWith(
                        color: AccountantThemeConfig.white60,
                      ),
                    ),
                  ],
                ),
              Text(
                log.timeAgo,
                style: AccountantThemeConfig.bodySmall.copyWith(
                  color: AccountantThemeConfig.white60,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatisticsOverview(),
          const SizedBox(height: 16),
          _buildActionTypeChart(),
        ],
      ),
    );
  }

  Widget _buildStatisticsOverview() {
    final totalActions = _statistics['total_actions'] as int? ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'نظرة عامة',
            style: AccountantThemeConfig.bodyLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'إجمالي العمليات',
                  totalActions.toString(),
                  Icons.analytics_rounded,
                  AccountantThemeConfig.primaryGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: AccountantThemeConfig.white70,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActionTypeChart() {
    final actionsByType = _statistics['actions_by_type'] as Map<String, dynamic>? ?? {};

    if (actionsByType.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AccountantThemeConfig.accentBlue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'العمليات حسب النوع',
            style: AccountantThemeConfig.bodyLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...actionsByType.entries.map((entry) {
            final actionType = TreasuryAuditActionType.fromCode(entry.key);
            final count = entry.value as int;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    actionType.code == 'create' ? Icons.add_circle_rounded :
                    actionType.code == 'update' ? Icons.edit_rounded :
                    actionType.code == 'delete' ? Icons.delete_rounded :
                    Icons.visibility_rounded,
                    color: AccountantThemeConfig.accentBlue,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      actionType.nameAr,
                      style: AccountantThemeConfig.bodyMedium.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AccountantThemeConfig.accentBlue.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      count.toString(),
                      style: AccountantThemeConfig.bodySmall.copyWith(
                        color: AccountantThemeConfig.accentBlue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: _loadData,
      backgroundColor: AccountantThemeConfig.primaryGreen,
      child: const Icon(
        Icons.refresh_rounded,
        color: Colors.white,
      ),
    );
  }

  void _clearFilters() {
    setState(() {
      _selectedEntityType = widget.entityType;
      _selectedActionType = null;
      _selectedSeverity = null;
      _startDate = null;
      _endDate = null;
    });
    _loadData();
  }

  void _showEntityTypeFilter() {
    // TODO: Implement entity type filter dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'سيتم تنفيذ هذه الميزة قريباً',
          style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
        ),
        backgroundColor: AccountantThemeConfig.accentBlue,
      ),
    );
  }

  void _showActionTypeFilter() {
    // TODO: Implement action type filter dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'سيتم تنفيذ هذه الميزة قريباً',
          style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
        ),
        backgroundColor: AccountantThemeConfig.accentBlue,
      ),
    );
  }

  void _showSeverityFilter() {
    // TODO: Implement severity filter dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'سيتم تنفيذ هذه الميزة قريباً',
          style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
        ),
        backgroundColor: AccountantThemeConfig.accentBlue,
      ),
    );
  }

  void _showDateRangeFilter() {
    // TODO: Implement date range filter dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'سيتم تنفيذ هذه الميزة قريباً',
          style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
        ),
        backgroundColor: AccountantThemeConfig.accentBlue,
      ),
    );
  }

  String _getDateRangeText() {
    if (_startDate == null && _endDate == null) {
      return 'الكل';
    } else if (_startDate != null && _endDate != null) {
      return 'فترة محددة';
    } else if (_startDate != null) {
      return 'من تاريخ محدد';
    } else {
      return 'حتى تاريخ محدد';
    }
  }
}
