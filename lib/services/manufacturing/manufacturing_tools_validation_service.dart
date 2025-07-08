import 'package:smartbiztracker_new/models/manufacturing/production_batch.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// نتيجة التحقق من صحة البيانات
class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
  final Map<String, dynamic> metadata;

  const ValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
    this.metadata = const {},
  });

  /// إنشاء نتيجة صحيحة
  factory ValidationResult.valid({
    List<String> warnings = const [],
    Map<String, dynamic> metadata = const {},
  }) {
    return ValidationResult(
      isValid: true,
      warnings: warnings,
      metadata: metadata,
    );
  }

  /// إنشاء نتيجة خاطئة
  factory ValidationResult.invalid({
    required List<String> errors,
    List<String> warnings = const [],
    Map<String, dynamic> metadata = const {},
  }) {
    return ValidationResult(
      isValid: false,
      errors: errors,
      warnings: warnings,
      metadata: metadata,
    );
  }

  /// دمج نتائج متعددة
  static ValidationResult merge(List<ValidationResult> results) {
    final allErrors = <String>[];
    final allWarnings = <String>[];
    final allMetadata = <String, dynamic>{};

    for (final result in results) {
      allErrors.addAll(result.errors);
      allWarnings.addAll(result.warnings);
      allMetadata.addAll(result.metadata);
    }

    return ValidationResult(
      isValid: allErrors.isEmpty,
      errors: allErrors,
      warnings: allWarnings,
      metadata: allMetadata,
    );
  }

  /// عدد المشاكل الإجمالي
  int get totalIssues => errors.length + warnings.length;

  /// هل توجد تحذيرات فقط
  bool get hasWarningsOnly => warnings.isNotEmpty && errors.isEmpty;
}

/// خدمة التحقق من صحة بيانات أدوات التصنيع
class ManufacturingToolsValidationService {
  
  /// التحقق من صحة تحليلات استخدام الأدوات
  ValidationResult validateToolUsageAnalytics(List<ToolUsageAnalytics> analytics) {
    try {
      AppLogger.info('🔍 Validating tool usage analytics');

      final errors = <String>[];
      final warnings = <String>[];
      final metadata = <String, dynamic>{};

      if (analytics.isEmpty) {
        warnings.add('لا توجد بيانات تحليلات استخدام الأدوات');
        return ValidationResult.valid(warnings: warnings);
      }

      // التحقق من كل تحليل أداة
      for (int i = 0; i < analytics.length; i++) {
        final analytic = analytics[i];
        final toolErrors = _validateSingleToolAnalytic(analytic, i);
        errors.addAll(toolErrors);
      }

      // التحقق من التكرارات
      final duplicateErrors = _checkForDuplicateTools(analytics);
      errors.addAll(duplicateErrors);

      // التحقق من الاتساق في البيانات
      final consistencyWarnings = _checkDataConsistency(analytics);
      warnings.addAll(consistencyWarnings);

      // إحصائيات التحقق
      metadata['total_tools'] = analytics.length;
      metadata['tools_with_issues'] = analytics.where((a) => 
        a.usagePercentage > 100 || a.remainingStock < 0).length;
      metadata['critical_stock_tools'] = analytics.where((a) => 
        a.stockStatus.toLowerCase() == 'critical').length;

      AppLogger.info('✅ Validation completed: ${errors.length} errors, ${warnings.length} warnings');

      return errors.isEmpty 
          ? ValidationResult.valid(warnings: warnings, metadata: metadata)
          : ValidationResult.invalid(errors: errors, warnings: warnings, metadata: metadata);

    } catch (e) {
      AppLogger.error('❌ Error validating tool usage analytics: $e');
      return ValidationResult.invalid(errors: ['خطأ في التحقق من صحة البيانات: $e']);
    }
  }

