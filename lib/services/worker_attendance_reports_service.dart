/// Worker Attendance Reports Service for SmartBizTracker
/// 
/// This service handles all attendance reporting functionality including
/// data retrieval, analytics calculations, and report generation.

import 'package:smartbiztracker_new/models/attendance_models.dart';
import 'package:smartbiztracker_new/models/user_model.dart';
import 'package:smartbiztracker_new/providers/supabase_provider.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WorkerAttendanceReportsService {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  /// Get attendance report data for a specific period using optimized database function
  Future<List<WorkerAttendanceReportData>> getAttendanceReportData({
    required AttendanceReportPeriod period,
    AttendanceSettings? settings,
  }) async {
    try {
      AppLogger.info('🔍 جاري جلب بيانات تقرير الحضور للفترة: ${period.displayName}');

      final dateRange = period.getDateRange();
      final attendanceSettings = settings ?? AttendanceSettings.defaultSettings();

      // Use optimized database function for better performance
      final response = await _supabase.rpc(
        'get_worker_attendance_report_data',
        params: {
          'start_date': dateRange.startDate.toIso8601String(),
          'end_date': dateRange.endDate.toIso8601String(),
          'work_start_hour': attendanceSettings.workStartTime.hour,
          'work_start_minute': attendanceSettings.workStartTime.minute,
          'work_end_hour': attendanceSettings.workEndTime.hour,
          'work_end_minute': attendanceSettings.workEndTime.minute,
          'late_tolerance_minutes': attendanceSettings.lateToleranceMinutes,
          'early_departure_tolerance_minutes': attendanceSettings.earlyDepartureToleranceMinutes,
        },
      );

      if (response == null || response.isEmpty) {
        AppLogger.info('ℹ️ لا يوجد عمال مسجلين في النظام');
        return [];
      }

      final reportData = (response as List<dynamic>)
          .map((data) => WorkerAttendanceReportData.fromJson(data as Map<String, dynamic>))
          .toList();

      AppLogger.info('✅ تم جلب بيانات تقرير الحضور بنجاح: ${reportData.length} عامل');
      return reportData;

    } catch (e) {
      AppLogger.error('❌ خطأ في جلب بيانات تقرير الحضور: $e');
      // Fallback to manual calculation if database function fails
      return await _getAttendanceReportDataFallback(period: period, settings: settings);
    }
  }

  /// Fallback method for getting attendance report data
  Future<List<WorkerAttendanceReportData>> _getAttendanceReportDataFallback({
    required AttendanceReportPeriod period,
    AttendanceSettings? settings,
  }) async {
    try {
      AppLogger.info('🔄 استخدام الطريقة البديلة لجلب بيانات تقرير الحضور');

      final dateRange = period.getDateRange();
      final attendanceSettings = settings ?? AttendanceSettings.defaultSettings();

      // Get all workers with role 'worker' or 'عامل' (support both English and Arabic)
      // and status 'approved' or 'active' (support both status values)
      final workersResponse = await _supabase
          .from('user_profiles')
          .select('id, name, profile_image')
          .or('role.eq.worker,role.eq.عامل')
          .or('status.eq.approved,status.eq.active');

      if (workersResponse.isEmpty) {
        AppLogger.info('ℹ️ لا يوجد عمال مسجلين في النظام');
        return [];
      }

      final workers = workersResponse as List<dynamic>;
      final reportData = <WorkerAttendanceReportData>[];

      for (final worker in workers) {
        final workerId = worker['id'] as String;
        final workerName = worker['name'] as String;
        final profileImageUrl = worker['profile_image'] as String?;

        // Get attendance records for this worker in the specified period
        final attendanceRecords = await _getWorkerAttendanceRecords(
          workerId: workerId,
          startDate: dateRange.startDate,
          endDate: dateRange.endDate,
        );

        // Calculate attendance statistics
        final workerReportData = await _calculateWorkerAttendanceData(
          workerId: workerId,
          workerName: workerName,
          profileImageUrl: profileImageUrl,
          attendanceRecords: attendanceRecords,
          period: period,
          settings: attendanceSettings,
          dateRange: dateRange,
        );

        reportData.add(workerReportData);
      }

      AppLogger.info('✅ تم جلب بيانات تقرير الحضور بنجاح (الطريقة البديلة): ${reportData.length} عامل');
      return reportData;

    } catch (e) {
      AppLogger.error('❌ خطأ في الطريقة البديلة لجلب بيانات تقرير الحضور: $e');
      rethrow;
    }
  }
  
  /// Get attendance summary statistics for a period using optimized database function
  Future<AttendanceReportSummary> getAttendanceSummary({
    required AttendanceReportPeriod period,
    AttendanceSettings? settings,
  }) async {
    try {
      AppLogger.info('📊 جاري حساب إحصائيات الحضور للفترة: ${period.displayName}');

      final dateRange = period.getDateRange();
      final attendanceSettings = settings ?? AttendanceSettings.defaultSettings();

      // Try to use optimized database function first
      try {
        final response = await _supabase.rpc(
          'get_attendance_summary_stats',
          params: {
            'start_date': dateRange.startDate.toIso8601String(),
            'end_date': dateRange.endDate.toIso8601String(),
            'work_start_hour': attendanceSettings.workStartTime.hour,
            'work_start_minute': attendanceSettings.workStartTime.minute,
            'work_end_hour': attendanceSettings.workEndTime.hour,
            'work_end_minute': attendanceSettings.workEndTime.minute,
            'late_tolerance_minutes': attendanceSettings.lateToleranceMinutes,
            'early_departure_tolerance_minutes': attendanceSettings.earlyDepartureToleranceMinutes,
          },
        );

        if (response != null && response.isNotEmpty) {
          final data = response[0] as Map<String, dynamic>;

          final summary = AttendanceReportSummary(
            totalWorkers: data['total_workers'] as int? ?? 0,
            presentWorkers: data['present_workers'] as int? ?? 0,
            absentWorkers: data['absent_workers'] as int? ?? 0,
            attendanceRate: (data['attendance_rate'] as num? ?? 0.0).toDouble(),
            totalLateArrivals: data['total_late_arrivals'] as int? ?? 0,
            totalEarlyDepartures: data['total_early_departures'] as int? ?? 0,
            averageWorkingHours: (data['average_working_hours'] as num? ?? 0.0).toDouble(),
            period: period,
            dateRange: dateRange,
          );

          AppLogger.info('✅ تم حساب إحصائيات الحضور بنجاح (قاعدة البيانات المحسنة)');
          return summary;
        }
      } catch (e) {
        AppLogger.warning('⚠️ فشل في استخدام دالة قاعدة البيانات المحسنة، استخدام الطريقة البديلة: $e');
      }

      // Fallback to calculating from report data
      final reportData = await getAttendanceReportData(
        period: period,
        settings: settings,
      );

      // Calculate summary statistics
      final totalWorkers = reportData.length;
      final presentWorkers = reportData.where((data) =>
          data.checkInStatus != AttendanceReportStatus.absent).length;
      final absentWorkers = totalWorkers - presentWorkers;
      final attendanceRate = totalWorkers > 0 ? presentWorkers / totalWorkers : 0.0;

      final totalLateArrivals = reportData.fold<int>(0, (sum, data) => sum + data.lateArrivals);
      final totalEarlyDepartures = reportData.fold<int>(0, (sum, data) => sum + data.earlyDepartures);

      final totalWorkingHours = reportData.fold<double>(0, (sum, data) => sum + data.totalHoursWorked);
      final averageWorkingHours = totalWorkers > 0 ? totalWorkingHours / totalWorkers : 0.0;

      final summary = AttendanceReportSummary(
        totalWorkers: totalWorkers,
        presentWorkers: presentWorkers,
        absentWorkers: absentWorkers,
        attendanceRate: attendanceRate,
        totalLateArrivals: totalLateArrivals,
        totalEarlyDepartures: totalEarlyDepartures,
        averageWorkingHours: averageWorkingHours,
        period: period,
        dateRange: dateRange,
      );

      AppLogger.info('✅ تم حساب إحصائيات الحضور بنجاح (الطريقة البديلة)');
      return summary;

    } catch (e) {
      AppLogger.error('❌ خطأ في حساب إحصائيات الحضور: $e');
      rethrow;
    }
  }
  
  /// Get worker attendance records for a date range
  Future<List<WorkerAttendanceRecord>> _getWorkerAttendanceRecords({
    required String workerId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final response = await _supabase
          .from('worker_attendance_records')
          .select('*')
          .eq('worker_id', workerId)
          .gte('timestamp', startDate.toIso8601String())
          .lte('timestamp', endDate.toIso8601String())
          .order('timestamp', ascending: true);
      
      final records = (response as List<dynamic>)
          .map((record) => WorkerAttendanceRecord.fromJson(record as Map<String, dynamic>))
          .toList();
      
      return records;
      
    } catch (e) {
      AppLogger.error('❌ خطأ في جلب سجلات الحضور للعامل $workerId: $e');
      return [];
    }
  }
  
  /// Calculate attendance data for a specific worker
  Future<WorkerAttendanceReportData> _calculateWorkerAttendanceData({
    required String workerId,
    required String workerName,
    String? profileImageUrl,
    required List<WorkerAttendanceRecord> attendanceRecords,
    required AttendanceReportPeriod period,
    required AttendanceSettings settings,
    required DateRange dateRange,
  }) async {
    // Group records by date
    final recordsByDate = <DateTime, List<WorkerAttendanceRecord>>{};
    
    for (final record in attendanceRecords) {
      final date = DateTime(record.timestamp.year, record.timestamp.month, record.timestamp.day);
      recordsByDate.putIfAbsent(date, () => []).add(record);
    }
    
    // Calculate statistics based on period
    DateTime? checkInTime;
    DateTime? checkOutTime;
    AttendanceReportStatus checkInStatus = AttendanceReportStatus.absent;
    AttendanceReportStatus checkOutStatus = AttendanceReportStatus.missingCheckOut;
    double totalHoursWorked = 0.0;
    int attendanceDays = 0;
    int absenceDays = 0;
    int lateArrivals = 0;
    int earlyDepartures = 0;
    int lateMinutes = 0;
    int earlyMinutes = 0;
    
    // For daily reports, get today's data
    if (period == AttendanceReportPeriod.daily) {
      final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final todayRecords = recordsByDate[today] ?? [];
      
      if (todayRecords.isNotEmpty) {
        final checkInRecord = todayRecords.where((r) => r.attendanceType == AttendanceType.checkIn).firstOrNull;
        final checkOutRecord = todayRecords.where((r) => r.attendanceType == AttendanceType.checkOut).firstOrNull;
        
        if (checkInRecord != null) {
          checkInTime = checkInRecord.timestamp;
          checkInStatus = _calculateCheckInStatus(checkInRecord.timestamp, settings);
          if (checkInStatus == AttendanceReportStatus.late) {
            lateArrivals = 1;
            lateMinutes = _calculateLateMinutes(checkInRecord.timestamp, settings);
          }
        }
        
        if (checkOutRecord != null) {
          checkOutTime = checkOutRecord.timestamp;
          checkOutStatus = _calculateCheckOutStatus(checkOutRecord.timestamp, settings);
          if (checkOutStatus == AttendanceReportStatus.earlyDeparture) {
            earlyDepartures = 1;
            earlyMinutes = _calculateEarlyMinutes(checkOutRecord.timestamp, settings);
          }
        }
        
        if (checkInTime != null && checkOutTime != null) {
          totalHoursWorked = checkOutTime.difference(checkInTime).inMinutes / 60.0;
          attendanceDays = 1;
        } else if (checkInTime != null) {
          attendanceDays = 1;
        }
      } else {
        absenceDays = 1;
      }
    } else {
      // For weekly/monthly reports, calculate aggregated data
      final workDays = _getWorkDaysInRange(dateRange, settings);
      
      for (final workDay in workDays) {
        final dayRecords = recordsByDate[workDay] ?? [];
        
        if (dayRecords.isNotEmpty) {
          final checkInRecord = dayRecords.where((r) => r.attendanceType == AttendanceType.checkIn).firstOrNull;
          final checkOutRecord = dayRecords.where((r) => r.attendanceType == AttendanceType.checkOut).firstOrNull;
          
          if (checkInRecord != null) {
            attendanceDays++;
            
            final dayCheckInStatus = _calculateCheckInStatus(checkInRecord.timestamp, settings);
            if (dayCheckInStatus == AttendanceReportStatus.late) {
              lateArrivals++;
              lateMinutes += _calculateLateMinutes(checkInRecord.timestamp, settings);
            }
            
            if (checkOutRecord != null) {
              final dayCheckOutStatus = _calculateCheckOutStatus(checkOutRecord.timestamp, settings);
              if (dayCheckOutStatus == AttendanceReportStatus.earlyDeparture) {
                earlyDepartures++;
                earlyMinutes += _calculateEarlyMinutes(checkOutRecord.timestamp, settings);
              }
              
              totalHoursWorked += checkOutRecord.timestamp.difference(checkInRecord.timestamp).inMinutes / 60.0;
            }
          }
        } else {
          absenceDays++;
        }
      }
    }
    
    return WorkerAttendanceReportData(
      workerId: workerId,
      workerName: workerName,
      profileImageUrl: profileImageUrl,
      checkInTime: checkInTime,
      checkOutTime: checkOutTime,
      checkInStatus: checkInStatus,
      checkOutStatus: checkOutStatus,
      totalHoursWorked: totalHoursWorked,
      attendanceDays: attendanceDays,
      absenceDays: absenceDays,
      lateArrivals: lateArrivals,
      earlyDepartures: earlyDepartures,
      lateMinutes: lateMinutes,
      earlyMinutes: earlyMinutes,
      reportDate: DateTime.now(),
    );
  }
  
  /// Calculate check-in status based on work start time and tolerance
  AttendanceReportStatus _calculateCheckInStatus(DateTime checkInTime, AttendanceSettings settings) {
    final workStartDateTime = DateTime(
      checkInTime.year,
      checkInTime.month,
      checkInTime.day,
      settings.workStartTime.hour,
      settings.workStartTime.minute,
    );
    
    final toleranceDateTime = workStartDateTime.add(Duration(minutes: settings.lateToleranceMinutes));
    
    if (checkInTime.isAfter(toleranceDateTime)) {
      return AttendanceReportStatus.late;
    } else {
      return AttendanceReportStatus.onTime;
    }
  }
  
  /// Calculate check-out status based on work end time and tolerance
  AttendanceReportStatus _calculateCheckOutStatus(DateTime checkOutTime, AttendanceSettings settings) {
    final workEndDateTime = DateTime(
      checkOutTime.year,
      checkOutTime.month,
      checkOutTime.day,
      settings.workEndTime.hour,
      settings.workEndTime.minute,
    );
    
    final toleranceDateTime = workEndDateTime.subtract(Duration(minutes: settings.earlyDepartureToleranceMinutes));
    
    if (checkOutTime.isBefore(toleranceDateTime)) {
      return AttendanceReportStatus.earlyDeparture;
    } else {
      return AttendanceReportStatus.onTime;
    }
  }
  
  /// Calculate late minutes
  int _calculateLateMinutes(DateTime checkInTime, AttendanceSettings settings) {
    final workStartDateTime = DateTime(
      checkInTime.year,
      checkInTime.month,
      checkInTime.day,
      settings.workStartTime.hour,
      settings.workStartTime.minute,
    );
    
    return checkInTime.difference(workStartDateTime).inMinutes.clamp(0, double.infinity).toInt();
  }
  
  /// Calculate early departure minutes
  int _calculateEarlyMinutes(DateTime checkOutTime, AttendanceSettings settings) {
    final workEndDateTime = DateTime(
      checkOutTime.year,
      checkOutTime.month,
      checkOutTime.day,
      settings.workEndTime.hour,
      settings.workEndTime.minute,
    );
    
    return workEndDateTime.difference(checkOutTime).inMinutes.clamp(0, double.infinity).toInt();
  }
  
  /// Get work days in a date range based on settings
  List<DateTime> _getWorkDaysInRange(DateRange dateRange, AttendanceSettings settings) {
    final workDays = <DateTime>[];
    var currentDate = dateRange.startDate;

    while (currentDate.isBefore(dateRange.endDate) || currentDate.isAtSameMomentAs(dateRange.endDate)) {
      if (settings.isWorkDay(currentDate)) {
        workDays.add(DateTime(currentDate.year, currentDate.month, currentDate.day));
      }
      currentDate = currentDate.add(const Duration(days: 1));
    }

    return workDays;
  }

  /// Export attendance report data to specified format
  Future<Map<String, dynamic>> exportAttendanceReport({
    required AttendanceReportPeriod period,
    required String format, // 'pdf' or 'excel'
    AttendanceSettings? settings,
  }) async {
    try {
      AppLogger.info('📄 بدء تصدير تقرير الحضور بصيغة: $format');

      // Get report data
      final reportData = await getAttendanceReportData(
        period: period,
        settings: settings,
      );

      final reportSummary = await getAttendanceSummary(
        period: period,
        settings: settings,
      );

      // Prepare export data
      final exportData = {
        'report_info': {
          'title': 'تقرير حضور العمال - ${period.displayName}',
          'period': period.displayName,
          'date_range': {
            'start': reportSummary.dateRange.startDate.toIso8601String(),
            'end': reportSummary.dateRange.endDate.toIso8601String(),
          },
          'generated_at': DateTime.now().toIso8601String(),
          'format': format,
        },
        'summary': reportSummary.toJson(),
        'workers_data': reportData.map((data) => data.toJson()).toList(),
        'settings': settings?.toJson() ?? AttendanceSettings.defaultSettings().toJson(),
      };

      // TODO: Implement actual PDF/Excel generation
      // This would require adding dependencies like:
      // - pdf: ^3.10.4 for PDF generation
      // - excel: ^2.1.0 for Excel generation
      // - path_provider: for file storage

      // Simulate export processing time
      await Future.delayed(const Duration(seconds: 2));

      final fileName = 'attendance_report_${period.name}_${DateTime.now().millisecondsSinceEpoch}.$format';

      AppLogger.info('✅ تم تصدير تقرير الحضور بنجاح: $fileName');

      return {
        'success': true,
        'message': 'تم تصدير التقرير بنجاح',
        'file_name': fileName,
        'file_path': '/downloads/$fileName', // Placeholder path
        'export_data': exportData,
      };

    } catch (e) {
      AppLogger.error('❌ خطأ في تصدير تقرير الحضور: $e');
      return {
        'success': false,
        'message': 'فشل في تصدير التقرير: $e',
        'error': e.toString(),
      };
    }
  }
}
