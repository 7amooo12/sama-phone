import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:smartbiztracker_new/services/supabase_service.dart';

/// Currency Conversion Service for Import Analysis
/// Handles real-time currency conversion with EGP as target currency
class CurrencyConversionService {
  static const String _cacheKey = 'currency_rates_cache';
  static const Duration _cacheExpiry = Duration(minutes: 15);
  static DateTime? _lastCacheUpdate;
  static Map<String, double>? _cachedRates;
  
  /// Get current exchange rate from RMB to EGP
  static Future<double> getRmbToEgpRate() async {
    try {
      // Check cache first
      if (_isCacheValid()) {
        final rate = _cachedRates?['RMB_TO_EGP'];
        if (rate != null) {
          AppLogger.info('استخدام سعر الصرف المحفوظ: $rate');
          return rate;
        }
      }
      
      // Try to get from database first
      final dbRate = await _getRateFromDatabase('RMB', 'EGP');
      if (dbRate != null) {
        _updateCache('RMB_TO_EGP', dbRate);
        return dbRate;
      }
      
      // Try to get from API
      final apiRate = await _getRateFromAPI('RMB', 'EGP');
      if (apiRate != null) {
        // Save to database for future use
        await _saveRateToDatabase('RMB', 'EGP', apiRate);
        _updateCache('RMB_TO_EGP', apiRate);
        return apiRate;
      }
      
      // Fallback to default rate
      const fallbackRate = 6.85; // Default RMB to EGP rate
      AppLogger.warning('استخدام سعر الصرف الافتراضي: $fallbackRate');
      _updateCache('RMB_TO_EGP', fallbackRate);
      return fallbackRate;
      
    } catch (e) {
      AppLogger.error('خطأ في الحصول على سعر الصرف: $e');
      // Return fallback rate
      return 6.85;
    }
  }
  
  /// Get exchange rate from database
  static Future<double?> _getRateFromDatabase(String baseCurrency, String targetCurrency) async {
    try {
      final supabaseService = SupabaseService();

      // Use the existing database methods from SupabaseService
      final records = await supabaseService.getRecordsByFilter(
        'currency_rates',
        'base_currency',
        baseCurrency
      );

      // Filter by target currency and get the most recent rate
      final filteredRecords = records.where((record) =>
        record['target_currency'] == targetCurrency
      ).toList();

      if (filteredRecords.isNotEmpty) {
        // Sort by rate_date descending to get the most recent
        filteredRecords.sort((a, b) {
          final dateA = DateTime.tryParse(a['rate_date'] ?? '') ?? DateTime(1970);
          final dateB = DateTime.tryParse(b['rate_date'] ?? '') ?? DateTime(1970);
          return dateB.compareTo(dateA);
        });

        final mostRecent = filteredRecords.first;
        return (mostRecent['rate'] as num).toDouble();
      }

      return null;
    } catch (e) {
      AppLogger.error('خطأ في الحصول على سعر الصرف من قاعدة البيانات: $e');
      return null;
    }
  }
  