  /// التحقق من صحة تحليل فجوة الإنتاج
  ValidationResult validateProductionGapAnalysis(ProductionGapAnalysis gapAnalysis) {
    try {
      AppLogger.info('🔍 Validating production gap analysis');

      final errors = <String>[];
      final warnings = <String>[];
      final metadata = <String, dynamic>{};

      // التحقق من القيم الأساسية
      if (gapAnalysis.targetQuantity <= 0) {
        errors.add('الكمية المستهدفة يجب أن تكون أكبر من صفر');
      }

      if (gapAnalysis.currentProduction < 0) {
        errors.add('الإنتاج الحالي لا يمكن أن يكون سالباً');
      }

      // التحقق من نسبة الإكمال
      if (gapAnalysis.completionPercentage < 0 || gapAnalysis.completionPercentage > 200) {
        warnings.add('نسبة الإكمال غير طبيعية: ${gapAnalysis.completionPercentage.toStringAsFixed(1)}%');
      }

      // التحقق من الاتساق بين الحقول
      final calculatedPercentage = gapAnalysis.targetQuantity > 0 
          ? (gapAnalysis.currentProduction / gapAnalysis.targetQuantity) * 100
          : 0.0;
      
      if ((calculatedPercentage - gapAnalysis.completionPercentage).abs() > 1.0) {
        warnings.add('عدم تطابق في حساب نسبة الإكمال');
      }

      // التحقق من القطع المتبقية
      final calculatedRemaining = gapAnalysis.targetQuantity - gapAnalysis.currentProduction;
      if ((calculatedRemaining - gapAnalysis.remainingPieces).abs() > 0.1) {
        warnings.add('عدم تطابق في حساب القطع المتبقية');
      }

      // التحقق من حالات الإنتاج الزائد
      if (gapAnalysis.isOverProduced && gapAnalysis.remainingPieces >= 0) {
        errors.add('تناقض في بيانات الإنتاج الزائد');
      }

      // التحقق من حالة الإكمال
      if (gapAnalysis.isCompleted && gapAnalysis.remainingPieces > 0) {
        errors.add('تناقض في حالة الإكمال مع القطع المتبقية');
      }

      metadata['completion_percentage'] = gapAnalysis.completionPercentage;
      metadata['is_over_produced'] = gapAnalysis.isOverProduced;
      metadata['remaining_pieces'] = gapAnalysis.remainingPieces;

      AppLogger.info('✅ Gap analysis validation completed');

      return errors.isEmpty 
          ? ValidationResult.valid(warnings: warnings, metadata: metadata)
          : ValidationResult.invalid(errors: errors, warnings: warnings, metadata: metadata);

    } catch (e) {
      AppLogger.error('❌ Error validating production gap analysis: $e');
      return ValidationResult.invalid(errors: ['خطأ في التحقق من تحليل فجوة الإنتاج: $e']);
    }
  }

  /// التحقق من صحة توقعات الأدوات المطلوبة
  ValidationResult validateRequiredToolsForecast(RequiredToolsForecast forecast) {
    try {
      AppLogger.info('🔍 Validating required tools forecast');

      final errors = <String>[];
      final warnings = <String>[];
      final metadata = <String, dynamic>{};

      // التحقق من القطع المتبقية
      if (forecast.remainingPieces < 0) {
        errors.add('القطع المتبقية لا يمكن أن تكون سالبة');
      }

      if (forecast.remainingPieces == 0 && forecast.requiredTools.isNotEmpty) {
        warnings.add('لا توجد قطع متبقية ولكن هناك أدوات مطلوبة');
      }

      // التحقق من كل أداة مطلوبة
      for (int i = 0; i < forecast.requiredTools.length; i++) {
        final tool = forecast.requiredTools[i];
        final toolErrors = _validateRequiredToolItem(tool, i, forecast.remainingPieces);
        errors.addAll(toolErrors);
      }

      // التحقق من اتساق حالة الإكمال
      final hasUnavailableTools = forecast.requiredTools.any((tool) => !tool.isAvailable);
      if (forecast.canCompleteProduction && hasUnavailableTools) {
        errors.add('تناقض: يمكن إكمال الإنتاج رغم وجود أدوات غير متوفرة');
      }

      // التحقق من قائمة الأدوات غير المتوفرة
      final actualUnavailableTools = forecast.requiredTools
          .where((tool) => !tool.isAvailable)
          .map((tool) => tool.toolName)
          .toList();
      
      if (actualUnavailableTools.length != forecast.unavailableTools.length) {
        warnings.add('عدم تطابق في قائمة الأدوات غير المتوفرة');
      }

      // التحقق من التكلفة الإجمالية
      final calculatedCost = forecast.requiredTools
          .where((tool) => tool.estimatedCost != null)
          .fold<double>(0, (sum, tool) => sum + tool.estimatedCost!);
      
      if (forecast.totalCost > 0 && (calculatedCost - forecast.totalCost).abs() > 1.0) {
        warnings.add('عدم تطابق في حساب التكلفة الإجمالية');
      }

      metadata['tools_count'] = forecast.toolsCount;
      metadata['unavailable_tools_count'] = forecast.unavailableToolsCount;
      metadata['can_complete_production'] = forecast.canCompleteProduction;
      metadata['total_cost'] = forecast.totalCost;

      AppLogger.info('✅ Tools forecast validation completed');

      return errors.isEmpty 
          ? ValidationResult.valid(warnings: warnings, metadata: metadata)
          : ValidationResult.invalid(errors: errors, warnings: warnings, metadata: metadata);

    } catch (e) {
      AppLogger.error('❌ Error validating required tools forecast: $e');
      return ValidationResult.invalid(errors: ['خطأ في التحقق من توقعات الأدوات: $e']);
    }
  }

