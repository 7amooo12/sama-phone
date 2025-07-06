import 'package:smartbiztracker_new/models/warehouse_reports_model.dart';
import 'package:smartbiztracker_new/models/warehouse_inventory_model.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// خدمة المطابقة الذكية للمنتجات
class SmartProductMatcher {
  
  /// مطابقة منتجات API مع مخزون المخازن
  static List<SmartProductMatch> matchProducts({
    required List<ApiProductModel> apiProducts,
    required List<WarehouseInventoryModel> warehouseInventory,
    double minimumMatchScore = 0.7,
  }) {
    AppLogger.info('🔍 بدء المطابقة الذكية للمنتجات: ${apiProducts.length} منتج API مع ${warehouseInventory.length} منتج مخزن');
    
    final matches = <SmartProductMatch>[];
    
    for (final apiProduct in apiProducts) {
      final match = _findBestMatch(apiProduct, warehouseInventory, minimumMatchScore);
      matches.add(match);
    }
    
    final matchedCount = matches.where((m) => m.isMatched).length;
    final missingCount = matches.where((m) => m.isMissing).length;
    
    AppLogger.info('✅ اكتملت المطابقة: $matchedCount مطابق، $missingCount مفقود');
    
    return matches;
  }

  /// العثور على أفضل مطابقة لمنتج API
  static SmartProductMatch _findBestMatch(
    ApiProductModel apiProduct,
    List<WarehouseInventoryModel> warehouseInventory,
    double minimumMatchScore,
  ) {
    double bestScore = 0.0;
    WarehouseInventoryModel? bestMatch;
    final matchReasons = <String>[];
    bool hasExactIdMatch = false;

    // أولاً: البحث عن مطابقة معرف مباشرة
    final apiProductId = apiProduct.id.toString().trim();

    for (final warehouseProduct in warehouseInventory) {
      final warehouseProductId = warehouseProduct.productId.toString().trim();

      // فحص مطابقة المعرف المباشرة أولاً
      if (apiProductId == warehouseProductId) {
        bestMatch = warehouseProduct;
        bestScore = 1.0; // أعلى درجة ممكنة للمطابقة المباشرة
        hasExactIdMatch = true;
        matchReasons.add('مطابقة معرف مباشرة: $apiProductId');
        AppLogger.info('🎯 مطابقة معرف مباشرة: API[$apiProductId] = Warehouse[$warehouseProductId], الكمية: ${warehouseProduct.quantity}');
        break; // توقف عند أول مطابقة معرف مباشرة
      }
    }

    // إذا لم نجد مطابقة معرف مباشرة، ابحث بالطريقة التقليدية
    if (!hasExactIdMatch) {
      for (final warehouseProduct in warehouseInventory) {
        final score = _calculateMatchScore(apiProduct, warehouseProduct);

        if (score > bestScore) {
          bestScore = score;
          bestMatch = warehouseProduct;
        }
      }
    }

    // تحديد نوع المطابقة والأسباب
    MatchType matchType;
    if (hasExactIdMatch || bestScore >= 0.95) {
      matchType = MatchType.exact;
      if (hasExactIdMatch) {
        matchReasons.add('مطابقة معرف مباشرة');
      } else {
        matchReasons.add('مطابقة تامة في الاسم والمعرف');
      }
    } else if (bestScore >= 0.8) {
      matchType = MatchType.similar;
      matchReasons.add('مطابقة عالية في الاسم أو الخصائص');
    } else if (bestScore >= minimumMatchScore) {
      matchType = MatchType.partial;
      matchReasons.add('مطابقة جزئية في بعض الخصائص');
    } else {
      matchType = MatchType.none;
      matchReasons.add('لا توجد مطابقة كافية');
      // إذا كانت النتيجة أقل من الحد الأدنى، نضع bestMatch = null لتجنب الكميات الوهمية
      if (!hasExactIdMatch && bestScore < minimumMatchScore) {
        bestMatch = null;
        AppLogger.info('🚫 رفض المطابقة الضعيفة: API[${apiProduct.id}] - أفضل نتيجة: ${bestScore.toStringAsFixed(3)} < الحد الأدنى: $minimumMatchScore');
      }
    }

    // تسجيل تفصيلي للنتيجة
    if (bestMatch != null) {
      AppLogger.info('🔍 نتيجة المطابقة: API[${apiProduct.id}] -> Warehouse[${bestMatch.productId}], النتيجة: ${bestScore.toStringAsFixed(3)}, النوع: $matchType, الكمية: ${bestMatch.quantity}');
    } else {
      AppLogger.info('❌ لا توجد مطابقة صحيحة: API[${apiProduct.id}:"${apiProduct.name}"] (أفضل نتيجة: ${bestScore.toStringAsFixed(3)})');
    }

    return SmartProductMatch(
      apiProduct: apiProduct,
      warehouseProduct: bestMatch,
      matchScore: bestScore,
      matchType: matchType,
      matchReasons: matchReasons,
    );
  }

