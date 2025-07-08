import 'package:flutter/material.dart';
import 'package:smartbiztracker_new/models/manufacturing/production_batch.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:smartbiztracker_new/utils/accountant_theme_config.dart';

/// معالج الحالات الاستثنائية لأدوات التصنيع
class ManufacturingToolsEdgeCasesHandler {
  
  /// معالجة حالة تجاوز الإنتاج للهدف المطلوب
  static ProductionGapAnalysis handleOverProduction(ProductionGapAnalysis gapAnalysis) {
    AppLogger.info('🔄 Handling over-production case');
    
    if (gapAnalysis.currentProduction > gapAnalysis.targetQuantity) {
      final overProducedAmount = gapAnalysis.currentProduction - gapAnalysis.targetQuantity;
      
      return ProductionGapAnalysis(
        productId: gapAnalysis.productId,
        productName: gapAnalysis.productName,
        currentProduction: gapAnalysis.currentProduction,
        targetQuantity: gapAnalysis.targetQuantity,
        remainingPieces: -overProducedAmount, // سالب للإشارة إلى الإنتاج الزائد
        completionPercentage: (gapAnalysis.currentProduction / gapAnalysis.targetQuantity) * 100,
        isOverProduced: true,
        isCompleted: true,
        estimatedCompletionDate: gapAnalysis.estimatedCompletionDate,
      );
    }
    
    return gapAnalysis;
  }

  /// معالجة حالة عدم وجود قطع متبقية
  static RequiredToolsForecast? handleZeroRemainingPieces(double remainingPieces) {
    AppLogger.info('🔄 Handling zero remaining pieces case');
    
    if (remainingPieces <= 0) {
      return RequiredToolsForecast(
        productId: 0,
        remainingPieces: 0,
        requiredTools: [],
        canCompleteProduction: true,
        unavailableTools: [],
        totalCost: 0,
      );
    }
    
    return null;
  }

  /// معالجة حالة عدم وجود بيانات أدوات
  static List<ToolUsageAnalytics> handleMissingToolData(int batchId) {
    AppLogger.warning('⚠️ No tool data found for batch: $batchId');
    
    return [
      ToolUsageAnalytics(
        toolId: -1,
        toolName: 'لا توجد بيانات أدوات',
        unit: 'غير محدد',
        quantityUsedPerUnit: 0,
        totalQuantityUsed: 0,
        remainingStock: 0,
        initialStock: 0,
        usagePercentage: 0,
        stockStatus: 'unknown',
        usageHistory: [],
      ),
    ];
  }

  /// معالجة حالة البيانات التالفة أو غير المكتملة
  static ToolUsageAnalytics sanitizeToolAnalytics(ToolUsageAnalytics analytics) {
    AppLogger.info('🧹 Sanitizing tool analytics data');
    
    return ToolUsageAnalytics(
      toolId: analytics.toolId,
      toolName: analytics.toolName.isEmpty ? 'أداة غير محددة' : analytics.toolName,
      unit: analytics.unit.isEmpty ? 'وحدة' : analytics.unit,
      quantityUsedPerUnit: analytics.quantityUsedPerUnit.isNaN || analytics.quantityUsedPerUnit < 0 
          ? 0 : analytics.quantityUsedPerUnit,
      totalQuantityUsed: analytics.totalQuantityUsed.isNaN || analytics.totalQuantityUsed < 0 
          ? 0 : analytics.totalQuantityUsed,
      remainingStock: analytics.remainingStock.isNaN || analytics.remainingStock < 0 
          ? 0 : analytics.remainingStock,
      initialStock: analytics.initialStock.isNaN || analytics.initialStock < 0 
          ? analytics.totalQuantityUsed + analytics.remainingStock : analytics.initialStock,
      usagePercentage: analytics.usagePercentage.isNaN || analytics.usagePercentage < 0 
          ? 0 : analytics.usagePercentage.clamp(0, 100),
      stockStatus: _sanitizeStockStatus(analytics.stockStatus),
      usageHistory: analytics.usageHistory,
    );
  }

