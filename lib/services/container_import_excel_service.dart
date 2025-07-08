/// Container Import Excel Processing Service
/// 
/// This service handles Excel file processing for container imports with
/// intelligent column detection and flexible data extraction capabilities.

import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart' as excel;
import '../models/container_import_models.dart';
import '../utils/app_logger.dart';

/// Service for processing Excel files for container imports
class ContainerImportExcelService {
  static const int MAX_ROWS_TO_SCAN_FOR_HEADERS = 50;
  static const int MAX_ROWS_TO_PROCESS = 10000;
  static const double SIMILARITY_THRESHOLD = 0.75;

  /// Enhanced comprehensive column name variations for flexible fuzzy matching
  /// Supports case insensitivity, partial matching, and extensive variations
  static final Map<String, List<String>> columnVariations = {
    'product_name': [
      // Complete phrases
      'product name', 'item name', 'product description', 'item description',
      'product title', 'item title', 'goods name', 'merchandise name',
      'article name', 'commodity name', 'product info', 'item info',
      'product details', 'item details', 'part number', 'model number',

      // Single words and abbreviations
      'product', 'item', 'name', 'title', 'label', 'description', 'desc',
      'goods', 'merchandise', 'article', 'commodity', 'material', 'stuff',
      'sku', 'model', 'part', 'code', 'id', 'identifier', 'ref', 'reference',

      // Variations with underscores and concatenations
      'product_name', 'productname', 'item_name', 'itemname', 'product_title',
      'producttitle', 'item_title', 'itemtitle', 'part_number', 'partnumber',
      'model_number', 'modelnumber', 'product_code', 'productcode',
      'item_code', 'itemcode', 'product_id', 'productid', 'item_id', 'itemid',

      // Abbreviated forms
      'prod', 'itm', 'prd', 'pname', 'iname', 'pcode', 'icode', 'pid', 'iid',

      // Arabic variations - comprehensive
      'اسم المنتج', 'المنتج', 'البضاعة', 'السلعة', 'الصنف', 'النوع', 'العنصر',
      'الوصف', 'التسمية', 'الاسم', 'المادة', 'القطعة', 'الموديل', 'العنوان',
      'التفاصيل', 'البيانات', 'المعلومات', 'الكود', 'الرقم المرجعي', 'المرجع',
      'رقم القطعة', 'رقم الموديل', 'كود المنتج', 'معرف المنتج', 'هوية المنتج'
    ],

    'number_of_cartons': [
      // Complete phrases
      'number of cartons', 'carton count', 'cartons quantity', 'total cartons',
      'carton number', 'cartons number', 'number of boxes', 'box count',
      'boxes quantity', 'total boxes', 'box number', 'boxes number',
      'package count', 'packages quantity', 'total packages',

      // Single words and abbreviations
      'cartons', 'carton', 'boxes', 'box', 'packages', 'package', 'pack',
      'packs', 'ctn', 'ctns', 'bx', 'bxs', 'pkg', 'pkgs', 'container',
      'containers', 'case', 'cases', 'unit', 'units',

      // Variations with underscores
      'carton_count', 'cartons_count', 'box_count', 'boxes_count',
      'package_count', 'packages_count', 'carton_qty', 'box_qty',
      'package_qty', 'carton_number', 'box_number', 'package_number',

      // Abbreviated forms
      'ctn', 'CTN', 'ctns', 'CTNS', 'bx', 'BX', 'pkg', 'PKG',
      'no_cartons', 'no_boxes', 'no_packages', 'num_cartons',
      'num_boxes', 'num_packages', 'qty_cartons', 'qty_boxes',

      // Arabic variations - comprehensive
      'عدد الكراتين', 'الكراتين', 'كرتون', 'كراتين', 'عدد الصناديق',
      'الصناديق', 'صندوق', 'صناديق', 'عدد العبوات', 'العبوات', 'عبوة',
      'عبوات', 'كمية الكراتين', 'كمية الصناديق', 'كمية العبوات',
      'رقم الكرتون', 'رقم الصندوق', 'رقم العبوة', 'مجموع الكراتين'
    ],

    'pieces_per_carton': [
      // Complete phrases
      'pieces per carton', 'pcs per carton', 'units per carton',
      'items per carton', 'quantity per carton', 'pieces per box',
      'pcs per box', 'units per box', 'items per box', 'quantity per box',
      'pieces per package', 'pcs per package', 'units per package',
      'carton capacity', 'box capacity', 'package capacity',

      // Abbreviated forms
      'pc/ctn', 'pcs/ctn', 'pc/carton', 'pcs/carton', 'pieces/carton',
      'pc/box', 'pcs/box', 'pc/bx', 'pcs/bx', 'pieces/box',
      'pc/pkg', 'pcs/pkg', 'pieces/package', 'units/carton',
      'units/box', 'units/package', 'qty/carton', 'qty/box',

      // Variations with underscores
      'pieces_per_carton', 'pcs_per_carton', 'units_per_carton',
      'items_per_carton', 'pieces_per_box', 'pcs_per_box',
      'units_per_box', 'items_per_box', 'carton_size', 'box_size',
      'package_size', 'carton_capacity', 'box_capacity',

      // Single words
      'capacity', 'size', 'content', 'contents', 'inner', 'inside',
      'per', 'each', 'every', 'individual', 'single',

      // Arabic variations - comprehensive
      'قطعة في الكرتونة', 'قطع في الكرتون', 'قطعة/كرتون', 'قطع/كرتون',
      'عدد القطع في الكرتون', 'كمية القطع في الكرتون', 'محتوى الكرتون',
      'سعة الكرتون', 'قطعة في الصندوق', 'قطع في الصندوق', 'قطعة/صندوق',
      'محتوى الصندوق', 'سعة الصندوق', 'قطعة في العبوة', 'قطع في العبوة',
      'محتوى العبوة', 'سعة العبوة', 'عدد القطع', 'كمية القطع'
    ],

    'total_quantity': [
      // Complete phrases
      'total quantity', 'total qty', 'grand total', 'overall quantity',
      'total pieces', 'total pcs', 'total units', 'total items',
      'sum quantity', 'sum qty', 'aggregate quantity', 'combined quantity',
      'final quantity', 'net quantity', 'gross quantity',

      // Single words
      'quantity', 'qty', 'total', 'sum', 'aggregate', 'combined',
      'overall', 'grand', 'final', 'net', 'gross', 'complete',
      'full', 'entire', 'whole', 'all', 'pieces', 'pcs', 'units',
      'items', 'count', 'number', 'amount', 'volume',

      // Variations with underscores
      'total_quantity', 'total_qty', 'grand_total', 'overall_qty',
      'total_pieces', 'total_pcs', 'total_units', 'total_items',
      'sum_qty', 'aggregate_qty', 'combined_qty', 'final_qty',
      'net_qty', 'gross_qty', 'complete_qty', 'full_qty',

      // Abbreviated forms
      'tot_qty', 'tot_quantity', 'ttl_qty', 'ttl_quantity',
      'gr_total', 'gr_qty', 'ovr_qty', 'fin_qty', 'net_qty',
      'grs_qty', 'cmp_qty', 'ful_qty', 'all_qty',

      // Arabic variations - comprehensive
      'إجمالي الكمية', 'الكمية الإجمالية', 'المجموع الكلي', 'إجمالي',
      'الكمية', 'عدد', 'كمية', 'المقدار', 'العدد الكلي', 'المجموع',
      'الإجمالي', 'الحجم', 'القطع الإجمالية', 'الوحدات الإجمالية',
      'العناصر الإجمالية', 'كامل الكمية', 'جميع القطع', 'مجموع الكمية',
      'إجمالي القطع', 'إجمالي الوحدات', 'الكمية النهائية'
    ],

    'remarks': [
      // Complete phrases
      'remarks', 'notes', 'comments', 'observations', 'additional info',
      'additional information', 'extra details', 'special notes',
      'manufacturing materials', 'material composition', 'specifications',
      'description', 'details', 'information', 'memo', 'annotation',

      // Single words
      'remark', 'note', 'comment', 'observation', 'info', 'detail',
      'specification', 'spec', 'material', 'composition', 'content',
      'ingredient', 'component', 'element', 'substance', 'fabric',
      'texture', 'finish', 'quality', 'grade', 'type', 'kind',

      // Variations with underscores
      'remarks_notes', 'additional_info', 'extra_details', 'special_notes',
      'manufacturing_materials', 'material_composition', 'product_specs',
      'item_details', 'product_info', 'item_info', 'extra_info',
      'additional_details', 'special_info', 'custom_notes',

      // Abbreviated forms
      'rmks', 'nts', 'cmts', 'obs', 'add_info', 'ext_det', 'spc_nts',
      'mfg_mat', 'mat_comp', 'prod_spec', 'itm_det', 'prod_inf',

      // Arabic variations - comprehensive
      'ملاحظات', 'مواد التصنيع', 'المواد', 'التركيب', 'المكونات',
      'العناصر', 'المواد الخام', 'الخامات', 'النسيج', 'القماش',
      'الملمس', 'اللمسة النهائية', 'الجودة', 'الدرجة', 'النوع',
      'الصنف', 'التفاصيل الإضافية', 'معلومات إضافية', 'تفاصيل خاصة',
      'مواصفات', 'وصف', 'تفاصيل', 'معلومات', 'مذكرة', 'تعليق'
    ],
  };

