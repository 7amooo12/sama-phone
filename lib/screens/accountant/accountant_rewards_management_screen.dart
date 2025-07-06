import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/worker_rewards_provider.dart';
import '../../providers/supabase_provider.dart';
import '../../models/user_role.dart';
import '../../models/worker_reward_model.dart';
import '../../widgets/shared/custom_loader.dart';
import '../../utils/accountant_theme_config.dart';
import '../../utils/app_logger.dart';
import '../../widgets/shared/show_snackbar.dart';

class AccountantRewardsManagementScreen extends StatefulWidget {
  const AccountantRewardsManagementScreen({super.key});

  @override
  State<AccountantRewardsManagementScreen> createState() => _AccountantRewardsManagementScreenState();
}

class _AccountantRewardsManagementScreenState extends State<AccountantRewardsManagementScreen> {
  List<Map<String, dynamic>> _workers = [];
  bool _isLoadingWorkers = false;
  String? _selectedWorkerId;
  final String _selectedFilter = 'all'; // all, individual, recent
  final TextEditingController _searchController = TextEditingController();

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
      // استخدام نفس الطريقة المستخدمة في صفحة إسناد المهام
      final allWorkers = await Provider.of<SupabaseProvider>(context, listen: false)
          .getUsersByRole(UserRole.worker.value);

      // تصفية العمال المعتمدين مع مرونة في فحص الحالة
      final approvedWorkers = allWorkers.where((worker) =>
        worker.isApproved ||
        worker.status == 'approved' ||
        worker.status == 'active'
      ).toList();

      // تحويل UserModel إلى Map للتوافق مع باقي الكود
      final workersMap = approvedWorkers.map((worker) => {
        'id': worker.id,
        'name': worker.name,
        'email': worker.email,
        'role': worker.role.value,
        'status': worker.status,
      }).toList();

