import 'dart:convert';
import 'dart:math';
import 'package:smartbiztracker_new/models/import_analysis_models.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// مولد التقارير المحسن - تقارير متقدمة للمنتجات المجمعة مع تحليل المواد
class EnhancedSummaryGenerator {
  
  /// إنشاء تقرير شامل للمنتجات المجمعة
  static Map<String, dynamic> generateComprehensiveReport(List<ProductGroup> productGroups) {
    AppLogger.info('📊 إنشاء تقرير شامل لـ ${productGroups.length} مجموعة منتجات');
    
    final report = <String, dynamic>{
      'metadata': _generateMetadata(productGroups),
      'overview': _generateOverview(productGroups),
      'product_analysis': _generateProductAnalysis(productGroups),
      'material_analysis': _generateMaterialAnalysis(productGroups),
      'category_breakdown': _generateCategoryBreakdown(productGroups),
      'quantity_analysis': _generateQuantityAnalysis(productGroups),
      'quality_metrics': _generateQualityMetrics(productGroups),
      'recommendations': _generateRecommendations(productGroups),
      'detailed_products': _generateDetailedProductList(productGroups),
    };
    
    AppLogger.info('✅ تم إنشاء التقرير الشامل بنجاح');
    return report;
  }
  
  /// إنشاء البيانات الوصفية
  static Map<String, dynamic> _generateMetadata(List<ProductGroup> groups) {
    return {
      'generated_at': DateTime.now().toIso8601String(),
      'total_groups': groups.length,
      'report_version': '2.0',
      'processing_method': 'intelligent_grouping_with_material_aggregation',
      'language': 'ar',
    };
  }
  
  /// إنشاء النظرة العامة
  static Map<String, dynamic> _generateOverview(List<ProductGroup> groups) {
    final totalProducts = groups.length;
    final totalMaterials = groups.fold(0, (sum, group) => sum + group.materials.length);
    final totalQuantity = groups.fold(0, (sum, group) => sum + group.totalQuantity);
    final totalCartons = groups.fold(0, (sum, group) => sum + group.totalCartonCount);
    
    final productsWithMaterials = groups.where((g) => g.materials.isNotEmpty).length;
    final avgMaterialsPerProduct = totalProducts > 0 ? (totalMaterials / totalProducts) : 0.0;
    final avgQuantityPerProduct = totalProducts > 0 ? (totalQuantity / totalProducts) : 0.0;
    
    return {
      'total_unique_products': totalProducts,
      'total_materials_extracted': totalMaterials,
      'total_quantity': totalQuantity,
      'total_cartons': totalCartons,
      'products_with_materials': productsWithMaterials,
      'products_without_materials': totalProducts - productsWithMaterials,
      'average_materials_per_product': double.parse(avgMaterialsPerProduct.toStringAsFixed(2)),
      'average_quantity_per_product': double.parse(avgQuantityPerProduct.toStringAsFixed(1)),
      'material_extraction_rate': totalProducts > 0 ? double.parse((productsWithMaterials / totalProducts * 100).toStringAsFixed(1)) : 0.0,
    };
  }
  
  /// تحليل المنتجات
  static Map<String, dynamic> _generateProductAnalysis(List<ProductGroup> groups) {
    final productsByMaterialCount = <String, int>{};
    final productsByQuantityRange = <String, int>{};
    final productsByConfidence = <String, int>{};
    
    for (final group in groups) {
      // تجميع حسب عدد المواد
      final materialCount = group.materials.length;
      String materialRange;
      if (materialCount == 0) materialRange = 'بدون مواد';
      else if (materialCount == 1) materialRange = 'مادة واحدة';
      else if (materialCount <= 3) materialRange = '2-3 مواد';
      else if (materialCount <= 5) materialRange = '4-5 مواد';
      else materialRange = 'أكثر من 5 مواد';
      
      productsByMaterialCount[materialRange] = (productsByMaterialCount[materialRange] ?? 0) + 1;
      
      // تجميع حسب نطاق الكمية
      final quantity = group.totalQuantity;
      String quantityRange;
      if (quantity <= 0) quantityRange = 'صفر';
      else if (quantity <= 10) quantityRange = '1-10';
      else if (quantity <= 50) quantityRange = '11-50';
      else if (quantity <= 100) quantityRange = '51-100';
      else if (quantity <= 500) quantityRange = '101-500';
      else quantityRange = 'أكثر من 500';
      
      productsByQuantityRange[quantityRange] = (productsByQuantityRange[quantityRange] ?? 0) + 1;
      
      // تجميع حسب ثقة التجميع
      final confidence = group.groupingConfidence;
      String confidenceRange;
      if (confidence < 0.3) confidenceRange = 'منخفضة (<30%)';
      else if (confidence < 0.5) confidenceRange = 'متوسطة منخفضة (30-50%)';
      else if (confidence < 0.7) confidenceRange = 'متوسطة (50-70%)';
      else if (confidence < 0.9) confidenceRange = 'عالية (70-90%)';
      else confidenceRange = 'عالية جداً (90%+)';
      
      productsByConfidence[confidenceRange] = (productsByConfidence[confidenceRange] ?? 0) + 1;
    }
    
    return {
      'distribution_by_material_count': productsByMaterialCount,
      'distribution_by_quantity_range': productsByQuantityRange,
      'distribution_by_confidence': productsByConfidence,
      'top_products_by_quantity': _getTopProductsByQuantity(groups, 10),
      'top_products_by_material_count': _getTopProductsByMaterialCount(groups, 10),
    };
  }
  
