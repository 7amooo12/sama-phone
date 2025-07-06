import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/treasury_models.dart';
import '../utils/app_logger.dart';

/// Service for managing treasury backups and configurations
class TreasuryBackupService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get all backup configurations
  Future<List<TreasuryBackupConfig>> getBackupConfigs() async {
    try {
      AppLogger.info('🔄 Loading backup configurations');
      
      final response = await _supabase
          .from('treasury_backup_configs')
          .select()
          .order('created_at', ascending: false);

      final configs = (response as List)
          .map((json) => TreasuryBackupConfig.fromJson(json as Map<String, dynamic>))
          .toList();

      AppLogger.info('✅ Loaded ${configs.length} backup configurations');
      return configs;
    } catch (e) {
      AppLogger.error('❌ Error loading backup configurations: $e');
      throw Exception('فشل في تحميل إعدادات النسخ الاحتياطي: $e');
    }
  }

  /// Create or update backup configuration
  Future<TreasuryBackupConfig> saveBackupConfig({
    String? configId,
    required String name,
    String? description,
    required TreasuryBackupType backupType,
    required TreasuryBackupScheduleType scheduleType,
    TreasuryBackupFrequency? scheduleFrequency,
    TimeOfDay? scheduleTime,
    int? scheduleDayOfWeek,
    int? scheduleDayOfMonth,
    bool includeTreasuryVaults = true,
    bool includeTransactions = true,
    bool includeConnections = true,
    bool includeLimits = true,
    bool includeAlerts = true,
    int retentionDays = 30,
    bool isEnabled = true,
  }) async {
    try {
      AppLogger.info('🔄 Saving backup configuration: $name');

      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      final configData = {
        'name': name,
        'description': description,
        'backup_type': backupType.code,
        'schedule_type': scheduleType.code,
        'schedule_frequency': scheduleFrequency?.code,
        'schedule_time': scheduleTime != null
            ? '${scheduleTime.hour.toString().padLeft(2, '0')}:${scheduleTime.minute.toString().padLeft(2, '0')}'
            : null,
        'schedule_day_of_week': scheduleDayOfWeek,
        'schedule_day_of_month': scheduleDayOfMonth,
        'include_treasury_vaults': includeTreasuryVaults,
        'include_transactions': includeTransactions,
        'include_connections': includeConnections,
        'include_limits': includeLimits,
        'include_alerts': includeAlerts,
        'retention_days': retentionDays,
        'is_enabled': isEnabled,
        'updated_at': DateTime.now().toIso8601String(),
      };

      Map<String, dynamic> response;

      if (configId != null) {
        // Update existing configuration
        response = await _supabase
            .from('treasury_backup_configs')
            .update(configData)
            .eq('id', configId)
            .select()
            .single();
      } else {
        // Create new configuration
        configData['created_by'] = currentUser.id;
        response = await _supabase
            .from('treasury_backup_configs')
            .insert(configData)
            .select()
            .single();
      }

      final config = TreasuryBackupConfig.fromJson(response);
      AppLogger.info('✅ Backup configuration saved: ${config.id}');
      return config;
    } catch (e) {
      AppLogger.error('❌ Error saving backup configuration: $e');
      throw Exception('فشل في حفظ إعدادات النسخ الاحتياطي: $e');
    }
  }

  /// Delete backup configuration
  Future<void> deleteBackupConfig(String configId) async {
    try {
      AppLogger.info('🔄 Deleting backup configuration: $configId');

      await _supabase
          .from('treasury_backup_configs')
          .delete()
          .eq('id', configId);

      AppLogger.info('✅ Backup configuration deleted');
    } catch (e) {
      AppLogger.error('❌ Error deleting backup configuration: $e');
      throw Exception('فشل في حذف إعدادات النسخ الاحتياطي: $e');
    }
  }

  /// Get backups for a configuration
  Future<List<TreasuryBackup>> getBackups({
    String? configId,
    int limit = 50,
  }) async {
    try {
      AppLogger.info('🔄 Loading backups');

      var query = _supabase
          .from('treasury_backups')
          .select()
          .order('started_at', ascending: false)
          .limit(limit);

      if (configId != null) {
        query = query.eq('config_id', configId);
      }

      final response = await query;

      final backups = (response as List)
          .map((json) => TreasuryBackup.fromJson(json as Map<String, dynamic>))
          .toList();

      AppLogger.info('✅ Loaded ${backups.length} backups');
      return backups;
    } catch (e) {
      AppLogger.error('❌ Error loading backups: $e');
      throw Exception('فشل في تحميل النسخ الاحتياطية: $e');
    }
  }

  /// Create manual backup
  Future<String> createManualBackup({
    required String configId,
    String? customName,
  }) async {
    try {
      AppLogger.info('🔄 Creating manual backup for config: $configId');

      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      final backupName = customName ?? 'نسخة احتياطية يدوية - ${DateTime.now().toIso8601String()}';

      final backupId = await _supabase.rpc('create_treasury_backup', params: {
        'config_uuid': configId,
        'backup_name_param': backupName,
        'user_uuid': currentUser.id,
      });

      AppLogger.info('✅ Manual backup created: $backupId');
      return backupId as String;
    } catch (e) {
      AppLogger.error('❌ Error creating manual backup: $e');
      throw Exception('فشل في إنشاء النسخة الاحتياطية: $e');
    }
  }

  /// Restore backup
  Future<Map<String, dynamic>> restoreBackup({
    required String backupId,
    bool restoreVaults = true,
    bool restoreTransactions = true,
    bool restoreConnections = true,
    bool restoreLimits = true,
    bool restoreAlerts = true,
    bool clearExisting = false,
  }) async {
    try {
      AppLogger.info('🔄 Restoring backup: $backupId');

      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      final restoreOptions = {
        'restore_vaults': restoreVaults,
        'restore_transactions': restoreTransactions,
        'restore_connections': restoreConnections,
        'restore_limits': restoreLimits,
        'restore_alerts': restoreAlerts,
        'clear_existing': clearExisting,
      };

      final result = await _supabase.rpc('restore_treasury_backup', params: {
        'backup_uuid': backupId,
        'restore_options': restoreOptions,
        'user_uuid': currentUser.id,
      });

      AppLogger.info('✅ Backup restored successfully');
      return result as Map<String, dynamic>;
    } catch (e) {
      AppLogger.error('❌ Error restoring backup: $e');
      throw Exception('فشل في استعادة النسخة الاحتياطية: $e');
    }
  }

  /// Delete backup
  Future<void> deleteBackup(String backupId) async {
    try {
      AppLogger.info('🔄 Deleting backup: $backupId');

      await _supabase
          .from('treasury_backups')
          .delete()
          .eq('id', backupId);

      AppLogger.info('✅ Backup deleted');
    } catch (e) {
      AppLogger.error('❌ Error deleting backup: $e');
      throw Exception('فشل في حذف النسخة الاحتياطية: $e');
    }
  }

  /// Get backup statistics
  Future<Map<String, dynamic>> getBackupStatistics() async {
    try {
      AppLogger.info('🔄 Loading backup statistics');

      final response = await _supabase
          .from('treasury_backups')
          .select('backup_status, file_size, started_at, completed_at');

      final backups = response as List;

      final totalBackups = backups.length;
      final completedBackups = backups.where((b) => b['backup_status'] == 'completed').length;
      final failedBackups = backups.where((b) => b['backup_status'] == 'failed').length;
      final pendingBackups = backups.where((b) => b['backup_status'] == 'pending').length;

      double totalSize = 0;
      for (final backup in backups) {
        if (backup['file_size'] != null) {
          totalSize += (backup['file_size'] as num).toDouble();
        }
      }

      final statistics = {
        'total_backups': totalBackups,
        'completed_backups': completedBackups,
        'failed_backups': failedBackups,
        'pending_backups': pendingBackups,
        'success_rate': totalBackups > 0 ? (completedBackups / totalBackups * 100) : 0.0,
        'total_size_bytes': totalSize,
      };

      AppLogger.info('✅ Backup statistics calculated');
      return statistics;
    } catch (e) {
      AppLogger.error('❌ Error loading backup statistics: $e');
      throw Exception('فشل في تحميل إحصائيات النسخ الاحتياطي: $e');
    }
  }

  /// Export backup data as JSON string
  String exportBackupAsJson(TreasuryBackup backup) {
    if (backup.backupData == null) {
      throw Exception('لا توجد بيانات للتصدير في هذه النسخة الاحتياطية');
    }

    try {
      final exportData = {
        ...backup.backupData!,
        'export_metadata': {
          'backup_id': backup.id,
          'backup_name': backup.backupName,
          'exported_at': DateTime.now().toIso8601String(),
          'exported_by': _supabase.auth.currentUser?.id,
        },
      };

      return jsonEncode(exportData);
    } catch (e) {
      AppLogger.error('❌ Error exporting backup data: $e');
      throw Exception('فشل في تصدير بيانات النسخة الاحتياطية: $e');
    }
  }
}