  /// معالجة حالة فشل تحميل البيانات
  static Widget buildErrorFallbackWidget({
    required String title,
    required String message,
    VoidCallback? onRetry,
    IconData icon = Icons.error_outline,
    Color? color,
  }) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: AccountantThemeConfig.glowBorder(
          (color ?? Colors.red).withOpacity(0.3)
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: (color ?? Colors.red).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 48,
              color: color ?? Colors.red,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: Icon(Icons.refresh),
              label: Text('إعادة المحاولة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: color ?? Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// معالجة حالة البيانات الفارغة
  static Widget buildEmptyDataWidget({
    required String title,
    required String message,
    VoidCallback? onAction,
    String? actionLabel,
    IconData icon = Icons.inbox_outlined,
  }) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: AccountantThemeConfig.cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: AccountantThemeConfig.glowBorder(Colors.white.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 48,
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: AccountantThemeConfig.headlineSmall.copyWith(
              color: Colors.white54,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: AccountantThemeConfig.bodyMedium.copyWith(
              color: Colors.white38,
            ),
            textAlign: TextAlign.center,
          ),
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAction,
              icon: Icon(Icons.add),
              label: Text(actionLabel),
              style: AccountantThemeConfig.primaryButtonStyle,
            ),
          ],
        ],
      ),
    );
  }

  /// معالجة حالة انتهاء مهلة الطلب
  static Widget buildTimeoutWidget({
    required VoidCallback onRetry,
  }) {
    return buildErrorFallbackWidget(
      title: 'انتهت مهلة الطلب',
      message: 'استغرق تحميل البيانات وقتاً أطول من المتوقع. يرجى المحاولة مرة أخرى.',
      onRetry: onRetry,
      icon: Icons.access_time,
      color: Colors.orange,
    );
  }

  /// معالجة حالة عدم وجود اتصال بالإنترنت
  static Widget buildNoConnectionWidget({
    required VoidCallback onRetry,
  }) {
    return buildErrorFallbackWidget(
      title: 'لا يوجد اتصال بالإنترنت',
      message: 'تحقق من اتصالك بالإنترنت وحاول مرة أخرى.',
      onRetry: onRetry,
      icon: Icons.wifi_off,
      color: Colors.grey,
    );
  }

  /// معالجة حالة خطأ في الخادم
  static Widget buildServerErrorWidget({
    required VoidCallback onRetry,
    String? errorCode,
  }) {
    return buildErrorFallbackWidget(
      title: 'خطأ في الخادم',
      message: errorCode != null 
          ? 'حدث خطأ في الخادم (رمز الخطأ: $errorCode). يرجى المحاولة لاحقاً.'
          : 'حدث خطأ في الخادم. يرجى المحاولة لاحقاً.',
      onRetry: onRetry,
      icon: Icons.dns,
      color: Colors.red,
    );
  }

  /// معالجة حالة عدم وجود صلاحيات
  static Widget buildPermissionDeniedWidget() {
    return buildErrorFallbackWidget(
      title: 'غير مصرح',
      message: 'ليس لديك صلاحية للوصول إلى هذه البيانات.',
      icon: Icons.lock,
      color: Colors.amber,
    );
  }

  /// معالجة القيم الشاذة في البيانات
  static double sanitizeNumericValue(double value, {
    double defaultValue = 0.0,
    double? min,
    double? max,
  }) {
    if (value.isNaN || value.isInfinite) {
      AppLogger.warning('⚠️ Invalid numeric value detected, using default: $defaultValue');
      return defaultValue;
    }
    
    if (min != null && value < min) {
      AppLogger.warning('⚠️ Value below minimum ($value < $min), clamping to $min');
      return min;
    }
    
    if (max != null && value > max) {
      AppLogger.warning('⚠️ Value above maximum ($value > $max), clamping to $max');
      return max;
    }
    
    return value;
  }

  /// معالجة النصوص الفارغة أو null
  static String sanitizeStringValue(String? value, {
    String defaultValue = 'غير محدد',
    bool trimWhitespace = true,
  }) {
    if (value == null || value.isEmpty) {
      return defaultValue;
    }
    
    final sanitized = trimWhitespace ? value.trim() : value;
    return sanitized.isEmpty ? defaultValue : sanitized;
  }

  /// معالجة التواريخ غير الصحيحة
  static DateTime sanitizeDateValue(DateTime? date, {
    DateTime? defaultDate,
    DateTime? minDate,
    DateTime? maxDate,
  }) {
    final now = DateTime.now();
    final fallbackDate = defaultDate ?? now;
    
    if (date == null) {
      return fallbackDate;
    }
    
    if (minDate != null && date.isBefore(minDate)) {
      AppLogger.warning('⚠️ Date before minimum, using minimum date');
      return minDate;
    }
    
    if (maxDate != null && date.isAfter(maxDate)) {
      AppLogger.warning('⚠️ Date after maximum, using maximum date');
      return maxDate;
    }
    
    return date;
  }

  /// تنظيف حالة المخزون
  static String _sanitizeStockStatus(String status) {
    final normalizedStatus = status.toLowerCase().trim();

    switch (normalizedStatus) {
      case 'high':
      case 'عالي':
        return 'high';
      case 'medium':
      case 'متوسط':
        return 'medium';
      case 'low':
      case 'منخفض':
        return 'low';
      case 'critical':
      case 'حرج':
        return 'critical';
      case 'out_of_stock':
      case 'نفد المخزون':
        return 'critical';
      case 'completed':
      case 'مكتمل':
        return 'high'; // Map completed to high status for UI consistency
      default:
        AppLogger.warning('⚠️ Unknown stock status: $status, defaulting to medium');
        return 'medium';
    }
  }

  /// معالجة حالة البيانات المتضاربة
  static Map<String, dynamic> resolveDataConflicts(
    Map<String, dynamic> data1,
    Map<String, dynamic> data2,
    {String strategy = 'latest'}
  ) {
    AppLogger.info('🔄 Resolving data conflicts using strategy: $strategy');
    
    switch (strategy) {
      case 'latest':
        // استخدام البيانات الأحدث (data2)
        return {...data1, ...data2};
      case 'merge':
        // دمج البيانات مع الحفاظ على القيم غير null
        final merged = <String, dynamic>{};
        final allKeys = {...data1.keys, ...data2.keys};
        
        for (final key in allKeys) {
          if (data2.containsKey(key) && data2[key] != null) {
            merged[key] = data2[key];
          } else if (data1.containsKey(key) && data1[key] != null) {
            merged[key] = data1[key];
          }
        }
        
        return merged;
      case 'conservative':
        // استخدام البيانات الأقدم (data1) مع إضافة المفاتيح الجديدة فقط
        final result = Map<String, dynamic>.from(data1);
        for (final key in data2.keys) {
          if (!result.containsKey(key)) {
            result[key] = data2[key];
          }
        }
        return result;
      default:
        AppLogger.warning('⚠️ Unknown conflict resolution strategy: $strategy');
        return data1;
    }
  }
}
