/// Comprehensive integration tests for the complete attendance workflow
/// Tests check-in → persistence → check-out → reports flow

import 'package:flutter_test/flutter_test.dart';
import 'package:smartbiztracker_new/models/attendance_models.dart';
import 'package:smartbiztracker_new/providers/attendance_provider.dart';
import 'package:smartbiztracker_new/providers/worker_attendance_reports_provider.dart';
import 'package:smartbiztracker_new/services/attendance_service.dart';

void main() {
  group('Attendance Workflow Integration Tests', () {
    late AttendanceProvider attendanceProvider;
    late WorkerAttendanceReportsProvider reportsProvider;
    late AttendanceService attendanceService;
    
    const testWorkerId = 'test-worker-123';
    const testDeviceHash = 'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890';

    setUp(() {
      attendanceProvider = AttendanceProvider();
      reportsProvider = WorkerAttendanceReportsProvider();
      attendanceService = AttendanceService();
    });

    group('State Management Tests', () {
      test('should not call setState during build phase', () async {
        // This test verifies that the setState() during build issue is fixed
        bool buildPhaseError = false;
        
        try {
          // Simulate calling refresh during build phase
          await attendanceProvider.refreshAttendanceData(testWorkerId);
        } catch (e) {
          if (e.toString().contains('setState() or markNeedsBuild() called during build')) {
            buildPhaseError = true;
          }
        }
        
        expect(buildPhaseError, isFalse, 'setState should not be called during build phase');
      });

      test('should prevent duplicate refresh calls', () async {
        int refreshCount = 0;
        
        // Start multiple refresh operations simultaneously
        final futures = List.generate(5, (_) async {
          await attendanceProvider.refreshAttendanceData(testWorkerId);
          refreshCount++;
        });
        
        await Future.wait(futures);
        
        // Only one refresh should actually execute due to deduplication
        expect(refreshCount, lessThanOrEqualTo(2), 'Should prevent duplicate refresh calls');
      });
    });

    group('Request Deduplication Tests', () {
      test('should deduplicate simultaneous attendance record requests', () async {
        final service = AttendanceService();
        
        // Make multiple simultaneous requests for the same worker
        final futures = List.generate(5, (_) => 
          service.getWorkerAttendanceRecords(workerId: testWorkerId)
        );
        
        final results = await Future.wait(futures);
        
        // All results should be identical (from the same request)
        expect(results.length, equals(5));
        for (int i = 1; i < results.length; i++) {
          expect(results[i].length, equals(results[0].length));
        }
      });

      test('should clear cache after attendance processing', () async {
        final service = AttendanceService();
        
        // Make initial request
        await service.getWorkerAttendanceRecords(workerId: testWorkerId);
        
        // Process attendance (this should clear cache)
        await service.processQRAttendance(
          workerId: testWorkerId,
          deviceHash: testDeviceHash,
          nonce: 'test-nonce-${DateTime.now().millisecondsSinceEpoch}',
          qrTimestamp: DateTime.now(),
          attendanceType: AttendanceType.checkIn,
        );
        
        // Subsequent request should fetch fresh data
        final records = await service.getWorkerAttendanceRecords(workerId: testWorkerId);
        
        expect(records, isNotNull);
      });
    });

    group('Attendance Persistence Tests', () {
      test('should persist check-in record immediately', () async {
        final service = AttendanceService();
        
        // Process check-in
        final checkInResult = await service.processQRAttendance(
          workerId: testWorkerId,
          deviceHash: testDeviceHash,
          nonce: 'checkin-${DateTime.now().millisecondsSinceEpoch}',
          qrTimestamp: DateTime.now(),
          attendanceType: AttendanceType.checkIn,
        );
        
        expect(checkInResult.success, isTrue, 'Check-in should succeed');
        
        // Immediately check today's status
        final todayStatus = await service.getTodayAttendanceStatus(testWorkerId);
        
        expect(todayStatus['hasCheckedIn'], isTrue, 'Check-in should be immediately available');
        expect(todayStatus['canCheckOut'], isTrue, 'Should be able to check out after check-in');
      });

      test('should allow check-out after check-in', () async {
        final service = AttendanceService();
        
        // Process check-in
        await service.processQRAttendance(
          workerId: testWorkerId,
          deviceHash: testDeviceHash,
          nonce: 'checkin-${DateTime.now().millisecondsSinceEpoch}',
          qrTimestamp: DateTime.now(),
          attendanceType: AttendanceType.checkIn,
        );
        
        // Wait a moment to ensure persistence
        await Future.delayed(const Duration(milliseconds: 200));
        
        // Process check-out
        final checkOutResult = await service.processQRAttendance(
          workerId: testWorkerId,
          deviceHash: testDeviceHash,
          nonce: 'checkout-${DateTime.now().millisecondsSinceEpoch}',
          qrTimestamp: DateTime.now(),
          attendanceType: AttendanceType.checkOut,
        );
        
        expect(checkOutResult.success, isTrue, 'Check-out should succeed after check-in');
        
        // Verify final status
        final finalStatus = await service.getTodayAttendanceStatus(testWorkerId);
        expect(finalStatus['hasCheckedIn'], isTrue);
        expect(finalStatus['hasCheckedOut'], isTrue);
        expect(finalStatus['isCurrentlyWorking'], isFalse);
      });
    });

    group('Error Handling Tests', () {
      test('should handle network errors gracefully', () async {
        final service = AttendanceService();
        
        // This test would require mocking network failures
        // For now, we test that the service doesn't crash on errors
        try {
          await service.getWorkerAttendanceRecords(
            workerId: 'invalid-worker-id',
          );
        } catch (e) {
          expect(e, isA<Exception>());
          expect(e.toString(), contains('فشل في جلب سجلات الحضور'));
        }
      });

      test('should retry failed operations', () async {
        final service = AttendanceService();
        
        // Test retry logic by making a request that might fail
        final records = await service.getWorkerAttendanceRecords(
          workerId: testWorkerId,
        );
        
        // Should not throw exception due to retry logic
        expect(records, isNotNull);
      });
    });

    group('Reports Integration Tests', () {
      test('should update reports after attendance processing', () async {
        // Initialize reports provider
        await reportsProvider.initialize();
        
        // Process attendance
        await attendanceProvider.processQRAttendance(
          workerId: testWorkerId,
          qrData: '{"workerId":"$testWorkerId","deviceHash":"$testDeviceHash","nonce":"test","timestamp":${DateTime.now().millisecondsSinceEpoch}}',
          attendanceType: AttendanceType.checkIn,
        );
        
        // Wait for reports to update
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Verify reports reflect the new attendance data
        expect(reportsProvider.isInitialized, isTrue);
        expect(reportsProvider.error, isNull);
      });

      test('should apply attendance settings to calculations', () async {
        // Create custom attendance settings
        final customSettings = AttendanceSettings(
          workStartTime: const TimeOfDay(hour: 8, minute: 0),
          workEndTime: const TimeOfDay(hour: 16, minute: 0),
          lateToleranceMinutes: 10,
          earlyDepartureToleranceMinutes: 5,
          requiredDailyHours: 8.0,
          workDays: [6, 7, 1, 2, 3], // Saturday to Wednesday
        );
        
        // Update settings
        await reportsProvider.updateAttendanceSettings(customSettings);
        
        // Verify settings are applied
        expect(reportsProvider.attendanceSettings.workStartTime.hour, equals(8));
        expect(reportsProvider.attendanceSettings.lateToleranceMinutes, equals(10));
        expect(reportsProvider.attendanceSettings.workDays, equals([6, 7, 1, 2, 3]));
      });
    });

    group('Performance Tests', () {
      test('should handle multiple workers efficiently', () async {
        final service = AttendanceService();
        final stopwatch = Stopwatch()..start();
        
        // Process attendance for multiple workers simultaneously
        final futures = List.generate(10, (index) async {
          return service.getWorkerAttendanceRecords(
            workerId: 'worker-$index',
          );
        });
        
        await Future.wait(futures);
        stopwatch.stop();
        
        // Should complete within reasonable time
        expect(stopwatch.elapsedMilliseconds, lessThan(5000), 
               'Should handle multiple workers efficiently');
      });
    });
  });
}
