import 'dart:io';
import 'dart:isolate';
import 'dart:convert';
import 'dart:typed_data';
import 'package:excel/excel.dart' as excel;
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:smartbiztracker_new/models/import_analysis_models.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// خدمة معالجة ملفات Excel/CSV المتقدمة مع الكشف الذكي للرؤوس والمعالجة في الخلفية
/// تدعم الملفات الكبيرة مع إدارة الذاكرة والمعالجة المتدفقة
class ExcelParsingService {
  static const int _maxFileSize = 100 * 1024 * 1024; // 100MB
  static const int _chunkSize = 1024 * 1024; // 1MB chunks for streaming
  static const int _maxHeaderScanRows = 20; // Maximum rows to scan for headers
  
  /// معالجة ملف Excel/CSV مع التقدم والإلغاء
  static Future<ExcelParsingResult> parseFile({
    required String filePath,
    required SupportedFileType fileType,
    Function(double progress)? onProgress,
    Function(String status)? onStatusUpdate,
    bool enableIsolateProcessing = true,
  }) async {
    try {
      onStatusUpdate?.call('بدء معالجة الملف...');
      
      // التحقق من حجم الملف
      final file = File(filePath);
      final fileSize = await file.length();
      
      if (fileSize > _maxFileSize) {
        throw ExcelParsingException(
          'حجم الملف كبير جداً. الحد الأقصى المسموح: ${(_maxFileSize / (1024 * 1024)).toInt()}MB',
          ExcelParsingErrorType.fileSizeExceeded,
        );
      }
      
      onProgress?.call(0.1);
      onStatusUpdate?.call('قراءة الملف...');
      
      // اختيار طريقة المعالجة بناءً على حجم الملف
      if (fileSize > 10 * 1024 * 1024 && enableIsolateProcessing) {
        // معالجة في الخلفية للملفات الكبيرة
        return await _parseInIsolate(
          filePath: filePath,
          fileType: fileType,
          onProgress: onProgress,
          onStatusUpdate: onStatusUpdate,
        );
      } else {
        // معالجة مباشرة للملفات الصغيرة
        return await _parseDirectly(
          filePath: filePath,
          fileType: fileType,
          onProgress: onProgress,
          onStatusUpdate: onStatusUpdate,
        );
      }
    } catch (e) {
      AppLogger.error('خطأ في معالجة الملف: $e');
      if (e is ExcelParsingException) rethrow;
      throw ExcelParsingException(
        'فشل في معالجة الملف: ${e.toString()}',
        ExcelParsingErrorType.processingError,
      );
    }
  }
  
  /// معالجة مباشرة للملفات الصغيرة
  static Future<ExcelParsingResult> _parseDirectly({
    required String filePath,
    required SupportedFileType fileType,
    Function(double progress)? onProgress,
    Function(String status)? onStatusUpdate,
  }) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    
    onProgress?.call(0.3);
    onStatusUpdate?.call('تحليل بنية الملف...');
    
    List<List<dynamic>> rawData;
    
    switch (fileType) {
      case SupportedFileType.xlsx:
      case SupportedFileType.xls:
        rawData = await _parseExcelData(bytes, onProgress);
        break;
      case SupportedFileType.csv:
        rawData = await _parseCsvData(bytes, onProgress);
        break;
    }
    
    onProgress?.call(0.6);
    onStatusUpdate?.call('الكشف الذكي عن الرؤوس...');
    
    // الكشف الذكي عن الرؤوس
    final headerDetectionResult = detectHeaders(rawData);

    onProgress?.call(0.8);
    onStatusUpdate?.call('استخراج البيانات...');

    // استخراج البيانات
    final extractedData = extractPackingListData(
      rawData,
      headerDetectionResult,
    );
    
    onProgress?.call(1.0);
    onStatusUpdate?.call('اكتمل بنجاح');
    
