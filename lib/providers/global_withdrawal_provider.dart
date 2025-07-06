import 'package:flutter/foundation.dart';
import '../models/global_withdrawal_models.dart';
import '../services/enhanced_global_withdrawal_service.dart';
import '../utils/app_logger.dart';

/// مزود إدارة طلبات السحب العالمية
class GlobalWithdrawalProvider with ChangeNotifier {
  final EnhancedGlobalWithdrawalService _withdrawalService = EnhancedGlobalWithdrawalService();

  // حالة التطبيق
  bool _isLoading = false;
  bool _isProcessing = false;
  String? _error;

  // البيانات
  List<GlobalWithdrawalRequest> _requests = [];
  GlobalWithdrawalRequest? _selectedRequest;
  List<WarehouseRequestAllocation> _selectedRequestAllocations = [];
  EnhancedWithdrawalProcessingResult? _lastProcessingResult;
  GlobalProcessingPerformance? _performanceStats;

  // إعدادات
  GlobalProcessingSettings _settings = const GlobalProcessingSettings();

  // تخزين مؤقت
  final Map<String, GlobalWithdrawalRequest> _requestCache = {};
  final Map<String, List<WarehouseRequestAllocation>> _allocationCache = {};
  DateTime? _lastCacheUpdate;

  // Getters
  bool get isLoading => _isLoading;
  bool get isProcessing => _isProcessing;
  String? get error => _error;
  List<GlobalWithdrawalRequest> get requests => _requests;
  GlobalWithdrawalRequest? get selectedRequest => _selectedRequest;
  List<WarehouseRequestAllocation> get selectedRequestAllocations => _selectedRequestAllocations;
  EnhancedWithdrawalProcessingResult? get lastProcessingResult => _lastProcessingResult;
  GlobalProcessingPerformance? get performanceStats => _performanceStats;
  GlobalProcessingSettings get settings => _settings;

