import 'dart:convert';
import 'package:smartbiztracker_new/models/import_analysis_models.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// خدمة التحقق الذكي - تحقق شامل من صحة المنتجات المجمعة وسلامة المواد
class IntelligentValidationService {
  
  /// تحقق شامل من مجموعات المنتجات
  static Future<ValidationReport> validateProductGroups(List<ProductGroup> productGroups) async {
    AppLogger.info('🔍 بدء التحقق الشامل من ${productGroups.length} مجموعة منتجات');
    
    final report = ValidationReport(
      totalGroups: productGroups.length,
      validatedAt: DateTime.now(),
    );
    
    for (int i = 0; i < productGroups.length; i++) {
      final group = productGroups[i];
      final groupValidation = await _validateSingleGroup(group, i);
      report.addGroupValidation(groupValidation);
    }
    
    // تحقق من التناسق العام
    await _validateOverallConsistency(productGroups, report);
    
    AppLogger.info('✅ تم التحقق من جميع المجموعات: ${report.validGroups} صحيحة، ${report.invalidGroups} غير صحيحة، ${report.warningGroups} تحذيرات');
    
    return report;
  }
  
  /// تحقق من مجموعة واحدة
  static Future<GroupValidationResult> _validateSingleGroup(ProductGroup group, int index) async {
    final result = GroupValidationResult(
      groupId: group.id,
      groupIndex: index,
      itemNumber: group.itemNumber,
    );
    
    // تحقق من البيانات الأساسية
    _validateBasicData(group, result);
    
    // تحقق من المواد
    _validateMaterials(group, result);
    
    // تحقق من الكميات
    _validateQuantities(group, result);
    
    // تحقق من ثقة التجميع
    _validateGroupingConfidence(group, result);
    
    // تحقق من المراجع المصدر
    _validateSourceReferences(group, result);
    
    return result;
  }
  
  /// تحقق من البيانات الأساسية
  static void _validateBasicData(ProductGroup group, GroupValidationResult result) {
    // تحقق من معرف المنتج
    if (group.itemNumber.trim().isEmpty) {
      result.addError('معرف المنتج فارغ');
    } else if (group.itemNumber.length < 2) {
      result.addWarning('معرف المنتج قصير جداً: "${group.itemNumber}"');
    } else if (!_isValidProductIdFormat(group.itemNumber)) {
      result.addWarning('تنسيق معرف المنتج غير مألوف: "${group.itemNumber}"');
    }
    
    // تحقق من الكمية الإجمالية
    if (group.totalQuantity <= 0) {
      result.addError('الكمية الإجمالية صفر أو سالبة: ${group.totalQuantity}');
    } else if (group.totalQuantity > 1000000) {
      result.addWarning('الكمية الإجمالية كبيرة جداً: ${group.totalQuantity}');
    }
    
    // تحقق من عدد الكراتين
    if (group.totalCartonCount < 0) {
      result.addError('عدد الكراتين سالب: ${group.totalCartonCount}');
    } else if (group.totalCartonCount > 0 && group.totalQuantity > 0) {
      final piecesPerCarton = group.totalQuantity / group.totalCartonCount;
      if (piecesPerCarton > 10000) {
        result.addWarning('عدد القطع لكل كرتون كبير جداً: ${piecesPerCarton.toStringAsFixed(1)}');
      } else if (piecesPerCarton < 1) {
        result.addWarning('عدد القطع لكل كرتون صغير جداً: ${piecesPerCarton.toStringAsFixed(1)}');
      }
    }
  }
  
