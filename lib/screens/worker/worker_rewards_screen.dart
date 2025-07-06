import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/worker_rewards_provider.dart';
import '../../models/worker_reward_model.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/custom_loader.dart';
import '../../utils/style_system.dart';

class WorkerRewardsScreen extends StatefulWidget {
  const WorkerRewardsScreen({super.key});

  @override
  State<WorkerRewardsScreen> createState() => _WorkerRewardsScreenState();
}

class _WorkerRewardsScreenState extends State<WorkerRewardsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WorkerRewardsProvider>().initializeForCurrentUser();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StyleSystem.scaffoldBackgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: CustomAppBar(
          title: 'المكافآت والأرصدة',
          backgroundColor: StyleSystem.surfaceDark,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: StyleSystem.textPrimary),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 16),
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: StyleSystem.headerGradient,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: StyleSystem.shadowSmall,
                  ),
                  child: const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                onPressed: () {
                  context.read<WorkerRewardsProvider>().initializeForCurrentUser();
                },
              ),
            ),
          ],
        ),
      ),
      body: Consumer<WorkerRewardsProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const CustomLoader(message: 'جاري تحميل المكافآت...');
          }

          if (provider.error != null) {
            return _buildErrorState(provider.error!);
          }

          return RefreshIndicator(
            onRefresh: () => provider.initializeForCurrentUser(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBalanceCard(provider),
                  const SizedBox(height: 20),
                  _buildStatsCards(provider),
                  const SizedBox(height: 20),
                  _buildRewardsHistory(provider),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBalanceCard(WorkerRewardsProvider provider) {
    final balance = provider.currentUserBalance;
    final currentBalance = balance?.currentBalance ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey.shade900,
            Colors.grey.shade800,
            Colors.grey.shade700,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.amber.shade400.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'رصيدي الحالي',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            '${NumberFormat('#,##0.00').format(currentBalance)} جنيه',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.3),
          const SizedBox(height: 8),
          Text(
            'آخر تحديث: ${balance != null ? DateFormat('dd/MM/yyyy').format(balance.lastUpdated) : 'غير محدد'}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 800.ms).slideY(begin: -0.3);
  }

  Widget _buildStatsCards(WorkerRewardsProvider provider) {
    final balance = provider.currentUserBalance;
    final totalEarned = balance?.totalEarned ?? 0.0;
    final totalWithdrawn = balance?.totalWithdrawn ?? 0.0;
    final monthlyStats = provider.getMonthlyRewardsSummary(
      provider.currentUserBalance?.workerId ?? '',
    );

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'إجمالي المكاسب',
            value: '${NumberFormat('#,##0.00').format(totalEarned)} جنيه',
            icon: Icons.trending_up_rounded,
            color: StyleSystem.successColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'هذا الشهر',
            value: '${NumberFormat('#,##0.00').format(monthlyStats['currentMonth'] ?? 0)} جنيه',
            icon: Icons.calendar_month_rounded,
            color: StyleSystem.accentColor,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
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
            Colors.grey.shade800,
            Colors.grey.shade700,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade300,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
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
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.3);
  }

  Widget _buildRewardsHistory(WorkerRewardsProvider provider) {
    final myRewards = provider.myRewards;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'سجل المكافآت',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 16),

        if (myRewards.isEmpty) ...[
          _buildEmptyRewardsState(),
        ] else ...[
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: myRewards.length,
            itemBuilder: (context, index) {
              final reward = myRewards[index];
              return _buildRewardCard(reward, index);
            },
          ),
        ],
      ],
    );
  }

  Widget _buildRewardCard(WorkerRewardModel reward, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey.shade800,
            Colors.grey.shade700,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getRewardTypeColor(reward.rewardType).withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _getRewardTypeColor(reward.rewardType).withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getRewardTypeColor(reward.rewardType).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getRewardTypeIcon(reward.rewardType),
              color: _getRewardTypeColor(reward.rewardType),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reward.rewardTypeDisplayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getSmartRewardDescription(reward),
                  style: TextStyle(
                    color: Colors.grey.shade300,
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  DateFormat('dd/MM/yyyy - hh:mm a').format(reward.awardedAt),
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _getRewardAmountDisplay(reward),
                style: StyleSystem.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: reward.rewardType == RewardType.penalty
                      ? StyleSystem.errorColor
                      : StyleSystem.successColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'جنيه',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate(delay: (index * 100).ms).fadeIn(duration: 600.ms).slideX(begin: 0.3);
  }

  Widget _buildEmptyRewardsState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: StyleSystem.cardGradient,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: StyleSystem.elevatedCardShadow,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  StyleSystem.primaryColor.withOpacity(0.1),
                  StyleSystem.accentColor.withOpacity(0.05),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.card_giftcard_rounded,
              size: 48,
              color: StyleSystem.primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد مكافآت بعد',
            style: StyleSystem.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: StyleSystem.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ستظهر مكافآتك هنا عند حصولك عليها',
            style: StyleSystem.bodyMedium.copyWith(
              color: StyleSystem.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }



  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
              color: StyleSystem.errorColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            error,
            style: StyleSystem.bodyMedium.copyWith(
              color: StyleSystem.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              context.read<WorkerRewardsProvider>().initializeForCurrentUser();
            },
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
    );
  }

  // دوال مساعدة لتحسين عرض المكافآت
  Color _getRewardTypeColor(RewardType type) {
    switch (type) {
      case RewardType.monetary:
        return StyleSystem.successColor;
      case RewardType.bonus:
        return Colors.amber;
      case RewardType.commission:
        return StyleSystem.infoColor;
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
        return Icons.attach_money_rounded;
      case RewardType.bonus:
        return Icons.card_giftcard_rounded;
      case RewardType.commission:
        return Icons.percent_rounded;
      case RewardType.penalty:
        return Icons.money_off_rounded;
      case RewardType.adjustment:
        return Icons.tune_rounded;
      case RewardType.overtime:
        return Icons.access_time_rounded;
    }
  }

  String _getSmartRewardDescription(WorkerRewardModel reward) {
    // منطق ذكي لوصف المكافآت والخصومات
    if (reward.rewardType == RewardType.penalty) {
      if (reward.description?.toLowerCase().contains('تأخير') == true) {
        return 'خصم تأخير في العمل';
      } else if (reward.description?.toLowerCase().contains('غياب') == true) {
        return 'خصم غياب بدون إذن';
      } else if (reward.description?.toLowerCase().contains('خطأ') == true) {
        return 'خصم أخطاء في العمل';
      } else {
        return reward.description ?? 'خصم إداري';
      }
    } else if (reward.rewardType == RewardType.bonus) {
      if (reward.description?.toLowerCase().contains('أداء') == true) {
        return 'مكافأة الأداء المتميز';
      } else if (reward.description?.toLowerCase().contains('حضور') == true) {
        return 'مكافأة الحضور المنتظم';
      } else if (reward.description?.toLowerCase().contains('إنجاز') == true) {
        return 'مكافأة إنجاز المهام';
      } else {
        return reward.description ?? 'مكافأة تشجيعية';
      }
    } else if (reward.rewardType == RewardType.commission) {
      return 'عمولة على ${reward.description ?? 'المبيعات'}';
    } else {
      return reward.description ?? reward.rewardTypeDisplayName;
    }
  }

  String _getRewardAmountDisplay(WorkerRewardModel reward) {
    // عرض ذكي للمبلغ مع إشارة + أو -
    final amount = reward.amount;
    if (reward.rewardType == RewardType.penalty) {
      // الخصومات تظهر بإشارة سالبة
      return '-${NumberFormat('#,##0.00').format(amount.abs())}';
    } else {
      // المكافآت تظهر بإشارة موجبة
      return '+${NumberFormat('#,##0.00').format(amount.abs())}';
    }
  }
}
