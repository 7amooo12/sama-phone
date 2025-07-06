import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/worker_reward_model.dart';
import '../utils/app_logger.dart';

class WorkerRewardsProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<WorkerRewardModel> _rewards = [];
  List<WorkerRewardBalanceModel> _balances = [];
  WorkerRewardBalanceModel? _currentUserBalance;
  bool _isLoading = false;
  String? _error;

  // Getters
  List<WorkerRewardModel> get rewards => _rewards;
  List<WorkerRewardBalanceModel> get balances => _balances;
  WorkerRewardBalanceModel? get currentUserBalance => _currentUserBalance;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Get rewards for current user
  List<WorkerRewardModel> get myRewards {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return [];
    return _rewards.where((reward) => reward.workerId == currentUserId).toList();
  }

  // Fetch all rewards with enhanced error handling and retry logic
  Future<void> fetchRewards() async {
    _setLoading(true);
    int retryCount = 0;
    const maxRetries = 3;
    const baseDelay = Duration(seconds: 2);

    while (retryCount < maxRetries) {
      try {
        AppLogger.info('🔄 Starting to fetch worker rewards... (Attempt ${retryCount + 1}/$maxRetries)');

        // أولاً نحصل على المكافآت الأساسية مع timeout محسن
        final response = await _supabase
            .from('worker_rewards')
            .select('*')
            .order('awarded_at', ascending: false)
            .timeout(const Duration(seconds: 30));

        // ثم نحصل على أسماء المستخدمين والمهام بشكل منفصل مع timeout
        final userProfiles = await _supabase
            .from('user_profiles')
            .select('id, name')
            .timeout(const Duration(seconds: 30));

        final workerTasks = await _supabase
            .from('worker_tasks')
            .select('id, title')
            .timeout(const Duration(seconds: 30));

      // إنشاء خرائط للبحث السريع
      final userMap = <String, String>{};
      for (final profile in userProfiles) {
        final userId = profile['id'] as String;
        final userName = profile['name']?.toString() ?? 'مستخدم غير معروف';
        userMap[userId] = userName;
      }

      final taskMap = <String, String>{};
      for (final task in workerTasks) {
        final taskId = task['id'] as String;
        final taskTitle = task['title']?.toString() ?? 'مهمة غير معروفة';
        taskMap[taskId] = taskTitle;
      }

      AppLogger.info('📊 Raw rewards response: ${response.length} records');

      _rewards = (response as List).map((json) {
        final reward = WorkerRewardModel.fromJson(json as Map<String, dynamic>);
        return reward.copyWith(
          workerName: userMap[reward.workerId] ?? 'مستخدم غير معروف',
          awardedByName: reward.awardedBy != null ? userMap[reward.awardedBy!] ?? 'مستخدم غير معروف' : null,
          taskTitle: reward.relatedTaskId != null ? taskMap[reward.relatedTaskId!] ?? 'مهمة غير معروفة' : null,
        );
      }).toList();

        _clearError();
        AppLogger.info('✅ Successfully fetched ${_rewards.length} rewards');

        // Log current user rewards count
        final currentUserId = _supabase.auth.currentUser?.id;
        if (currentUserId != null) {
          final myRewardsCount = _rewards.where((r) => r.workerId == currentUserId).length;
          AppLogger.info('👤 Current user has $myRewardsCount rewards');
        }

        // Success - break out of retry loop
        break;

      } catch (e) {
        retryCount++;
        final isNetworkError = e.toString().toLowerCase().contains('connection') ||
                              e.toString().toLowerCase().contains('timeout') ||
                              e.toString().toLowerCase().contains('reset by peer') ||
                              e.toString().toLowerCase().contains('network');

        AppLogger.error('❌ Error fetching rewards (attempt $retryCount/$maxRetries): $e');

        if (retryCount >= maxRetries || !isNetworkError) {
          // Final failure or non-network error
          _setError('فشل في تحميل المكافآت: ${_getArabicErrorMessage(e.toString())}');
          break;
        } else {
          // Wait before retry with exponential backoff
          final delay = Duration(seconds: baseDelay.inSeconds * (1 << (retryCount - 1)));
          AppLogger.info('⏳ Retrying in ${delay.inSeconds} seconds...');
          await Future.delayed(delay);
        }
      }
    }
    _setLoading(false);
  }

  // Helper method to convert error messages to Arabic
  String _getArabicErrorMessage(String error) {
    final errorLower = error.toLowerCase();
    if (errorLower.contains('connection') || errorLower.contains('reset by peer')) {
      return 'مشكلة في الاتصال بالخادم. تحقق من اتصال الإنترنت';
    } else if (errorLower.contains('timeout')) {
      return 'انتهت مهلة الاتصال. حاول مرة أخرى';
    } else if (errorLower.contains('network')) {
      return 'خطأ في الشبكة. تحقق من اتصال الإنترنت';
    } else {
      return 'خطأ غير متوقع. حاول مرة أخرى لاحقاً';
    }
  }

  // Fetch reward balances
  Future<void> fetchRewardBalances() async {
    _setLoading(true);
    try {
      AppLogger.info('🔄 Starting to fetch reward balances...');

      // أولاً نحصل على الأرصدة الأساسية
      final response = await _supabase
          .from('worker_reward_balances')
          .select('*')
          .order('last_updated', ascending: false);

      // ثم نحصل على أسماء المستخدمين
      final userProfiles = await _supabase
          .from('user_profiles')
          .select('id, name');

      // إنشاء خريطة للمستخدمين
      final userMap = <String, String>{};
      for (final profile in userProfiles) {
        final userId = profile['id'] as String;
        final userName = profile['name']?.toString() ?? 'مستخدم غير معروف';
        userMap[userId] = userName;
      }

      AppLogger.info('📊 Raw balances response: ${response.length} records');

      _balances = (response as List).map((json) {
        final balance = WorkerRewardBalanceModel.fromJson(json as Map<String, dynamic>);
        return balance.copyWith(
          workerName: userMap[balance.workerId] ?? 'مستخدم غير معروف',
        );
      }).toList();

      // Set current user balance
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId != null) {
        _currentUserBalance = _balances.firstWhere(
          (balance) => balance.workerId == currentUserId,
          orElse: () => WorkerRewardBalanceModel(
            workerId: currentUserId,
            currentBalance: 0.0,
            totalEarned: 0.0,
            totalWithdrawn: 0.0,
            lastUpdated: DateTime.now(),
          ),
        );

        AppLogger.info('👤 Current user balance: ${_currentUserBalance?.currentBalance ?? 0.0}');
      } else {
        AppLogger.warning('⚠️ No current user found for balance calculation');
      }

      _clearError();
      AppLogger.info('✅ Successfully fetched ${_balances.length} reward balances');
    } catch (e) {
      _setError('فشل في تحميل أرصدة المكافآت: $e');
      AppLogger.error('❌ Error fetching reward balances: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Award reward to worker (admin only)
  Future<bool> awardReward({
    required String workerId,
    required double amount,
    required RewardType rewardType,
    String? description,
    String? relatedTaskId,
    String? notes,
  }) async {
    try {
      _setLoading(true);
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        _setError('المستخدم غير مسجل الدخول');
        return false;
      }

      AppLogger.info('🎁 Starting reward assignment for worker: $workerId, amount: $amount');
      AppLogger.info('👤 Current user ID: $currentUserId');

      final rewardData = {
        'worker_id': workerId,
        'amount': amount,
        'reward_type': rewardType.name,
        'description': description,
        'awarded_by': currentUserId,
        'related_task_id': relatedTaskId,
        'notes': notes,
        'status': 'active',
      };

      AppLogger.info('📝 Reward data to insert: $rewardData');

      // Insert the reward
      AppLogger.info('💾 Attempting to insert into worker_rewards table...');
      final insertResult = await _supabase.from('worker_rewards').insert(rewardData).select();
      AppLogger.info('✅ Reward inserted successfully: ${insertResult.length} records');

      // NOTE: Balance update is handled automatically by database trigger
      // The trigger_update_reward_balance trigger automatically updates worker_reward_balances
      // when a new reward is inserted, so we don't need to manually update the balance here.
      AppLogger.info('💡 Balance will be updated automatically by database trigger');

      // Refresh data to get latest state
      await Future.wait([
        fetchRewards(),
        fetchRewardBalances(),
      ]);

      AppLogger.info('✅ Reward awarded successfully and data refreshed');
      return true;
    } catch (e) {
      _setError('فشل في منح المكافأة: $e');
      AppLogger.error('❌ Error awarding reward: $e');

      // Provide specific error analysis for RLS issues
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('row-level security') || errorString.contains('42501')) {
        AppLogger.error('🔒 RLS POLICY ERROR DETECTED!');
        AppLogger.error('💡 This is a Row Level Security (RLS) issue in Supabase.');
        AppLogger.error('💡 SOLUTION: Run the WORKER_REWARDS_RLS_FIX.sql script in Supabase SQL Editor');
        AppLogger.error('💡 The script creates basic policies that allow authenticated users to insert rewards');
      } else if (errorString.contains('foreign key') || errorString.contains('violates')) {
        AppLogger.error('🔗 FOREIGN KEY ERROR: Check if worker_id and awarded_by are valid user IDs');
      } else if (errorString.contains('column') && errorString.contains('does not exist')) {
        AppLogger.error('📋 COLUMN ERROR: Check if worker_rewards table schema matches the data being inserted');
      }

      return false;
    } finally {
      _setLoading(false);
    }
  }

  // DEPRECATED: This method is no longer needed because the database trigger
  // automatically updates worker_reward_balances when a reward is inserted.
  // Keeping this method commented for reference in case manual balance updates are needed.

  /*
  // Update worker balance after reward assignment
  Future<void> _updateWorkerBalance(String workerId, double amount) async {
    try {
      AppLogger.info('💰 Updating worker balance for: $workerId, amount: $amount');

      // Check if balance record exists
      final existingBalance = await _supabase
          .from('worker_reward_balances')
          .select()
          .eq('worker_id', workerId)
          .maybeSingle();

      if (existingBalance != null) {
        // Update existing balance
        final newCurrentBalance = (existingBalance['current_balance'] ?? 0.0) + amount;
        final newTotalEarned = (existingBalance['total_earned'] ?? 0.0) + (amount > 0 ? amount : 0);

        await _supabase
            .from('worker_reward_balances')
            .update({
              'current_balance': newCurrentBalance,
              'total_earned': newTotalEarned,
              'last_updated': DateTime.now().toIso8601String(),
            })
            .eq('worker_id', workerId);

        AppLogger.info('✅ Updated existing balance: current=$newCurrentBalance, total=$newTotalEarned');
      } else {
        // Create new balance record
        final newBalance = {
          'worker_id': workerId,
          'current_balance': amount,
          'total_earned': amount > 0 ? amount : 0.0,
          'total_withdrawn': 0.0,
          'last_updated': DateTime.now().toIso8601String(),
        };

        await _supabase.from('worker_reward_balances').insert(newBalance);
        AppLogger.info('✅ Created new balance record: $newBalance');
      }
    } catch (e) {
      AppLogger.error('❌ Error updating worker balance: $e');
      // Don't throw here as the reward was already created
    }
  }
  */

  // Update reward status (admin only)
  Future<bool> updateRewardStatus(String rewardId, RewardStatus status) async {
    try {
      await _supabase
          .from('worker_rewards')
          .update({'status': status.name})
          .eq('id', rewardId);

      // Refresh data
      await fetchRewards();
      await fetchRewardBalances();

      AppLogger.info('✅ Reward status updated successfully');
      return true;
    } catch (e) {
      _setError('فشل في تحديث حالة المكافأة: $e');
      AppLogger.error('❌ Error updating reward status: $e');
      return false;
    }
  }

  // Get workers list for admin reward management
  Future<List<Map<String, dynamic>>> getWorkersList() async {
    try {
      AppLogger.info('🔍 Fetching workers list for rewards management...');

      // أولاً: جلب جميع المستخدمين لفهم البيانات الموجودة
      final allUsersResponse = await _supabase
          .from('user_profiles')
          .select('id, name, email, role, status')
          .order('name');

      AppLogger.info('📊 Total users in database: ${allUsersResponse.length}');

      // طباعة تفاصيل جميع المستخدمين
      for (var user in allUsersResponse) {
        AppLogger.info('👤 User: ${user['name']} - Role: ${user['role']} - Status: ${user['status']}');
      }

      // البحث عن العمال المعتمدين
      final approvedWorkersResponse = await _supabase
          .from('user_profiles')
          .select('id, name, email, role, status')
          .eq('role', 'worker')
          .eq('status', 'approved')
          .order('name');

      AppLogger.info('📊 Approved workers found: ${approvedWorkersResponse.length}');

      // إذا لم نجد عمال معتمدين، جرب البحث عن جميع العمال
      if (approvedWorkersResponse.isEmpty) {
        AppLogger.info('⚠️ No approved workers found, checking all workers...');

        final allWorkersResponse = await _supabase
            .from('user_profiles')
            .select('id, name, email, role, status')
            .eq('role', 'worker')
            .order('name');

        AppLogger.info('📊 All workers (any status): ${allWorkersResponse.length}');

        for (var worker in allWorkersResponse) {
          AppLogger.info('👷 Worker: ${worker['name']} - Status: ${worker['status']}');
        }

        // إذا وجدنا عمال غير معتمدين، استخدمهم مؤقتاً
        if (allWorkersResponse.isNotEmpty) {
          final workers = List<Map<String, dynamic>>.from(allWorkersResponse).map((worker) {
            return {
              'id': worker['id'] ?? '',
              'name': worker['name'] ?? 'عامل غير معروف',
              'email': worker['email'] ?? '',
              'role': worker['role'] ?? '',
              'status': worker['status'] ?? '',
            };
          }).toList();

          AppLogger.info('✅ Using ${workers.length} workers (including non-approved)');
          return workers;
        }
      }

      // تأكد من أن جميع القيم ليست null
      final workers = List<Map<String, dynamic>>.from(approvedWorkersResponse).map((worker) {
        AppLogger.info('👤 Processing approved worker: ${worker['name']} (${worker['id']})');
        return {
          'id': worker['id'] ?? '',
          'name': worker['name'] ?? 'عامل غير معروف',
          'email': worker['email'] ?? '',
          'role': worker['role'] ?? '',
          'status': worker['status'] ?? '',
        };
      }).toList();

      AppLogger.info('✅ Fetched ${workers.length} approved workers for rewards management');
      AppLogger.info('👥 Workers list: ${workers.map((w) => '${w['name']} (${w['id']})').join(', ')}');
      return workers;
    } catch (e) {
      AppLogger.error('❌ Error fetching workers list: $e');
      return [];
    }
  }

  // Get worker balance by ID
  WorkerRewardBalanceModel? getWorkerBalance(String workerId) {
    try {
      return _balances.firstWhere(
        (balance) => balance.workerId == workerId,
        orElse: () => WorkerRewardBalanceModel(
          workerId: workerId,
          currentBalance: 0.0,
          totalEarned: 0.0,
          totalWithdrawn: 0.0,
          lastUpdated: DateTime.now(),
        ),
      );
    } catch (e) {
      AppLogger.error('❌ Error getting worker balance for $workerId: $e');
      return WorkerRewardBalanceModel(
        workerId: workerId,
        currentBalance: 0.0,
        totalEarned: 0.0,
        totalWithdrawn: 0.0,
        lastUpdated: DateTime.now(),
      );
    }
  }

  // Calculate total rewards for a worker
  double getTotalRewardsForWorker(String workerId) {
    return _rewards
        .where((reward) => reward.workerId == workerId && reward.status == RewardStatus.active)
        .fold(0.0, (sum, reward) => sum + reward.amount);
  }

  // Get recent rewards for a worker
  List<WorkerRewardModel> getRecentRewardsForWorker(String workerId, {int limit = 10}) {
    return _rewards
        .where((reward) => reward.workerId == workerId)
        .take(limit)
        .toList();
  }

  // Get rewards by type for a worker
  List<WorkerRewardModel> getRewardsByType(String workerId, RewardType type) {
    return _rewards
        .where((reward) => reward.workerId == workerId && reward.rewardType == type)
        .toList();
  }

  // Get monthly rewards summary for a worker
  Map<String, double> getMonthlyRewardsSummary(String workerId) {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final lastMonth = DateTime(now.year, now.month - 1);

    final currentMonthRewards = _rewards
        .where((reward) =>
          reward.workerId == workerId &&
          reward.awardedAt.isAfter(currentMonth) &&
          reward.status == RewardStatus.active)
        .fold(0.0, (sum, reward) => sum + reward.amount);

    final lastMonthRewards = _rewards
        .where((reward) =>
          reward.workerId == workerId &&
          reward.awardedAt.isAfter(lastMonth) &&
          reward.awardedAt.isBefore(currentMonth) &&
          reward.status == RewardStatus.active)
        .fold(0.0, (sum, reward) => sum + reward.amount);

    return {
      'currentMonth': currentMonthRewards,
      'lastMonth': lastMonthRewards,
    };
  }

  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _clearError();
  }

  // Initialize data for current user
  Future<void> initializeForCurrentUser() async {
    try {
      AppLogger.info('🚀 Initializing worker rewards for current user...');

      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        AppLogger.error('❌ No current user found during initialization');
        _setError('المستخدم غير مسجل الدخول');
        return;
      }

      AppLogger.info('👤 Current user ID: $currentUserId');

      await Future.wait([
        fetchRewards(),
        fetchRewardBalances(),
      ]);

      AppLogger.info('✅ Worker rewards initialization completed successfully');
    } catch (e) {
      AppLogger.error('❌ Error during worker rewards initialization: $e');
      _setError('فشل في تحميل بيانات المكافآت: $e');
    }
  }
}
