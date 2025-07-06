import 'package:flutter/foundation.dart';
import 'package:smartbiztracker_new/models/warehouse_dispatch_model.dart';
import 'package:smartbiztracker_new/services/warehouse_dispatch_service.dart';
import 'package:smartbiztracker_new/constants/warehouse_dispatch_constants.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// مزود طلبات صرف المخزون
/// يدير حالة طلبات الصرف والتحديثات
class WarehouseDispatchProvider with ChangeNotifier {
  final WarehouseDispatchService _service = WarehouseDispatchService();

  // حالة البيانات
  List<WarehouseDispatchModel> _dispatchRequests = [];
  List<WarehouseDispatchModel> _filteredRequests = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';
  String _statusFilter = 'all'; // all, pending, processing, completed, cancelled

  // Getters
  List<WarehouseDispatchModel> get dispatchRequests => _dispatchRequests;
  List<WarehouseDispatchModel> get filteredRequests => _filteredRequests;
  List<WarehouseDispatchModel> get requests => _dispatchRequests; // Alias for compatibility
  bool get isLoading => _isLoading;
  bool get hasError => _errorMessage != null;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  String get statusFilter => _statusFilter;

  /// تحميل طلبات الصرف
  Future<void> loadDispatchRequests({bool forceRefresh = false}) async {
    try {
      // تجنب التحميل المتكرر إذا كانت البيانات موجودة
      if (_dispatchRequests.isNotEmpty && !forceRefresh) {
        _applyFilters();
        return;
      }

      _setLoading(true);
      _clearError();

      AppLogger.info('🚚 تحميل طلبات صرف المخزون...');

      final requests = await _service.getDispatchRequests();
      
      _dispatchRequests = requests;
      _applyFilters();

      AppLogger.info('✅ تم تحميل ${requests.length} طلب صرف بنجاح');

    } catch (e) {
      AppLogger.error('❌ خطأ في تحميل طلبات الصرف: $e');
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// تحميل طلبات الصرف (alias for compatibility)
  Future<void> loadRequests({bool forceRefresh = false}) async {
    return loadDispatchRequests(forceRefresh: forceRefresh);
  }

  /// إنشاء طلب صرف جديد من فاتورة
  Future<WarehouseDispatchModel?> createDispatchFromInvoice({
    required String invoiceId,
    required String customerName,
    required double totalAmount,
    required List<Map<String, dynamic>> items,
    required String requestedBy,
    String? notes,
    String? warehouseId,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      AppLogger.info('📋 إنشاء طلب صرف من فاتورة: $invoiceId');

      final createdDispatch = await _service.createDispatchFromInvoice(
        invoiceId: invoiceId,
        customerName: customerName,
        totalAmount: totalAmount,
        items: items,
        requestedBy: requestedBy,
        notes: notes,
        warehouseId: warehouseId,
      );

      if (createdDispatch != null) {
        // إضافة الطلب الجديد إلى القائمة المحلية
        _dispatchRequests.insert(0, createdDispatch);
        _applyFilters();
        AppLogger.info('✅ تم إنشاء طلب الصرف بنجاح');
        return createdDispatch;
      } else {
        _setError('فشل في إنشاء طلب الصرف');
        return null;
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في إنشاء طلب الصرف: $e');

      // تحسين رسائل الخطأ للمستخدم
      String errorMessage = 'خطأ في تحويل الفاتورة إلى طلب صرف';

      if (e.toString().contains('يجب اختيار المخزن المطلوب الصرف منه')) {
        errorMessage = 'يجب اختيار المخزن المطلوب الصرف منه لتحويل الفاتورة';
      } else if (e.toString().contains('null value in column "warehouse_id"')) {
        errorMessage = 'يجب اختيار المخزن المطلوب الصرف منه لتحويل الفاتورة';
      } else if (e.toString().contains('المستخدم غير مسجل دخول')) {
        errorMessage = 'يجب تسجيل الدخول أولاً';
      } else if (e.toString().contains('row-level security policy')) {
        errorMessage = 'ليس لديك صلاحية لتحويل الفواتير إلى طلبات صرف';
      } else {
        errorMessage = 'حدث خطأ في تحويل الفاتورة: ${e.toString()}';
      }

      _setError(errorMessage);
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// إنشاء طلب صرف يدوي
  Future<bool> createManualDispatch({
    required String productName,
    required int quantity,
    required String reason,
    required String requestedBy,
    String? notes,
    String? warehouseId,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      AppLogger.info('📋 إنشاء طلب صرف يدوي للمنتج: $productName');

      final success = await _service.createManualDispatch(
        productName: productName,
        quantity: quantity,
        reason: reason,
        requestedBy: requestedBy,
        notes: notes,
        warehouseId: warehouseId,
      );

      if (success) {
        // إعادة تحميل القائمة
        await loadDispatchRequests(forceRefresh: true);
        AppLogger.info('✅ تم إنشاء طلب الصرف اليدوي بنجاح');
        return true;
      } else {
        _setError('فشل في إنشاء طلب الصرف');
        return false;
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في إنشاء طلب الصرف اليدوي: $e');

      // تحسين رسائل الخطأ للمستخدم
      String errorMessage = 'خطأ في إنشاء طلب الصرف';

      if (e.toString().contains('يجب اختيار المخزن')) {
        errorMessage = 'يجب اختيار المخزن المطلوب الصرف منه';
      } else if (e.toString().contains('null value in column "warehouse_id"')) {
        errorMessage = 'يجب اختيار المخزن المطلوب الصرف منه';
      } else if (e.toString().contains('المستخدم غير مسجل دخول')) {
        errorMessage = 'يجب تسجيل الدخول أولاً';
      } else if (e.toString().contains('row-level security policy')) {
        errorMessage = 'ليس لديك صلاحية لإنشاء طلبات الصرف';
      } else {
        errorMessage = 'حدث خطأ في إنشاء طلب الصرف: ${e.toString()}';
      }

      _setError(errorMessage);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// تحديث حالة طلب الصرف مع التحقق من التزامن
  Future<bool> updateDispatchStatus({
    required String requestId,
    required String newStatus,
    required String updatedBy,
    String? notes,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      AppLogger.info('🔄 تحديث حالة طلب الصرف: $requestId إلى $newStatus');

      final success = await _service.updateDispatchStatus(
        requestId: requestId,
        newStatus: newStatus,
        updatedBy: updatedBy,
        notes: notes,
      );

      if (success) {
        AppLogger.info('✅ تم تحديث قاعدة البيانات بنجاح');

        // إضافة تأخير قصير للسماح لقاعدة البيانات بالتزامن
        await Future.delayed(const Duration(milliseconds: 100));

        // الحصول على الطلب المحدث من قاعدة البيانات للتأكد من التزامن
        final updatedRequest = await _service.getDispatchRequestByIdFresh(requestId);

        if (updatedRequest != null) {
          AppLogger.info('🔄 تحديث البيانات المحلية بالحالة الجديدة: ${updatedRequest.status}');

          // تحديث الطلب في القائمة المحلية بالبيانات الفعلية من قاعدة البيانات
          final index = _dispatchRequests.indexWhere((r) => r.id == requestId);
          if (index != -1) {
            _dispatchRequests[index] = updatedRequest;
          } else {
            _dispatchRequests.add(updatedRequest);
          }
          _applyFilters();

          AppLogger.info('✅ تم تحديث حالة طلب الصرف والبيانات المحلية بنجاح');
        } else {
          AppLogger.warning('⚠️ لم يتم العثور على الطلب المحدث في قاعدة البيانات');

          // تحديث محلي كبديل
          final index = _dispatchRequests.indexWhere((r) => r.id == requestId);
          if (index != -1) {
            _dispatchRequests[index] = _dispatchRequests[index].copyWith(
              status: newStatus,
              updatedAt: DateTime.now(),
            );
            _applyFilters();
          }
        }

        return true;
      } else {
        _setError('فشل في تحديث حالة طلب الصرف');
        return false;
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في تحديث حالة طلب الصرف: $e');
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// تعيين استعلام البحث
  void setSearchQuery(String query) {
    if (_searchQuery != query) {
      _searchQuery = query;
      _applyFilters();
    }
  }

  /// تعيين فلتر الحالة
  void setStatusFilter(String status) {
    if (_statusFilter != status) {
      _statusFilter = status;
      _applyFilters();
    }
  }

  /// تطبيق التصفية والبحث
  void _applyFilters() {
    List<WarehouseDispatchModel> filtered = List.from(_dispatchRequests);

    // تطبيق فلتر الحالة
    if (_statusFilter != 'all') {
      filtered = filtered.where((request) => request.status == _statusFilter).toList();
    }

    // تطبيق البحث
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((request) {
        return request.customerName.toLowerCase().contains(query) ||
               request.invoiceId.toLowerCase().contains(query) ||
               (request.notes?.toLowerCase().contains(query) ?? false) ||
               request.requestNumber.toLowerCase().contains(query);
      }).toList();
    }

    // ترتيب حسب التاريخ (الأحدث أولاً)
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    _filteredRequests = filtered;
    notifyListeners();
  }

  /// تعيين حالة التحميل
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// تعيين رسالة الخطأ
  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  /// مسح رسالة الخطأ
  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// FIXED: إعادة تحميل طلبات الصرف من قاعدة البيانات مع مسح الكاش
  Future<void> refreshDispatchRequests({bool clearCache = false}) async {
    try {
      AppLogger.info('🔄 إعادة تحميل طلبات الصرف من قاعدة البيانات... (clearCache: $clearCache)');

      _setLoading(true);
      _clearError();

      if (clearCache) {
        AppLogger.info('🗑️ مسح الكاش المحلي...');
        _dispatchRequests.clear();
        _filteredRequests.clear();
      }

      // إضافة تأخير قصير للسماح لقاعدة البيانات بالتزامن
      await Future.delayed(const Duration(milliseconds: 200));

      final requests = await _service.getDispatchRequests();

      _dispatchRequests = requests;
      _applyFilters();

      AppLogger.info('✅ تم إعادة تحميل ${requests.length} طلب صرف بنجاح');

    } catch (e) {
      AppLogger.error('❌ خطأ في إعادة تحميل طلبات الصرف: $e');
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// مسح الكاش وإعادة التحميل الكامل
  Future<void> forceRefreshFromDatabase() async {
    try {
      AppLogger.info('🔄 إعادة تحميل قسري من قاعدة البيانات...');

      // مسح جميع البيانات المحلية
      _dispatchRequests.clear();
      _filteredRequests.clear();
      notifyListeners();

      // إعادة تحميل من قاعدة البيانات
      await refreshDispatchRequests(clearCache: true);

      AppLogger.info('✅ تم الإعادة التحميل القسري بنجاح');
    } catch (e) {
      AppLogger.error('❌ خطأ في الإعادة التحميل القسري: $e');
      rethrow;
    }
  }

  /// FIXED: الحصول على طلب صرف محدد بالمعرف مع إعادة التحميل من قاعدة البيانات
  Future<WarehouseDispatchModel?> getDispatchById(String requestId, {bool forceRefresh = false}) async {
    try {
      AppLogger.info('🔍 البحث عن طلب الصرف: $requestId (forceRefresh: $forceRefresh)');

      // إذا كان مطلوب إعادة تحميل قسري، تجاهل البيانات المحلية
      if (!forceRefresh) {
        // البحث في القائمة المحلية أولاً
        final localDispatch = _dispatchRequests.firstWhere(
          (d) => d.id == requestId,
          orElse: () => WarehouseDispatchModel(
            id: '',
            requestNumber: '',
            type: '',
            status: '',
            reason: '',
            requestedBy: '',
            requestedAt: DateTime.now(),
            items: [],
          ),
        );

        if (localDispatch.id.isNotEmpty) {
          AppLogger.info('📋 تم العثور على الطلب في القائمة المحلية: ${localDispatch.status}');
          return localDispatch;
        }
      }

      // إعادة تحميل من قاعدة البيانات مباشرة
      AppLogger.info('🔄 إعادة تحميل الطلب من قاعدة البيانات مباشرة...');
      final freshDispatch = await _service.getDispatchRequestById(requestId);

      if (freshDispatch != null) {
        AppLogger.info('✅ تم العثور على الطلب في قاعدة البيانات: ${freshDispatch.status}');

        // تحديث الطلب في القائمة المحلية
        final index = _dispatchRequests.indexWhere((r) => r.id == requestId);
        if (index != -1) {
          _dispatchRequests[index] = freshDispatch;
        } else {
          _dispatchRequests.add(freshDispatch);
        }
        _applyFilters();

        return freshDispatch;
      }

      AppLogger.warning('⚠️ لم يتم العثور على الطلب: $requestId');
      return null;

    } catch (e) {
      AppLogger.error('❌ خطأ في البحث عن طلب الصرف: $e');
      return null;
    }
  }

  /// FIXED: الحصول على طلب صرف محدد مع آلية إعادة المحاولة للتحقق من الحالة
  Future<WarehouseDispatchModel?> getDispatchByIdWithRetry(
    String requestId,
    String expectedStatus, {
    int maxRetries = 3,
    Duration retryDelay = const Duration(milliseconds: 500),
  }) async {
    try {
      AppLogger.info('🔄 البحث عن طلب الصرف مع إعادة المحاولة: $requestId (متوقع: $expectedStatus)');

      for (int attempt = 1; attempt <= maxRetries; attempt++) {
        AppLogger.info('🔍 المحاولة $attempt من $maxRetries');

        // الحصول على الطلب من قاعدة البيانات مباشرة مع ضمان الحصول على أحدث البيانات
        final dispatch = await _service.getDispatchRequestByIdFresh(requestId, delay: retryDelay);

        if (dispatch != null) {
          AppLogger.info('📋 تم العثور على الطلب - الحالة الحالية: ${dispatch.status}');

          if (dispatch.status == expectedStatus) {
            AppLogger.info('✅ تطابقت الحالة المتوقعة: $expectedStatus');

            // تحديث الطلب في القائمة المحلية
            final index = _dispatchRequests.indexWhere((r) => r.id == requestId);
            if (index != -1) {
              _dispatchRequests[index] = dispatch;
            } else {
              _dispatchRequests.add(dispatch);
            }
            _applyFilters();

            return dispatch;
          } else {
            AppLogger.warning('⚠️ عدم تطابق الحالة - متوقع: $expectedStatus، فعلي: ${dispatch.status}');

            if (attempt < maxRetries) {
              AppLogger.info('⏳ انتظار ${retryDelay.inMilliseconds}ms قبل المحاولة التالية...');
              await Future.delayed(retryDelay);
            }
          }
        } else {
          AppLogger.warning('⚠️ لم يتم العثور على الطلب في المحاولة $attempt');

          if (attempt < maxRetries) {
            await Future.delayed(retryDelay);
          }
        }
      }

      AppLogger.error('❌ فشل في العثور على الطلب بالحالة المتوقعة بعد $maxRetries محاولات');
      return null;

    } catch (e) {
      AppLogger.error('❌ خطأ في البحث عن طلب الصرف مع إعادة المحاولة: $e');
      return null;
    }
  }

  /// إعادة تعيين المزود
  void reset() {
    _dispatchRequests.clear();
    _filteredRequests.clear();
    _searchQuery = '';
    _statusFilter = 'all';
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  /// الحصول على إحصائيات الطلبات
  Map<String, int> getRequestsStats() {
    final pending = _dispatchRequests.where((r) => r.status == 'pending').length;
    final processing = _dispatchRequests.where((r) => r.status == 'processing').length;
    final completed = _dispatchRequests.where((r) => r.status == 'completed').length;
    final cancelled = _dispatchRequests.where((r) => r.status == 'cancelled').length;

    return {
      'total': _dispatchRequests.length,
      'pending': pending,
      'processing': processing,
      'completed': completed,
      'cancelled': cancelled,
    };
  }

  /// البحث عن طلب بالمعرف
  WarehouseDispatchModel? findRequestById(String id) {
    try {
      return _dispatchRequests.firstWhere((request) => request.id == id);
    } catch (e) {
      return null;
    }
  }

  /// الحصول على الطلبات المعلقة
  List<WarehouseDispatchModel> getPendingRequests() {
    return _dispatchRequests.where((r) => r.status == 'pending').toList();
  }

  /// الحصول على الطلبات قيد المعالجة
  List<WarehouseDispatchModel> getProcessingRequests() {
    return _dispatchRequests.where((r) => r.status == 'processing').toList();
  }

  /// إعادة تحميل طلب معين بالمعرف
  Future<WarehouseDispatchModel?> reloadDispatchRequest(String requestId) async {
    try {
      _setLoading(true);
      _clearError();

      AppLogger.info('🔄 إعادة تحميل طلب الصرف: $requestId');

      final request = await _service.getDispatchRequestById(requestId);

      if (request != null) {
        // تحديث الطلب في القائمة المحلية
        final index = _dispatchRequests.indexWhere((r) => r.id == requestId);
        if (index != -1) {
          _dispatchRequests[index] = request;
        } else {
          _dispatchRequests.add(request);
        }

        _applyFilters();
        AppLogger.info('✅ تم إعادة تحميل طلب الصرف بنجاح');
        return request;
      } else {
        _setError('لم يتم العثور على الطلب');
        return null;
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في إعادة تحميل طلب الصرف: $e');
      _setError(e.toString());
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// التحقق من سلامة بيانات طلب معين
  Future<Map<String, dynamic>> verifyRequestIntegrity(String requestId) async {
    try {
      AppLogger.info('🔍 التحقق من سلامة بيانات الطلب: $requestId');

      final integrity = await _service.verifyRequestDataIntegrity(requestId);

      AppLogger.info('📊 نتائج التحقق من السلامة: ${integrity['integrity']}');
      return integrity;
    } catch (e) {
      AppLogger.error('❌ خطأ في التحقق من سلامة البيانات: $e');
      return {
        'integrity': 'error',
        'error': e.toString(),
      };
    }
  }

  /// مسح جميع طلبات الصرف
  Future<bool> clearAllDispatchRequests() async {
    try {
      _setLoading(true);
      _clearError();

      AppLogger.info('🗑️ بدء عملية مسح جميع طلبات الصرف من المزود...');

      // تشخيص شامل للمشاكل أولاً
      AppLogger.info('🔍 تشخيص شامل للمشاكل...');
      final diagnostics = await _service.runComprehensiveDiagnostics();
      AppLogger.info('📊 نتائج التشخيص الشامل: $diagnostics');

      // اختبار الصلاحيات أولاً
      AppLogger.info('🧪 اختبار صلاحيات الحذف...');
      final testResult = await _service.testDeleteOperation();
      AppLogger.info('📊 نتائج اختبار الصلاحيات: $testResult');

      final success = await _service.clearAllDispatchRequests();

      if (success) {
        // مسح البيانات المحلية
        _dispatchRequests.clear();
        _filteredRequests.clear();

        AppLogger.info('✅ تم مسح جميع طلبات الصرف بنجاح');
        return true;
      } else {
        _setError('فشل في مسح طلبات الصرف');
        return false;
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في مسح طلبات الصرف: $e');
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// الحصول على عدد طلبات الصرف الحالية
  Future<int> getDispatchRequestsCount() async {
    try {
      return await _service.getDispatchRequestsCount();
    } catch (e) {
      AppLogger.error('❌ خطأ في الحصول على عدد طلبات الصرف: $e');
      return 0;
    }
  }

  @override
  void dispose() {
    reset();
    super.dispose();
  }
}