  /// تحقق من المواد
  static void _validateMaterials(ProductGroup group, GroupValidationResult result) {
    if (group.materials.isEmpty) {
      result.addWarning('لا توجد مواد مستخرجة للمنتج');
      return;
    }
    
    final materialNames = <String>[];
    int totalMaterialQuantity = 0;
    
    for (int i = 0; i < group.materials.length; i++) {
      final material = group.materials[i];
      
      // تحقق من اسم المادة
      if (material.materialName.trim().isEmpty) {
        result.addError('اسم المادة ${i + 1} فارغ');
      } else if (material.materialName.length < 3) {
        result.addWarning('اسم المادة ${i + 1} قصير جداً: "${material.materialName}"');
      }
      
      // تحقق من كمية المادة
      if (material.quantity <= 0) {
        result.addError('كمية المادة "${material.materialName}" صفر أو سالبة: ${material.quantity}');
      } else if (material.quantity > group.totalQuantity) {
        result.addWarning('كمية المادة "${material.materialName}" أكبر من الكمية الإجمالية: ${material.quantity} > ${group.totalQuantity}');
      }
      
      totalMaterialQuantity += material.quantity;
      
      // تحقق من التكرار
      if (materialNames.contains(material.materialName.toLowerCase())) {
        result.addWarning('اسم المادة مكرر: "${material.materialName}"');
      }
      materialNames.add(material.materialName.toLowerCase());
      
      // تحقق من التصنيف
      if (material.category == null) {
        result.addInfo('المادة "${material.materialName}" غير مصنفة');
      }
    }
    
    // تحقق من تناسق الكميات
    if (totalMaterialQuantity > group.totalQuantity * 1.5) {
      result.addWarning('إجمالي كميات المواد أكبر بكثير من الكمية الإجمالية: $totalMaterialQuantity vs ${group.totalQuantity}');
    } else if (totalMaterialQuantity < group.totalQuantity * 0.5) {
      result.addWarning('إجمالي كميات المواد أقل بكثير من الكمية الإجمالية: $totalMaterialQuantity vs ${group.totalQuantity}');
    }
  }
  
  /// تحقق من الكميات
  static void _validateQuantities(ProductGroup group, GroupValidationResult result) {
    // تحقق من التناسق بين الكميات المختلفة
    final materialQuantities = group.materials.map((m) => m.quantity).toList();
    
    if (materialQuantities.isNotEmpty) {
      final maxMaterialQuantity = materialQuantities.reduce((a, b) => a > b ? a : b);
      final minMaterialQuantity = materialQuantities.reduce((a, b) => a < b ? a : b);
      
      // تحقق من التفاوت الكبير في الكميات
      if (maxMaterialQuantity > minMaterialQuantity * 100) {
        result.addWarning('تفاوت كبير في كميات المواد: $minMaterialQuantity - $maxMaterialQuantity');
      }
    }
    
    // تحقق من المنطقية
    if (group.totalCartonCount > 0 && group.totalQuantity > 0) {
      final avgPiecesPerCarton = group.totalQuantity / group.totalCartonCount;
      if (avgPiecesPerCarton < 1) {
        result.addError('متوسط القطع لكل كرتون أقل من 1: ${avgPiecesPerCarton.toStringAsFixed(2)}');
      }
    }
  }
  
  /// تحقق من ثقة التجميع
  static void _validateGroupingConfidence(ProductGroup group, GroupValidationResult result) {
    if (group.groupingConfidence < 0.3) {
      result.addError('ثقة التجميع منخفضة جداً: ${(group.groupingConfidence * 100).toStringAsFixed(1)}%');
    } else if (group.groupingConfidence < 0.5) {
      result.addWarning('ثقة التجميع منخفضة: ${(group.groupingConfidence * 100).toStringAsFixed(1)}%');
    } else if (group.groupingConfidence < 0.7) {
      result.addInfo('ثقة التجميع متوسطة: ${(group.groupingConfidence * 100).toStringAsFixed(1)}%');
    }
  }
  