  /// تحليل المواد
  static Map<String, dynamic> _generateMaterialAnalysis(List<ProductGroup> groups) {
    final materialFrequency = <String, int>{};
    final materialQuantities = <String, int>{};
    final materialCategories = <String, int>{};
    
    for (final group in groups) {
      for (final material in group.materials) {
        // تكرار المواد
        materialFrequency[material.materialName] = (materialFrequency[material.materialName] ?? 0) + 1;
        
        // كميات المواد
        materialQuantities[material.materialName] = (materialQuantities[material.materialName] ?? 0) + material.quantity;
        
        // فئات المواد
        final category = material.category ?? 'غير مصنف';
        materialCategories[category] = (materialCategories[category] ?? 0) + 1;
      }
    }
    
    // ترتيب المواد
    final topMaterialsByFrequency = materialFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final topMaterialsByQuantity = materialQuantities.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return {
      'total_unique_materials': materialFrequency.length,
      'material_categories': materialCategories,
      'top_materials_by_frequency': topMaterialsByFrequency.take(15).map((e) => {
        'material_name': e.key,
        'frequency': e.value,
        'percentage': double.parse((e.value / groups.length * 100).toStringAsFixed(1)),
      }).toList(),
      'top_materials_by_quantity': topMaterialsByQuantity.take(15).map((e) => {
        'material_name': e.key,
        'total_quantity': e.value,
        'average_quantity': double.parse((e.value / materialFrequency[e.key]!).toStringAsFixed(1)),
      }).toList(),
      'material_diversity_index': _calculateMaterialDiversityIndex(materialFrequency),
    };
  }
  
  /// تحليل الفئات
  static Map<String, dynamic> _generateCategoryBreakdown(List<ProductGroup> groups) {
    final categoryStats = <String, Map<String, dynamic>>{};
    
    for (final group in groups) {
      for (final material in group.materials) {
        final category = material.category ?? 'غير مصنف';
        
        if (!categoryStats.containsKey(category)) {
          categoryStats[category] = {
            'material_count': 0,
            'total_quantity': 0,
            'product_count': 0,
            'materials': <String>{},
          };
        }
        
        final stats = categoryStats[category]!;
        stats['material_count'] = (stats['material_count'] as int) + 1;
        stats['total_quantity'] = (stats['total_quantity'] as int) + material.quantity;
        (stats['materials'] as Set<String>).add(material.materialName);
      }
    }
    
    // حساب عدد المنتجات لكل فئة
    for (final group in groups) {
      final categoriesInGroup = group.materials.map((m) => m.category ?? 'غير مصنف').toSet();
      for (final category in categoriesInGroup) {
        categoryStats[category]!['product_count'] = (categoryStats[category]!['product_count'] as int) + 1;
      }
    }
    
    // تحويل إلى تنسيق التقرير
    final categoryBreakdown = categoryStats.entries.map((entry) {
      final category = entry.key;
      final stats = entry.value;
      final materials = stats['materials'] as Set<String>;
      
      return {
        'category': category,
        'material_count': stats['material_count'],
        'unique_materials': materials.length,
        'total_quantity': stats['total_quantity'],
        'product_count': stats['product_count'],
        'average_quantity_per_material': stats['material_count'] > 0 
            ? double.parse(((stats['total_quantity'] as int) / (stats['material_count'] as int)).toStringAsFixed(1))
            : 0.0,
        'top_materials': materials.take(5).toList(),
      };
    }).toList();
    
    // ترتيب حسب الكمية الإجمالية
    categoryBreakdown.sort((a, b) => (b['total_quantity'] as int).compareTo(a['total_quantity'] as int));
    
    return {
      'categories': categoryBreakdown,
      'total_categories': categoryBreakdown.length,
      'largest_category': categoryBreakdown.isNotEmpty ? categoryBreakdown.first['category'] : null,
    };
  }
  
