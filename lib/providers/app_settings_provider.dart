import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartbiztracker_new/services/flask_api_service.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

class AppSettingsProvider extends ChangeNotifier {

  AppSettingsProvider() {
    _loadSettings();
  }
  final FlaskApiService _apiService = FlaskApiService();

  // Settings state
  bool _showPricesToPublic = true;
  bool _showStockToPublic = true;
  String _storeName = 'SAMA Store';
  String _currencySymbol = 'جنيه';
  bool _isLoading = false;
  String? _error;

  // Pricing approval workflow state
  bool _originalPriceVisibility = true; // Store original setting before hiding prices
  bool _isPricingApprovalMode = false; // Track if we're in pricing approval workflow

  // Getters
  bool get showPricesToPublic => _showPricesToPublic;
  bool get showStockToPublic => _showStockToPublic;
  String get storeName => _storeName;
  String get currencySymbol => _currencySymbol;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isPricingApprovalMode => _isPricingApprovalMode;

  // Load settings from API and cache locally
  Future<void> _loadSettings() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Try to load from API first
      final apiSettings = await _apiService.getSettings();

      if (apiSettings.isNotEmpty) {
        // Parse boolean values correctly
        _showPricesToPublic = _parseBooleanValue(apiSettings['show_prices_to_public']);
        _showStockToPublic = _parseBooleanValue(apiSettings['show_stock_to_public']);
        _storeName = apiSettings['store_name']?.toString() ?? 'SAMA Store';
        _currencySymbol = apiSettings['currency_symbol']?.toString() ?? 'جنيه';

        AppLogger.info('✅ تم تحميل الإعدادات: أسعار=$_showPricesToPublic، مخزون=$_showStockToPublic');

        // Cache settings locally
        await _cacheSettings();
      } else {
        // Fallback to cached settings
        await _loadCachedSettings();
      }
    } catch (e) {
      AppLogger.error('Error loading settings from API', e);
      // Fallback to cached settings
      await _loadCachedSettings();
      _error = 'فشل في تحميل الإعدادات من الخادم';
    }

    _isLoading = false;
    notifyListeners();
  }

  // Load cached settings from SharedPreferences
  Future<void> _loadCachedSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _showPricesToPublic = prefs.getBool('show_prices_to_public') ?? true;
      _showStockToPublic = prefs.getBool('show_stock_to_public') ?? true;
      _storeName = prefs.getString('store_name') ?? 'SAMA Store';
      _currencySymbol = prefs.getString('currency_symbol') ?? 'جنيه';
    } catch (e) {
      AppLogger.error('Error loading cached settings', e);
    }
  }

  // Cache settings locally
  Future<void> _cacheSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('show_prices_to_public', _showPricesToPublic);
      await prefs.setBool('show_stock_to_public', _showStockToPublic);
      await prefs.setString('store_name', _storeName);
      await prefs.setString('currency_symbol', _currencySymbol);
    } catch (e) {
      AppLogger.error('Error caching settings', e);
    }
  }

  // Update price visibility setting (admin only)
  Future<bool> updatePriceVisibility(bool showPrices) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      AppLogger.info('🔧 محاولة تحديث إعدادات الأسعار: $showPrices');

      final success = await _apiService.updateSettings({
        'show_prices_to_public': showPrices,
      });

      if (success) {
        _showPricesToPublic = showPrices;
        await _cacheSettings();
        AppLogger.info('✅ تم تحديث إعدادات الأسعار بنجاح: $showPrices');
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = 'فشل في تحديث إعدادات الأسعار';
        AppLogger.error('❌ فشل في تحديث إعدادات الأسعار');
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في تحديث إعدادات الأسعار: $e');
      _error = 'خطأ في تحديث إعدادات الأسعار';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Update stock visibility setting (admin only)
  Future<bool> updateStockVisibility(bool showStock) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      AppLogger.info('🔧 محاولة تحديث إعدادات المخزون: $showStock');

      final success = await _apiService.updateSettings({
        'show_stock_to_public': showStock,
      });

      if (success) {
        _showStockToPublic = showStock;
        await _cacheSettings();
        AppLogger.info('✅ تم تحديث إعدادات المخزون بنجاح: $showStock');
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = 'فشل في تحديث إعدادات المخزون';
        AppLogger.error('❌ فشل في تحديث إعدادات المخزون');
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      AppLogger.error('❌ خطأ في تحديث إعدادات المخزون: $e');
      _error = 'خطأ في تحديث إعدادات المخزون';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Refresh settings from API
  Future<void> refreshSettings() async {
    await _loadSettings();
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Helper method to parse boolean values from API
  bool _parseBooleanValue(dynamic value) {
    if (value == null) return true; // Default to true

    if (value is bool) return value;

    if (value is String) {
      return value.toLowerCase() == 'true' || value == '1';
    }

    if (value is int) {
      return value == 1;
    }

    return true; // Default fallback
  }

  // ===== PRICING APPROVAL WORKFLOW METHODS =====

  /// Enter pricing approval mode - hide prices temporarily
  Future<void> enterPricingApprovalMode() async {
    if (_isPricingApprovalMode) {
      AppLogger.info('🔒 Already in pricing approval mode');
      return;
    }

    AppLogger.info('🔒 Entering pricing approval mode - hiding prices from customers');

    // Store the original price visibility setting
    _originalPriceVisibility = _showPricesToPublic;
    _isPricingApprovalMode = true;

    // Hide prices from public
    _showPricesToPublic = false;

    // Cache the temporary state
    await _cacheSettings();

    notifyListeners();
  }

  /// Exit pricing approval mode - restore original price visibility
  Future<void> exitPricingApprovalMode() async {
    if (!_isPricingApprovalMode) {
      AppLogger.info('🔓 Not in pricing approval mode');
      return;
    }

    AppLogger.info('🔓 Exiting pricing approval mode - restoring original price visibility: $_originalPriceVisibility');

    // Restore original price visibility
    _showPricesToPublic = _originalPriceVisibility;
    _isPricingApprovalMode = false;

    // Update the setting on the server
    try {
      final success = await _apiService.updateSettings({
        'show_prices_to_public': _showPricesToPublic,
      });

      if (success) {
        AppLogger.info('✅ Successfully restored price visibility on server: $_showPricesToPublic');
      } else {
        AppLogger.error('❌ Failed to restore price visibility on server');
      }
    } catch (e) {
      AppLogger.error('❌ Error restoring price visibility on server: $e');
    }

    // Cache the restored state
    await _cacheSettings();

    notifyListeners();
  }

  /// Temporarily hide prices for pricing approval workflow (local only)
  void hidePricesForPricingApproval() {
    if (!_isPricingApprovalMode) {
      _originalPriceVisibility = _showPricesToPublic;
      _isPricingApprovalMode = true;
    }

    _showPricesToPublic = false;
    AppLogger.info('🔒 Prices hidden for pricing approval workflow');
    notifyListeners();
  }

  /// Restore prices after pricing approval (with server sync)
  Future<void> restorePricesAfterApproval() async {
    if (!_isPricingApprovalMode) {
      AppLogger.info('🔓 Not in pricing approval mode, nothing to restore');
      return;
    }

    AppLogger.info('🔓 Restoring prices after pricing approval: $_originalPriceVisibility');

    // Restore original visibility
    _showPricesToPublic = _originalPriceVisibility;
    _isPricingApprovalMode = false;

    // Update server settings
    try {
      final success = await updatePriceVisibility(_showPricesToPublic);
      if (success) {
        AppLogger.info('✅ Successfully restored price visibility after approval');
      } else {
        AppLogger.error('❌ Failed to restore price visibility after approval');
      }
    } catch (e) {
      AppLogger.error('❌ Error restoring price visibility after approval: $e');
    }
  }
}