  /// التحقق من صحة تاريخ استخدام الأدوات
  ValidationResult validateToolUsageHistory(List<ToolUsageEntry> history) {
    try {
      AppLogger.info('🔍 Validating tool usage history');

      final errors = <String>[];
      final warnings = <String>[];
      final metadata = <String, dynamic>{};

      if (history.isEmpty) {
        warnings.add('لا يوجد تاريخ استخدام للأدوات');
        return ValidationResult.valid(warnings: warnings);
      }

      // التحقق من كل إدخال
      for (int i = 0; i < history.length; i++) {
        final entry = history[i];
        
        if (entry.quantityUsed <= 0) {
          errors.add('الكمية المستخدمة في الإدخال ${i + 1} يجب أن تكون أكبر من صفر');
        }

        if (entry.usageDate.isAfter(DateTime.now())) {
          errors.add('تاريخ الاستخدام في الإدخال ${i + 1} لا يمكن أن يكون في المستقبل');
        }

        if (entry.batchId <= 0) {
          errors.add('معرف الدفعة في الإدخال ${i + 1} غير صحيح');
        }
      }

      // التحقق من ترتيب التواريخ
      final sortedHistory = List<ToolUsageEntry>.from(history)
        ..sort((a, b) => a.usageDate.compareTo(b.usageDate));
      
      if (!_areListsEqual(history, sortedHistory)) {
        warnings.add('تاريخ الاستخدام غير مرتب زمنياً');
      }

      // إحصائيات التاريخ
      final totalQuantity = history.fold<double>(0, (sum, entry) => sum + entry.quantityUsed);
      final uniqueBatches = history.map((entry) => entry.batchId).toSet().length;
      final dateRange = history.isNotEmpty 
          ? history.last.usageDate.difference(history.first.usageDate).inDays
          : 0;

      metadata['total_entries'] = history.length;
      metadata['total_quantity_used'] = totalQuantity;
      metadata['unique_batches'] = uniqueBatches;
      metadata['date_range_days'] = dateRange;

      AppLogger.info('✅ Usage history validation completed');

      return errors.isEmpty 
          ? ValidationResult.valid(warnings: warnings, metadata: metadata)
          : ValidationResult.invalid(errors: errors, warnings: warnings, metadata: metadata);

    } catch (e) {
      AppLogger.error('❌ Error validating tool usage history: $e');
      return ValidationResult.invalid(errors: ['خطأ في التحقق من تاريخ الاستخدام: $e']);
    }
  }

