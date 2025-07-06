import 'package:smartbiztracker_new/models/warehouse_reports_model.dart';
import 'package:smartbiztracker_new/models/warehouse_inventory_model.dart';
import 'package:smartbiztracker_new/models/warehouse_model.dart';
import 'package:smartbiztracker_new/models/product_model.dart';
import 'package:smartbiztracker_new/services/warehouse_service.dart';
import 'package:smartbiztracker_new/services/api_service.dart';
import 'package:smartbiztracker_new/services/api_product_sync_service.dart';
import 'package:smartbiztracker_new/services/warehouse_reports_cache_service.dart';
import 'package:smartbiztracker_new/services/warehouse_reports_error_handler.dart';
import 'package:smartbiztracker_new/utils/warehouse_reports_performance_validator.dart';
import 'package:smartbiztracker_new/utils/smart_product_matcher.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// خدمة تقارير المخازن المتقدمة
class WarehouseReportsService {
  final WarehouseService _warehouseService;
  final ApiService _apiService;

  // تخزين مؤقت لأسماء المخازن لتحسين الأداء
  Map<String, String>? _warehouseNamesCache;
  DateTime? _warehouseNamesCacheTime;
  final ApiProductSyncService _apiProductSyncService;

  // معرف مخزن المعرض
  static const String exhibitionWarehouseId = '2183e926-aaa3-4a99-bf1f-965b1618f8d1';

  WarehouseReportsService({
    WarehouseService? warehouseService,
    ApiService? apiService,
    ApiProductSyncService? apiProductSyncService,
  }) : _warehouseService = warehouseService ?? WarehouseService(),
        _apiService = apiService ?? ApiService(),
        _apiProductSyncService = apiProductSyncService ?? ApiProductSyncService();

  /// إنشاء تقرير تحليل المعرض مع التخزين المؤقت ومعالجة الأخطاء
  Future<ExhibitionAnalysisReport> generateExhibitionAnalysisReport() async {
    return await WarehouseReportsErrorHandler.executeWithRetry(
      () async {
        AppLogger.info('📊 بدء إنشاء تقرير تحليل المعرض مع التخزين المؤقت');

      // التحقق من وجود تقرير محفوظ في التخزين المؤقت
      final cachedReport = WarehouseReportsCacheService.getCachedReport<ExhibitionAnalysisReport>('exhibition_analysis');
      if (cachedReport != null) {
        AppLogger.info('⚡ استخدام تقرير تحليل المعرض من التخزين المؤقت');
        return cachedReport;
      }

      // تحميل منتجات المعرض وفلترة المنتجات ذات المخزون الصفري
      final allExhibitionInventory = await _warehouseService.getWarehouseInventory(exhibitionWarehouseId);
      final exhibitionInventory = allExhibitionInventory.where((item) => item.quantity > 0).toList();
      AppLogger.info('📦 تم تحميل ${exhibitionInventory.length} منتج من المعرض (بعد استبعاد المخزون الصفري)');
      AppLogger.info('📦 إجمالي منتجات المعرض (قبل الفلترة): ${allExhibitionInventory.length}');

      // تحميل جميع منتجات API مع التخزين المؤقت وفلترة المنتجات غير النشطة
      final activeApiProducts = await _loadAllApiProductsWithCache();
      AppLogger.info('🌐 تم تحميل ${activeApiProducts.length} منتج نشط من API');

      // طباعة عينة من معرفات المنتجات للتشخيص
      if (exhibitionInventory.isNotEmpty) {
        AppLogger.info('🔍 عينة من معرفات منتجات المعرض: ${exhibitionInventory.take(5).map((e) => e.productId).join(', ')}');
      }
      if (activeApiProducts.isNotEmpty) {
        AppLogger.info('🔍 عينة من معرفات منتجات API: ${activeApiProducts.take(5).map((e) => e.id).join(', ')}');
      }

      // العثور على المنتجات المفقودة من المعرض (فقط المنتجات النشطة)
      final missingProducts = SmartProductMatcher.findMissingFromExhibition(
        apiProducts: activeApiProducts,
        exhibitionInventory: exhibitionInventory,
        minimumMatchScore: 0.7,
      );

      // الحصول على معلومات المعرض
      final warehouses = await _warehouseService.getWarehouses();
      final exhibitionWarehouse = warehouses.firstWhere(
        (w) => w.id == exhibitionWarehouseId,
        orElse: () => WarehouseModel(
          id: exhibitionWarehouseId,
          name: 'المعرض',
          address: '',
          isActive: true,
          createdAt: DateTime.now(),
          createdBy: '',
        ),
      );

      final report = ExhibitionAnalysisReport(
        exhibitionProducts: exhibitionInventory,
        missingProducts: missingProducts,
        allApiProducts: activeApiProducts,
        generatedAt: DateTime.now(),
        exhibitionWarehouseId: exhibitionWarehouseId,
        exhibitionWarehouseName: exhibitionWarehouse.name,
      );

      // حفظ التقرير في التخزين المؤقت
      await WarehouseReportsCacheService.cacheReport('exhibition_analysis', report);

        AppLogger.info('✅ تم إنشاء تقرير تحليل المعرض بنجاح وحفظه في التخزين المؤقت');
        return report;
      },
      'تحليل المعرض',
      shouldRetry: WarehouseReportsErrorHandler.isRetryableError,
    );
  }

