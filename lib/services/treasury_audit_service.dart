import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/treasury_models.dart';
import '../utils/app_logger.dart';

/// Service for managing treasury audit trail and logging
class TreasuryAuditService {
  final SupabaseClient _supabase = Supabase.instance.client;
  String? _currentSessionId;

  /// Start audit session for current user
  Future<String> startAuditSession({
    String? ipAddress,
    String? userAgent,
  }) async {
    try {
      AppLogger.info('🔄 Starting audit session');

      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      final sessionId = await _supabase.rpc('start_treasury_audit_session', params: {
        'user_id_param': currentUser.id,
        'ip_address_param': ipAddress,
        'user_agent_param': userAgent,
      });

      _currentSessionId = sessionId as String;
      AppLogger.info('✅ Audit session started: $_currentSessionId');
      return _currentSessionId!;
    } catch (e) {
      AppLogger.error('❌ Error starting audit session: $e');
      throw Exception('فشل في بدء جلسة المراجعة: $e');
    }
  }

  /// End current audit session
  Future<void> endAuditSession({
    String endReason = 'logout',
  }) async {
    try {
      if (_currentSessionId == null) return;

      AppLogger.info('🔄 Ending audit session: $_currentSessionId');

      await _supabase.rpc('end_treasury_audit_session', params: {
        'session_id_param': _currentSessionId,
        'end_reason_param': endReason,
      });

      AppLogger.info('✅ Audit session ended');
      _currentSessionId = null;
    } catch (e) {
      AppLogger.error('❌ Error ending audit session: $e');
      // Don't throw exception for session end failures
    }
  }

  /// Log treasury audit event
  Future<String> logAuditEvent({
    required TreasuryAuditEntityType entityType,
    String? entityId,
    required TreasuryAuditActionType actionType,
    required String actionDescription,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
    Map<String, dynamic>? metadata,
    TreasuryAuditSeverity severity = TreasuryAuditSeverity.info,
    List<String>? tags,
    String? ipAddress,
    String? userAgent,
  }) async {
    try {
      AppLogger.info('🔄 Logging audit event: ${actionType.code} for ${entityType.code}');

      final currentUser = _supabase.auth.currentUser;

      final auditId = await _supabase.rpc('log_treasury_audit', params: {
        'entity_type_param': entityType.code,
        'entity_id_param': entityId,
        'action_type_param': actionType.code,
        'action_description_param': actionDescription,
        'user_id_param': currentUser?.id,
        'old_values_param': oldValues,
        'new_values_param': newValues,
        'metadata_param': metadata,
        'severity_param': severity.code,
        'tags_param': tags,
        'ip_address_param': ipAddress,
        'user_agent_param': userAgent,
        'session_id_param': _currentSessionId,
      });

      AppLogger.info('✅ Audit event logged: $auditId');
      return auditId as String;
    } catch (e) {
      AppLogger.error('❌ Error logging audit event: $e');
      // Don't throw exception for audit logging failures to avoid disrupting main operations
      return '';
    }
  }

  /// Get audit trail with filters
  Future<List<TreasuryAuditLog>> getAuditTrail({
    TreasuryAuditEntityType? entityType,
    String? entityId,
    String? userId,
    TreasuryAuditActionType? actionType,
    TreasuryAuditSeverity? severity,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      AppLogger.info('🔄 Loading audit trail');

      final response = await _supabase.rpc('get_treasury_audit_trail', params: {
        'entity_type_filter': entityType?.code,
        'entity_id_filter': entityId,
        'user_id_filter': userId,
        'action_type_filter': actionType?.code,
        'severity_filter': severity?.code,
        'start_date': startDate?.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
        'limit_count': limit,
        'offset_count': offset,
      });

      final auditLogs = (response as List)
          .map((json) => TreasuryAuditLog.fromJson(json as Map<String, dynamic>))
          .toList();

      AppLogger.info('✅ Loaded ${auditLogs.length} audit logs');
      return auditLogs;
    } catch (e) {
      AppLogger.error('❌ Error loading audit trail: $e');
      throw Exception('فشل في تحميل سجل المراجعة: $e');
    }
  }

  /// Get audit statistics
  Future<Map<String, dynamic>> getAuditStatistics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      AppLogger.info('🔄 Loading audit statistics');