      setState(() {
        _workers = workersMap;
        _isLoadingWorkers = false;
      });

    } catch (e) {
      setState(() {
        _isLoadingWorkers = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل قائمة العمال: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        title: const Text(
          'إدارة مكافآت العمال',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
        backgroundColor: Colors.grey.shade900,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
            tooltip: 'تحديث البيانات',
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

  Widget _buildErrorState(String error) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'حدث خطأ في تحميل البيانات',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
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
            const Color(0xFF10B981),
            const Color(0xFF10B981).withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.card_giftcard_rounded,
                color: Colors.white,
                size: 28,
              ),
              SizedBox(width: 12),
              Text(
                'منح مكافأة سريعة',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'اختر عامل لمنحه مكافأة فورية',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedWorkerId,
                      hint: Text(
                        'اختر عامل...',
                        style: TextStyle(color: Colors.white.withOpacity(0.8)),
                      ),
                      dropdownColor: Colors.grey.shade800,
                      style: const TextStyle(color: Colors.white),
                      items: _workers.map((worker) {
                        return DropdownMenuItem<String>(
                          value: worker['id']?.toString(),
                          child: Text(
                            worker['name']?.toString() ?? 'عامل غير معروف',
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
                  foregroundColor: const Color(0xFF10B981),
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
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.accentBlue),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تصفية وبحث',
            style: AccountantThemeConfig.headlineSmall,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            style: AccountantThemeConfig.bodyMedium,
            decoration: InputDecoration(
              hintText: 'البحث عن عامل...',
              hintStyle: AccountantThemeConfig.bodySmall,
              prefixIcon: Icon(
                Icons.search,
                color: AccountantThemeConfig.accentBlue,
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AccountantThemeConfig.accentBlue.withValues(alpha: 0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AccountantThemeConfig.accentBlue.withValues(alpha: 0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AccountantThemeConfig.accentBlue,
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(WorkerRewardsProvider provider) {
    final totalRewards = provider.rewards.length;
    final totalAmount = provider.rewards.fold<double>(
      0.0,
      (sum, reward) => sum + reward.amount
    );
    final activeWorkers = _workers.length;

    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'إجمالي المكافآت',
            '$totalRewards',
            Icons.card_giftcard,
            AccountantThemeConfig.primaryGreen,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSummaryCard(
            'المبلغ الإجمالي',
            AccountantThemeConfig.formatCurrency(totalAmount),
            Icons.monetization_on,
            AccountantThemeConfig.warningOrange,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSummaryCard(
            'العمال النشطين',
            '$activeWorkers',
            Icons.people,
            AccountantThemeConfig.accentBlue,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
        border: AccountantThemeConfig.glowBorder(color),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
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
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: AccountantThemeConfig.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkersSection(WorkerRewardsProvider provider) {
    return Container(
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
                  'أرصدة العمال',
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
            if (_workers.isEmpty)
              _buildEmptyWorkersState()
            else
              Column(
                children: _workers.map((worker) => _buildWorkerCard(worker, provider)).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyWorkersState() {
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

  Widget _buildWorkerCard(Map<String, dynamic> worker, WorkerRewardsProvider provider) {
    final workerId = worker['id']?.toString() ?? '';
    final workerName = worker['name']?.toString() ?? 'عامل غير معروف';
    final balance = provider.getWorkerBalance(workerId);
    final workerRewards = provider.rewards.where((r) => r.workerId == workerId).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3),
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
              backgroundColor: AccountantThemeConfig.primaryGreen,
              child: Text(
                workerName.isNotEmpty ? workerName[0].toUpperCase() : 'ع',
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
                    workerName,
                    style: AccountantThemeConfig.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'الرصيد: ${AccountantThemeConfig.formatCurrency(balance?.currentBalance ?? 0.0)}',
                    style: AccountantThemeConfig.bodyMedium.copyWith(
                      color: AccountantThemeConfig.primaryGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'عدد المكافآت: ${workerRewards.length}',
                    style: AccountantThemeConfig.bodySmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),

            // Action buttons
            Column(
              children: [
                ElevatedButton.icon(
                  onPressed: () => _showRewardDialog(workerId, workerName),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('مكافأة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AccountantThemeConfig.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: const Size(80, 32),
                    textStyle: AccountantThemeConfig.labelSmall,
                  ),
                ),
                const SizedBox(height: 8),
                if ((balance?.currentBalance ?? 0.0) > 0)
                  ElevatedButton.icon(
                    onPressed: () => _showClearAccountDialog(workerId, workerName, balance?.currentBalance ?? 0.0),
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('تصفية'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AccountantThemeConfig.dangerRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: const Size(80, 32),
                      textStyle: AccountantThemeConfig.labelSmall,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentRewardsSection(WorkerRewardsProvider provider) {
    final recentRewards = provider.rewards.take(10).toList();

    return Container(
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(AccountantThemeConfig.largeBorderRadius),
        border: AccountantThemeConfig.glowBorder(AccountantThemeConfig.warningOrange),
        boxShadow: AccountantThemeConfig.cardShadows,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: AccountantThemeConfig.orangeGradient,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.history,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'المكافآت الحديثة',
                  style: AccountantThemeConfig.headlineSmall,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (recentRewards.isEmpty)
              _buildEmptyRewardsState()
            else
              Column(
                children: recentRewards.map((reward) => _buildRewardCard(reward)).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyRewardsState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.card_giftcard_outlined,
            size: 64,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد مكافآت حديثة',
            style: AccountantThemeConfig.bodyLarge.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardCard(WorkerRewardModel reward) {
    final worker = _workers.firstWhere(
      (w) => w['id'] == reward.workerId,
      orElse: () => {'name': 'عامل غير معروف'},
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
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
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  worker['name']?.toString() ?? 'عامل غير معروف',
                  style: AccountantThemeConfig.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  reward.description ?? 'مكافأة',
                  style: AccountantThemeConfig.bodySmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                AccountantThemeConfig.formatCurrency(reward.amount),
                style: AccountantThemeConfig.bodyMedium.copyWith(
                  color: reward.amount >= 0
                      ? AccountantThemeConfig.primaryGreen
                      : AccountantThemeConfig.dangerRed,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                AccountantThemeConfig.formatDate(reward.awardedAt),
                style: AccountantThemeConfig.bodySmall.copyWith(
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getRewardTypeColor(RewardType type) {
    switch (type) {
      case RewardType.bonus:
        return AccountantThemeConfig.primaryGreen;
      case RewardType.commission:
        return AccountantThemeConfig.accentBlue;
      case RewardType.overtime:
        return AccountantThemeConfig.warningOrange;
      case RewardType.adjustment:
        return AccountantThemeConfig.dangerRed;
      default:
        return AccountantThemeConfig.neutralColor;
    }
  }

  IconData _getRewardTypeIcon(RewardType type) {
    switch (type) {
      case RewardType.bonus:
        return Icons.card_giftcard;
      case RewardType.commission:
        return Icons.monetization_on;
      case RewardType.overtime:
        return Icons.access_time;
      case RewardType.adjustment:
        return Icons.tune;
      default:
        return Icons.help_outline;
    }
  }

  void _showRewardDialog(String workerId, String workerName) {
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    RewardType selectedType = RewardType.bonus;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AccountantThemeConfig.cardBackground1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AccountantThemeConfig.greenGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.card_giftcard,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'منح مكافأة لـ $workerName',
                style: AccountantThemeConfig.headlineMedium,
              ),
            ),
          ],
        ),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Amount field
              Text(
                'المبلغ',
                style: AccountantThemeConfig.labelLarge,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                style: AccountantThemeConfig.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'أدخل المبلغ',
                  hintStyle: AccountantThemeConfig.bodySmall,
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: AccountantThemeConfig.primaryGreen,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Reward type
              Text(
                'نوع المكافأة',
                style: AccountantThemeConfig.labelLarge,
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<RewardType>(
                    value: selectedType,
                    isExpanded: true,
                    dropdownColor: AccountantThemeConfig.cardBackground1,
                    style: AccountantThemeConfig.bodyMedium,
                    items: RewardType.values.map((type) {
                      return DropdownMenuItem<RewardType>(
                        value: type,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              Icon(
                                _getRewardTypeIcon(type),
                                color: _getRewardTypeColor(type),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(_getRewardTypeText(type)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (RewardType? value) {
                      if (value != null) {
                        setState(() {
                          selectedType = value;
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Description field
              Text(
                'الوصف (اختياري)',
                style: AccountantThemeConfig.labelLarge,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                style: AccountantThemeConfig.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'أدخل وصف المكافأة',
                  hintStyle: AccountantThemeConfig.bodySmall,
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: AccountantThemeConfig.primaryGreen.withValues(alpha: 0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: AccountantThemeConfig.primaryGreen,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'إلغاء',
              style: AccountantThemeConfig.labelLarge.copyWith(
                color: AccountantThemeConfig.neutralColor,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => _grantReward(
              workerId,
              amountController.text,
              selectedType,
              descriptionController.text,
            ),
            style: AccountantThemeConfig.primaryButtonStyle,
            child: const Text('منح المكافأة'),
          ),
        ],
      ),
    );
  }

  String _getRewardTypeText(RewardType type) {
    switch (type) {
      case RewardType.bonus:
        return 'مكافأة';
      case RewardType.commission:
        return 'عمولة';
      case RewardType.overtime:
        return 'ساعات إضافية';
      case RewardType.adjustment:
        return 'تعديل';
      default:
        return 'أخرى';
    }
  }

  Future<void> _grantReward(String workerId, String amountText, RewardType type, String description) async {
    if (amountText.isEmpty) {
      ShowSnackbar.show(context, 'يرجى إدخال المبلغ', isError: true);
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ShowSnackbar.show(context, 'يرجى إدخال مبلغ صحيح', isError: true);
      return;
    }

    Navigator.pop(context);

    try {
      final success = await context.read<WorkerRewardsProvider>().awardReward(
        workerId: workerId,
        amount: amount,
        rewardType: type,
        description: description.trim().isNotEmpty ? description.trim() : null,
      );

      if (success) {
        ShowSnackbar.show(context, 'تم منح المكافأة بنجاح', isError: false);
        await _loadData(); // Refresh data
      } else {
        ShowSnackbar.show(context, 'فشل في منح المكافأة', isError: true);
      }
    } catch (e) {
      AppLogger.error('Error granting reward: $e');
      ShowSnackbar.show(context, 'حدث خطأ أثناء منح المكافأة: $e', isError: true);
    }
  }

  /// Show confirmation dialog for clearing worker account balance
  void _showClearAccountDialog(String workerId, String workerName, double currentBalance) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AccountantThemeConfig.cardBackground1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AccountantThemeConfig.dangerRed, AccountantThemeConfig.dangerRed.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.clear_all_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'تصفية حساب العامل',
                style: AccountantThemeConfig.headlineMedium,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AccountantThemeConfig.dangerRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AccountantThemeConfig.dangerRed.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_rounded,
                        color: AccountantThemeConfig.dangerRed,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'تحذير',
                        style: AccountantThemeConfig.labelLarge.copyWith(
                          color: AccountantThemeConfig.dangerRed,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'هل أنت متأكد من تصفية حساب العامل "$workerName"؟',
                    style: AccountantThemeConfig.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'الرصيد الحالي: ${AccountantThemeConfig.formatCurrency(currentBalance)}',
                    style: AccountantThemeConfig.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AccountantThemeConfig.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'سيتم إنشاء خصم بقيمة الرصيد الحالي لتصفير الحساب.',
                    style: AccountantThemeConfig.bodySmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
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
            child: Text(
              'إلغاء',
              style: AccountantThemeConfig.labelLarge.copyWith(
                color: AccountantThemeConfig.neutralColor,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => _processClearAccount(workerId, workerName, currentBalance),
            style: ElevatedButton.styleFrom(
              backgroundColor: AccountantThemeConfig.dangerRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('تصفية الحساب'),
          ),
        ],
      ),
    );
  }

  /// Process clearing worker account balance
  Future<void> _processClearAccount(String workerId, String workerName, double currentBalance) async {
    Navigator.pop(context); // Close dialog

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AccountantThemeConfig.cardBackground1,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AccountantThemeConfig.primaryGreen),
            ),
            const SizedBox(height: 16),
            Text(
              'جاري تصفية الحساب...',
              style: AccountantThemeConfig.bodyMedium,
            ),
          ],
        ),
      ),
    );

    try {
      // Create adjustment reward with negative amount to clear balance
      final success = await context.read<WorkerRewardsProvider>().awardReward(
        workerId: workerId,
        amount: -currentBalance, // Negative amount to clear balance
        rewardType: RewardType.adjustment,
        description: 'تصفية حساب العامل - إعادة تعيين الرصيد إلى صفر',
        notes: 'تم تصفية الحساب بواسطة المحاسب',
      );

      // Close loading dialog
      Navigator.pop(context);

      if (success) {
        ShowSnackbar.show(context, 'تم تصفية حساب العامل "$workerName" بنجاح', isError: false);
        await _loadData(); // Refresh data
      } else {
        ShowSnackbar.show(context, 'فشل في تصفية حساب العامل', isError: true);
      }
    } catch (e) {
      // Close loading dialog
      Navigator.pop(context);

      AppLogger.error('Error clearing worker account: $e');
      ShowSnackbar.show(context, 'حدث خطأ أثناء تصفية الحساب: $e', isError: true);
    }
  }
}