  /// إنشاء تقرير تغطية المخزون الذكي (محسن للأداء مع التخزين المؤقت ومعالجة الأخطاء)
  Future<InventoryCoverageReport> generateInventoryCoverageReport() async {
    return await WarehouseReportsErrorHandler.executeWithRetry(
      () async {
        AppLogger.info('📊 بدء إنشاء تقرير تغطية المخزون الذكي المحسن مع التخزين المؤقت');

      // التحقق من وجود تقرير محفوظ في التخزين المؤقت
      final cachedReport = WarehouseReportsCacheService.getCachedReport<InventoryCoverageReport>('inventory_coverage');
      if (cachedReport != null) {
        AppLogger.info('⚡ استخدام تقرير تغطية المخزون من التخزين المؤقت');
        return cachedReport;
      }

      // تنظيف التخزين المؤقت المنتهي الصلاحية
      WarehouseReportsCacheService.cleanupExpired();

      // تحميل جميع المخازن النشطة فقط
      final allWarehouses = await _warehouseService.getWarehouses();
      final warehouses = allWarehouses.where((warehouse) => warehouse.isActive).toList();
      AppLogger.info('🏢 تم تحميل ${warehouses.length} مخزن نشط');

      // تحميل جميع منتجات API النشطة مع التخزين المؤقت
      final apiProducts = await _loadAllApiProductsWithCache();
      AppLogger.info('🌐 تم تحميل ${apiProducts.length} منتج نشط من API');

      // تحسين الأداء الحرج: تحميل جميع مخزونات المخازن مرة واحدة مع التخزين المؤقت
      AppLogger.info('🚀 تحميل جميع مخزونات المخازن مرة واحدة مع التخزين المؤقت...');
      final allWarehouseInventories = await _preloadAllWarehouseInventoriesWithCache(warehouses);
      AppLogger.info('✅ تم تحميل مخزونات ${allWarehouseInventories.length} مخزن مسبقاً');

      // تحليل تغطية كل منتج باستخدام البيانات المحملة مسبقاً
      AppLogger.info('🚀 بدء المعالجة المحسنة لـ ${apiProducts.length} منتج');

      // تقسيم المنتجات إلى مجموعات أكبر للمعالجة المحسنة
      const batchSize = 50; // زيادة حجم المجموعة لتحسين الأداء
      final productAnalyses = <ProductCoverageAnalysis>[];
      final totalBatches = (apiProducts.length / batchSize).ceil();

      for (int i = 0; i < apiProducts.length; i += batchSize) {
        final endIndex = (i + batchSize < apiProducts.length) ? i + batchSize : apiProducts.length;
        final batch = apiProducts.sublist(i, endIndex);
        final currentBatch = (i ~/ batchSize) + 1;

        AppLogger.info('📦 معالجة المجموعة $currentBatch/$totalBatches: منتجات ${i + 1}-$endIndex');

        // معالجة المجموعة بشكل متوازي باستخدام البيانات المحملة مسبقاً
        final batchAnalyses = await Future.wait(
          batch.map((apiProduct) => _analyzeProductCoverageOptimized(apiProduct, allWarehouseInventories)),
        );

        productAnalyses.addAll(batchAnalyses);

        // تسجيل التقدم
        final progress = (currentBatch / totalBatches * 0.8) + 0.1; // 10% للتحميل، 80% للمعالجة، 10% للإنهاء
        AppLogger.info('📊 تقدم المعالجة: ${(progress * 100).toInt()}% (${productAnalyses.length}/${apiProducts.length} منتج)');

        // تقليل التأخير بين المجموعات
        if (i + batchSize < apiProducts.length) {
          await Future.delayed(const Duration(milliseconds: 5));
        }
      }

      AppLogger.info('✅ انتهت المعالجة المحسنة لجميع المنتجات في ${totalBatches} مجموعة');

      // حساب الإحصائيات العامة
      final globalStatistics = _calculateGlobalStatistics(productAnalyses, warehouses);

      final report = InventoryCoverageReport(
        productAnalyses: productAnalyses,
        warehouses: warehouses,
        totalApiProducts: apiProducts.length,
        generatedAt: DateTime.now(),
        globalStatistics: globalStatistics,
      );

      // حفظ التقرير في التخزين المؤقت
      await WarehouseReportsCacheService.cacheReport('inventory_coverage', report);

        AppLogger.info('✅ تم إنشاء تقرير تغطية المخزون بنجاح وحفظه في التخزين المؤقت');
        return report;
      },
      'تغطية المخزون',
      shouldRetry: WarehouseReportsErrorHandler.isRetryableError,
    );
  }

  /// تحميل جميع منتجات API مع التخزين المؤقت
  Future<List<ApiProductModel>> _loadAllApiProductsWithCache() async {
    // التحقق من التخزين المؤقت أولاً
    final cachedProducts = WarehouseReportsCacheService.getCachedApiProducts();
    if (cachedProducts != null) {
      return cachedProducts.where((product) => product.isActive).toList();
    }

    // تحميل من المصدر وحفظ في التخزين المؤقت
    final allProducts = await _loadAllApiProducts();
    await WarehouseReportsCacheService.cacheApiProducts(allProducts);

    return allProducts.where((product) => product.isActive).toList();
  }

  /// تحميل جميع مخزونات المخازن مرة واحدة مع التخزين المؤقت
  Future<Map<String, List<WarehouseInventoryModel>>> _preloadAllWarehouseInventoriesWithCache(
    List<WarehouseModel> warehouses,
  ) async {
    final allInventories = <String, List<WarehouseInventoryModel>>{};

    // تحميل أسماء المخازن مع التخزين المؤقت
    final warehouseNamesMap = await _getCachedWarehouseNamesWithCache();

    // التحقق من التخزين المؤقت لكل مخزن
    final warehousesToLoad = <WarehouseModel>[];

    for (final warehouse in warehouses) {
      final cachedInventory = WarehouseReportsCacheService.getCachedWarehouseInventory(warehouse.id);
      if (cachedInventory != null) {
        allInventories[warehouse.id] = cachedInventory;
      } else {
        warehousesToLoad.add(warehouse);
      }
    }

    AppLogger.info('⚡ تم استرداد ${allInventories.length} مخزون من التخزين المؤقت، يحتاج تحميل ${warehousesToLoad.length} مخزن');

    // تحميل المخازن المتبقية
    if (warehousesToLoad.isNotEmpty) {
      final newInventories = await _preloadAllWarehouseInventories(warehousesToLoad, warehouseNamesMap);
      allInventories.addAll(newInventories);

      // حفظ في التخزين المؤقت
      await WarehouseReportsCacheService.cacheWarehouseInventories(newInventories);
    }

    return allInventories;
  }