  /// حساب درجة المطابقة بين منتج API ومنتج المخزن
  static double _calculateMatchScore(
    ApiProductModel apiProduct,
    WarehouseInventoryModel warehouseProduct,
  ) {
    double score = 0.0;
    int factors = 0;

    // تنظيف وتحويل المعرفات للمقارنة مع معالجة أنواع البيانات المختلفة
    final apiProductId = _normalizeId(apiProduct.id);
    final warehouseProductId = _normalizeId(warehouseProduct.productId);

    // مطابقة المعرف (أعلى أولوية) - إذا تطابق المعرف، فهذا يضمن مطابقة قوية
    bool hasIdMatch = apiProductId == warehouseProductId;
    if (hasIdMatch) {
      // مطابقة المعرف تحصل على وزن عالي جداً لضمان تجاوز العتبة
      score += 1.0;
      factors++;

      // إذا كان هناك مطابقة في المعرف، نعطي مكافأة إضافية لضمان النجاح
      score += 0.5; // مكافأة إضافية للمطابقة المثالية
      factors++;

      AppLogger.info('🎯 مطابقة معرف مؤكدة: API[$apiProductId] = Warehouse[$warehouseProductId], الكمية: ${warehouseProduct.quantity}');

      // عند مطابقة المعرف، نعطي درجات افتراضية عالية للحقول المفقودة
      // هذا يضمن أن مطابقة المعرف تحصل على درجة عالية حتى لو كانت البيانات الأخرى مفقودة
      score += 0.8; // درجة افتراضية للاسم
      score += 0.6; // درجة افتراضية للفئة
      score += 0.3; // درجة افتراضية للسعر
      factors += 3;

      return score / factors; // إرجاع مبكر للمطابقة المباشرة
    }

    // مطابقة الاسم (أولوية عالية) - فقط إذا كان الاسم متوفراً
    final warehouseProductName = warehouseProduct.product?.name ?? '';
    if (warehouseProductName.isNotEmpty && apiProduct.name.isNotEmpty) {
      final nameScore = _calculateNameSimilarity(
        apiProduct.name,
        warehouseProductName,
      );
      score += nameScore * 0.8;
      factors++;

      if (nameScore > 0.8) {
        AppLogger.info('🔤 مطابقة اسم عالية: "${apiProduct.name}" ≈ "${warehouseProductName}", النتيجة: ${nameScore.toStringAsFixed(3)}');
      }
    }

    // مطابقة الفئة (أولوية متوسطة)
    if (warehouseProduct.product?.category != null && apiProduct.category.isNotEmpty) {
      final categoryScore = _calculateCategorySimilarity(
        apiProduct.category,
        warehouseProduct.product!.category,
      );
      score += categoryScore * 0.6;
      factors++;
    }

    // مطابقة SKU (أولوية متوسطة)
    if (apiProduct.sku != null && warehouseProduct.product?.sku != null) {
      final skuScore = _calculateSkuSimilarity(
        apiProduct.sku!,
        warehouseProduct.product!.sku,
      );
      score += skuScore * 0.7;
      factors++;
    }

    // مطابقة السعر (أولوية منخفضة)
    if (warehouseProduct.product?.price != null && apiProduct.price > 0) {
      final priceScore = _calculatePriceSimilarity(
        apiProduct.price,
        warehouseProduct.product!.price,
      );
      score += priceScore * 0.3;
      factors++;
    }

    final finalScore = factors > 0 ? score / factors : 0.0;

    // تسجيل تفصيلي للمطابقة لأغراض التشخيص
    if (finalScore > 0.5) {
      AppLogger.info('📊 نتيجة المطابقة: API[${apiProduct.id}:"${apiProduct.name}"] -> Warehouse[${warehouseProduct.productId}:"${warehouseProductName}"], النتيجة: ${finalScore.toStringAsFixed(3)}, الكمية: ${warehouseProduct.quantity}');
    }

    return finalScore;
  }

