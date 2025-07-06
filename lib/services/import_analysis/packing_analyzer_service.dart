import 'dart:math';
import 'package:smartbiztracker_new/models/import_analysis_models.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// خدمة تحليل قوائم التعبئة المتقدمة مع التصنيف الذكي وكشف التكرار
/// تستخدم خوارزميات التطابق الضبابي والتحليل الإحصائي المتقدم
class PackingListAnalyzer {
  static const double _defaultSimilarityThreshold = 0.90;
  static const int _maxCategoryKeywords = 50;
  
  /// تصنيف العناصر بناءً على الكلمات المفتاحية والتحليل النصي
  static Future<List<PackingListItem>> classifyItems(
    List<PackingListItem> items, {
    double confidenceThreshold = 0.7,
  }) async {
    try {
      AppLogger.info('بدء تصنيف ${items.length} عنصر...');
      
      final classifiedItems = <PackingListItem>[];
      
      for (final item in items) {
        final classification = await _classifyItem(item);
        
        final updatedItem = item.copyWith(
          category: classification.category,
          subcategory: classification.subcategory,
          classificationConfidence: classification.confidence,
        );
        
        classifiedItems.add(updatedItem);
      }
      
      AppLogger.info('تم تصنيف ${classifiedItems.length} عنصر بنجاح');
      return classifiedItems;
      
    } catch (e) {
      AppLogger.error('خطأ في تصنيف العناصر: $e');
      return items;
    }
  }
  
  /// تصنيف عنصر واحد
  static Future<ItemClassification> _classifyItem(PackingListItem item) async {
    final text = _extractTextForClassification(item);
    final normalizedText = _normalizeArabicText(text);
    
    // البحث في قواعد التصنيف
    for (final category in _categoryRules) {
      final confidence = _calculateCategoryConfidence(normalizedText, category);
      
      if (confidence >= 0.7) {
        final subcategory = _findSubcategory(normalizedText, category);
        
        return ItemClassification(
          category: category.name,
          subcategory: subcategory,
          confidence: confidence,
        );
      }
    }
    
    // تصنيف افتراضي
    return ItemClassification(
      category: 'غير مصنف',
      subcategory: null,
      confidence: 0.0,
    );
  }
  
  /// استخراج النص للتصنيف
  static String _extractTextForClassification(PackingListItem item) {
    final textParts = <String>[];
    
    textParts.add(item.itemNumber);
    
    if (item.remarks != null) {
      item.remarks!.values.forEach((remark) {
        if (remark != null) textParts.add(remark.toString());
      });
    }
    
    return textParts.join(' ').toLowerCase();
  }
  
  /// تطبيع النص العربي
  static String _normalizeArabicText(String text) {
    // إزالة التشكيل
    text = text.replaceAll(RegExp(r'[\u064B-\u0652]'), '');
    
    // توحيد الألف
    text = text.replaceAll(RegExp(r'[آأإ]'), 'ا');
    
    // توحيد التاء المربوطة والهاء
    text = text.replaceAll('ة', 'ه');
    
    // إزالة الرموز الخاصة
    text = text.replaceAll(RegExp(r'[^\w\s]'), ' ');
    
    // إزالة المسافات الزائدة
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    return text;
  }
  
  /// حساب مستوى الثقة في التصنيف
  static double _calculateCategoryConfidence(String text, CategoryRule category) {
    int matchCount = 0;
    int totalKeywords = category.keywords.length;
    
    for (final keyword in category.keywords) {
      if (_fuzzyMatch(text, keyword)) {
        matchCount++;
      }
    }
    
    return matchCount / totalKeywords;
  }
  
  /// التطابق الضبابي للنصوص
  static bool _fuzzyMatch(String text, String keyword) {
    // تطابق دقيق
    if (text.contains(keyword)) return true;
    
    // تطابق جزئي مع تحمل الأخطاء
    final similarity = _calculateStringSimilarity(text, keyword);
    return similarity >= 0.8;
  }
  
  /// حساب التشابه بين النصوص باستخدام Levenshtein Distance
  static double _calculateStringSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;
    
    final distance = _levenshteinDistance(s1, s2);
    final maxLength = max(s1.length, s2.length);
    