  /// تحميل جميع مخزونات المخازن مرة واحدة لتحسين الأداء (الطريقة الأساسية)
  Future<Map<String, List<WarehouseInventoryModel>>> _preloadAllWarehouseInventories(
    List<WarehouseModel> warehouses, [
    Map<String, String>? warehouseNamesMap,
  ]) async {
    final allInventories = <String, List<WarehouseInventoryModel>>{};

    // تحميل أسماء المخازن مسبقاً (استخدام المعطى أو التحميل مع التخزين المؤقت)
    final effectiveWarehouseNamesMap = warehouseNamesMap ?? await _getCachedWarehouseNamesWithCache();

    // تحميل مخزونات جميع المخازن بشكل متوازي
    final inventoryResults = await Future.wait(
      warehouses.map((warehouse) async {
        try {
          AppLogger.info('📦 تحميل مخزون المخزن: ${warehouse.name}');
          final inventory = await _warehouseService.getWarehouseInventory(warehouse.id);

          // إضافة أسماء المخازن للمخزون
          final warehouseName = effectiveWarehouseNamesMap[warehouse.id] ?? warehouse.name;
          final enhancedInventory = inventory.map((item) =>
              item.copyWith(warehouseName: warehouseName)).toList();

          return MapEntry(warehouse.id, enhancedInventory);
        } catch (e) {
          AppLogger.warning('⚠️ خطأ في تحميل مخزون المخزن ${warehouse.name}: $e');
          return MapEntry(warehouse.id, <WarehouseInventoryModel>[]);
        }
      }),
    );

    // تجميع النتائج
    for (final entry in inventoryResults) {
      allInventories[entry.key] = entry.value;
    }

    final totalItems = allInventories.values.fold(0, (sum, inventory) => sum + inventory.length);
    AppLogger.info('✅ تم تحميل $totalItems عنصر مخزون من ${warehouses.length} مخزن');

    return allInventories;
  }

  /// فحص ما إذا كان منتج API له كمية صفر (حالة استثنائية)
  bool _isZeroApiQuantityProduct(ApiProductModel apiProduct) {
    return apiProduct.quantity <= 0;
  }

  /// إنشاء تحليل للمنتجات الاستثنائية باستخدام البيانات المحملة مسبقاً (محسن)
  ProductCoverageAnalysis _createExceptionAnalysisOptimized(
    ApiProductModel apiProduct,
    Map<String, List<WarehouseInventoryModel>> allWarehouseInventories,
  ) {
    try {
      // البحث عن أي مخزون موجود في المخازن لهذا المنتج
      final warehouseInventories = <WarehouseInventoryModel>[];

      for (final entry in allWarehouseInventories.entries) {
        final inventory = entry.value;

        // استخدام المطابقة الذكية للعثور على المنتج
        final matches = SmartProductMatcher.matchProducts(
          apiProducts: [apiProduct],
          warehouseInventory: inventory,
          minimumMatchScore: 0.7,
        );

        // إضافة المطابقات الناجحة فقط
        for (final match in matches) {
          if (match.warehouseProduct != null &&
              match.isMatched &&
              _validateProductMatch(apiProduct, match.warehouseProduct!, match.matchScore)) {
            warehouseInventories.add(match.warehouseProduct!);
          }
        }
      }

      final totalWarehouseQuantity = warehouseInventories.fold(0, (sum, inventory) => sum + inventory.quantity);

      // إنشاء توصيات خاصة للحالة الاستثنائية
      final recommendations = <String>[
        'المنتج غير متوفر في API (كمية = 0)',
        'التحقق من حالة المنتج في النظام الخارجي',
        'قد يكون المنتج متوقف أو غير متوفر مؤقتاً',
      ];

      if (totalWarehouseQuantity > 0) {
        recommendations.addAll([
          'يوجد مخزون في المخازن: $totalWarehouseQuantity قطعة',
          'النظر في تحديث بيانات API أو مراجعة المخزون',
          'قد تحتاج لإزالة المخزون أو تحديث API',
        ]);
      } else {
        recommendations.add('لا يوجد مخزون في المخازن - حالة متسقة');
      }

      return ProductCoverageAnalysis(
        apiProduct: apiProduct,
        warehouseInventories: warehouseInventories,
        totalWarehouseQuantity: totalWarehouseQuantity,
        coveragePercentage: -1.0, // قيمة خاصة للحالة الاستثنائية
        status: CoverageStatus.exception,
        recommendations: recommendations,
      );
    } catch (e) {
      AppLogger.warning('⚠️ خطأ في تحليل الحالة الاستثنائية للمنتج ${apiProduct.id}: $e');
      return ProductCoverageAnalysis(
        apiProduct: apiProduct,
        warehouseInventories: [],
        totalWarehouseQuantity: 0,
        coveragePercentage: -1.0,
        status: CoverageStatus.exception,
        recommendations: ['خطأ في تحليل البيانات'],
      );
    }
  }

  /// إنشاء تحليل للمنتجات الاستثنائية (API بكمية صفر) - الطريقة القديمة
  Future<ProductCoverageAnalysis> _createExceptionAnalysis(
    ApiProductModel apiProduct,
    List<WarehouseModel> warehouses,
  ) async {
    try {
      // البحث عن أي مخزون موجود في المخازن لهذا المنتج (رغم أن API كميته صفر)
      final warehouseInventories = await _findProductInAllWarehouses(apiProduct, warehouses);
      final totalWarehouseQuantity = warehouseInventories.fold(0, (sum, inventory) => sum + inventory.quantity);

      // إنشاء توصيات خاصة للحالة الاستثنائية
      final recommendations = <String>[
        'المنتج غير متوفر في API (كمية = 0)',
        'التحقق من حالة المنتج في النظام الخارجي',
        'قد يكون المنتج متوقف أو غير متوفر مؤقتاً',
      ];

      if (totalWarehouseQuantity > 0) {
        recommendations.addAll([
          'يوجد مخزون في المخازن: $totalWarehouseQuantity قطعة',
          'النظر في تحديث بيانات API أو مراجعة المخزون',
          'قد تحتاج لإزالة المخزون أو تحديث API',
        ]);
      } else {
        recommendations.add('لا يوجد مخزون في المخازن - حالة متسقة');
      }

      AppLogger.info('🔶 تحليل استثنائي: API[${apiProduct.id}] - كمية API: 0, كمية المخازن: $totalWarehouseQuantity');

      return ProductCoverageAnalysis(
        apiProduct: apiProduct,
        warehouseInventories: warehouseInventories,
        totalWarehouseQuantity: totalWarehouseQuantity,
        coveragePercentage: -1.0, // قيمة خاصة للحالة الاستثنائية
        status: CoverageStatus.exception,
        recommendations: recommendations,
      );
    } catch (e) {
      AppLogger.error('❌ خطأ في إنشاء التحليل الاستثنائي للمنتج ${apiProduct.id}: $e');

      return ProductCoverageAnalysis(
        apiProduct: apiProduct,
        warehouseInventories: [],
        totalWarehouseQuantity: 0,
        coveragePercentage: -1.0,
        status: CoverageStatus.exception,
        recommendations: ['خطأ في تحليل المنتج الاستثنائي'],
      );
    }
  }