  /// Process Excel file for container import
  static Future<ContainerImportResult> processExcelFile({
    required String filePath,
    required String filename,
    Function(double progress)? onProgress,
    Function(String status)? onStatusUpdate,
  }) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      onStatusUpdate?.call('قراءة الملف...');
      onProgress?.call(0.1);

      final file = File(filePath);
      final bytes = await file.readAsBytes();
      
      onStatusUpdate?.call('تحليل بنية Excel...');
      onProgress?.call(0.2);

      final excelFile = excel.Excel.decodeBytes(bytes);
      
      if (excelFile.tables.isEmpty) {
        throw Exception('الملف لا يحتوي على أوراق عمل');
      }

      final sheetName = excelFile.tables.keys.first;
      final sheet = excelFile.tables[sheetName]!;
      
      onStatusUpdate?.call('البحث عن رؤوس الأعمدة...');
      onProgress?.call(0.3);

      // Find header row and column mapping
      final headerResult = _findHeaderRow(sheet);
      if (headerResult.isEmpty) {
        throw Exception('لم يتم العثور على أعمدة البيانات المطلوبة');
      }

      onStatusUpdate?.call('استخراج البيانات...');
      onProgress?.call(0.5);

      // Extract data from rows
      final extractionResult = _extractDataFromSheet(sheet, headerResult, onProgress);
      
