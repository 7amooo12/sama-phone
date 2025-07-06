/// Worker Attendance Reports Provider for SmartBizTracker
/// 
/// This provider manages the state for attendance reports including
/// time period selection, data caching, and settings management.

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:smartbiztracker_new/models/attendance_models.dart';
import 'package:smartbiztracker_new/services/worker_attendance_reports_service.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';

class WorkerAttendanceReportsProvider extends ChangeNotifier {
  final WorkerAttendanceReportsService _reportsService = WorkerAttendanceReportsService();
  final SupabaseClient _supabase = Supabase.instance.client;

  // State management
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;

  // Report data
  AttendanceReportPeriod _selectedPeriod = AttendanceReportPeriod.daily;
  List<WorkerAttendanceReportData> _reportData = [];
  AttendanceReportSummary? _reportSummary;
  AttendanceSettings _attendanceSettings = AttendanceSettings.defaultSettings();

  // Cache management
  DateTime? _lastCacheUpdate;
  static const Duration _cacheValidDuration = Duration(minutes: 5);
  final Map<AttendanceReportPeriod, List<WorkerAttendanceReportData>> _cachedReportData = {};
  final Map<AttendanceReportPeriod, AttendanceReportSummary> _cachedSummaries = {};

  // Real-time updates
  StreamSubscription<List<Map<String, dynamic>>>? _attendanceSubscription;
  bool _realTimeEnabled = true;
  
  // Getters
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  AttendanceReportPeriod get selectedPeriod => _selectedPeriod;
  List<WorkerAttendanceReportData> get reportData => _reportData;
  AttendanceReportSummary? get reportSummary => _reportSummary;
  AttendanceSettings get attendanceSettings => _attendanceSettings;
  
  /// Initialize the provider
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      AppLogger.info('🚀 بدء تهيئة مزود تقارير الحضور...');
      
      _setLoading(true);
      _clearError();
      
      // Load attendance settings from preferences
      await _loadAttendanceSettings();

      // Load initial report data
      await _loadReportData();

      // Setup real-time updates
      _setupRealTimeUpdates();

