import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:smartbiztracker_new/models/worker_attendance_model.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:smartbiztracker_new/widgets/worker_attendance/attendance_failure_widget.dart';

/// معالج أخطاء حضور العمال الشامل
class WorkerAttendanceErrorHandler {
  static final WorkerAttendanceErrorHandler _instance = WorkerAttendanceErrorHandler._internal();
  factory WorkerAttendanceErrorHandler() => _instance;
  WorkerAttendanceErrorHandler._internal();

  /// معالجة أخطاء الكاميرا
  static Future<AttendanceValidationResponse> handleCameraError(dynamic error) async {
    AppLogger.error('❌ خطأ في الكاميرا: $error');
    
    // التحقق من أذونات الكاميرا
    final cameraStatus = await Permission.camera.status;
    
    if (cameraStatus.isDenied) {
      return AttendanceValidationResponse.error(
        AttendanceErrorMessages.getMessage(AttendanceErrorCodes.permissionDenied),
        AttendanceErrorCodes.permissionDenied,
      );
    } else if (cameraStatus.isPermanentlyDenied) {
      return AttendanceValidationResponse.error(
        'تم رفض إذن الكاميرا نهائياً. يرجى تفعيله من إعدادات التطبيق.',
        AttendanceErrorCodes.permissionDenied,
      );
    } else {
      return AttendanceValidationResponse.error(
        AttendanceErrorMessages.getMessage(AttendanceErrorCodes.cameraError),
        AttendanceErrorCodes.cameraError,
      );
    }
  }

