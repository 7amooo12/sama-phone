import 'dart:convert';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// خدمة معالجة الخلايا المتقدمة - تحليل ذكي للخلايا المعقدة والمتعددة المنتجات
class AdvancedCellProcessor {
  
  /// استخراج معرفات المنتجات المتعددة من خلية واحدة
  /// مثال: "YH0916-3 YH0917-3 YH0918-1" -> ["YH0916-3", "YH0917-3", "YH0918-1"]
  static List<String> extractMultipleProductIds(String cellValue) {
    if (cellValue.trim().isEmpty) return [];
    
    AppLogger.info('🔍 تحليل خلية متعددة المنتجات: "$cellValue"');
    
    // تنظيف النص الأولي
    String cleanValue = cellValue.trim();
    
    // أنماط الفصل الشائعة
    final separatorPatterns = [
      RegExp(r'\s+'),           // مسافات متعددة
      RegExp(r'[,،]'),          // فواصل عربية وإنجليزية
      RegExp(r'[;؛]'),          // فاصلة منقوطة
      RegExp(r'[\|\|]'),        // خط عمودي
      RegExp(r'[-–—](?=\s)'),   // شرطة متبوعة بمسافة
      RegExp(r'[\n\r]'),        // أسطر جديدة
    ];
    
    // تطبيق أنماط الفصل
    List<String> products = [cleanValue];
    for (final pattern in separatorPatterns) {
      final newProducts = <String>[];
      for (final product in products) {
        newProducts.addAll(product.split(pattern));
      }
      products = newProducts;
    }
    
    // تنظيف وفلترة النتائج
    final cleanProducts = products
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .where((p) => _isValidProductId(p))
        .toList();
    
    AppLogger.info('📦 تم استخراج ${cleanProducts.length} منتج: $cleanProducts');
    return cleanProducts;
  }
  
  /// تحليل ذكي لخلية الملاحظات لاستخراج المواد والكميات - استخدام القيم الخام من QTY
  static Map<String, dynamic> parseRemarksCell(String remarksValue, int? rawQtyValue) {
    if (remarksValue.trim().isEmpty) {
      return {'materials': <Map<String, dynamic>>[], 'parsed_successfully': false};
    }

    AppLogger.info('🔍 تحليل خلية الملاحظات: "$remarksValue" مع الكمية الخام: $rawQtyValue');

    final materials = <Map<String, dynamic>>[];
    String cleanRemarks = remarksValue.trim();

    // أنماط استخراج المواد الشائعة
    final materialPatterns = [
      // نمط: مادة (كمية)
      RegExp(r'([^()]+)\s*\((\d+)\)', caseSensitive: false),
      // نمط: مادة - كمية
      RegExp(r'([^-]+)\s*-\s*(\d+)', caseSensitive: false),
      // نمط: مادة × كمية
      RegExp(r'([^×]+)\s*×\s*(\d+)', caseSensitive: false),
      // نمط: مادة * كمية
      RegExp(r'([^*]+)\s*\*\s*(\d+)', caseSensitive: false),
    ];

    bool foundStructuredData = false;

    // محاولة استخراج البيانات المنظمة
    for (final pattern in materialPatterns) {
      final matches = pattern.allMatches(cleanRemarks);
      if (matches.isNotEmpty) {
        foundStructuredData = true;
        for (final match in matches) {
          final materialName = match.group(1)?.trim() ?? '';
          final quantityStr = match.group(2)?.trim() ?? '0';
          final quantity = int.tryParse(quantityStr) ?? 0;

          if (materialName.isNotEmpty && quantity > 0) {
            materials.add({
              'material_name': materialName,
              'quantity': quantity, // استخدام الكمية المستخرجة من النمط
              'extraction_method': 'structured_pattern',
              'confidence': 0.9,
              'source': 'remarks_pattern',
            });
          }
        }
        break; // استخدم أول نمط ناجح فقط
      }
    }

    // إذا لم نجد بيانات منظمة، حاول التحليل الذكي مع القيمة الخام
    if (!foundStructuredData) {
      final intelligentMaterials = _parseRemarksIntelligently(cleanRemarks, rawQtyValue);
      materials.addAll(intelligentMaterials);
    }

    AppLogger.info('🧪 تم استخراج ${materials.length} مادة من الملاحظات باستخدام القيم الخام');

    return {
      'materials': materials,
      'parsed_successfully': materials.isNotEmpty,
      'original_remarks': remarksValue,
      'raw_qty_used': rawQtyValue,
      'extraction_confidence': foundStructuredData ? 0.9 : 0.6,
    };
  }
  