  /// تحليل تغطية منتج واحد باستخدام البيانات المحملة مسبقاً (محسن للأداء)
  Future<ProductCoverageAnalysis> _analyzeProductCoverageOptimized(
    ApiProductModel apiProduct,
    Map<String, List<WarehouseInventoryModel>> allWarehouseInventories,
  ) async {
    try {
      // فحص الحالة الاستثنائية - منتج API بكمية صفر
      if (_isZeroApiQuantityProduct(apiProduct)) {
        return _createExceptionAnalysisOptimized(apiProduct, allWarehouseInventories);
      }

      // البحث في جميع المخزونات المحملة مسبقاً
      final warehouseInventories = <WarehouseInventoryModel>[];

      for (final entry in allWarehouseInventories.entries) {
        final warehouseId = entry.key;
        final inventory = entry.value;

        // استخدام المطابقة الذكية للعثور على المنتج
        final matches = SmartProductMatcher.matchProducts(
          apiProducts: [apiProduct],
          warehouseInventory: inventory,
          minimumMatchScore: 0.7,
        );

        // إضافة المطابقات الناجحة فقط
        for (final match in matches) {
          if (match.warehouseProduct != null &&
              match.isMatched &&
              match.warehouseProduct!.quantity > 0 &&
              _validateProductMatch(apiProduct, match.warehouseProduct!, match.matchScore)) {
            warehouseInventories.add(match.warehouseProduct!);
          }
        }
      }

      // حساب إجمالي الكمية
      final totalQuantity = warehouseInventories.fold(0, (sum, inventory) => sum + inventory.quantity);
      final finalTotalQuantity = _validateAndCorrectTotalQuantity(apiProduct, warehouseInventories, totalQuantity);

      // حساب نسبة التغطية وتحديد الحالة
      final coveragePercentage = _calculateCorrectCoveragePercentage(finalTotalQuantity, apiProduct);
      final status = _determineCoverageStatus(coveragePercentage);
      final recommendations = _generateRecommendations(apiProduct, warehouseInventories, status, finalTotalQuantity);

      return ProductCoverageAnalysis(
        apiProduct: apiProduct,
        warehouseInventories: warehouseInventories,
        totalWarehouseQuantity: finalTotalQuantity,
        coveragePercentage: coveragePercentage,
        status: status,
        recommendations: recommendations,
      );
    } catch (e) {
      AppLogger.warning('⚠️ خطأ في تحليل تغطية المنتج ${apiProduct.id}: $e');
      return ProductCoverageAnalysis(
        apiProduct: apiProduct,
        warehouseInventories: [],
        totalWarehouseQuantity: 0,
        coveragePercentage: 0.0,
        status: CoverageStatus.missing,
        recommendations: ['خطأ في تحليل البيانات'],
      );
    }
  }

  /// تحليل تغطية منتج واحد عبر جميع المخازن (الطريقة القديمة)
  Future<ProductCoverageAnalysis> _analyzeProductCoverage(
    ApiProductModel apiProduct,
    List<WarehouseModel> warehouses,
  ) async {
    try {
      AppLogger.info('🔍 تحليل تغطية المنتج: ${apiProduct.id} - ${apiProduct.name}');

      // فحص الحالة الاستثنائية - منتج API بكمية صفر
      if (_isZeroApiQuantityProduct(apiProduct)) {
        AppLogger.warning('⚠️ منتج API بكمية صفر: ${apiProduct.id} - ${apiProduct.name}');
        return _createExceptionAnalysis(apiProduct, warehouses);
      }

      // استخدام المطابقة الذكية للعثور على المنتج في جميع المخازن
      final allWarehouseInventories = await _findProductInAllWarehouses(apiProduct, warehouses);

      // فلترة المخزون لاستبعاد الكميات الصفرية والتحقق من صحة البيانات
      final warehouseInventories = allWarehouseInventories
          .where((inventory) => inventory.quantity > 0)
          .where((inventory) => inventory.productId != null && inventory.productId.toString().isNotEmpty)
          .toList();

      // حساب إجمالي الكمية (فقط المخزون غير الصفري والصحيح)
      final totalQuantity = warehouseInventories.fold(0, (sum, inventory) => sum + inventory.quantity);

      // التحقق النهائي من عدم وجود كميات وهمية
      final finalTotalQuantity = _validateAndCorrectTotalQuantity(apiProduct, warehouseInventories, totalQuantity);

      // حساب نسبة التغطية الصحيحة (مقارنة مع كمية API)
      final coveragePercentage = _calculateCorrectCoveragePercentage(finalTotalQuantity, apiProduct);

      // تحديد حالة التغطية المحدثة
      final status = _determineCoverageStatus(coveragePercentage);

      // إنشاء التوصيات المحدثة
      final recommendations = _generateRecommendations(apiProduct, warehouseInventories, status, finalTotalQuantity);

      AppLogger.info('📊 نتيجة التحليل: API[${apiProduct.id}] - كمية API: ${apiProduct.quantity}, إجمالي المخازن: $finalTotalQuantity, التغطية: ${coveragePercentage.toStringAsFixed(1)}%');

      // تحسين بيانات المخزون بأسماء المخازن
      final enhancedInventories = await _enhanceInventoryWithWarehouseNames(warehouseInventories);

      return ProductCoverageAnalysis(
        apiProduct: apiProduct,
        warehouseInventories: enhancedInventories,
        totalWarehouseQuantity: finalTotalQuantity,
        coveragePercentage: coveragePercentage,
        status: status,
        recommendations: recommendations,
      );
    } catch (e) {
      AppLogger.warning('⚠️ خطأ في تحليل تغطية المنتج ${apiProduct.id}: $e');

      // إرجاع تحليل فارغ في حالة الخطأ
      return ProductCoverageAnalysis(
        apiProduct: apiProduct,
        warehouseInventories: [],
        totalWarehouseQuantity: 0,
        coveragePercentage: 0.0,
        status: CoverageStatus.missing,
        recommendations: ['خطأ في تحليل البيانات'],
      );
    }
  }