  /// تحقق من المراجع المصدر
  static void _validateSourceReferences(ProductGroup group, GroupValidationResult result) {
    if (group.sourceRowReferences.isEmpty) {
      result.addWarning('لا توجد مراجع للصفوف المصدر');
    } else if (group.sourceRowReferences.length > 10) {
      result.addInfo('عدد كبير من الصفوف المصدر: ${group.sourceRowReferences.length}');
    }
    
    // تحقق من تنسيق المراجع
    for (final ref in group.sourceRowReferences) {
      if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(ref)) {
        result.addWarning('تنسيق مرجع صف غير صحيح: "$ref"');
      }
    }
  }
  
  /// تحقق من التناسق العام
  static Future<void> _validateOverallConsistency(List<ProductGroup> groups, ValidationReport report) async {
    // تحقق من التكرار في معرفات المنتجات
    final productIds = <String>[];
    for (final group in groups) {
      if (productIds.contains(group.itemNumber)) {
        report.addGlobalWarning('معرف منتج مكرر: "${group.itemNumber}"');
      }
      productIds.add(group.itemNumber);
    }
    
    // إحصائيات عامة
    final totalProducts = groups.length;
    final totalMaterials = groups.fold(0, (sum, group) => sum + group.materials.length);
    final totalQuantity = groups.fold(0, (sum, group) => sum + group.totalQuantity);
    
    report.addGlobalInfo('إجمالي المنتجات: $totalProducts');
    report.addGlobalInfo('إجمالي المواد: $totalMaterials');
    report.addGlobalInfo('إجمالي الكمية: $totalQuantity');
    
    if (totalProducts > 0) {
      final avgMaterialsPerProduct = (totalMaterials / totalProducts).toStringAsFixed(1);
      final avgQuantityPerProduct = (totalQuantity / totalProducts).toStringAsFixed(1);
      
      report.addGlobalInfo('متوسط المواد لكل منتج: $avgMaterialsPerProduct');
      report.addGlobalInfo('متوسط الكمية لكل منتج: $avgQuantityPerProduct');
    }
  }
  
  /// تحقق من تنسيق معرف المنتج
  static bool _isValidProductIdFormat(String productId) {
    final patterns = [
      RegExp(r'^[A-Z]{2,4}\d{3,6}(-\d+)?$'),     // YH0916-3
      RegExp(r'^\d{4,8}(/\d+[A-Z]*)?$'),         // 2333/1GD
      RegExp(r'^[A-Z]+\d+[A-Z]*$'),              // ABC123X
      RegExp(r'^[A-Z]{1,3}-\d{3,6}$'),           // A-12345
    ];
    
    return patterns.any((pattern) => pattern.hasMatch(productId.toUpperCase()));
  }
}

/// تقرير التحقق الشامل
class ValidationReport {
  final int totalGroups;
  final DateTime validatedAt;
  final List<GroupValidationResult> groupResults = [];
  final List<String> globalWarnings = [];
  final List<String> globalErrors = [];
  final List<String> globalInfo = [];
  
  ValidationReport({
    required this.totalGroups,
    required this.validatedAt,
  });
  
  void addGroupValidation(GroupValidationResult result) {
    groupResults.add(result);
  }
  
  void addGlobalWarning(String warning) {
    globalWarnings.add(warning);
  }
  
  void addGlobalError(String error) {
    globalErrors.add(error);
  }
  
  void addGlobalInfo(String info) {
    globalInfo.add(info);
  }
  
  int get validGroups => groupResults.where((r) => r.isValid).length;
  int get invalidGroups => groupResults.where((r) => !r.isValid).length;
  int get warningGroups => groupResults.where((r) => r.hasWarnings).length;
  
  bool get isOverallValid => invalidGroups == 0 && globalErrors.isEmpty;
  
  Map<String, dynamic> toJson() {
    return {
      'total_groups': totalGroups,
      'valid_groups': validGroups,
      'invalid_groups': invalidGroups,
      'warning_groups': warningGroups,
      'is_overall_valid': isOverallValid,
      'validated_at': validatedAt.toIso8601String(),
      'global_warnings': globalWarnings,
      'global_errors': globalErrors,
      'global_info': globalInfo,
      'group_results': groupResults.map((r) => r.toJson()).toList(),
    };
  }
}

/// نتيجة تحقق مجموعة واحدة
class GroupValidationResult {
  final String groupId;
  final int groupIndex;
  final String itemNumber;
  final List<String> errors = [];
  final List<String> warnings = [];
  final List<String> info = [];
  
  GroupValidationResult({
    required this.groupId,
    required this.groupIndex,
    required this.itemNumber,
  });
  
  void addError(String error) {
    errors.add(error);
  }
  
  void addWarning(String warning) {
    warnings.add(warning);
  }
  
  void addInfo(String information) {
    info.add(information);
  }
  
  bool get isValid => errors.isEmpty;
  bool get hasWarnings => warnings.isNotEmpty;
  bool get hasInfo => info.isNotEmpty;
  
  Map<String, dynamic> toJson() {
    return {
      'group_id': groupId,
      'group_index': groupIndex,
      'item_number': itemNumber,
      'is_valid': isValid,
      'has_warnings': hasWarnings,
      'errors': errors,
      'warnings': warnings,
      'info': info,
    };
  }
}
