import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/worker_rewards_provider.dart';
import '../../providers/supabase_provider.dart';
import '../../models/worker_reward_model.dart';
import '../../models/user_role.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_loader.dart';
import '../../utils/style_system.dart';

class AdminRewardsManagementScreen extends StatefulWidget {
  const AdminRewardsManagementScreen({super.key});

  @override
  State<AdminRewardsManagementScreen> createState() => _AdminRewardsManagementScreenState();
}

class _AdminRewardsManagementScreenState extends State<AdminRewardsManagementScreen> {
  List<Map<String, dynamic>> _workers = [];
  bool _isLoadingWorkers = false;
  String? _selectedWorkerId;
  String _selectedFilter = 'all'; // all, individual, recent

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final provider = context.read<WorkerRewardsProvider>();
    await provider.fetchRewards();
    await provider.fetchRewardBalances();
    await _loadWorkers();
  }

  Future<void> _loadWorkers() async {
    setState(() {
      _isLoadingWorkers = true;
    });

    try {
      // Debug print removed for production

      // استخدام نفس الطريقة المستخدمة في صفحة إسناد المهام
      final allWorkers = await Provider.of<SupabaseProvider>(context, listen: false)
          .getUsersByRole(UserRole.worker.value);

      // تصفية العمال المعتمدين مع مرونة في فحص الحالة
      final approvedWorkers = allWorkers.where((worker) =>
        worker.isApproved ||
        worker.status == 'approved' ||
        worker.status == 'active'
      ).toList();

      // Debug print removed for production

      // تحويل UserModel إلى Map للتوافق مع باقي الكود
      final workersMap = approvedWorkers.map((worker) => {
        'id': worker.id,
        'name': worker.name,
        'email': worker.email,
        'role': worker.role.value,
        'status': worker.status,
      }).toList();

      // Debug information removed for production

      setState(() {
        _workers = workersMap;
      });

      if (workersMap.isEmpty) {
        // Debug print removed for production
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.white),
                  SizedBox(width: 8),
                  Text('لا يوجد عمال معتمدين في النظام'),
                ],
              ),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      } else {
        // Debug print removed for production
      }
    } catch (e) {
      // Debug print removed for production
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('خطأ في تحميل قائمة العمال: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoadingWorkers = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StyleSystem.backgroundDark,
      appBar: CustomAppBar(
        title: 'إدارة مكافآت العمال',
        backgroundColor: StyleSystem.primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Consumer<WorkerRewardsProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading || _isLoadingWorkers) {
            return const CustomLoader(message: 'جاري تحميل البيانات...');
          }

          if (provider.error != null) {
            return _buildErrorState(provider.error!);
          }

          return RefreshIndicator(
            onRefresh: _loadData,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildQuickRewardSection(),
                  const SizedBox(height: 20),
                  _buildFilterSection(),
                  const SizedBox(height: 20),
                  _buildSummaryCards(provider),
                  const SizedBox(height: 20),
                  _buildWorkersSection(provider),
                  const SizedBox(height: 20),
                  _buildRecentRewardsSection(provider),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickRewardSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            StyleSystem.primaryColor,
            StyleSystem.primaryColor.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: StyleSystem.elevatedCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.card_giftcard_rounded,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'منح مكافأة سريعة',
                style: StyleSystem.titleLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedWorkerId,
                      hint: const Text(
                        'اختر العامل',
                        style: TextStyle(color: Colors.white70),
                      ),
                      dropdownColor: StyleSystem.surfaceDark,
                      style: const TextStyle(color: Colors.white),
                      items: _workers.map((worker) {
                        return DropdownMenuItem<String>(
                          value: worker['id']?.toString(),
                          child: Text(
                            worker['name']?.toString() ?? 'غير محدد',
                            style: const TextStyle(color: Colors.white),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedWorkerId = value;
                        });
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _selectedWorkerId != null
                    ? () {
                        final selectedWorker = _workers.firstWhere(
                          (w) => w['id'] == _selectedWorkerId,
                          orElse: () => {'name': 'غير محدد'},
                        );
                        _showRewardDialog(_selectedWorkerId!, selectedWorker['name']?.toString() ?? 'غير محدد');
                      }
                    : null,
                icon: const Icon(Icons.add_rounded),
                label: const Text('منح مكافأة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: StyleSystem.primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: StyleSystem.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: StyleSystem.neutralMedium.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تصفية وعرض المكافآت',
            style: StyleSystem.titleMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: StyleSystem.backgroundDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: StyleSystem.neutralMedium.withValues(alpha: 0.3)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedFilter,
                      dropdownColor: StyleSystem.surfaceDark,
                      style: const TextStyle(color: Colors.white),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('جميع المكافآت')),
                        DropdownMenuItem(value: 'individual', child: Text('مكافآت عامل محدد')),
                        DropdownMenuItem(value: 'recent', child: Text('المكافآت الأخيرة')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedFilter = value!;
                        });
                      },
                    ),
                  ),
                ),
              ),
              if (_selectedFilter == 'individual') ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: StyleSystem.backgroundDark,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: StyleSystem.neutralMedium.withValues(alpha: 0.3)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedWorkerId,
                        hint: const Text('اختر العامل', style: TextStyle(color: Colors.white70)),
                        dropdownColor: StyleSystem.surfaceDark,
                        style: const TextStyle(color: Colors.white),
                        items: _workers.map((worker) {
                          return DropdownMenuItem<String>(
                            value: worker['id']?.toString(),
                            child: Text(worker['name']?.toString() ?? 'غير محدد'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedWorkerId = value;
                          });
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(WorkerRewardsProvider provider) {
    final totalRewards = provider.rewards
        .where((r) => r.status == RewardStatus.active)
        .fold(0.0, (sum, reward) => sum + ((reward.amount as num?)?.toDouble() ?? 0.0));

    final totalWorkers = _workers.length;
    final activeRewards = provider.rewards
        .where((r) => r.status == RewardStatus.active)
        .length;

    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            title: 'إجمالي المكافآت',
            value: '${NumberFormat('#,##0.00').format(totalRewards)} جنيه',
            icon: Icons.payments_rounded,
            color: StyleSystem.successColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            title: 'عدد العمال',
            value: '$totalWorkers',
            icon: Icons.people_rounded,
            color: StyleSystem.primaryColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            title: 'المكافآت النشطة',
            value: '$activeRewards',
            icon: Icons.star_rounded,
            color: StyleSystem.accentColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            StyleSystem.surfaceDark,
            StyleSystem.surfaceDark.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: StyleSystem.elevatedCardShadow,
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: StyleSystem.bodySmall.copyWith(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: StyleSystem.titleMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkersSection(WorkerRewardsProvider provider) {
    // Apply filtering based on selected filter
    List<Map<String, dynamic>> filteredWorkers = _workers;
    if (_selectedFilter == 'individual' && _selectedWorkerId != null) {
      filteredWorkers = _workers.where((w) => w['id'] == _selectedWorkerId).toList();
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            StyleSystem.surfaceDark,
            StyleSystem.surfaceDark.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: StyleSystem.elevatedCardShadow,
        border: Border.all(
          color: StyleSystem.primaryColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(
                  Icons.people_rounded,
                  color: StyleSystem.primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'إدارة مكافآت العمال',
                  style: StyleSystem.titleLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                if (_selectedFilter == 'individual' && _selectedWorkerId != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: StyleSystem.primaryColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: StyleSystem.primaryColor.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      'عرض عامل محدد',
                      style: StyleSystem.bodySmall.copyWith(
                        color: StyleSystem.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (filteredWorkers.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.person_off_rounded,
                          size: 48,
                          color: Colors.orange,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _selectedFilter == 'individual'
                              ? 'لم يتم اختيار عامل للعرض'
                              : 'لا يوجد عمال مسجلين',
                          style: StyleSystem.titleMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedFilter == 'individual'
                              ? 'يرجى اختيار عامل من القائمة المنسدلة أعلاه'
                              : 'يرجى التأكد من وجود عمال مسجلين ومعتمدين في النظام',
                          style: StyleSystem.bodyMedium.copyWith(
                            color: Colors.white70,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_selectedFilter != 'individual') ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loadWorkers,
                            icon: const Icon(Icons.refresh),
                            label: const Text('إعادة تحميل'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredWorkers.length,
              separatorBuilder: (context, index) => Divider(
                color: Colors.white.withValues(alpha: 0.1),
                height: 1,
              ),
              itemBuilder: (context, index) {
                final worker = filteredWorkers[index];
                final balance = provider.balances.firstWhere(
                  (b) => b.workerId == worker['id']?.toString(),
                  orElse: () => WorkerRewardBalanceModel(
                    workerId: worker['id']?.toString() ?? '',
                    currentBalance: 0.0,
                    totalEarned: 0.0,
                    totalWithdrawn: 0.0,
                    lastUpdated: DateTime.now(),
                  ),
                );
                return _buildWorkerCard(worker, balance, provider);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWorkerCard(
    Map<String, dynamic> worker,
    WorkerRewardBalanceModel balance,
    WorkerRewardsProvider provider,
  ) {
    final workerRewards = provider.rewards.where((r) => r.workerId == worker['id']?.toString()).toList();
    final recentRewardsCount = workerRewards.length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: StyleSystem.backgroundDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: StyleSystem.primaryColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.person_rounded,
                  color: StyleSystem.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      worker['name']?.toString() ?? 'غير محدد',
                      style: StyleSystem.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      worker['email']?.toString() ?? '',
                      style: StyleSystem.bodySmall.copyWith(
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _showRewardDialog(worker['id']?.toString() ?? '', worker['name']?.toString() ?? 'عامل غير معروف'),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('مكافأة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: StyleSystem.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: balance.currentBalance > 0
                        ? () => _showClearAccountDialog(worker['id']?.toString() ?? '', worker['name']?.toString() ?? 'عامل غير معروف', balance.currentBalance)
                        : null,
                    icon: const Icon(Icons.clear_all_rounded, size: 16),
                    label: const Text('تصفية'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: StyleSystem.errorColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildWorkerStatCard(
                  'الرصيد الحالي',
                  '${NumberFormat('#,##0.00').format(balance.currentBalance)} جنيه',
                  Icons.account_balance_wallet_rounded,
                  StyleSystem.successColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildWorkerStatCard(
                  'إجمالي المكافآت',
                  '${NumberFormat('#,##0.00').format(balance.totalEarned)} جنيه',
                  Icons.payments_rounded,
                  StyleSystem.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildWorkerStatCard(
                  'عدد المكافآت',
                  '$recentRewardsCount',
                  Icons.star_rounded,
                  StyleSystem.accentColor,
                ),
              ),
            ],
          ),
          if (_selectedFilter == 'individual' && _selectedWorkerId == worker['id']?.toString()) ...[
            const SizedBox(height: 16),
            _buildWorkerRewardsHistory(workerRewards),
          ],
        ],
      ),
    );
  }

  Widget _buildWorkerStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            title,
            style: StyleSystem.bodySmall.copyWith(
              color: Colors.white70,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: StyleSystem.bodySmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildWorkerRewardsHistory(List<WorkerRewardModel> rewards) {
    if (rewards.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.history_rounded, color: Colors.white54, size: 20),
            const SizedBox(width: 8),
            Text(
              'لا توجد مكافآت لهذا العامل',
              style: StyleSystem.bodySmall.copyWith(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.history_rounded, color: StyleSystem.primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  'سجل المكافآت (${rewards.length})',
                  style: StyleSystem.titleSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rewards.take(5).length, // Show only last 5 rewards
            separatorBuilder: (context, index) => Divider(
              color: Colors.white.withValues(alpha: 0.1),
              height: 1,
            ),
            itemBuilder: (context, index) {
              final reward = rewards[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _getRewardTypeColor(reward.rewardType).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(
                        _getRewardTypeIcon(reward.rewardType),
                        color: _getRewardTypeColor(reward.rewardType),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reward.description?.toString() ?? reward.rewardTypeDisplayName.toString() ?? '',
                            style: StyleSystem.bodySmall.copyWith(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            DateFormat('dd/MM/yyyy').format(reward.awardedAt),
                            style: StyleSystem.bodySmall.copyWith(
                              color: Colors.white60,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${((reward.amount as num?)?.toDouble() ?? 0.0) >= 0 ? '+' : ''}${NumberFormat('#,##0.00').format((reward.amount as num?)?.toDouble() ?? 0.0)}',
                      style: StyleSystem.bodySmall.copyWith(
                        color: ((reward.amount as num?)?.toDouble() ?? 0.0) >= 0 ? StyleSystem.successColor : StyleSystem.errorColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          if (rewards.length > 5)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Center(
                child: TextButton(
                  onPressed: () => _showFullRewardsHistory(rewards),
                  child: Text(
                    'عرض جميع المكافآت (${rewards.length})',
                    style: StyleSystem.bodySmall.copyWith(
                      color: StyleSystem.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecentRewardsSection(WorkerRewardsProvider provider) {
    List<WorkerRewardModel> recentRewards = provider.rewards;

    // Apply filtering
    if (_selectedFilter == 'individual' && _selectedWorkerId != null) {
      recentRewards = provider.rewards.where((r) => r.workerId == _selectedWorkerId).toList();
    } else if (_selectedFilter == 'recent') {
      recentRewards = provider.rewards.take(10).toList();
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            StyleSystem.surfaceDark,
            StyleSystem.surfaceDark.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: StyleSystem.elevatedCardShadow,
        border: Border.all(
          color: StyleSystem.primaryColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(
                  Icons.history_rounded,
                  color: StyleSystem.primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  _selectedFilter == 'individual'
                      ? 'مكافآت العامل المحدد'
                      : 'المكافآت الأخيرة',
                  style: StyleSystem.titleLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: StyleSystem.primaryColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${recentRewards.length} مكافأة',
                    style: StyleSystem.bodySmall.copyWith(
                      color: StyleSystem.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (recentRewards.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(
                    Icons.card_giftcard_outlined,
                    size: 48,
                    color: Colors.white54,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _selectedFilter == 'individual'
                        ? 'لا توجد مكافآت لهذا العامل'
                        : 'لا توجد مكافآت بعد',
                    style: StyleSystem.bodyMedium.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recentRewards.length,
              separatorBuilder: (context, index) => Divider(
                color: Colors.white.withValues(alpha: 0.1),
                height: 1,
              ),
              itemBuilder: (context, index) {
                final reward = recentRewards[index];
                return _buildRewardItem(reward);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRewardItem(WorkerRewardModel reward) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: StyleSystem.backgroundDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getRewardTypeColor(reward.rewardType).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getRewardTypeIcon(reward.rewardType),
              color: _getRewardTypeColor(reward.rewardType),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reward.workerName?.toString() ?? 'غير محدد',
                  style: StyleSystem.titleSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  reward.rewardTypeDisplayName.toString() ?? '',
                  style: StyleSystem.bodySmall.copyWith(
                    color: Colors.white70,
                  ),
                ),
                if (reward.description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    reward.description?.toString() ?? '',
                    style: StyleSystem.bodySmall.copyWith(
                      color: Colors.white60,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${((reward.amount as num?)?.toDouble() ?? 0.0) >= 0 ? '+' : ''}${NumberFormat('#,##0.00').format((reward.amount as num?)?.toDouble() ?? 0.0)}',
                style: StyleSystem.titleSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: ((reward.amount as num?)?.toDouble() ?? 0.0) >= 0 ? StyleSystem.successColor : StyleSystem.errorColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                DateFormat('dd/MM/yyyy').format(reward.awardedAt),
                style: StyleSystem.bodySmall.copyWith(
                  color: Colors.white60,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showFullRewardsHistory(List<WorkerRewardModel> rewards) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: StyleSystem.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.history_rounded, color: StyleSystem.primaryColor, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'سجل المكافآت الكامل',
                    style: StyleSystem.titleLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: rewards.length,
                  separatorBuilder: (context, index) => Divider(
                    color: Colors.white.withValues(alpha: 0.1),
                    height: 1,
                  ),
                  itemBuilder: (context, index) {
                    final reward = rewards[index];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: _getRewardTypeColor(reward.rewardType).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              _getRewardTypeIcon(reward.rewardType),
                              color: _getRewardTypeColor(reward.rewardType),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  reward.description?.toString() ?? reward.rewardTypeDisplayName.toString() ?? '',
                                  style: StyleSystem.bodyMedium.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('dd/MM/yyyy - HH:mm').format(reward.awardedAt),
                                  style: StyleSystem.bodySmall.copyWith(
                                    color: Colors.white60,
                                  ),
                                ),
                                if (reward.awardedByName != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'منحت بواسطة: ${reward.awardedByName?.toString() ?? ''}',
                                    style: StyleSystem.bodySmall.copyWith(
                                      color: Colors.white60,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Text(
                            '${((reward.amount as num?)?.toDouble() ?? 0.0) >= 0 ? '+' : ''}${NumberFormat('#,##0.00').format((reward.amount as num?)?.toDouble() ?? 0.0)} جنيه',
                            style: StyleSystem.titleSmall.copyWith(
                              color: ((reward.amount as num?)?.toDouble() ?? 0.0) >= 0 ? StyleSystem.successColor : StyleSystem.errorColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRewardDialog(String workerId, String workerName) {
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    RewardType selectedType = RewardType.monetary;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: StyleSystem.surfaceDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.card_giftcard_rounded, color: StyleSystem.primaryColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'منح مكافأة لـ $workerName',
                  style: StyleSystem.titleLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // نوع المكافأة
                Text(
                  'نوع المكافأة',
                  style: StyleSystem.titleSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: StyleSystem.backgroundDark,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<RewardType>(
                      value: selectedType,
                      isExpanded: true,
                      dropdownColor: StyleSystem.surfaceDark,
                      style: const TextStyle(color: Colors.white),
                      items: RewardType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(_getRewardTypeDisplayName(type)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedType = value!;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // المبلغ
                Text(
                  'المبلغ (جنيه)',
                  style: StyleSystem.titleSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: StyleSystem.backgroundDark,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextFormField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'أدخل المبلغ',
                      hintStyle: TextStyle(color: Colors.white60),
                      suffixText: 'جنيه',
                      suffixStyle: TextStyle(color: Colors.white70),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'المبلغ مطلوب';
                      }
                      if (double.tryParse(value) == null) {
                        return 'المبلغ غير صحيح';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // الوصف
                Text(
                  'الوصف (اختياري)',
                  style: StyleSystem.titleSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: StyleSystem.backgroundDark,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextFormField(
                    controller: descriptionController,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'سبب منح المكافأة...',
                      hintStyle: TextStyle(color: Colors.white60),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white70,
            ),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              // التحقق من صحة البيانات
              if (amountController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('يرجى إدخال المبلغ'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final amount = double.tryParse(amountController.text.trim());
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('يرجى إدخال مبلغ صحيح'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              // إظهار مؤشر التحميل
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: StyleSystem.surfaceDark,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: StyleSystem.primaryColor),
                        const SizedBox(height: 16),
                        const Text(
                          'جاري منح المكافأة...',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              );

              try {
                final success = await context.read<WorkerRewardsProvider>().awardReward(
                  workerId: workerId,
                  amount: amount,
                  rewardType: selectedType,
                  description: descriptionController.text.trim().isNotEmpty
                      ? descriptionController.text.trim()
                      : null,
                );

                // إغلاق مؤشر التحميل
                Navigator.pop(context);
                // إغلاق نافذة المكافأة
                Navigator.pop(context);

                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: Colors.white),
                          SizedBox(width: 8),
                          Text('تم منح المكافأة بنجاح'),
                        ],
                      ),
                      backgroundColor: StyleSystem.successColor,
                      duration: const Duration(seconds: 3),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  );
                } else {
                  final error = context.read<WorkerRewardsProvider>().error;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.error_rounded, color: Colors.white),
                          const SizedBox(width: 8),
                          Expanded(child: Text(error ?? 'فشل في منح المكافأة')),
                        ],
                      ),
                      backgroundColor: StyleSystem.errorColor,
                      duration: const Duration(seconds: 3),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  );
                }
              } catch (e) {
                // إغلاق مؤشر التحميل
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.error_rounded, color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(child: Text('حدث خطأ: $e')),
                      ],
                    ),
                    backgroundColor: StyleSystem.errorColor,
                    duration: const Duration(seconds: 3),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: StyleSystem.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.card_giftcard_rounded, size: 18),
                SizedBox(width: 8),
                Text('منح المكافأة'),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  String _getRewardTypeDisplayName(RewardType type) {
    switch (type) {
      case RewardType.monetary:
        return 'مكافأة مالية';
      case RewardType.bonus:
        return 'علاوة';
      case RewardType.commission:
        return 'عمولة';
      case RewardType.penalty:
        return 'خصم';
      case RewardType.adjustment:
        return 'تعديل';
      case RewardType.overtime:
        return 'ساعات إضافية';
    }
  }

  Color _getRewardTypeColor(RewardType type) {
    switch (type) {
      case RewardType.monetary:
        return StyleSystem.successColor;
      case RewardType.bonus:
        return StyleSystem.accentColor;
      case RewardType.commission:
        return StyleSystem.primaryColor;
      case RewardType.penalty:
        return StyleSystem.errorColor;
      case RewardType.adjustment:
        return StyleSystem.warningColor;
      case RewardType.overtime:
        return Colors.orange;
    }
  }

  IconData _getRewardTypeIcon(RewardType type) {
    switch (type) {
      case RewardType.monetary:
        return Icons.payments_rounded;
      case RewardType.bonus:
        return Icons.star_rounded;
      case RewardType.commission:
        return Icons.trending_up_rounded;
      case RewardType.penalty:
        return Icons.remove_circle_rounded;
      case RewardType.adjustment:
        return Icons.tune_rounded;
      case RewardType.overtime:
        return Icons.access_time_rounded;
    }
  }

  void _showClearAccountDialog(String workerId, String workerName, double currentBalance) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: StyleSystem.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_rounded, color: StyleSystem.errorColor, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'تصفية حساب العامل',
                style: StyleSystem.titleLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'هل أنت متأكد من تصفية حساب العامل "$workerName"؟',
              style: StyleSystem.bodyMedium.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: StyleSystem.errorColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: StyleSystem.errorColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_rounded,
                           color: StyleSystem.errorColor, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'الرصيد الحالي:',
                        style: StyleSystem.titleSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${NumberFormat('#,##0.00').format(currentBalance)} جنيه',
                    style: StyleSystem.titleMedium.copyWith(
                      color: StyleSystem.errorColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '⚠️ سيتم إنشاء خصم بقيمة الرصيد الحالي لتصفير الحساب',
                    style: StyleSystem.bodySmall.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white70,
            ),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _clearWorkerAccount(workerId, workerName, currentBalance);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: StyleSystem.errorColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.clear_all_rounded, size: 18),
                SizedBox(width: 8),
                Text('تصفية الحساب'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _clearWorkerAccount(String workerId, String workerName, double currentBalance) async {
    // إظهار مؤشر التحميل
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: StyleSystem.surfaceDark,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: StyleSystem.primaryColor),
              const SizedBox(height: 16),
              const Text(
                'جاري تصفية الحساب...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      // إنشاء خصم بقيمة الرصيد الحالي لتصفير الحساب
      final success = await context.read<WorkerRewardsProvider>().awardReward(
        workerId: workerId,
        amount: -currentBalance, // مبلغ سالب للخصم
        rewardType: RewardType.adjustment,
        description: 'تصفية حساب العامل - إعادة تعيين الرصيد إلى صفر',
        notes: 'تم تصفية الحساب بواسطة الإدارة',
      );

      // إغلاق مؤشر التحميل
      Navigator.pop(context);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('تم تصفية حساب العامل "$workerName" بنجاح'),
                ),
              ],
            ),
            backgroundColor: StyleSystem.successColor,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      } else {
        final error = context.read<WorkerRewardsProvider>().error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(error ?? 'فشل في تصفية الحساب')),
              ],
            ),
            backgroundColor: StyleSystem.errorColor,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      // إغلاق مؤشر التحميل
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('حدث خطأ: $e')),
            ],
          ),
          backgroundColor: StyleSystem.errorColor,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: StyleSystem.surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: StyleSystem.errorColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: StyleSystem.errorGradient,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'حدث خطأ',
              style: StyleSystem.headlineSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              error,
              style: StyleSystem.bodyMedium.copyWith(
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: StyleSystem.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