      onStatusUpdate?.call('إنشاء النتائج...');
      onProgress?.call(0.9);

      // Create batch
      final batch = ContainerImportBatch.create(
        filename: filename,
        originalFilename: filename,
        fileSize: bytes.length,
        fileType: 'xlsx',
        items: extractionResult.items,
      );

      stopwatch.stop();

      // Debug logging
      AppLogger.info('🎉 Container import completed successfully');
      AppLogger.info('📊 Final results: ${extractionResult.items.length} items processed');
      print('🔍 ContainerImportExcelService - Final items count: ${extractionResult.items.length}');

      if (extractionResult.items.isNotEmpty) {
        print('🔍 First item: ${extractionResult.items.first.productName}');
        print('🔍 Last item: ${extractionResult.items.last.productName}');
      }

      onStatusUpdate?.call('اكتمل بنجاح - ${extractionResult.items.length} منتج');
      onProgress?.call(1.0);

      final result = ContainerImportResult(
        success: true,
        batch: batch,
        items: extractionResult.items,
        columnMapping: headerResult,
        totalRows: sheet.maxRows,
        processedRows: extractionResult.processedRows,
        skippedRows: extractionResult.skippedRows,
        errors: extractionResult.errors,
        warnings: extractionResult.warnings,
        processingTime: stopwatch.elapsedMilliseconds / 1000.0,
      );