  /// تطبيع المعرف للمقارنة
  static String _normalizeId(dynamic id) {
    if (id == null) return '';

    String normalizedId = id.toString().trim();

    // إزالة البادئات الشائعة
    normalizedId = normalizedId.replaceAll(RegExp(r'^(sama_|product_|item_)', caseSensitive: false), '');

    // إزالة الأصفار البادئة للأرقام
    if (RegExp(r'^\d+$').hasMatch(normalizedId)) {
      normalizedId = int.parse(normalizedId).toString();
    }

    return normalizedId.toLowerCase();
  }

  /// حساب تشابه الأسماء مع تحسينات للنص العربي
  static double _calculateNameSimilarity(String name1, String name2) {
    if (name1.isEmpty || name2.isEmpty) return 0.0;

    // تنظيف النصوص مع تحسينات للعربية
    final cleanName1 = _cleanArabicText(name1);
    final cleanName2 = _cleanArabicText(name2);

    // مطابقة تامة
    if (cleanName1 == cleanName2) return 1.0;

    // فحص الاحتواء (إذا كان أحد الأسماء يحتوي على الآخر)
    if (cleanName1.contains(cleanName2) || cleanName2.contains(cleanName1)) {
      return 0.9;
    }

    // مطابقة جزئية باستخدام Levenshtein distance
    final distance = _levenshteinDistance(cleanName1, cleanName2);
    final maxLength = [cleanName1.length, cleanName2.length].reduce((a, b) => a > b ? a : b);

    if (maxLength == 0) return 0.0;

    final similarity = 1.0 - (distance / maxLength);

    // مكافأة إضافية للكلمات المشتركة مع تحسينات للعربية
    final commonWords = _countCommonArabicWords(cleanName1, cleanName2);
    final totalWords = _countWords(cleanName1) + _countWords(cleanName2);
    final wordBonus = totalWords > 0 ? (commonWords * 2) / totalWords : 0.0;

    // مكافأة إضافية للكلمات الرئيسية المطابقة
    final keywordBonus = _calculateKeywordMatchBonus(cleanName1, cleanName2);

    final finalScore = (similarity + wordBonus + keywordBonus) / 3;

    return finalScore.clamp(0.0, 1.0);
  }

  /// حساب تشابه الفئات
  static double _calculateCategorySimilarity(String category1, String category2) {
    if (category1.isEmpty || category2.isEmpty) return 0.0;
    
    final cleanCat1 = _cleanText(category1);
    final cleanCat2 = _cleanText(category2);
    
    if (cleanCat1 == cleanCat2) return 1.0;
    
    // فئات مشابهة معروفة
    final similarCategories = {
      'إلكترونيات': ['الكترونيات', 'electronics', 'electronic'],
      'ملابس': ['clothing', 'clothes', 'fashion'],
      'طعام': ['food', 'غذاء', 'مأكولات'],
      'مشروبات': ['drinks', 'beverages', 'شراب'],
    };
    
    for (final entry in similarCategories.entries) {
      final mainCategory = entry.key;
      final alternatives = entry.value;
      
      if ((cleanCat1 == mainCategory || alternatives.contains(cleanCat1)) &&
          (cleanCat2 == mainCategory || alternatives.contains(cleanCat2))) {
        return 0.8;
      }
    }
    
    return _calculateNameSimilarity(cleanCat1, cleanCat2) * 0.7;
  }

