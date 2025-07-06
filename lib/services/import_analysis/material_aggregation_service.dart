import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:smartbiztracker_new/models/import_analysis_models.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// خدمة تجميع المواد - تجميع ذكي للمواد من أعمدة الملاحظات مع الحفاظ على الكميات الفردية
class MaterialAggregationService {
  static const Uuid _uuid = Uuid();
  
  /// تجميع المواد من مجموعات المنتجات
  static Future<List<ProductGroup>> aggregateMaterialsInGroups(List<ProductGroup> productGroups) async {
    AppLogger.info('🔄 بدء تجميع المواد في ${productGroups.length} مجموعة منتجات');
    
    final aggregatedGroups = <ProductGroup>[];
    
    for (final group in productGroups) {
      final aggregatedGroup = await _aggregateGroupMaterials(group);
      aggregatedGroups.add(aggregatedGroup);
    }
    
    AppLogger.info('✅ تم تجميع المواد في جميع المجموعات');
    return aggregatedGroups;
  }
  
  /// تجميع المواد في مجموعة واحدة
  static Future<ProductGroup> _aggregateGroupMaterials(ProductGroup group) async {
    AppLogger.info('🧪 تجميع المواد للمنتج: ${group.itemNumber}');
    
    if (group.materials.isEmpty) {
      AppLogger.info('⚠️ لا توجد مواد للتجميع في المنتج: ${group.itemNumber}');
      return group;
    }
    
    // تجميع المواد المتشابهة
    final aggregatedMaterials = await _aggregateSimilarMaterials(group.materials);
    
    // إنشاء مجموعة محدثة
    final updatedGroup = group.copyWith(
      materials: aggregatedMaterials,
      aggregatedData: {
        ...group.aggregatedData ?? {},
        'materials_aggregated': true,
        'original_materials_count': group.materials.length,
        'aggregated_materials_count': aggregatedMaterials.length,
        'aggregation_timestamp': DateTime.now().toIso8601String(),
      },
      updatedAt: DateTime.now(),
    );
    
    AppLogger.info('✅ تم تجميع ${group.materials.length} مادة إلى ${aggregatedMaterials.length} مادة للمنتج: ${group.itemNumber}');
    
    return updatedGroup;
  }
  
  /// تجميع المواد المتشابهة
  static Future<List<MaterialEntry>> _aggregateSimilarMaterials(List<MaterialEntry> materials) async {
    final materialGroups = <String, List<MaterialEntry>>{};
    
    // تجميع المواد حسب الاسم المنظم
    for (final material in materials) {
      final normalizedName = _normalizeMaterialName(material.materialName);
      materialGroups.putIfAbsent(normalizedName, () => []).add(material);
    }
    
    final aggregatedMaterials = <MaterialEntry>[];
    
    // دمج المواد المتشابهة
    for (final entry in materialGroups.entries) {
      final normalizedName = entry.key;
      final similarMaterials = entry.value;
      
      if (similarMaterials.length == 1) {
        // مادة واحدة فقط - إضافة مباشرة
        aggregatedMaterials.add(similarMaterials.first);
      } else {
        // مواد متشابهة - دمج
        final mergedMaterial = await _mergeSimilarMaterials(similarMaterials);
        aggregatedMaterials.add(mergedMaterial);
        
        AppLogger.info('🔗 تم دمج ${similarMaterials.length} مادة متشابهة: "$normalizedName"');
      }
    }
    
    // ترتيب المواد حسب الكمية (تنازلي)
    aggregatedMaterials.sort((a, b) => b.quantity.compareTo(a.quantity));
    
    return aggregatedMaterials;
  }
  
