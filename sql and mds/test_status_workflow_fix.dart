import 'package:flutter_test/flutter_test.dart';
import 'package:smartbiztracker_new/constants/warehouse_dispatch_constants.dart';

/// اختبار إصلاح سير عمل حالات طلبات الصرف
/// يتحقق من صحة انتقالات الحالة وفقاً للقواعد المحددة
void main() {
  group('Warehouse Dispatch Status Workflow Tests', () {
    test('should validate correct status transitions', () {
      // اختبار الانتقالات الصحيحة
      
      // من pending
      expect(
        WarehouseDispatchConstants.isValidStatusTransition('pending', 'approved'),
        isTrue,
        reason: 'pending → approved should be valid',
      );
      expect(
        WarehouseDispatchConstants.isValidStatusTransition('pending', 'rejected'),
        isTrue,
        reason: 'pending → rejected should be valid',
      );
      expect(
        WarehouseDispatchConstants.isValidStatusTransition('pending', 'processing'),
        isTrue,
        reason: 'pending → processing should be valid',
      );

      // من approved
      expect(
        WarehouseDispatchConstants.isValidStatusTransition('approved', 'processing'),
        isTrue,
        reason: 'approved → processing should be valid',
      );
      expect(
        WarehouseDispatchConstants.isValidStatusTransition('approved', 'executed'),
        isTrue,
        reason: 'approved → executed should be valid',
      );
      expect(
        WarehouseDispatchConstants.isValidStatusTransition('approved', 'cancelled'),
        isTrue,
        reason: 'approved → cancelled should be valid',
      );

      // من processing
      expect(
        WarehouseDispatchConstants.isValidStatusTransition('processing', 'completed'),
        isTrue,
        reason: 'processing → completed should be valid',
      );
      expect(
        WarehouseDispatchConstants.isValidStatusTransition('processing', 'executed'),
        isTrue,
        reason: 'processing → executed should be valid',
      );
      expect(
        WarehouseDispatchConstants.isValidStatusTransition('processing', 'cancelled'),
        isTrue,
        reason: 'processing → cancelled should be valid',
      );
    });

    test('should reject invalid status transitions', () {
      // اختبار الانتقالات غير الصحيحة
      
      // من pending مباشرة إلى completed (هذا كان السبب في الخطأ)
      expect(
        WarehouseDispatchConstants.isValidStatusTransition('pending', 'completed'),
        isFalse,
        reason: 'pending → completed should be INVALID (this was the bug)',
      );

      // من pending مباشرة إلى executed
      expect(
        WarehouseDispatchConstants.isValidStatusTransition('pending', 'executed'),
        isFalse,
        reason: 'pending → executed should be invalid',
      );

      // من الحالات النهائية
      expect(
        WarehouseDispatchConstants.isValidStatusTransition('completed', 'processing'),
        isFalse,
        reason: 'completed → processing should be invalid (final status)',
      );
      expect(
        WarehouseDispatchConstants.isValidStatusTransition('executed', 'pending'),
        isFalse,
        reason: 'executed → pending should be invalid (final status)',
      );
      expect(
        WarehouseDispatchConstants.isValidStatusTransition('cancelled', 'approved'),
        isFalse,
        reason: 'cancelled → approved should be invalid (final status)',
      );
      expect(
        WarehouseDispatchConstants.isValidStatusTransition('rejected', 'processing'),
        isFalse,
        reason: 'rejected → processing should be invalid (final status)',
      );
    });

    test('should provide correct next possible statuses', () {
      // اختبار الحالات التالية الممكنة
      
      expect(
        WarehouseDispatchConstants.getNextPossibleStatuses('pending'),
        containsAll(['approved', 'rejected', 'processing']),
        reason: 'pending should allow approved, rejected, processing',
      );

      expect(
        WarehouseDispatchConstants.getNextPossibleStatuses('approved'),
        containsAll(['processing', 'executed', 'cancelled']),
        reason: 'approved should allow processing, executed, cancelled',
      );

      expect(
        WarehouseDispatchConstants.getNextPossibleStatuses('processing'),
        containsAll(['completed', 'executed', 'cancelled']),
        reason: 'processing should allow completed, executed, cancelled',
      );

      // الحالات النهائية لا تسمح بأي انتقالات
      expect(
        WarehouseDispatchConstants.getNextPossibleStatuses('completed'),
        isEmpty,
        reason: 'completed is final status - no transitions allowed',
      );
      expect(
        WarehouseDispatchConstants.getNextPossibleStatuses('executed'),
        isEmpty,
        reason: 'executed is final status - no transitions allowed',
      );
      expect(
        WarehouseDispatchConstants.getNextPossibleStatuses('cancelled'),
        isEmpty,
        reason: 'cancelled is final status - no transitions allowed',
      );
      expect(
        WarehouseDispatchConstants.getNextPossibleStatuses('rejected'),
        isEmpty,
        reason: 'rejected is final status - no transitions allowed',
      );
    });

    test('should validate the correct workflow for interactive processing', () {
      // اختبار السير الصحيح للمعالجة التفاعلية
      
      // الخطوة 1: من pending إلى processing (عند فتح الشاشة التفاعلية)
      expect(
        WarehouseDispatchConstants.isValidStatusTransition('pending', 'processing'),
        isTrue,
        reason: 'Step 1: pending → processing when opening interactive screen',
      );

      // الخطوة 2: من processing إلى completed (عند إكمال جميع المنتجات)
      expect(
        WarehouseDispatchConstants.isValidStatusTransition('processing', 'completed'),
        isTrue,
        reason: 'Step 2: processing → completed when all products are processed',
      );

      // التحقق من أن الانتقال المباشر غير مسموح (هذا كان الخطأ الأصلي)
      expect(
        WarehouseDispatchConstants.isValidStatusTransition('pending', 'completed'),
        isFalse,
        reason: 'Direct pending → completed should be invalid (this was the original bug)',
      );
    });

    test('should check if status allows processing', () {
      // اختبار إمكانية المعالجة
      
      expect(
        WarehouseDispatchConstants.canProcess('pending'),
        isTrue,
        reason: 'pending status should allow processing',
      );
      expect(
        WarehouseDispatchConstants.canProcess('approved'),
        isTrue,
        reason: 'approved status should allow processing',
      );
      expect(
        WarehouseDispatchConstants.canProcess('processing'),
        isFalse,
        reason: 'processing status should not allow re-processing',
      );
      expect(
        WarehouseDispatchConstants.canProcess('completed'),
        isFalse,
        reason: 'completed status should not allow processing',
      );
    });

    test('should identify final statuses correctly', () {
      // اختبار تحديد الحالات النهائية
      
      expect(
        WarehouseDispatchConstants.isFinalStatus('completed'),
        isTrue,
        reason: 'completed should be final status',
      );
      expect(
        WarehouseDispatchConstants.isFinalStatus('executed'),
        isTrue,
        reason: 'executed should be final status',
      );
      expect(
        WarehouseDispatchConstants.isFinalStatus('cancelled'),
        isTrue,
        reason: 'cancelled should be final status',
      );
      expect(
        WarehouseDispatchConstants.isFinalStatus('rejected'),
        isTrue,
        reason: 'rejected should be final status',
      );
      expect(
        WarehouseDispatchConstants.isFinalStatus('pending'),
        isFalse,
        reason: 'pending should not be final status',
      );
      expect(
        WarehouseDispatchConstants.isFinalStatus('processing'),
        isFalse,
        reason: 'processing should not be final status',
      );
    });
  });

  group('Status Display Tests', () {
    test('should provide correct Arabic status names', () {
      expect(
        WarehouseDispatchConstants.getStatusDisplayName('pending'),
        equals('في الانتظار'),
      );
      expect(
        WarehouseDispatchConstants.getStatusDisplayName('processing'),
        equals('قيد المعالجة'),
      );
      expect(
        WarehouseDispatchConstants.getStatusDisplayName('completed'),
        equals('مكتمل'),
      );
      expect(
        WarehouseDispatchConstants.getStatusDisplayName('approved'),
        equals('موافق عليه'),
      );
      expect(
        WarehouseDispatchConstants.getStatusDisplayName('rejected'),
        equals('مرفوض'),
      );
      expect(
        WarehouseDispatchConstants.getStatusDisplayName('executed'),
        equals('منفذ'),
      );
      expect(
        WarehouseDispatchConstants.getStatusDisplayName('cancelled'),
        equals('ملغي'),
      );
    });
  });
}