      _isInitialized = true;
      AppLogger.info('✅ تم تهيئة مزود تقارير الحضور بنجاح');
      
    } catch (e) {
      AppLogger.error('❌ خطأ في تهيئة مزود تقارير الحضور: $e');
      _setError('فشل في تهيئة تقارير الحضور: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  /// Change the selected time period
  Future<void> changePeriod(AttendanceReportPeriod period) async {
    if (_selectedPeriod == period) return;
    
    try {
      AppLogger.info('📅 تغيير فترة التقرير إلى: ${period.displayName}');
      
      _selectedPeriod = period;
      _safeNotifyListeners();
      
      // Load data for the new period
      await _loadReportData();
      
    } catch (e) {
      AppLogger.error('❌ خطأ في تغيير فترة التقرير: $e');
      _setError('فشل في تغيير فترة التقرير: $e');
    }
  }
  
  /// Update attendance settings
  Future<void> updateAttendanceSettings(AttendanceSettings newSettings) async {
    try {
      AppLogger.info('⚙️ تحديث إعدادات الحضور...');

      _setLoading(true);
      _clearError();

      // Validate settings before saving
      final validationError = newSettings.validate();
      if (validationError != null) {
        throw Exception('إعدادات غير صحيحة: $validationError');
      }

      _attendanceSettings = newSettings;

      // Save settings to preferences
      await _saveAttendanceSettings();

      // Clear cache and reload data with new settings
      _clearCache();
      await _loadReportData();

      AppLogger.info('✅ تم تحديث إعدادات الحضور بنجاح');

    } catch (e) {
      AppLogger.error('❌ خطأ في تحديث إعدادات الحضور: $e');
      _setError('فشل في تحديث إعدادات الحضور: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  /// Refresh report data
  Future<void> refresh() async {
    try {
      AppLogger.info('🔄 تحديث بيانات تقرير الحضور...');
      
      _clearCache();
      await _loadReportData();
      
      AppLogger.info('✅ تم تحديث بيانات تقرير الحضور بنجاح');
      
    } catch (e) {
      AppLogger.error('❌ خطأ في تحديث بيانات تقرير الحضور: $e');
      _setError('فشل في تحديث بيانات التقرير: $e');
    }
  }
  
  /// Get report data for a specific worker
  WorkerAttendanceReportData? getWorkerReportData(String workerId) {
    try {
      return _reportData.firstWhere((data) => data.workerId == workerId);
    } catch (e) {
      return null;
    }
  }
  
  /// Get workers by attendance status
  List<WorkerAttendanceReportData> getWorkersByStatus(AttendanceReportStatus status) {
    return _reportData.where((data) => 
        data.checkInStatus == status || data.checkOutStatus == status).toList();
  }
  
  /// Export report data
  Future<String> exportReportData({
    required String format, // 'pdf' or 'excel'
  }) async {
    try {
      AppLogger.info('📄 تصدير بيانات التقرير بصيغة: $format');

      final result = await _reportsService.exportAttendanceReport(
        period: _selectedPeriod,
        format: format,
        settings: _attendanceSettings,
      );

      if (result['success'] == true) {
        AppLogger.info('✅ تم تصدير التقرير بنجاح: ${result['file_name']}');
        return result['message'] as String;
      } else {
        throw Exception(result['message']);
      }

    } catch (e) {
      AppLogger.error('❌ خطأ في تصدير التقرير: $e');
      throw Exception('فشل في تصدير التقرير: $e');
    }
  }
  
  /// Load report data from service
  Future<void> _loadReportData() async {
    try {
      // Check cache first
      if (_isCacheValid() && _cachedReportData.containsKey(_selectedPeriod)) {
        _reportData = _cachedReportData[_selectedPeriod]!;
        _reportSummary = _cachedSummaries[_selectedPeriod];
        _safeNotifyListeners();
        return;
      }
      
      _setLoading(true);
      _clearError();
      
      // Load fresh data from service
      final reportData = await _reportsService.getAttendanceReportData(
        period: _selectedPeriod,
        settings: _attendanceSettings,
      );
      
      final reportSummary = await _reportsService.getAttendanceSummary(
        period: _selectedPeriod,
        settings: _attendanceSettings,
      );
      
      // Update state
      _reportData = reportData;
      _reportSummary = reportSummary;
      
      // Update cache
      _cachedReportData[_selectedPeriod] = reportData;
      _cachedSummaries[_selectedPeriod] = reportSummary;
      _lastCacheUpdate = DateTime.now();
      
      _safeNotifyListeners();
      
    } catch (e) {
      AppLogger.error('❌ خطأ في تحميل بيانات التقرير: $e');
      _setError('فشل في تحميل بيانات التقرير: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  /// Load attendance settings from database, SharedPreferences, or defaults
  Future<void> _loadAttendanceSettings() async {
    try {
      AppLogger.info('🔄 جاري تحميل إعدادات الحضور...');

      // First, try to load from database
      final databaseSettings = await _loadSettingsFromDatabase();
      if (databaseSettings != null) {
        _attendanceSettings = databaseSettings;
        AppLogger.info('✅ تم تحميل إعدادات الحضور من قاعدة البيانات');

        // Cache settings locally for offline access
        await _cacheSettingsToSharedPreferences(_attendanceSettings);
        return;
      }

      // Fallback to SharedPreferences if database fails
      final cachedSettings = await _loadSettingsFromSharedPreferences();
      if (cachedSettings != null) {
        _attendanceSettings = cachedSettings;
        AppLogger.info('✅ تم تحميل إعدادات الحضور من التخزين المحلي');
        return;
      }

      // Final fallback to default settings
      _attendanceSettings = AttendanceSettings.defaultSettings();
      AppLogger.info('ℹ️ استخدام إعدادات الحضور الافتراضية');

    } catch (e) {
      AppLogger.error('❌ خطأ في تحميل إعدادات الحضور: $e');

      // Try to load from SharedPreferences as fallback
      try {
        final cachedSettings = await _loadSettingsFromSharedPreferences();
        if (cachedSettings != null) {
          _attendanceSettings = cachedSettings;
          AppLogger.info('✅ تم تحميل إعدادات الحضور من التخزين المحلي (احتياطي)');
          return;
        }
      } catch (cacheError) {
        AppLogger.error('❌ خطأ في تحميل إعدادات الحضور من التخزين المحلي: $cacheError');
      }

      // Use default settings on all errors
      _attendanceSettings = AttendanceSettings.defaultSettings();
      AppLogger.info('ℹ️ استخدام إعدادات الحضور الافتراضية (بعد فشل التحميل)');
    }
  }

  /// Save attendance settings to database and SharedPreferences
  Future<void> _saveAttendanceSettings() async {
    try {
      AppLogger.info('💾 جاري حفظ إعدادات الحضور...');

      bool databaseSaveSuccess = false;
      bool sharedPrefsSaveSuccess = false;

      // Try to save to database first
      try {
        await _saveSettingsToDatabase(_attendanceSettings);
        databaseSaveSuccess = true;
        AppLogger.info('✅ تم حفظ إعدادات الحضور في قاعدة البيانات');
      } catch (dbError) {
        AppLogger.error('❌ خطأ في حفظ إعدادات الحضور في قاعدة البيانات: $dbError');
      }

      // Always save to SharedPreferences as backup
      try {
        await _cacheSettingsToSharedPreferences(_attendanceSettings);
        sharedPrefsSaveSuccess = true;
        AppLogger.info('✅ تم حفظ إعدادات الحضور في التخزين المحلي');
      } catch (cacheError) {
        AppLogger.error('❌ خطأ في حفظ إعدادات الحضور في التخزين المحلي: $cacheError');
      }

      if (databaseSaveSuccess || sharedPrefsSaveSuccess) {
        AppLogger.info('✅ تم حفظ إعدادات الحضور بنجاح');
      } else {
        throw Exception('فشل في حفظ إعدادات الحضور في جميع وسائل التخزين');
      }

    } catch (e) {
      AppLogger.error('❌ خطأ في حفظ إعدادات الحضور: $e');
      rethrow;
    }
  }
  
  /// Load attendance settings from database
  Future<AttendanceSettings?> _loadSettingsFromDatabase() async {
    try {
      final response = await _supabase.rpc('get_attendance_settings');

      if (response == null) {
        AppLogger.info('ℹ️ لا توجد إعدادات حضور محفوظة في قاعدة البيانات');
        return null;
      }

      final settingsData = response as Map<String, dynamic>;

      // Check if these are default settings (no database record)
      if (settingsData['is_default'] == true) {
        AppLogger.info('ℹ️ قاعدة البيانات ترجع الإعدادات الافتراضية');
        return null;
      }

      final settings = AttendanceSettings.fromJson(settingsData);

      // Validate loaded settings
      final validationError = settings.validate();
      if (validationError != null) {
        AppLogger.warning('⚠️ إعدادات الحضور المحملة من قاعدة البيانات غير صحيحة: $validationError');
        return null;
      }

      return settings;
    } catch (e) {
      AppLogger.error('❌ خطأ في تحميل إعدادات الحضور من قاعدة البيانات: $e');
      return null;
    }
  }

  /// Save attendance settings to database
  Future<void> _saveSettingsToDatabase(AttendanceSettings settings) async {
    try {
      final response = await _supabase.rpc('update_attendance_settings', params: {
        'p_work_start_hour': settings.workStartTime.hour,
        'p_work_start_minute': settings.workStartTime.minute,
        'p_work_end_hour': settings.workEndTime.hour,
        'p_work_end_minute': settings.workEndTime.minute,
        'p_late_tolerance_minutes': settings.lateToleranceMinutes,
        'p_early_departure_tolerance_minutes': settings.earlyDepartureToleranceMinutes,
        'p_required_daily_hours': settings.requiredDailyHours,
        'p_work_days': settings.workDays,
      });

      if (response == null || response['success'] != true) {
        throw Exception(response?['message'] ?? 'فشل في حفظ الإعدادات');
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في حفظ إعدادات الحضور في قاعدة البيانات: $e');
      rethrow;
    }
  }

  /// Load attendance settings from SharedPreferences
  Future<AttendanceSettings?> _loadSettingsFromSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString('attendance_settings');

      if (settingsJson == null || settingsJson.isEmpty) {
        AppLogger.info('ℹ️ لا توجد إعدادات حضور محفوظة في التخزين المحلي');
        return null;
      }

      // Check cache timestamp
      final timestamp = prefs.getInt('attendance_settings_timestamp');
      if (timestamp != null) {
        final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
        const maxCacheAge = 30 * 24 * 60 * 60 * 1000; // Cache expires after 30 days (in milliseconds)

        if (cacheAge > maxCacheAge) {
          AppLogger.info('ℹ️ إعدادات الحضور المحلية منتهية الصلاحية');
          await prefs.remove('attendance_settings');
          await prefs.remove('attendance_settings_timestamp');
          return null;
        }
      }

      final settingsData = jsonDecode(settingsJson) as Map<String, dynamic>;
      final settings = AttendanceSettings.fromJson(settingsData);

      // Validate loaded settings
      final validationError = settings.validate();
      if (validationError != null) {
        AppLogger.warning('⚠️ إعدادات الحضور المحلية غير صحيحة: $validationError');
        // Clear invalid cached settings
        await prefs.remove('attendance_settings');
        await prefs.remove('attendance_settings_timestamp');
        return null;
      }

      return settings;
    } catch (e) {
      AppLogger.error('❌ خطأ في تحميل إعدادات الحضور من التخزين المحلي: $e');

      // Clear corrupted cache
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('attendance_settings');
        await prefs.remove('attendance_settings_timestamp');
      } catch (clearError) {
        AppLogger.error('❌ خطأ في مسح التخزين المحلي المعطوب: $clearError');
      }

      return null;
    }
  }

  /// Cache attendance settings to SharedPreferences
  Future<void> _cacheSettingsToSharedPreferences(AttendanceSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = jsonEncode(settings.toJson());
      await prefs.setString('attendance_settings', settingsJson);

      // Also store timestamp for cache validation
      await prefs.setInt('attendance_settings_timestamp', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      AppLogger.error('❌ خطأ في حفظ إعدادات الحضور في التخزين المحلي: $e');
      rethrow;
    }
  }

  /// Check if cache is still valid
  bool _isCacheValid() {
    if (_lastCacheUpdate == null) return false;
    return DateTime.now().difference(_lastCacheUpdate!) < _cacheValidDuration;
  }

  /// Clear all cached data
  void _clearCache() {
    _cachedReportData.clear();
    _cachedSummaries.clear();
    _lastCacheUpdate = null;
  }
  
  /// Set loading state
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      _safeNotifyListeners();
    }
  }

  /// Set error state
  void _setError(String error) {
    _error = error;
    _safeNotifyListeners();
  }

  /// Clear error state
  void _clearError() {
    if (_error != null) {
      _error = null;
      _safeNotifyListeners();
    }
  }

  /// Safely notify listeners to avoid framework assertion errors
  void _safeNotifyListeners() {
    if (!hasListeners) return;

    try {
      // Use post-frame callback to ensure we're not in the middle of a build
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (hasListeners) {
          notifyListeners();
        }
      });
    } catch (e) {
      // Fallback to immediate notification if post-frame callback fails
      try {
        notifyListeners();
      } catch (e2) {
        AppLogger.error('❌ خطأ في إشعار المستمعين: $e2');
      }
    }
  }
  
  /// Setup real-time updates for attendance records
  void _setupRealTimeUpdates() {
    try {
      if (!_realTimeEnabled) return;

      AppLogger.info('🔄 إعداد التحديثات الفورية لسجلات الحضور...');

      // Subscribe to worker_attendance_records table changes
      // Note: This is a placeholder implementation since Supabase real-time
      // subscriptions require proper setup and authentication

      // TODO: Implement actual Supabase real-time subscription
      // _attendanceSubscription = Supabase.instance.client
      //     .from('worker_attendance_records')
      //     .stream(primaryKey: ['id'])
      //     .listen(_handleAttendanceUpdate);

      AppLogger.info('✅ تم إعداد التحديثات الفورية بنجاح');

    } catch (e) {
      AppLogger.error('❌ خطأ في إعداد التحديثات الفورية: $e');
    }
  }

  /// Handle real-time attendance record updates
  void _handleAttendanceUpdate(List<Map<String, dynamic>> data) {
    try {
      AppLogger.info('📡 تم استلام تحديث فوري لسجلات الحضور');

      // Clear cache to force refresh on next data request
      _clearCache();

      // If we're currently viewing data, refresh it
      if (_isInitialized && !_isLoading) {
        _loadReportData();
      }

    } catch (e) {
      AppLogger.error('❌ خطأ في معالجة التحديث الفوري: $e');
    }
  }

  /// Enable or disable real-time updates
  void setRealTimeUpdates(bool enabled) {
    if (_realTimeEnabled == enabled) return;

    _realTimeEnabled = enabled;

    if (enabled) {
      _setupRealTimeUpdates();
    } else {
      _attendanceSubscription?.cancel();
      _attendanceSubscription = null;
    }

    AppLogger.info('🔄 تم ${enabled ? 'تفعيل' : 'إلغاء'} التحديثات الفورية');
  }

  /// Force refresh data (useful for manual refresh)
  Future<void> forceRefresh() async {
    try {
      AppLogger.info('🔄 فرض تحديث البيانات...');

      _clearCache();
      await _loadReportData();

      AppLogger.info('✅ تم تحديث البيانات بنجاح');

    } catch (e) {
      AppLogger.error('❌ خطأ في فرض تحديث البيانات: $e');
      _setError('فشل في تحديث البيانات: $e');
    }
  }

  @override
  void dispose() {
    _attendanceSubscription?.cancel();
    _clearCache();
    super.dispose();
  }
}
