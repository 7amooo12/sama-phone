import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../models/voucher_model.dart';
import '../models/client_voucher_model.dart';
import '../services/voucher_service.dart';
import '../services/supabase_service.dart';
import '../utils/app_logger.dart';

class VoucherProvider extends ChangeNotifier {
  final VoucherService _voucherService = VoucherService();
  final SupabaseService _supabaseService = SupabaseService();

  // State variables
  List<VoucherModel> _vouchers = [];
  List<ClientVoucherModel> _clientVouchers = [];
  List<ClientVoucherModel> _allClientVouchers = [];
  List<String> _productCategories = [];
  List<Map<String, dynamic>> _products = [];
  Map<String, dynamic> _statistics = {};

  bool _isLoading = false;
  bool _isCreating = false;
  bool _isAssigning = false;
  String? _error;
  bool _mounted = true;

  // Getters
  List<VoucherModel> get vouchers => _vouchers;
  List<ClientVoucherModel> get clientVouchers => _clientVouchers;
  List<ClientVoucherModel> get allClientVouchers => _allClientVouchers;
  List<String> get productCategories => _productCategories;
  List<Map<String, dynamic>> get products => _products;
  Map<String, dynamic> get statistics => _statistics;

  bool get isLoading => _isLoading;
  bool get isCreating => _isCreating;
  bool get isAssigning => _isAssigning;
  String? get error => _error;
  bool get mounted => _mounted;

  // Filtered getters
  List<VoucherModel> get activeVouchers => _vouchers.where((v) => v.isValid).toList();
  List<VoucherModel> get expiredVouchers => _vouchers.where((v) => v.isExpired).toList();
  List<VoucherModel> get inactiveVouchers => _vouchers.where((v) => !v.isActive).toList();

  List<ClientVoucherModel> get activeClientVouchers =>
      _clientVouchers.where((cv) => cv.status == ClientVoucherStatus.active).toList();
  List<ClientVoucherModel> get usedClientVouchers =>
      _clientVouchers.where((cv) => cv.status == ClientVoucherStatus.used).toList();
  List<ClientVoucherModel> get expiredClientVouchers =>
      _clientVouchers.where((cv) => cv.status == ClientVoucherStatus.expired).toList();

  // Safe getters that only return vouchers with valid voucher data
  List<ClientVoucherModel> get validActiveClientVouchers =>
      _clientVouchers.where((cv) => cv.status == ClientVoucherStatus.active && cv.voucher != null).toList();
  List<ClientVoucherModel> get validUsedClientVouchers =>
      _clientVouchers.where((cv) => cv.status == ClientVoucherStatus.used && cv.voucher != null).toList();
  List<ClientVoucherModel> get validExpiredClientVouchers =>
      _clientVouchers.where((cv) => cv.status == ClientVoucherStatus.expired && cv.voucher != null).toList();

  // Getters for vouchers with missing data (for debugging/error handling)
  List<ClientVoucherModel> get invalidClientVouchers =>
      _clientVouchers.where((cv) => cv.voucher == null).toList();

  // ============================================================================
  // VOUCHER MANAGEMENT
  // ============================================================================

