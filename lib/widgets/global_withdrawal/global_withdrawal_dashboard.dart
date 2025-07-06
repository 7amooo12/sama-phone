import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/global_withdrawal_models.dart';
import '../../providers/global_withdrawal_provider.dart';
import '../../config/accountant_theme_config.dart';
import '../../utils/app_logger.dart';
import 'global_withdrawal_request_card.dart';
import 'global_withdrawal_creation_dialog.dart';

/// لوحة تحكم طلبات السحب العالمية
class GlobalWithdrawalDashboard extends StatefulWidget {
  const GlobalWithdrawalDashboard({super.key});

  @override
  State<GlobalWithdrawalDashboard> createState() => _GlobalWithdrawalDashboardState();
}

class _GlobalWithdrawalDashboardState extends State<GlobalWithdrawalDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedStatus = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final provider = context.read<GlobalWithdrawalProvider>();
    await provider.loadGlobalRequests();
    await provider.loadPerformanceStats();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.backgroundGradient,
      ),
      child: Column(
        children: [
          _buildHeader(),
          _buildStatsCards(),
          _buildTabBar(),
          Expanded(
            child: _buildTabContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        boxShadow: AccountantThemeConfig.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AccountantThemeConfig.primaryColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.inventory_2,
              color: AccountantThemeConfig.primaryColor,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'نظام السحب العالمي',
                  style: AccountantThemeConfig.headingStyle.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'إدارة طلبات السحب بدون ربط بمخازن محددة',
                  style: AccountantThemeConfig.bodyStyle.copyWith(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Consumer<GlobalWithdrawalProvider>(
      builder: (context, provider, child) {
        return Row(
          children: [
            // زر إنشاء طلب جديد
            ElevatedButton.icon(
              onPressed: provider.isLoading ? null : _showCreateRequestDialog,
              icon: const Icon(Icons.add),
              label: const Text('طلب جديد'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AccountantThemeConfig.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            // زر معالجة تلقائية
            ElevatedButton.icon(
              onPressed: provider.isProcessing ? null : _processAllCompleted,
              icon: provider.isProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.auto_fix_high),
              label: Text(provider.isProcessing ? 'جاري المعالجة...' : 'معالجة تلقائية'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            // زر التحديث
            IconButton(
              onPressed: provider.isLoading ? null : _refreshData,
              icon: Icon(
                Icons.refresh,
                color: provider.isLoading ? Colors.white54 : Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatsCards() {
    return Consumer<GlobalWithdrawalProvider>(
      builder: (context, provider, child) {
        final stats = provider.quickStats;
        final performance = provider.performanceStats;

        return Container(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'إجمالي الطلبات',
                  '${stats['total']}',
                  Icons.inventory,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'طلبات عالمية',
                  '${stats['global']}',
                  Icons.public,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'معالجة تلقائية',
                  '${stats['auto_processed']}',
                  Icons.auto_awesome,
                  Colors.purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'نسبة النجاح',
                  '${performance?.successRate.toStringAsFixed(1) ?? '0'}%',
                  Icons.trending_up,
                  Colors.orange,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AccountantThemeConfig.cardShadow,
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: AccountantThemeConfig.headingStyle.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: AccountantThemeConfig.bodyStyle.copyWith(
              fontSize: 12,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AccountantThemeConfig.primaryColor,
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        tabs: const [
          Tab(text: 'جميع الطلبات'),
          Tab(text: 'في الانتظار'),
          Tab(text: 'مكتملة'),
          Tab(text: 'الإحصائيات'),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildRequestsList('all'),
        _buildRequestsList('pending'),
        _buildRequestsList('completed'),
        _buildPerformanceTab(),
      ],
    );
  }

  Widget _buildRequestsList(String status) {
    return Consumer<GlobalWithdrawalProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text(
                  'جاري تحميل الطلبات...',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          );
        }

        if (provider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  provider.error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _refreshData,
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          );
        }

        final requests = status == 'all' 
            ? provider.requests
            : provider.getRequestsByStatus(status);

        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 64,
                  color: Colors.white54,
                ),
                const SizedBox(height: 16),
                Text(
                  status == 'all' 
                      ? 'لا توجد طلبات سحب'
                      : 'لا توجد طلبات ${_getStatusText(status)}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'ابدأ بإنشاء طلب سحب عالمي جديد',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            return GlobalWithdrawalRequestCard(
              request: request,
              onTap: () => _selectRequest(request),
              onProcess: request.status == 'completed' && !request.isAutoProcessed
                  ? () => _processRequest(request.id)
                  : null,
            );
          },
        );
      },
    );
  }

  Widget _buildPerformanceTab() {
    return Consumer<GlobalWithdrawalProvider>(
      builder: (context, provider, child) {
        final performance = provider.performanceStats;

        if (performance == null) {
          return const Center(
            child: Text(
              'لا توجد بيانات أداء متاحة',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'إحصائيات الأداء',
                style: AccountantThemeConfig.headingStyle.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              // بطاقات الأداء
              Row(
                children: [
                  Expanded(
                    child: _buildPerformanceCard(
                      'معدل النجاح',
                      '${performance.successRate.toStringAsFixed(1)}%',
                      Icons.check_circle,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildPerformanceCard(
                      'متوسط وقت المعالجة',
                      '${performance.averageProcessingTime.toStringAsFixed(1)}s',
                      Icons.timer,
                      Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildPerformanceCard(
                      'متوسط المخازن/طلب',
                      performance.averageWarehousesPerRequest.toStringAsFixed(1),
                      Icons.warehouse,
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildPerformanceCard(
                      'كفاءة التخصيص',
                      '${performance.averageAllocationEfficiency.toStringAsFixed(1)}%',
                      Icons.trending_up,
                      Colors.purple,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPerformanceCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AccountantThemeConfig.cardShadow,
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: AccountantThemeConfig.headingStyle.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: AccountantThemeConfig.bodyStyle.copyWith(
              fontSize: 12,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'في الانتظار';
      case 'completed':
        return 'مكتملة';
      case 'cancelled':
        return 'ملغية';
      default:
        return status;
    }
  }

  void _showCreateRequestDialog() {
    showDialog(
      context: context,
      builder: (context) => const GlobalWithdrawalCreationDialog(),
    ).then((created) {
      if (created == true) {
        _refreshData();
      }
    });
  }

  Future<void> _processAllCompleted() async {
    final provider = context.read<GlobalWithdrawalProvider>();
    final count = await provider.processAllCompletedRequests();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم معالجة $count طلب تلقائياً'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _processRequest(String requestId) async {
    final provider = context.read<GlobalWithdrawalProvider>();
    final success = await provider.processGlobalRequest(requestId: requestId);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'تم معالجة الطلب بنجاح' : 'فشل في معالجة الطلب'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _selectRequest(GlobalWithdrawalRequest request) {
    final provider = context.read<GlobalWithdrawalProvider>();
    provider.selectRequest(request.id);
    
    // يمكن إضافة navigation إلى صفحة تفاصيل الطلب هنا
    AppLogger.info('تم تحديد الطلب: ${request.id}');
  }

  Future<void> _refreshData() async {
    final provider = context.read<GlobalWithdrawalProvider>();
    await provider.loadGlobalRequests(forceRefresh: true);
    await provider.loadPerformanceStats();
  }
}
