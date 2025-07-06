import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:smartbiztracker_new/models/import_analysis_models.dart';
import 'package:smartbiztracker_new/services/import_analysis/advanced_cell_processor.dart';
import 'package:smartbiztracker_new/services/import_analysis/performance_optimizer.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// خدمة التجميع الذكي للمنتجات - تجميع المنتجات المتشابهة وتجميع موادها
class ProductGroupingService {
  static const Uuid _uuid = Uuid();
  
  /// تجميع المنتجات الذكي من البيانات المستخرجة مع تحسين الأداء
  static Future<List<ProductGroup>> groupProducts(List<Map<String, dynamic>> rawData) async {
    return await PerformanceOptimizer.processWithTimeLimit(
      operation: () => _performGrouping(rawData),
      operationName: 'تجميع المنتجات الذكي',
    );
  }

  /// تنفيذ التجميع الفعلي مع التحسين
  static Future<List<ProductGroup>> _performGrouping(List<Map<String, dynamic>> rawData) async {
    AppLogger.info('🔄 بدء التجميع الذكي للمنتجات من ${rawData.length} صف');

    // استخدام التخزين المؤقت للبيانات المتشابهة
    final cacheKey = 'grouping_${rawData.length}_${rawData.hashCode}';

    return await PerformanceOptimizer.cacheResult(
      key: cacheKey,
      operation: () async {
        // الخطوة 1: معالجة الخلايا المتعددة المنتجات بشكل محسن
        final expandedData = await PerformanceOptimizer.processBatches(
          data: rawData,
          processor: (row) => _processRowOptimized(row, rawData.indexOf(row)),
          operationName: 'توسيع الخلايا المتعددة',
          batchSize: 50,
        );

        final flattenedData = expandedData.expand((list) => list).toList();
        AppLogger.info('📈 تم توسيع البيانات إلى ${flattenedData.length} عنصر');

        // الخطوة 2: تجميع المنتجات حسب معرف المنتج
        final groupedProducts = await _groupByProductId(flattenedData);
        AppLogger.info('🗂️ تم تجميع ${groupedProducts.length} مجموعة منتجات');

        // الخطوة 3: تجميع المواد لكل مجموعة مع التحسين
        final finalGroups = await PerformanceOptimizer.processBatches(
          data: groupedProducts.entries.toList(),
          processor: (entry) => _createProductGroupOptimized(entry.key, entry.value),
          operationName: 'تجميع المواد',
          batchSize: 20,
        );

        AppLogger.info('✅ تم إنشاء ${finalGroups.length} مجموعة نهائية');
        return finalGroups;
      },
    );
  }

  /// معالجة الصف المحسنة
  static Future<List<Map<String, dynamic>>> _processRowOptimized(Map<String, dynamic> row, int rowIndex) async {
    final itemNumber = row['item_number']?.toString() ?? '';

    if (itemNumber.isEmpty) {
      return []; // تجاهل الصفوف بدون معرف منتج
    }

    // استخراج معرفات المنتجات المتعددة
    final productIds = AdvancedCellProcessor.extractMultipleProductIds(itemNumber);

    if (productIds.length <= 1) {
      // منتج واحد فقط - إضافة مباشرة
      final processedRow = await _processRowData(row, rowIndex);
      return processedRow != null ? [processedRow] : [];
    } else {
      // منتجات متعددة - توزيع البيانات
      final baseQuantity = row['total_quantity'] as int? ?? 0;
      final baseCartons = row['carton_count'] as int? ?? 0;

      // توزيع الكميات بالتساوي
      final quantityPerProduct = productIds.length > 0 ? (baseQuantity / productIds.length).round() : 0;
      final cartonsPerProduct = productIds.length > 0 ? (baseCartons / productIds.length).round() : 0;

      final expandedRows = <Map<String, dynamic>>[];

      for (int i = 0; i < productIds.length; i++) {
        final productId = productIds[i];
        final expandedRow = Map<String, dynamic>.from(row);

        expandedRow['item_number'] = productId;
        expandedRow['total_quantity'] = quantityPerProduct;
        expandedRow['carton_count'] = cartonsPerProduct;
        expandedRow['source_row_index'] = rowIndex;
        expandedRow['expanded_from_multi_product'] = true;
        expandedRow['original_item_number'] = itemNumber;

        final processedRow = await _processRowData(expandedRow, rowIndex, i);
        if (processedRow != null) {
          expandedRows.add(processedRow);
        }
      }

      return expandedRows;
    }
  }