  /// حساب تشابه SKU
  static double _calculateSkuSimilarity(String sku1, String sku2) {
    if (sku1.isEmpty || sku2.isEmpty) return 0.0;
    
    final cleanSku1 = sku1.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final cleanSku2 = sku2.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    
    if (cleanSku1 == cleanSku2) return 1.0;
    
    // مطابقة جزئية
    if (cleanSku1.contains(cleanSku2) || cleanSku2.contains(cleanSku1)) {
      return 0.8;
    }
    
    return _calculateNameSimilarity(cleanSku1, cleanSku2) * 0.6;
  }

  /// حساب تشابه الأسعار
  static double _calculatePriceSimilarity(double price1, double price2) {
    if (price1 <= 0 || price2 <= 0) return 0.0;
    
    final difference = (price1 - price2).abs();
    final average = (price1 + price2) / 2;
    
    if (average == 0) return 1.0;
    
    final percentageDifference = difference / average;
    
    // مطابقة ممتازة إذا كان الفرق أقل من 5%
    if (percentageDifference <= 0.05) return 1.0;
    
    // مطابقة جيدة إذا كان الفرق أقل من 20%
    if (percentageDifference <= 0.2) return 0.8;
    
    // مطابقة متوسطة إذا كان الفرق أقل من 50%
    if (percentageDifference <= 0.5) return 0.5;
    
    return 0.0;
  }