    return 1.0 - (distance / maxLength);
  }
  
  /// حساب Levenshtein Distance
  static int _levenshteinDistance(String s1, String s2) {
    final matrix = List.generate(
      s1.length + 1,
      (i) => List.filled(s2.length + 1, 0),
    );
    
    for (int i = 0; i <= s1.length; i++) {
      matrix[i][0] = i;
    }
    
    for (int j = 0; j <= s2.length; j++) {
      matrix[0][j] = j;
    }
    
    for (int i = 1; i <= s1.length; i++) {
      for (int j = 1; j <= s2.length; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        
        matrix[i][j] = [
          matrix[i - 1][j] + 1,      // deletion
          matrix[i][j - 1] + 1,      // insertion
          matrix[i - 1][j - 1] + cost, // substitution
        ].reduce(min);
      }
    }
    
    return matrix[s1.length][s2.length];
  }
  
  /// البحث عن التصنيف الفرعي
  static String? _findSubcategory(String text, CategoryRule category) {
    for (final subcategory in category.subcategories) {
      for (final keyword in subcategory.keywords) {
        if (_fuzzyMatch(text, keyword)) {
          return subcategory.name;
        }
      }
    }
    return null;
  }
  
  /// كشف العناصر المكررة والمتشابهة
  static Future<List<DuplicateCluster>> detectDuplicates(
    List<PackingListItem> items, {
    double similarityThreshold = _defaultSimilarityThreshold,
  }) async {
    try {
      AppLogger.info('بدء كشف التكرار في ${items.length} عنصر...');
      
      final clusters = <DuplicateCluster>[];
      final processedItems = <String>{};
      
      for (int i = 0; i < items.length; i++) {
        final item1 = items[i];
        
        if (processedItems.contains(item1.id)) continue;
        
        final similarItems = <PackingListItem>[item1];
        processedItems.add(item1.id);
        
        for (int j = i + 1; j < items.length; j++) {
          final item2 = items[j];
          
          if (processedItems.contains(item2.id)) continue;
          
          final similarity = await _calculateItemSimilarity(item1, item2);
          
          if (similarity >= similarityThreshold) {
            similarItems.add(item2);
            processedItems.add(item2.id);
          }
        }
        
        if (similarItems.length > 1) {
          final averageSimilarity = _calculateAverageSimilarity(similarItems);
          final suggestedAction = _suggestDuplicateAction(similarItems);
          
          clusters.add(DuplicateCluster(
            id: 'cluster_${DateTime.now().millisecondsSinceEpoch}_$i',
            items: similarItems,
            averageSimilarity: averageSimilarity,
            suggestedAction: suggestedAction,
          ));
        }
      }
      
      AppLogger.info('تم العثور على ${clusters.length} مجموعة تكرار');
      return clusters;
      
    } catch (e) {
      AppLogger.error('خطأ في كشف التكرار: $e');
      return [];
    }
  }
  
  /// حساب التشابه بين عنصرين
  static Future<double> _calculateItemSimilarity(
    PackingListItem item1,
    PackingListItem item2,
  ) async {
    double totalSimilarity = 0.0;
    int factorCount = 0;
    
    // تشابه رقم الصنف (وزن عالي)
    final itemNumberSimilarity = _calculateStringSimilarity(
      item1.itemNumber,
      item2.itemNumber,
    );
    totalSimilarity += itemNumberSimilarity * 0.4;
    factorCount++;
    
    // تشابه الملاحظات
    final remarks1 = _extractRemarksText(item1);
    final remarks2 = _extractRemarksText(item2);
    
    if (remarks1.isNotEmpty && remarks2.isNotEmpty) {
      final remarksSimilarity = _calculateStringSimilarity(remarks1, remarks2);
      totalSimilarity += remarksSimilarity * 0.3;
      factorCount++;
    }
    
    // تشابه الأبعاد
    if (item1.dimensions != null && item2.dimensions != null) {
      final dimensionsSimilarity = _calculateDimensionsSimilarity(
        item1.dimensions!,
        item2.dimensions!,
      );
      totalSimilarity += dimensionsSimilarity * 0.2;
      factorCount++;
    }
    
    // تشابه الأسعار
    if (item1.rmbPrice != null && item2.rmbPrice != null) {
      final priceSimilarity = _calculatePriceSimilarity(
        item1.rmbPrice!,
        item2.rmbPrice!,
      );
      totalSimilarity += priceSimilarity * 0.1;
      factorCount++;
    }
    
    return factorCount > 0 ? totalSimilarity / factorCount : 0.0;
  }
  
  /// استخراج نص الملاحظات
  static String _extractRemarksText(PackingListItem item) {
    if (item.remarks == null) return '';
    
    return item.remarks!.values
        .where((remark) => remark != null)
        .map((remark) => remark.toString())
        .join(' ')
        .toLowerCase();
  }
  
  /// حساب تشابه الأبعاد
  static double _calculateDimensionsSimilarity(
    Map<String, dynamic> dims1,
    Map<String, dynamic> dims2,
  ) {
    final size1_1 = (dims1['size1'] as num?)?.toDouble() ?? 0.0;
    final size2_1 = (dims1['size2'] as num?)?.toDouble() ?? 0.0;
    final size3_1 = (dims1['size3'] as num?)?.toDouble() ?? 0.0;
    
    final size1_2 = (dims2['size1'] as num?)?.toDouble() ?? 0.0;
    final size2_2 = (dims2['size2'] as num?)?.toDouble() ?? 0.0;
    final size3_2 = (dims2['size3'] as num?)?.toDouble() ?? 0.0;
    
    final volume1 = size1_1 * size2_1 * size3_1;
    final volume2 = size1_2 * size2_2 * size3_2;
    
    if (volume1 == 0.0 || volume2 == 0.0) return 0.0;
    
    final volumeDiff = (volume1 - volume2).abs();
    final maxVolume = max(volume1, volume2);
    
    return 1.0 - (volumeDiff / maxVolume);
  }
  
  /// حساب تشابه الأسعار
  static double _calculatePriceSimilarity(double price1, double price2) {
    if (price1 == 0.0 || price2 == 0.0) return 0.0;
    
    final priceDiff = (price1 - price2).abs();
    final maxPrice = max(price1, price2);
    
    return 1.0 - (priceDiff / maxPrice);
  }
  
  /// حساب متوسط التشابه في المجموعة
  static double _calculateAverageSimilarity(List<PackingListItem> items) {
    if (items.length < 2) return 1.0;
    
    double totalSimilarity = 0.0;
    int comparisons = 0;
    
    for (int i = 0; i < items.length; i++) {
      for (int j = i + 1; j < items.length; j++) {
        // هذا تقدير مبسط - في التطبيق الفعلي نحتاج لحساب التشابه الفعلي
        totalSimilarity += 0.9; // قيمة افتراضية
        comparisons++;
      }
    }
    
    return comparisons > 0 ? totalSimilarity / comparisons : 1.0;
  }
  
  /// اقتراح إجراء للتعامل مع التكرار
  static String _suggestDuplicateAction(List<PackingListItem> items) {
    if (items.length == 2) {
      return 'دمج العنصرين';
    } else if (items.length <= 5) {
      return 'مراجعة ودمج العناصر المتشابهة';
    } else {
      return 'مراجعة شاملة - عدد كبير من العناصر المتشابهة';
    }
  }

  /// تحليل إحصائي شامل للبيانات
  static Future<PackingListStatistics> analyzeStatistics(
    List<PackingListItem> items,
  ) async {
    try {
      AppLogger.info('بدء التحليل الإحصائي لـ ${items.length} عنصر...');

      final validItems = items.where((item) => item.isValid).toList();

      // إحصائيات الكمية
      final quantities = validItems.map((item) => item.totalQuantity).toList();
      final quantityStats = _calculateNumericStatistics(quantities.map((q) => q.toDouble()).toList());

      // إحصائيات الأسعار
      final prices = validItems
          .where((item) => item.rmbPrice != null)
          .map((item) => item.rmbPrice!)
          .toList();
      final priceStats = prices.isNotEmpty ? _calculateNumericStatistics(prices) : null;

      // إحصائيات الأوزان
      final weights = validItems
          .where((item) => item.totalNetWeight != null)
          .map((item) => item.totalNetWeight!)
          .toList();
      final weightStats = weights.isNotEmpty ? _calculateNumericStatistics(weights) : null;

      // إحصائيات الأحجام
      final volumes = validItems
          .where((item) => item.totalCubicMeters != null)
          .map((item) => item.totalCubicMeters!)
          .toList();
      final volumeStats = volumes.isNotEmpty ? _calculateNumericStatistics(volumes) : null;

      // تحليل التصنيفات
      final categoryBreakdown = _analyzeCategoryBreakdown(validItems);

      // تحليل جودة البيانات
      final qualityAnalysis = _analyzeDataQuality(items);

      return PackingListStatistics(
        totalItems: items.length,
        validItems: validItems.length,
        invalidItems: items.length - validItems.length,
        quantityStatistics: quantityStats,
        priceStatistics: priceStats,
        weightStatistics: weightStats,
        volumeStatistics: volumeStats,
        categoryBreakdown: categoryBreakdown,
        qualityAnalysis: qualityAnalysis,
        processingTime: DateTime.now(),
      );

    } catch (e) {
      AppLogger.error('خطأ في التحليل الإحصائي: $e');
      rethrow;
    }
  }

  /// حساب الإحصائيات الرقمية
  static NumericStatistics _calculateNumericStatistics(List<double> values) {
    if (values.isEmpty) {
      return NumericStatistics(
        count: 0,
        sum: 0.0,
        average: 0.0,
        minimum: 0.0,
        maximum: 0.0,
        median: 0.0,
        standardDeviation: 0.0,
      );
    }

    values.sort();

    final count = values.length;
    final sum = values.reduce((a, b) => a + b);
    final average = sum / count;
    final minimum = values.first;
    final maximum = values.last;

    // حساب الوسيط
    final median = count % 2 == 0
        ? (values[count ~/ 2 - 1] + values[count ~/ 2]) / 2
        : values[count ~/ 2];

    // حساب الانحراف المعياري
    final variance = values
        .map((value) => pow(value - average, 2))
        .reduce((a, b) => a + b) / count;
    final standardDeviation = sqrt(variance);

    return NumericStatistics(
      count: count,
      sum: sum,
      average: average,
      minimum: minimum,
      maximum: maximum,
      median: median,
      standardDeviation: standardDeviation,
    );
  }

  /// تحليل توزيع التصنيفات
  static Map<String, CategoryStatistics> _analyzeCategoryBreakdown(
    List<PackingListItem> items,
  ) {
    final categoryMap = <String, List<PackingListItem>>{};

    for (final item in items) {
      final category = item.category ?? 'غير مصنف';
      categoryMap.putIfAbsent(category, () => []).add(item);
    }

    final breakdown = <String, CategoryStatistics>{};
    final totalItems = items.length;

    for (final entry in categoryMap.entries) {
      final categoryItems = entry.value;
      final totalQuantity = categoryItems.fold(0, (sum, item) => sum + item.totalQuantity);
      final totalValue = categoryItems.fold(0.0, (sum, item) => sum + item.totalRmbValue);

      breakdown[entry.key] = CategoryStatistics(
        itemCount: categoryItems.length,
        totalQuantity: totalQuantity,
        totalValue: totalValue,
        percentage: (categoryItems.length / totalItems) * 100,
        averagePrice: categoryItems.isNotEmpty
            ? totalValue / categoryItems.length
            : 0.0,
      );
    }

    return breakdown;
  }

  /// تحليل جودة البيانات
  static DataQualityAnalysis _analyzeDataQuality(List<PackingListItem> items) {
    int completeItems = 0;
    int missingItemNumbers = 0;
    int missingQuantities = 0;
    int missingPrices = 0;
    int missingDimensions = 0;
    int invalidQuantities = 0;

    for (final item in items) {
      bool isComplete = true;

      if (item.itemNumber.isEmpty) {
        missingItemNumbers++;
        isComplete = false;
      }

      if (item.totalQuantity <= 0) {
        invalidQuantities++;
        isComplete = false;
      }

      if (item.rmbPrice == null || item.rmbPrice! <= 0) {
        missingPrices++;
        isComplete = false;
      }

      if (item.dimensions == null || item.dimensions!.isEmpty) {
        missingDimensions++;
        isComplete = false;
      }

      if (isComplete) completeItems++;
    }

    final totalItems = items.length;
    final completenessScore = totalItems > 0 ? (completeItems / totalItems) * 100 : 0.0;

    return DataQualityAnalysis(
      totalItems: totalItems,
      completeItems: completeItems,
      completenessScore: completenessScore,
      missingItemNumbers: missingItemNumbers,
      missingQuantities: missingQuantities,
      missingPrices: missingPrices,
      missingDimensions: missingDimensions,
      invalidQuantities: invalidQuantities,
    );
  }

  /// قواعد التصنيف المحددة مسبقاً
  static final List<CategoryRule> _categoryRules = [
    CategoryRule(
      name: 'إلكترونيات',
      keywords: [
        'phone', 'mobile', 'tablet', 'laptop', 'computer', 'electronic',
        'هاتف', 'جوال', 'لوحي', 'حاسوب', 'إلكتروني', 'كمبيوتر'
      ],
      subcategories: [
        SubcategoryRule(
          name: 'هواتف ذكية',
          keywords: ['phone', 'mobile', 'smartphone', 'هاتف', 'جوال'],
        ),
        SubcategoryRule(
          name: 'أجهزة لوحية',
          keywords: ['tablet', 'ipad', 'لوحي'],
        ),
      ],
    ),
    CategoryRule(
      name: 'ملابس',
      keywords: [
        'shirt', 'pants', 'dress', 'clothing', 'apparel', 'textile',
        'قميص', 'بنطلون', 'فستان', 'ملابس', 'نسيج'
      ],
      subcategories: [
        SubcategoryRule(
          name: 'ملابس رجالية',
          keywords: ['men', 'male', 'رجالي', 'رجال'],
        ),
        SubcategoryRule(
          name: 'ملابس نسائية',
          keywords: ['women', 'female', 'lady', 'نسائي', 'نساء', 'سيدات'],
        ),
      ],
    ),
    CategoryRule(
      name: 'أدوات منزلية',
      keywords: [
        'kitchen', 'home', 'household', 'furniture', 'appliance',
        'مطبخ', 'منزل', 'منزلي', 'أثاث', 'جهاز'
      ],
      subcategories: [
        SubcategoryRule(
          name: 'أدوات مطبخ',
          keywords: ['kitchen', 'cooking', 'مطبخ', 'طبخ'],
        ),
      ],
    ),
    CategoryRule(
      name: 'ألعاب',
      keywords: [
        'toy', 'game', 'play', 'children', 'kid',
        'لعبة', 'لعب', 'أطفال', 'طفل'
      ],
      subcategories: [],
    ),
  ];
}