    return ExcelParsingResult(
      data: extractedData,
      headerMapping: headerDetectionResult.mapping,
      totalRows: rawData.length,
      dataRows: extractedData.length,
      detectionConfidence: headerDetectionResult.confidence,
      processingTime: DateTime.now(),
    );
  }
  
  /// معالجة في الخلفية باستخدام Isolate
  static Future<ExcelParsingResult> _parseInIsolate({
    required String filePath,
    required SupportedFileType fileType,
    Function(double progress)? onProgress,
    Function(String status)? onStatusUpdate,
  }) async {
    final receivePort = ReceivePort();
    final isolateData = IsolateParsingData(
      filePath: filePath,
      fileType: fileType,
      sendPort: receivePort.sendPort,
    );
    
    onStatusUpdate?.call('بدء المعالجة في الخلفية...');
    
    // إنشاء Isolate للمعالجة
    final isolate = await Isolate.spawn(_isolateEntryPoint, isolateData);
    
    ExcelParsingResult? result;
    Exception? error;
    
    await for (final message in receivePort) {
      if (message is Map<String, dynamic>) {
        if (message.containsKey('progress')) {
          onProgress?.call(message['progress'] as double);
        } else if (message.containsKey('status')) {
          onStatusUpdate?.call(message['status'] as String);
        } else if (message.containsKey('result')) {
          result = ExcelParsingResult.fromJson(message['result']);
          break;
        } else if (message.containsKey('error')) {
          error = ExcelParsingException(
            message['error'] as String,
            ExcelParsingErrorType.processingError,
          );
          break;
        }
      }
    }
    
    isolate.kill();
    receivePort.close();
    
    if (error != null) throw error;
    if (result == null) {
      throw ExcelParsingException(
        'فشل في الحصول على نتيجة المعالجة',
        ExcelParsingErrorType.processingError,
      );
    }
    
    return result;
  }
  
  /// نقطة دخول Isolate
  static void _isolateEntryPoint(IsolateParsingData data) async {
    final startTime = DateTime.now();

    try {
      // CRITICAL FIX: Initialize isolate for background operations
      // Note: BackgroundIsolateBinaryMessenger requires RootIsolateToken in newer Flutter versions
      // For Excel parsing, we don't need platform channel access, so we can skip this initialization

      data.sendPort.send({'status': 'بدء المعالجة في الخلفية...'});
      data.sendPort.send({'progress': 0.1});

      // ENHANCED ERROR HANDLING: Memory usage tracking
      AppLogger.info('🔄 بدء معالجة الملف في Isolate: ${data.filePath}');

      final file = File(data.filePath);
      if (!await file.exists()) {
        throw ExcelParsingException(
          'الملف غير موجود: ${data.filePath}',
          ExcelParsingErrorType.fileNotFound,
        );
      }

      final fileSize = await file.length();
      AppLogger.info('📊 حجم الملف: ${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB');

      final bytes = await file.readAsBytes();
      AppLogger.info('✅ تم قراءة الملف بنجاح');

      data.sendPort.send({'status': 'تحليل بنية الملف...'});
      data.sendPort.send({'progress': 0.3});

      List<List<dynamic>> rawData;

      try {
        switch (data.fileType) {
          case SupportedFileType.xlsx:
          case SupportedFileType.xls:
            AppLogger.info('📋 معالجة ملف Excel...');
            rawData = await _parseExcelData(bytes, (progress) {
              data.sendPort.send({'progress': 0.3 + (progress * 0.3)});
            });
            break;
          case SupportedFileType.csv:
            AppLogger.info('📋 معالجة ملف CSV...');
            rawData = await _parseCsvData(bytes, (progress) {
              data.sendPort.send({'progress': 0.3 + (progress * 0.3)});
            });
            break;
        }

        AppLogger.info('✅ تم تحليل الملف - عدد الصفوف: ${rawData.length}');

      } catch (e) {
        AppLogger.error('❌ خطأ في تحليل بنية الملف: $e');
        throw ExcelParsingException(
          'فشل في تحليل بنية الملف: $e',
          ExcelParsingErrorType.invalidFormat,
        );
      }

      data.sendPort.send({'status': 'الكشف الذكي عن الرؤوس...'});
      data.sendPort.send({'progress': 0.6});

      HeaderDetectionResult headerDetectionResult;
      try {
        AppLogger.info('🔍 بدء الكشف عن الرؤوس...');
        headerDetectionResult = detectHeaders(rawData);
        AppLogger.info('✅ تم كشف الرؤوس بنجاح - الثقة: ${(headerDetectionResult.confidence * 100).toStringAsFixed(1)}%');
      } catch (e) {
        AppLogger.error('❌ خطأ في كشف الرؤوس: $e');
        throw ExcelParsingException(
          'فشل في كشف رؤوس الأعمدة: $e',
          ExcelParsingErrorType.headersNotFound,
        );
      }

      data.sendPort.send({'status': 'استخراج البيانات...'});
      data.sendPort.send({'progress': 0.8});

      List<Map<String, dynamic>> extractedData;
      try {
        AppLogger.info('📦 بدء استخراج البيانات...');
        extractedData = extractPackingListData(
          rawData,
          headerDetectionResult,
        );
        AppLogger.info('✅ تم استخراج البيانات بنجاح - عدد العناصر: ${extractedData.length}');
      } catch (e) {
        AppLogger.error('❌ خطأ في استخراج البيانات: $e');
        throw ExcelParsingException(
          'فشل في استخراج البيانات: $e',
          ExcelParsingErrorType.dataExtractionError,
        );
      }

      final processingTime = DateTime.now().difference(startTime);
      AppLogger.info('⏱️ وقت المعالجة الإجمالي: ${processingTime.inMilliseconds}ms');

      data.sendPort.send({'progress': 1.0});
      data.sendPort.send({'status': 'اكتمل بنجاح'});

      final result = ExcelParsingResult(
        data: extractedData,
        headerMapping: headerDetectionResult.mapping,
        totalRows: rawData.length,
        dataRows: extractedData.length,
        detectionConfidence: headerDetectionResult.confidence,
        processingTime: DateTime.now(),
      );

      AppLogger.info('🎉 تمت معالجة الملف بنجاح في Isolate');
      data.sendPort.send({'result': result.toJson()});

    } catch (e) {
      final processingTime = DateTime.now().difference(startTime);
      AppLogger.error('💥 خطأ في معالجة الملف في Isolate: $e');
      AppLogger.error('⏱️ وقت المعالجة قبل الخطأ: ${processingTime.inMilliseconds}ms');

      // ENHANCED ERROR HANDLING: Send detailed error information
      data.sendPort.send({
        'error': e.toString(),
        'errorType': e.runtimeType.toString(),
        'processingTime': processingTime.inMilliseconds,
        'filePath': data.filePath,
      });
    }
  }
  
  /// معالجة بيانات Excel
  static Future<List<List<dynamic>>> _parseExcelData(
    Uint8List bytes,
    Function(double progress)? onProgress,
  ) async {
    try {
      final excelFile = excel.Excel.decodeBytes(bytes);
      
      if (excelFile.tables.isEmpty) {
        throw ExcelParsingException(
          'الملف لا يحتوي على أوراق عمل',
          ExcelParsingErrorType.invalidFormat,
        );
      }
      
      // استخدام أول ورقة عمل
      final sheetName = excelFile.tables.keys.first;
      final sheet = excelFile.tables[sheetName]!;
      
      final List<List<dynamic>> data = [];
      final totalRows = sheet.maxRows;
      
      for (int rowIndex = 0; rowIndex < totalRows; rowIndex++) {
        final row = <dynamic>[];
        final sheetRow = sheet.rows[rowIndex];

        for (final cell in sheetRow) {
          row.add(cell?.value?.toString() ?? '');
        }

        // إضافة جميع الصفوف (حتى الفارغة) - سيتم التعامل معها لاحقاً في مرحلة الاستخراج
        data.add(row);

        // تسجيل تفصيلي للصفوف الأولى
        if (rowIndex < 10) {
          final nonEmptyCells = row.where((cell) => cell.toString().trim().isNotEmpty).length;
          AppLogger.info('📄 قراءة الصف $rowIndex: $nonEmptyCells خلايا غير فارغة من ${row.length}');
        }

        // تحديث التقدم
        if (rowIndex % 100 == 0) {
          onProgress?.call(rowIndex / totalRows);
        }
      }

      AppLogger.info('📊 تم قراءة ${data.length} صف من ملف Excel');
      
      onProgress?.call(1.0);
      return data;
    } catch (e) {
      throw ExcelParsingException(
        'فشل في معالجة ملف Excel: ${e.toString()}',
        ExcelParsingErrorType.invalidFormat,
      );
    }
  }
  
  /// معالجة بيانات CSV
  static Future<List<List<dynamic>>> _parseCsvData(
    Uint8List bytes,
    Function(double progress)? onProgress,
  ) async {
    try {
      final content = utf8.decode(bytes);
      final csvData = const CsvToListConverter().convert(content);

      onProgress?.call(1.0);
      return csvData;
    } catch (e) {
      throw ExcelParsingException(
        'فشل في معالجة ملف CSV: ${e.toString()}',
        ExcelParsingErrorType.invalidFormat,
      );
    }
  }

  /// الكشف الذكي عن الرؤوس مع خوارزمية متقدمة
  @visibleForTesting
  static HeaderDetectionResult detectHeaders(List<List<dynamic>> data) {
    if (data.isEmpty) {
      throw ExcelParsingException(
        'الملف فارغ أو لا يحتوي على بيانات',
        ExcelParsingErrorType.emptyFile,
      );
    }

    AppLogger.info('🔍 بدء كشف الرؤوس في ${data.length} صف');

    // طباعة أول 5 صفوف للتشخيص مع تفاصيل أكثر
    for (int i = 0; i < data.length && i < 5; i++) {
      final row = data[i];
      AppLogger.info('📋 الصف $i (${row.length} عمود): ${row.take(15).toList()}');

      // البحث عن الكلمات المفتاحية المهمة في هذا الصف
      final criticalHeaders = ['ITEM NO', 'CTN', 'QTY', 'REMARKS', 'PC/CTN'];
      final foundHeaders = <String>[];
      for (int j = 0; j < row.length && j < 20; j++) {
        final cellValue = row[j].toString().toUpperCase().trim();
        for (final header in criticalHeaders) {
          if (cellValue.contains(header)) {
            foundHeaders.add('$header@$j');
          }
        }
      }
      if (foundHeaders.isNotEmpty) {
        AppLogger.info('🎯 الصف $i - رؤوس مهمة: ${foundHeaders.join(', ')}');
      }
    }

    // الكلمات المفتاحية المحسنة للأعمدة الأساسية الثلاثة مع دعم التطابق الضبابي
    final expectedHeaders = <String, List<String>>{
      // الأعمدة الأساسية الثلاثة - أولوية عالية
      'item_number': [
        'ITEM NO.', 'ITEM NO', 'ITEM_NO', 'ITEMNO', 'ITEM', 'ITEM NUMBER',
        'PRODUCT NO', 'PRODUCT_NO', 'PRODUCT CODE', 'PRODUCT_CODE',
        'MODEL NO', 'MODEL_NO', 'MODEL', 'CODE', 'SKU',
        'رقم الصنف', 'الصنف', 'رقم المنتج', 'كود المنتج', 'موديل',
        '型号', '产品编号', '货号', '商品编号'
      ],
      'total_quantity': [
        'QTY', 'QUANTITY', 'TOTAL QTY', 'TOTAL_QTY', 'TOTALQTY',
        'TOTAL QUANTITY', 'TOTAL_QUANTITY', 'TOTALQUANTITY',
        'الكمية', 'الكمية الإجمالية', 'إجمالي الكمية', 'كمية',
        '数量', '总数量', '总量', '件数'
      ],
      'remarks_a': [
        'REMARKS', 'REMARK', 'REMARKS A', 'REMARKSA', 'DESCRIPTION',
        'DESC', 'MATERIAL', 'MATERIALS', 'SPECIFICATION', 'SPEC',
        'DETAILS', 'INFO', 'INFORMATION', 'COMMENT', 'COMMENTS',
        'ملاحظات', 'ملاحظة', 'وصف', 'تفاصيل', 'مواد', 'مادة', 'مواصفات',
        '备注', '说明', '描述', '材料', '规格', '详情'
      ],

      // الأعمدة الثانوية - أولوية متوسطة
      'serial_number': ['S/NO.', 'S/NO', 'SERIAL', 'الرقم التسلسلي', 'رقم', 'NO.', 'NO', '序号'],
      'image_url': ['PICTURE', 'IMAGE', 'PHOTO', 'صورة المنتج', 'صورة', 'IMG', '图片'],
      'carton_count': ['CTN', 'CARTON', 'CARTONS', 'ctn', 'carton', 'cartons', 'عدد الكراتين', 'كراتين', 'BOXES', 'boxes', '箱数'],
      'pieces_per_carton': ['PC/CTN', 'PCS/CTN', 'PIECES/CARTON', 'pc/ctn', 'pcs/ctn', 'pieces/carton', 'قطع لكل كرتون', 'قطع/كرتون', '支/箱'],

      // الأعمدة الاختيارية - أولوية منخفضة
      'size1': ['SIZE1', 'LENGTH', 'L', 'الطول', 'طول', '长'],
      'size2': ['SIZE2', 'WIDTH', 'W', 'العرض', 'عرض', '宽'],
      'size3': ['SIZE3', 'HEIGHT', 'H', 'الارتفاع', 'ارتفاع', '高'],
      'total_cubic_meters': ['T.CBM', 'TOTAL CBM', 'CBM', 'المتر المكعب الإجمالي', 'متر مكعب', '总体积'],
      'net_weight': ['N.W', 'NET WEIGHT', 'الوزن الصافي', 'وزن صافي', '净重'],
      'gross_weight': ['G.W', 'GROSS WEIGHT', 'الوزن الإجمالي', 'وزن إجمالي', '毛重'],
      'total_net_weight': ['T.NW', 'TOTAL NET WEIGHT', 'الوزن الصافي الكلي', '总净重'],
      'total_gross_weight': ['T.GW', 'TOTAL GROSS WEIGHT', 'الوزن الإجمالي الكلي', '总毛重'],
      'unit_price': ['PRICE', 'UNIT PRICE', 'السعر لكل وحدة', 'السعر', 'UNIT_PRICE', '单价'],
      'rmb_price': ['RMB', 'RMB PRICE', 'السعر باليوان الصيني', 'يوان', '总金额'],
      'remarks_b': ['REMARKS B', 'REMARK B', 'ملاحظات ب'],
      'remarks_c': ['REMARKS C', 'REMARK C', 'ملاحظات ج'],
    };

    // أوزان الأولوية للأعمدة الأساسية
    final columnPriorities = <String, double>{
      'item_number': 3.0,      // أولوية عالية جداً
      'total_quantity': 3.0,   // أولوية عالية جداً
      'remarks_a': 3.0,        // أولوية عالية جداً
      'serial_number': 2.0,    // أولوية متوسطة
      'carton_count': 2.0,     // أولوية متوسطة
      'pieces_per_carton': 2.0, // أولوية متوسطة
    };

    int bestHeaderRow = -1;
    double bestConfidence = 0.0;
    Map<String, int> bestMapping = {};

    // فحص أول 20 صف للعثور على أفضل صف رؤوس
    final maxScanRows = data.length < _maxHeaderScanRows ? data.length : _maxHeaderScanRows;

    // OPTIMIZATION: Add timeout mechanism to prevent infinite processing
    final startTime = DateTime.now();
    const maxProcessingTime = Duration(seconds: 30); // 30 second timeout

    for (int rowIndex = 0; rowIndex < maxScanRows; rowIndex++) {
      // OPTIMIZATION: Check timeout to prevent infinite loops
      if (DateTime.now().difference(startTime) > maxProcessingTime) {
        AppLogger.warning('تم تجاوز الحد الزمني لمعالجة الرؤوس - إيقاف المعالجة');
        break;
      }

      final row = data[rowIndex];
      final mapping = <String, int>{};
      int matchCount = 0;

      AppLogger.info('فحص الصف $rowIndex: ${row.take(10).toList()}');

      for (int colIndex = 0; colIndex < row.length; colIndex++) {
        final cellValue = row[colIndex].toString().trim().toUpperCase();

        if (cellValue.isEmpty) continue;

        // البحث عن تطابق مع الكلمات المفتاحية باستخدام التطابق الضبابي المحسن
        bool foundExactMatch = false;

        for (final entry in expectedHeaders.entries) {
          final fieldName = entry.key;
          final keywords = entry.value;

          // تجنب التطابق المتعدد لنفس العمود
          if (mapping.containsKey(fieldName)) continue;

          double bestMatchScore = 0.0;
          String bestMatchKeyword = '';

          for (final keyword in keywords) {
            final matchScore = _calculateFuzzyMatchScore(cellValue, keyword.toUpperCase());

            // OPTIMIZATION: Early termination for perfect matches
            if (matchScore >= 0.95) {
              bestMatchScore = matchScore;
              bestMatchKeyword = keyword;
              foundExactMatch = true;
              break; // Stop searching for this field
            }

            if (matchScore > bestMatchScore && matchScore >= 0.7) { // عتبة التطابق الضبابي
              bestMatchScore = matchScore;
              bestMatchKeyword = keyword;
            }
          }

          if (bestMatchScore >= 0.7) {
            mapping[fieldName] = colIndex;
            matchCount++;
            AppLogger.info('تطابق ضبابي: $cellValue -> $fieldName في العمود $colIndex (نقاط: ${(bestMatchScore * 100).toStringAsFixed(1)}%)');

            // OPTIMIZATION: If we found a perfect match, break out of field loop
            if (foundExactMatch) break;
          }
        }
      }

      // حساب مستوى الثقة المرجح بناءً على أولوية الأعمدة
      double weightedScore = 0.0;
      double totalWeight = 0.0;

      for (final entry in mapping.entries) {
        final fieldName = entry.key;
        final weight = columnPriorities[fieldName] ?? 1.0;
        weightedScore += weight;
        totalWeight += weight;
      }

      // إضافة وزن للأعمدة المفقودة المهمة
      for (final entry in columnPriorities.entries) {
        if (!mapping.containsKey(entry.key)) {
          totalWeight += entry.value;
        }
      }

      final confidence = totalWeight > 0 ? weightedScore / totalWeight : 0.0;
      AppLogger.info('الصف $rowIndex: تطابق $matchCount أعمدة، النقاط المرجحة: ${weightedScore.toStringAsFixed(1)}/${totalWeight.toStringAsFixed(1)} (ثقة: ${(confidence * 100).toStringAsFixed(1)}%)');

      if (confidence > bestConfidence) {
        bestConfidence = confidence;
        bestHeaderRow = rowIndex;
        bestMapping = Map.from(mapping);
        AppLogger.info('أفضل صف رؤوس جديد: $rowIndex بثقة ${(bestConfidence * 100).toStringAsFixed(1)}%');
      }
    }

    AppLogger.info('أفضل نتيجة: الصف $bestHeaderRow بثقة ${(bestConfidence * 100).toStringAsFixed(1)}%');
    AppLogger.info('خريطة الأعمدة النهائية: $bestMapping');

    if (bestHeaderRow == -1 || bestConfidence < 0.3) {
      AppLogger.error('فشل في كشف الرؤوس - أفضل ثقة: ${(bestConfidence * 100).toStringAsFixed(1)}%');
      AppLogger.error('الرؤوس المكتشفة: ${bestHeaderRow >= 0 ? data[bestHeaderRow].take(10).toList() : 'لا يوجد'}');
      throw ExcelParsingException(
        'لم يتم العثور على رؤوس صحيحة في الملف. يرجى التأكد من تنسيق الملف. أفضل ثقة: ${(bestConfidence * 100).toStringAsFixed(1)}%',
        ExcelParsingErrorType.headersNotFound,
      );
    }

    AppLogger.info('تم كشف الرؤوس بنجاح في الصف $bestHeaderRow');
    return HeaderDetectionResult(
      headerRow: bestHeaderRow,
      mapping: bestMapping,
      confidence: bestConfidence,
      detectedHeaders: data[bestHeaderRow].map((e) => e.toString()).toList(),
    );
  }

  /// التحقق من تطابق الرأس مع الكلمة المفتاحية (محسن)
  static bool _isHeaderMatch(String cellValue, String keyword) {
    return _calculateFuzzyMatchScore(cellValue, keyword) >= 0.7;
  }

  /// حساب نقاط التطابق الضبابي بين نصين (محسن للأداء والنصوص العربية)
  static double _calculateFuzzyMatchScore(String cellValue, String keyword) {
    // OPTIMIZATION: Early return for empty strings
    if (cellValue.isEmpty || keyword.isEmpty) return 0.0;

    // ARABIC TEXT FIX: Normalize Arabic text before comparison
    final normalizedCell = _normalizeArabicText(cellValue);
    final normalizedKeyword = _normalizeArabicText(keyword);

    // تطابق دقيق - أعلى نقاط
    if (normalizedCell == normalizedKeyword) return 1.0;

    // تطابق جزئي مباشر
    if (normalizedCell.contains(normalizedKeyword)) return 0.9;

    // OPTIMIZATION: Skip expensive operations for very different lengths
    if ((normalizedCell.length - normalizedKeyword.length).abs() > normalizedKeyword.length) {
      return 0.0;
    }

    // تنظيف النصوص من الرموز الخاصة والمسافات (مع دعم العربية)
    final cleanCell = _cleanTextForMatching(normalizedCell);
    final cleanKeyword = _cleanTextForMatching(normalizedKeyword);

    // OPTIMIZATION: Early return for empty cleaned strings
    if (cleanCell.isEmpty || cleanKeyword.isEmpty) return 0.0;

    // تطابق بعد التنظيف
    if (cleanCell == cleanKeyword) return 0.85;
    if (cleanCell.contains(cleanKeyword)) return 0.8;

    // تطابق الكلمات الفردية
    final cellWords = cleanCell.split('');
    final keywordWords = cleanKeyword.split('');

    if (cellWords.isNotEmpty && keywordWords.isNotEmpty) {
      // حساب نسبة التطابق بين الأحرف
      final similarity = _calculateStringSimilarity(cleanCell, cleanKeyword);
      if (similarity >= 0.7) return similarity * 0.75; // تقليل النقاط للتطابق الجزئي
    }

    // تطابق الاختصارات الشائعة
    final abbreviationScore = _checkAbbreviationMatch(cellValue, keyword);
    if (abbreviationScore > 0) return abbreviationScore;

    return 0.0;
  }

  /// حساب التشابه بين نصين باستخدام خوارزمية Levenshtein المبسطة
  static double _calculateStringSimilarity(String s1, String s2) {
    if (s1.isEmpty || s2.isEmpty) return 0.0;
    if (s1 == s2) return 1.0;

    final longer = s1.length > s2.length ? s1 : s2;
    final shorter = s1.length > s2.length ? s2 : s1;

    if (longer.length == 0) return 1.0;

    final editDistance = _calculateLevenshteinDistance(longer, shorter);
    return (longer.length - editDistance) / longer.length;
  }

  /// حساب مسافة Levenshtein بين نصين
  static int _calculateLevenshteinDistance(String s1, String s2) {
    final matrix = List.generate(s1.length + 1,
        (i) => List.generate(s2.length + 1, (j) => 0));

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
          matrix[i - 1][j - 1] + cost // substitution
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[s1.length][s2.length];
  }

  /// فحص تطابق الاختصارات الشائعة
  static double _checkAbbreviationMatch(String cellValue, String keyword) {
    final abbreviations = <String, List<String>>{
      'QTY': ['QUANTITY', 'TOTAL_QUANTITY', 'TOTALQTY'],
      'CTN': ['CARTON', 'CARTONS'],
      'NO': ['NUMBER', 'NUM'],
      'PC': ['PIECE', 'PIECES'],
      'RMB': ['YUAN', 'CNY'],
    };

    for (final entry in abbreviations.entries) {
      final abbr = entry.key;
      final fullForms = entry.value;

      if ((cellValue.contains(abbr) && fullForms.contains(keyword)) ||
          (keyword.contains(abbr) && fullForms.contains(cellValue))) {
        return 0.8;
      }
    }

    return 0.0;
  }

  /// ARABIC TEXT FIX: Normalize Arabic text for better matching
  static String _normalizeArabicText(String text) {
    if (text.isEmpty) return text;

    // Convert to uppercase for consistency
    String normalized = text.toUpperCase();

    // Normalize Arabic characters
    normalized = normalized
        // Normalize Alef variations
        .replaceAll(RegExp(r'[آأإ]'), 'ا')
        // Normalize Teh Marbuta
        .replaceAll('ة', 'ه')
        // Normalize Yeh variations
        .replaceAll('ي', 'ى')
        // Remove Arabic diacritics (Tashkeel)
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06ED]'), '')
        // Normalize spaces
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return normalized;
  }

  /// ARABIC TEXT FIX: Clean text for matching (supports Arabic)
  static String _cleanTextForMatching(String text) {
    if (text.isEmpty) return text;

    // Remove special characters but keep Arabic letters, numbers, and basic Latin
    return text
        .replaceAll(RegExp(r'[^\u0600-\u06FF\u0750-\u077F\w]'), '')
        .toLowerCase();
  }

  /// استخراج بيانات قائمة التعبئة - تحسين شامل لاستخراج جميع البيانات
  @visibleForTesting
  static List<Map<String, dynamic>> extractPackingListData(
    List<List<dynamic>> rawData,
    HeaderDetectionResult headerResult,
  ) {
    final extractedData = <Map<String, dynamic>>[];

    AppLogger.info('🔍 بدء استخراج البيانات الشامل من الصف ${headerResult.headerRow + 1} إلى ${rawData.length}');
    AppLogger.info('🗺️ خريطة الأعمدة: ${headerResult.mapping}');

    // طباعة صف الرؤوس للتشخيص
    if (headerResult.headerRow < rawData.length) {
      final headerRow = rawData[headerResult.headerRow];
      AppLogger.info('📋 صف الرؤوس (${headerResult.headerRow}): ${headerRow.take(15).toList()}');

      // طباعة تفصيلية للأعمدة المهمة
      for (final entry in headerResult.mapping.entries) {
        final fieldName = entry.key;
        final columnIndex = entry.value;
        if (columnIndex < headerRow.length) {
          final headerValue = headerRow[columnIndex];
          AppLogger.info('🎯 العمود $fieldName: الفهرس $columnIndex = "$headerValue"');
        }
      }
    }

    // تحديد الأعمدة المستهدفة للتحقق من البيانات
    final targetColumns = <String, int?>{
      'item_number': headerResult.mapping['item_number'],
      'carton_count': headerResult.mapping['carton_count'],
      'pieces_per_carton': headerResult.mapping['pieces_per_carton'],
      'total_quantity': headerResult.mapping['total_quantity'],
      'remarks_a': headerResult.mapping['remarks_a'],
    };

    AppLogger.info('🎯 الأعمدة المستهدفة: $targetColumns');

    // التحقق من وجود الأعمدة الأساسية
    final missingColumns = <String>[];
    if (targetColumns['item_number'] == null) missingColumns.add('ITEM NO');
    if (targetColumns['carton_count'] == null) missingColumns.add('CTN');
    if (targetColumns['pieces_per_carton'] == null) missingColumns.add('PC/CTN');
    if (targetColumns['total_quantity'] == null) missingColumns.add('QTY');
    if (targetColumns['remarks_a'] == null) missingColumns.add('REMARKS');

    if (missingColumns.isNotEmpty) {
      AppLogger.warning('⚠️ أعمدة مفقودة: ${missingColumns.join(', ')}');
    } else {
      AppLogger.info('✅ تم العثور على جميع الأعمدة الأساسية');
    }

    int consecutiveEmptyRows = 0;
    const maxConsecutiveEmptyRows = 50; // زيادة الحد الأقصى لضمان معالجة جميع الصفوف

    // بدء من الصف التالي لصف الرؤوس - معالجة جميع الصفوف بدون حدود
    for (int rowIndex = headerResult.headerRow + 1; rowIndex < rawData.length; rowIndex++) {
      final row = rawData[rowIndex];

      // فحص محسن للصفوف الفارغة - التركيز على الأعمدة المستهدفة فقط
      if (_isTargetDataRowEmpty(row, targetColumns)) {
        consecutiveEmptyRows++;
        AppLogger.info('⏭️ صف فارغ في الأعمدة المستهدفة $rowIndex (متتالية: $consecutiveEmptyRows)');

        // توقف فقط بعد عدة صفوف فارغة متتالية لضمان عدم تفويت البيانات
        // زيادة الحد لضمان معالجة جميع الصفوف في الملفات الكبيرة
        if (consecutiveEmptyRows >= maxConsecutiveEmptyRows) {
          AppLogger.info('🛑 توقف الاستخراج بعد $consecutiveEmptyRows صف فارغ متتالي في الصف $rowIndex');
          AppLogger.info('📊 تم معالجة ${rowIndex - headerResult.headerRow - 1} صف من أصل ${rawData.length - headerResult.headerRow - 1} صف متاح');
          break;
        }
        continue;
      }

      // إعادة تعيين عداد الصفوف الفارغة المتتالية
      consecutiveEmptyRows = 0;

      // تسجيل معلومات الصف للتشخيص
      final nonEmptyCells = row.where((cell) => cell.toString().trim().isNotEmpty).length;
      final targetDataCells = _countTargetDataCells(row, targetColumns);
      AppLogger.info('🔍 معالجة الصف $rowIndex - خلايا غير فارغة: $nonEmptyCells من ${row.length} | بيانات مستهدفة: $targetDataCells');

      final itemData = <String, dynamic>{};

      // استخراج البيانات بناءً على الخريطة المكتشفة
      for (final entry in headerResult.mapping.entries) {
        final fieldName = entry.key;
        final columnIndex = entry.value;

        if (columnIndex < row.length) {
          final cellValue = row[columnIndex];
          final parsedValue = _parseFieldValue(fieldName, cellValue);
          itemData[fieldName] = parsedValue;

          // طباعة تفصيلية للحقول المهمة
          if (['item_number', 'total_quantity', 'carton_count', 'pieces_per_carton', 'remarks_a'].contains(fieldName)) {
            AppLogger.info('📊 الصف $rowIndex - $fieldName: "$cellValue" → $parsedValue');
          }
        }
      }

      // طباعة أول 5 عناصر للتشخيص
      if (extractedData.length < 5) {
        AppLogger.info('📦 الصف $rowIndex البيانات المستخرجة: ${itemData}');
      }

      // التحقق من وجود البيانات الأساسية المطلوبة
      if (isValidPackingItem(itemData)) {
        // التحقق من وجود منتجات متعددة في خانة رقم الصنف
        final multipleItems = _splitMultiProductCell(itemData, rowIndex);

        if (multipleItems.length > 1) {
          // إضافة جميع المنتجات المنفصلة
          for (int i = 0; i < multipleItems.length; i++) {
            final splitItem = multipleItems[i];
            splitItem['temp_id'] = 'temp_${DateTime.now().millisecondsSinceEpoch}_${rowIndex}_$i';
            splitItem['row_number'] = rowIndex + 1;

            extractedData.add(splitItem);
            AppLogger.info('✅ الصف $rowIndex منتج ${i + 1}/${multipleItems.length} - رقم الصنف: "${splitItem['item_number']}", الكمية: ${splitItem['total_quantity']}');
          }
        } else {
          // منتج واحد فقط
          itemData['temp_id'] = 'temp_${DateTime.now().millisecondsSinceEpoch}_$rowIndex';
          itemData['row_number'] = rowIndex + 1;

          extractedData.add(itemData);
          AppLogger.info('✅ الصف $rowIndex صالح - رقم الصنف: "${itemData['item_number']}", الكمية: ${itemData['total_quantity']}');
        }
      } else {
        // تسجيل تفصيلي لسبب رفض الصف
        _logRowRejectionReason(rowIndex, itemData, row);
      }
    }

    final totalDataRows = rawData.length - headerResult.headerRow - 1;
    final skippedRows = totalDataRows - extractedData.length;

    AppLogger.info('🎯 ملخص الاستخراج الشامل للبيانات:');
    AppLogger.info('   📊 إجمالي الصفوف في الملف: ${rawData.length}');
    AppLogger.info('   📋 صف الرؤوس المكتشف: ${headerResult.headerRow}');
    AppLogger.info('   📈 صفوف البيانات المتاحة للمعالجة: $totalDataRows');
    AppLogger.info('   ✅ عناصر مستخرجة صالحة: ${extractedData.length}');
    AppLogger.info('   ❌ صفوف مُتخطاة (فارغة أو غير صالحة): $skippedRows');
    AppLogger.info('   📊 معدل الاستخراج الشامل: ${totalDataRows > 0 ? ((extractedData.length / totalDataRows) * 100).toStringAsFixed(1) : 0}%');

    // تحذير إذا كان هناك عدد كبير من الصفوف المتخطاة
    if (skippedRows > totalDataRows * 0.3) {
      AppLogger.warning('⚠️ تم تخطي أكثر من 30% من الصفوف - قد تحتاج لمراجعة معايير التحقق من صحة البيانات');
    }

    // تأكيد معالجة جميع الصفوف المطلوبة
    if (totalDataRows >= 145 && extractedData.length < 100) {
      AppLogger.warning('⚠️ الملف يحتوي على ${totalDataRows} صف لكن تم استخراج ${extractedData.length} عنصر فقط - قد تحتاج لمراجعة معايير الاستخراج');
    }

    if (extractedData.length == totalDataRows) {
      AppLogger.info('🎉 تم استخراج جميع البيانات بنجاح - لا توجد صفوف مفقودة!');
    } else if (skippedRows > 0) {
      AppLogger.warning('⚠️ تم تخطي $skippedRows صف - قد تحتوي على بيانات جزئية أو تنسيق غير متوقع');
    }

    // طباعة ملخص العناصر المستخرجة
    if (extractedData.isNotEmpty) {
      AppLogger.info('📋 ملخص العناصر المستخرجة:');
      for (int i = 0; i < extractedData.length && i < 5; i++) {
        final item = extractedData[i];
        AppLogger.info('   العنصر ${i + 1}: رقم="${item['item_number']}", كمية=${item['total_quantity']}, كراتين=${item['carton_count']}, صف=${item['row_number']}');
      }

      if (extractedData.length > 5) {
        AppLogger.info('   ... و ${extractedData.length - 5} عنصر إضافي');
      }
    } else {
      AppLogger.warning('⚠️ لم يتم استخراج أي عناصر صالحة من الملف!');
    }

    // التحقق الشامل من صحة البيانات المستخرجة
    final validationResult = _validateExtractedData(extractedData, rawData.length, headerResult);
    AppLogger.info('📊 نتيجة التحقق من البيانات: ${validationResult}');

    return extractedData;
  }

  /// تقسيم الخلايا التي تحتوي على منتجات متعددة في رقم الصنف
  static List<Map<String, dynamic>> _splitMultiProductCell(Map<String, dynamic> itemData, int rowIndex) {
    final itemNumber = itemData['item_number']?.toString() ?? '';

    // أنماط الفصل الشائعة للمنتجات المتعددة
    final separators = [
      '\n',           // سطر جديد
      '/',            // شرطة مائلة
      '&',            // علامة العطف
      '+',            // علامة الجمع
      ',',            // فاصلة
      ';',            // فاصلة منقوطة
      '|',            // خط عمودي
    ];

    // البحث عن فاصل في رقم الصنف
    String? foundSeparator;
    for (final separator in separators) {
      if (itemNumber.contains(separator)) {
        foundSeparator = separator;
        break;
      }
    }

    // إذا لم يتم العثور على فاصل، إرجاع المنتج كما هو
    if (foundSeparator == null) {
      return [itemData];
    }

    // تقسيم رقم الصنف
    final itemNumbers = itemNumber
        .split(foundSeparator)
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();

    // إذا كان هناك منتج واحد فقط بعد التقسيم، إرجاع المنتج كما هو
    if (itemNumbers.length <= 1) {
      return [itemData];
    }

    AppLogger.info('🔄 الصف $rowIndex: تم اكتشاف ${itemNumbers.length} منتجات في رقم الصنف: ${itemNumbers.join(', ')}');

    // إنشاء منتجات منفصلة
    final splitItems = <Map<String, dynamic>>[];
    final totalQuantity = itemData['total_quantity'] as int? ?? 0;
    final cartonCount = itemData['carton_count'] as int? ?? 0;
    final piecesPerCarton = itemData['pieces_per_carton'] as int? ?? 0;

    // توزيع الكميات بالتساوي على المنتجات مع ضمان قيم صحيحة
    final quantityPerItem = totalQuantity > 0 ? (totalQuantity / itemNumbers.length).round() : 1;
    final cartonsPerItem = cartonCount > 0 ? (cartonCount / itemNumbers.length).round() : 0;

    for (int i = 0; i < itemNumbers.length; i++) {
      final splitItem = Map<String, dynamic>.from(itemData);

      // تحديث رقم الصنف
      splitItem['item_number'] = itemNumbers[i];

      // توزيع الكميات مع ضمان قيم صحيحة
      if (i == itemNumbers.length - 1) {
        // المنتج الأخير يحصل على الباقي لتجنب فقدان الكميات بسبب التقريب
        final remainingQuantity = totalQuantity - (quantityPerItem * (itemNumbers.length - 1));
        final remainingCartons = cartonCount - (cartonsPerItem * (itemNumbers.length - 1));

        splitItem['total_quantity'] = remainingQuantity > 0 ? remainingQuantity : 1;
        splitItem['carton_count'] = remainingCartons > 0 ? remainingCartons : 0;
      } else {
        splitItem['total_quantity'] = quantityPerItem;
        splitItem['carton_count'] = cartonsPerItem;
      }

      // الاحتفاظ بنفس قيمة القطع لكل كرتون
      splitItem['pieces_per_carton'] = piecesPerCarton;

      // إضافة معلومات التقسيم في metadata لتجنب مشاكل قاعدة البيانات
      final metadata = splitItem['metadata'] as Map<String, dynamic>? ?? {};
      metadata['original_item_number'] = itemNumber;
      metadata['split_separator'] = foundSeparator;
      metadata['is_split_product'] = true;
      metadata['split_index'] = i + 1;
      metadata['total_splits'] = itemNumbers.length;
      splitItem['metadata'] = metadata;

      splitItems.add(splitItem);

      AppLogger.info('   منتج ${i + 1}: "${itemNumbers[i]}" - كمية: ${splitItem['total_quantity']}, كراتين: ${splitItem['carton_count']}');
    }

    return splitItems;
  }

  /// تحليل قيمة الحقل بناءً على نوعه - عرض القيم الخام بدون عمليات حسابية
  static dynamic _parseFieldValue(String fieldName, dynamic cellValue) {
    final stringValue = cellValue.toString().trim();

    if (stringValue.isEmpty) return null;

    // الحقول التي تتطلب عرض القيم الخام بدون تعديل
    if ([
      'total_quantity', 'carton_count', 'pieces_per_carton'
    ].contains(fieldName)) {
      return _parseRawIntegerValue(stringValue);
    }

    // الحقول الرقمية الأخرى (مع معالجة محدودة)
    if ([
      'serial_number'
    ].contains(fieldName)) {
      return _parseIntegerValue(stringValue);
    }

    // الحقول العشرية
    if ([
      'size1', 'size2', 'size3', 'total_cubic_meters',
      'net_weight', 'gross_weight', 'total_net_weight', 'total_gross_weight',
      'unit_price', 'rmb_price'
    ].contains(fieldName)) {
      return _parseDoubleValue(stringValue);
    }

    // الحقول النصية
    return stringValue;
  }

  /// تحليل القيم الخام للأعداد الصحيحة بدون عمليات حسابية - عرض القيمة كما هي في Excel
  static int? _parseRawIntegerValue(String value) {
    if (value.isEmpty) return null;

    // إزالة المسافات فقط والاحتفاظ بالقيمة كما هي
    String cleaned = value.trim();

    // إزالة الفواصل فقط إذا كانت فواصل آلاف واضحة
    if (cleaned.contains(',') && !cleaned.contains('.')) {
      cleaned = cleaned.replaceAll(',', '');
    }

    // محاولة تحويل مباشر بدون تعديلات إضافية
    final intValue = int.tryParse(cleaned);
    if (intValue != null) {
      return intValue;
    }

    // إذا فشل التحويل المباشر، محاولة تحويل من عشري إلى صحيح
    final doubleValue = double.tryParse(cleaned);
    if (doubleValue != null) {
      return doubleValue.toInt(); // تحويل مباشر بدون تقريب
    }

    // إذا فشل كل شيء، إرجاع null مع تسجيل تفصيلي
    AppLogger.warning('⚠️ فشل في تحليل القيمة الخام: "$value" → "$cleaned"');
    return null;
  }

  /// تحليل القيم الصحيحة مع معالجة متقدمة للتنسيقات المختلفة
  static int? _parseIntegerValue(String value) {
    if (value.isEmpty) return null;

    // إزالة المسافات والفواصل والرموز غير الرقمية
    String cleaned = value
        .replaceAll(RegExp(r'[^\d.,\-+]'), '') // الاحتفاظ بالأرقام والفواصل والإشارات
        .replaceAll(',', '') // إزالة الفواصل (thousands separator)
        .trim();

    if (cleaned.isEmpty) return null;

    // معالجة الأرقام العشرية (تحويل إلى صحيح)
    if (cleaned.contains('.')) {
      final doubleValue = double.tryParse(cleaned);
      return doubleValue?.round();
    }

    // معالجة الأرقام الصحيحة
    return int.tryParse(cleaned);
  }

  /// تحليل القيم العشرية مع معالجة متقدمة للتنسيقات المختلفة وحماية من تجاوز حدود قاعدة البيانات
  static double? _parseDoubleValue(String value) {
    if (value.isEmpty) return null;

    // إزالة المسافات والرموز غير الرقمية (الاحتفاظ بالنقطة العشرية)
    String cleaned = value
        .replaceAll(RegExp(r'[^\d.,\-+]'), '') // الاحتفاظ بالأرقام والفواصل والإشارات
        .replaceAll(',', '.') // تحويل الفاصلة إلى نقطة عشرية
        .trim();

    if (cleaned.isEmpty) return null;

    // معالجة النقاط المتعددة (الاحتفاظ بالأخيرة فقط كنقطة عشرية)
    final parts = cleaned.split('.');
    if (parts.length > 2) {
      // إذا كان هناك أكثر من نقطة، اعتبر الأخيرة نقطة عشرية والباقي فواصل آلاف
      final integerPart = parts.sublist(0, parts.length - 1).join('');
      final decimalPart = parts.last;
      cleaned = '$integerPart.$decimalPart';
    }

    final parsedValue = double.tryParse(cleaned);
    if (parsedValue == null) return null;

    // التحقق من حدود قاعدة البيانات DECIMAL(15,6) - الحد الأقصى: 999999999.999999
    const maxValue = 999999999.999999;
    const minValue = -999999999.999999;

    if (parsedValue > maxValue) {
      AppLogger.warning('قيمة تتجاوز الحد الأقصى لقاعدة البيانات: $parsedValue > $maxValue، سيتم تقليلها');
      return maxValue;
    } else if (parsedValue < minValue) {
      AppLogger.warning('قيمة تقل عن الحد الأدنى لقاعدة البيانات: $parsedValue < $minValue، سيتم زيادتها');
      return minValue;
    }

    return parsedValue;
  }

  /// التحقق من صحة عنصر قائمة التعبئة - تحسين شامل لاستخراج جميع البيانات
  @visibleForTesting
  static bool isValidPackingItem(Map<String, dynamic> itemData) {
    // التحقق من وجود أي بيانات مفيدة في الصف - منطق شامل ومرن جداً
    final itemNumber = itemData['item_number']?.toString().trim();
    final quantity = itemData['total_quantity'];
    final cartonCount = itemData['carton_count'];
    final piecesPerCarton = itemData['pieces_per_carton'];
    final remarks = itemData['remarks_a']?.toString().trim();
    final serialNumber = itemData['serial_number'];
    final imageUrl = itemData['image_url']?.toString().trim();

    // الشروط الشاملة للتحقق من صحة العنصر - قبول أي بيانات مفيدة:
    // 1. رقم صنف غير فارغ
    // 2. كمية صحيحة (أي رقم أكبر من صفر)
    // 3. بيانات كراتين (عدد كراتين أو قطع لكل كرتون)
    // 4. ملاحظات مفيدة (أكثر من حرفين)
    // 5. رقم تسلسلي
    // 6. رابط صورة

    final hasValidItemNumber = itemNumber != null && itemNumber.isNotEmpty && itemNumber != '-';
    final hasValidQuantity = quantity != null &&
                            ((quantity is int && quantity > 0) ||
                             (quantity is double && quantity > 0));
    final hasValidCartonCount = cartonCount != null &&
                               ((cartonCount is int && cartonCount > 0) ||
                                (cartonCount is double && cartonCount > 0));
    final hasValidPiecesPerCarton = piecesPerCarton != null &&
                                   ((piecesPerCarton is int && piecesPerCarton > 0) ||
                                    (piecesPerCarton is double && piecesPerCarton > 0));
    final hasValidRemarks = remarks != null && remarks.isNotEmpty && remarks.length > 2 && remarks != '-';
    final hasValidSerialNumber = serialNumber != null &&
                                ((serialNumber is int && serialNumber > 0) ||
                                 (serialNumber is double && serialNumber > 0));
    final hasValidImageUrl = imageUrl != null && imageUrl.isNotEmpty && imageUrl != '-';

    // العنصر صالح إذا كان يحتوي على أي من البيانات المفيدة - منطق شامل
    final isValid = hasValidItemNumber || hasValidQuantity || hasValidCartonCount ||
                   hasValidPiecesPerCarton || hasValidRemarks || hasValidSerialNumber || hasValidImageUrl;

    if (!isValid) {
      AppLogger.warning('عنصر غير صالح - رقم الصنف: "$itemNumber", الكمية: $quantity (${quantity.runtimeType}), كراتين: $cartonCount, قطع/كرتون: $piecesPerCarton, ملاحظات: "$remarks", رقم تسلسلي: $serialNumber, صورة: "$imageUrl"');
    } else {
      final truncatedRemarks = remarks != null && remarks.length > 50
          ? '${remarks.substring(0, 50)}...'
          : remarks ?? '';
      AppLogger.info('عنصر صالح - رقم الصنف: "$itemNumber", الكمية: $quantity, كراتين: $cartonCount, ملاحظات: "$truncatedRemarks"');
    }

    return isValid;
  }

  /// التحقق من كون الصف فارغ تماماً - منطق محسن
  static bool _isRowCompletelyEmpty(List<dynamic> row) {
    if (row.isEmpty) return true;

    // التحقق من كل خلية في الصف
    for (final cell in row) {
      final cellValue = cell.toString().trim();

      // إذا كانت الخلية تحتوي على أي محتوى مفيد، فالصف ليس فارغاً
      if (cellValue.isNotEmpty &&
          cellValue != '0' &&
          cellValue != '-' &&
          cellValue != 'null' &&
          cellValue != 'NULL') {
        return false;
      }
    }

    return true;
  }

  /// فحص محسن للصفوف الفارغة - التركيز على الأعمدة المستهدفة فقط
  static bool _isTargetDataRowEmpty(List<dynamic> row, Map<String, int?> targetColumns) {
    if (row.isEmpty) return true;

    // فحص الأعمدة المستهدفة فقط: ITEM NO., ctn, pc/ctn, QTY, REMARKS
    for (final entry in targetColumns.entries) {
      final columnIndex = entry.value;
      if (columnIndex != null && columnIndex < row.length) {
        final cellValue = row[columnIndex].toString().trim();

        // إذا وجدت أي بيانات مفيدة في الأعمدة المستهدفة، فالصف ليس فارغاً
        if (cellValue.isNotEmpty &&
            cellValue != '0' &&
            cellValue != '-' &&
            cellValue != 'null' &&
            cellValue != 'NULL' &&
            cellValue != 'n/a' &&
            cellValue != 'N/A') {
          return false;
        }
      }
    }

    return true;
  }

  /// عد الخلايا التي تحتوي على بيانات في الأعمدة المستهدفة
  static int _countTargetDataCells(List<dynamic> row, Map<String, int?> targetColumns) {
    int count = 0;

    for (final entry in targetColumns.entries) {
      final columnIndex = entry.value;
      if (columnIndex != null && columnIndex < row.length) {
        final cellValue = row[columnIndex].toString().trim();

        if (cellValue.isNotEmpty &&
            cellValue != '0' &&
            cellValue != '-' &&
            cellValue != 'null' &&
            cellValue != 'NULL' &&
            cellValue != 'n/a' &&
            cellValue != 'N/A') {
          count++;
        }
      }
    }

    return count;
  }

  /// تسجيل تفصيلي لسبب رفض الصف
  static void _logRowRejectionReason(int rowIndex, Map<String, dynamic> itemData, List<dynamic> rawRow) {
    final itemNumber = itemData['item_number']?.toString().trim();
    final quantity = itemData['total_quantity'];
    final cartonCount = itemData['carton_count'];
    final piecesPerCarton = itemData['pieces_per_carton'];
    final remarks = itemData['remarks_a']?.toString().trim();

    final reasons = <String>[];

    if (itemNumber == null || itemNumber.isEmpty) {
      reasons.add('رقم الصنف فارغ');
    }

    if (quantity == null || (quantity is! int && quantity is! double) || (quantity is num && quantity <= 0)) {
      reasons.add('الكمية غير صالحة ($quantity - ${quantity.runtimeType})');
    }

    if ((cartonCount == null || cartonCount is! int || cartonCount <= 0) &&
        (piecesPerCarton == null || piecesPerCarton is! int || piecesPerCarton <= 0)) {
      reasons.add('بيانات الكراتين غير صالحة');
    }

    if (remarks == null || remarks.isEmpty || remarks.length <= 2) {
      reasons.add('ملاحظات غير مفيدة');
    }

    final nonEmptyCells = rawRow.where((cell) => cell.toString().trim().isNotEmpty).length;

    AppLogger.warning('❌ الصف $rowIndex مرفوض - الأسباب: ${reasons.join(', ')} | خلايا غير فارغة: $nonEmptyCells/${rawRow.length}');
    AppLogger.info('   📋 البيانات الخام: ${rawRow.take(10).toList()}');
    AppLogger.info('   🔍 البيانات المستخرجة: $itemData');
  }

  /// التحقق الشامل من صحة البيانات المستخرجة
  static Map<String, dynamic> _validateExtractedData(
    List<Map<String, dynamic>> extractedData,
    int totalRawRows,
    HeaderDetectionResult headerResult,
  ) {
    final validation = <String, dynamic>{
      'total_raw_rows': totalRawRows,
      'header_row': headerResult.headerRow,
      'data_rows_available': totalRawRows - headerResult.headerRow - 1,
      'extracted_items': extractedData.length,
      'extraction_rate': 0.0,
      'column_mapping_issues': <String>[],
      'data_quality_issues': <String>[],
      'quantity_validation': <String, dynamic>{},
      'materials_validation': <String, dynamic>{},
    };

    final dataRowsAvailable = totalRawRows - headerResult.headerRow - 1;
    if (dataRowsAvailable > 0) {
      validation['extraction_rate'] = (extractedData.length / dataRowsAvailable * 100);
    }

    // التحقق من خريطة الأعمدة
    final requiredColumns = ['item_number', 'total_quantity', 'carton_count', 'pieces_per_carton'];
    final missingColumns = <String>[];

    for (final column in requiredColumns) {
      if (!headerResult.mapping.containsKey(column)) {
        missingColumns.add(column);
      }
    }

    if (missingColumns.isNotEmpty) {
      validation['column_mapping_issues'].add('أعمدة مفقودة: ${missingColumns.join(', ')}');
    }

    // التحقق من جودة البيانات
    int itemsWithQuantity = 0;
    int itemsWithCartons = 0;
    int itemsWithPiecesPerCarton = 0;
    int itemsWithMaterials = 0;
    final quantityIssues = <String>[];

    for (int i = 0; i < extractedData.length; i++) {
      final item = extractedData[i];

      // التحقق من الكمية
      final quantity = item['total_quantity'];
      if (quantity != null && quantity > 0) {
        itemsWithQuantity++;
      } else {
        quantityIssues.add('العنصر ${i + 1}: كمية غير صحيحة ($quantity)');
      }

      // التحقق من الكراتين
      if (item['carton_count'] != null && item['carton_count'] > 0) {
        itemsWithCartons++;
      }

      // التحقق من القطع لكل كرتون
      if (item['pieces_per_carton'] != null && item['pieces_per_carton'] > 0) {
        itemsWithPiecesPerCarton++;
      }

      // التحقق من المواد
      final remarks = item['remarks_a']?.toString() ?? '';
      if (remarks.isNotEmpty) {
        itemsWithMaterials++;
      }
    }

    // إحصائيات التحقق من الكمية
    validation['quantity_validation'] = {
      'items_with_quantity': itemsWithQuantity,
      'items_with_cartons': itemsWithCartons,
      'items_with_pieces_per_carton': itemsWithPiecesPerCarton,
      'quantity_coverage': extractedData.isNotEmpty ? (itemsWithQuantity / extractedData.length * 100) : 0,
      'carton_coverage': extractedData.isNotEmpty ? (itemsWithCartons / extractedData.length * 100) : 0,
      'pieces_coverage': extractedData.isNotEmpty ? (itemsWithPiecesPerCarton / extractedData.length * 100) : 0,
      'issues': quantityIssues.take(5).toList(),
    };

    // إحصائيات المواد
    validation['materials_validation'] = {
      'items_with_materials': itemsWithMaterials,
      'materials_coverage': extractedData.isNotEmpty ? (itemsWithMaterials / extractedData.length * 100) : 0,
    };

    // تقييم عام لجودة البيانات
    if (validation['extraction_rate'] < 50) {
      validation['data_quality_issues'].add('معدل استخراج منخفض: ${validation['extraction_rate'].toStringAsFixed(1)}%');
    }

    if (validation['quantity_validation']['quantity_coverage'] < 80) {
      validation['data_quality_issues'].add('تغطية الكمية منخفضة: ${validation['quantity_validation']['quantity_coverage'].toStringAsFixed(1)}%');
    }

    return validation;
  }
}