  /// تحميل طلبات السحب العالمية
  Future<void> loadGlobalRequests({
    String? status,
    int? limit,
    bool forceRefresh = false,
  }) async {
    if (_isLoading && !forceRefresh) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      AppLogger.info('📋 تحميل طلبات السحب العالمية');

      final requests = await _withdrawalService.getGlobalWithdrawalRequests(
        status: status,
        limit: limit,
      );

      _requests = requests;
      
      // تحديث التخزين المؤقت
      for (final request in requests) {
        _requestCache[request.id] = request;
      }
      _lastCacheUpdate = DateTime.now();

      AppLogger.info('✅ تم تحميل ${requests.length} طلب سحب عالمي');
    } catch (e) {
      _error = 'فشل في تحميل طلبات السحب: $e';
      AppLogger.error('❌ $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// إنشاء طلب سحب عالمي جديد
  Future<GlobalWithdrawalRequest?> createGlobalRequest({
    required String reason,
    required List<WithdrawalRequestItem> items,
    required String requestedBy,
    String? allocationStrategy,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      AppLogger.info('🌍 إنشاء طلب سحب عالمي جديد');

      final request = await _withdrawalService.createGlobalWithdrawalRequest(
        reason: reason,
        items: items,
        requestedBy: requestedBy,
        allocationStrategy: allocationStrategy ?? _settings.defaultAllocationStrategy,
      );

      // إضافة الطلب للقائمة
      _requests.insert(0, request);
      _requestCache[request.id] = request;

      AppLogger.info('✅ تم إنشاء طلب السحب العالمي: ${request.id}');
      return request;
    } catch (e) {
      _error = 'فشل في إنشاء طلب السحب: $e';
      AppLogger.error('❌ $_error');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// معالجة طلب سحب عالمي
  Future<bool> processGlobalRequest({
    required String requestId,
    String? allocationStrategy,
    String? performedBy,
  }) async {
    _isProcessing = true;
    _error = null;
    notifyListeners();

    try {
      AppLogger.info('🔄 معالجة طلب السحب العالمي: $requestId');

      final result = await _withdrawalService.processGlobalWithdrawalRequest(
        requestId: requestId,
        allocationStrategy: allocationStrategy ?? _settings.defaultAllocationStrategy,
        performedBy: performedBy,
      );

      _lastProcessingResult = result;

      // تحديث الطلب في القائمة
      final requestIndex = _requests.indexWhere((r) => r.id == requestId);
      if (requestIndex != -1) {
        final updatedRequest = await _withdrawalService.getGlobalWithdrawalRequest(requestId);
        _requests[requestIndex] = updatedRequest;
        _requestCache[requestId] = updatedRequest;

        if (_selectedRequest?.id == requestId) {
          _selectedRequest = updatedRequest;
          await _loadSelectedRequestAllocations();
        }
      }

      AppLogger.info('✅ نتائج المعالجة: ${result.summaryText}');
      return result.success;
    } catch (e) {
      _error = 'فشل في معالجة طلب السحب: $e';
      AppLogger.error('❌ $_error');
      return false;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// تحديد طلب للعرض التفصيلي
  Future<void> selectRequest(String requestId) async {
    try {
      // التحقق من التخزين المؤقت أولاً
      if (_requestCache.containsKey(requestId) && _isCacheValid()) {
        _selectedRequest = _requestCache[requestId];
      } else {
        _selectedRequest = await _withdrawalService.getGlobalWithdrawalRequest(requestId);
        _requestCache[requestId] = _selectedRequest!;
      }

      await _loadSelectedRequestAllocations();
      notifyListeners();
    } catch (e) {
      _error = 'فشل في تحميل تفاصيل الطلب: $e';
      AppLogger.error('❌ $_error');
      notifyListeners();
    }
  }

  /// تحميل تخصيصات الطلب المحدد
  Future<void> _loadSelectedRequestAllocations() async {
    if (_selectedRequest == null) return;

    try {
      // التحقق من التخزين المؤقت
      if (_allocationCache.containsKey(_selectedRequest!.id) && _isCacheValid()) {
        _selectedRequestAllocations = _allocationCache[_selectedRequest!.id]!;
      } else {
        _selectedRequestAllocations = await _withdrawalService.getRequestAllocations(_selectedRequest!.id);
        _allocationCache[_selectedRequest!.id] = _selectedRequestAllocations;
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في تحميل تخصيصات الطلب: $e');
      _selectedRequestAllocations = [];
    }
  }

  /// معالجة جميع الطلبات المكتملة
  Future<int> processAllCompletedRequests({
    String? allocationStrategy,
    int? limit,
  }) async {
    _isProcessing = true;
    _error = null;
    notifyListeners();

    try {
      AppLogger.info('🔄 معالجة جميع الطلبات المكتملة');

      final results = await _withdrawalService.processAllCompletedRequests(
        allocationStrategy: allocationStrategy ?? _settings.defaultAllocationStrategy,
        limit: limit,
      );

      // تحديث القوائم
      await loadGlobalRequests(forceRefresh: true);

      AppLogger.info('✅ تم معالجة ${results.length} طلب');
      return results.length;
    } catch (e) {
      _error = 'فشل في معالجة الطلبات المكتملة: $e';
      AppLogger.error('❌ $_error');
      return 0;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// تحويل طلب تقليدي إلى عالمي
  Future<bool> convertToGlobalRequest(String requestId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      AppLogger.info('🔄 تحويل طلب إلى عالمي: $requestId');

      final convertedRequest = await _withdrawalService.convertToGlobalRequest(requestId);
      
      // تحديث القائمة
      final requestIndex = _requests.indexWhere((r) => r.id == requestId);
      if (requestIndex != -1) {
        _requests[requestIndex] = convertedRequest;
      } else {
        _requests.insert(0, convertedRequest);
      }
      
      _requestCache[requestId] = convertedRequest;

      AppLogger.info('✅ تم تحويل الطلب إلى عالمي');
      return true;
    } catch (e) {
      _error = 'فشل في تحويل الطلب: $e';
      AppLogger.error('❌ $_error');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// تحميل إحصائيات الأداء
  Future<void> loadPerformanceStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      AppLogger.info('📊 تحميل إحصائيات الأداء');

      _performanceStats = await _withdrawalService.getProcessingPerformance(
        startDate: startDate,
        endDate: endDate,
      );

      notifyListeners();
      AppLogger.info('✅ تم تحميل إحصائيات الأداء');
    } catch (e) {
      AppLogger.error('❌ خطأ في تحميل إحصائيات الأداء: $e');
    }
  }

  /// إلغاء تخصيص
  Future<bool> cancelAllocation(String allocationId) async {
    try {
      final success = await _withdrawalService.cancelAllocation(allocationId);
      
      if (success) {
        // تحديث التخصيصات المحلية
        await _loadSelectedRequestAllocations();
        notifyListeners();
      }

      return success;
    } catch (e) {
      _error = 'فشل في إلغاء التخصيص: $e';
      AppLogger.error('❌ $_error');
      notifyListeners();
      return false;
    }
  }

  /// تحديث إعدادات المعالجة
  void updateSettings(GlobalProcessingSettings newSettings) {
    _settings = newSettings;
    _clearCache();
    notifyListeners();
    AppLogger.info('⚙️ تم تحديث إعدادات المعالجة العالمية');
  }

  /// تنظيف التخزين المؤقت
  void _clearCache() {
    _requestCache.clear();
    _allocationCache.clear();
    _lastCacheUpdate = null;
  }

  /// التحقق من صحة التخزين المؤقت
  bool _isCacheValid() {
    if (_lastCacheUpdate == null) return false;
    final cacheAge = DateTime.now().difference(_lastCacheUpdate!);
    return cacheAge.inMinutes < 5; // صالح لمدة 5 دقائق
  }

  /// تحديث التخزين المؤقت يدوياً
  void refreshCache() {
    _clearCache();
    loadGlobalRequests(forceRefresh: true);
    AppLogger.info('🔄 تم تحديث التخزين المؤقت');
  }

  /// إعادة تعيين الأخطاء
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// إلغاء تحديد الطلب
  void clearSelection() {
    _selectedRequest = null;
    _selectedRequestAllocations = [];
    notifyListeners();
  }

  /// الحصول على طلبات حسب الحالة
  List<GlobalWithdrawalRequest> getRequestsByStatus(String status) {
    return _requests.where((request) => request.status == status).toList();
  }

  /// الحصول على الطلبات العالمية فقط
  List<GlobalWithdrawalRequest> get globalRequests {
    return _requests.where((request) => request.isGlobalRequest).toList();
  }

  /// الحصول على الطلبات المعالجة تلقائياً
  List<GlobalWithdrawalRequest> get autoProcessedRequests {
    return _requests.where((request) => request.isAutoProcessed).toList();
  }

  /// إحصائيات سريعة
  Map<String, int> get quickStats {
    return {
      'total': _requests.length,
      'global': globalRequests.length,
      'auto_processed': autoProcessedRequests.length,
      'pending': getRequestsByStatus('pending').length,
      'completed': getRequestsByStatus('completed').length,
    };
  }

  @override
  void dispose() {
    _clearCache();
    super.dispose();
  }
}
