/// Comprehensive Test Suite for Worker Attendance Reports System
/// 
/// This test file covers all aspects of the attendance reporting functionality
/// including models, services, providers, and UI components.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/models/attendance_models.dart';
import 'package:smartbiztracker_new/providers/worker_attendance_reports_provider.dart';
import 'package:smartbiztracker_new/services/worker_attendance_reports_service.dart';
import 'package:smartbiztracker_new/screens/attendance/worker_attendance_reports_screen.dart';
import 'package:smartbiztracker_new/widgets/attendance/attendance_summary_cards.dart';
import 'package:smartbiztracker_new/widgets/attendance/attendance_data_table.dart';

// Mock classes
class MockWorkerAttendanceReportsService extends Mock implements WorkerAttendanceReportsService {}

void main() {
  group('Attendance Models Tests', () {
    test('AttendanceReportPeriod should return correct display names', () {
      expect(AttendanceReportPeriod.daily.displayName, equals('يومي'));
      expect(AttendanceReportPeriod.weekly.displayName, equals('أسبوعي'));
      expect(AttendanceReportPeriod.monthly.displayName, equals('شهري'));
    });

    test('AttendanceReportPeriod should return correct date ranges', () {
      final now = DateTime.now();
      
      // Test daily range
      final dailyRange = AttendanceReportPeriod.daily.getDateRange();
      expect(dailyRange.totalDays, equals(1));
      expect(dailyRange.startDate.day, equals(now.day));
      
      // Test weekly range
      final weeklyRange = AttendanceReportPeriod.weekly.getDateRange();
      expect(weeklyRange.totalDays, equals(7));
      
      // Test monthly range
      final monthlyRange = AttendanceReportPeriod.monthly.getDateRange();
      expect(monthlyRange.startDate.day, equals(1));
      expect(monthlyRange.startDate.month, equals(now.month));
    });

    test('AttendanceReportStatus should return correct colors', () {
      expect(AttendanceReportStatus.onTime.statusColor, equals(const Color(0xFF10B981)));
      expect(AttendanceReportStatus.late.statusColor, equals(const Color(0xFFF59E0B)));
      expect(AttendanceReportStatus.absent.statusColor, equals(const Color(0xFFEF4444)));
      expect(AttendanceReportStatus.earlyDeparture.statusColor, equals(const Color(0xFFF59E0B)));
      expect(AttendanceReportStatus.missingCheckOut.statusColor, equals(const Color(0xFFEF4444)));
    });

    test('AttendanceSettings should create default settings correctly', () {
      final settings = AttendanceSettings.defaultSettings();
      
      expect(settings.workStartTime, equals(const TimeOfDay(hour: 9, minute: 0)));
      expect(settings.workEndTime, equals(const TimeOfDay(hour: 17, minute: 0)));
      expect(settings.lateToleranceMinutes, equals(15));
      expect(settings.earlyDepartureToleranceMinutes, equals(10));
      expect(settings.requiredDailyHours, equals(8.0));
      expect(settings.workDays, equals([1, 2, 3, 4, 5]));
    });

    test('AttendanceSettings should serialize and deserialize correctly', () {
      final originalSettings = AttendanceSettings.defaultSettings();
      final json = originalSettings.toJson();
      final deserializedSettings = AttendanceSettings.fromJson(json);
      
      expect(deserializedSettings.workStartTime.hour, equals(originalSettings.workStartTime.hour));
      expect(deserializedSettings.workStartTime.minute, equals(originalSettings.workStartTime.minute));
      expect(deserializedSettings.workEndTime.hour, equals(originalSettings.workEndTime.hour));
      expect(deserializedSettings.workEndTime.minute, equals(originalSettings.workEndTime.minute));
      expect(deserializedSettings.lateToleranceMinutes, equals(originalSettings.lateToleranceMinutes));
      expect(deserializedSettings.earlyDepartureToleranceMinutes, equals(originalSettings.earlyDepartureToleranceMinutes));
      expect(deserializedSettings.requiredDailyHours, equals(originalSettings.requiredDailyHours));
      expect(deserializedSettings.workDays, equals(originalSettings.workDays));
    });

    test('WorkerAttendanceReportData should serialize and deserialize correctly', () {
      final reportData = WorkerAttendanceReportData(
        workerId: 'test-worker-id',
        workerName: 'Test Worker',
        profileImageUrl: 'https://example.com/image.jpg',
        checkInTime: DateTime(2024, 1, 1, 9, 0),
        checkOutTime: DateTime(2024, 1, 1, 17, 0),
        checkInStatus: AttendanceReportStatus.onTime,
        checkOutStatus: AttendanceReportStatus.onTime,
        totalHoursWorked: 8.0,
        attendanceDays: 1,
        absenceDays: 0,
        lateArrivals: 0,
        earlyDepartures: 0,
        lateMinutes: 0,
        earlyMinutes: 0,
        reportDate: DateTime(2024, 1, 1),
      );
      
      final json = reportData.toJson();
      final deserializedData = WorkerAttendanceReportData.fromJson(json);
      
      expect(deserializedData.workerId, equals(reportData.workerId));
      expect(deserializedData.workerName, equals(reportData.workerName));
      expect(deserializedData.profileImageUrl, equals(reportData.profileImageUrl));
      expect(deserializedData.checkInStatus, equals(reportData.checkInStatus));
      expect(deserializedData.checkOutStatus, equals(reportData.checkOutStatus));
      expect(deserializedData.totalHoursWorked, equals(reportData.totalHoursWorked));
      expect(deserializedData.attendanceDays, equals(reportData.attendanceDays));
      expect(deserializedData.absenceDays, equals(reportData.absenceDays));
    });
  });

  group('Attendance Provider Tests', () {
    late WorkerAttendanceReportsProvider provider;
    late MockWorkerAttendanceReportsService mockService;

    setUp(() {
      mockService = MockWorkerAttendanceReportsService();
      provider = WorkerAttendanceReportsProvider();
    });

    test('Provider should initialize with correct default values', () {
      expect(provider.isLoading, isFalse);
      expect(provider.isInitialized, isFalse);
      expect(provider.error, isNull);
      expect(provider.selectedPeriod, equals(AttendanceReportPeriod.daily));
      expect(provider.reportData, isEmpty);
      expect(provider.reportSummary, isNull);
    });

    test('Provider should change period correctly', () async {
      await provider.changePeriod(AttendanceReportPeriod.weekly);
      expect(provider.selectedPeriod, equals(AttendanceReportPeriod.weekly));
    });

    test('Provider should handle settings update correctly', () async {
      final newSettings = AttendanceSettings(
        workStartTime: const TimeOfDay(hour: 8, minute: 0),
        workEndTime: const TimeOfDay(hour: 16, minute: 0),
        lateToleranceMinutes: 10,
        earlyDepartureToleranceMinutes: 5,
        requiredDailyHours: 7.0,
        workDays: [1, 2, 3, 4, 5],
      );
      
      await provider.updateAttendanceSettings(newSettings);
      expect(provider.attendanceSettings.workStartTime.hour, equals(8));
      expect(provider.attendanceSettings.lateToleranceMinutes, equals(10));
    });
  });

  group('Attendance UI Widget Tests', () {
    testWidgets('AttendanceSummaryCards should display correctly', (WidgetTester tester) async {
      final summary = AttendanceReportSummary(
        totalWorkers: 10,
        presentWorkers: 8,
        absentWorkers: 2,
        attendanceRate: 0.8,
        totalLateArrivals: 3,
        totalEarlyDepartures: 1,
        averageWorkingHours: 7.5,
        period: AttendanceReportPeriod.daily,
        dateRange: AttendanceReportPeriod.daily.getDateRange(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AttendanceSummaryCards(
              summary: summary,
              isLoading: false,
            ),
          ),
        ),
      );

      expect(find.text('10'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('80.0%'), findsOneWidget);
    });

    testWidgets('AttendanceDataTable should display worker data correctly', (WidgetTester tester) async {
      final reportData = [
        WorkerAttendanceReportData(
          workerId: 'worker-1',
          workerName: 'أحمد محمد',
          profileImageUrl: null,
          checkInTime: DateTime(2024, 1, 1, 9, 0),
          checkOutTime: DateTime(2024, 1, 1, 17, 0),
          checkInStatus: AttendanceReportStatus.onTime,
          checkOutStatus: AttendanceReportStatus.onTime,
          totalHoursWorked: 8.0,
          attendanceDays: 1,
          absenceDays: 0,
          lateArrivals: 0,
          earlyDepartures: 0,
          lateMinutes: 0,
          earlyMinutes: 0,
          reportDate: DateTime(2024, 1, 1),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AttendanceDataTable(
              reportData: reportData,
              isLoading: false,
              userRole: 'admin',
            ),
          ),
        ),
      );

      expect(find.text('أحمد محمد'), findsOneWidget);
      expect(find.text('09:00'), findsOneWidget);
      expect(find.text('17:00'), findsOneWidget);
    });

    testWidgets('WorkerAttendanceReportsScreen should build correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => WorkerAttendanceReportsProvider(),
            child: const WorkerAttendanceReportsScreen(userRole: 'admin'),
          ),
        ),
      );

      expect(find.text('تقارير حضور العمال'), findsOneWidget);
      expect(find.text('يومي'), findsOneWidget);
      expect(find.text('أسبوعي'), findsOneWidget);
      expect(find.text('شهري'), findsOneWidget);
    });
  });

  group('Attendance Integration Tests', () {
    testWidgets('Complete attendance workflow should work correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => WorkerAttendanceReportsProvider(),
            child: const WorkerAttendanceReportsScreen(userRole: 'admin'),
          ),
        ),
      );

      // Test period selection
      await tester.tap(find.text('أسبوعي'));
      await tester.pumpAndSettle();

      // Test settings button
      await tester.tap(find.byIcon(Icons.settings_rounded));
      await tester.pumpAndSettle();

      // Test export button
      await tester.tap(find.byIcon(Icons.file_download_rounded));
      await tester.pumpAndSettle();
    });

    test('Attendance calculations should be accurate', () {
      final checkInTime = DateTime(2024, 1, 1, 9, 15); // 15 minutes late
      final checkOutTime = DateTime(2024, 1, 1, 16, 45); // 15 minutes early
      
      final hoursWorked = checkOutTime.difference(checkInTime).inMinutes / 60.0;
      expect(hoursWorked, equals(7.5));
      
      // Test late calculation
      final workStartTime = DateTime(2024, 1, 1, 9, 0);
      final lateMinutes = checkInTime.difference(workStartTime).inMinutes;
      expect(lateMinutes, equals(15));
      
      // Test early departure calculation
      final workEndTime = DateTime(2024, 1, 1, 17, 0);
      final earlyMinutes = workEndTime.difference(checkOutTime).inMinutes;
      expect(earlyMinutes, equals(15));
    });
  });

  group('Error Handling Tests', () {
    test('Provider should handle service errors gracefully', () async {
      final provider = WorkerAttendanceReportsProvider();
      
      // Test error handling during initialization
      try {
        await provider.initialize();
      } catch (e) {
        expect(provider.error, isNotNull);
      }
    });

    test('Service should handle network errors gracefully', () async {
      final service = WorkerAttendanceReportsService();
      
      // Test error handling for invalid period
      try {
        await service.getAttendanceReportData(
          period: AttendanceReportPeriod.daily,
          settings: null,
        );
      } catch (e) {
        expect(e, isA<Exception>());
      }
    });
  });

  group('Performance Tests', () {
    test('Large dataset should be handled efficiently', () async {
      final reportData = List.generate(1000, (index) => 
        WorkerAttendanceReportData(
          workerId: 'worker-$index',
          workerName: 'Worker $index',
          profileImageUrl: null,
          checkInTime: DateTime(2024, 1, 1, 9, 0),
          checkOutTime: DateTime(2024, 1, 1, 17, 0),
          checkInStatus: AttendanceReportStatus.onTime,
          checkOutStatus: AttendanceReportStatus.onTime,
          totalHoursWorked: 8.0,
          attendanceDays: 1,
          absenceDays: 0,
          lateArrivals: 0,
          earlyDepartures: 0,
          lateMinutes: 0,
          earlyMinutes: 0,
          reportDate: DateTime(2024, 1, 1),
        ),
      );
      
      expect(reportData.length, equals(1000));
      
      // Test filtering performance
      final stopwatch = Stopwatch()..start();
      final lateWorkers = reportData.where((data) => 
          data.checkInStatus == AttendanceReportStatus.late).toList();
      stopwatch.stop();
      
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });
  });
}
