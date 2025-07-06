import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:smartbiztracker_new/utils/uuid_validator.dart';



/// نموذج مادة فردية مع الكمية - للتجميع الذكي للمواد
class MaterialEntry {
  final String id;
  final String materialName;
  final int quantity;
  final String? originalRemarks;
  final String? category;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  const MaterialEntry({
    required this.id,
    required this.materialName,
    required this.quantity,
    this.originalRemarks,
    this.category,
    this.metadata,
    required this.createdAt,
  });

  factory MaterialEntry.fromJson(Map<String, dynamic> json) {
    return MaterialEntry(
      id: json['id'] as String,
      materialName: json['material_name'] as String,
      quantity: json['quantity'] as int,
      originalRemarks: json['original_remarks'] as String?,
      category: json['category'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'material_name': materialName,
      'quantity': quantity,
      'original_remarks': originalRemarks,
      'category': category,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
    };
  }

  MaterialEntry copyWith({
    String? id,
    String? materialName,
    int? quantity,
    String? originalRemarks,
    String? category,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
  }) {
    return MaterialEntry(
      id: id ?? this.id,
      materialName: materialName ?? this.materialName,
      quantity: quantity ?? this.quantity,
      originalRemarks: originalRemarks ?? this.originalRemarks,
      category: category ?? this.category,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'MaterialEntry(id: $id, materialName: $materialName, quantity: $quantity)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MaterialEntry &&
        other.id == id &&
        other.materialName == materialName &&
        other.quantity == quantity;
  }

  @override
  int get hashCode => Object.hash(id, materialName, quantity);
}

/// نموذج مجموعة المنتجات - تجميع ذكي للمنتجات المتشابهة مع تجميع المواد
class ProductGroup {
  final String id;
  final String itemNumber;
  final String? imageUrl;
  final List<MaterialEntry> materials;
  final int totalQuantity;
  final int totalCartonCount;
  final List<String> sourceRowReferences;
  final Map<String, dynamic>? aggregatedData;
  final double groupingConfidence;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ProductGroup({
    required this.id,
    required this.itemNumber,
    this.imageUrl,
    required this.materials,
    required this.totalQuantity,
    required this.totalCartonCount,
    required this.sourceRowReferences,
    this.aggregatedData,
    required this.groupingConfidence,
    required this.createdAt,
    this.updatedAt,
  });

  factory ProductGroup.fromJson(Map<String, dynamic> json) {
    return ProductGroup(
      id: json['id'] as String,
      itemNumber: json['item_number'] as String,
      imageUrl: json['image_url'] as String?,
      materials: (json['materials'] as List<dynamic>)
          .map((e) => MaterialEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalQuantity: json['total_quantity'] as int,
      totalCartonCount: json['total_carton_count'] as int,
      sourceRowReferences: (json['source_row_references'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      aggregatedData: json['aggregated_data'] as Map<String, dynamic>?,
      groupingConfidence: (json['grouping_confidence'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'item_number': itemNumber,
      'image_url': imageUrl,
      'materials': materials.map((e) => e.toJson()).toList(),
      'total_quantity': totalQuantity,
      'total_carton_count': totalCartonCount,
      'source_row_references': sourceRowReferences,
      'aggregated_data': aggregatedData,
      'grouping_confidence': groupingConfidence,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// الحصول على عدد المواد الفريدة
  int get uniqueMaterialsCount => materials.length;

  /// الحصول على إجمالي كمية المواد
  int get totalMaterialsQuantity => materials.fold(0, (sum, material) => sum + material.quantity);

  /// الحصول على المواد مجمعة حسب الفئة
  Map<String, List<MaterialEntry>> get materialsByCategory {
    final Map<String, List<MaterialEntry>> grouped = {};
    for (final material in materials) {
      final category = material.category ?? 'غير مصنف';
      grouped.putIfAbsent(category, () => []).add(material);
    }
    return grouped;
  }

  /// الحصول على أهم المواد (الأكثر كمية)
  List<MaterialEntry> getTopMaterials([int limit = 5]) {
    final sortedMaterials = List<MaterialEntry>.from(materials);
    sortedMaterials.sort((a, b) => b.quantity.compareTo(a.quantity));
    return sortedMaterials.take(limit).toList();
  }

  ProductGroup copyWith({
    String? id,
    String? itemNumber,
    String? imageUrl,
    List<MaterialEntry>? materials,
    int? totalQuantity,
    int? totalCartonCount,
    List<String>? sourceRowReferences,
    Map<String, dynamic>? aggregatedData,
    double? groupingConfidence,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductGroup(
      id: id ?? this.id,
      itemNumber: itemNumber ?? this.itemNumber,
      imageUrl: imageUrl ?? this.imageUrl,
      materials: materials ?? this.materials,
      totalQuantity: totalQuantity ?? this.totalQuantity,
      totalCartonCount: totalCartonCount ?? this.totalCartonCount,
      sourceRowReferences: sourceRowReferences ?? this.sourceRowReferences,
      aggregatedData: aggregatedData ?? this.aggregatedData,
      groupingConfidence: groupingConfidence ?? this.groupingConfidence,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'ProductGroup(id: $id, itemNumber: $itemNumber, materials: ${materials.length}, totalQuantity: $totalQuantity)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProductGroup &&
        other.id == id &&
        other.itemNumber == itemNumber &&
        other.materials.length == materials.length;
  }

  @override
  int get hashCode => Object.hash(id, itemNumber, materials.length);
}

/// نموذج عنصر قائمة التعبئة - البيانات الأساسية المستخرجة من ملفات Excel/CSV
class PackingListItem {
  final String id;
  final String importBatchId;
  
  // معلومات تحديد العنصر الأساسية
  final int? serialNumber;
  final String itemNumber;
  final String? imageUrl;
  
  // معلومات الكمية
  final int? cartonCount;
  final int? piecesPerCarton;
  final int totalQuantity; // Keep as int in Dart for compatibility, but database uses BIGINT
  
  // الأبعاد (مخزنة كـ JSON للمرونة)
  final Map<String, dynamic>? dimensions;
  final double? totalCubicMeters;
  
  // معلومات الوزن (مخزنة كـ JSON)
  final Map<String, dynamic>? weights;
  
  // معلومات التسعير بدقة عالية للدقة المالية
  final double? unitPrice;
  final double? rmbPrice;
  final double? convertedPrice;
  final double? conversionRate;
  final String? conversionCurrency;
  
  // الملاحظات والتعليقات (دعم حقول متعددة)
  final Map<String, dynamic>? remarks;

  // التجميع الذكي للمواد - جديد للنظام المحسن
  final List<MaterialEntry>? materials;
  final String? productGroupId;
  final bool isGroupedProduct;
  final List<String>? sourceRowReferences;
  final double? groupingConfidence;

  // التصنيف والتحليل
  final String? category;
  final String? subcategory;
  final double? classificationConfidence;

  // التحقق من صحة البيانات والجودة
  final String validationStatus;
  final List<String>? validationIssues;
  final double? dataQualityScore;

  // اكتشاف التكرار والتجميع
  final String? duplicateClusterId;
  final double? similarityScore;
  final bool isPotentialDuplicate;
  
  // التدقيق والتتبع
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  
  // بيانات وصفية للمعالجة
  final Map<String, dynamic>? metadata;

  const PackingListItem({
    required this.id,
    required this.importBatchId,
    this.serialNumber,
    required this.itemNumber,
    this.imageUrl,
    this.cartonCount,
    this.piecesPerCarton,
    required this.totalQuantity,
    this.dimensions,
    this.totalCubicMeters,
    this.weights,
    this.unitPrice,
    this.rmbPrice,
    this.convertedPrice,
    this.conversionRate,
    this.conversionCurrency,
    this.remarks,
    this.materials,
    this.productGroupId,
    this.isGroupedProduct = false,
    this.sourceRowReferences,
    this.groupingConfidence,
    this.category,
    this.subcategory,
    this.classificationConfidence,
    this.validationStatus = 'pending',
    this.validationIssues,
    this.dataQualityScore,
    this.duplicateClusterId,
    this.similarityScore,
    this.isPotentialDuplicate = false,
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.metadata,
  });

  factory PackingListItem.fromJson(Map<String, dynamic> json) {
    return PackingListItem(
      id: json['id'] as String,
      importBatchId: json['import_batch_id'] as String,
      serialNumber: json['serial_number'] as int?,
      itemNumber: json['item_number'] as String,
      imageUrl: json['image_url'] as String?,
      cartonCount: json['carton_count'] as int?,
      piecesPerCarton: json['pieces_per_carton'] as int?,
      totalQuantity: json['total_quantity'] as int,
      dimensions: json['dimensions'] as Map<String, dynamic>?,
      totalCubicMeters: (json['total_cubic_meters'] as num?)?.toDouble(),
      weights: json['weights'] as Map<String, dynamic>?,
      unitPrice: (json['unit_price'] as num?)?.toDouble(),
      rmbPrice: (json['rmb_price'] as num?)?.toDouble(),
      convertedPrice: (json['converted_price'] as num?)?.toDouble(),
      conversionRate: (json['conversion_rate'] as num?)?.toDouble(),
      conversionCurrency: json['conversion_currency'] as String?,
      remarks: json['remarks'] as Map<String, dynamic>?,
      materials: json['materials'] != null
          ? (json['materials'] as List<dynamic>)
              .map((e) => MaterialEntry.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      productGroupId: json['product_group_id'] as String?,
      isGroupedProduct: json['is_grouped_product'] as bool? ?? false,
      sourceRowReferences: (json['source_row_references'] as List<dynamic>?)?.cast<String>(),
      groupingConfidence: (json['grouping_confidence'] as num?)?.toDouble(),
      category: json['category'] as String?,
      subcategory: json['subcategory'] as String?,
      classificationConfidence: (json['classification_confidence'] as num?)?.toDouble(),
      validationStatus: json['validation_status'] as String? ?? 'pending',
      validationIssues: (json['validation_issues'] as List<dynamic>?)?.cast<String>(),
      dataQualityScore: (json['data_quality_score'] as num?)?.toDouble(),
      duplicateClusterId: json['duplicate_cluster_id'] as String?,
      similarityScore: (json['similarity_score'] as num?)?.toDouble(),
      isPotentialDuplicate: json['is_potential_duplicate'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String) 
          : null,
      createdBy: json['created_by'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'import_batch_id': importBatchId,
      'serial_number': serialNumber,
      'item_number': itemNumber,
      'image_url': imageUrl,
      'carton_count': cartonCount,
      'pieces_per_carton': piecesPerCarton,
      'total_quantity': totalQuantity,
      'dimensions': dimensions,
      'total_cubic_meters': totalCubicMeters,
      'weights': weights,
      'unit_price': unitPrice,
      'rmb_price': rmbPrice,
      'converted_price': convertedPrice,
      'conversion_rate': conversionRate,
      'conversion_currency': conversionCurrency,
      'remarks': remarks,
      'materials': materials?.map((e) => e.toJson()).toList(),
      'product_group_id': productGroupId,
      'is_grouped_product': isGroupedProduct,
      'source_row_references': sourceRowReferences,
      'grouping_confidence': groupingConfidence,
      'category': category,
      'subcategory': subcategory,
      'classification_confidence': classificationConfidence,
      'validation_status': validationStatus,
      'validation_issues': validationIssues,
      'data_quality_score': dataQualityScore,
      'duplicate_cluster_id': duplicateClusterId,
      'similarity_score': similarityScore,
      'is_potential_duplicate': isPotentialDuplicate,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'created_by': createdBy,
      'metadata': metadata,
    };

    // Add ID only if it's a valid UUID
    UuidValidator.addUuidToJson(json, 'id', id);

    return json;
  }

  PackingListItem copyWith({
    String? id,
    String? importBatchId,
    int? serialNumber,
    String? itemNumber,
    String? imageUrl,
    int? cartonCount,
    int? piecesPerCarton,
    int? totalQuantity,
    Map<String, dynamic>? dimensions,
    double? totalCubicMeters,
    Map<String, dynamic>? weights,
    double? unitPrice,
    double? rmbPrice,
    double? convertedPrice,
    double? conversionRate,
    String? conversionCurrency,
    Map<String, dynamic>? remarks,
    List<MaterialEntry>? materials,
    String? productGroupId,
    bool? isGroupedProduct,
    List<String>? sourceRowReferences,
    double? groupingConfidence,
    String? category,
    String? subcategory,
    double? classificationConfidence,
    String? validationStatus,
    List<String>? validationIssues,
    double? dataQualityScore,
    String? duplicateClusterId,
    double? similarityScore,
    bool? isPotentialDuplicate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    Map<String, dynamic>? metadata,
  }) {
    return PackingListItem(
      id: id ?? this.id,
      importBatchId: importBatchId ?? this.importBatchId,
      serialNumber: serialNumber ?? this.serialNumber,
      itemNumber: itemNumber ?? this.itemNumber,
      imageUrl: imageUrl ?? this.imageUrl,
      cartonCount: cartonCount ?? this.cartonCount,
      piecesPerCarton: piecesPerCarton ?? this.piecesPerCarton,
      totalQuantity: totalQuantity ?? this.totalQuantity,
      dimensions: dimensions ?? this.dimensions,
      totalCubicMeters: totalCubicMeters ?? this.totalCubicMeters,
      weights: weights ?? this.weights,
      unitPrice: unitPrice ?? this.unitPrice,
      rmbPrice: rmbPrice ?? this.rmbPrice,
      convertedPrice: convertedPrice ?? this.convertedPrice,
      conversionRate: conversionRate ?? this.conversionRate,
      conversionCurrency: conversionCurrency ?? this.conversionCurrency,
      remarks: remarks ?? this.remarks,
      materials: materials ?? this.materials,
      productGroupId: productGroupId ?? this.productGroupId,
      isGroupedProduct: isGroupedProduct ?? this.isGroupedProduct,
      sourceRowReferences: sourceRowReferences ?? this.sourceRowReferences,
      groupingConfidence: groupingConfidence ?? this.groupingConfidence,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      classificationConfidence: classificationConfidence ?? this.classificationConfidence,
      validationStatus: validationStatus ?? this.validationStatus,
      validationIssues: validationIssues ?? this.validationIssues,
      dataQualityScore: dataQualityScore ?? this.dataQualityScore,
      duplicateClusterId: duplicateClusterId ?? this.duplicateClusterId,
      similarityScore: similarityScore ?? this.similarityScore,
      isPotentialDuplicate: isPotentialDuplicate ?? this.isPotentialDuplicate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PackingListItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'PackingListItem(id: $id, itemNumber: $itemNumber, totalQuantity: $totalQuantity)';
  }

  /// الحصول على الوزن الصافي الإجمالي
  double? get totalNetWeight {
    if (weights == null) return null;
    return (weights!['total_net_weight'] as num?)?.toDouble();
  }

  /// الحصول على الوزن الإجمالي الكلي
  double? get totalGrossWeight {
    if (weights == null) return null;
    return (weights!['total_gross_weight'] as num?)?.toDouble();
  }

  /// الحصول على الأبعاد كسلسلة نصية
  String get dimensionsString {
    if (dimensions == null) return 'غير محدد';
    final size1 = dimensions!['size1']?.toString() ?? '0';
    final size2 = dimensions!['size2']?.toString() ?? '0';
    final size3 = dimensions!['size3']?.toString() ?? '0';
    final unit = dimensions!['unit']?.toString() ?? 'سم';
    return '$size1 × $size2 × $size3 $unit';
  }

  /// الحصول على القيمة الإجمالية بالعملة المحولة
  double get totalConvertedValue {
    if (convertedPrice == null) return 0.0;
    return convertedPrice! * totalQuantity;
  }

  /// الحصول على القيمة الإجمالية باليوان الصيني
  double get totalRmbValue {
    if (rmbPrice == null) return 0.0;
    return rmbPrice! * totalQuantity;
  }

  /// التحقق من صحة البيانات الأساسية
  bool get isValid {
    return validationStatus == 'valid' && 
           itemNumber.isNotEmpty && 
           totalQuantity > 0;
  }

  /// الحصول على حالة التحقق مع الألوان
  ValidationStatusInfo get validationStatusInfo {
    switch (validationStatus) {
      case 'valid':
        return ValidationStatusInfo('صحيح', '#4CAF50');
      case 'invalid':
        return ValidationStatusInfo('غير صحيح', '#F44336');
      case 'warning':
        return ValidationStatusInfo('تحذير', '#FF9800');
      default:
        return ValidationStatusInfo('قيد المراجعة', '#9E9E9E');
    }
  }

  /// الحصول على عدد المواد المختلفة
  int get materialsCount => materials?.length ?? 0;

  /// الحصول على إجمالي كمية المواد
  int get totalMaterialsQuantity => materials?.fold<int>(0, (sum, material) => sum + material.quantity) ?? 0;

  /// الحصول على قائمة بأسماء المواد
  List<String> get materialNames => materials?.map((MaterialEntry e) => e.materialName).toList() ?? [];

  /// البحث عن مادة بالاسم
  MaterialEntry? findMaterialByName(String name) {
    if (materials == null) return null;
    try {
      return materials!.firstWhere((material) =>
          material.materialName.toLowerCase().contains(name.toLowerCase()));
    } catch (e) {
      return null;
    }
  }

  /// الحصول على المواد مجمعة حسب الفئة
  Map<String, List<MaterialEntry>> get materialsByCategory {
    if (materials == null) return {};
    final Map<String, List<MaterialEntry>> grouped = {};
    for (final material in materials!) {
      final category = material.category ?? 'غير مصنف';
      grouped.putIfAbsent(category, () => []).add(material);
    }
    return grouped;
  }

  /// الحصول على أهم المواد (الأكثر كمية)
  List<MaterialEntry> getTopMaterials([int limit = 5]) {
    if (materials == null) return [];
    final sortedMaterials = List<MaterialEntry>.from(materials!);
    sortedMaterials.sort((a, b) => b.quantity.compareTo(a.quantity));
    return sortedMaterials.take(limit).toList();
  }

  /// التحقق من كون المنتج مجمع
  bool get hasGroupedMaterials => isGroupedProduct && materials != null && materials!.isNotEmpty;

  /// الحصول على ملخص المواد كنص
  String get materialsSummary {
    if (materials == null || materials!.isEmpty) return 'لا توجد مواد';
    if (materials!.length == 1) {
      final material = materials!.first;
      return '${material.materialName} (${material.quantity})';
    }
    return '${materials!.length} مواد مختلفة (إجمالي: $totalMaterialsQuantity)';
  }
}

/// معلومات حالة التحقق
class ValidationStatusInfo {
  final String label;
  final String color;

  const ValidationStatusInfo(this.label, this.color);
}

/// نموذج دفعة الاستيراد - تتبع استيراد الملفات وحالة المعالجة
class ImportBatch {
  final String id;
  final String filename;
  final String originalFilename;
  final int fileSize;
  final String fileType;
  final int totalItems;
  final int processedItems;
  final String processingStatus;

  // إحصائيات موجزة (JSON للمرونة)
  final Map<String, dynamic>? summaryStats;
  final Map<String, dynamic>? categoryBreakdown;
  final Map<String, dynamic>? financialSummary;

  // تتبع التحقق والأخطاء
  final List<String>? validationErrors;
  final List<String>? processingErrors;

  // إدارة الإصدارات للتعامل مع الدفعات المكررة
  final int versionNumber;
  final String? parentBatchId;

  // إعدادات العملة لهذه الدفعة
  final Map<String, dynamic>? currencySettings;

  // حقول التدقيق
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  // بيانات وصفية لمعلومات المعالجة
  final Map<String, dynamic>? metadata;

  const ImportBatch({
    required this.id,
    required this.filename,
    required this.originalFilename,
    required this.fileSize,
    required this.fileType,
    this.totalItems = 0,
    this.processedItems = 0,
    this.processingStatus = 'pending',
    this.summaryStats,
    this.categoryBreakdown,
    this.financialSummary,
    this.validationErrors,
    this.processingErrors,
    this.versionNumber = 1,
    this.parentBatchId,
    this.currencySettings,
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.metadata,
  });

  factory ImportBatch.fromJson(Map<String, dynamic> json) {
    return ImportBatch(
      id: json['id'] as String,
      filename: json['filename'] as String,
      originalFilename: json['original_filename'] as String,
      fileSize: json['file_size'] as int,
      fileType: json['file_type'] as String,
      totalItems: json['total_items'] as int? ?? 0,
      processedItems: json['processed_items'] as int? ?? 0,
      processingStatus: json['processing_status'] as String? ?? 'pending',
      summaryStats: json['summary_stats'] as Map<String, dynamic>?,
      categoryBreakdown: json['category_breakdown'] as Map<String, dynamic>?,
      financialSummary: json['financial_summary'] as Map<String, dynamic>?,
      validationErrors: (json['validation_errors'] as List<dynamic>?)?.cast<String>(),
      processingErrors: (json['processing_errors'] as List<dynamic>?)?.cast<String>(),
      versionNumber: json['version_number'] as int? ?? 1,
      parentBatchId: json['parent_batch_id'] as String?,
      currencySettings: json['currency_settings'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      createdBy: json['created_by'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'filename': filename,
      'original_filename': originalFilename,
      'file_size': fileSize,
      'file_type': fileType,
      'total_items': totalItems,
      'processed_items': processedItems,
      'processing_status': processingStatus,
      'summary_stats': summaryStats,
      'category_breakdown': categoryBreakdown,
      'financial_summary': financialSummary,
      'validation_errors': validationErrors,
      'processing_errors': processingErrors,
      'version_number': versionNumber,
      'currency_settings': currencySettings,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'created_by': createdBy,
      'metadata': metadata,
    };

    // Add ID only if it's a valid UUID
    UuidValidator.addUuidToJson(json, 'id', id);
    // Add parent_batch_id only if it's a valid UUID
    UuidValidator.addUuidToJson(json, 'parent_batch_id', parentBatchId);

    return json;
  }

  ImportBatch copyWith({
    String? id,
    String? filename,
    String? originalFilename,
    int? fileSize,
    String? fileType,
    int? totalItems,
    int? processedItems,
    String? processingStatus,
    Map<String, dynamic>? summaryStats,
    Map<String, dynamic>? categoryBreakdown,
    Map<String, dynamic>? financialSummary,
    List<String>? validationErrors,
    List<String>? processingErrors,
    int? versionNumber,
    String? parentBatchId,
    Map<String, dynamic>? currencySettings,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    Map<String, dynamic>? metadata,
  }) {
    return ImportBatch(
      id: id ?? this.id,
      filename: filename ?? this.filename,
      originalFilename: originalFilename ?? this.originalFilename,
      fileSize: fileSize ?? this.fileSize,
      fileType: fileType ?? this.fileType,
      totalItems: totalItems ?? this.totalItems,
      processedItems: processedItems ?? this.processedItems,
      processingStatus: processingStatus ?? this.processingStatus,
      summaryStats: summaryStats ?? this.summaryStats,
      categoryBreakdown: categoryBreakdown ?? this.categoryBreakdown,
      financialSummary: financialSummary ?? this.financialSummary,
      validationErrors: validationErrors ?? this.validationErrors,
      processingErrors: processingErrors ?? this.processingErrors,
      versionNumber: versionNumber ?? this.versionNumber,
      parentBatchId: parentBatchId ?? this.parentBatchId,
      currencySettings: currencySettings ?? this.currencySettings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ImportBatch && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ImportBatch(id: $id, filename: $filename, status: $processingStatus)';
  }

  /// الحصول على معلومات حالة المعالجة
  ProcessingStatusInfo get processingStatusInfo {
    switch (processingStatus) {
      case 'completed':
        return ProcessingStatusInfo('مكتمل', '#4CAF50', 'تم الانتهاء من المعالجة بنجاح');
      case 'processing':
        return ProcessingStatusInfo('قيد المعالجة', '#2196F3', 'جاري معالجة الملف...');
      case 'failed':
        return ProcessingStatusInfo('فشل', '#F44336', 'فشل في معالجة الملف');
      case 'cancelled':
        return ProcessingStatusInfo('ملغي', '#FF9800', 'تم إلغاء المعالجة');
      default:
        return ProcessingStatusInfo('في الانتظار', '#9E9E9E', 'في انتظار بدء المعالجة');
    }
  }

  /// الحصول على نسبة التقدم
  double get progressPercentage {
    if (totalItems == 0) return 0.0;
    return (processedItems / totalItems).clamp(0.0, 1.0);
  }

  /// الحصول على حجم الملف بتنسيق قابل للقراءة
  String get formattedFileSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    if (fileSize < 1024 * 1024 * 1024) return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// التحقق من وجود أخطاء
  bool get hasErrors {
    return (validationErrors?.isNotEmpty ?? false) ||
           (processingErrors?.isNotEmpty ?? false);
  }

  /// الحصول على العملة المستهدفة
  String get targetCurrency {
    return currencySettings?['target_currency'] as String? ?? 'EGP';
  }

  /// الحصول على سعر الصرف
  double get exchangeRate {
    return (currencySettings?['exchange_rate'] as num?)?.toDouble() ?? 2.25;
  }

  /// الحصول على القيمة الإجمالية المحولة
  double get totalConvertedValue {
    return (financialSummary?['total_converted_value'] as num?)?.toDouble() ?? 0.0;
  }

  /// الحصول على القيمة الإجمالية باليوان الصيني
  double get totalRmbValue {
    return (financialSummary?['total_rmb_value'] as num?)?.toDouble() ?? 0.0;
  }
}

/// معلومات حالة المعالجة
class ProcessingStatusInfo {
  final String label;
  final String color;
  final String description;

  const ProcessingStatusInfo(this.label, this.color, this.description);
}

/// نموذج أسعار الصرف - تتبع أسعار الصرف في الوقت الفعلي
class CurrencyRate {
  final String id;
  final String baseCurrency;
  final String targetCurrency;
  final double rate;
  final DateTime rateDate;
  final String rateSource;

  // بيانات وصفية للـ API
  final String? apiProvider;
  final Map<String, dynamic>? apiResponseData;

  // حقول التدقيق
  final DateTime createdAt;
  final DateTime? updatedAt;

  const CurrencyRate({
    required this.id,
    required this.baseCurrency,
    required this.targetCurrency,
    required this.rate,
    required this.rateDate,
    this.rateSource = 'manual',
    this.apiProvider,
    this.apiResponseData,
    required this.createdAt,
    this.updatedAt,
  });

  factory CurrencyRate.fromJson(Map<String, dynamic> json) {
    return CurrencyRate(
      id: json['id'] as String,
      baseCurrency: json['base_currency'] as String,
      targetCurrency: json['target_currency'] as String,
      rate: (json['rate'] as num).toDouble(),
      rateDate: DateTime.parse(json['rate_date'] as String),
      rateSource: json['rate_source'] as String? ?? 'manual',
      apiProvider: json['api_provider'] as String?,
      apiResponseData: json['api_response_data'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'base_currency': baseCurrency,
      'target_currency': targetCurrency,
      'rate': rate,
      'rate_date': rateDate.toIso8601String().split('T')[0], // Date only
      'rate_source': rateSource,
      'api_provider': apiProvider,
      'api_response_data': apiResponseData,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  CurrencyRate copyWith({
    String? id,
    String? baseCurrency,
    String? targetCurrency,
    double? rate,
    DateTime? rateDate,
    String? rateSource,
    String? apiProvider,
    Map<String, dynamic>? apiResponseData,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CurrencyRate(
      id: id ?? this.id,
      baseCurrency: baseCurrency ?? this.baseCurrency,
      targetCurrency: targetCurrency ?? this.targetCurrency,
      rate: rate ?? this.rate,
      rateDate: rateDate ?? this.rateDate,
      rateSource: rateSource ?? this.rateSource,
      apiProvider: apiProvider ?? this.apiProvider,
      apiResponseData: apiResponseData ?? this.apiResponseData,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CurrencyRate &&
           other.baseCurrency == baseCurrency &&
           other.targetCurrency == targetCurrency &&
           other.rateDate == rateDate;
  }

  @override
  int get hashCode => Object.hash(baseCurrency, targetCurrency, rateDate);

  @override
  String toString() {
    return 'CurrencyRate($baseCurrency → $targetCurrency: $rate)';
  }

  /// الحصول على زوج العملات
  String get currencyPair => '$baseCurrency/$targetCurrency';

  /// التحقق من كون السعر حديث (أقل من 24 ساعة)
  bool get isRecent {
    final now = DateTime.now();
    final difference = now.difference(rateDate);
    return difference.inHours < 24;
  }

  /// الحصول على عمر السعر بالساعات
  int get ageInHours {
    final now = DateTime.now();
    return now.difference(rateDate).inHours;
  }
}

/// نموذج إعدادات تحليل الاستيراد - تفضيلات المستخدم والتكوين
class ImportAnalysisSettings {
  final String id;
  final String userId;

  // إعدادات معالجة الملفات
  final int maxFileSizeMb;
  final bool autoDetectHeaders;
  final String defaultCurrency;

  // إعدادات التصنيف
  final bool categoryClassificationEnabled;
  final double duplicateDetectionThreshold;
  final bool autoMergeDuplicates;

  // تفضيلات واجهة المستخدم
  final int itemsPerPage;
  final String defaultView;
  final bool showAdvancedAnalytics;

  // تفضيلات التصدير
  final String defaultExportFormat;
  final bool includeImagesInExport;

  // إعدادات الإشعارات
  final bool notifyOnCompletion;
  final bool notifyOnErrors;

  // بيانات الإعدادات
  final Map<String, dynamic>? settingsData;

  // حقول التدقيق
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ImportAnalysisSettings({
    required this.id,
    required this.userId,
    this.maxFileSizeMb = 50,
    this.autoDetectHeaders = true,
    this.defaultCurrency = 'EGP',
    this.categoryClassificationEnabled = true,
    this.duplicateDetectionThreshold = 0.90,
    this.autoMergeDuplicates = false,
    this.itemsPerPage = 50,
    this.defaultView = 'table',
    this.showAdvancedAnalytics = true,
    this.defaultExportFormat = 'xlsx',
    this.includeImagesInExport = true,
    this.notifyOnCompletion = true,
    this.notifyOnErrors = true,
    this.settingsData,
    required this.createdAt,
    this.updatedAt,
  });

  factory ImportAnalysisSettings.fromJson(Map<String, dynamic> json) {
    return ImportAnalysisSettings(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      maxFileSizeMb: json['max_file_size_mb'] as int? ?? 50,
      autoDetectHeaders: json['auto_detect_headers'] as bool? ?? true,
      defaultCurrency: json['default_currency'] as String? ?? 'EGP',
      categoryClassificationEnabled: json['category_classification_enabled'] as bool? ?? true,
      duplicateDetectionThreshold: (json['duplicate_detection_threshold'] as num?)?.toDouble() ?? 0.90,
      autoMergeDuplicates: json['auto_merge_duplicates'] as bool? ?? false,
      itemsPerPage: json['items_per_page'] as int? ?? 50,
      defaultView: json['default_view'] as String? ?? 'table',
      showAdvancedAnalytics: json['show_advanced_analytics'] as bool? ?? true,
      defaultExportFormat: json['default_export_format'] as String? ?? 'xlsx',
      includeImagesInExport: json['include_images_in_export'] as bool? ?? true,
      notifyOnCompletion: json['notify_on_completion'] as bool? ?? true,
      notifyOnErrors: json['notify_on_errors'] as bool? ?? true,
      settingsData: json['settings_data'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'user_id': userId,
      'max_file_size_mb': maxFileSizeMb,
      'auto_detect_headers': autoDetectHeaders,
      'default_currency': defaultCurrency,
      'category_classification_enabled': categoryClassificationEnabled,
      'duplicate_detection_threshold': duplicateDetectionThreshold,
      'auto_merge_duplicates': autoMergeDuplicates,
      'items_per_page': itemsPerPage,
      'default_view': defaultView,
      'show_advanced_analytics': showAdvancedAnalytics,
      'default_export_format': defaultExportFormat,
      'include_images_in_export': includeImagesInExport,
      'notify_on_completion': notifyOnCompletion,
      'notify_on_errors': notifyOnErrors,
      'settings_data': settingsData,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };

    // Use UuidValidator to safely add UUID to JSON
    UuidValidator.addUuidToJson(json, 'id', id);

    return json;
  }

  ImportAnalysisSettings copyWith({
    String? id,
    String? userId,
    int? maxFileSizeMb,
    bool? autoDetectHeaders,
    String? defaultCurrency,
    bool? categoryClassificationEnabled,
    double? duplicateDetectionThreshold,
    bool? autoMergeDuplicates,
    int? itemsPerPage,
    String? defaultView,
    bool? showAdvancedAnalytics,
    String? defaultExportFormat,
    bool? includeImagesInExport,
    bool? notifyOnCompletion,
    bool? notifyOnErrors,
    Map<String, dynamic>? settingsData,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ImportAnalysisSettings(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      maxFileSizeMb: maxFileSizeMb ?? this.maxFileSizeMb,
      autoDetectHeaders: autoDetectHeaders ?? this.autoDetectHeaders,
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      categoryClassificationEnabled: categoryClassificationEnabled ?? this.categoryClassificationEnabled,
      duplicateDetectionThreshold: duplicateDetectionThreshold ?? this.duplicateDetectionThreshold,
      autoMergeDuplicates: autoMergeDuplicates ?? this.autoMergeDuplicates,
      itemsPerPage: itemsPerPage ?? this.itemsPerPage,
      defaultView: defaultView ?? this.defaultView,
      showAdvancedAnalytics: showAdvancedAnalytics ?? this.showAdvancedAnalytics,
      defaultExportFormat: defaultExportFormat ?? this.defaultExportFormat,
      includeImagesInExport: includeImagesInExport ?? this.includeImagesInExport,
      notifyOnCompletion: notifyOnCompletion ?? this.notifyOnCompletion,
      notifyOnErrors: notifyOnErrors ?? this.notifyOnErrors,
      settingsData: settingsData ?? this.settingsData,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ImportAnalysisSettings && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ImportAnalysisSettings(userId: $userId, defaultCurrency: $defaultCurrency)';
  }

  /// إنشاء إعدادات افتراضية للمستخدم
  static ImportAnalysisSettings createDefault(String userId) {
    return ImportAnalysisSettings(
      id: const Uuid().v4(),
      userId: userId,
      createdAt: DateTime.now(),
    );
  }
}

/// نموذج نتيجة التحقق - نتائج التحقق من صحة البيانات
class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
  final double qualityScore;
  final Map<String, dynamic>? details;

  const ValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
    this.qualityScore = 1.0,
    this.details,
  });

  factory ValidationResult.fromJson(Map<String, dynamic> json) {
    return ValidationResult(
      isValid: json['is_valid'] as bool,
      errors: (json['errors'] as List<dynamic>?)?.cast<String>() ?? [],
      warnings: (json['warnings'] as List<dynamic>?)?.cast<String>() ?? [],
      qualityScore: (json['quality_score'] as num?)?.toDouble() ?? 1.0,
      details: json['details'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'is_valid': isValid,
      'errors': errors,
      'warnings': warnings,
      'quality_score': qualityScore,
      'details': details,
    };
  }

  /// إنشاء نتيجة صحيحة
  static ValidationResult valid({double qualityScore = 1.0}) {
    return ValidationResult(
      isValid: true,
      qualityScore: qualityScore,
    );
  }

  /// إنشاء نتيجة غير صحيحة
  static ValidationResult invalid(List<String> errors, {List<String> warnings = const []}) {
    return ValidationResult(
      isValid: false,
      errors: errors,
      warnings: warnings,
      qualityScore: 0.0,
    );
  }

  /// إنشاء نتيجة مع تحذيرات
  static ValidationResult withWarnings(List<String> warnings, {double qualityScore = 0.8}) {
    return ValidationResult(
      isValid: true,
      warnings: warnings,
      qualityScore: qualityScore,
    );
  }
}

/// نموذج مجموعة التكرار - تجميع العناصر المتشابهة
class DuplicateCluster {
  final String id;
  final List<PackingListItem> items;
  final double averageSimilarity;
  final String? suggestedAction;

  const DuplicateCluster({
    required this.id,
    required this.items,
    required this.averageSimilarity,
    this.suggestedAction,
  });

  factory DuplicateCluster.fromJson(Map<String, dynamic> json) {
    return DuplicateCluster(
      id: json['id'] as String,
      items: (json['items'] as List<dynamic>)
          .map((item) => PackingListItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      averageSimilarity: (json['average_similarity'] as num).toDouble(),
      suggestedAction: json['suggested_action'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'items': items.map((item) => item.toJson()).toList(),
      'average_similarity': averageSimilarity,
      'suggested_action': suggestedAction,
    };
  }

  /// الحصول على العنصر الرئيسي (الأول في القائمة)
  PackingListItem get primaryItem => items.first;

  /// الحصول على العناصر الثانوية
  List<PackingListItem> get secondaryItems => items.skip(1).toList();

  /// الحصول على إجمالي الكمية
  int get totalQuantity => items.fold(0, (sum, item) => sum + item.totalQuantity);

  /// الحصول على إجمالي القيمة
  double get totalValue => items.fold(0.0, (sum, item) => sum + item.totalConvertedValue);
}

/// تعداد أنواع الملفات المدعومة
enum SupportedFileType {
  xlsx('xlsx', 'Excel 2007+', ['application/vnd.openxmlformats-officedocument.spreadsheetml.sheet']),
  xls('xls', 'Excel 97-2003', ['application/vnd.ms-excel']),
  csv('csv', 'Comma Separated Values', ['text/csv', 'application/csv']);

  const SupportedFileType(this.extension, this.description, this.mimeTypes);

  final String extension;
  final String description;
  final List<String> mimeTypes;

  /// التحقق من نوع الملف بناءً على الامتداد
  static SupportedFileType? fromExtension(String extension) {
    final ext = extension.toLowerCase().replaceAll('.', '');
    for (final type in SupportedFileType.values) {
      if (type.extension == ext) return type;
    }
    return null;
  }

  /// التحقق من نوع الملف بناءً على MIME type
  static SupportedFileType? fromMimeType(String mimeType) {
    for (final type in SupportedFileType.values) {
      if (type.mimeTypes.contains(mimeType)) return type;
    }
    return null;
  }
}

/// تعداد حالات المعالجة
enum ProcessingStatus {
  pending('pending', 'في الانتظار'),
  processing('processing', 'قيد المعالجة'),
  completed('completed', 'مكتمل'),
  failed('failed', 'فشل'),
  cancelled('cancelled', 'ملغي');

  const ProcessingStatus(this.value, this.arabicLabel);

  final String value;
  final String arabicLabel;

  static ProcessingStatus fromString(String value) {
    for (final status in ProcessingStatus.values) {
      if (status.value == value) return status;
    }
    return ProcessingStatus.pending;
  }
}

/// تعداد حالات التحقق
enum ValidationStatus {
  pending('pending', 'قيد المراجعة'),
  valid('valid', 'صحيح'),
  invalid('invalid', 'غير صحيح'),
  warning('warning', 'تحذير');

  const ValidationStatus(this.value, this.arabicLabel);

  final String value;
  final String arabicLabel;

  static ValidationStatus fromString(String value) {
    for (final status in ValidationStatus.values) {
      if (status.value == value) return status;
    }
    return ValidationStatus.pending;
  }
}

/// تعداد أنواع العرض
enum ViewType {
  table('table', 'جدول'),
  cards('cards', 'بطاقات'),
  grid('grid', 'شبكة');

  const ViewType(this.value, this.arabicLabel);

  final String value;
  final String arabicLabel;

  static ViewType fromString(String value) {
    for (final type in ViewType.values) {
      if (type.value == value) return type;
    }
    return ViewType.table;
  }
}

/// تعداد تنسيقات التصدير
enum ExportFormat {
  xlsx('xlsx', 'Excel'),
  pdf('pdf', 'PDF'),
  csv('csv', 'CSV');

  const ExportFormat(this.value, this.label);

  final String value;
  final String label;

  static ExportFormat fromString(String value) {
    for (final format in ExportFormat.values) {
      if (format.value == value) return format;
    }
    return ExportFormat.xlsx;
  }
}
