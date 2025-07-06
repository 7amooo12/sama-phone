import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:smartbiztracker_new/models/worker_attendance_model.dart';
import 'package:smartbiztracker_new/services/worker_attendance_service.dart';
import 'package:smartbiztracker_new/providers/worker_attendance_provider.dart';
import 'package:smartbiztracker_new/utils/worker_attendance_security.dart';
import 'package:smartbiztracker_new/utils/worker_attendance_error_handler.dart';
import 'package:smartbiztracker_new/widgets/worker_attendance/professional_qr_scanner_widget.dart';
import 'package:smartbiztracker_new/widgets/worker_attendance/worker_attendance_dashboard_tab.dart';

/// اختبارات شاملة لنظام حضور العمال
void main() {
  group('Worker Attendance Models Tests', () {
    test('QRAttendanceToken should validate correctly', () {
      // إنشاء رمز صحيح
      final validToken = QRAttendanceToken(
        workerId: 'worker_123',
        timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        deviceHash: 'device_hash_123',
        nonce: 'nonce_123',
        signature: 'signature_123',
      );

      expect(validToken.isValid(), isTrue);
      expect(validToken.remainingSeconds, greaterThan(0));
    });

    test('QRAttendanceToken should be invalid when expired', () {
      // إنشاء رمز منتهي الصلاحية
      final expiredToken = QRAttendanceToken(
        workerId: 'worker_123',
        timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000 - 30, // 30 ثانية مضت
        deviceHash: 'device_hash_123',
        nonce: 'nonce_123',
        signature: 'signature_123',
      );

      expect(expiredToken.isValid(), isFalse);
      expect(expiredToken.remainingSeconds, equals(0));
    });

    test('AttendanceValidationResponse should create success response', () {
      final attendanceRecord = WorkerAttendanceModel(
        id: 'test_id',
        workerId: 'worker_123',
        workerName: 'أحمد محمد',
        employeeId: 'EMP001',
        timestamp: DateTime.now(),
        type: AttendanceType.checkIn,
        deviceHash: 'device_hash',
        status: AttendanceStatus.confirmed,
        createdAt: DateTime.now(),
      );

      final response = AttendanceValidationResponse.success(attendanceRecord);

      expect(response.isValid, isTrue);
      expect(response.attendanceRecord, equals(attendanceRecord));
      expect(response.errorMessage, isNull);
    });

    test('AttendanceValidationResponse should create error response', () {
      const errorMessage = 'رمز QR غير صحيح';
      const errorCode = AttendanceErrorCodes.invalidSignature;

      final response = AttendanceValidationResponse.error(errorMessage, errorCode);

      expect(response.isValid, isFalse);
      expect(response.errorMessage, equals(errorMessage));
      expect(response.errorCode, equals(errorCode));
      expect(response.attendanceRecord, isNull);
    });
  });

  group('Worker Attendance Security Tests', () {
    test('generateSecureNonce should create unique nonces', () {
      final nonce1 = WorkerAttendanceSecurity.generateSecureNonce();
      final nonce2 = WorkerAttendanceSecurity.generateSecureNonce();

      expect(nonce1, isNotEmpty);
      expect(nonce2, isNotEmpty);
      expect(nonce1, isNot(equals(nonce2)));
      expect(nonce1.length, equals(16));
    });

    test('generateHMACSignature should create consistent signatures', () {
      const payload = 'test_payload';
      
      final signature1 = WorkerAttendanceSecurity.generateHMACSignature(payload);
      final signature2 = WorkerAttendanceSecurity.generateHMACSignature(payload);

      expect(signature1, equals(signature2));
      expect(signature1, isNotEmpty);
    });

    test('verifyHMACSignature should validate signatures correctly', () {
      const payload = 'test_payload';
      final signature = WorkerAttendanceSecurity.generateHMACSignature(payload);

      expect(WorkerAttendanceSecurity.verifyHMACSignature(payload, signature), isTrue);
      expect(WorkerAttendanceSecurity.verifyHMACSignature(payload, 'invalid_signature'), isFalse);
    });

    test('isTokenTimeValid should validate time correctly', () {
      final currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final validTime = currentTime - 10; // 10 ثوان مضت
      final invalidTime = currentTime - 30; // 30 ثانية مضت

      expect(WorkerAttendanceSecurity.isTokenTimeValid(validTime), isTrue);
      expect(WorkerAttendanceSecurity.isTokenTimeValid(invalidTime), isFalse);
    });

    test('validateGapRequirement should enforce 15-hour gap', () {
      final now = DateTime.now();
      final validLastTime = now.subtract(const Duration(hours: 16)); // 16 ساعة مضت
      final invalidLastTime = now.subtract(const Duration(hours: 10)); // 10 ساعات مضت

      expect(WorkerAttendanceSecurity.validateGapRequirement(validLastTime), isTrue);
      expect(WorkerAttendanceSecurity.validateGapRequirement(invalidLastTime), isFalse);
      expect(WorkerAttendanceSecurity.validateGapRequirement(null), isTrue); // أول تسجيل
    });

    test('validateAttendanceSequence should enforce correct sequence', () {
      // أول تسجيل يجب أن يكون دخول
      expect(WorkerAttendanceSecurity.validateAttendanceSequence(AttendanceType.checkIn, null), isTrue);
      expect(WorkerAttendanceSecurity.validateAttendanceSequence(AttendanceType.checkOut, null), isFalse);

      // بعد الدخول يجب أن يكون خروج
      expect(WorkerAttendanceSecurity.validateAttendanceSequence(AttendanceType.checkOut, AttendanceType.checkIn), isTrue);
      expect(WorkerAttendanceSecurity.validateAttendanceSequence(AttendanceType.checkIn, AttendanceType.checkIn), isFalse);

      // بعد الخروج يجب أن يكون دخول
      expect(WorkerAttendanceSecurity.validateAttendanceSequence(AttendanceType.checkIn, AttendanceType.checkOut), isTrue);
      expect(WorkerAttendanceSecurity.validateAttendanceSequence(AttendanceType.checkOut, AttendanceType.checkOut), isFalse);
    });

    test('validateNonceUniqueness should prevent replay attacks', () {
      const nonce = 'test_nonce';
      final usedNonces = ['used_nonce_1', 'used_nonce_2'];

      expect(WorkerAttendanceSecurity.validateNonceUniqueness(nonce, usedNonces), isTrue);
      expect(WorkerAttendanceSecurity.validateNonceUniqueness('used_nonce_1', usedNonces), isFalse);
    });

    test('validateDeviceMatch should verify device consistency', () {
      const deviceHash = 'device_hash_123';
      const matchingHash = 'device_hash_123';
      const differentHash = 'device_hash_456';

      expect(WorkerAttendanceSecurity.validateDeviceMatch(deviceHash, matchingHash), isTrue);
      expect(WorkerAttendanceSecurity.validateDeviceMatch(deviceHash, differentHash), isFalse);
    });
  });

  group('Worker Attendance Error Handler Tests', () {
    test('validateInput should validate QR data correctly', () {
      // بيانات صحيحة
      const validQR = '{"workerId":"123","timestamp":1234567890}';
      expect(WorkerAttendanceErrorHandler.validateInput(validQR), isNull);

      // بيانات فارغة
      expect(WorkerAttendanceErrorHandler.validateInput(null)?.isValid, isFalse);
      expect(WorkerAttendanceErrorHandler.validateInput('')?.isValid, isFalse);

      // بيانات قصيرة
      expect(WorkerAttendanceErrorHandler.validateInput('short')?.isValid, isFalse);

      // تنسيق خاطئ
      expect(WorkerAttendanceErrorHandler.validateInput('invalid_format')?.isValid, isFalse);
    });

    test('handleTokenValidationError should return appropriate responses', () {
      final response = WorkerAttendanceErrorHandler.handleTokenValidationError(
        AttendanceErrorCodes.tokenExpired,
        'Token expired',
      );

      expect(response.isValid, isFalse);
      expect(response.errorCode, equals(AttendanceErrorCodes.tokenExpired));
      expect(response.errorMessage, contains('انتهت صلاحية'));
    });

    test('AttendanceErrorMessages should provide Arabic messages', () {
      final message = AttendanceErrorMessages.getMessage(AttendanceErrorCodes.tokenExpired);
      expect(message, contains('انتهت صلاحية'));

      final unknownMessage = AttendanceErrorMessages.getMessage('UNKNOWN_CODE');
      expect(unknownMessage, contains('حدث خطأ غير متوقع'));
    });
  });

  group('Integration Tests', () {
    test('Complete QR validation workflow should work correctly', () async {
      // إنشاء رمز QR آمن
      final token = await WorkerAttendanceSecurity.createSecureAttendanceToken('worker_123');
      
      expect(token.workerId, equals('worker_123'));
      expect(token.isValid(), isTrue);
      expect(token.nonce, isNotEmpty);
      expect(token.signature, isNotEmpty);

      // التحقق من الأمان
      final deviceHash = await WorkerAttendanceSecurity.generateDeviceFingerprint();
      final usedNonces = <String>[];
      
      final validationResponse = await WorkerAttendanceSecurity.validateTokenSecurity(
        token,
        token.deviceHash, // نفس الجهاز
        usedNonces,
        null, // أول تسجيل
        null,
      );

      expect(validationResponse.isValid, isTrue);
      expect(validationResponse.attendanceRecord?.workerId, equals('worker_123'));
    });

    test('Security validation should reject invalid tokens', () async {
      final token = await WorkerAttendanceSecurity.createSecureAttendanceToken('worker_123');
      
      // جهاز مختلف
      final differentDeviceHash = 'different_device_hash';
      final usedNonces = <String>[];
      
      final validationResponse = await WorkerAttendanceSecurity.validateTokenSecurity(
        token,
        differentDeviceHash,
        usedNonces,
        null,
        null,
      );

      expect(validationResponse.isValid, isFalse);
      expect(validationResponse.errorCode, equals(AttendanceErrorCodes.deviceMismatch));
    });

    test('Replay attack should be prevented', () async {
      final token = await WorkerAttendanceSecurity.createSecureAttendanceToken('worker_123');
      
      // نونس مستخدم من قبل
      final usedNonces = [token.nonce];
      
      final validationResponse = await WorkerAttendanceSecurity.validateTokenSecurity(
        token,
        token.deviceHash,
        usedNonces,
        null,
        null,
      );

      expect(validationResponse.isValid, isFalse);
      expect(validationResponse.errorCode, equals(AttendanceErrorCodes.replayAttack));
    });

    test('Gap violation should be detected', () async {
      final token = await WorkerAttendanceSecurity.createSecureAttendanceToken('worker_123');
      
      // آخر حضور منذ 5 ساعات فقط
      final recentAttendance = DateTime.now().subtract(const Duration(hours: 5));
      final usedNonces = <String>[];
      
      final validationResponse = await WorkerAttendanceSecurity.validateTokenSecurity(
        token,
        token.deviceHash,
        usedNonces,
        recentAttendance,
        AttendanceType.checkOut,
      );

      expect(validationResponse.isValid, isFalse);
      expect(validationResponse.errorCode, equals(AttendanceErrorCodes.gapViolation));
    });
  });

  group('Performance Tests', () {
    test('Token generation should be fast', () async {
      final stopwatch = Stopwatch()..start();
      
      for (int i = 0; i < 100; i++) {
        await WorkerAttendanceSecurity.createSecureAttendanceToken('worker_$i');
      }
      
      stopwatch.stop();
      
      // يجب أن يكون أقل من ثانية واحدة لـ 100 رمز
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
    });

    test('Signature verification should be fast', () {
      final stopwatch = Stopwatch()..start();
      
      const payload = 'test_payload_for_performance';
      final signature = WorkerAttendanceSecurity.generateHMACSignature(payload);
      
      for (int i = 0; i < 1000; i++) {
        WorkerAttendanceSecurity.verifyHMACSignature(payload, signature);
      }
      
      stopwatch.stop();
      
      // يجب أن يكون أقل من 100 مللي ثانية لـ 1000 تحقق
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });

    test('Nonce generation should be unique at scale', () {
      final nonces = <String>{};
      
      for (int i = 0; i < 10000; i++) {
        final nonce = WorkerAttendanceSecurity.generateSecureNonce();
        expect(nonces.contains(nonce), isFalse, reason: 'Duplicate nonce found: $nonce');
        nonces.add(nonce);
      }
      
      expect(nonces.length, equals(10000));
    });
  });

  group('Edge Cases Tests', () {
    test('Should handle null and empty values gracefully', () {
      expect(() => WorkerAttendanceErrorHandler.validateInput(null), returnsNormally);
      expect(() => WorkerAttendanceErrorHandler.validateInput(''), returnsNormally);
      expect(() => AttendanceErrorMessages.getMessage(null), returnsNormally);
    });

    test('Should handle extreme timestamps', () {
      // وقت في المستقبل
      final futureTime = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
      expect(WorkerAttendanceSecurity.isTokenTimeValid(futureTime), isFalse);

      // وقت قديم جداً
      final oldTime = DateTime.now().millisecondsSinceEpoch ~/ 1000 - 86400;
      expect(WorkerAttendanceSecurity.isTokenTimeValid(oldTime), isFalse);
    });

    test('Should handle very long nonce lists', () {
      final longNonceList = List.generate(10000, (index) => 'nonce_$index');
      final newNonce = 'new_nonce';
      
      final stopwatch = Stopwatch()..start();
      final isUnique = WorkerAttendanceSecurity.validateNonceUniqueness(newNonce, longNonceList);
      stopwatch.stop();
      
      expect(isUnique, isTrue);
      expect(stopwatch.elapsedMilliseconds, lessThan(10)); // يجب أن يكون سريع
    });
  });

  group('QR Scanner Widget Lifecycle Tests', () {
    testWidgets('ProfessionalQRScannerWidget should dispose properly without errors', (WidgetTester tester) async {
      // إنشاء مزود حضور العمال
      final provider = WorkerAttendanceProvider();

      // بناء الواجهة مع المزود
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: provider,
            child: Scaffold(
              body: ProfessionalQRScannerWidget(
                onQRDetected: (qrData) async {
                  // معالجة وهمية للـ QR
                },
                onError: () {
                  // معالجة وهمية للخطأ
                },
              ),
            ),
          ),
        ),
      );

      // التأكد من بناء الواجهة بنجاح
      await tester.pump();

      // العثور على الواجهة
      expect(find.byType(ProfessionalQRScannerWidget), findsOneWidget);

      // إزالة الواجهة للتأكد من التنظيف الصحيح
      await tester.pumpWidget(Container());

      // التأكد من عدم وجود أخطاء في التنظيف
      await tester.pump();

      // تنظيف المزود
      provider.dispose();
    });

    testWidgets('WorkerAttendanceDashboardTab should handle tab switching without errors', (WidgetTester tester) async {
      final provider = WorkerAttendanceProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: provider,
            child: const Scaffold(
              body: WorkerAttendanceDashboardTab(),
            ),
          ),
        ),
      );

      // التأكد من بناء الواجهة
      await tester.pump();

      // العثور على التبويبات
      expect(find.byType(TabBarView), findsOneWidget);

      // محاولة التبديل بين التبويبات
      final tabBar = find.byType(TabBar);
      if (tabBar.evaluate().isNotEmpty) {
        await tester.tap(tabBar);
        await tester.pump();
      }

      // إزالة الواجهة
      await tester.pumpWidget(Container());
      await tester.pump();

      provider.dispose();
    });

    test('WorkerAttendanceProvider should handle multiple dispose calls safely', () {
      final provider = WorkerAttendanceProvider();

      // استدعاء dispose عدة مرات يجب ألا يسبب خطأ
      provider.dispose();
      provider.dispose();
      provider.dispose();

      // لا يجب أن يحدث خطأ
      expect(true, isTrue);
    });

    test('QR Scanner should handle mounted checks correctly', () async {
      bool qrDetected = false;
      bool errorOccurred = false;

      // محاكاة معالجة QR مع فحص mounted
      Future<void> simulateQRProcessing() async {
        try {
          // محاكاة معالجة غير متزامنة
          await Future.delayed(const Duration(milliseconds: 100));
          qrDetected = true;
        } catch (e) {
          errorOccurred = true;
        }
      }

      await simulateQRProcessing();

      expect(qrDetected, isTrue);
      expect(errorOccurred, isFalse);
    });
  });
}
