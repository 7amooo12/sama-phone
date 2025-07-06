import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/treasury_models.dart';
import '../utils/app_logger.dart';

/// Service for managing treasury limits and alerts
class TreasuryLimitsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get treasury limits for a specific treasury
  Future<List<TreasuryLimit>> getTreasuryLimits(String treasuryId) async {
    try {
      AppLogger.info('🔄 Loading treasury limits for: $treasuryId');

      final response = await _supabase
          .from('treasury_limits')
          .select()
          .eq('treasury_id', treasuryId)
          .order('created_at', ascending: false);

      final limits = (response as List)
          .map((json) => TreasuryLimit.fromJson(json as Map<String, dynamic>))
          .toList();

      AppLogger.info('✅ Loaded ${limits.length} treasury limits');
      return limits;
    } catch (e) {
      AppLogger.error('❌ Error loading treasury limits: $e');
      throw Exception('فشل في تحميل حدود الخزنة: $e');
    }
  }

  /// Create or update treasury limit
  Future<TreasuryLimit> saveTreasuryLimit({
    String? limitId,
    required String treasuryId,
    required TreasuryLimitType limitType,
    required double limitValue,
    double warningThreshold = 80.0,
    double criticalThreshold = 95.0,
    bool isEnabled = true,
  }) async {
    try {
      AppLogger.info('🔄 Saving treasury limit: ${limitType.code} for $treasuryId');

      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      final limitData = {
        'treasury_id': treasuryId,
        'limit_type': limitType.code,
        'limit_value': limitValue,
        'warning_threshold': warningThreshold,
        'critical_threshold': criticalThreshold,
        'is_enabled': isEnabled,
        'updated_at': DateTime.now().toIso8601String(),
      };

      Map<String, dynamic> response;

      if (limitId != null) {
        // Update existing limit
        response = await _supabase
            .from('treasury_limits')
            .update(limitData)
            .eq('id', limitId)
            .select()
            .single();
      } else {
        // Create new limit
        limitData['created_by'] = currentUser.id;
        response = await _supabase
            .from('treasury_limits')
            .insert(limitData)
            .select()
            .single();
      }

      final limit = TreasuryLimit.fromJson(response);
      AppLogger.info('✅ Treasury limit saved: ${limit.id}');
      return limit;
    } catch (e) {
      AppLogger.error('❌ Error saving treasury limit: $e');
      
      String errorMessage = 'فشل في حفظ حد الخزنة';
      if (e.toString().contains('unique_treasury_limit_type')) {
        errorMessage = 'يوجد حد من نفس النوع لهذه الخزنة بالفعل';
      } else if (e.toString().contains('valid_thresholds')) {
        errorMessage = 'عتبة التحذير يجب أن تكون أقل من أو تساوي العتبة الحرجة';
      }
      
      throw Exception(errorMessage);
    }
  }

  /// Delete treasury limit
  Future<void> deleteTreasuryLimit(String limitId) async {
    try {
      AppLogger.info('🔄 Deleting treasury limit: $limitId');

      await _supabase
          .from('treasury_limits')
          .delete()
          .eq('id', limitId);

      AppLogger.info('✅ Treasury limit deleted');
    } catch (e) {
      AppLogger.error('❌ Error deleting treasury limit: $e');
      throw Exception('فشل في حذف حد الخزنة: $e');
    }
  }

  /// Check treasury limits and return alerts
  Future<List<Map<String, dynamic>>> checkTreasuryLimits({
    required String treasuryId,
    double? currentBalance,
  }) async {
    try {
      AppLogger.info('🔄 Checking treasury limits for: $treasuryId');

      final response = await _supabase.rpc('check_treasury_limits', params: {
        'treasury_uuid': treasuryId,
        'current_balance': currentBalance,
      });

      final alerts = List<Map<String, dynamic>>.from(response as List);
      AppLogger.info('✅ Found ${alerts.length} limit violations');
      return alerts;
    } catch (e) {
      AppLogger.error('❌ Error checking treasury limits: $e');
      throw Exception('فشل في فحص حدود الخزنة: $e');
    }
  }

  /// Get treasury alerts
  Future<List<TreasuryAlert>> getTreasuryAlerts({
    String? treasuryId,
    bool includeAcknowledged = false,
    int limit = 50,
  }) async {
    try {
      AppLogger.info('🔄 Loading treasury alerts');

      final response = await _supabase.rpc('get_treasury_alerts', params: {
        'treasury_uuid': treasuryId,
        'include_acknowledged': includeAcknowledged,
        'limit_count': limit,
      });

      final alerts = (response as List)
          .map((json) => TreasuryAlert.fromJson(json as Map<String, dynamic>))
          .toList();

      AppLogger.info('✅ Loaded ${alerts.length} treasury alerts');
      return alerts;
    } catch (e) {
      AppLogger.error('❌ Error loading treasury alerts: $e');
      throw Exception('فشل في تحميل تنبيهات الخزنة: $e');
    }
  }

  /// Create treasury alert
  Future<String> createTreasuryAlert({
    required String treasuryId,
    required TreasuryAlertType alertType,
    required TreasuryAlertSeverity severity,
    required String title,
    required String message,
    double? currentValue,
    double? limitValue,
    double? thresholdPercentage,
  }) async {
    try {
      AppLogger.info('🔄 Creating treasury alert: ${alertType.code}');

      final alertId = await _supabase.rpc('create_treasury_alert', params: {
        'treasury_uuid': treasuryId,
        'alert_type_param': alertType.code,
        'severity_param': severity.code,
        'title_param': title,
        'message_param': message,
        'current_value_param': currentValue,
        'limit_value_param': limitValue,
        'threshold_percentage_param': thresholdPercentage,
      });

      AppLogger.info('✅ Treasury alert created: $alertId');
      return alertId as String;
    } catch (e) {
      AppLogger.error('❌ Error creating treasury alert: $e');
      throw Exception('فشل في إنشاء تنبيه الخزنة: $e');
    }
  }

  /// Acknowledge treasury alert
  Future<void> acknowledgeTreasuryAlert(String alertId) async {
    try {
      AppLogger.info('🔄 Acknowledging treasury alert: $alertId');

      final currentUser = _supabase.auth.currentUser;
      await _supabase.rpc('acknowledge_treasury_alert', params: {
        'alert_uuid': alertId,
        'user_uuid': currentUser?.id,
      });

      AppLogger.info('✅ Treasury alert acknowledged');
    } catch (e) {
      AppLogger.error('❌ Error acknowledging treasury alert: $e');
      throw Exception('فشل في الإقرار بتنبيه الخزنة: $e');
    }
  }

  /// Get alert statistics
  Future<Map<String, dynamic>> getAlertStatistics({
    String? treasuryId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      AppLogger.info('🔄 Loading alert statistics');

      var query = _supabase
          .from('treasury_alerts')
          .select('severity, alert_type, is_acknowledged');

      if (treasuryId != null) {
        query = query.eq('treasury_id', treasuryId);
      }

      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      final response = await query;
      final alerts = response as List;

      int totalAlerts = alerts.length;
      int acknowledgedAlerts = alerts.where((a) => a['is_acknowledged'] == true).length;
      int pendingAlerts = totalAlerts - acknowledgedAlerts;

      Map<String, int> severityCount = {
        'info': 0,
        'warning': 0,
        'critical': 0,
        'error': 0,
      };

      Map<String, int> typeCount = {
        'balance_low': 0,
        'balance_high': 0,
        'transaction_limit': 0,
        'exchange_rate_change': 0,
      };

      for (final alert in alerts) {
        final severity = alert['severity'] as String;
        final type = alert['alert_type'] as String;
        
        severityCount[severity] = (severityCount[severity] ?? 0) + 1;
        typeCount[type] = (typeCount[type] ?? 0) + 1;
      }

      final statistics = {
        'total_alerts': totalAlerts,
        'acknowledged_alerts': acknowledgedAlerts,
        'pending_alerts': pendingAlerts,
        'acknowledgment_rate': totalAlerts > 0 ? (acknowledgedAlerts / totalAlerts * 100) : 0.0,
        'severity_breakdown': severityCount,
        'type_breakdown': typeCount,
      };

      AppLogger.info('✅ Alert statistics calculated');
      return statistics;
    } catch (e) {
      AppLogger.error('❌ Error loading alert statistics: $e');
      throw Exception('فشل في تحميل إحصائيات التنبيهات: $e');
    }
  }

  /// Bulk acknowledge alerts
  Future<void> bulkAcknowledgeAlerts(List<String> alertIds) async {
    try {
      AppLogger.info('🔄 Bulk acknowledging ${alertIds.length} alerts');

      final currentUser = _supabase.auth.currentUser;
      
      for (final alertId in alertIds) {
        await acknowledgeTreasuryAlert(alertId);
      }

      AppLogger.info('✅ Bulk acknowledgment completed');
    } catch (e) {
      AppLogger.error('❌ Error in bulk acknowledgment: $e');
      throw Exception('فشل في الإقرار المجمع للتنبيهات: $e');
    }
  }
}