  /// التحقق من صحة إجمالي الكمية وتصحيح الكميات الوهمية
  int _validateAndCorrectTotalQuantity(
    ApiProductModel apiProduct,
    List<WarehouseInventoryModel> warehouseInventories,
    int calculatedTotal,
  ) {
    // إذا لم يكن هناك مخزون صحيح، يجب أن تكون الكمية صفر
    if (warehouseInventories.isEmpty) {
      if (calculatedTotal > 0) {
        AppLogger.warning('⚠️ تم اكتشاف كمية وهمية للمنتج ${apiProduct.id}: $calculatedTotal (لا يوجد مخزون صحيح)');
        return 0;
      }
      return 0;
    }

    // إعادة حساب الكمية من المخزون الصحيح فقط
    final recalculatedTotal = warehouseInventories
        .where((inventory) => inventory.quantity > 0)
        .fold(0, (sum, inventory) => sum + inventory.quantity);

    // التحقق من التطابق
    if (calculatedTotal != recalculatedTotal) {
      AppLogger.warning('⚠️ عدم تطابق في حساب الكمية للمنتج ${apiProduct.id}: محسوبة=$calculatedTotal, معاد حسابها=$recalculatedTotal');
      AppLogger.info('🔧 تم تصحيح الكمية للمنتج ${apiProduct.id}: $calculatedTotal -> $recalculatedTotal');
      return recalculatedTotal;
    }

    // التحقق من منطقية الكمية
    if (recalculatedTotal < 0) {
      AppLogger.warning('⚠️ كمية سالبة غير منطقية للمنتج ${apiProduct.id}: $recalculatedTotal');
      return 0;
    }

    AppLogger.info('✅ تم التحقق من صحة الكمية للمنتج ${apiProduct.id}: $recalculatedTotal');
    return recalculatedTotal;
  }

  /// التحقق من صحة المطابقة ومنع الكميات الوهمية
  bool _validateProductMatch(
    ApiProductModel apiProduct,
    WarehouseInventoryModel warehouseProduct,
    double matchScore,
  ) {
    // التحقق من صحة المعرفات
    if (warehouseProduct.productId == null || warehouseProduct.productId.toString().isEmpty) {
      AppLogger.warning('⚠️ معرف منتج المخزن فارغ أو null للمنتج ${apiProduct.id}');
      return false;
    }

    // التحقق من صحة الكمية
    if (warehouseProduct.quantity <= 0) {
      AppLogger.info('ℹ️ كمية المنتج صفر أو سالبة: ${warehouseProduct.productId} (${warehouseProduct.quantity})');
      return false;
    }

    // التحقق من نتيجة المطابقة
    if (matchScore < 0.7) {
      AppLogger.info('ℹ️ نتيجة مطابقة ضعيفة: API[${apiProduct.id}] -> Warehouse[${warehouseProduct.productId}] (${matchScore.toStringAsFixed(3)})');
      return false;
    }

    // التحقق من صحة بيانات المنتج
    if (warehouseProduct.warehouseId == null || warehouseProduct.warehouseId.isEmpty) {
      AppLogger.warning('⚠️ معرف المخزن فارغ أو null للمنتج ${warehouseProduct.productId}');
      return false;
    }

    return true;
  }

  /// العثور على منتج في جميع المخازن باستخدام المطابقة الذكية (محسن للأداء)
  Future<List<WarehouseInventoryModel>> _findProductInAllWarehouses(
    ApiProductModel apiProduct,
    List<WarehouseModel> warehouses,
  ) async {
    AppLogger.info('🔍 البحث عن المنتج ${apiProduct.id} في ${warehouses.length} مخزن');

    final allInventories = <WarehouseInventoryModel>[];

    // تحميل أسماء المخازن مسبقاً للأداء المحسن
    final warehouseNamesMap = await _getCachedWarehouseNames();

    // معالجة المخازن بشكل متوازي لتحسين الأداء
    final warehouseResults = await Future.wait(
      warehouses.map((warehouse) async {
        try {
          // تحميل مخزون المخزن مع أسماء المخازن
          final warehouseInventory = await _warehouseService.getWarehouseInventoryWithNames(warehouse.id);

          // استخدام المطابقة الذكية للعثور على المنتج
          final matches = SmartProductMatcher.matchProducts(
            apiProducts: [apiProduct],
            warehouseInventory: warehouseInventory,
            minimumMatchScore: 0.7,
          );

          final warehouseMatches = <WarehouseInventoryModel>[];

          // إضافة المطابقات الناجحة فقط (مع التحقق الشامل من صحة المطابقة)
          for (final match in matches) {
            if (match.warehouseProduct != null &&
                match.isMatched &&
                _validateProductMatch(apiProduct, match.warehouseProduct!, match.matchScore)) {
              // التأكد من إضافة اسم المخزن باستخدام التخزين المؤقت المحسن
              final warehouseName = match.warehouseProduct!.warehouseName ??
                                   warehouseNamesMap[warehouse.id] ??
                                   warehouse.name;
              final enhancedProduct = match.warehouseProduct!.warehouseName != null
                  ? match.warehouseProduct!
                  : match.warehouseProduct!.copyWith(warehouseName: warehouseName);

              warehouseMatches.add(enhancedProduct);
              AppLogger.info('✅ تم العثور على المنتج ${apiProduct.id} في المخزن ${warehouse.name}: ${match.warehouseProduct!.quantity} قطعة (نتيجة المطابقة: ${match.matchScore.toStringAsFixed(3)})');
            } else if (match.warehouseProduct != null) {
              AppLogger.info('🚫 رفض مطابقة غير صحيحة: API[${apiProduct.id}] -> Warehouse[${match.warehouseProduct!.productId}], النتيجة: ${match.matchScore.toStringAsFixed(3)}, الكمية: ${match.warehouseProduct!.quantity}');
            }
          }

          return warehouseMatches;
        } catch (e) {
          AppLogger.warning('⚠️ خطأ في البحث عن المنتج ${apiProduct.id} في المخزن ${warehouse.name}: $e');
          // في حالة الخطأ، استخدم الطريقة التقليدية مع إضافة اسم المخزن من التخزين المؤقت
          try {
            final fallbackInventory = await _warehouseService.getWarehouseInventory(warehouse.id);
            final warehouseName = warehouseNamesMap[warehouse.id] ?? warehouse.name;
            final enhancedInventory = fallbackInventory.map((item) =>
                item.copyWith(warehouseName: warehouseName)).toList();

            final fallbackMatches = SmartProductMatcher.matchProducts(
              apiProducts: [apiProduct],
              warehouseInventory: enhancedInventory,
              minimumMatchScore: 0.7,
            );

            return fallbackMatches
                .where((match) => match.warehouseProduct != null && match.isMatched)
                .map((match) => match.warehouseProduct!)
                .toList();
          } catch (fallbackError) {
            AppLogger.error('❌ فشل في الطريقة الاحتياطية للمخزن ${warehouse.name}: $fallbackError');
            return <WarehouseInventoryModel>[];
          }
        }
      }),
    );

    // دمج النتائج من جميع المخازن
    for (final warehouseMatches in warehouseResults) {
      allInventories.addAll(warehouseMatches);
    }

    return allInventories;
  }