      print('🔍 ContainerImportExcelService - Returning result with ${result.items.length} items');
      return result;

    } catch (e) {
      stopwatch.stop();
      AppLogger.error('❌ Error processing Excel file: $e');
      
      return ContainerImportResult(
        success: false,
        items: [],
        columnMapping: {},
        totalRows: 0,
        processedRows: 0,
        skippedRows: 0,
        errors: [e.toString()],
        warnings: [],
        processingTime: stopwatch.elapsedMilliseconds / 1000.0,
      );
    }
  }

  /// Find header row and create column mapping
  static Map<String, int> _findHeaderRow(excel.Sheet sheet) {
    int headerRowIndex = -1;
    Map<String, int> bestMapping = {};
    int bestMatchScore = 0;

    final maxRowsToScan = [sheet.maxRows, MAX_ROWS_TO_SCAN_FOR_HEADERS].reduce((a, b) => a < b ? a : b);
    
    AppLogger.info('🔍 Scanning $maxRowsToScan rows for headers...');

    for (int rowIndex = 0; rowIndex < maxRowsToScan; rowIndex++) {
      try {
        final row = sheet.row(rowIndex);
        if (row.isEmpty) continue;

        final potentialMapping = <String, int>{};
        int matchScore = 0;

        for (int colIndex = 0; colIndex < row.length && colIndex < 100; colIndex++) {
          final cell = row[colIndex];
          if (cell?.value == null) continue;

          final cellValue = _cleanCellValue(cell!.value.toString());
          if (cellValue.isEmpty) continue;

          // Check against all column variations
          for (final entry in columnVariations.entries) {
            final columnKey = entry.key;
            final variations = entry.value;

            for (final variation in variations) {
              final similarity = _calculateAdvancedSimilarity(cellValue, variation);
              if (similarity >= SIMILARITY_THRESHOLD) {
                potentialMapping[columnKey] = colIndex;
                matchScore += (similarity * 100).round();
                break;
              }
            }
          }
        }

        // Update best match if this row has better score
        if (matchScore > bestMatchScore && potentialMapping.containsKey('product_name')) {
          bestMatchScore = matchScore;
          bestMapping = Map.from(potentialMapping);
          headerRowIndex = rowIndex;
          AppLogger.info('📊 Best match at row ${rowIndex + 1} with score: $matchScore');
        }

        // Early exit if we found a good match
        if (potentialMapping.length >= 3 && matchScore >= 300) {
          break;
        }

      } catch (e) {
        AppLogger.warning('⚠️ Error processing row ${rowIndex + 1}: $e');
        continue;
      }
    }

    if (headerRowIndex != -1) {
      AppLogger.info('✅ Header found at row ${headerRowIndex + 1} with mapping: $bestMapping');
    }

    return bestMapping;
  }

  /// Extract data from sheet using column mapping
  static _ExtractionResult _extractDataFromSheet(
    excel.Sheet sheet,
    Map<String, int> columnMapping,
    Function(double progress)? onProgress,
  ) {
    final List<ContainerImportItem> items = [];
    final List<String> errors = [];
    final List<String> warnings = [];
    int processedRows = 0;
    int skippedRows = 0;

    // Find the header row index
    int headerRowIndex = 0;
    for (int i = 0; i < sheet.maxRows && i < MAX_ROWS_TO_SCAN_FOR_HEADERS; i++) {
      final row = sheet.row(i);
      if (row.isNotEmpty) {
        bool hasHeaders = false;
        for (final colIndex in columnMapping.values) {
          if (colIndex < row.length && row[colIndex]?.value != null) {
            final cellValue = _cleanCellValue(row[colIndex]!.value.toString());
            if (cellValue.isNotEmpty) {
              hasHeaders = true;
              break;
            }
          }
        }
        if (hasHeaders) {
          headerRowIndex = i;
          break;
        }
      }
    }

    final maxRowsToProcess = [sheet.maxRows, MAX_ROWS_TO_PROCESS].reduce((a, b) => a < b ? a : b);
    final dataStartRow = headerRowIndex + 1;
    
    AppLogger.info('📋 Processing data from row ${dataStartRow + 1} to $maxRowsToProcess');

    for (int rowIndex = dataStartRow; rowIndex < maxRowsToProcess; rowIndex++) {
      try {
        final row = sheet.row(rowIndex);
        if (row.isEmpty) {
          skippedRows++;
          continue;
        }

        // Check if row is empty
        if (_isRowEmpty(row)) {
          skippedRows++;
          continue;
        }

        // Extract data from row
        final productName = _getCellValue(row, columnMapping['product_name']);
        if (productName.isEmpty) {
          skippedRows++;
          errors.add('Row ${rowIndex + 1}: Product name is missing');
          continue;
        }

        final numberOfCartons = _parseIntValue(_getCellValue(row, columnMapping['number_of_cartons']));
        final piecesPerCarton = _parseIntValue(_getCellValue(row, columnMapping['pieces_per_carton']));
        final totalQuantity = _parseIntValue(_getCellValue(row, columnMapping['total_quantity']));
        final remarks = _getCellValue(row, columnMapping['remarks']);

        // Validate essential data
        if (numberOfCartons <= 0 && piecesPerCarton <= 0 && totalQuantity <= 0) {
          skippedRows++;
          errors.add('Row ${rowIndex + 1}: No valid quantity data found');
          continue;
        }

        // Create item
        final item = ContainerImportItem.create(
          productName: productName,
          numberOfCartons: numberOfCartons,
          piecesPerCarton: piecesPerCarton,
          totalQuantity: totalQuantity,
          remarks: remarks,
        );

        // Check for quantity consistency
        if (numberOfCartons > 0 && piecesPerCarton > 0 && totalQuantity > 0) {
          if (!item.isQuantityConsistent) {
            warnings.add('Row ${rowIndex + 1}: Quantity mismatch - calculated: ${item.calculatedTotalPieces}, provided: $totalQuantity');
          }
        }

        items.add(item);
        processedRows++;

        // Debug logging for first few items
        if (items.length <= 5) {
          print('🔍 Item ${items.length}: ${item.productName} - ${item.numberOfCartons} cartons, ${item.totalQuantity} total');
        }

        // Update progress
        if (onProgress != null && rowIndex % 100 == 0) {
          final progress = 0.5 + (0.4 * (rowIndex - dataStartRow) / (maxRowsToProcess - dataStartRow));
          onProgress(progress);
        }

      } catch (e) {
        skippedRows++;
        errors.add('Row ${rowIndex + 1}: Processing error - $e');
        continue;
      }
    }

    AppLogger.info('✅ Extraction completed: ${items.length} items processed, $skippedRows skipped');

    // Debug summary
    print('🔍 Extraction Summary:');
    print('   - Total items extracted: ${items.length}');
    print('   - Processed rows: $processedRows');
    print('   - Skipped rows: $skippedRows');
    print('   - Errors: ${errors.length}');
    print('   - Warnings: ${warnings.length}');

    if (items.isNotEmpty) {
      print('   - Sample items:');
      for (int i = 0; i < items.length && i < 3; i++) {
        final item = items[i];
        print('     ${i + 1}. ${item.productName} (${item.totalQuantity} total)');
      }
    }

    final result = _ExtractionResult(
      items: items,
      processedRows: processedRows,
      skippedRows: skippedRows,
      errors: errors,
      warnings: warnings,
    );

    print('🔍 Returning _ExtractionResult with ${result.items.length} items');
    return result;
  }

  /// Clean cell value for comparison
  static String _cleanCellValue(String value) {
    return value.toLowerCase().trim().replaceAll(RegExp(r'[^\w\s\u0600-\u06FF]'), ' ').replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Calculate advanced similarity between two strings
  static double _calculateAdvancedSimilarity(String str1, String str2) {
    if (str1 == str2) return 1.0;
    if (str1.isEmpty || str2.isEmpty) return 0.0;

    // Exact match
    if (str1 == str2) return 1.0;

    // Contains match
    if (str1.contains(str2) || str2.contains(str1)) return 0.9;

    // Partial match
    final words1 = str1.split(' ');
    final words2 = str2.split(' ');
    
    int matchingWords = 0;
    for (final word1 in words1) {
      for (final word2 in words2) {
        if (word1 == word2 || word1.contains(word2) || word2.contains(word1)) {
          matchingWords++;
          break;
        }
      }
    }

    if (matchingWords > 0) {
      return 0.7 + (0.2 * matchingWords / words1.length.clamp(1, double.infinity));
    }

    return 0.0;
  }

  /// Check if row is empty
  static bool _isRowEmpty(List<excel.Data?> row) {
    return row.every((cell) => cell?.value == null || cell!.value.toString().trim().isEmpty);
  }

  /// Get cell value safely
  static String _getCellValue(List<excel.Data?> row, int? columnIndex) {
    if (columnIndex == null || columnIndex >= row.length) return '';
    final cell = row[columnIndex];
    if (cell?.value == null) return '';
    return cell!.value.toString().trim();
  }

  /// Parse integer value safely
  static int _parseIntValue(String value) {
    if (value.isEmpty) return 0;
    final cleanValue = value.replaceAll(RegExp(r'[^\d]'), '');
    return int.tryParse(cleanValue) ?? 0;
  }
}

/// Internal class for extraction results
class _ExtractionResult {
  final List<ContainerImportItem> items;
  final int processedRows;
  final int skippedRows;
  final List<String> errors;
  final List<String> warnings;

  _ExtractionResult({
    required this.items,
    required this.processedRows,
    required this.skippedRows,
    required this.errors,
    required this.warnings,
  });
}