  /// التحقق من تحليل أداة واحدة
  List<String> _validateSingleToolAnalytic(ToolUsageAnalytics analytic, int index) {
    final errors = <String>[];

    if (analytic.toolName.trim().isEmpty) {
      errors.add('اسم الأداة في الصف ${index + 1} فارغ');
    }

    if (analytic.unit.trim().isEmpty) {
      errors.add('وحدة القياس في الصف ${index + 1} فارغة');
    }

    if (analytic.quantityUsedPerUnit < 0) {
      errors.add('الكمية المستخدمة لكل وحدة في الصف ${index + 1} لا يمكن أن تكون سالبة');
    }

    if (analytic.totalQuantityUsed < 0) {
      errors.add('إجمالي الكمية المستخدمة في الصف ${index + 1} لا يمكن أن تكون سالبة');
    }

    if (analytic.remainingStock < 0) {
      errors.add('المخزون المتبقي في الصف ${index + 1} لا يمكن أن يكون سالباً');
    }

    if (analytic.initialStock < 0) {
      errors.add('المخزون الأولي في الصف ${index + 1} لا يمكن أن يكون سالباً');
    }

    if (analytic.usagePercentage < 0 || analytic.usagePercentage > 100) {
      errors.add('نسبة الاستهلاك في الصف ${index + 1} يجب أن تكون بين 0 و 100');
    }

    if (analytic.initialStock > 0 && analytic.totalQuantityUsed > analytic.initialStock) {
      errors.add('الكمية المستخدمة في الصف ${index + 1} تتجاوز المخزون الأولي');
    }

    return errors;
  }

  /// التحقق من التكرارات في الأدوات
  List<String> _checkForDuplicateTools(List<ToolUsageAnalytics> analytics) {
    final errors = <String>[];
    final seenTools = <int>{};

    for (final analytic in analytics) {
      if (seenTools.contains(analytic.toolId)) {
        errors.add('الأداة ${analytic.toolName} (ID: ${analytic.toolId}) مكررة');
      } else {
        seenTools.add(analytic.toolId);
      }
    }

    return errors;
  }

  /// التحقق من اتساق البيانات
  List<String> _checkDataConsistency(List<ToolUsageAnalytics> analytics) {
    final warnings = <String>[];

    // التحقق من الوحدات المختلطة
    final units = analytics.map((a) => a.unit).toSet();
    if (units.length > 5) {
      warnings.add('عدد كبير من وحدات القياس المختلفة (${units.length})');
    }

    // التحقق من القيم الشاذة
    final usagePercentages = analytics.map((a) => a.usagePercentage).toList();
    if (usagePercentages.isNotEmpty) {
      final avgUsage = usagePercentages.reduce((a, b) => a + b) / usagePercentages.length;
      final outliers = analytics.where((a) => (a.usagePercentage - avgUsage).abs() > 50).length;
      
      if (outliers > 0) {
        warnings.add('توجد $outliers أداة بنسب استهلاك شاذة');
      }
    }

    return warnings;
  }

  /// التحقق من عنصر أداة مطلوبة
  List<String> _validateRequiredToolItem(RequiredToolItem tool, int index, double remainingPieces) {
    final errors = <String>[];

    if (tool.toolName.trim().isEmpty) {
      errors.add('اسم الأداة في الصف ${index + 1} فارغ');
    }

    if (tool.quantityPerUnit < 0) {
      errors.add('الكمية لكل وحدة في الصف ${index + 1} لا يمكن أن تكون سالبة');
    }

    if (tool.totalQuantityNeeded < 0) {
      errors.add('إجمالي الكمية المطلوبة في الصف ${index + 1} لا يمكن أن تكون سالبة');
    }

    if (tool.availableStock < 0) {
      errors.add('المخزون المتوفر في الصف ${index + 1} لا يمكن أن يكون سالباً');
    }

    // التحقق من حساب الكمية الإجمالية
    final calculatedTotal = tool.quantityPerUnit * remainingPieces;
    if ((calculatedTotal - tool.totalQuantityNeeded).abs() > 0.1) {
      errors.add('خطأ في حساب الكمية الإجمالية للأداة في الصف ${index + 1}');
    }

    // التحقق من حساب النقص
    final calculatedShortfall = (tool.totalQuantityNeeded - tool.availableStock).clamp(0.0, double.infinity);
    if ((calculatedShortfall - tool.shortfall).abs() > 0.1) {
      errors.add('خطأ في حساب النقص للأداة في الصف ${index + 1}');
    }

    // التحقق من حالة التوفر
    if (tool.isAvailable && tool.shortfall > 0) {
      errors.add('تناقض في حالة التوفر للأداة في الصف ${index + 1}');
    }

    return errors;
  }

  /// مقارنة قائمتين للتحقق من التساوي
  bool _areListsEqual<T>(List<T> list1, List<T> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return false;
    }
    return true;
  }
}
