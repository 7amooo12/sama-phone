import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:smartbiztracker_new/models/import_analysis_models.dart';
import 'package:smartbiztracker_new/models/container_import_models.dart';
import 'package:smartbiztracker_new/services/import_analysis/excel_parsing_service.dart';
import 'package:smartbiztracker_new/services/container_import_excel_service.dart';

import 'package:smartbiztracker_new/services/import_analysis/packing_analyzer_service.dart';
import 'package:smartbiztracker_new/services/import_analysis/smart_summary_service.dart';
import 'package:smartbiztracker_new/services/import_analysis/currency_conversion_service.dart';
import 'package:smartbiztracker_new/services/import_analysis/product_grouping_service.dart';
import 'package:smartbiztracker_new/services/import_analysis/material_aggregation_service.dart';
import 'package:smartbiztracker_new/services/import_analysis/intelligent_validation_service.dart';
import 'package:smartbiztracker_new/services/import_analysis/enhanced_summary_generator.dart';
import 'package:smartbiztracker_new/services/import_analysis/performance_optimizer.dart';
import 'package:smartbiztracker_new/services/supabase_service.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// مزود حالة تحليل الاستيراد الشامل مع إدارة الحالة والمعالجة والتحديثات
/// يدعم المعالجة في الخلفية والتخزين المؤقت والتعامل مع الأخطاء
class ImportAnalysisProvider extends ChangeNotifier {
  final SupabaseService _supabaseService;
  final Uuid _uuid = const Uuid();
  
  // حالة التطبيق
  bool _isLoading = false;
  bool _isProcessing = false;
  String _currentStatus = '';
  double _processingProgress = 0.0;
  String? _errorMessage;
  
  // بيانات الاستيراد
  List<ImportBatch> _importBatches = [];
  ImportBatch? _currentBatch;
  List<PackingListItem> _currentItems = [];
  List<ProductGroup> _currentProductGroups = [];
  PackingListStatistics? _currentStatistics;
  List<DuplicateCluster> _duplicateClusters = [];
  Map<String, dynamic>? _smartSummary;
  Map<String, dynamic>? _enhancedSummary;
  Map<String, dynamic>? _validationReport;

  // بيانات استيراد الحاويات الجديدة
  ContainerImportBatch? _currentContainerBatch;
  List<ContainerImportItem> _currentContainerItems = [];
  ContainerImportResult? _lastContainerImportResult;
  
  // إعدادات المستخدم
  ImportAnalysisSettings? _userSettings;
  
  // فلترة وبحث
  String _searchQuery = '';
  String _selectedCategory = '';
  String _selectedStatus = '';
  int _currentPage = 0;
  int _itemsPerPage = 50;
  

  
  // إلغاء العمليات
  Timer? _debounceTimer;
  
  ImportAnalysisProvider({
    required SupabaseService supabaseService,
  }) : _supabaseService = supabaseService {
    AppLogger.info('🚀 Initializing ImportAnalysisProvider...');
    try {
      _initializeProvider();
      AppLogger.info('✅ ImportAnalysisProvider initialized successfully');
    } catch (e) {
      AppLogger.error('❌ Failed to initialize ImportAnalysisProvider: $e');
      _setError('خطأ في تهيئة مزود تحليل الاستيراد: $e');
    }
  }
  
  // Getters
  bool get isLoading => _isLoading;
  bool get isProcessing => _isProcessing;
  String get currentStatus => _currentStatus;
  double get processingProgress => _processingProgress;
  String? get errorMessage => _errorMessage;
  
  List<ImportBatch> get importBatches => _importBatches;
  ImportBatch? get currentBatch => _currentBatch;
  List<PackingListItem> get currentItems => _filteredItems;
  List<ProductGroup> get currentProductGroups => _currentProductGroups;
  PackingListStatistics? get currentStatistics => _currentStatistics;
  List<DuplicateCluster> get duplicateClusters => _duplicateClusters;
  Map<String, dynamic>? get smartSummary => _smartSummary;
  Map<String, dynamic>? get enhancedSummary => _enhancedSummary;
  Map<String, dynamic>? get validationReport => _validationReport;

  // Container Import Getters
  ContainerImportBatch? get currentContainerBatch => _currentContainerBatch;
  List<ContainerImportItem> get currentContainerItems => _currentContainerItems;
  ContainerImportResult? get lastContainerImportResult => _lastContainerImportResult;
  
  ImportAnalysisSettings? get userSettings => _userSettings;
  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;
  String get selectedStatus => _selectedStatus;
  int get currentPage => _currentPage;
  int get itemsPerPage => _itemsPerPage;

  
  /// العناصر المفلترة بناءً على البحث والفلاتر
  List<PackingListItem> get _filteredItems {
    var items = List<PackingListItem>.from(_currentItems);
    
    // فلترة البحث
    if (_searchQuery.isNotEmpty) {
      items = items.where((item) =>
        item.itemNumber.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        (item.category?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
      ).toList();
    }
    
    // فلترة التصنيف
    if (_selectedCategory.isNotEmpty && _selectedCategory != 'الكل') {
      items = items.where((item) => item.category == _selectedCategory).toList();
    }
    
    // فلترة الحالة
    if (_selectedStatus.isNotEmpty && _selectedStatus != 'الكل') {
      items = items.where((item) => item.validationStatus == _selectedStatus).toList();
    }
    
    // ترقيم الصفحات
    final startIndex = _currentPage * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, items.length);
    
    return items.sublist(startIndex, endIndex);
  }
  
  /// إجمالي عدد الصفحات
  int get totalPages {
    final totalItems = _currentItems.length;
    return (totalItems / _itemsPerPage).ceil();
  }
  
  /// تهيئة المزود
  Future<void> _initializeProvider() async {
    try {
      await _loadUserSettings();
      await _loadImportBatches();
    } catch (e) {
      AppLogger.error('خطأ في تهيئة مزود تحليل الاستيراد: $e');
    }
  }
  
  /// تحميل إعدادات المستخدم
  Future<void> _loadUserSettings() async {
    try {
      final userId = _supabaseService.currentUserId;
      if (userId == null) return;
      
      final settings = await _supabaseService.getRecordsByFilter(
        'import_analysis_settings',
        'user_id',
        userId,
      );
      
      if (settings.isNotEmpty) {
        _userSettings = ImportAnalysisSettings.fromJson(settings.first);
        _itemsPerPage = _userSettings!.itemsPerPage;
      } else {
        // إنشاء إعدادات افتراضية
        _userSettings = ImportAnalysisSettings.createDefault(userId);
        await _saveUserSettings();
      }
      
      notifyListeners();
    } catch (e) {
      AppLogger.error('خطأ في تحميل إعدادات المستخدم: $e');
    }
  }
  
  /// حفظ إعدادات المستخدم
  Future<void> _saveUserSettings() async {
    try {
      if (_userSettings == null) return;
      
      await _supabaseService.createRecord(
        'import_analysis_settings',
        _userSettings!.toJson(),
      );
    } catch (e) {
      AppLogger.error('خطأ في حفظ إعدادات المستخدم: $e');
    }
  }
  