  /// إنشاء مجموعة منتج محسنة
  static Future<ProductGroup> _createProductGroupOptimized(String productId, List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) {
      throw ArgumentError('قائمة الصفوف فارغة للمنتج: $productId');
    }

    // جمع البيانات الأساسية
    final firstRow = rows.first;
    final originalItemNumber = firstRow['item_number'] as String? ?? productId;
    final imageUrl = firstRow['image_url'] as String?;

    // جمع الكميات والمواد بشكل محسن
    int totalQuantity = 0;
    int totalCartons = 0;
    final sourceRowReferences = <String>[];
    final allMaterials = <Map<String, dynamic>>[];

    for (final row in rows) {
      totalQuantity += (row['total_quantity'] as int? ?? 0);
      totalCartons += (row['carton_count'] as int? ?? 0);
      sourceRowReferences.add(row['row_reference'] as String);

      // جمع المواد
      final materials = row['extracted_materials'] as List<dynamic>? ?? [];
      for (final material in materials) {
        if (material is Map<String, dynamic>) {
          allMaterials.add(material);
        }
      }
    }

    // تجميع المواد المتشابهة بشكل محسن
    final aggregatedMaterials = _aggregateSimilarMaterialsOptimized(allMaterials);

    // إنشاء كائنات MaterialEntry
    final materialEntries = aggregatedMaterials.map((materialData) {
      return MaterialEntry(
        id: _uuid.v4(),
        materialName: materialData['material_name'] as String,
        quantity: materialData['quantity'] as int,
        originalRemarks: materialData['original_remarks'] as String?,
        category: _categorizeMaterial(materialData['material_name'] as String),
        metadata: {
          'extraction_method': materialData['extraction_method'],
          'confidence': materialData['confidence'],
        },
        createdAt: DateTime.now(),
      );
    }).toList();

    // حساب ثقة التجميع
    final groupingConfidence = _calculateGroupingConfidence(rows, materialEntries);

