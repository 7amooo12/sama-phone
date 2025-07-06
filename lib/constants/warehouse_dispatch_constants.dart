/// ثوابت طلبات صرف المخزون
/// Constants for warehouse dispatch requests

class WarehouseDispatchConstants {
  // Status values - must match database constraint
  static const String statusPending = 'pending';
  static const String statusApproved = 'approved';
  static const String statusRejected = 'rejected';
  static const String statusExecuted = 'executed';
  static const String statusCancelled = 'cancelled';
  static const String statusProcessing = 'processing';
  static const String statusCompleted = 'completed';

  // Type values
  static const String typeWithdrawal = 'withdrawal';
  static const String typeTransfer = 'transfer';
  static const String typeAdjustment = 'adjustment';
  static const String typeReturn = 'return';

  // All valid status values
  static const List<String> validStatusValues = [
    statusPending,
    statusApproved,
    statusRejected,
    statusExecuted,
    statusCancelled,
    statusProcessing,
    statusCompleted,
  ];

  // All valid type values
  static const List<String> validTypeValues = [
    typeWithdrawal,
    typeTransfer,
    typeAdjustment,
    typeReturn,
  ];

  // Status display names in Arabic
  static const Map<String, String> statusDisplayNames = {
    statusPending: 'في الانتظار',
    statusApproved: 'موافق عليه',
    statusRejected: 'مرفوض',
    statusExecuted: 'منفذ',
    statusCancelled: 'ملغي',
    statusProcessing: 'قيد المعالجة',
    statusCompleted: 'مكتمل',
  };

  // Type display names in Arabic
  static const Map<String, String> typeDisplayNames = {
    typeWithdrawal: 'سحب من المخزن',
    typeTransfer: 'نقل بين المخازن',
    typeAdjustment: 'تعديل مخزون',
    typeReturn: 'إرجاع للمخزن',
  };

  /// Validate status value
  static bool isValidStatus(String status) {
    return validStatusValues.contains(status);
  }

  /// Validate type value
  static bool isValidType(String type) {
    return validTypeValues.contains(type);
  }

  /// Get status display name
  static String getStatusDisplayName(String status) {
    return statusDisplayNames[status] ?? status;
  }

  /// Get type display name
  static String getTypeDisplayName(String type) {
    return typeDisplayNames[type] ?? type;
  }

  /// Check if status allows editing
  static bool canEdit(String status) {
    return status == statusPending;
  }

  /// Check if status allows approval
  static bool canApprove(String status) {
    return status == statusPending;
  }

  /// Check if status allows execution
  static bool canExecute(String status) {
    return status == statusApproved || status == statusProcessing;
  }

  /// Check if status allows cancellation
  static bool canCancel(String status) {
    return status == statusPending || status == statusApproved;
  }

  /// Check if status allows processing
  static bool canProcess(String status) {
    return status == statusPending || status == statusApproved;
  }

  /// Check if status is final (cannot be changed)
  static bool isFinalStatus(String status) {
    return status == statusExecuted || 
           status == statusCompleted || 
           status == statusCancelled || 
           status == statusRejected;
  }

  /// Get next possible status values for a given status
  static List<String> getNextPossibleStatuses(String currentStatus) {
    switch (currentStatus) {
      case statusPending:
        return [statusApproved, statusRejected, statusProcessing];
      case statusApproved:
        return [statusProcessing, statusExecuted, statusCancelled];
      case statusProcessing:
        return [statusCompleted, statusExecuted, statusCancelled];
      case statusRejected:
      case statusExecuted:
      case statusCompleted:
      case statusCancelled:
        return []; // Final statuses cannot be changed
      default:
        return [];
    }
  }

  /// Status workflow validation
  static bool isValidStatusTransition(String fromStatus, String toStatus) {
    final possibleStatuses = getNextPossibleStatuses(fromStatus);
    return possibleStatuses.contains(toStatus);
  }
}