  /// معالجة أخطاء الشبكة
  static AttendanceValidationResponse handleNetworkError(dynamic error) {
    AppLogger.error('❌ خطأ في الشبكة: $error');
    
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('timeout') || errorString.contains('connection timeout')) {
      return AttendanceValidationResponse.error(
        'انتهت مهلة الاتصال. تحقق من سرعة الإنترنت وأعد المحاولة.',
        AttendanceErrorCodes.networkError,
      );
    } else if (errorString.contains('no internet') || errorString.contains('network unreachable')) {
      return AttendanceValidationResponse.error(
        'لا يوجد اتصال بالإنترنت. تحقق من الاتصال وأعد المحاولة.',
        AttendanceErrorCodes.networkError,
      );
    } else if (errorString.contains('server') || errorString.contains('500')) {
      return AttendanceValidationResponse.error(
        'خطأ في الخادم. يرجى المحاولة مرة أخرى لاحقاً.',
        AttendanceErrorCodes.databaseError,
      );
    } else {
      return AttendanceValidationResponse.error(
        AttendanceErrorMessages.getMessage(AttendanceErrorCodes.networkError),
        AttendanceErrorCodes.networkError,
      );
    }
  }

  /// معالجة أخطاء قاعدة البيانات
  static AttendanceValidationResponse handleDatabaseError(dynamic error) {
    AppLogger.error('❌ خطأ في قاعدة البيانات: $error');
    
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('unique constraint') || errorString.contains('duplicate')) {
      return AttendanceValidationResponse.error(
        'تم استخدام هذا الرمز من قبل. يرجى إنشاء رمز جديد.',
        AttendanceErrorCodes.replayAttack,
      );
    } else if (errorString.contains('foreign key') || errorString.contains('not found')) {
      return AttendanceValidationResponse.error(
        AttendanceErrorMessages.getMessage(AttendanceErrorCodes.workerNotFound),
        AttendanceErrorCodes.workerNotFound,
      );
    } else if (errorString.contains('check constraint')) {
      return AttendanceValidationResponse.error(
        'البيانات المرسلة غير صحيحة. تحقق من صحة رمز QR.',
        AttendanceErrorCodes.invalidSignature,
      );
    } else {
      return AttendanceValidationResponse.error(
        AttendanceErrorMessages.getMessage(AttendanceErrorCodes.databaseError),
        AttendanceErrorCodes.databaseError,
      );
    }
  }

  /// معالجة أخطاء التحقق من الرمز المميز
  static AttendanceValidationResponse handleTokenValidationError(String errorCode, String? errorMessage) {
    AppLogger.warning('⚠️ خطأ في التحقق من الرمز: $errorCode - $errorMessage');
    
    switch (errorCode) {
      case AttendanceErrorCodes.tokenExpired:
        return AttendanceValidationResponse.error(
          AttendanceErrorMessages.getMessage(AttendanceErrorCodes.tokenExpired),
          AttendanceErrorCodes.tokenExpired,
        );
      
      case AttendanceErrorCodes.invalidSignature:
        return AttendanceValidationResponse.error(
          AttendanceErrorMessages.getMessage(AttendanceErrorCodes.invalidSignature),
          AttendanceErrorCodes.invalidSignature,
        );
      
      case AttendanceErrorCodes.replayAttack:
        return AttendanceValidationResponse.error(
          AttendanceErrorMessages.getMessage(AttendanceErrorCodes.replayAttack),
          AttendanceErrorCodes.replayAttack,
        );
      
      case AttendanceErrorCodes.deviceMismatch:
        return AttendanceValidationResponse.error(
          AttendanceErrorMessages.getMessage(AttendanceErrorCodes.deviceMismatch),
          AttendanceErrorCodes.deviceMismatch,
        );
      
      case AttendanceErrorCodes.gapViolation:
        return AttendanceValidationResponse.error(
          AttendanceErrorMessages.getMessage(AttendanceErrorCodes.gapViolation),
          AttendanceErrorCodes.gapViolation,
        );
      
      case AttendanceErrorCodes.sequenceError:
        return AttendanceValidationResponse.error(
          AttendanceErrorMessages.getMessage(AttendanceErrorCodes.sequenceError),
          AttendanceErrorCodes.sequenceError,
        );
      
      case AttendanceErrorCodes.workerNotFound:
        return AttendanceValidationResponse.error(
          AttendanceErrorMessages.getMessage(AttendanceErrorCodes.workerNotFound),
          AttendanceErrorCodes.workerNotFound,
        );
      
      default:
        return AttendanceValidationResponse.error(
          errorMessage ?? 'حدث خطأ غير متوقع في التحقق من الرمز.',
          errorCode,
        );
    }
  }

  /// معالجة أخطاء عامة
  static AttendanceValidationResponse handleGenericError(dynamic error) {
    AppLogger.error('❌ خطأ عام: $error');
    
    final errorString = error.toString();
    
    // محاولة تحديد نوع الخطأ من الرسالة
    if (errorString.contains('camera') || errorString.contains('Camera')) {
      return AttendanceValidationResponse.error(
        AttendanceErrorMessages.getMessage(AttendanceErrorCodes.cameraError),
        AttendanceErrorCodes.cameraError,
      );
    } else if (errorString.contains('network') || errorString.contains('internet') || errorString.contains('connection')) {
      return AttendanceValidationResponse.error(
        AttendanceErrorMessages.getMessage(AttendanceErrorCodes.networkError),
        AttendanceErrorCodes.networkError,
      );
    } else if (errorString.contains('database') || errorString.contains('sql') || errorString.contains('query')) {
      return AttendanceValidationResponse.error(
        AttendanceErrorMessages.getMessage(AttendanceErrorCodes.databaseError),
        AttendanceErrorCodes.databaseError,
      );
    } else {
      return AttendanceValidationResponse.error(
        'حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى.',
        'UNKNOWN_ERROR',
      );
    }
  }

  /// طلب أذونات الكاميرا
  static Future<bool> requestCameraPermission() async {
    try {
      final status = await Permission.camera.request();
      
      if (status.isGranted) {
        AppLogger.info('✅ تم منح إذن الكاميرا');
        return true;
      } else if (status.isDenied) {
        AppLogger.warning('⚠️ تم رفض إذن الكاميرا');
        return false;
      } else if (status.isPermanentlyDenied) {
        AppLogger.warning('⚠️ تم رفض إذن الكاميرا نهائياً');
        // يمكن فتح إعدادات التطبيق هنا
        await openAppSettings();
        return false;
      }
      
      return false;
    } catch (e) {
      AppLogger.error('❌ خطأ في طلب إذن الكاميرا: $e');
      return false;
    }
  }

  /// التحقق من حالة أذونات الكاميرا
  static Future<PermissionStatus> checkCameraPermission() async {
    try {
      return await Permission.camera.status;
    } catch (e) {
      AppLogger.error('❌ خطأ في التحقق من إذن الكاميرا: $e');
      return PermissionStatus.denied;
    }
  }

  /// عرض رسالة خطأ مع إمكانية إعادة المحاولة
  static void showErrorDialog(
    BuildContext context,
    String errorMessage,
    String? errorCode, {
    VoidCallback? onRetry,
    VoidCallback? onDismiss,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AttendanceFailureWidget(
        errorMessage: errorMessage,
        errorCode: errorCode,
        onRetry: () {
          Navigator.of(context).pop();
          onRetry?.call();
        },
        onDismiss: () {
          Navigator.of(context).pop();
          onDismiss?.call();
        },
      ),
    );
  }

  /// تسجيل الأخطاء مع تفاصيل إضافية
  static void logError(String operation, dynamic error, {Map<String, dynamic>? context}) {
    final errorDetails = {
      'operation': operation,
      'error': error.toString(),
      'timestamp': DateTime.now().toIso8601String(),
      if (context != null) ...context,
    };
    
    AppLogger.error('❌ Worker Attendance Error: $errorDetails');
  }

  /// التحقق من صحة البيانات المدخلة
  static AttendanceValidationResponse? validateInput(String? qrData) {
    if (qrData == null || qrData.isEmpty) {
      return AttendanceValidationResponse.error(
        'رمز QR فارغ أو غير صحيح.',
        AttendanceErrorCodes.invalidSignature,
      );
    }
    
    if (qrData.length < 10) {
      return AttendanceValidationResponse.error(
        'رمز QR قصير جداً. تأكد من صحة الرمز.',
        AttendanceErrorCodes.invalidSignature,
      );
    }
    
    // التحقق من أن البيانات تحتوي على JSON صحيح
    try {
      final decoded = qrData.trim();
      if (!decoded.startsWith('{') || !decoded.endsWith('}')) {
        return AttendanceValidationResponse.error(
          'تنسيق رمز QR غير صحيح.',
          AttendanceErrorCodes.invalidSignature,
        );
      }
    } catch (e) {
      return AttendanceValidationResponse.error(
        'رمز QR تالف أو غير قابل للقراءة.',
        AttendanceErrorCodes.invalidSignature,
      );
    }
    
    return null; // البيانات صحيحة
  }
}