  /// حساب نسبة التغطية الصحيحة (مقارنة مع كمية API)
  double _calculateCorrectCoveragePercentage(int totalWarehouseQuantity, ApiProductModel apiProduct) {
    // الحصول على كمية API (من حقل quantity أو stockQuantity)
    final apiQuantity = apiProduct.quantity;

    // معالجة الحالات الاستثنائية - منتجات API بكمية صفر
    if (apiQuantity <= 0) {
      AppLogger.warning('⚠️ منتج API بكمية صفر: ${apiProduct.id} - ${apiProduct.name} (كمية API: $apiQuantity)');
      // إرجاع قيمة خاصة للإشارة إلى حالة استثنائية
      return -1.0; // قيمة خاصة تشير إلى حالة استثنائية
    }

    if (totalWarehouseQuantity <= 0) {
      // إذا لم يكن هناك مخزون في المخازن
      return 0.0;
    }

    // حساب النسبة: (إجمالي كمية المخازن ÷ كمية API) × 100
    final percentage = (totalWarehouseQuantity / apiQuantity) * 100;

    // تحديد الحد الأقصى عند 100% (لا نعرض أكثر من 100% حتى لو كان المخزون أكبر)
    final cappedPercentage = percentage.clamp(0.0, 100.0);

    AppLogger.info('📊 حساب التغطية: API[${apiProduct.id}] - كمية API: $apiQuantity, كمية المخازن: $totalWarehouseQuantity, النسبة: ${cappedPercentage.toStringAsFixed(1)}%');

    return cappedPercentage;
  }

  /// تحديد حالة التغطية المحدثة
  CoverageStatus _determineCoverageStatus(double coveragePercentage) {
    // حالة استثنائية - منتج API بكمية صفر
    if (coveragePercentage == -1.0) return CoverageStatus.exception;

    if (coveragePercentage == 0) return CoverageStatus.missing;
    if (coveragePercentage >= 100) return CoverageStatus.excellent; // Full Coverage (100%)
    if (coveragePercentage >= 80) return CoverageStatus.good;        // Good Coverage (80-99%)
    if (coveragePercentage >= 50) return CoverageStatus.moderate;    // Partial Coverage (50-79%)
    if (coveragePercentage >= 1) return CoverageStatus.low;          // Low Coverage (1-49%)
    return CoverageStatus.critical;                                  // Critical/Missing (0%)
  }

  /// إنشاء التوصيات الذكية المحدثة
  List<String> _generateRecommendations(
    ApiProductModel apiProduct,
    List<WarehouseInventoryModel> inventories,
    CoverageStatus status,
    int totalWarehouseQuantity,
  ) {
    final recommendations = <String>[];
    final apiQuantity = apiProduct.quantity;
    final difference = totalWarehouseQuantity - apiQuantity;
    
    // إضافة معلومات الكمية والفرق
    if (apiQuantity > 0) {
      if (difference > 0) {
        recommendations.add('فائض في المخزون: ${difference} قطعة إضافية');
      } else if (difference < 0) {
        recommendations.add('نقص في المخزون: ${difference.abs()} قطعة مطلوبة');
      } else {
        recommendations.add('المخزون مطابق تماماً لكمية API');
      }
    }

    switch (status) {
      case CoverageStatus.exception:
        recommendations.add('المنتج غير متوفر في API (كمية = 0)');
        recommendations.add('التحقق من حالة المنتج في النظام الخارجي');
        recommendations.add('قد يكون المنتج متوقف أو غير متوفر مؤقتاً');
        if (totalWarehouseQuantity > 0) {
          recommendations.add('يوجد مخزون في المخازن: $totalWarehouseQuantity قطعة');
          recommendations.add('النظر في تحديث بيانات API أو إزالة المخزون');
        }
        break;

      case CoverageStatus.missing:
        recommendations.add('إضافة هذا المنتج إلى المخازن');
        recommendations.add('التحقق من توفر المنتج لدى الموردين');
        if (apiQuantity > 0) {
          recommendations.add('الكمية المطلوبة: $apiQuantity قطعة');
        }
        break;

      case CoverageStatus.critical:
        recommendations.add('زيادة المخزون بشكل عاجل');
        recommendations.add('مراجعة استراتيجية التوريد');
        if (difference < 0) {
          recommendations.add('إضافة ${difference.abs()} قطعة على الأقل');
        }
        break;

      case CoverageStatus.low:
        recommendations.add('زيادة المخزون تدريجياً');
        recommendations.add('مراقبة معدل الاستهلاك');
        if (difference < 0) {
          recommendations.add('النقص الحالي: ${difference.abs()} قطعة');
        }
        break;

      case CoverageStatus.moderate:
        recommendations.add('مراقبة مستوى المخزون');
        recommendations.add('التخطيط للتجديد');
        if (difference < 0) {
          recommendations.add('تحسين المخزون بإضافة ${difference.abs()} قطعة');
        }
        break;

      case CoverageStatus.good:
        recommendations.add('الحفاظ على المستوى الحالي');
        if (difference < 0) {
          recommendations.add('إضافة ${difference.abs()} قطعة للوصول للتغطية الكاملة');
        }
        break;

      case CoverageStatus.excellent:
        recommendations.add('تغطية كاملة - مستوى ممتاز');
        if (difference > 0) {
          recommendations.add('فائض آمن: ${difference} قطعة إضافية');
        }
        if (inventories.length == 1) {
          recommendations.add('النظر في توزيع المخزون على مخازن متعددة');
        }
        break;
    }
    
    // توصيات إضافية بناءً على التوزيع
    if (inventories.length > 1) {
      final quantities = inventories.map((i) => i.quantity).toList();
      final maxQuantity = quantities.reduce((a, b) => a > b ? a : b);
      final minQuantity = quantities.reduce((a, b) => a < b ? a : b);
      
      if (maxQuantity > minQuantity * 3) {
        recommendations.add('إعادة توزيع المخزون بين المخازن');
      }
    }
    
    return recommendations;
  }