  /// تحليل ذكي للملاحظات بدون أنماط محددة - استخدام القيم الخام من QTY
  static List<Map<String, dynamic>> _parseRemarksIntelligently(String remarks, int? rawQtyValue) {
    final materials = <Map<String, dynamic>>[];

    // فصل النص إلى أجزاء محتملة
    final parts = _splitRemarksIntoParts(remarks);

    for (final part in parts) {
      if (_isMaterialDescription(part)) {
        // استخدام القيمة الخام من عمود QTY بدون عمليات حسابية
        // إذا كان هناك عدة مواد، استخدم نفس الكمية لكل مادة (كما هي في Excel)
        final materialQuantity = rawQtyValue ?? 1;

        materials.add({
          'material_name': part.trim(),
          'quantity': materialQuantity, // القيمة الخام من QTY بدون تقسيم
          'extraction_method': 'intelligent_parsing_raw',
          'confidence': 0.6,
          'source': 'raw_qty_column',
        });
      }
    }

    // إذا لم نجد مواد محددة، اعتبر النص كله مادة واحدة مع القيمة الخام
    if (materials.isEmpty && remarks.trim().isNotEmpty) {
      materials.add({
        'material_name': remarks.trim(),
        'quantity': rawQtyValue ?? 1, // القيمة الخام من QTY
        'extraction_method': 'fallback_single_material_raw',
        'confidence': 0.4,
        'source': 'raw_qty_column',
      });
    }

    return materials;
  }
  
  /// فصل الملاحظات إلى أجزاء محتملة
  static List<String> _splitRemarksIntoParts(String remarks) {
    // أنماط الفصل للمواد
    final separators = [
      RegExp(r'[,،]'),          // فواصل
      RegExp(r'[;؛]'),          // فاصلة منقوطة
      RegExp(r'\s+و\s+'),       // "و" العربية
      RegExp(r'\s+and\s+'),     // "and" الإنجليزية
      RegExp(r'[\n\r]'),        // أسطر جديدة
      RegExp(r'\s*\+\s*'),      // علامة زائد
    ];
    
    List<String> parts = [remarks];
    for (final separator in separators) {
      final newParts = <String>[];
      for (final part in parts) {
        newParts.addAll(part.split(separator));
      }
      parts = newParts;
    }
    
    return parts
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .where((p) => p.length > 2) // تجاهل الأجزاء القصيرة جداً
        .toList();
  }
  
  /// التحقق من كون النص وصف مادة صالح
  static bool _isMaterialDescription(String text) {
    if (text.length < 3) return false;
    
    // كلمات مفتاحية تدل على المواد
    final materialKeywords = [
      'طوق', 'شبوه', 'كرستاله', 'بلاستيك', 'معدن', 'الومنيوم', 'حديد',
      'خشب', 'زجاج', 'قماش', 'جلد', 'مطاط', 'سيليكون',
      'ring', 'plastic', 'metal', 'aluminum', 'steel', 'wood', 'glass',
      'fabric', 'leather', 'rubber', 'silicone', 'crystal'
    ];
    
    final lowerText = text.toLowerCase();
    return materialKeywords.any((keyword) => lowerText.contains(keyword.toLowerCase()));
  }
  
  /// التحقق من صحة معرف المنتج
  static bool _isValidProductId(String productId) {
    if (productId.length < 2) return false;
    
    // أنماط معرفات المنتجات الشائعة
    final validPatterns = [
      RegExp(r'^[A-Z]{2,4}\d{3,6}(-\d+)?$'),     // YH0916-3
      RegExp(r'^\d{4,8}(/\d+[A-Z]*)?$'),         // 2333/1GD
      RegExp(r'^[A-Z]+\d+[A-Z]*$'),              // ABC123X
      RegExp(r'^[A-Z]{1,3}-\d{3,6}$'),           // A-12345
    ];
    
    return validPatterns.any((pattern) => pattern.hasMatch(productId.toUpperCase()));
  }
  
  /// دمج البيانات من خلايا متعددة لنفس المنتج
  static Map<String, dynamic> mergeProductData(List<Map<String, dynamic>> productRows) {
    if (productRows.isEmpty) return {};
    if (productRows.length == 1) return productRows.first;
    
    AppLogger.info('🔄 دمج ${productRows.length} صف لنفس المنتج');
    
    final mergedData = Map<String, dynamic>.from(productRows.first);
    final allMaterials = <Map<String, dynamic>>[];
    int totalQuantity = 0;
    int totalCartons = 0;
    final sourceRows = <String>[];
    
    for (int i = 0; i < productRows.length; i++) {
      final row = productRows[i];
      
      // جمع الكميات
      final quantity = row['total_quantity'] as int? ?? 0;
      final cartons = row['carton_count'] as int? ?? 0;
      totalQuantity += quantity;
      totalCartons += cartons;
      
      // جمع المواد
      if (row['materials'] != null) {
        final materials = row['materials'] as List<Map<String, dynamic>>;
        allMaterials.addAll(materials);
      }
      
      // تتبع الصفوف المصدر
      sourceRows.add('row_${i + 1}');
    }
    
    // تحديث البيانات المدمجة
    mergedData['total_quantity'] = totalQuantity;
    mergedData['carton_count'] = totalCartons;
    mergedData['materials'] = allMaterials;
    mergedData['source_rows'] = sourceRows;
    mergedData['is_merged_product'] = true;
    mergedData['merge_confidence'] = 0.8;
    
    AppLogger.info('✅ تم دمج المنتج: كمية إجمالية $totalQuantity، ${allMaterials.length} مادة');
    
    return mergedData;
  }
  
  /// تنظيف وتوحيد معرف المنتج
  static String normalizeProductId(String productId) {
    return productId
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'\s+'), '')  // إزالة المسافات
        .replaceAll(RegExp(r'[^\w\-/]'), ''); // الاحتفاظ بالأحرف والأرقام والشرطات والشرطة المائلة فقط
  }
}
