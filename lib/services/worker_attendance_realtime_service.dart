import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smartbiztracker_new/models/worker_attendance_model.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// خدمة التحديثات الفورية لحضور العمال
class WorkerAttendanceRealtimeService {
  static final WorkerAttendanceRealtimeService _instance = WorkerAttendanceRealtimeService._internal();
  factory WorkerAttendanceRealtimeService() => _instance;
  WorkerAttendanceRealtimeService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  
  // Stream controllers للتحديثات الفورية
  final StreamController<AttendanceStatistics> _statisticsController = 
      StreamController<AttendanceStatistics>.broadcast();
  final StreamController<WorkerAttendanceModel> _newAttendanceController = 
      StreamController<WorkerAttendanceModel>.broadcast();
  final StreamController<List<WorkerAttendanceModel>> _recentAttendanceController = 
      StreamController<List<WorkerAttendanceModel>>.broadcast();
  
  // Subscription للاستماع للتغييرات
  RealtimeChannel? _attendanceChannel;
  RealtimeChannel? _statisticsChannel;
  
  // Cache للبيانات
  AttendanceStatistics? _cachedStatistics;
  List<WorkerAttendanceModel> _cachedRecentAttendance = [];
  
  // Timer للتحديث الدوري
  Timer? _periodicUpdateTimer;

  // Getters للـ streams
  Stream<AttendanceStatistics> get statisticsStream => _statisticsController.stream;
  Stream<WorkerAttendanceModel> get newAttendanceStream => _newAttendanceController.stream;
  Stream<List<WorkerAttendanceModel>> get recentAttendanceStream => _recentAttendanceController.stream;

  /// تهيئة الخدمة والاشتراك في التحديثات الفورية
  Future<void> initialize() async {
    try {
      AppLogger.info('🚀 تهيئة خدمة التحديثات الفورية...');
      
      // تحميل البيانات الأولية
      await _loadInitialData();
      
      // بدء الاستماع للتحديثات الفورية
      await _startRealtimeSubscriptions();
      
      // بدء التحديث الدوري
      _startPeriodicUpdates();
      
      AppLogger.info('✅ تم تهيئة خدمة التحديثات الفورية بنجاح');
    } catch (e) {
      AppLogger.error('❌ خطأ في تهيئة خدمة التحديثات الفورية: $e');
      rethrow;
    }
  }

  /// تحميل البيانات الأولية
  Future<void> _loadInitialData() async {
    try {
      // تحميل الإحصائيات
      await refreshStatistics();
      
      // تحميل الحضور الحديث
      await refreshRecentAttendance();
      
      AppLogger.info('📊 تم تحميل البيانات الأولية');
    } catch (e) {
      AppLogger.error('❌ خطأ في تحميل البيانات الأولية: $e');
    }
  }