  /// حساب الإحصائيات العامة
  Map<String, dynamic> _calculateGlobalStatistics(
    List<ProductCoverageAnalysis> analyses,
    List<WarehouseModel> warehouses,
  ) {
    final totalProducts = analyses.length;

    // فصل المنتجات العادية عن الاستثنائية
    final normalAnalyses = analyses.where((a) => a.status != CoverageStatus.exception).toList();
    final exceptionAnalyses = analyses.where((a) => a.status == CoverageStatus.exception).toList();

    final totalQuantity = analyses.fold(0, (sum, analysis) => sum + analysis.totalWarehouseQuantity);

    // حساب متوسط التغطية للمنتجات العادية فقط (استبعاد الاستثنائية)
    final averageCoverage = normalAnalyses.isEmpty ? 0.0 :
        normalAnalyses.fold(0.0, (sum, analysis) => sum + analysis.coveragePercentage) / normalAnalyses.length;

    final statusDistribution = <String, int>{};
    for (final status in CoverageStatus.values) {
      statusDistribution[status.name] = analyses.where((a) => a.status == status).length;
    }

    return {
      'total_products': totalProducts,
      'normal_products': normalAnalyses.length,
      'exception_products': exceptionAnalyses.length,
      'total_quantity': totalQuantity,
      'average_coverage': averageCoverage,
      'total_warehouses': warehouses.length,
      'active_warehouses': warehouses.where((w) => w.isActive).length,
      'status_distribution': statusDistribution,
      'generated_at': DateTime.now().toIso8601String(),
    };
  }

  /// تحميل جميع منتجات API
  Future<List<ApiProductModel>> _loadAllApiProducts() async {
    try {
      AppLogger.info('🌐 تحميل منتجات من API الخارجي');
      
      // محاولة تحميل من API الرئيسي
      final products = await _apiService.getProducts();
      
      // تحويل إلى ApiProductModel
      final apiProducts = products.map((product) => ApiProductModel(
        id: product.id,
        name: product.name,
        description: product.description,
        price: product.price,
        category: product.category,
        imageUrl: product.imageUrl,
        sku: product.sku,
        isActive: product.isActive,
        quantity: product.quantity, // إضافة كمية المنتج من API
        metadata: product.metadata,
      )).toList();
      
      AppLogger.info('✅ تم تحميل ${apiProducts.length} منتج من API');
      return apiProducts;
    } catch (e) {
      AppLogger.warning('⚠️ فشل في تحميل منتجات API، استخدام بيانات تجريبية: $e');
      
      // إرجاع بيانات تجريبية في حالة فشل API
      return _generateSampleApiProducts();
    }
  }

  /// إنشاء بيانات تجريبية للمنتجات
  List<ApiProductModel> _generateSampleApiProducts() {
    return List.generate(50, (index) {
      final categories = ['إلكترونيات', 'ملابس', 'طعام', 'مشروبات', 'أدوات منزلية'];
      final category = categories[index % categories.length];

      // إنشاء كميات متنوعة للاختبار
      final quantities = [0, 10, 25, 50, 75, 100, 150, 200];
      final quantity = quantities[index % quantities.length];

      return ApiProductModel(
        id: (index + 1).toString(),
        name: 'منتج تجريبي ${index + 1}',
        description: 'وصف المنتج التجريبي رقم ${index + 1}',
        price: (index + 1) * 10.0,
        category: category,
        sku: 'DEMO-${index + 1}',
        isActive: true,
        quantity: quantity,
      );
    });
  }

  /// البحث في منتجات API
  Future<List<ApiProductModel>> searchApiProducts({
    String? query,
    String? category,
    double? minPrice,
    double? maxPrice,
  }) async {
    try {
      final allProducts = await _loadAllApiProducts();

      var filteredProducts = allProducts.where((product) {
        // فلترة بالاستعلام النصي
        if (query != null && query.isNotEmpty) {
          final searchQuery = query.toLowerCase();
          if (!product.name.toLowerCase().contains(searchQuery) &&
              !product.description.toLowerCase().contains(searchQuery) &&
              !(product.sku?.toLowerCase().contains(searchQuery) ?? false)) {
            return false;
          }
        }

        // فلترة بالفئة
        if (category != null && category.isNotEmpty && category != 'الكل') {
          if (product.category != category) return false;
        }

        // فلترة بالسعر
        if (minPrice != null && product.price < minPrice) return false;
        if (maxPrice != null && product.price > maxPrice) return false;

        return true;
      }).toList();

      return filteredProducts;
    } catch (e) {
      AppLogger.error('❌ خطأ في البحث في منتجات API: $e');
      return [];
    }
  }

  /// الحصول على فئات المنتجات من API
  Future<List<String>> getApiProductCategories() async {
    try {
      final products = await _loadAllApiProducts();
      final categories = products.map((p) => p.category).toSet().toList();
      categories.sort();
      return ['الكل', ...categories];
    } catch (e) {
      AppLogger.error('❌ خطأ في تحميل فئات المنتجات: $e');
      return ['الكل'];
    }
  }