      final response = await _supabase.rpc('get_treasury_audit_statistics', params: {
        'start_date': startDate?.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
      });

      final statistics = response as Map<String, dynamic>;
      AppLogger.info('✅ Audit statistics loaded');
      return statistics;
    } catch (e) {
      AppLogger.error('❌ Error loading audit statistics: $e');
      throw Exception('فشل في تحميل إحصائيات المراجعة: $e');
    }
  }

  /// Log treasury vault operation
  Future<void> logTreasuryVaultOperation({
    required String vaultId,
    required TreasuryAuditActionType actionType,
    required String description,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
    Map<String, dynamic>? metadata,
  }) async {
    await logAuditEvent(
      entityType: TreasuryAuditEntityType.treasuryVault,
      entityId: vaultId,
      actionType: actionType,
      actionDescription: description,
      oldValues: oldValues,
      newValues: newValues,
      metadata: metadata,
      tags: ['treasury', 'vault'],
    );
  }

  /// Log treasury transaction operation
  Future<void> logTreasuryTransactionOperation({
    required String transactionId,
    required TreasuryAuditActionType actionType,
    required String description,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
    Map<String, dynamic>? metadata,
  }) async {
    await logAuditEvent(
      entityType: TreasuryAuditEntityType.treasuryTransaction,
      entityId: transactionId,
      actionType: actionType,
      actionDescription: description,
      oldValues: oldValues,
      newValues: newValues,
      metadata: metadata,
      tags: ['treasury', 'transaction'],
    );
  }

  /// Log fund transfer operation
  Future<void> logFundTransferOperation({
    required String transferId,
    required TreasuryAuditActionType actionType,
    required String description,
    Map<String, dynamic>? metadata,
  }) async {
    await logAuditEvent(
      entityType: TreasuryAuditEntityType.fundTransfer,
      entityId: transferId,
      actionType: actionType,
      actionDescription: description,
      metadata: metadata,
      tags: ['treasury', 'transfer'],
    );
  }

  /// Log treasury limit operation
  Future<void> logTreasuryLimitOperation({
    required String limitId,
    required TreasuryAuditActionType actionType,
    required String description,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
    Map<String, dynamic>? metadata,
  }) async {
    await logAuditEvent(
      entityType: TreasuryAuditEntityType.treasuryLimit,
      entityId: limitId,
      actionType: actionType,
      actionDescription: description,
      oldValues: oldValues,
      newValues: newValues,
      metadata: metadata,
      tags: ['treasury', 'limit'],
    );
  }

  /// Log treasury alert operation
  Future<void> logTreasuryAlertOperation({
    required String alertId,
    required TreasuryAuditActionType actionType,
    required String description,
    Map<String, dynamic>? metadata,
  }) async {
    await logAuditEvent(
      entityType: TreasuryAuditEntityType.treasuryAlert,
      entityId: alertId,
      actionType: actionType,
      actionDescription: description,
      metadata: metadata,
      tags: ['treasury', 'alert'],
    );
  }

  /// Log treasury backup operation
  Future<void> logTreasuryBackupOperation({
    required String backupId,
    required TreasuryAuditActionType actionType,
    required String description,
    Map<String, dynamic>? metadata,
  }) async {
    await logAuditEvent(
      entityType: TreasuryAuditEntityType.treasuryBackup,
      entityId: backupId,
      actionType: actionType,
      actionDescription: description,
      metadata: metadata,
      tags: ['treasury', 'backup'],
    );
  }

  /// Log system error
  Future<void> logSystemError({
    required String errorDescription,
    Map<String, dynamic>? errorDetails,
    String? entityId,
    TreasuryAuditEntityType? entityType,
  }) async {
    await logAuditEvent(
      entityType: entityType ?? TreasuryAuditEntityType.systemEvent,
      entityId: entityId,
      actionType: TreasuryAuditActionType.error,
      actionDescription: errorDescription,
      metadata: errorDetails,
      severity: TreasuryAuditSeverity.error,
      tags: ['system', 'error'],
    );
  }

  /// Get current session ID
  String? get currentSessionId => _currentSessionId;

  /// Check if session is active
  bool get hasActiveSession => _currentSessionId != null;
}