/// بيانات Isolate للمعالجة في الخلفية
class IsolateParsingData {
  final String filePath;
  final SupportedFileType fileType;
  final SendPort sendPort;

  const IsolateParsingData({
    required this.filePath,
    required this.fileType,
    required this.sendPort,
  });
}

/// نتيجة كشف الرؤوس
class HeaderDetectionResult {
  final int headerRow;
  final Map<String, int> mapping;
  final double confidence;
  final List<String> detectedHeaders;

  const HeaderDetectionResult({
    required this.headerRow,
    required this.mapping,
    required this.confidence,
    required this.detectedHeaders,
  });
}

/// نتيجة معالجة Excel
class ExcelParsingResult {
  final List<Map<String, dynamic>> data;
  final Map<String, int> headerMapping;
  final int totalRows;
  final int dataRows;
  final double detectionConfidence;
  final DateTime processingTime;

  const ExcelParsingResult({
    required this.data,
    required this.headerMapping,
    required this.totalRows,
    required this.dataRows,
    required this.detectionConfidence,
    required this.processingTime,
  });

  Map<String, dynamic> toJson() {
    return {
      'data': data,
      'header_mapping': headerMapping,
      'total_rows': totalRows,
      'data_rows': dataRows,
      'detection_confidence': detectionConfidence,
      'processing_time': processingTime.toIso8601String(),
    };
  }

  factory ExcelParsingResult.fromJson(Map<String, dynamic> json) {
    return ExcelParsingResult(
      data: (json['data'] as List<dynamic>).cast<Map<String, dynamic>>(),
      headerMapping: Map<String, int>.from(json['header_mapping']),
      totalRows: json['total_rows'] as int,
      dataRows: json['data_rows'] as int,
      detectionConfidence: (json['detection_confidence'] as num).toDouble(),
      processingTime: DateTime.parse(json['processing_time'] as String),
    );
  }
}

/// استثناء معالجة Excel
class ExcelParsingException implements Exception {
  final String message;
  final ExcelParsingErrorType errorType;

  const ExcelParsingException(this.message, this.errorType);

  @override
  String toString() => 'ExcelParsingException: $message';
}

/// أنواع أخطاء معالجة Excel
enum ExcelParsingErrorType {
  fileSizeExceeded,
  invalidFormat,
  emptyFile,
  headersNotFound,
  processingError,
  insufficientData,
  dataExtractionError,
  fileNotFound,
}