  /// Load all vouchers
  Future<void> loadVouchers() async {
    _setLoading(true);
    _clearError();

    try {
      AppLogger.info('Loading vouchers...');
      _vouchers = await _voucherService.getAllVouchers();
      AppLogger.info('Loaded ${_vouchers.length} vouchers');
    } catch (e) {
      _setError('فشل في تحميل القسائم: ${e.toString()}');
      AppLogger.error('Error loading vouchers: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Load active vouchers only
  Future<void> loadActiveVouchers() async {
    _setLoading(true);
    _clearError();

    try {
      AppLogger.info('Loading active vouchers...');
      _vouchers = await _voucherService.getActiveVouchers();
      AppLogger.info('Loaded ${_vouchers.length} active vouchers');
    } catch (e) {
      _setError('فشل في تحميل القسائم النشطة: ${e.toString()}');
      AppLogger.error('Error loading active vouchers: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Create new voucher
  Future<VoucherModel?> createVoucher(VoucherCreateRequest request) async {
    _setCreating(true);
    _clearError();

    try {
      AppLogger.info('Creating voucher: ${request.name}');
      final voucher = await _voucherService.createVoucher(request);

      if (voucher != null) {
        _vouchers.insert(0, voucher);
        AppLogger.info('Voucher created successfully: ${voucher.code}');
        notifyListeners();
        return voucher;
      } else {
        _setError('فشل في إنشاء القسيمة - تحقق من صحة البيانات');
        return null;
      }
    } catch (e) {
      // Handle specific authentication errors
      if (e.toString().contains('المستخدم غير مسجل الدخول') ||
          e.toString().contains('not authenticated')) {
        _setError('يجب تسجيل الدخول أولاً لإنشاء القسائم');
      } else if (e.toString().contains('created_by') ||
                 e.toString().contains('23502')) {
        _setError('خطأ في المصادقة - يرجى تسجيل الدخول مرة أخرى');
      } else {
        _setError('خطأ في إنشاء القسيمة: ${e.toString()}');
      }
      AppLogger.error('Error creating voucher: $e');
      return null;
    } finally {
      _setCreating(false);
    }
  }

  /// Update voucher
  Future<bool> updateVoucher(String voucherId, VoucherUpdateRequest request) async {
    _setLoading(true);
    _clearError();

    try {
      AppLogger.info('Updating voucher: $voucherId');
      final updatedVoucher = await _voucherService.updateVoucher(voucherId, request);
      
      if (updatedVoucher != null) {
        final index = _vouchers.indexWhere((v) => v.id == voucherId);
        if (index != -1) {
          _vouchers[index] = updatedVoucher;
          notifyListeners();
        }
        AppLogger.info('Voucher updated successfully');
        return true;
      } else {
        _setError('فشل في تحديث القسيمة');
        return false;
      }
    } catch (e) {
      _setError('خطأ في تحديث القسيمة: ${e.toString()}');
      AppLogger.error('Error updating voucher: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Delete voucher with enhanced constraint handling and force option
  Future<Map<String, dynamic>> deleteVoucher(String voucherId, {bool forceDelete = false}) async {
    _setLoading(true);
    _clearError();

    try {
      AppLogger.info('Deleting voucher: $voucherId (force: $forceDelete)');
      final result = await _voucherService.deleteVoucher(voucherId, forceDelete: forceDelete);

      if (result['success'] == true) {
        _vouchers.removeWhere((v) => v.id == voucherId);
        notifyListeners();
        AppLogger.info('Voucher deleted successfully');
      } else {
        _setError(result['message']?.toString() ?? 'فشل في حذف القسيمة');
      }

      return result;
    } catch (e) {
      final errorMessage = 'خطأ في حذف القسيمة: ${e.toString()}';
      _setError(errorMessage);
      AppLogger.error('Error deleting voucher: $e');
      return {
        'success': false,
        'canDelete': false,
        'reason': 'provider_error',
        'message': errorMessage,
        'error': e.toString(),
      };
    } finally {
      _setLoading(false);
    }
  }

  /// Delete all vouchers (BULK DELETION)
  Future<Map<String, dynamic>> deleteAllVouchers({bool forceDelete = false}) async {
    _setLoading(true);
    _clearError();

    try {
      AppLogger.info('🚨 Deleting all vouchers (force: $forceDelete)');
      final result = await _voucherService.deleteAllVouchers(forceDelete: forceDelete);

      if (result['success'] == true) {
        _vouchers.clear();
        _allClientVouchers.clear();
        AppLogger.info('All vouchers deleted successfully');
        notifyListeners();
      } else {
        _setError(result['message']?.toString() ?? 'فشل في حذف جميع القسائم');
      }

      return result;
    } catch (e) {
      final errorMessage = 'خطأ في حذف جميع القسائم: ${e.toString()}';
      _setError(errorMessage);
      AppLogger.error('Error deleting all vouchers: $e');
      return {
        'success': false,
        'canDelete': false,
        'reason': 'provider_error',
        'message': errorMessage,
        'error': e.toString(),
      };
    } finally {
      _setLoading(false);
    }
  }

  /// Deactivate voucher instead of deleting it
  Future<bool> deactivateVoucher(String voucherId) async {
    _setLoading(true);
    _clearError();

    try {
      AppLogger.info('Deactivating voucher: $voucherId');
      final success = await _voucherService.deactivateVoucher(voucherId);

      if (success) {
        // Update the voucher in the local list
        final voucherIndex = _vouchers.indexWhere((v) => v.id == voucherId);
        if (voucherIndex != -1) {
          _vouchers[voucherIndex] = _vouchers[voucherIndex].copyWith(isActive: false);
          notifyListeners();
        }
        AppLogger.info('Voucher deactivated successfully');
        return true;
      } else {
        _setError('فشل في إلغاء تفعيل القسيمة');
        return false;
      }
    } catch (e) {
      _setError('خطأ في إلغاء تفعيل القسيمة: ${e.toString()}');
      AppLogger.error('Error deactivating voucher: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }



  // ============================================================================
  // CLIENT VOUCHER MANAGEMENT
  // ============================================================================

  /// Assign vouchers to clients with enhanced error handling and widget lifecycle safety
  Future<bool> assignVouchersToClients(String voucherId, List<String> clientIds) async {
    // Check if we're still mounted before starting
    if (!mounted) {
      AppLogger.warning('⚠️ Provider not mounted - skipping voucher assignment');
      return false;
    }

    _setAssigning(true);
    _clearError();

    try {
      AppLogger.info('🔄 Starting voucher assignment in provider...');
      AppLogger.info('   - Voucher ID: $voucherId');
      AppLogger.info('   - Client IDs: $clientIds');

      final request = ClientVoucherAssignRequest(
        voucherId: voucherId,
        clientIds: clientIds,
      );

      final assignedVouchers = await _voucherService.assignVouchersToClients(request);

      // Check if we're still mounted before updating state
      if (!mounted) {
        AppLogger.warning('⚠️ Provider unmounted during assignment - operation completed but UI not updated');
        return assignedVouchers.isNotEmpty;
      }

      if (assignedVouchers.isNotEmpty) {
        AppLogger.info('✅ Voucher assignment successful in service');

        // Add to all client vouchers list
        _allClientVouchers.insertAll(0, assignedVouchers);

        // Refresh the voucher list to ensure we have the latest data
        AppLogger.info('🔄 Refreshing voucher data after assignment...');

        try {
          await loadAllClientVouchers();
        } catch (e) {
          AppLogger.warning('⚠️ Failed to refresh voucher data after assignment: $e');
          // Continue anyway - assignment was successful
        }

        // Check if we're still mounted before notifying listeners
        if (mounted) {
          notifyListeners();
        }

        AppLogger.info('🎉 Vouchers assigned successfully to ${assignedVouchers.length} clients');

        // Log assignment details for verification
        for (final assignment in assignedVouchers) {
          AppLogger.info('   ✓ Assignment: ${assignment.id} - Client: ${assignment.clientName ?? assignment.clientId}');
        }

        return true;
      } else {
        AppLogger.error('❌ No vouchers were assigned - service returned empty list');
        if (mounted) {
          _setError('فشل في تعيين القسائم للعملاء - لم يتم إنشاء أي تعيينات');
        }
        return false;
      }
    } catch (e) {
      AppLogger.error('❌ Error in voucher assignment: $e');

      // Only update error state if still mounted
      if (mounted) {
        // Handle specific authentication errors
        if (e.toString().contains('المستخدم غير مسجل الدخول') ||
            e.toString().contains('not authenticated')) {
          _setError('يجب تسجيل الدخول أولاً لتعيين القسائم');
        } else if (e.toString().contains('ليس لديك صلاحية')) {
          _setError('ليس لديك صلاحية لتعيين القسائم - تحقق من دورك في النظام');
        } else if (e.toString().contains('القسيمة غير موجودة')) {
          _setError('القسيمة المحددة غير موجودة أو تم حذفها');
        } else if (e.toString().contains('القسيمة غير نشطة')) {
          _setError('القسيمة غير نشطة - لا يمكن تعيينها للعملاء');
        } else if (e.toString().contains('القسيمة منتهية الصلاحية')) {
          _setError('القسيمة منتهية الصلاحية - لا يمكن تعيينها للعملاء');
        } else if (e.toString().contains('لا يوجد عملاء صالحين')) {
          _setError('العملاء المحددون غير صالحين أو غير موافق عليهم');
        } else if (e.toString().contains('تم تعيين هذه القسيمة')) {
          _setError('تم تعيين هذه القسيمة لبعض العملاء مسبقاً');
        } else if (e.toString().contains('assigned_by') ||
                   e.toString().contains('23502')) {
          _setError('خطأ في المصادقة - يرجى تسجيل الدخول مرة أخرى');
        } else {
          _setError('خطأ في تعيين القسائم: ${e.toString()}');
        }
      }

      return false;
    } finally {
      // Only update loading state if still mounted
      if (mounted) {
        _setAssigning(false);
      }
    }
  }

  /// Load client vouchers for specific client with enhanced null safety
  Future<void> loadClientVouchers(String clientId) async {
    _setLoading(true);
    _clearError();

    try {
      // Validate client ID
      if (clientId.isEmpty) {
        AppLogger.error('Cannot load vouchers: Client ID is empty');
        _setError('معرف العميل غير صالح');
        return;
      }

      AppLogger.info('🔄 Loading vouchers for client: $clientId');

      // Add authentication verification
      final currentUser = _supabaseService.currentUser;
      AppLogger.info('🔐 Current authenticated user: ${currentUser?.id} (${currentUser?.email})');

      if (currentUser?.id != clientId) {
        AppLogger.warning('⚠️ User ID mismatch: authenticated=${currentUser?.id}, requested=$clientId');
      }

      final allVouchers = await _voucherService.getClientVouchers(clientId);

      // Enhanced logging for debugging
      AppLogger.info('📊 Raw vouchers received: ${allVouchers.length}');

      // Categorize vouchers by status
      final activeVouchers = allVouchers.where((v) => v.status == ClientVoucherStatus.active).toList();
      final usedVouchers = allVouchers.where((v) => v.status == ClientVoucherStatus.used).toList();
      final expiredVouchers = allVouchers.where((v) => v.status == ClientVoucherStatus.expired).toList();

      AppLogger.info('📋 Voucher breakdown: Active=${activeVouchers.length}, Used=${usedVouchers.length}, Expired=${expiredVouchers.length}');

      // Filter out unsafe vouchers for UI rendering
      final safeVouchers = allVouchers.where((voucher) => voucher.isSafeForUI).toList();
      final unsafeCount = allVouchers.length - safeVouchers.length;

      _clientVouchers = safeVouchers;

      AppLogger.info('✅ Loaded ${_clientVouchers.length} safe vouchers for client');
      if (unsafeCount > 0) {
        AppLogger.warning('⚠️ Filtered out $unsafeCount unsafe vouchers from UI');
        AppLogger.warning('💡 Unsafe vouchers have null/invalid data and could cause UI crashes');
      }

      // Log detailed voucher information for debugging
      for (final voucher in _clientVouchers) {
        AppLogger.info('📄 Voucher: ${voucher.id} - ${voucher.voucher?.name ?? 'NULL'} (${voucher.status.value})');
      }

      // Defer notification to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    } catch (e) {
      _setError('فشل في تحميل قسائم العميل: ${e.toString()}');
      AppLogger.error('❌ Error loading client vouchers: $e');
      // Ensure we have an empty list on error
      _clientVouchers = [];
    } finally {
      _setLoading(false);
    }
  }

  /// Load all client voucher assignments with enhanced null safety
  Future<void> loadAllClientVouchers() async {
    _setLoading(true);
    _clearError();

    try {
      AppLogger.info('🔄 Loading all client voucher assignments...');
      final allVouchers = await _voucherService.getAllClientVouchers();

      // Filter out unsafe vouchers for UI rendering
      final safeVouchers = allVouchers.where((voucher) => voucher.isSafeForUI).toList();
      final unsafeCount = allVouchers.length - safeVouchers.length;

      _allClientVouchers = safeVouchers;

      AppLogger.info('✅ Loaded ${_allClientVouchers.length} safe client voucher assignments');
      if (unsafeCount > 0) {
        AppLogger.warning('⚠️ Filtered out $unsafeCount unsafe vouchers from admin UI');
      }

      // Defer notification to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    } catch (e) {
      _setError('فشل في تحميل تعيينات القسائم: ${e.toString()}');
      AppLogger.error('❌ Error loading all client vouchers: $e');
      // Ensure we have an empty list on error
      _allClientVouchers = [];
    } finally {
      _setLoading(false);
    }
  }

  /// Use voucher
  Future<bool> useVoucher(String clientVoucherId, String orderId, double discountAmount) async {
    _setLoading(true);
    _clearError();

    try {
      AppLogger.info('Using voucher: $clientVoucherId');
      
      final request = VoucherUsageRequest(
        clientVoucherId: clientVoucherId,
        orderId: orderId,
        discountAmount: discountAmount,
      );
      
      final usedVoucher = await _voucherService.useVoucher(request);
      
      if (usedVoucher != null) {
        // Update in client vouchers list
        final index = _clientVouchers.indexWhere((cv) => cv.id == clientVoucherId);
        if (index != -1) {
          _clientVouchers[index] = usedVoucher;
        }
        
        // Update in all client vouchers list
        final allIndex = _allClientVouchers.indexWhere((cv) => cv.id == clientVoucherId);
        if (allIndex != -1) {
          _allClientVouchers[allIndex] = usedVoucher;
        }
        
        notifyListeners();
        AppLogger.info('Voucher used successfully');
        return true;
      } else {
        _setError('فشل في استخدام القسيمة');
        return false;
      }
    } catch (e) {
      _setError('خطأ في استخدام القسيمة: ${e.toString()}');
      AppLogger.error('Error using voucher: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Get applicable vouchers for cart
  Future<List<ClientVoucherModel>> getApplicableVouchers(String clientId, List<Map<String, dynamic>> cartItems) async {
    try {
      AppLogger.info('Getting applicable vouchers for client: $clientId');
      return await _voucherService.getApplicableVouchers(clientId, cartItems);
    } catch (e) {
      AppLogger.error('Error getting applicable vouchers: $e');
      return [];
    }
  }

  /// Calculate voucher discount
  Map<String, dynamic> calculateVoucherDiscount(VoucherModel voucher, List<Map<String, dynamic>> cartItems) {
    return _voucherService.calculateVoucherDiscount(voucher, cartItems);
  }

  // ============================================================================
  // DATA LOADING
  // ============================================================================

  /// Load product categories
  Future<void> loadProductCategories() async {
    try {
      AppLogger.info('Loading product categories...');
      _productCategories = await _voucherService.getProductCategories();
      AppLogger.info('Loaded ${_productCategories.length} product categories');
      notifyListeners();
    } catch (e) {
      AppLogger.error('Error loading product categories: $e');
    }
  }

  /// Load products
  Future<void> loadProducts() async {
    try {
      AppLogger.info('Loading products...');
      _products = await _voucherService.getProductsForVoucher();
      AppLogger.info('Loaded ${_products.length} products');
      notifyListeners();
    } catch (e) {
      AppLogger.error('Error loading products: $e');
    }
  }

  /// Get available products for voucher creation with stock filtering
  Future<List<Map<String, dynamic>>> getAvailableProductsForVoucher({
    bool includeOutOfStock = false,
    bool sortByQuantity = true,
  }) async {
    try {
      AppLogger.info('Getting available products for voucher creation');
      return await _voucherService.getAvailableProductsForVoucher(
        includeOutOfStock: includeOutOfStock,
        sortByQuantity: sortByQuantity,
      );
    } catch (e) {
      AppLogger.error('Error getting available products for voucher: $e');
      return [];
    }
  }

  /// Load statistics
  Future<void> loadStatistics() async {
    try {
      AppLogger.info('Loading voucher statistics...');
      _statistics = await _voucherService.getVoucherStatistics();
      AppLogger.info('Loaded voucher statistics');
      notifyListeners();
    } catch (e) {
      AppLogger.error('Error loading statistics: $e');
    }
  }

  /// Load all data
  Future<void> loadAllData() async {
    await Future.wait([
      loadVouchers(),
      loadProductCategories(),
      loadProducts(),
      loadStatistics(),
    ]);
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /// Clear all data
  void clearData() {
    _vouchers.clear();
    _clientVouchers.clear();
    _allClientVouchers.clear();
    _productCategories.clear();
    _products.clear();
    _statistics.clear();
    _clearError();
    notifyListeners();
  }

  /// Refresh data
  Future<void> refresh() async {
    await loadAllData();
  }

  /// Test voucher loading with specific client ID (for debugging and null safety verification)
  Future<Map<String, dynamic>> testVoucherLoading(String clientId) async {
    final testResult = <String, dynamic>{
      'success': false,
      'error': null,
      'voucherCount': 0,
      'safeVoucherCount': 0,
      'unsafeVoucherCount': 0,
      'nullVoucherCount': 0,
      'details': <String, dynamic>{},
    };

    try {
      AppLogger.info('🧪 Testing voucher loading with null safety for client: $clientId');

      // Test the service directly
      final allVouchers = await _voucherService.getClientVouchers(clientId);

      // Analyze voucher safety
      final safeVouchers = allVouchers.where((v) => v.isSafeForUI).toList();
      final unsafeVouchers = allVouchers.where((v) => !v.isSafeForUI).toList();
      final nullVouchers = allVouchers.where((v) => v.voucher == null).toList();

      testResult['success'] = true;
      testResult['voucherCount'] = allVouchers.length;
      testResult['safeVoucherCount'] = safeVouchers.length;
      testResult['unsafeVoucherCount'] = unsafeVouchers.length;
      testResult['nullVoucherCount'] = nullVouchers.length;
      testResult['details'] = {
        'clientId': clientId,
        'totalVouchers': allVouchers.length,
        'safeVouchers': safeVouchers.length,
        'unsafeVouchers': unsafeVouchers.length,
        'nullVouchers': nullVouchers.length,
        'voucherIds': allVouchers.map((v) => v.id).toList(),
        'voucherStatuses': allVouchers.map((v) => v.status.value).toList(),
        'voucherCodes': allVouchers.map((v) => v.voucherCode).toList(),
        'voucherNames': allVouchers.map((v) => v.voucherName).toList(),
        'safetyStatus': allVouchers.map((v) => v.isSafeForUI).toList(),
        'validityStatus': allVouchers.map((v) => v.isVoucherDataValid).toList(),
      };

      AppLogger.info('✅ Test successful: ${allVouchers.length} total, ${safeVouchers.length} safe, ${unsafeVouchers.length} unsafe');
      if (nullVouchers.isNotEmpty) {
        AppLogger.warning('⚠️ Found ${nullVouchers.length} vouchers with null data');
      }

      return testResult;
    } catch (e) {
      testResult['error'] = e.toString();
      AppLogger.error('❌ Test failed: $e');
      return testResult;
    }
  }

  // ============================================================================
  // PRIVATE METHODS
  // ============================================================================

  void _setLoading(bool loading) {
    _isLoading = loading;
    // Defer notification to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  void _setCreating(bool creating) {
    _isCreating = creating;
    // Defer notification to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  void _setAssigning(bool assigning) {
    _isAssigning = assigning;
    // Defer notification to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  void _setError(String error) {
    _error = error;
    // Defer notification to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  void _clearError() {
    _error = null;
  }

  @override
  void dispose() {
    _mounted = false;
    super.dispose();
  }
}
