import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:smartbiztracker_new/models/worker_attendance_model.dart';
import 'package:smartbiztracker_new/services/worker_attendance_service.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// مزود إدارة حضور العمال
class WorkerAttendanceProvider extends ChangeNotifier {
  final WorkerAttendanceService _attendanceService = WorkerAttendanceService();

  // حالة التطبيق
  bool _isLoading = false;
  bool _isScanning = false;
  bool _isProcessing = false;
  bool _isInitialized = false;
  String? _error;
  
  // بيانات الحضور
  AttendanceStatistics _statistics = AttendanceStatistics.empty();
  List<WorkerAttendanceModel> _recentAttendance = [];
  WorkerAttendanceModel? _lastProcessedAttendance;
  
  // معلومات الجهاز
  DeviceInfo? _deviceInfo;
  
  // إعدادات الماسح
  bool _flashlightEnabled = false;
  bool _frontCamera = false;
  
  // تخزين مؤقت للبيانات
  DateTime? _lastCacheUpdate;
  static const Duration _cacheValidDuration = Duration(minutes: 5);

  // Getters
  bool get isLoading => _isLoading;
  bool get isScanning => _isScanning;
  bool get isProcessing => _isProcessing;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  AttendanceStatistics get statistics => _statistics;
  List<WorkerAttendanceModel> get recentAttendance => _recentAttendance;
  WorkerAttendanceModel? get lastProcessedAttendance => _lastProcessedAttendance;
  DeviceInfo? get deviceInfo => _deviceInfo;
  bool get flashlightEnabled => _flashlightEnabled;
  bool get frontCamera => _frontCamera;