  /// Get exchange rate from API
  static Future<double?> _getRateFromAPI(String baseCurrency, String targetCurrency) async {
    try {
      // Using a free currency API (you can replace with your preferred API)
      final url = 'https://api.exchangerate-api.com/v4/latest/$baseCurrency';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rates = data['rates'] as Map<String, dynamic>;
        
        if (rates.containsKey(targetCurrency)) {
          final rate = (rates[targetCurrency] as num).toDouble();
          AppLogger.info('تم الحصول على سعر الصرف من API: $rate');
          return rate;
        }
      }
      
      return null;
    } catch (e) {
      AppLogger.error('خطأ في الحصول على سعر الصرف من API: $e');
      return null;
    }
  }
  
  /// Save exchange rate to database
  static Future<void> _saveRateToDatabase(String baseCurrency, String targetCurrency, double rate) async {
    try {
      final supabaseService = SupabaseService();

      // التحقق من حدود قاعدة البيانات DECIMAL(15,6)
      const maxRate = 999999999.999999;
      const minRate = -999999999.999999;

      if (rate > maxRate || rate < minRate) {
        AppLogger.warning('سعر الصرف $baseCurrency إلى $targetCurrency يتجاوز حدود قاعدة البيانات: $rate');
        throw Exception('سعر الصرف غير صالح: $rate');
      }

      // Use the existing database methods from SupabaseService
      final rateData = {
        'base_currency': baseCurrency,
        'target_currency': targetCurrency,
        'rate': rate,
        'rate_date': DateTime.now().toIso8601String().split('T')[0],
        'rate_source': 'api',
        'api_provider': 'exchangerate-api',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Check if record exists
      final existingRecords = await supabaseService.getRecordsByFilter(
        'currency_rates',
        'base_currency',
        baseCurrency
      );

      final existingRecord = existingRecords.where((record) =>
        record['target_currency'] == targetCurrency &&
        record['rate_date'] == rateData['rate_date']
      ).firstOrNull;

      if (existingRecord != null) {
        // Update existing record
        await supabaseService.updateRecord(
          'currency_rates',
          existingRecord['id'],
          rateData
        );
      } else {
        // Create new record
        await supabaseService.createRecord('currency_rates', rateData);
      }

      AppLogger.info('تم حفظ سعر الصرف في قاعدة البيانات');
    } catch (e) {
      AppLogger.error('خطأ في حفظ سعر الصرف: $e');
    }
  }
  
  /// Check if cache is valid
  static bool _isCacheValid() {
    if (_lastCacheUpdate == null || _cachedRates == null) {
      return false;
    }
    
    return DateTime.now().difference(_lastCacheUpdate!).compareTo(_cacheExpiry) < 0;
  }
  
  /// Update cache
  static void _updateCache(String key, double rate) {
    _cachedRates ??= {};
    _cachedRates![key] = rate;
    _lastCacheUpdate = DateTime.now();
  }
  
  /// Convert RMB amount to EGP
  static Future<double> convertRmbToEgp(double rmbAmount) async {
    final rate = await getRmbToEgpRate();
    return rmbAmount * rate;
  }
  
  /// Convert multiple amounts
  static Future<Map<String, double>> convertMultipleAmounts(Map<String, double> amounts) async {
    final rate = await getRmbToEgpRate();
    final converted = <String, double>{};
    
    for (final entry in amounts.entries) {
      converted[entry.key] = entry.value * rate;
    }
    
    return converted;
  }
  
  /// Get formatted currency string
  static String formatEgpCurrency(double amount) {
    return '${amount.toStringAsFixed(2)} ج.م';
  }
  
  /// Get formatted RMB currency string
  static String formatRmbCurrency(double amount) {
    return '¥${amount.toStringAsFixed(2)}';
  }
  
  /// Get all supported currency pairs
  static List<Map<String, String>> getSupportedCurrencyPairs() {
    return [
      {'base': 'RMB', 'target': 'EGP', 'name': 'يوان صيني إلى جنيه مصري'},
      {'base': 'RMB', 'target': 'USD', 'name': 'يوان صيني إلى دولار أمريكي'},
      {'base': 'RMB', 'target': 'SAR', 'name': 'يوان صيني إلى ريال سعودي'},
      {'base': 'USD', 'target': 'EGP', 'name': 'دولار أمريكي إلى جنيه مصري'},
      {'base': 'USD', 'target': 'SAR', 'name': 'دولار أمريكي إلى ريال سعودي'},
      {'base': 'SAR', 'target': 'EGP', 'name': 'ريال سعودي إلى جنيه مصري'},
    ];
  }
  
  /// Clear cache
  static void clearCache() {
    _cachedRates = null;
    _lastCacheUpdate = null;
    AppLogger.info('تم مسح ذاكرة التخزين المؤقت لأسعار الصرف');
  }
  
  /// Get cache status
  static Map<String, dynamic> getCacheStatus() {
    return {
      'is_valid': _isCacheValid(),
      'last_update': _lastCacheUpdate?.toIso8601String(),
      'cached_rates_count': _cachedRates?.length ?? 0,
      'expires_in_minutes': _lastCacheUpdate != null 
          ? _cacheExpiry.inMinutes - DateTime.now().difference(_lastCacheUpdate!).inMinutes
          : 0,
    };
  }
}