  /// تنظيف النص العربي مع تحسينات
  static String _cleanArabicText(String text) {
    return text
        .toLowerCase()
        .trim()
        // إزالة التشكيل العربي
        .replaceAll(RegExp(r'[\u064B-\u0652\u0670\u0640]'), '')
        // توحيد الأحرف المتشابهة
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        // إزالة الرموز غير المرغوبة مع الاحتفاظ بالعربية والإنجليزية والأرقام
        .replaceAll(RegExp(r'[^\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFFa-z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  /// تنظيف النص (للتوافق مع الكود القديم)
  static String _cleanText(String text) {
    return _cleanArabicText(text);
  }

  /// حساب Levenshtein distance
  static int _levenshteinDistance(String s1, String s2) {
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;
    
    final matrix = List.generate(
      s1.length + 1,
      (i) => List.generate(s2.length + 1, (j) => 0),
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
        ].reduce((a, b) => a < b ? a : b);
      }
    }
    
    return matrix[s1.length][s2.length];
  }

  /// عد الكلمات المشتركة مع تحسينات للعربية
  static int _countCommonArabicWords(String text1, String text2) {
    final words1 = text1.split(' ').where((w) => w.isNotEmpty && w.length > 2).toSet();
    final words2 = text2.split(' ').where((w) => w.isNotEmpty && w.length > 2).toSet();

    int commonCount = 0;

    // مطابقة تامة للكلمات
    commonCount += words1.intersection(words2).length;

    // مطابقة جزئية للكلمات الطويلة
    for (final word1 in words1) {
      if (word1.length > 4) {
        for (final word2 in words2) {
          if (word2.length > 4 && !words1.intersection(words2).contains(word1)) {
            if (word1.contains(word2) || word2.contains(word1)) {
              commonCount++;
              break;
            }
          }
        }
      }
    }

    return commonCount;
  }

  /// عد الكلمات المشتركة (للتوافق مع الكود القديم)
  static int _countCommonWords(String text1, String text2) {
    return _countCommonArabicWords(text1, text2);
  }

  /// عد الكلمات
  static int _countWords(String text) {
    return text.split(' ').where((w) => w.isNotEmpty).length;
  }

  /// حساب مكافأة الكلمات الرئيسية
  static double _calculateKeywordMatchBonus(String text1, String text2) {
    // كلمات رئيسية مهمة في أسماء المنتجات
    final keywords = ['جهاز', 'كمبيوتر', 'لابتوب', 'موبايل', 'تلفون', 'شاشة', 'طابعة', 'كاميرا', 'سماعة'];

    double bonus = 0.0;
    for (final keyword in keywords) {
      if (text1.contains(keyword) && text2.contains(keyword)) {
        bonus += 0.1;
      }
    }

    return bonus.clamp(0.0, 0.3); // حد أقصى 30% مكافأة
  }

  /// العثور على المنتجات المفقودة من المعرض
  static List<ApiProductModel> findMissingFromExhibition({
    required List<ApiProductModel> apiProducts,
    required List<WarehouseInventoryModel> exhibitionInventory,
    double minimumMatchScore = 0.7,
  }) {
    AppLogger.info('🔍 البحث عن المنتجات المفقودة من المعرض');
    AppLogger.info('📊 إجمالي منتجات API: ${apiProducts.length}');
    AppLogger.info('📦 إجمالي منتجات المعرض (كمية > 0): ${exhibitionInventory.length}');

    // فلترة منتجات المعرض للتأكد من أن الكمية > 0
    final validExhibitionInventory = exhibitionInventory.where((item) => item.quantity > 0).toList();
    AppLogger.info('✅ منتجات المعرض الصالحة: ${validExhibitionInventory.length}');

    // طباعة عينة من المعرفات للتشخيص
    if (validExhibitionInventory.isNotEmpty) {
      final sampleWarehouseIds = validExhibitionInventory.take(10).map((e) => e.productId).join(', ');
      AppLogger.info('🔍 عينة من معرفات المعرض: $sampleWarehouseIds');
    }
    if (apiProducts.isNotEmpty) {
      final sampleApiIds = apiProducts.take(10).map((e) => e.id).join(', ');
      AppLogger.info('🔍 عينة من معرفات API: $sampleApiIds');
    }

    // إنشاء مجموعة من معرفات المعرض المطبعة للبحث السريع
    final exhibitionProductIds = validExhibitionInventory
        .map((item) => _normalizeId(item.productId))
        .toSet();

    AppLogger.info('🔍 معرفات المعرض المطبعة: ${exhibitionProductIds.take(10).join(', ')}');

    final missingProducts = <ApiProductModel>[];
    final foundProducts = <ApiProductModel>[];

    // فحص كل منتج API
    for (final apiProduct in apiProducts) {
      final normalizedApiId = _normalizeId(apiProduct.id);

      // فحص مطابقة المعرف المباشرة أولاً
      if (exhibitionProductIds.contains(normalizedApiId)) {
        foundProducts.add(apiProduct);
        AppLogger.info('✅ منتج موجود (مطابقة معرف): ${apiProduct.id} -> $normalizedApiId');
        continue;
      }

      // إذا لم نجد مطابقة معرف مباشرة، استخدم المطابقة الذكية
      bool foundMatch = false;
      for (final warehouseProduct in validExhibitionInventory) {
        final matchScore = _calculateMatchScore(apiProduct, warehouseProduct);

        if (matchScore >= minimumMatchScore) {
          foundProducts.add(apiProduct);
          foundMatch = true;
          AppLogger.info('✅ منتج موجود (مطابقة ذكية): ${apiProduct.id} -> ${warehouseProduct.productId}, النتيجة: ${matchScore.toStringAsFixed(3)}');
          break;
        }
      }

      if (!foundMatch) {
        missingProducts.add(apiProduct);
        AppLogger.info('❌ منتج مفقود: ${apiProduct.id} - ${apiProduct.name}');
      }
    }

    AppLogger.info('📈 نتائج التحليل النهائية:');
    AppLogger.info('  - إجمالي منتجات API: ${apiProducts.length}');
    AppLogger.info('  - منتجات موجودة في المعرض: ${foundProducts.length}');
    AppLogger.info('  - منتجات مفقودة من المعرض: ${missingProducts.length}');
    AppLogger.info('  - نسبة التغطية: ${((foundProducts.length / apiProducts.length) * 100).toStringAsFixed(1)}%');

    // التحقق من التطابق المزدوج
    final foundIds = foundProducts.map((p) => p.id).toSet();
    final missingIds = missingProducts.map((p) => p.id).toSet();
    final duplicates = foundIds.intersection(missingIds);

    if (duplicates.isNotEmpty) {
      AppLogger.warning('⚠️ تم العثور على منتجات مكررة في النتائج: ${duplicates.join(', ')}');
    }

    return missingProducts;
  }
}