  /// تهيئة المزود
  Future<void> initialize() async {
    if (_isLoading || _isInitialized) return;

    _setLoading(true);
    _clearError();

    try {
      AppLogger.info('🚀 تهيئة مزود حضور العمال...');

      // تحميل معلومات الجهاز
      await _loadDeviceInfo();

      // تحميل الإحصائيات
      await loadStatistics();

      _isInitialized = true;
      AppLogger.info('✅ تم تهيئة مزود حضور العمال بنجاح');
    } catch (e) {
      _setError('خطأ في تهيئة نظام الحضور: $e');
      AppLogger.error('❌ خطأ في تهيئة المزود: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// تحميل معلومات الجهاز
  Future<void> _loadDeviceInfo() async {
    try {
      _deviceInfo = await _attendanceService.getDeviceInfo();
      AppLogger.info('📱 تم تحميل معلومات الجهاز: ${_deviceInfo?.deviceModel}');
    } catch (e) {
      AppLogger.error('❌ خطأ في تحميل معلومات الجهاز: $e');
      rethrow;
    }
  }

  /// تحميل الإحصائيات
  Future<void> loadStatistics({bool forceRefresh = false}) async {
    // التحقق من صحة التخزين المؤقت
    if (!forceRefresh && _isCacheValid()) {
      AppLogger.info('⚡ استخدام الإحصائيات من التخزين المؤقت');
      return;
    }

    try {
      AppLogger.info('📊 تحميل إحصائيات الحضور...');
      
      _statistics = await _attendanceService.getAttendanceStatistics();
      _recentAttendance = _statistics.recentAttendance;
      _lastCacheUpdate = DateTime.now();
      
      AppLogger.info('✅ تم تحميل الإحصائيات: ${_statistics.totalWorkers} عامل');
      notifyListeners();
    } catch (e) {
      _setError('خطأ في تحميل الإحصائيات: $e');
      AppLogger.error('❌ خطأ في تحميل الإحصائيات: $e');
    }
  }

  /// بدء المسح
  void startScanning() {
    if (_isScanning) return;
    
    _isScanning = true;
    _clearError();
    AppLogger.info('📷 بدء مسح QR...');
    notifyListeners();
  }

  /// إيقاف المسح
  void stopScanning() {
    if (!_isScanning) return;
    
    _isScanning = false;
    AppLogger.info('⏹️ إيقاف مسح QR');
    notifyListeners();
  }

  /// معالجة رمز QR
  Future<AttendanceValidationResponse> processQRCode(String qrData) async {
    if (_isProcessing) {
      return AttendanceValidationResponse.error('جاري المعالجة...');
    }

    _setProcessing(true);
    _clearError();

    try {
      AppLogger.info('🔍 معالجة رمز QR...');
      
      // التحقق من صحة الرمز
      final validationResponse = await _attendanceService.validateQRToken(qrData);
      
      if (!validationResponse.isValid) {
        _setError(validationResponse.errorMessage ?? 'رمز QR غير صحيح');
        return validationResponse;
      }

      // معالجة الحضور
      final token = QRAttendanceToken.fromJson(jsonDecode(qrData));
      final processResponse = await _attendanceService.processAttendance(token);
      
      if (processResponse.isValid && processResponse.attendanceRecord != null) {
        _lastProcessedAttendance = processResponse.attendanceRecord;
        
        // تحديث الإحصائيات
        await loadStatistics(forceRefresh: true);
        
        AppLogger.info('✅ تم تسجيل الحضور بنجاح');
      } else {
        _setError(processResponse.errorMessage ?? 'فشل في تسجيل الحضور');
      }

      return processResponse;
      
    } catch (e) {
      final errorMessage = 'خطأ في معالجة رمز QR: $e';
      _setError(errorMessage);
      AppLogger.error('❌ $errorMessage');
      return AttendanceValidationResponse.error(errorMessage);
    } finally {
      _setProcessing(false);
    }
  }

  /// تبديل الفلاش
  void toggleFlashlight() {
    _flashlightEnabled = !_flashlightEnabled;
    AppLogger.info('💡 الفلاش: ${_flashlightEnabled ? 'مفعل' : 'معطل'}');
    notifyListeners();
  }

  /// تبديل الكاميرا
  void toggleCamera() {
    _frontCamera = !_frontCamera;
    AppLogger.info('📷 الكاميرا: ${_frontCamera ? 'أمامية' : 'خلفية'}');
    notifyListeners();
  }

  /// الحصول على سجل حضور عامل
  Future<List<WorkerAttendanceModel>> getWorkerHistory(
    String workerId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      return await _attendanceService.getWorkerAttendanceHistory(
        workerId,
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e) {
      AppLogger.error('❌ خطأ في تحميل سجل العامل: $e');
      return [];
    }
  }

  /// تحديث البيانات
  Future<void> refresh() async {
    await loadStatistics(forceRefresh: true);
  }

  /// مسح آخر حضور معالج
  void clearLastProcessedAttendance() {
    _lastProcessedAttendance = null;
    notifyListeners();
  }

  /// التحقق من صحة التخزين المؤقت
  bool _isCacheValid() {
    if (_lastCacheUpdate == null) return false;
    final now = DateTime.now();
    return now.difference(_lastCacheUpdate!) < _cacheValidDuration;
  }

  /// تعيين حالة التحميل
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  /// تعيين حالة المعالجة
  void _setProcessing(bool processing) {
    if (_isProcessing != processing) {
      _isProcessing = processing;
      notifyListeners();
    }
  }

  /// تعيين رسالة خطأ
  void _setError(String? error) {
    if (_error != error) {
      _error = error;
      notifyListeners();
    }
  }

  /// مسح رسالة الخطأ
  void _clearError() {
    _setError(null);
  }

  /// إعادة تعيين الحالة
  void reset() {
    _isLoading = false;
    _isScanning = false;
    _isProcessing = false;
    _isInitialized = false;
    _error = null;
    _lastProcessedAttendance = null;
    _flashlightEnabled = false;
    _frontCamera = false;
    notifyListeners();
  }

  /// الحصول على سجلات الحضور لتاريخ محدد
  Future<List<WorkerAttendanceModel>> getAttendanceForDate(DateTime date) async {
    try {
      AppLogger.info('📅 جاري تحميل سجلات الحضور لتاريخ: ${date.toIso8601String().split('T')[0]}');

      // استخدام الطريقة الموجودة في الخدمة مع تصفية التاريخ
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final allRecords = await _attendanceService.getRecentAttendanceRecords(limit: 100);

      // تصفية السجلات للتاريخ المحدد
      final filteredRecords = allRecords.where((record) {
        return record.timestamp.isAfter(startOfDay) && record.timestamp.isBefore(endOfDay);
      }).toList();

      AppLogger.info('✅ تم تحميل ${filteredRecords.length} سجل حضور للتاريخ المحدد');
      return filteredRecords;
    } catch (e) {
      AppLogger.error('❌ خطأ في تحميل سجلات الحضور: $e');
      return [];
    }
  }

  @override
  void dispose() {
    reset();
    super.dispose();
  }
}