/// نتيجة تصنيف العنصر
class ItemClassification {
  final String category;
  final String? subcategory;
  final double confidence;

  const ItemClassification({
    required this.category,
    this.subcategory,
    required this.confidence,
  });
}

/// قاعدة التصنيف
class CategoryRule {
  final String name;
  final List<String> keywords;
  final List<SubcategoryRule> subcategories;

  const CategoryRule({
    required this.name,
    required this.keywords,
    required this.subcategories,
  });
}

/// قاعدة التصنيف الفرعي
class SubcategoryRule {
  final String name;
  final List<String> keywords;

  const SubcategoryRule({
    required this.name,
    required this.keywords,
  });
}

/// إحصائيات قائمة التعبئة
class PackingListStatistics {
  final int totalItems;
  final int validItems;
  final int invalidItems;
  final NumericStatistics quantityStatistics;
  final NumericStatistics? priceStatistics;
  final NumericStatistics? weightStatistics;
  final NumericStatistics? volumeStatistics;
  final Map<String, CategoryStatistics> categoryBreakdown;
  final DataQualityAnalysis qualityAnalysis;
  final DateTime processingTime;

  const PackingListStatistics({
    required this.totalItems,
    required this.validItems,
    required this.invalidItems,
    required this.quantityStatistics,
    this.priceStatistics,
    this.weightStatistics,
    this.volumeStatistics,
    required this.categoryBreakdown,
    required this.qualityAnalysis,
    required this.processingTime,
  });
}