  /// تحليل الكميات
  static Map<String, dynamic> _generateQuantityAnalysis(List<ProductGroup> groups) {
    if (groups.isEmpty) return {};
    
    final quantities = groups.map((g) => g.totalQuantity).toList();
    quantities.sort();
    
    final totalQuantity = quantities.fold(0, (sum, q) => sum + q);
    final avgQuantity = totalQuantity / quantities.length;
    final medianQuantity = quantities[quantities.length ~/ 2];
    final minQuantity = quantities.first;
    final maxQuantity = quantities.last;
    
    // حساب الانحراف المعياري
    final variance = quantities.fold(0.0, (sum, q) => sum + pow(q - avgQuantity, 2)) / quantities.length;
    final stdDeviation = sqrt(variance);
    
    return {
      'total_quantity': totalQuantity,
      'average_quantity': double.parse(avgQuantity.toStringAsFixed(1)),
      'median_quantity': medianQuantity,
      'min_quantity': minQuantity,
      'max_quantity': maxQuantity,
      'standard_deviation': double.parse(stdDeviation.toStringAsFixed(1)),
      'quantity_range': maxQuantity - minQuantity,
      'coefficient_of_variation': avgQuantity > 0 ? double.parse((stdDeviation / avgQuantity * 100).toStringAsFixed(1)) : 0.0,
    };
  }
  
  /// مقاييس الجودة
  static Map<String, dynamic> _generateQualityMetrics(List<ProductGroup> groups) {
    if (groups.isEmpty) return {};
    
    final confidenceScores = groups.map((g) => g.groupingConfidence).toList();
    final avgConfidence = confidenceScores.fold(0.0, (sum, c) => sum + c) / confidenceScores.length;
    
    final highConfidenceGroups = groups.where((g) => g.groupingConfidence >= 0.7).length;
    final lowConfidenceGroups = groups.where((g) => g.groupingConfidence < 0.5).length;
    
    final groupsWithMultipleSources = groups.where((g) => g.sourceRowReferences.length > 1).length;
    
    return {
      'average_grouping_confidence': double.parse((avgConfidence * 100).toStringAsFixed(1)),
      'high_confidence_groups': highConfidenceGroups,
      'low_confidence_groups': lowConfidenceGroups,
      'groups_with_multiple_sources': groupsWithMultipleSources,
      'data_quality_score': _calculateDataQualityScore(groups),
      'completeness_score': _calculateCompletenessScore(groups),
    };
  }
  
  /// التوصيات
  static List<Map<String, dynamic>> _generateRecommendations(List<ProductGroup> groups) {
    final recommendations = <Map<String, dynamic>>[];
    
    final lowConfidenceGroups = groups.where((g) => g.groupingConfidence < 0.5).length;
    if (lowConfidenceGroups > 0) {
      recommendations.add({
        'type': 'تحذير',
        'title': 'مجموعات بثقة منخفضة',
        'description': 'يوجد $lowConfidenceGroups مجموعة بثقة تجميع منخفضة. يُنصح بمراجعتها يدوياً.',
        'priority': 'عالية',
      });
    }
    
    final groupsWithoutMaterials = groups.where((g) => g.materials.isEmpty).length;
    if (groupsWithoutMaterials > 0) {
      recommendations.add({
        'type': 'تحسين',
        'title': 'منتجات بدون مواد',
        'description': 'يوجد $groupsWithoutMaterials منتج بدون مواد مستخرجة. يمكن تحسين استخراج المواد.',
        'priority': 'متوسطة',
      });
    }
    
    final avgMaterialsPerProduct = groups.isNotEmpty 
        ? groups.fold(0, (sum, g) => sum + g.materials.length) / groups.length 
        : 0.0;
    
    if (avgMaterialsPerProduct < 1.5) {
      recommendations.add({
        'type': 'تحسين',
        'title': 'قلة المواد المستخرجة',
        'description': 'متوسط المواد لكل منتج منخفض (${avgMaterialsPerProduct.toStringAsFixed(1)}). يمكن تحسين خوارزميات الاستخراج.',
        'priority': 'متوسطة',
      });
    }
    
    return recommendations;
  }
  