    // إنشاء مجموعة المنتج
    return ProductGroup(
      id: _uuid.v4(),
      itemNumber: originalItemNumber,
      imageUrl: imageUrl,
      materials: materialEntries,
      totalQuantity: totalQuantity,
      totalCartonCount: totalCartons,
      sourceRowReferences: sourceRowReferences,
      aggregatedData: {
        'original_rows_count': rows.length,
        'materials_sources': allMaterials.length,
        'aggregation_method': 'optimized_smart_grouping',
        'processing_time': DateTime.now().toIso8601String(),
      },
      groupingConfidence: groupingConfidence,
      createdAt: DateTime.now(),
    );
  }
  
  /// توسيع الخلايا التي تحتوي على منتجات متعددة
  static Future<List<Map<String, dynamic>>> _expandMultiProductCells(List<Map<String, dynamic>> rawData) async {
    final expandedData = <Map<String, dynamic>>[];
    
    for (int rowIndex = 0; rowIndex < rawData.length; rowIndex++) {
      final row = rawData[rowIndex];
      final itemNumber = row['item_number']?.toString() ?? '';
      
      if (itemNumber.isEmpty) {
        continue; // تجاهل الصفوف بدون معرف منتج
      }
      
      // استخراج معرفات المنتجات المتعددة
      final productIds = AdvancedCellProcessor.extractMultipleProductIds(itemNumber);
      
      if (productIds.length <= 1) {
        // منتج واحد فقط - إضافة مباشرة
        final processedRow = await _processRowData(row, rowIndex);
        if (processedRow != null) {
          expandedData.add(processedRow);
        }
      } else {
        // منتجات متعددة - توزيع البيانات
        AppLogger.info('📦 توسيع صف $rowIndex إلى ${productIds.length} منتجات: $productIds');
        
        final baseQuantity = row['total_quantity'] as int? ?? 0;
        final baseCartons = row['carton_count'] as int? ?? 0;
        
        // توزيع الكميات بالتساوي
        final quantityPerProduct = productIds.length > 0 ? (baseQuantity / productIds.length).round() : 0;
        final cartonsPerProduct = productIds.length > 0 ? (baseCartons / productIds.length).round() : 0;
        
        for (int i = 0; i < productIds.length; i++) {
          final productId = productIds[i];
          final expandedRow = Map<String, dynamic>.from(row);
          
          expandedRow['item_number'] = productId;
          expandedRow['total_quantity'] = quantityPerProduct;
          expandedRow['carton_count'] = cartonsPerProduct;
          expandedRow['source_row_index'] = rowIndex;
          expandedRow['expanded_from_multi_product'] = true;
          expandedRow['original_item_number'] = itemNumber;
          
          final processedRow = await _processRowData(expandedRow, rowIndex, i);
          if (processedRow != null) {
            expandedData.add(processedRow);
          }
        }
      }
    }
    
    return expandedData;
  }
  
  /// معالجة بيانات الصف الواحد
  static Future<Map<String, dynamic>?> _processRowData(Map<String, dynamic> row, int rowIndex, [int? subIndex]) async {
    final itemNumber = row['item_number']?.toString() ?? '';
    if (itemNumber.isEmpty) return null;
    
    // تنظيف معرف المنتج
    final normalizedId = AdvancedCellProcessor.normalizeProductId(itemNumber);
    
    // معالجة الملاحظات لاستخراج المواد
    final remarksValue = row['remarks_a']?.toString() ?? '';
    final totalQuantity = row['total_quantity'] as int?;
    
    final remarksAnalysis = AdvancedCellProcessor.parseRemarksCell(remarksValue, totalQuantity);
    
    // إنشاء البيانات المعالجة
    final processedRow = Map<String, dynamic>.from(row);
    processedRow['normalized_item_number'] = normalizedId;
    processedRow['extracted_materials'] = remarksAnalysis['materials'];
    processedRow['materials_extraction_confidence'] = remarksAnalysis['extraction_confidence'];
    processedRow['row_reference'] = subIndex != null ? '${rowIndex + 1}.${subIndex + 1}' : '${rowIndex + 1}';
    
    return processedRow;
  }
  
  /// تجميع المنتجات حسب معرف المنتج
  static Future<Map<String, List<Map<String, dynamic>>>> _groupByProductId(List<Map<String, dynamic>> expandedData) async {
    final grouped = <String, List<Map<String, dynamic>>>{};
    
    for (final row in expandedData) {
      final normalizedId = row['normalized_item_number'] as String;
      grouped.putIfAbsent(normalizedId, () => []).add(row);
    }
    
    // طباعة إحصائيات التجميع
    for (final entry in grouped.entries) {
      final productId = entry.key;
      final rows = entry.value;
      if (rows.length > 1) {
        AppLogger.info('🔗 المنتج "$productId" موجود في ${rows.length} صف');
      }
    }
    
    return grouped;
  }
  
  /// تجميع المواد لكل مجموعة منتجات
  static Future<List<ProductGroup>> _aggregateMaterials(Map<String, List<Map<String, dynamic>>> groupedProducts) async {
    final productGroups = <ProductGroup>[];
    
    for (final entry in groupedProducts.entries) {
      final productId = entry.key;
      final rows = entry.value;
      
      if (rows.isEmpty) continue;
      
      // جمع البيانات الأساسية
      final firstRow = rows.first;
      final originalItemNumber = firstRow['item_number'] as String? ?? productId;
      final imageUrl = firstRow['image_url'] as String?;
      
      // جمع الكميات
      int totalQuantity = 0;
      int totalCartons = 0;
      final sourceRowReferences = <String>[];
      final allMaterials = <Map<String, dynamic>>[];
      
      for (final row in rows) {
        totalQuantity += (row['total_quantity'] as int? ?? 0);
        totalCartons += (row['carton_count'] as int? ?? 0);
        sourceRowReferences.add(row['row_reference'] as String);
        
        // جمع المواد
        final materials = row['extracted_materials'] as List<dynamic>? ?? [];
        for (final material in materials) {
          if (material is Map<String, dynamic>) {
            allMaterials.add(material);
          }
        }
      }
      
      // تجميع المواد المتشابهة
      final aggregatedMaterials = _aggregateSimilarMaterials(allMaterials);
      
      // إنشاء كائنات MaterialEntry
      final materialEntries = aggregatedMaterials.map((materialData) {
        return MaterialEntry(
          id: _uuid.v4(),
          materialName: materialData['material_name'] as String,
          quantity: materialData['quantity'] as int,
          originalRemarks: materialData['original_remarks'] as String?,
          category: _categorizeMaterial(materialData['material_name'] as String),
          metadata: {
            'extraction_method': materialData['extraction_method'],
            'confidence': materialData['confidence'],
          },
          createdAt: DateTime.now(),
        );
      }).toList();
      
      // حساب ثقة التجميع
      final groupingConfidence = _calculateGroupingConfidence(rows, materialEntries);
      
      // إنشاء مجموعة المنتج
      final productGroup = ProductGroup(
        id: _uuid.v4(),
        itemNumber: originalItemNumber,
        imageUrl: imageUrl,
        materials: materialEntries,
        totalQuantity: totalQuantity,
        totalCartonCount: totalCartons,
        sourceRowReferences: sourceRowReferences,
        aggregatedData: {
          'original_rows_count': rows.length,
          'materials_sources': allMaterials.length,
          'aggregation_method': 'smart_grouping',
        },
        groupingConfidence: groupingConfidence,
        createdAt: DateTime.now(),
      );
      
      productGroups.add(productGroup);
      
      AppLogger.info('✅ تم إنشاء مجموعة للمنتج "$originalItemNumber": $totalQuantity قطعة، ${materialEntries.length} مادة');
    }
    
    return productGroups;
  }
  
  /// تجميع المواد المتشابهة
  static List<Map<String, dynamic>> _aggregateSimilarMaterials(List<Map<String, dynamic>> materials) {
    return _aggregateSimilarMaterialsOptimized(materials);
  }

  /// تجميع المواد المتشابهة بشكل محسن
  static List<Map<String, dynamic>> _aggregateSimilarMaterialsOptimized(List<Map<String, dynamic>> materials) {
    if (materials.isEmpty) return [];

    // استخدام Map للتجميع السريع
    final aggregated = <String, Map<String, dynamic>>{};
    final normalizedToOriginal = <String, String>{};

    for (final material in materials) {
      final materialName = material['material_name'] as String;
      final quantity = material['quantity'] as int? ?? 0;

      if (quantity <= 0) continue; // تجاهل الكميات الصفرية أو السالبة

      // تنظيف اسم المادة للتجميع
      final normalizedName = _normalizeMaterialName(materialName);

      if (normalizedName.isEmpty) continue; // تجاهل الأسماء الفارغة

      if (aggregated.containsKey(normalizedName)) {
        // جمع الكمية مع المادة الموجودة
        final existing = aggregated[normalizedName]!;
        existing['quantity'] = (existing['quantity'] as int) + quantity;

        // اختيار أفضل اسم (الأطول والأكثر وصفية)
        final existingName = existing['material_name'] as String;
        if (materialName.length > existingName.length) {
          existing['material_name'] = materialName;
          normalizedToOriginal[normalizedName] = materialName;
        }
      } else {
        // إضافة مادة جديدة
        aggregated[normalizedName] = Map<String, dynamic>.from(material);
        normalizedToOriginal[normalizedName] = materialName;
      }
    }

    // ترتيب النتائج حسب الكمية (تنازلي)
    final result = aggregated.values.toList();
    result.sort((a, b) => (b['quantity'] as int).compareTo(a['quantity'] as int));

    return result;
  }
  
  /// تنظيف اسم المادة للتجميع
  static String _normalizeMaterialName(String materialName) {
    return materialName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[^\w\s\u0600-\u06FF]'), ''); // الاحتفاظ بالأحرف العربية والإنجليزية فقط
  }
  
  /// تصنيف المادة
  static String? _categorizeMaterial(String materialName) {
    final lowerName = materialName.toLowerCase();
    
    if (lowerName.contains('طوق') || lowerName.contains('ring')) {
      return 'حلقات';
    } else if (lowerName.contains('شبوه') || lowerName.contains('plastic')) {
      return 'بلاستيك';
    } else if (lowerName.contains('كرستاله') || lowerName.contains('crystal')) {
      return 'كريستال';
    } else if (lowerName.contains('معدن') || lowerName.contains('metal')) {
      return 'معادن';
    } else if (lowerName.contains('الومنيوم') || lowerName.contains('aluminum')) {
      return 'الومنيوم';
    }
    
    return null; // غير مصنف
  }
  
  /// حساب ثقة التجميع
  static double _calculateGroupingConfidence(List<Map<String, dynamic>> rows, List<MaterialEntry> materials) {
    double confidence = 0.5; // ثقة أساسية
    
    // زيادة الثقة إذا كان هناك مواد مستخرجة
    if (materials.isNotEmpty) {
      confidence += 0.3;
    }
    
    // زيادة الثقة إذا كانت البيانات متسقة
    if (rows.length > 1) {
      confidence += 0.1; // تجميع من صفوف متعددة
    }
    
    // تقليل الثقة إذا كانت هناك تناقضات
    final uniqueImageUrls = rows.map((r) => r['image_url']).toSet().length;
    if (uniqueImageUrls > 1) {
      confidence -= 0.1; // صور مختلفة لنفس المنتج
    }
    
    return confidence.clamp(0.0, 1.0);
  }
}