  /// دمج المواد المتشابهة
  static Future<MaterialEntry> _mergeSimilarMaterials(List<MaterialEntry> similarMaterials) async {
    if (similarMaterials.isEmpty) {
      throw ArgumentError('قائمة المواد المتشابهة فارغة');
    }
    
    if (similarMaterials.length == 1) {
      return similarMaterials.first;
    }
    
    // استخدام أول مادة كأساس
    final baseMaterial = similarMaterials.first;
    
    // جمع الكميات
    int totalQuantity = 0;
    final originalRemarksList = <String>[];
    final sourceIds = <String>[];
    
    for (final material in similarMaterials) {
      totalQuantity += material.quantity;
      sourceIds.add(material.id);
      
      if (material.originalRemarks != null && material.originalRemarks!.isNotEmpty) {
        originalRemarksList.add(material.originalRemarks!);
      }
    }
    
    // اختيار أفضل اسم للمادة (الأطول والأكثر وصفية)
    final bestMaterialName = _selectBestMaterialName(
      similarMaterials.map((m) => m.materialName).toList()
    );
    
    // دمج البيانات الوصفية
    final mergedMetadata = <String, dynamic>{
      'merged_from_count': similarMaterials.length,
      'source_material_ids': sourceIds,
      'merge_timestamp': DateTime.now().toIso8601String(),
      'merge_method': 'similar_materials_aggregation',
    };
    
    // إضافة البيانات الوصفية من المواد الأصلية
    for (int i = 0; i < similarMaterials.length; i++) {
      final material = similarMaterials[i];
      if (material.metadata != null) {
        mergedMetadata['source_${i}_metadata'] = material.metadata;
      }
    }
    
    return MaterialEntry(
      id: _uuid.v4(),
      materialName: bestMaterialName,
      quantity: totalQuantity,
      originalRemarks: originalRemarksList.isNotEmpty 
          ? originalRemarksList.join(' | ') 
          : null,
      category: baseMaterial.category,
      metadata: mergedMetadata,
      createdAt: DateTime.now(),
    );
  }
  
  /// تنظيف اسم المادة للمقارنة
  static String _normalizeMaterialName(String materialName) {
    return materialName
        .trim()
        .toLowerCase()
        // إزالة الأرقام والرموز الخاصة
        .replaceAll(RegExp(r'[0-9\(\)\[\]{}]'), '')
        // توحيد المسافات
        .replaceAll(RegExp(r'\s+'), ' ')
        // إزالة الكلمات الشائعة غير المهمة
        .replaceAll(RegExp(r'\b(و|أو|مع|من|في|على|إلى|and|or|with|from|in|on|to)\b'), '')
        // إزالة المسافات الزائدة
        .trim();
  }
  
  /// اختيار أفضل اسم للمادة من قائمة الأسماء
  static String _selectBestMaterialName(List<String> materialNames) {
    if (materialNames.isEmpty) return '';
    if (materialNames.length == 1) return materialNames.first;
    
    // ترتيب الأسماء حسب الطول والوصفية
    materialNames.sort((a, b) {
      // تفضيل الأسماء الأطول
      final lengthComparison = b.length.compareTo(a.length);
      if (lengthComparison != 0) return lengthComparison;
      
      // تفضيل الأسماء التي تحتوي على كلمات مفتاحية مهمة
      final aScore = _calculateMaterialNameScore(a);
      final bScore = _calculateMaterialNameScore(b);
      return bScore.compareTo(aScore);
    });
    
    return materialNames.first;
  }
  
  /// حساب نقاط جودة اسم المادة
  static int _calculateMaterialNameScore(String materialName) {
    int score = 0;
    final lowerName = materialName.toLowerCase();
    
    // كلمات مفتاحية مهمة
    final importantKeywords = [
      'طوق', 'شبوه', 'كرستاله', 'بلاستيك', 'معدن', 'الومنيوم',
      'ring', 'plastic', 'crystal', 'metal', 'aluminum', 'steel'
    ];
    
    for (final keyword in importantKeywords) {
      if (lowerName.contains(keyword.toLowerCase())) {
        score += 10;
      }
    }
    
    // تفضيل الأسماء التي تحتوي على تفاصيل
    if (lowerName.contains('بليد') || lowerName.contains('blade')) score += 5;
    if (lowerName.contains('بخرطوم') || lowerName.contains('hose')) score += 5;
    if (lowerName.contains('قطعه غياره') || lowerName.contains('spare part')) score += 5;
    
    // تفضيل الأسماء الأطول (المزيد من التفاصيل)
    score += materialName.length ~/ 10;
    
    return score;
  }
  