  /// إحصائيات سريعة للتقارير
  Future<Map<String, dynamic>> getQuickReportStats() async {
    try {
      AppLogger.info('📊 تحميل الإحصائيات السريعة للتقارير');

      // تحميل البيانات الأساسية
      final allWarehouses = await _warehouseService.getWarehouses();
      final warehouses = allWarehouses.where((w) => w.isActive).toList();
      final allApiProducts = await _loadAllApiProducts();
      final apiProducts = allApiProducts.where((product) => product.isActive).toList();
      final allExhibitionInventory = await _warehouseService.getWarehouseInventory(exhibitionWarehouseId);
      final exhibitionInventory = allExhibitionInventory.where((item) => item.quantity > 0).toList();

      // حساب الإحصائيات (استبعاد المنتجات ذات المخزون الصفري)
      final totalWarehouses = allWarehouses.length;
      final activeWarehouses = warehouses.length;
      final totalApiProducts = apiProducts.length;
      final exhibitionProductsCount = exhibitionInventory.length;
      final exhibitionCoverage = totalApiProducts > 0 ?
          (exhibitionProductsCount / totalApiProducts * 100) : 0.0;

      // حساب إجمالي المخزون عبر جميع المخازن (استبعاد المخزون الصفري)
      int totalInventoryItems = 0;
      int totalQuantity = 0;

      for (final warehouse in warehouses) {
        try {
          final allInventory = await _warehouseService.getWarehouseInventory(warehouse.id);
          final nonZeroInventory = allInventory.where((item) => item.quantity > 0).toList();
          totalInventoryItems += nonZeroInventory.length;
          totalQuantity += nonZeroInventory.fold(0, (sum, item) => sum + item.quantity);
        } catch (e) {
          AppLogger.warning('⚠️ خطأ في تحميل مخزون المخزن ${warehouse.id}: $e');
        }
      }

      return {
        'total_warehouses': totalWarehouses,
        'active_warehouses': activeWarehouses,
        'total_api_products': totalApiProducts,
        'exhibition_products_count': exhibitionProductsCount,
        'exhibition_coverage_percentage': exhibitionCoverage,
        'total_inventory_items': totalInventoryItems,
        'total_quantity': totalQuantity,
        'last_updated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      AppLogger.error('❌ خطأ في تحميل الإحصائيات السريعة: $e');
      return {
        'error': e.toString(),
        'last_updated': DateTime.now().toIso8601String(),
      };
    }
  }

  /// التأكد من وجود أسماء المخازن في بيانات المخزون
  List<WarehouseInventoryModel> _ensureWarehouseNames(
    List<WarehouseInventoryModel> inventories,
    List<WarehouseModel> warehouses,
  ) {
    final warehouseMap = {for (var w in warehouses) w.id: w.name};

    return inventories.map((inventory) {
      if (inventory.warehouseName == null || inventory.warehouseName!.isEmpty) {
        final warehouseName = warehouseMap[inventory.warehouseId];
        if (warehouseName != null) {
          return inventory.copyWith(warehouseName: warehouseName);
        }
      }
      return inventory;
    }).toList();
  }

  /// الحصول على أسماء المخازن مع التخزين المؤقت المحسن
  Future<Map<String, String>> _getCachedWarehouseNamesWithCache() async {
    // التحقق من التخزين المؤقت أولاً
    final cachedNames = WarehouseReportsCacheService.getCachedWarehouseNames();
    if (cachedNames != null) {
      return cachedNames;
    }

    // تحميل من المصدر وحفظ في التخزين المؤقت
    final names = await _getCachedWarehouseNames();
    await WarehouseReportsCacheService.cacheWarehouseNames(names);

    return names;
  }

  /// الحصول على أسماء المخازن مع التخزين المؤقت للأداء (الطريقة الأساسية)
  Future<Map<String, String>> _getCachedWarehouseNames() async {
    try {
      // التحقق من صحة التخزين المؤقت (صالح لمدة 5 دقائق)
      final now = DateTime.now();
      if (_warehouseNamesCache != null &&
          _warehouseNamesCacheTime != null &&
          now.difference(_warehouseNamesCacheTime!).inMinutes < 5) {
        AppLogger.info('📋 استخدام أسماء المخازن من التخزين المؤقت');
        return _warehouseNamesCache!;
      }

      AppLogger.info('🔄 تحديث تخزين أسماء المخازن المؤقت');

      // تحميل أسماء المخازن من قاعدة البيانات
      final warehouses = await _warehouseService.getWarehouses();
      _warehouseNamesCache = {for (var w in warehouses) w.id: w.name};
      _warehouseNamesCacheTime = now;

      AppLogger.info('✅ تم تحديث تخزين ${_warehouseNamesCache!.length} اسم مخزن مؤقتاً');
      return _warehouseNamesCache!;
    } catch (e) {
      AppLogger.error('❌ خطأ في تحميل أسماء المخازن: $e');
      return _warehouseNamesCache ?? {}; // إرجاع التخزين المؤقت القديم أو خريطة فارغة
    }
  }

  /// تحسين بيانات المخزون مع أسماء المخازن (محسن للأداء)
  Future<List<WarehouseInventoryModel>> _enhanceInventoryWithWarehouseNames(
    List<WarehouseInventoryModel> inventories,
  ) async {
    try {
      // الحصول على أسماء المخازن من التخزين المؤقت
      final warehouseMap = await _getCachedWarehouseNames();

      if (warehouseMap.isEmpty) {
        AppLogger.warning('⚠️ لا توجد أسماء مخازن متاحة');
        return inventories;
      }

      // تحسين بيانات المخزون
      final enhancedInventories = inventories.map((inventory) {
        if (inventory.warehouseName == null || inventory.warehouseName!.isEmpty) {
          final warehouseName = warehouseMap[inventory.warehouseId];
          if (warehouseName != null) {
            return inventory.copyWith(warehouseName: warehouseName);
          } else {
            AppLogger.warning('⚠️ لم يتم العثور على اسم المخزن: ${inventory.warehouseId}');
          }
        }
        return inventory;
      }).toList();

      final enhancedCount = enhancedInventories.where((inv) => inv.warehouseName != null).length;
      AppLogger.info('✅ تم تحسين $enhancedCount من ${enhancedInventories.length} عنصر مخزون بأسماء المخازن');
      return enhancedInventories;
    } catch (e) {
      AppLogger.error('❌ خطأ في تحسين بيانات المخزون بأسماء المخازن: $e');
      return inventories; // إرجاع البيانات الأصلية في حالة الخطأ
    }
  }

  /// مسح تخزين أسماء المخازن المؤقت (للاستخدام عند تحديث المخازن)
  void clearWarehouseNamesCache() {
    _warehouseNamesCache = null;
    _warehouseNamesCacheTime = null;
    AppLogger.info('🗑️ تم مسح تخزين أسماء المخازن المؤقت');
  }
}