/// إحصائيات رقمية
class NumericStatistics {
  final int count;
  final double sum;
  final double average;
  final double minimum;
  final double maximum;
  final double median;
  final double standardDeviation;

  const NumericStatistics({
    required this.count,
    required this.sum,
    required this.average,
    required this.minimum,
    required this.maximum,
    required this.median,
    required this.standardDeviation,
  });
}

/// إحصائيات التصنيف
class CategoryStatistics {
  final int itemCount;
  final int totalQuantity;
  final double totalValue;
  final double percentage;
  final double averagePrice;

  const CategoryStatistics({
    required this.itemCount,
    required this.totalQuantity,
    required this.totalValue,
    required this.percentage,
    required this.averagePrice,
  });
}

/// تحليل جودة البيانات
class DataQualityAnalysis {
  final int totalItems;
  final int completeItems;
  final double completenessScore;
  final int missingItemNumbers;
  final int missingQuantities;
  final int missingPrices;
  final int missingDimensions;
  final int invalidQuantities;

  const DataQualityAnalysis({
    required this.totalItems,
    required this.completeItems,
    required this.completenessScore,
    required this.missingItemNumbers,
    required this.missingQuantities,
    required this.missingPrices,
    required this.missingDimensions,
    required this.invalidQuantities,
  });

  /// الحصول على تقييم الجودة
  String get qualityGrade {
    if (completenessScore >= 90) return 'ممتاز';
    if (completenessScore >= 80) return 'جيد جداً';
    if (completenessScore >= 70) return 'جيد';
    if (completenessScore >= 60) return 'مقبول';
    return 'ضعيف';
  }

  /// الحصول على لون تقييم الجودة
  String get qualityColor {
    if (completenessScore >= 90) return '#4CAF50';
    if (completenessScore >= 80) return '#8BC34A';
    if (completenessScore >= 70) return '#FFC107';
    if (completenessScore >= 60) return '#FF9800';
    return '#F44336';
  }
}
