import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../utils/accountant_theme_config.dart';
import '../../providers/treasury_provider.dart';
import '../../models/treasury_models.dart';
import '../../services/treasury_limits_service.dart';
import '../../utils/app_logger.dart';

class TreasuryLimitsScreen extends StatefulWidget {
  final String treasuryId;
  final String treasuryName;

  const TreasuryLimitsScreen({
    super.key,
    required this.treasuryId,
    required this.treasuryName,
  });

  @override
  State<TreasuryLimitsScreen> createState() => _TreasuryLimitsScreenState();
}

class _TreasuryLimitsScreenState extends State<TreasuryLimitsScreen>
    with TickerProviderStateMixin {
  final _limitsService = TreasuryLimitsService();
  
  List<TreasuryLimit> _limits = [];
  List<TreasuryAlert> _alerts = [];
  bool _isLoading = false;
  String? _error;

  late TabController _tabController;

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
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _limitsService.getTreasuryLimits(widget.treasuryId),
        _limitsService.getTreasuryAlerts(treasuryId: widget.treasuryId),
      ]);

      setState(() {
        _limits = results[0] as List<TreasuryLimit>;
        _alerts = results[1] as List<TreasuryAlert>;
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
            'حدود وتنبيهات الخزنة',
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            widget.treasuryName,
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
            icon: Icon(Icons.tune_rounded, size: 20),
            text: 'الحدود',
          ),
          Tab(
            icon: Icon(Icons.notifications_rounded, size: 20),
            text: 'التنبيهات',
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
          border: AccountantThemeConfig.glowBorder(Colors.red),
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
        _buildLimitsTab(),
        _buildAlertsTab(),
      ],
    );
  }

  Widget _buildLimitsTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AccountantThemeConfig.primaryGreen,
      backgroundColor: Colors.grey[900],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLimitsHeader(),
            const SizedBox(height: 16),
            if (_limits.isEmpty)
              _buildEmptyLimitsState()
            else
              _buildLimitsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildLimitsHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(12),
        border: AccountantThemeConfig.glowBorder(),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.tune_rounded,
              color: AccountantThemeConfig.primaryGreen,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'حدود الخزنة',
                  style: AccountantThemeConfig.bodyLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'قم بتعيين حدود للرصيد والمعاملات لضمان الأمان',
                  style: AccountantThemeConfig.bodySmall.copyWith(
                    color: AccountantThemeConfig.white70,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AccountantThemeConfig.accentBlue.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_limits.length} حد',
              style: AccountantThemeConfig.bodySmall.copyWith(
                color: AccountantThemeConfig.accentBlue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyLimitsState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: AccountantThemeConfig.glowBorder(),
      ),
      child: Column(
        children: [
          Icon(
            Icons.tune_rounded,
            size: 64,
            color: AccountantThemeConfig.white60,
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد حدود محددة',
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'قم بإضافة حدود للخزنة لضمان الأمان والتحكم في المعاملات',
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: AccountantThemeConfig.white70,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddLimitDialog(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AccountantThemeConfig.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('إضافة حد جديد'),
          ),
        ],
      ),
    );
  }

  Widget _buildLimitsList() {
    return Column(
      children: _limits.map((limit) => _buildLimitCard(limit)).toList(),
    );
  }

  Widget _buildLimitCard(TreasuryLimit limit) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(12),
        border: AccountantThemeConfig.glowBorder(
          limit.isEnabled ? AccountantThemeConfig.primaryGreen : AccountantThemeConfig.white60,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (limit.isEnabled
                      ? AccountantThemeConfig.primaryGreen
                      : AccountantThemeConfig.white60).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getLimitTypeIcon(limit.limitType),
                  color: limit.isEnabled
                      ? AccountantThemeConfig.primaryGreen
                      : AccountantThemeConfig.white60,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      limit.limitType.nameAr,
                      style: AccountantThemeConfig.bodyLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${limit.limitValue.toStringAsFixed(2)} ج.م',
                      style: AccountantThemeConfig.bodyMedium.copyWith(
                        color: AccountantThemeConfig.white70,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: limit.isEnabled,
                onChanged: (value) => _toggleLimit(limit, value),
                activeColor: AccountantThemeConfig.primaryGreen,
              ),
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: Colors.white,
                ),
                color: const Color(0xFF1E293B),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        const Icon(Icons.edit_rounded, color: AccountantThemeConfig.accentBlue, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'تعديل',
                          style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete_rounded, color: Colors.red, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'حذف',
                          style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'edit') {
                    _showEditLimitDialog(limit);
                  } else if (value == 'delete') {
                    _showDeleteLimitDialog(limit);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildThresholdIndicator(
                  'تحذير',
                  limit.warningThreshold,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildThresholdIndicator(
                  'حرج',
                  limit.criticalThreshold,
                  Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThresholdIndicator(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_rounded,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Text(
            '${value.toStringAsFixed(0)}%',
            style: AccountantThemeConfig.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getLimitTypeIcon(TreasuryLimitType type) {
    switch (type) {
      case TreasuryLimitType.minBalance:
        return Icons.trending_down_rounded;
      case TreasuryLimitType.maxBalance:
        return Icons.trending_up_rounded;
      case TreasuryLimitType.dailyTransaction:
        return Icons.today_rounded;
      case TreasuryLimitType.monthlyTransaction:
        return Icons.calendar_month_rounded;
    }
  }

  Widget _buildAlertsTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AccountantThemeConfig.primaryGreen,
      backgroundColor: Colors.grey[900],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAlertsHeader(),
            const SizedBox(height: 16),
            if (_alerts.isEmpty)
              _buildEmptyAlertsState()
            else
              _buildAlertsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsHeader() {
    final pendingAlerts = _alerts.where((alert) => !alert.isAcknowledged).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(12),
        border: AccountantThemeConfig.glowBorder(),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (pendingAlerts > 0 ? Colors.red : AccountantThemeConfig.primaryGreen).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.notifications_rounded,
              color: pendingAlerts > 0 ? Colors.red : AccountantThemeConfig.primaryGreen,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تنبيهات الخزنة',
                  style: AccountantThemeConfig.bodyLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  pendingAlerts > 0
                      ? '$pendingAlerts تنبيه في انتظار المراجعة'
                      : 'جميع التنبيهات تمت مراجعتها',
                  style: AccountantThemeConfig.bodySmall.copyWith(
                    color: AccountantThemeConfig.white70,
                  ),
                ),
              ],
            ),
          ),
          if (pendingAlerts > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$pendingAlerts',
                style: AccountantThemeConfig.bodySmall.copyWith(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyAlertsState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
      ),
      child: Column(
        children: [
          Icon(
            Icons.notifications_off_rounded,
            size: 64,
            color: AccountantThemeConfig.white60,
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد تنبيهات',
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'لا توجد تنبيهات حالياً لهذه الخزنة',
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: AccountantThemeConfig.white70,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsList() {
    return Column(
      children: _alerts.map((alert) => _buildAlertCard(alert)).toList(),
    );
  }

  Widget _buildAlertCard(TreasuryAlert alert) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(12),
        border: AccountantThemeConfig.glowBorder(alert.severityColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: alert.severityColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  alert.alertIcon,
                  color: alert.severityColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.title,
                      style: AccountantThemeConfig.bodyLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      alert.message,
                      style: AccountantThemeConfig.bodyMedium.copyWith(
                        color: AccountantThemeConfig.white70,
                      ),
                    ),
                  ],
                ),
              ),
              if (!alert.isAcknowledged)
                ElevatedButton(
                  onPressed: () => _acknowledgeAlert(alert),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AccountantThemeConfig.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: const Text('إقرار'),
                ),
            ],
          ),
          if (alert.currentValue != null || alert.limitValue != null) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.white24),
            const SizedBox(height: 8),
            Row(
              children: [
                if (alert.currentValue != null)
                  Expanded(
                    child: _buildAlertDetailItem(
                      'القيمة الحالية',
                      '${alert.currentValue!.toStringAsFixed(2)} ج.م',
                    ),
                  ),
                if (alert.limitValue != null)
                  Expanded(
                    child: _buildAlertDetailItem(
                      'الحد المحدد',
                      '${alert.limitValue!.toStringAsFixed(2)} ج.م',
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                alert.severity.nameAr,
                style: AccountantThemeConfig.bodySmall.copyWith(
                  color: alert.severityColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _formatDateTime(alert.createdAt),
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

  Widget _buildAlertDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AccountantThemeConfig.bodySmall.copyWith(
            color: AccountantThemeConfig.white60,
          ),
        ),
        Text(
          value,
          style: AccountantThemeConfig.bodyMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: () => _showAddLimitDialog(),
      backgroundColor: AccountantThemeConfig.primaryGreen,
      child: const Icon(
        Icons.add_rounded,
        color: Colors.white,
      ),
    );
  }

  Future<void> _toggleLimit(TreasuryLimit limit, bool isEnabled) async {
    try {
      await _limitsService.saveTreasuryLimit(
        limitId: limit.id,
        treasuryId: limit.treasuryId,
        limitType: limit.limitType,
        limitValue: limit.limitValue,
        warningThreshold: limit.warningThreshold,
        criticalThreshold: limit.criticalThreshold,
        isEnabled: isEnabled,
      );

      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _acknowledgeAlert(TreasuryAlert alert) async {
    try {
      await _limitsService.acknowledgeTreasuryAlert(alert.id);
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم إقرار التنبيه بنجاح',
              style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
            ),
            backgroundColor: AccountantThemeConfig.primaryGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddLimitDialog() {
    // TODO: Implement add limit dialog
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

  void _showEditLimitDialog(TreasuryLimit limit) {
    // TODO: Implement edit limit dialog
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

  void _showDeleteLimitDialog(TreasuryLimit limit) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          'حذف الحد',
          style: AccountantThemeConfig.headlineSmall.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'هل أنت متأكد من حذف حد "${limit.limitType.nameAr}"؟',
          style: AccountantThemeConfig.bodyMedium.copyWith(
            color: AccountantThemeConfig.white70,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'إلغاء',
              style: AccountantThemeConfig.bodyMedium.copyWith(
                color: Colors.white,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _limitsService.deleteTreasuryLimit(limit.id);
                await _loadData();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'تم حذف الحد بنجاح',
                        style: AccountantThemeConfig.bodyMedium.copyWith(color: Colors.white),
                      ),
                      backgroundColor: AccountantThemeConfig.primaryGreen,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString()),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return 'منذ ${difference.inDays} يوم';
    } else if (difference.inHours > 0) {
      return 'منذ ${difference.inHours} ساعة';
    } else if (difference.inMinutes > 0) {
      return 'منذ ${difference.inMinutes} دقيقة';
    } else {
      return 'الآن';
    }
  }
}
