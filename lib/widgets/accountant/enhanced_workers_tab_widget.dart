import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../models/user_role.dart';
import '../../providers/supabase_provider.dart';
import '../../screens/accountant/accountant_rewards_management_screen.dart';
import '../../screens/accountant/accountant_task_assignment_screen.dart';
import '../../utils/accountant_theme_config.dart';
import '../../utils/app_logger.dart';

/// Enhanced Workers Tab Widget for Accountant Dashboard
/// Provides both Rewards Management and Task Assignment functionality
class EnhancedWorkersTabWidget extends StatefulWidget {
  const EnhancedWorkersTabWidget({super.key});

  @override
  State<EnhancedWorkersTabWidget> createState() => _EnhancedWorkersTabWidgetState();
}

class _EnhancedWorkersTabWidgetState extends State<EnhancedWorkersTabWidget> {
  List<UserModel> _workers = [];
  bool _isLoading = true;
  Map<String, int> _stats = {'tasks': 0, 'rewards': 0};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await Future.wait([
        _loadWorkersData(),
        _loadTasksAndRewardsStats(),
      ]);
    } catch (e) {
      AppLogger.error('Error loading workers tab data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadWorkersData() async {
    try {
      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
      final workers = await supabaseProvider.getUsersByRole(UserRole.worker.value);
      setState(() {
        _workers = workers;
      });
    } catch (e) {
      AppLogger.error('Error loading workers data: $e');
    }
  }

  Future<void> _loadTasksAndRewardsStats() async {
    try {
      // This would typically load from your database
      // For now, using placeholder values
      setState(() {
        _stats = {'tasks': 25, 'rewards': 12};
      });
    } catch (e) {
      AppLogger.error('Error loading stats: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        decoration: const BoxDecoration(
          gradient: AccountantThemeConfig.mainBackgroundGradient,
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: AccountantThemeConfig.primaryGreen,
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: AccountantThemeConfig.mainBackgroundGradient,
      ),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Header section
          SliverToBoxAdapter(
            child: _buildHeader(),
          ),

          // Management sections
          SliverToBoxAdapter(
            child: _buildManagementSections(),
          ),

          // Statistics section
          SliverToBoxAdapter(
            child: _buildStatisticsSection(),
          ),

          // Workers list
          SliverToBoxAdapter(
            child: _buildWorkersSection(),
          ),

          // Bottom padding
          const SliverToBoxAdapter(
            child: SizedBox(height: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.greenGradient,
        borderRadius: BorderRadius.circular(AccountantThemeConfig.largeBorderRadius),
        boxShadow: AccountantThemeConfig.glowShadows(AccountantThemeConfig.primaryGreen),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.people,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'إدارة العمال والمهام',
                    style: AccountantThemeConfig.headlineLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'متابعة أداء العمال وإسناد المهام ومنح المكافآت',
                    style: AccountantThemeConfig.bodyMedium.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManagementSections() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'إدارة العمال',
            style: AccountantThemeConfig.headlineMedium,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Rewards Management Card
              Expanded(
                child: _buildManagementCard(
                  title: 'منح المكافآت',
                  description: 'إدارة مكافآت العمال وأرصدتهم',
                  icon: Icons.card_giftcard,
                  gradient: AccountantThemeConfig.greenGradient,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AccountantRewardsManagementScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              // Task Assignment Card
              Expanded(
                child: _buildManagementCard(
                  title: 'إسناد المهام',
                  description: 'تكليف العمال بمهام الإنتاج',
                  icon: Icons.engineering,
                  gradient: AccountantThemeConfig.blueGradient,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AccountantTaskAssignmentScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildManagementCard({
    required String title,
    required String description,
    required IconData icon,
    required LinearGradient gradient,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: AccountantThemeConfig.headlineSmall.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: AccountantThemeConfig.bodySmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsSection() {
    final activeWorkers = _workers.where((w) => 
      w.status == 'approved' || w.status == 'active'
    ).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'إحصائيات العمال',
            style: AccountantThemeConfig.headlineMedium,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'إجمالي العمال',
                  '${_workers.length}',
                  Icons.people,
                  AccountantThemeConfig.accentBlue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'العمال النشطين',
                  '${activeWorkers.length}',
                  Icons.people,
                  AccountantThemeConfig.primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'المهام المكتملة',
                  '${_stats['tasks']}',
                  Icons.task_alt,
                  AccountantThemeConfig.warningOrange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'المكافآت الممنوحة',
                  '${_stats['rewards']}',
                  Icons.card_giftcard,
                  Colors.purple,
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
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
        border: AccountantThemeConfig.glowBorder(color),
        boxShadow: AccountantThemeConfig.cardShadows,
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
                    gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0.8)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: AccountantThemeConfig.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: AccountantThemeConfig.headlineMedium.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkersSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          gradient: AccountantThemeConfig.cardGradient,
          borderRadius: BorderRadius.circular(AccountantThemeConfig.largeBorderRadius),
          border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.primaryGreen),
          boxShadow: AccountantThemeConfig.cardShadows,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'قائمة العمال',
                    style: AccountantThemeConfig.headlineSmall,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: AccountantThemeConfig.blueGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_workers.length} عامل',
                      style: AccountantThemeConfig.labelMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildWorkersList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkersList() {
    if (_workers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد عمال مسجلين',
              style: AccountantThemeConfig.bodyLarge.copyWith(
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _workers.take(5).map((worker) => _buildWorkerCard(worker)).toList(),
    );
  }

  Widget _buildWorkerCard(UserModel worker) {
    final isActive = worker.status == 'approved' || worker.status == 'active';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3)
              : AccountantThemeConfig.neutralColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Worker avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: isActive
                  ? AccountantThemeConfig.primaryGreen
                  : AccountantThemeConfig.neutralColor,
              child: Text(
                worker.name.isNotEmpty ? worker.name[0].toUpperCase() : 'ع',
                style: AccountantThemeConfig.bodyLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Worker details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    worker.name,
                    style: AccountantThemeConfig.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    worker.email,
                    style: AccountantThemeConfig.bodySmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),

            // Status indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isActive
                    ? AccountantThemeConfig.primaryGreen.withValues(alpha: 0.2)
                    : AccountantThemeConfig.neutralColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isActive ? 'نشط' : 'غير نشط',
                style: AccountantThemeConfig.labelSmall.copyWith(
                  color: isActive
                      ? AccountantThemeConfig.primaryGreen
                      : AccountantThemeConfig.neutralColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