  /// إنشاء تقرير تجميع المواد
  static Map<String, dynamic> generateAggregationReport(List<ProductGroup> originalGroups, List<ProductGroup> aggregatedGroups) {
    int originalMaterialsCount = 0;
    int aggregatedMaterialsCount = 0;
    final productReports = <Map<String, dynamic>>[];
    
    for (int i = 0; i < originalGroups.length; i++) {
      final original = originalGroups[i];
      final aggregated = aggregatedGroups[i];
      
      originalMaterialsCount += original.materials.length;
      aggregatedMaterialsCount += aggregated.materials.length;
      
      if (original.materials.length != aggregated.materials.length) {
        productReports.add({
          'product_id': original.itemNumber,
          'original_materials_count': original.materials.length,
          'aggregated_materials_count': aggregated.materials.length,
          'reduction_count': original.materials.length - aggregated.materials.length,
          'reduction_percentage': ((original.materials.length - aggregated.materials.length) / original.materials.length * 100).toStringAsFixed(1),
        });
      }
    }
    
    final totalReduction = originalMaterialsCount - aggregatedMaterialsCount;
    final reductionPercentage = originalMaterialsCount > 0 
        ? (totalReduction / originalMaterialsCount * 100).toStringAsFixed(1)
        : '0.0';
    
    return {
      'total_products': originalGroups.length,
      'original_materials_count': originalMaterialsCount,
      'aggregated_materials_count': aggregatedMaterialsCount,
      'total_reduction': totalReduction,
      'reduction_percentage': reductionPercentage,
      'products_with_aggregation': productReports.length,
      'product_reports': productReports,
      'generated_at': DateTime.now().toIso8601String(),
    };
  }
  
  /// التحقق من جودة التجميع
  static Map<String, dynamic> validateAggregation(List<ProductGroup> aggregatedGroups) {
    final validationResults = <String, dynamic>{
      'is_valid': true,
      'warnings': <String>[],
      'errors': <String>[],
      'statistics': <String, dynamic>{},
    };
    
    int totalProducts = aggregatedGroups.length;
    int productsWithMaterials = 0;
    int totalMaterials = 0;
    final materialCategories = <String, int>{};
    
    for (final group in aggregatedGroups) {
      if (group.materials.isNotEmpty) {
        productsWithMaterials++;
        totalMaterials += group.materials.length;
        
        // تجميع الفئات
        for (final material in group.materials) {
          final category = material.category ?? 'غير مصنف';
          materialCategories[category] = (materialCategories[category] ?? 0) + 1;
        }
        
        // فحص التناسق
        if (group.totalQuantity <= 0) {
          validationResults['warnings'].add('المنتج ${group.itemNumber} له كمية صفر أو سالبة');
        }
        
        if (group.groupingConfidence < 0.5) {
          validationResults['warnings'].add('المنتج ${group.itemNumber} له ثقة تجميع منخفضة: ${group.groupingConfidence}');
        }
      }
    }
    
    validationResults['statistics'] = {
      'total_products': totalProducts,
      'products_with_materials': productsWithMaterials,
      'products_without_materials': totalProducts - productsWithMaterials,
      'total_materials': totalMaterials,
      'average_materials_per_product': productsWithMaterials > 0 ? (totalMaterials / productsWithMaterials).toStringAsFixed(2) : '0',
      'material_categories': materialCategories,
    };
    
    AppLogger.info('📊 تقرير التحقق من التجميع: ${validationResults['statistics']}');
    
    return validationResults;
  }
}