  /// بدء الاشتراك في التحديثات الفورية
  Future<void> _startRealtimeSubscriptions() async {
    try {
      // الاشتراك في تحديثات جدول الحضور
      _attendanceChannel = _supabase
          .channel('worker_attendance_records')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'worker_attendance_records',
            callback: _handleNewAttendanceRecord,
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'worker_attendance_records',
            callback: _handleUpdatedAttendanceRecord,
          );

      await _attendanceChannel?.subscribe();
      
      AppLogger.info('🔔 تم الاشتراك في تحديثات الحضور الفورية');
    } catch (e) {
      AppLogger.error('❌ خطأ في الاشتراك في التحديثات الفورية: $e');
    }
  }

  /// معالجة سجل حضور جديد
  void _handleNewAttendanceRecord(PostgresChangePayload payload) {
    try {
      AppLogger.info('📥 تم استلام سجل حضور جديد');
      
      final data = payload.newRecord;
      if (data != null) {
        final attendanceRecord = WorkerAttendanceModel.fromJson(data);
        
        // إضافة السجل للحضور الحديث
        _cachedRecentAttendance.insert(0, attendanceRecord);
        if (_cachedRecentAttendance.length > 10) {
          _cachedRecentAttendance = _cachedRecentAttendance.take(10).toList();
        }
        
        // إرسال التحديثات
        _newAttendanceController.add(attendanceRecord);
        _recentAttendanceController.add(List.from(_cachedRecentAttendance));
        
        // تحديث الإحصائيات
        _updateStatisticsAfterNewRecord(attendanceRecord);
        
        AppLogger.info('✅ تم معالجة سجل الحضور الجديد: ${attendanceRecord.workerName}');
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في معالجة سجل الحضور الجديد: $e');
    }
  }

  /// معالجة تحديث سجل حضور
  void _handleUpdatedAttendanceRecord(PostgresChangePayload payload) {
    try {
      AppLogger.info('📝 تم تحديث سجل حضور');
      
      final data = payload.newRecord;
      if (data != null) {
        final updatedRecord = WorkerAttendanceModel.fromJson(data);
        
        // تحديث السجل في القائمة المحفوظة
        final index = _cachedRecentAttendance.indexWhere((record) => record.id == updatedRecord.id);
        if (index != -1) {
          _cachedRecentAttendance[index] = updatedRecord;
          _recentAttendanceController.add(List.from(_cachedRecentAttendance));
        }
        
        AppLogger.info('✅ تم تحديث سجل الحضور: ${updatedRecord.workerName}');
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في معالجة تحديث سجل الحضور: $e');
    }
  }

  /// تحديث الإحصائيات بعد سجل جديد
  void _updateStatisticsAfterNewRecord(WorkerAttendanceModel record) {
    if (_cachedStatistics == null) return;
    
    try {
      final updatedStats = AttendanceStatistics(
        totalWorkers: _cachedStatistics!.totalWorkers,
        presentWorkers: record.type == AttendanceType.checkIn 
            ? _cachedStatistics!.presentWorkers + 1
            : _cachedStatistics!.presentWorkers - 1,
        absentWorkers: _cachedStatistics!.absentWorkers,
        lateWorkers: _cachedStatistics!.lateWorkers,
        recentAttendance: _cachedRecentAttendance,
        lastUpdated: DateTime.now(),
      );
      
      _cachedStatistics = updatedStats;
      _statisticsController.add(updatedStats);
      
      AppLogger.info('📊 تم تحديث الإحصائيات فورياً');
    } catch (e) {
      AppLogger.error('❌ خطأ في تحديث الإحصائيات: $e');
    }
  }

  /// بدء التحديث الدوري
  void _startPeriodicUpdates() {
    _periodicUpdateTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _refreshAllData();
    });
    
    AppLogger.info('⏰ تم بدء التحديث الدوري كل 5 دقائق');
  }

  /// تحديث جميع البيانات
  Future<void> _refreshAllData() async {
    try {
      await Future.wait([
        refreshStatistics(),
        refreshRecentAttendance(),
      ]);
      
      AppLogger.info('🔄 تم تحديث جميع البيانات دورياً');
    } catch (e) {
      AppLogger.error('❌ خطأ في التحديث الدوري: $e');
    }
  }

  /// تحديث الإحصائيات
  Future<void> refreshStatistics() async {
    try {
      final response = await _supabase.rpc('get_attendance_statistics');
      
      if (response != null) {
        final data = response as Map<String, dynamic>;
        
        final statistics = AttendanceStatistics(
          totalWorkers: data['total_workers'] ?? 0,
          presentWorkers: data['present_workers'] ?? 0,
          absentWorkers: data['absent_workers'] ?? 0,
          lateWorkers: data['late_workers'] ?? 0,
          recentAttendance: _cachedRecentAttendance,
          lastUpdated: DateTime.now(),
        );
        
        _cachedStatistics = statistics;
        _statisticsController.add(statistics);
        
        AppLogger.info('📊 تم تحديث الإحصائيات');
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في تحديث الإحصائيات: $e');
    }
  }

  /// تحديث الحضور الحديث
  Future<void> refreshRecentAttendance() async {
    try {
      final response = await _supabase
          .from('worker_attendance_records')
          .select('*')
          .order('created_at', ascending: false)
          .limit(10);

      final recentAttendance = (response as List)
          .map((item) => WorkerAttendanceModel.fromJson(item))
          .toList();

      _cachedRecentAttendance = recentAttendance;
      _recentAttendanceController.add(recentAttendance);
      
      // تحديث الإحصائيات مع الحضور الحديث
      if (_cachedStatistics != null) {
        final updatedStats = AttendanceStatistics(
          totalWorkers: _cachedStatistics!.totalWorkers,
          presentWorkers: _cachedStatistics!.presentWorkers,
          absentWorkers: _cachedStatistics!.absentWorkers,
          lateWorkers: _cachedStatistics!.lateWorkers,
          recentAttendance: recentAttendance,
          lastUpdated: DateTime.now(),
        );
        
        _cachedStatistics = updatedStats;
        _statisticsController.add(updatedStats);
      }
      
      AppLogger.info('📋 تم تحديث الحضور الحديث');
    } catch (e) {
      AppLogger.error('❌ خطأ في تحديث الحضور الحديث: $e');
    }
  }

  /// إضافة سجل حضور جديد محلياً (للتحديث الفوري)
  void addAttendanceRecordLocally(WorkerAttendanceModel record) {
    try {
      // إضافة السجل للحضور الحديث
      _cachedRecentAttendance.insert(0, record);
      if (_cachedRecentAttendance.length > 10) {
        _cachedRecentAttendance = _cachedRecentAttendance.take(10).toList();
      }
      
      // إرسال التحديثات
      _newAttendanceController.add(record);
      _recentAttendanceController.add(List.from(_cachedRecentAttendance));
      
      // تحديث الإحصائيات
      _updateStatisticsAfterNewRecord(record);
      
      AppLogger.info('✅ تم إضافة سجل الحضور محلياً: ${record.workerName}');
    } catch (e) {
      AppLogger.error('❌ خطأ في إضافة سجل الحضور محلياً: $e');
    }
  }

  /// الحصول على الإحصائيات المحفوظة
  AttendanceStatistics? get cachedStatistics => _cachedStatistics;

  /// الحصول على الحضور الحديث المحفوظ
  List<WorkerAttendanceModel> get cachedRecentAttendance => List.from(_cachedRecentAttendance);

  /// إيقاف الخدمة وتنظيف الموارد
  Future<void> dispose() async {
    try {
      AppLogger.info('🛑 إيقاف خدمة التحديثات الفورية...');
      
      // إلغاء الاشتراكات
      await _attendanceChannel?.unsubscribe();
      await _statisticsChannel?.unsubscribe();
      
      // إيقاف التحديث الدوري
      _periodicUpdateTimer?.cancel();
      
      // إغلاق الـ streams
      await _statisticsController.close();
      await _newAttendanceController.close();
      await _recentAttendanceController.close();
      
      AppLogger.info('✅ تم إيقاف خدمة التحديثات الفورية');
    } catch (e) {
      AppLogger.error('❌ خطأ في إيقاف خدمة التحديثات الفورية: $e');
    }
  }

  /// إعادة الاتصال في حالة انقطاع الشبكة
  Future<void> reconnect() async {
    try {
      AppLogger.info('🔄 إعادة الاتصال بخدمة التحديثات الفورية...');
      
      // إيقاف الاتصالات الحالية
      await _attendanceChannel?.unsubscribe();
      
      // إعادة بدء الاشتراكات
      await _startRealtimeSubscriptions();
      
      // تحديث البيانات
      await _refreshAllData();
      
      AppLogger.info('✅ تم إعادة الاتصال بنجاح');
    } catch (e) {
      AppLogger.error('❌ خطأ في إعادة الاتصال: $e');
    }
  }
}
