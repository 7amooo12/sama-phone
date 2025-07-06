import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_logger.dart';

/// أداة تشخيص وإصلاح مشاكل نظام المكافآت
class WorkerRewardsDebug {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// تشخيص شامل لنظام المكافآت
  static Future<Map<String, dynamic>> diagnoseRewardsSystem() async {
    final diagnosis = <String, dynamic>{};

    try {
      AppLogger.info('🔍 بدء تشخيص نظام المكافآت...');

      // 1. فحص الجداول المطلوبة
      diagnosis['tables'] = await _checkTables();

      // 2. فحص البيانات
      diagnosis['data'] = await _checkData();

      // 3. فحص المستخدم الحالي
      diagnosis['currentUser'] = await _checkCurrentUser();

      // 4. اختبار الاستعلامات
      diagnosis['queries'] = await _testQueries();

      AppLogger.info('✅ تم تشخيص نظام المكافآت بنجاح');

    } catch (e) {
      AppLogger.error('❌ خطأ في تشخيص نظام المكافآت: $e');
      diagnosis['error'] = e.toString();
    }

    return diagnosis;
  }

  /// فحص وجود الجداول المطلوبة
  static Future<Map<String, bool>> _checkTables() async {
    final tables = <String, bool>{};

    final requiredTables = [
      'user_profiles',
      'worker_rewards',
      'worker_reward_balances',
      'worker_tasks',
      'task_submissions',
      'task_feedback',
    ];

    for (final tableName in requiredTables) {
      try {
        await _supabase.from(tableName).select('id').limit(1);
        tables[tableName] = true;
        AppLogger.info('✅ الجدول $tableName موجود');
      } catch (e) {
        tables[tableName] = false;
        AppLogger.error('❌ الجدول $tableName غير موجود أو لا يمكن الوصول إليه: $e');
      }
    }

    return tables;
  }

  /// فحص البيانات الموجودة
  static Future<Map<String, int>> _checkData() async {
    final dataCounts = <String, int>{};

    try {
      // عدد المكافآت
      final rewardsResponse = await _supabase
          .from('worker_rewards')
          .select('id');
      dataCounts['rewards'] = rewardsResponse.length;

      // عدد أرصدة العمال
      final balancesResponse = await _supabase
          .from('worker_reward_balances')
          .select('worker_id');
      dataCounts['balances'] = balancesResponse.length;

      // عدد المهام
      final tasksResponse = await _supabase
          .from('worker_tasks')
          .select('id');
      dataCounts['tasks'] = tasksResponse.length;

      // عدد ملفات المستخدمين
      final profilesResponse = await _supabase
          .from('user_profiles')
          .select('id');
      dataCounts['profiles'] = profilesResponse.length;

      // عدد العمال
      final workersResponse = await _supabase
          .from('user_profiles')
          .select('id')
          .eq('role', 'worker');
      dataCounts['workers'] = workersResponse.length;

      // عدد تقديمات المهام
      final submissionsResponse = await _supabase
          .from('task_submissions')
          .select('id');
      dataCounts['submissions'] = submissionsResponse.length;

      // عدد التعليقات
      final feedbackResponse = await _supabase
          .from('task_feedback')
          .select('id');
      dataCounts['feedback'] = feedbackResponse.length;

    } catch (e) {
      AppLogger.error('❌ خطأ في فحص البيانات: $e');
    }

    return dataCounts;
  }