  /// تحميل دفعات الاستيراد
  Future<void> _loadImportBatches() async {
    try {
      _setLoading(true);
      
      final userId = _supabaseService.currentUserId;
      if (userId == null) return;
      
      final batches = await _supabaseService.getRecordsByFilter(
        'import_batches',
        'created_by',
        userId,
      );
      
      _importBatches = batches
          .map((batch) => ImportBatch.fromJson(batch))
          .toList();
      
      // ترتيب حسب تاريخ الإنشاء
      _importBatches.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      notifyListeners();
    } catch (e) {
      _setError('خطأ في تحميل دفعات الاستيراد: $e');
    } finally {
      _setLoading(false);
    }
  }
  

  
  /// رفع ملف جديد
  Future<void> uploadFile() async {
    try {
      _clearError();
      
      // اختيار الملف
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
        allowMultiple: false,
      );
      
      if (result == null || result.files.isEmpty) {
        return; // المستخدم ألغى العملية
      }
      
      final file = result.files.first;
      final filePath = file.path;
      
      if (filePath == null) {
        throw Exception('مسار الملف غير صحيح');
      }
      
      // التحقق من حجم الملف
      final maxSize = (_userSettings?.maxFileSizeMb ?? 50) * 1024 * 1024;
      if (file.size > maxSize) {
        throw Exception('حجم الملف كبير جداً. الحد الأقصى: ${_userSettings?.maxFileSizeMb ?? 50}MB');
      }
      
      // تحديد نوع الملف
      final extension = file.extension?.toLowerCase();
      final fileType = SupportedFileType.fromExtension(extension ?? '');
      
      if (fileType == null) {
        throw Exception('نوع الملف غير مدعوم. الأنواع المدعومة: xlsx, xls, csv');
      }
      
      await _processFile(filePath, file.name, fileType, file.size);
      
    } catch (e) {
      _setError('خطأ في رفع الملف: $e');
    }
  }
  
  /// معالجة الملف
  Future<void> _processFile(
    String filePath,
    String fileName,
    SupportedFileType fileType,
    int fileSize,
  ) async {
    try {
      _setProcessing(true);
      _setStatus('بدء معالجة الملف...');
      _setProgress(0.0);
      
      // إنشاء دفعة جديدة
      final batch = ImportBatch(
        id: _uuid.v4(),
        filename: fileName,
        originalFilename: fileName,
        fileSize: fileSize,
        fileType: fileType.extension,
        createdAt: DateTime.now(),
        createdBy: _supabaseService.currentUserId,
      );
      
      // معالجة الملف
      final result = await ExcelParsingService.parseFile(
        filePath: filePath,
        fileType: fileType,
        onProgress: (progress) {
          _setProgress(progress * 0.6); // 60% للمعالجة الأولية
        },
        onStatusUpdate: (status) {
          _setStatus(status);
        },
      );

      AppLogger.info('نتيجة معالجة Excel: ${result.dataRows} صف من البيانات');
      AppLogger.info('خريطة الرؤوس: ${result.headerMapping}');
      AppLogger.info('أول 3 عناصر من البيانات المستخرجة: ${result.data.take(3).toList()}');

      // تنفيذ المعالجة الذكية مع تحسين الأداء
      final processingResult = await PerformanceOptimizer.processWithTimeLimit(
        operation: () => _performIntelligentProcessing(result.data),
        operationName: 'المعالجة الذكية الشاملة',
      );

      final productGroups = processingResult['productGroups'] as List<ProductGroup>;
      final aggregatedGroups = processingResult['aggregatedGroups'] as List<ProductGroup>;
      final validationReport = processingResult['validationReport'] as ValidationReport;
      final enhancedSummary = processingResult['enhancedSummary'] as Map<String, dynamic>;

      _setStatus('🔄 تحويل إلى عناصر قائمة التعبئة...');
      _setProgress(0.95);

      // تحويل مجموعات المنتجات إلى عناصر قائمة التعبئة للتوافق مع النظام الحالي
      final items = await _convertProductGroupsToPackingItems(aggregatedGroups, batch.id);
      AppLogger.info('تم تحويل ${aggregatedGroups.length} مجموعة إلى ${items.length} عنصر قائمة تعبئة');

      // إنشاء التقرير الذكي التقليدي للتوافق
      final smartSummary = SmartSummaryService.generateSmartSummary(items);

      // حساب الإحصائيات التقليدية
      final statistics = await PackingListAnalyzer.analyzeStatistics(items);

      // كشف التكرار (سيكون أقل بسبب التجميع الذكي)
      final duplicates = await PackingListAnalyzer.detectDuplicates(items);

      // حفظ في قاعدة البيانات مع البيانات المحسنة
      print('🚨 DEBUG: About to call _saveBatchToDatabase');
      print('🚨 DEBUG: Items count before save: ${items.length}');
      print('🚨 DEBUG: Batch filename before save: ${batch.filename}');
      await _saveBatchToDatabase(batch, items, statistics, smartSummary, enhancedSummary, validationReport.toJson());
      print('🚨 DEBUG: _saveBatchToDatabase completed successfully');

      _setStatus('✅ اكتمل بنجاح');
      _setProgress(1.0);

      // تحديث الحالة
      _currentBatch = batch;
      _currentItems = items;
      _currentProductGroups = aggregatedGroups;
      _currentStatistics = statistics;
      _duplicateClusters = duplicates;
      _smartSummary = smartSummary;
      _enhancedSummary = enhancedSummary;
      _validationReport = validationReport.toJson();
      
      // إعادة تحميل الدفعات
      await _loadImportBatches();
      
      notifyListeners();
      
    } catch (e) {
      _setError('خطأ في معالجة الملف: $e');
    } finally {
      _setProcessing(false);
    }
  }

  /// إنشاء عنصر قائمة تعبئة من البيانات المستخرجة
  PackingListItem _createPackingListItem(Map<String, dynamic> data, String batchId) {
    // التحقق من صحة البيانات الأساسية قبل الإنشاء
    final totalQuantity = data['total_quantity'] as int?;
    final itemNumber = data['item_number'] as String? ?? '';

    // تسجيل تحذيري للبيانات المفقودة
    if (totalQuantity == null) {
      AppLogger.warning('⚠️ العنصر "$itemNumber" لا يحتوي على كمية صحيحة، سيتم استخدام 1 كقيمة افتراضية');
    }

    return PackingListItem(
      id: data['temp_id'] ?? _uuid.v4(),
      importBatchId: batchId,
      serialNumber: data['serial_number'] as int?,
      itemNumber: itemNumber,
      imageUrl: data['image_url'] as String?,
      cartonCount: data['carton_count'] as int?,
      piecesPerCarton: data['pieces_per_carton'] as int?,
      totalQuantity: totalQuantity ?? 1, // استخدام 1 بدلاً من 0 كقيمة افتراضية
      dimensions: _buildDimensions(data),
      totalCubicMeters: data['total_cubic_meters'] as double?,
      weights: _buildWeights(data),
      unitPrice: data['unit_price'] as double?,
      rmbPrice: data['rmb_price'] as double?,
      remarks: _buildRemarks(data),
      createdAt: DateTime.now(),
      createdBy: _supabaseService.currentUserId,
    );
  }

  /// بناء بيانات الأبعاد
  Map<String, dynamic>? _buildDimensions(Map<String, dynamic> data) {
    final size1 = data['size1'] as double?;
    final size2 = data['size2'] as double?;
    final size3 = data['size3'] as double?;

    if (size1 == null && size2 == null && size3 == null) return null;

    return {
      'size1': size1,
      'size2': size2,
      'size3': size3,
      'unit': 'cm',
    };
  }

  /// بناء بيانات الأوزان
  Map<String, dynamic>? _buildWeights(Map<String, dynamic> data) {
    final netWeight = data['net_weight'] as double?;
    final grossWeight = data['gross_weight'] as double?;
    final totalNetWeight = data['total_net_weight'] as double?;
    final totalGrossWeight = data['total_gross_weight'] as double?;

    if (netWeight == null && grossWeight == null &&
        totalNetWeight == null && totalGrossWeight == null) return null;

    return {
      'net_weight': netWeight,
      'gross_weight': grossWeight,
      'total_net_weight': totalNetWeight,
      'total_gross_weight': totalGrossWeight,
      'unit': 'kg',
    };
  }

  /// بناء بيانات الملاحظات
  Map<String, dynamic>? _buildRemarks(Map<String, dynamic> data) {
    final remarksA = data['remarks_a'] as String?;
    final remarksB = data['remarks_b'] as String?;
    final remarksC = data['remarks_c'] as String?;

    if (remarksA == null && remarksB == null && remarksC == null) return null;

    return {
      'remarks_a': remarksA,
      'remarks_b': remarksB,
      'remarks_c': remarksC,
    };
  }

  /// تحويل مجموعات المنتجات إلى عناصر قائمة التعبئة للتوافق مع النظام الحالي
  Future<List<PackingListItem>> _convertProductGroupsToPackingItems(List<ProductGroup> productGroups, String batchId) async {
    final items = <PackingListItem>[];

    for (final group in productGroups) {
      // إنشاء عنصر قائمة تعبئة من مجموعة المنتج
      final item = PackingListItem(
        id: _uuid.v4(),
        importBatchId: batchId,
        itemNumber: group.itemNumber,
        imageUrl: group.imageUrl,
        totalQuantity: group.totalQuantity,
        cartonCount: group.totalCartonCount,
        materials: group.materials,
        productGroupId: group.id,
        isGroupedProduct: true,
        sourceRowReferences: group.sourceRowReferences,
        groupingConfidence: group.groupingConfidence,
        remarks: _buildRemarksFromMaterials(group.materials),
        validationStatus: 'valid',
        createdAt: DateTime.now(),
        createdBy: _supabaseService.currentUserId,
      );

      items.add(item);
    }

    AppLogger.info('تم تحويل ${productGroups.length} مجموعة منتجات إلى ${items.length} عنصر قائمة تعبئة');
    return items;
  }

  /// بناء بيانات الملاحظات من المواد
  Map<String, dynamic>? _buildRemarksFromMaterials(List<MaterialEntry> materials) {
    if (materials.isEmpty) return null;

    // تجميع أسماء المواد مع كمياتها
    final materialDescriptions = materials.map((material) =>
        '${material.materialName} (${material.quantity})').toList();

    return {
      'remarks_a': materialDescriptions.join(' - '),
      'materials_count': materials.length,
      'total_materials_quantity': materials.fold(0, (sum, m) => sum + m.quantity),
    };
  }

  /// إعادة بناء مجموعات المنتجات من عناصر قائمة التعبئة
  Future<List<ProductGroup>> _reconstructProductGroupsFromItems(List<PackingListItem> items) async {
    final productGroups = <ProductGroup>[];

    for (final item in items) {
      if (item.isGroupedProduct && item.productGroupId != null) {
        // إنشاء مجموعة منتج من العنصر المجمع
        final group = ProductGroup(
          id: item.productGroupId!,
          itemNumber: item.itemNumber,
          imageUrl: item.imageUrl,
          materials: item.materials ?? [],
          totalQuantity: item.totalQuantity,
          totalCartonCount: item.cartonCount ?? 0,
          sourceRowReferences: item.sourceRowReferences ?? [],
          aggregatedData: {
            'reconstructed_from_item': true,
            'original_item_id': item.id,
          },
          groupingConfidence: item.groupingConfidence ?? 0.8,
          createdAt: item.createdAt,
          updatedAt: item.updatedAt,
        );

        productGroups.add(group);
      } else {
        // إنشاء مجموعة منتج بسيطة للعناصر غير المجمعة
        final materials = item.materials ?? [];
        final group = ProductGroup(
          id: _uuid.v4(),
          itemNumber: item.itemNumber,
          imageUrl: item.imageUrl,
          materials: materials,
          totalQuantity: item.totalQuantity,
          totalCartonCount: item.cartonCount ?? 0,
          sourceRowReferences: ['reconstructed'],
          aggregatedData: {
            'reconstructed_from_simple_item': true,
            'original_item_id': item.id,
          },
          groupingConfidence: 0.9, // ثقة عالية للعناصر البسيطة
          createdAt: item.createdAt,
          updatedAt: item.updatedAt,
        );

        productGroups.add(group);
      }
    }

    AppLogger.info('تم إعادة بناء ${productGroups.length} مجموعة منتجات من ${items.length} عنصر');
    return productGroups;
  }

  /// تنفيذ المعالجة الذكية الشاملة مع تحسين الأداء
  Future<Map<String, dynamic>> _performIntelligentProcessing(List<Map<String, dynamic>> rawData) async {
    // الخطوة 1: التجميع الذكي للمنتجات
    _setStatus('🔄 التجميع الذكي للمنتجات...');
    _setProgress(0.6);

    final productGroups = await PerformanceOptimizer.optimizeMemoryUsage(
      operation: () => ProductGroupingService.groupProducts(rawData),
      operationName: 'تجميع المنتجات',
    );
    AppLogger.info('تم إنشاء ${productGroups.length} مجموعة منتجات ذكية');

    // الخطوة 2: تجميع المواد
    _setStatus('🧪 تجميع المواد...');
    _setProgress(0.7);

    final aggregatedGroups = await PerformanceOptimizer.cacheResult(
      key: 'material_aggregation_${productGroups.length}_${productGroups.hashCode}',
      operation: () => MaterialAggregationService.aggregateMaterialsInGroups(productGroups),
    );
    AppLogger.info('تم تجميع المواد في ${aggregatedGroups.length} مجموعة');

    // الخطوة 3: التحقق من صحة البيانات
    _setStatus('✅ التحقق من صحة البيانات...');
    _setProgress(0.8);

    final validationReport = await IntelligentValidationService.validateProductGroups(aggregatedGroups);
    AppLogger.info('تقرير التحقق: ${validationReport.validGroups} صحيحة، ${validationReport.invalidGroups} غير صحيحة');

    // الخطوة 4: إنشاء التقارير المحسنة
    _setStatus('📊 إنشاء التقارير المحسنة...');
    _setProgress(0.9);

    final enhancedSummary = await PerformanceOptimizer.cacheResult(
      key: 'enhanced_summary_${aggregatedGroups.length}_${aggregatedGroups.hashCode}',
      operation: () async => EnhancedSummaryGenerator.generateComprehensiveReport(aggregatedGroups),
    );
    AppLogger.info('تم إنشاء التقرير المحسن مع ${enhancedSummary['overview']['total_unique_products']} منتج فريد');

    return {
      'productGroups': productGroups,
      'aggregatedGroups': aggregatedGroups,
      'validationReport': validationReport,
      'enhancedSummary': enhancedSummary,
    };
  }

  /// حفظ الدفعة في قاعدة البيانات مع البيانات المحسنة
  Future<void> _saveBatchToDatabase(
    ImportBatch batch,
    List<PackingListItem> items,
    PackingListStatistics statistics,
    Map<String, dynamic> smartSummary, [
    Map<String, dynamic>? enhancedSummary,
    Map<String, dynamic>? validationReport,
  ]) async {
    print('🚨 DEBUG: _saveBatchToDatabase method called!');
    print('🚨 DEBUG: Items count: ${items.length}');
    print('🚨 DEBUG: Batch filename: ${batch.filename}');
    print('🚨 DEBUG: Supabase service available: ${_supabaseService != null}');

    // ENHANCED DEBUGGING: Check authentication and session status
    await _validateDatabaseConnection();

    // Test database connection
    try {
      print('🚨 DEBUG: Testing database connection...');
      final testQuery = await _supabaseService.getAllRecords('import_batches');
      print('🚨 DEBUG: Database connection test successful, got ${testQuery.length} records');
    } catch (e) {
      print('🚨 DEBUG: Database connection test failed: $e');
    }

    try {
      print('🚨 DEBUG: Entering main try block');
      AppLogger.info('🔄 بدء حفظ البيانات في قاعدة البيانات...');
      AppLogger.error('🔄 TEST ERROR LOG - بدء حفظ البيانات في قاعدة البيانات...');
      print('🔄 بدء حفظ البيانات في قاعدة البيانات...');

      AppLogger.info('📊 إحصائيات الحفظ: ${items.length} عنصر، دفعة: ${batch.filename}');
      print('📊 إحصائيات الحفظ: ${items.length} عنصر، دفعة: ${batch.filename}');

      // حفظ الدفعة
      print('🚨 DEBUG: Starting batch data preparation');
      AppLogger.info('💾 إعداد بيانات الدفعة للحفظ...');
      print('💾 إعداد بيانات الدفعة للحفظ...');

      final batchData = batch.copyWith(
        totalItems: items.length,
        processedItems: items.length,
        processingStatus: 'completed',
        summaryStats: {
          'total_quantity': statistics.quantityStatistics.sum,
          'total_value': statistics.priceStatistics?.sum ?? 0.0,
          'categories_count': statistics.categoryBreakdown.length,
          'smart_summary': smartSummary,
          'enhanced_summary': enhancedSummary,
          'validation_report': validationReport,
          'processing_method': 'intelligent_grouping_v2',
          'has_grouped_products': items.any((item) => item.isGroupedProduct),
          'grouped_products_count': items.where((item) => item.isGroupedProduct).length,
        },
        categoryBreakdown: statistics.categoryBreakdown.map(
          (key, value) => MapEntry(key, {
            'count': value.itemCount,
            'percentage': value.percentage,
          }),
        ),
      );

      AppLogger.info('✅ تم إعداد بيانات الدفعة بنجاح');

      print('🚨 DEBUG: About to save batch to database');
      AppLogger.info('💾 محاولة حفظ الدفعة في جدول import_batches...');
      print('💾 محاولة حفظ الدفعة في جدول import_batches...');

      final batchJson = batchData.toJson();
      print('🚨 DEBUG: Batch JSON prepared, size: ${batchJson.toString().length}');
      AppLogger.info('📋 حجم بيانات الدفعة: ${batchJson.toString().length} حرف');
      print('📋 حجم بيانات الدفعة: ${batchJson.toString().length} حرف');

      // CRITICAL FIX: Validate batch data before saving
      await _validateBatchDataForDatabase(batchData, batchJson);

      print('🚨 DEBUG: Calling _supabaseService.createRecord for batch');
      final savedBatch = await _supabaseService.createRecord(
        'import_batches',
        batchJson,
      );
      print('🚨 DEBUG: Batch saved successfully');
      AppLogger.info('✅ تم حفظ الدفعة بنجاح');
      print('✅ تم حفظ الدفعة بنجاح');

      final batchId = savedBatch['id'] as String;
      print('🚨 DEBUG: Batch ID received: $batchId');
      AppLogger.info('🆔 معرف الدفعة المحفوظة: $batchId');
      print('🆔 معرف الدفعة المحفوظة: $batchId');

      // CRITICAL FIX: Add small delay to ensure batch is committed before items
      await Future.delayed(const Duration(milliseconds: 100));

      // حفظ العناصر
      print('🚨 DEBUG: Starting to save ${items.length} items');
      AppLogger.info('💾 بدء حفظ ${items.length} عنصر في جدول packing_list_items...');
      print('💾 بدء حفظ ${items.length} عنصر في جدول packing_list_items...');
      int savedItemsCount = 0;

      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        print('🚨 DEBUG: Processing item ${i + 1}/${items.length}: ${item.itemNumber}');
        try {
          AppLogger.info('💾 حفظ العنصر ${i + 1}/${items.length}: ${item.itemNumber}');
          print('💾 حفظ العنصر ${i + 1}/${items.length}: ${item.itemNumber}');

          final itemData = item.copyWith(
            importBatchId: batchId,
          );

          // التحقق من القيم قبل الحفظ لتجنب تجاوز حدود قاعدة البيانات
          final itemJson = itemData.toJson();

          // CRITICAL FIX: Only remove ID if it's not a valid UUID
          // The database will generate a new UUID if none is provided
          if (itemJson['id'] == null || itemJson['id'].toString().trim().isEmpty) {
            itemJson.remove('id');
            AppLogger.info('🔧 Removed empty ID, database will generate new UUID');
          } else {
            AppLogger.info('🆔 Using provided UUID: ${itemJson['id']}');
          }

          AppLogger.info('🔍 التحقق من صحة البيانات للعنصر: ${item.itemNumber}');

          // ENHANCED VALIDATION: Comprehensive data validation before database save
          await _validateItemDataForDatabase(item, itemJson);

          // CRITICAL FIX: Validate decimal precision limits
          _validateDecimalPrecisionLimits(itemJson, item.itemNumber);

          _validateNumericFields(itemJson, item.itemNumber);

          // التحقق من حجم البيانات
          final jsonString = itemJson.toString();
          print('🚨 DEBUG: Item JSON size: ${jsonString.length} characters');
          if (jsonString.length > 1000000) { // 1MB limit
            AppLogger.warning('⚠️ حجم بيانات العنصر ${item.itemNumber} كبير: ${jsonString.length} حرف');
            print('⚠️ حجم بيانات العنصر ${item.itemNumber} كبير: ${jsonString.length} حرف');
          }

          print('🚨 DEBUG: About to save item ${item.itemNumber} to database');
          await _supabaseService.createRecord(
            'packing_list_items',
            itemJson,
          );
          print('🚨 DEBUG: Item ${item.itemNumber} saved successfully');

          savedItemsCount++;
          if (savedItemsCount % 10 == 0) {
            AppLogger.info('📊 تم حفظ $savedItemsCount من ${items.length} عنصر');
          }

        } catch (e) {
          print('🚨 DEBUG: ERROR saving item ${item.itemNumber}: $e');
          AppLogger.error('❌ فشل في حفظ العنصر ${item.itemNumber}: $e');
          print('❌ فشل في حفظ العنصر ${item.itemNumber}: $e');
          AppLogger.error('📋 بيانات العنصر الفاشل: ${item.toJson()}');
          print('📋 بيانات العنصر الفاشل: ${item.toJson()}');
          rethrow;
        }
      }

      print('🚨 DEBUG: All items saved successfully');
      AppLogger.info('✅ تم حفظ الدفعة و$savedItemsCount عنصر في قاعدة البيانات بنجاح');
      print('✅ تم حفظ الدفعة و$savedItemsCount عنصر في قاعدة البيانات بنجاح');

    } catch (e, stackTrace) {
      print('🚨 DEBUG: MAJOR ERROR in _saveBatchToDatabase: $e');
      print('🚨 DEBUG: Stack trace: $stackTrace');
      AppLogger.error('❌ خطأ في حفظ البيانات: $e');
      AppLogger.error('📋 تفاصيل الخطأ: $stackTrace');
      print('❌ خطأ في حفظ البيانات: $e');
      print('📋 تفاصيل الخطأ: $stackTrace');

      // ENHANCED ERROR ANALYSIS
      await _analyzeAndLogDatabaseError(e, stackTrace, batch, items);

      // تحسين رسائل الخطأ للمستخدم
      String userFriendlyMessage = 'فشل في حفظ البيانات';

      if (e.toString().contains('numeric field overflow')) {
        userFriendlyMessage = 'فشل في حفظ البيانات: قيمة رقمية تتجاوز الحد المسموح. يرجى التحقق من قيم الأسعار والأوزان والأحجام في الملف.';
      } else if (e.toString().contains('PostgrestException')) {
        userFriendlyMessage = 'فشل في حفظ البيانات: خطأ في قاعدة البيانات. يرجى المحاولة مرة أخرى أو الاتصال بالدعم الفني.';
      } else if (e.toString().contains('connection')) {
        userFriendlyMessage = 'فشل في حفظ البيانات: مشكلة في الاتصال بالخادم. يرجى التحقق من الاتصال بالإنترنت.';
      } else if (e.toString().contains('duplicate key')) {
        userFriendlyMessage = 'فشل في حفظ البيانات: يوجد تكرار في البيانات. يرجى التحقق من الملف.';
      } else if (e.toString().contains('foreign key')) {
        userFriendlyMessage = 'فشل في حفظ البيانات: خطأ في ربط البيانات. يرجى المحاولة مرة أخرى.';
      } else if (e.toString().contains('null value')) {
        userFriendlyMessage = 'فشل في حفظ البيانات: يوجد قيم مفقودة مطلوبة. يرجى التحقق من اكتمال البيانات في الملف.';
      }

      throw Exception(userFriendlyMessage);
    }
  }

  /// ENHANCED BATCH DATA VALIDATION FOR DATABASE
  Future<void> _validateBatchDataForDatabase(ImportBatch batch, Map<String, dynamic> batchJson) async {
    try {
      AppLogger.info('🔍 BATCH VALIDATION: ${batch.filename}');

      // 1. Required Fields Validation
      if (batch.filename.trim().isEmpty) {
        throw Exception('اسم الملف مطلوب');
      }

      if (batch.originalFilename.trim().isEmpty) {
        throw Exception('الاسم الأصلي للملف مطلوب');
      }

      if (batch.fileSize <= 0) {
        throw Exception('حجم الملف يجب أن يكون أكبر من صفر');
      }

      if (batch.createdBy == null || batch.createdBy!.trim().isEmpty) {
        throw Exception('معرف المستخدم المنشئ مطلوب');
      }

      // 2. File Type Validation
      final validFileTypes = ['xlsx', 'xls', 'csv'];
      if (!validFileTypes.contains(batch.fileType.toLowerCase())) {
        throw Exception('نوع الملف غير مدعوم: ${batch.fileType}');
      }

      // 3. Processing Status Validation
      final validStatuses = ['pending', 'processing', 'completed', 'failed', 'cancelled'];
      if (!validStatuses.contains(batch.processingStatus)) {
        AppLogger.warning('⚠️ Invalid processing status: ${batch.processingStatus}, setting to pending');
        batchJson['processing_status'] = 'pending';
      }

      // 4. User ID Validation
      final currentUserId = _supabaseService.currentUserId;
      if (batch.createdBy != currentUserId) {
        AppLogger.warning('⚠️ Batch created by user ID mismatch: ${batch.createdBy} vs $currentUserId');
        batchJson['created_by'] = currentUserId;
      }

      AppLogger.info('✅ Batch validation passed: ${batch.filename}');

    } catch (e) {
      AppLogger.error('❌ Batch validation failed for ${batch.filename}: $e');
      rethrow;
    }
  }

  /// ENHANCED ITEM DATA VALIDATION FOR DATABASE
  Future<void> _validateItemDataForDatabase(PackingListItem item, Map<String, dynamic> itemJson) async {
    try {
      AppLogger.info('🔍 COMPREHENSIVE VALIDATION: ${item.itemNumber}');

      // 1. Required Fields Validation
      if (item.itemNumber.trim().isEmpty) {
        throw Exception('رقم العنصر مطلوب ولا يمكن أن يكون فارغاً');
      }

      if (item.totalQuantity < 0) {
        throw Exception('الكمية الإجمالية لا يمكن أن تكون سالبة');
      }

      // تحذير للكميات الصفرية لكن لا نمنع الحفظ
      if (item.totalQuantity == 0) {
        AppLogger.warning('⚠️ العنصر ${item.itemNumber} له كمية صفرية - قد يحتاج لمراجعة');
      }

      if (item.importBatchId.trim().isEmpty) {
        throw Exception('معرف الدفعة مطلوب');
      }

      if (item.createdBy == null || item.createdBy!.trim().isEmpty) {
        throw Exception('معرف المستخدم المنشئ مطلوب');
      }

      // 2. Foreign Key Validation
      final currentUserId = _supabaseService.currentUserId;
      if (item.createdBy != currentUserId) {
        AppLogger.warning('⚠️ Created by user ID mismatch: ${item.createdBy} vs $currentUserId');
        // Fix the created_by field to match current user
        itemJson['created_by'] = currentUserId;
      }

      // 3. Text Field Length Validation
      if (item.itemNumber.length > 255) {
        throw Exception('رقم العنصر طويل جداً (الحد الأقصى 255 حرف)');
      }

      // 4. JSON Field Validation
      if (item.remarks != null) {
        try {
          final remarksString = item.remarks.toString();
          if (remarksString.length > 10000) { // Reasonable limit for JSONB
            AppLogger.warning('⚠️ Remarks field very large: ${remarksString.length} characters');
          }
        } catch (e) {
          AppLogger.warning('⚠️ Invalid remarks JSON: $e');
        }
      }

      // 5. Arabic Text Encoding Validation
      if (item.remarks != null && item.remarks is Map) {
        final remarksMap = item.remarks as Map<String, dynamic>;
        for (final entry in remarksMap.entries) {
          if (entry.value is String) {
            final text = entry.value as String;
            // Check for Arabic text and ensure proper encoding
            if (text.contains(RegExp(r'[\u0600-\u06FF]'))) {
              AppLogger.info('✅ Arabic text detected in ${entry.key}: ${text.length} characters');
            }
          }
        }
      }

      AppLogger.info('✅ Item validation passed: ${item.itemNumber}');

    } catch (e) {
      AppLogger.error('❌ Item validation failed for ${item.itemNumber}: $e');
      rethrow;
    }
  }

  /// CRITICAL FIX: Validate decimal precision limits according to database schema
  void _validateDecimalPrecisionLimits(Map<String, dynamic> itemJson, String itemNumber) {
    // DECIMAL(3,2) fields - can only store values from -9.99 to 9.99
    // But for confidence scores, should be 0.00 to 1.00
    final decimal32Fields = [
      'classification_confidence',
      'data_quality_score',
      'similarity_score',
    ];

    for (final field in decimal32Fields) {
      final value = itemJson[field];
      if (value != null && value is num) {
        final doubleValue = value.toDouble();
        if (doubleValue > 1.0 || doubleValue < 0.0) {
          AppLogger.warning('⚠️ Confidence/score field $field for item $itemNumber out of range: $doubleValue (must be 0.0-1.0)');
          // Clamp the value to valid range
          itemJson[field] = doubleValue.clamp(0.0, 1.0);
          AppLogger.info('✅ Clamped $field to: ${itemJson[field]}');
        }
        if (doubleValue.isNaN || doubleValue.isInfinite) {
          AppLogger.warning('⚠️ Invalid $field value for item $itemNumber: $doubleValue, setting to 0.0');
          itemJson[field] = 0.0;
        }
      }
    }

    // DECIMAL(12,6) fields - pricing fields
    final decimal126Fields = [
      'unit_price',
      'rmb_price',
      'converted_price',
    ];

    const maxPrice = 999999.999999; // DECIMAL(12,6) max value
    for (final field in decimal126Fields) {
      final value = itemJson[field];
      if (value != null && value is num) {
        final doubleValue = value.toDouble();
        if (doubleValue > maxPrice || doubleValue < 0.0) {
          AppLogger.warning('⚠️ Price field $field for item $itemNumber out of range: $doubleValue');
          if (doubleValue < 0.0) {
            itemJson[field] = 0.0;
          } else if (doubleValue > maxPrice) {
            throw Exception('قيمة $field للعنصر $itemNumber تتجاوز الحد المسموح ($doubleValue). يرجى مراجعة البيانات في الملف.');
          }
        }
        if (doubleValue.isNaN || doubleValue.isInfinite) {
          AppLogger.warning('⚠️ Invalid $field value for item $itemNumber: $doubleValue, setting to null');
          itemJson[field] = null;
        }
      }
    }
  }

  /// التحقق من القيم الرقمية لتجنب تجاوز حدود قاعدة البيانات
  void _validateNumericFields(Map<String, dynamic> itemJson, String itemNumber) {
    const maxDecimalValue = 999999999.999999; // DECIMAL(15,6) max value
    const minDecimalValue = -999999999.999999; // DECIMAL(15,6) min value
    const maxIntValue = 2147483647; // INTEGER max value
    const minIntValue = -2147483648; // INTEGER min value
    const maxBigIntValue = 9223372036854775807; // BIGINT max value
    const minBigIntValue = -9223372036854775808; // BIGINT min value

    // الحقول التي تحتاج للتحقق من حدود DECIMAL(15,6)
    final decimalFieldsToCheck = [
      'total_cubic_meters',
      'conversion_rate',
    ];

    // الحقول التي تحتاج للتحقق من حدود INTEGER
    final intFieldsToCheck = [
      'serial_number',
      'carton_count',
      'pieces_per_carton',
    ];

    // الحقول التي تحتاج للتحقق من حدود BIGINT (للكميات الكبيرة)
    final bigIntFieldsToCheck = [
      'total_quantity',
    ];

    // التحقق من الحقول العشرية
    for (final field in decimalFieldsToCheck) {
      final value = itemJson[field];
      if (value != null && value is num) {
        final doubleValue = value.toDouble();
        if (doubleValue > maxDecimalValue || doubleValue < minDecimalValue) {
          AppLogger.warning('قيمة $field للعنصر $itemNumber تتجاوز حدود قاعدة البيانات: $doubleValue');
          throw Exception('قيمة $field للعنصر $itemNumber تتجاوز الحد المسموح ($doubleValue). يرجى مراجعة البيانات في الملف.');
        }
        if (doubleValue.isNaN || doubleValue.isInfinite) {
          AppLogger.warning('قيمة $field للعنصر $itemNumber غير صحيحة: $doubleValue');
          throw Exception('قيمة $field للعنصر $itemNumber غير صحيحة. يرجى مراجعة البيانات في الملف.');
        }
      }
    }

    // التحقق من الحقول الصحيحة
    for (final field in intFieldsToCheck) {
      final value = itemJson[field];
      if (value != null && value is num) {
        final intValue = value.toInt();
        if (intValue > maxIntValue || intValue < minIntValue) {
          AppLogger.warning('قيمة $field للعنصر $itemNumber تتجاوز حدود قاعدة البيانات: $intValue');
          throw Exception('قيمة $field للعنصر $itemNumber تتجاوز الحد المسموح ($intValue). يرجى مراجعة البيانات في الملف.');
        }
      }
    }

    // التحقق من الحقول الصحيحة الكبيرة (BIGINT)
    for (final field in bigIntFieldsToCheck) {
      final value = itemJson[field];
      if (value != null && value is num) {
        final intValue = value.toInt();
        if (intValue > maxBigIntValue || intValue < minBigIntValue) {
          AppLogger.warning('قيمة $field للعنصر $itemNumber تتجاوز حدود قاعدة البيانات: $intValue');
          throw Exception('قيمة $field للعنصر $itemNumber تتجاوز الحد المسموح ($intValue). يرجى مراجعة البيانات في الملف.');
        }
        // تسجيل تحذيري للقيم الكبيرة جداً
        if (intValue > 1000000000) { // مليار
          AppLogger.warning('⚠️ قيمة $field للعنصر $itemNumber كبيرة جداً: $intValue - تأكد من صحة البيانات');
        }
      }
    }

    // التحقق من الحقول المطلوبة
    if (itemJson['item_number'] == null || itemJson['item_number'].toString().trim().isEmpty) {
      throw Exception('رقم العنصر مطلوب ولا يمكن أن يكون فارغاً');
    }

    if (itemJson['import_batch_id'] == null || itemJson['import_batch_id'].toString().trim().isEmpty) {
      throw Exception('معرف الدفعة مطلوب ولا يمكن أن يكون فارغاً');
    }

    // التحقق من صحة بيانات المواد
    final materials = itemJson['materials'];
    if (materials != null && materials is List) {
      for (int i = 0; i < materials.length; i++) {
        final material = materials[i];
        if (material is Map<String, dynamic>) {
          if (material['material_name'] == null || material['material_name'].toString().trim().isEmpty) {
            throw Exception('اسم المادة مطلوب في العنصر $itemNumber');
          }
          if (material['quantity'] == null || material['quantity'] is! num || material['quantity'] < 0) {
            throw Exception('كمية المادة يجب أن تكون رقم غير سالب في العنصر $itemNumber');
          }

          // تحذير للكميات الصفرية لكن لا نمنع الحفظ
          if (material['quantity'] == 0) {
            AppLogger.warning('⚠️ المادة "${material['material_name']}" في العنصر $itemNumber لها كمية صفرية');
          }
        }
      }
    }

    // التحقق من صحة بيانات JSON المعقدة
    try {
      // محاولة تحويل البيانات إلى JSON للتأكد من عدم وجود مراجع دائرية
      final testJson = jsonEncode(itemJson);
      if (testJson.length > 2000000) { // 2MB limit for individual item
        throw Exception('حجم بيانات العنصر $itemNumber كبير جداً');
      }
    } catch (e) {
      throw Exception('خطأ في تحويل بيانات العنصر $itemNumber إلى JSON: $e');
    }
  }

  /// تحميل دفعة محددة
  Future<void> loadBatch(String batchId) async {
    try {
      _setLoading(true);
      _clearError();

      // تحميل الدفعة
      final batchData = await _supabaseService.getRecord('import_batches', batchId);
      if (batchData == null) {
        throw Exception('الدفعة غير موجودة');
      }

      _currentBatch = ImportBatch.fromJson(batchData);

      // تحميل العناصر
      final itemsData = await _supabaseService.getRecordsByFilter(
        'packing_list_items',
        'import_batch_id',
        batchId,
      );

      _currentItems = itemsData
          .map((item) => PackingListItem.fromJson(item))
          .toList();

      // استخراج البيانات المحسنة من الدفعة
      final summaryStats = _currentBatch?.summaryStats;
      if (summaryStats != null) {
        _enhancedSummary = summaryStats['enhanced_summary'] as Map<String, dynamic>?;
        _validationReport = summaryStats['validation_report'] as Map<String, dynamic>?;
        _smartSummary = summaryStats['smart_summary'] as Map<String, dynamic>?;
      }

      // إعادة بناء مجموعات المنتجات من العناصر المجمعة
      _currentProductGroups = await _reconstructProductGroupsFromItems(_currentItems);

      // حساب الإحصائيات
      _currentStatistics = await PackingListAnalyzer.analyzeStatistics(_currentItems);

      // كشف التكرار
      _duplicateClusters = await PackingListAnalyzer.detectDuplicates(_currentItems);

      // إنشاء التقرير الذكي إذا لم يكن موجوداً
      if (_smartSummary == null) {
        _smartSummary = SmartSummaryService.generateSmartSummary(_currentItems);
      }

      // إعادة تعيين الفلاتر
      _currentPage = 0;

      notifyListeners();

    } catch (e) {
      _setError('خطأ في تحميل الدفعة: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// البحث مع التأخير
  void search(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1500), () {
      _searchQuery = query;
      _currentPage = 0;
      notifyListeners();
    });
  }

  /// تطبيق فلتر التصنيف
  void filterByCategory(String category) {
    _selectedCategory = category;
    _currentPage = 0;
    notifyListeners();
  }

  /// تطبيق فلتر الحالة
  void filterByStatus(String status) {
    _selectedStatus = status;
    _currentPage = 0;
    notifyListeners();
  }

  /// تغيير الصفحة
  void changePage(int page) {
    if (page >= 0 && page < totalPages) {
      _currentPage = page;
      notifyListeners();
    }
  }

  /// تغيير عدد العناصر في الصفحة
  void changeItemsPerPage(int itemsPerPage) {
    _itemsPerPage = itemsPerPage;
    _currentPage = 0;

    // تحديث الإعدادات
    if (_userSettings != null) {
      _userSettings = _userSettings!.copyWith(itemsPerPage: itemsPerPage);
      _saveUserSettings();
    }

    notifyListeners();
  }



  /// حذف دفعة
  Future<void> deleteBatch(String batchId) async {
    try {
      _setLoading(true);

      // حذف العناصر أولاً
      await _supabaseService.deleteRecord('packing_list_items', batchId);

      // حذف الدفعة
      await _supabaseService.deleteRecord('import_batches', batchId);

      // إعادة تحميل الدفعات
      await _loadImportBatches();

      // إذا كانت الدفعة المحذوفة هي الحالية، مسح البيانات
      if (_currentBatch?.id == batchId) {
        _currentBatch = null;
        _currentItems.clear();
        _currentStatistics = null;
        _duplicateClusters.clear();
        _smartSummary = null;
      }

      notifyListeners();

    } catch (e) {
      _setError('خطأ في حذف الدفعة: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// مسح جميع بيانات الاستيراد (للتشخيص والاختبار)
  Future<void> clearAllImportData() async {
    try {
      _setLoading(true);
      AppLogger.info('🧹 بدء مسح جميع بيانات الاستيراد...');

      // مسح جميع العناصر باستخدام الطريقة الصحيحة
      // نحتاج لحذف العناصر واحداً تلو الآخر لأن Supabase لا يدعم حذف جميع الصفوف مباشرة
      final allItems = await _supabaseService.getAllRecords('packing_list_items');
      for (final item in allItems) {
        await _supabaseService.deleteRecord('packing_list_items', item['id']);
      }

      AppLogger.info('✅ تم مسح عناصر قائمة التعبئة');

      // مسح جميع الدفعات
      final allBatches = await _supabaseService.getAllRecords('import_batches');
      for (final batch in allBatches) {
        await _supabaseService.deleteRecord('import_batches', batch['id']);
      }

      AppLogger.info('✅ تم مسح دفعات الاستيراد');

      // مسح البيانات المحلية
      _importBatches.clear();
      _currentBatch = null;
      _currentItems.clear();
      _currentStatistics = null;
      _duplicateClusters.clear();
      _smartSummary = null;

      AppLogger.info('✅ تم مسح جميع بيانات الاستيراد بنجاح');
      notifyListeners();

    } catch (e) {
      AppLogger.error('❌ خطأ في مسح بيانات الاستيراد: $e');
      _setError('خطأ في مسح البيانات: $e');
    } finally {
      _setLoading(false);
    }
  }

  // ملف محدد للمعالجة في سير العمل الجديد
  PlatformFile? _selectedFile;
  PlatformFile? get selectedFile => _selectedFile;

  /// اختيار ملف للمعالجة (للاستخدام في سير العمل الجديد)
  Future<void> pickFile() async {
    try {
      _clearError();

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return; // المستخدم ألغى العملية
      }

      final file = result.files.first;

      // التحقق من حجم الملف
      final maxSize = (_userSettings?.maxFileSizeMb ?? 50) * 1024 * 1024;
      if (file.size > maxSize) {
        throw Exception('حجم الملف كبير جداً. الحد الأقصى: ${_userSettings?.maxFileSizeMb ?? 50}MB');
      }

      // تحديد نوع الملف
      final extension = file.extension?.toLowerCase();
      final fileType = SupportedFileType.fromExtension(extension ?? '');

      if (fileType == null) {
        throw Exception('نوع الملف غير مدعوم. الأنواع المدعومة: xlsx, xls, csv');
      }

      _selectedFile = file;
      notifyListeners();

    } catch (e) {
      _setError('خطأ في اختيار الملف: $e');
    }
  }

  /// معالجة الملف المحدد
  Future<void> processSelectedFile() async {
    if (_selectedFile == null) {
      _setError('لم يتم اختيار ملف للمعالجة');
      return;
    }

    final file = _selectedFile!;
    final filePath = file.path;

    if (filePath == null) {
      _setError('مسار الملف غير صحيح');
      return;
    }

    final extension = file.extension?.toLowerCase();
    final fileType = SupportedFileType.fromExtension(extension ?? '');

    if (fileType == null) {
      _setError('نوع الملف غير مدعوم');
      return;
    }

    await _processFile(filePath, file.name, fileType, file.size);
  }

  /// رفع ومعالجة ملف في خطوة واحدة (للاستخدام في الشاشة التشخيصية)
  Future<void> pickAndProcessFile() async {
    await pickFile();
    if (_selectedFile != null) {
      await processSelectedFile();
    }
  }

  /// تشخيص معالجة Excel مع بيانات وهمية للاختبار
  Future<void> debugExcelProcessing() async {
    try {
      _setLoading(true);
      _setStatus('🔍 بدء تشخيص معالجة Excel...');
      _setProgress(0.0);

      AppLogger.info('🧪 بدء تشخيص معالجة Excel مع بيانات وهمية');

      // إنشاء بيانات Excel وهمية للاختبار
      final mockExcelData = [
        // صف الرؤوس
        ['S/NO', 'ITEM NO.', 'picture', 'ctn', 'pc/ctn', 'QTY', 'size1', 'size2', 'size3', 't.cbm', 'N.W', 'G.W', 'T.NW', 'T.GW', 'PRICE', 'RMB', 'REMARKS'],

        // بيانات حقيقية من المثال المقدم
        ['1', 'C11/3GD', '10', '1', '200', '200', '55', '25', '39', '0.05', '21.50', '22.00', '21.50', '22.00', '', '', 'شبوه البلاستكية و قطعه غياره معدن'],
        ['2', '6330/500', '20', '2', '100', '200', '60', '30', '40', '0.07', '25.00', '26.00', '50.00', '52.00', '', '', 'قطع غيار معدنية'],
        ['3', 'ES-1008-560', '30', '1', '150', '150', '45', '20', '35', '0.03', '18.00', '19.00', '18.00', '19.00', '', '', 'مواد بلاستيكية'],
      ];

      _setStatus('🔍 اختبار كشف الرؤوس...');
      _setProgress(0.2);

      // اختبار كشف الرؤوس
      final headerResult = ExcelParsingService.detectHeaders(mockExcelData);
      AppLogger.info('📋 نتيجة كشف الرؤوس:');
      AppLogger.info('   صف الرؤوس: ${headerResult.headerRow}');
      AppLogger.info('   خريطة الأعمدة: ${headerResult.mapping}');
      AppLogger.info('   الثقة: ${headerResult.confidence}');

      _setStatus('📊 اختبار استخراج البيانات...');
      _setProgress(0.4);

      // اختبار استخراج البيانات
      final extractedData = ExcelParsingService.extractPackingListData(mockExcelData, headerResult);
      AppLogger.info('📊 البيانات المستخرجة (${extractedData.length} عنصر):');

      for (int i = 0; i < extractedData.length; i++) {
        final item = extractedData[i];
        AppLogger.info('   العنصر ${i + 1}:');
        AppLogger.info('     رقم الصنف: "${item['item_number']}"');
        AppLogger.info('     الكمية الإجمالية: ${item['total_quantity']}');
        AppLogger.info('     عدد الكراتين: ${item['carton_count']}');
        AppLogger.info('     قطع/كرتون: ${item['pieces_per_carton']}');
        AppLogger.info('     الملاحظات: "${item['remarks_a']}"');
      }

      _setStatus('🔄 تحويل البيانات إلى PackingListItem...');
      _setProgress(0.6);

      // تحويل البيانات إلى PackingListItem
      final items = <PackingListItem>[];
      for (final data in extractedData) {
        final item = _createPackingListItem(data, 'debug-batch-id');
        items.add(item);
      }

      _setStatus('📈 إنشاء التقرير الذكي...');
      _setProgress(0.8);

      // إنشاء التقرير الذكي
      final smartSummary = SmartSummaryService.generateSmartSummary(items);
      AppLogger.info('📋 التقرير الذكي المُنشأ:');
      AppLogger.info('   إجمالي العناصر: ${smartSummary['total_items_processed']}');
      AppLogger.info('   العناصر الصحيحة: ${smartSummary['valid_items']}');

      if (smartSummary['totals'] != null) {
        final totals = smartSummary['totals'] as Map<String, dynamic>;
        AppLogger.info('   الإجماليات:');
        AppLogger.info('     إجمالي الكراتين: ${totals['ctn']}');
        AppLogger.info('     إجمالي الكمية: ${totals['QTY']}');
        AppLogger.info('     إجمالي قطع/كرتون: ${totals['pc_ctn']}');

        // التحقق من القيم الوهمية
        if (totals['ctn'] == 836 || totals['QTY'] == 836 || totals['pc_ctn'] == 836) {
          AppLogger.error('❌ تم اكتشاف قيم وهمية! الإجماليات تحتوي على 836');
        } else {
          AppLogger.info('✅ لا توجد قيم وهمية - الإجماليات صحيحة');
        }
      }

      _setStatus('✅ اكتمل التشخيص بنجاح');
      _setProgress(1.0);

      // تحديث البيانات المحلية للعرض
      _currentItems = items;
      _smartSummary = smartSummary;

      notifyListeners();

    } catch (e) {
      AppLogger.error('❌ خطأ في تشخيص Excel: $e');
      _setError('خطأ في التشخيص: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// مسح جميع البيانات
  void clearData() {
    _currentBatch = null;
    _currentItems.clear();
    _currentStatistics = null;
    _duplicateClusters.clear();
    _smartSummary = null;
    _searchQuery = '';
    _selectedCategory = '';
    _selectedStatus = '';
    _currentPage = 0;
    _clearError();
    notifyListeners();
  }

  /// تصدير التقرير الذكي كـ JSON
  String? exportSmartSummaryAsJson() {
    if (_smartSummary == null) return null;
    return SmartSummaryService.generateJsonSummary(_currentItems);
  }

  /// الحصول على ملخص الملاحظات المجمعة
  List<Map<String, dynamic>>? getRemarksGroupedByQuantity() {
    return _smartSummary?['remarks_summary'] as List<Map<String, dynamic>>?;
  }

  /// الحصول على إجماليات الأعمدة الرقمية
  Map<String, dynamic>? getNumericalTotals() {
    return _smartSummary?['totals'] as Map<String, dynamic>?;
  }

  /// تعيين حالة التحميل
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// تعيين حالة المعالجة
  void _setProcessing(bool processing) {
    _isProcessing = processing;
    if (!processing) {
      _processingProgress = 0.0;
      _currentStatus = '';
    }
    notifyListeners();
  }

  /// تعيين الحالة الحالية
  void _setStatus(String status) {
    _currentStatus = status;
    notifyListeners();
  }

  /// تعيين تقدم المعالجة
  void _setProgress(double progress) {
    _processingProgress = progress.clamp(0.0, 1.0);
    notifyListeners();
  }

  /// تعيين رسالة خطأ
  void _setError(String error) {
    _errorMessage = error;
    AppLogger.error(error);
    notifyListeners();
  }

  /// مسح رسالة الخطأ
  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// ENHANCED DATABASE CONNECTION VALIDATION
  Future<void> _validateDatabaseConnection() async {
    try {
      AppLogger.info('🔍 DIAGNOSTIC: Validating database connection and authentication...');

      // Check current user authentication
      final currentUserId = _supabaseService.currentUserId;
      final currentUser = _supabaseService.currentUser;
      final currentSession = _supabaseService.currentSession;

      AppLogger.info('👤 Current User ID: $currentUserId');
      AppLogger.info('📧 Current User Email: ${currentUser?.email}');
      AppLogger.info('🔐 Session exists: ${currentSession != null}');
      AppLogger.info('⏰ Session expired: ${currentSession?.isExpired ?? 'N/A'}');

      if (currentUserId == null) {
        throw Exception('❌ CRITICAL: No authenticated user found');
      }

      if (currentSession?.isExpired == true) {
        AppLogger.warning('⚠️ Session expired, attempting refresh...');
        // Session refresh is handled automatically by Supabase
      }

      // Test database connectivity with a simple query
      try {
        final testQuery = await _supabaseService.getAllRecords('import_batches');
        AppLogger.info('✅ Database connectivity test passed (found ${testQuery.length} existing batches)');
      } catch (dbError) {
        AppLogger.error('❌ Database connectivity test failed: $dbError');
        throw Exception('Database connection failed: $dbError');
      }

      // Test RLS permissions by attempting to read user's own data
      try {
        final userBatches = await _supabaseService.getRecordsByFilter(
          'import_batches',
          'created_by',
          currentUserId
        );
        AppLogger.info('✅ RLS permissions test passed (user has ${userBatches.length} existing batches)');
      } catch (rlsError) {
        AppLogger.error('❌ RLS permissions test failed: $rlsError');
        throw Exception('Database permissions error: $rlsError');
      }

      AppLogger.info('✅ Database connection and authentication validation completed successfully');

    } catch (e) {
      AppLogger.error('💥 Database validation failed: $e');
      rethrow;
    }
  }

  /// ENHANCED ERROR ANALYSIS AND LOGGING
  Future<void> _analyzeAndLogDatabaseError(
    dynamic error,
    StackTrace stackTrace,
    ImportBatch batch,
    List<PackingListItem> items
  ) async {
    try {
      AppLogger.error('🔍 DETAILED ERROR ANALYSIS:');
      AppLogger.error('📋 Error Type: ${error.runtimeType}');
      AppLogger.error('📋 Error Message: $error');

      // Check if it's a Supabase-specific error
      if (error.toString().contains('PostgrestException')) {
        AppLogger.error('🗄️ PostgreSQL Database Error Detected');

        // Extract specific error details
        final errorString = error.toString();
        if (errorString.contains('duplicate key')) {
          AppLogger.error('🔑 Duplicate Key Constraint Violation');
          if (errorString.contains('import_batches_pkey')) {
            AppLogger.error('   - Duplicate batch ID detected');
          } else if (errorString.contains('packing_list_items_pkey')) {
            AppLogger.error('   - Duplicate item ID detected');
          }
        } else if (errorString.contains('foreign key')) {
          AppLogger.error('🔗 Foreign Key Constraint Violation');
          if (errorString.contains('import_batch_id')) {
            AppLogger.error('   - Invalid import_batch_id reference - batch may not exist');
          } else if (errorString.contains('created_by')) {
            AppLogger.error('   - Invalid created_by user reference');
          }
        } else if (errorString.contains('check constraint')) {
          AppLogger.error('✅ Check Constraint Violation');
          if (errorString.contains('file_type')) {
            AppLogger.error('   - Invalid file_type value (must be xlsx, xls, or csv)');
          } else if (errorString.contains('processing_status')) {
            AppLogger.error('   - Invalid processing_status value');
          } else if (errorString.contains('validation_status')) {
            AppLogger.error('   - Invalid validation_status value');
          }
        } else if (errorString.contains('not null')) {
          AppLogger.error('❌ NOT NULL Constraint Violation');
          if (errorString.contains('item_number')) {
            AppLogger.error('   - item_number cannot be null');
          } else if (errorString.contains('total_quantity')) {
            AppLogger.error('   - total_quantity cannot be null');
          } else if (errorString.contains('import_batch_id')) {
            AppLogger.error('   - import_batch_id cannot be null');
          }
        } else if (errorString.contains('row-level security')) {
          AppLogger.error('🔒 Row Level Security Policy Violation');
          AppLogger.error('   - User does not have permission to insert/update this data');
          AppLogger.error('   - Check if batch exists and belongs to current user');
        } else if (errorString.contains('numeric field overflow')) {
          AppLogger.error('📊 Numeric Field Overflow');
          AppLogger.error('   - One or more numeric values exceed database limits');
        }
      }

      // Log authentication context
      final currentUserId = _supabaseService.currentUserId;
      final currentSession = _supabaseService.currentSession;
      AppLogger.error('👤 User Context: $currentUserId');
      AppLogger.error('🔐 Session Valid: ${currentSession != null && !(currentSession?.isExpired ?? true)}');

      // Log batch data summary
      AppLogger.error('📦 Batch Data Summary:');
      AppLogger.error('  - Filename: ${batch.filename}');
      AppLogger.error('  - Items Count: ${items.length}');
      AppLogger.error('  - Created By: ${batch.createdBy}');
      AppLogger.error('  - File Size: ${batch.fileSize} bytes');

      // Log first few items for debugging
      if (items.isNotEmpty) {
        AppLogger.error('📋 Sample Item Data (first 3 items):');
        for (int i = 0; i < items.length && i < 3; i++) {
          final item = items[i];
          AppLogger.error('  Item ${i + 1}:');
          AppLogger.error('    - Item Number: ${item.itemNumber}');
          AppLogger.error('    - Total Quantity: ${item.totalQuantity}');
          AppLogger.error('    - Batch ID: ${item.importBatchId}');
          AppLogger.error('    - Created By: ${item.createdBy}');

          // Check for potential data issues
          if (item.itemNumber.isEmpty) {
            AppLogger.error('    ⚠️ WARNING: Empty item number');
          }
          if (item.totalQuantity <= 0) {
            AppLogger.error('    ⚠️ WARNING: Invalid quantity: ${item.totalQuantity}');
          }
        }
      }

      // Log stack trace for debugging
      AppLogger.error('📋 Stack Trace: $stackTrace');

    } catch (analysisError) {
      AppLogger.error('💥 Error during error analysis: $analysisError');
    }
  }

  /// ENHANCED DATABASE TRANSACTION: Rollback saved items in case of failure
  Future<void> _rollbackSavedItems(List<String> savedItemIds, String batchId) async {
    if (savedItemIds.isEmpty) return;

    try {
      AppLogger.warning('🔄 بدء التراجع - حذف ${savedItemIds.length} عنصر محفوظ...');

      // Delete saved items
      for (final itemId in savedItemIds) {
        try {
          await _supabaseService.deleteRecord('packing_list_items', itemId);
          AppLogger.info('🗑️ تم حذف العنصر: $itemId');
        } catch (e) {
          AppLogger.error('❌ فشل في حذف العنصر $itemId: $e');
        }
      }

      // Delete the batch if it was created
      try {
        await _supabaseService.deleteRecord('import_batches', batchId);
        AppLogger.info('🗑️ تم حذف الدفعة: $batchId');
      } catch (e) {
        AppLogger.error('❌ فشل في حذف الدفعة $batchId: $e');
      }

      AppLogger.info('✅ تم التراجع بنجاح');

    } catch (e) {
      AppLogger.error('💥 خطأ في عملية التراجع: $e');
    }
  }

  /// معالجة ملف Excel للحاوية الجديدة
  Future<void> processContainerImportFile() async {
    if (_selectedFile == null) {
      _setError('لم يتم اختيار ملف');
      return;
    }

    try {
      _setProcessing(true);
      _setStatus('بدء معالجة ملف الحاوية...');
      _setProgress(0.0);
      _clearError();

      AppLogger.info('🚀 Starting container import processing for: ${_selectedFile!.name}');

      // Process the Excel file using the container import service
      final result = await ContainerImportExcelService.processExcelFile(
        filePath: _selectedFile!.path!,
        filename: _selectedFile!.name,
        onProgress: (progress) {
          _setProgress(progress);
        },
        onStatusUpdate: (status) {
          _setStatus(status);
        },
      );

      if (result.success) {
        _currentContainerBatch = result.batch;
        _currentContainerItems = result.items;
        _lastContainerImportResult = result;

        AppLogger.info('✅ Container import processing completed successfully');
        AppLogger.info('📊 Processed ${result.items.length} items from ${result.totalRows} rows');

        if (result.errors.isNotEmpty) {
          AppLogger.warning('⚠️ Processing completed with ${result.errors.length} errors');
        }

        if (result.warnings.isNotEmpty) {
          AppLogger.warning('⚠️ Processing completed with ${result.warnings.length} warnings');
        }

        _setStatus('تم إكمال معالجة الحاوية بنجاح');
        _setProgress(1.0);
      } else {
        throw Exception('فشل في معالجة ملف الحاوية: ${result.errors.join(', ')}');
      }

    } catch (e) {
      AppLogger.error('❌ Error processing container import file: $e');
      _setError('خطأ في معالجة ملف الحاوية: $e');
    } finally {
      _setProcessing(false);
    }
  }

  /// مسح بيانات استيراد الحاوية الحالية
  void clearContainerImportData() {
    _currentContainerBatch = null;
    _currentContainerItems.clear();
    _lastContainerImportResult = null;
    notifyListeners();
    AppLogger.info('🧹 Container import data cleared');
  }

  /// الحصول على إحصائيات استيراد الحاوية
  Map<String, dynamic> getContainerImportStatistics() {
    if (_currentContainerItems.isEmpty) {
      return {
        'totalItems': 0,
        'totalCartons': 0,
        'totalQuantity': 0,
        'uniqueProducts': 0,
        'itemsWithDiscrepancies': 0,
        'averagePiecesPerCarton': 0.0,
      };
    }

    final totalCartons = _currentContainerItems.fold(0, (sum, item) => sum + item.numberOfCartons);
    final totalQuantity = _currentContainerItems.fold(0, (sum, item) => sum + item.totalQuantity);
    final uniqueProducts = _currentContainerItems.map((item) => item.productName).toSet().length;
    final itemsWithDiscrepancies = _currentContainerItems.where((item) => !item.isQuantityConsistent).length;
    final averagePiecesPerCarton = totalCartons > 0 ? totalQuantity / totalCartons : 0.0;

    return {
      'totalItems': _currentContainerItems.length,
      'totalCartons': totalCartons,
      'totalQuantity': totalQuantity,
      'uniqueProducts': uniqueProducts,
      'itemsWithDiscrepancies': itemsWithDiscrepancies,
      'averagePiecesPerCarton': averagePiecesPerCarton,
    };
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