  /// قائمة المنتجات التفصيلية
  static List<Map<String, dynamic>> _generateDetailedProductList(List<ProductGroup> groups) {
    return groups.map((group) => {
      'item_number': group.itemNumber,
      'total_quantity': group.totalQuantity,
      'total_cartons': group.totalCartonCount,
      'materials_count': group.materials.length,
      'grouping_confidence': double.parse((group.groupingConfidence * 100).toStringAsFixed(1)),
      'source_rows': group.sourceRowReferences.length,
      'materials': group.materials.map((m) => {
        'name': m.materialName,
        'quantity': m.quantity,
        'category': m.category,
      }).toList(),
    }).toList();
  }
  
  /// المنتجات الأعلى كمية
  static List<Map<String, dynamic>> _getTopProductsByQuantity(List<ProductGroup> groups, int limit) {
    final sorted = List<ProductGroup>.from(groups);
    sorted.sort((a, b) => b.totalQuantity.compareTo(a.totalQuantity));
    
    return sorted.take(limit).map((g) => {
      'item_number': g.itemNumber,
      'total_quantity': g.totalQuantity,
      'materials_count': g.materials.length,
    }).toList();
  }
  
  /// المنتجات الأعلى عدد مواد
  static List<Map<String, dynamic>> _getTopProductsByMaterialCount(List<ProductGroup> groups, int limit) {
    final sorted = List<ProductGroup>.from(groups);
    sorted.sort((a, b) => b.materials.length.compareTo(a.materials.length));
    
    return sorted.take(limit).map((g) => {
      'item_number': g.itemNumber,
      'materials_count': g.materials.length,
      'total_quantity': g.totalQuantity,
    }).toList();
  }
  
  /// حساب مؤشر تنوع المواد
  static double _calculateMaterialDiversityIndex(Map<String, int> materialFrequency) {
    if (materialFrequency.isEmpty) return 0.0;
    
    final totalMaterials = materialFrequency.values.fold(0, (sum, freq) => sum + freq);
    double diversity = 0.0;
    
    for (final freq in materialFrequency.values) {
      final proportion = freq / totalMaterials;
      if (proportion > 0) {
        diversity -= proportion * log(proportion) / ln2;
      }
    }
    
    return double.parse(diversity.toStringAsFixed(3));
  }
  
  /// حساب نقاط جودة البيانات
  static double _calculateDataQualityScore(List<ProductGroup> groups) {
    if (groups.isEmpty) return 0.0;
    
    double score = 0.0;
    
    // نقاط للثقة العالية
    final highConfidenceCount = groups.where((g) => g.groupingConfidence >= 0.7).length;
    score += (highConfidenceCount / groups.length) * 40;
    
    // نقاط لوجود المواد
    final withMaterialsCount = groups.where((g) => g.materials.isNotEmpty).length;
    score += (withMaterialsCount / groups.length) * 30;
    
    // نقاط للكميات المنطقية
    final validQuantityCount = groups.where((g) => g.totalQuantity > 0).length;
    score += (validQuantityCount / groups.length) * 20;
    
    // نقاط للمراجع المصدر
    final withSourcesCount = groups.where((g) => g.sourceRowReferences.isNotEmpty).length;
    score += (withSourcesCount / groups.length) * 10;
    
    return double.parse(score.toStringAsFixed(1));
  }
  
  /// حساب نقاط الاكتمال
  static double _calculateCompletenessScore(List<ProductGroup> groups) {
    if (groups.isEmpty) return 0.0;
    
    double score = 0.0;
    
    for (final group in groups) {
      double groupScore = 0.0;
      
      // معرف المنتج موجود
      if (group.itemNumber.isNotEmpty) groupScore += 25;
      
      // كمية موجودة
      if (group.totalQuantity > 0) groupScore += 25;
      
      // مواد موجودة
      if (group.materials.isNotEmpty) groupScore += 25;
      
      // مراجع مصدر موجودة
      if (group.sourceRowReferences.isNotEmpty) groupScore += 25;
      
      score += groupScore;
    }
    
    return double.parse((score / groups.length).toStringAsFixed(1));
  }
}