  /// فحص المستخدم الحالي
  static Future<Map<String, dynamic>> _checkCurrentUser() async {
    final userInfo = <String, dynamic>{};

    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser != null) {
        userInfo['id'] = currentUser.id;
        userInfo['email'] = currentUser.email;

        // الحصول على ملف المستخدم
        final profileResponse = await _supabase
            .from('user_profiles')
            .select('*')
            .eq('id', currentUser.id)
            .maybeSingle();

        if (profileResponse != null) {
          userInfo['profile'] = profileResponse;
          userInfo['role'] = profileResponse['role'];
          userInfo['status'] = profileResponse['status'];
        } else {
          userInfo['profile'] = null;
          AppLogger.warning('⚠️ لا يوجد ملف شخصي للمستخدم الحالي');
        }

        // فحص مكافآت المستخدم الحالي
        final myRewardsResponse = await _supabase
            .from('worker_rewards')
            .select('*')
            .eq('worker_id', currentUser.id);
        userInfo['myRewards'] = myRewardsResponse.length;

        // فحص رصيد المستخدم الحالي
        final myBalanceResponse = await _supabase
            .from('worker_reward_balances')
            .select('*')
            .eq('worker_id', currentUser.id)
            .maybeSingle();
        userInfo['myBalance'] = myBalanceResponse;

        // فحص تقديمات المهام للمستخدم الحالي
        final mySubmissionsResponse = await _supabase
            .from('task_submissions')
            .select('*')
            .eq('worker_id', currentUser.id);
        userInfo['mySubmissions'] = mySubmissionsResponse.length;

        // فحص المهام المسندة للمستخدم الحالي
        final myTasksResponse = await _supabase
            .from('worker_tasks')
            .select('*')
            .eq('assigned_to', currentUser.id);
        userInfo['myTasks'] = myTasksResponse.length;

      } else {
        userInfo['error'] = 'لا يوجد مستخدم مسجل دخول';
        AppLogger.warning('⚠️ لا يوجد مستخدم مسجل دخول');
      }
    } catch (e) {
      userInfo['error'] = e.toString();
      AppLogger.error('❌ خطأ في فحص المستخدم الحالي: $e');
    }

    return userInfo;
  }

  /// اختبار الاستعلامات المختلفة
  static Future<Map<String, dynamic>> _testQueries() async {
    final queryResults = <String, dynamic>{};

    try {
      // اختبار استعلام المكافآت البسيط
      final simpleRewardsQuery = await _supabase
          .from('worker_rewards')
          .select('*')
          .limit(5);
      queryResults['simpleRewards'] = {
        'success': true,
        'count': simpleRewardsQuery.length,
      };

      // اختبار استعلام الأرصدة البسيط
      final simpleBalancesQuery = await _supabase
          .from('worker_reward_balances')
          .select('*')
          .limit(5);
      queryResults['simpleBalances'] = {
        'success': true,
        'count': simpleBalancesQuery.length,
      };

      // اختبار استعلام ملفات المستخدمين
      final profilesQuery = await _supabase
          .from('user_profiles')
          .select('id, name')
          .limit(5);
      queryResults['profiles'] = {
        'success': true,
        'count': profilesQuery.length,
      };

      // اختبار استعلام المهام
      final tasksQuery = await _supabase
          .from('worker_tasks')
          .select('id, title')
          .limit(5);
      queryResults['tasks'] = {
        'success': true,
        'count': tasksQuery.length,
      };

      // اختبار استعلام تقديمات المهام
      final submissionsQuery = await _supabase
          .from('task_submissions')
          .select('*')
          .limit(5);
      queryResults['submissions'] = {
        'success': true,
        'count': submissionsQuery.length,
      };

      // اختبار استعلام التعليقات
      final feedbackQuery = await _supabase
          .from('task_feedback')
          .select('*')
          .limit(5);
      queryResults['feedback'] = {
        'success': true,
        'count': feedbackQuery.length,
      };

    } catch (e) {
      queryResults['error'] = e.toString();
      AppLogger.error('❌ خطأ في اختبار الاستعلامات: $e');
    }

    return queryResults;
  }

  /// إنشاء بيانات تجريبية للاختبار
  static Future<bool> createTestData() async {
    try {
      AppLogger.info('🔧 إنشاء بيانات تجريبية...');

      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        AppLogger.error('❌ لا يوجد مستخدم مسجل دخول');
        return false;
      }

      // إنشاء مكافأة تجريبية
      await _supabase.from('worker_rewards').insert({
        'worker_id': currentUser.id,
        'amount': 50.0,
        'reward_type': 'monetary',
        'description': 'مكافأة تجريبية للاختبار',
        'awarded_by': currentUser.id,
        'status': 'active',
      });

      // إنشاء أو تحديث رصيد تجريبي
      await _supabase.from('worker_reward_balances').upsert({
        'worker_id': currentUser.id,
        'current_balance': 50.0,
        'total_earned': 50.0,
        'total_withdrawn': 0.0,
        'last_updated': DateTime.now().toIso8601String(),
      });

      // إنشاء مهمة تجريبية
      final taskResponse = await _supabase.from('worker_tasks').insert({
        'title': 'مهمة تجريبية للاختبار',
        'description': 'هذه مهمة تجريبية لاختبار النظام',
        'assigned_to': currentUser.id,
        'assigned_by': currentUser.id,
        'priority': 'medium',
        'status': 'assigned',
        'category': 'test',
        'is_active': true,
      }).select().single();

      final taskId = taskResponse['id'] as String;

      // إنشاء تقديم مهمة تجريبي
      await _supabase.from('task_submissions').insert({
        'task_id': taskId,
        'worker_id': currentUser.id,
        'progress_report': 'تقرير تقدم تجريبي للاختبار',
        'completion_percentage': 50,
        'status': 'submitted',
        'hours_worked': 2.5,
        'notes': 'ملاحظات تجريبية',
        'is_final_submission': false,
      });

      AppLogger.info('✅ تم إنشاء البيانات التجريبية بنجاح');
      return true;

    } catch (e) {
      AppLogger.error('❌ خطأ في إنشاء البيانات التجريبية: $e');
      return false;
    }
  }

  /// طباعة تقرير التشخيص
  static void printDiagnosisReport(Map<String, dynamic> diagnosis) {
    print('\n${'='*50}');
    print('تقرير تشخيص نظام المكافآت');
    print('='*50);

    // طباعة حالة الجداول
    if (diagnosis['tables'] != null) {
      print('\n📊 حالة الجداول:');
      final tables = diagnosis['tables'] as Map<String, bool>;
      tables.forEach((table, exists) {
        print('  ${exists ? '✅' : '❌'} $table');
      });
    }

    // طباعة إحصائيات البيانات
    if (diagnosis['data'] != null) {
      print('\n📈 إحصائيات البيانات:');
      final data = diagnosis['data'] as Map<String, int>;
      data.forEach((key, count) {
        print('  $key: $count');
      });
    }

    // طباعة معلومات المستخدم الحالي
    if (diagnosis['currentUser'] != null) {
      print('\n👤 المستخدم الحالي:');
      final user = diagnosis['currentUser'] as Map<String, dynamic>;
      if (user['error'] != null) {
        print('  ❌ ${user['error']}');
      } else {
        print('  ID: ${user['id']}');
        print('  Email: ${user['email']}');
        print('  Role: ${user['role'] ?? 'غير محدد'}');
        print('  Status: ${user['status'] ?? 'غير محدد'}');
        print('  My Rewards: ${user['myRewards'] ?? 0}');
        print('  My Balance: ${user['myBalance']?['current_balance'] ?? 0.0}');
      }
    }

    // طباعة نتائج اختبار الاستعلامات
    if (diagnosis['queries'] != null) {
      print('\n🔍 نتائج اختبار الاستعلامات:');
      final queries = diagnosis['queries'] as Map<String, dynamic>;
      if (queries['error'] != null) {
        print('  ❌ خطأ: ${queries['error']}');
      } else {
        queries.forEach((key, result) {
          if (result is Map<String, dynamic> && result['success'] == true) {
            print('  ✅ $key: ${result['count']} سجل');
          }
        });
      }
    }

    print('\n${'='*50}');
  }
}
