import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:smartbiztracker_new/models/manufacturing/production_batch.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// خدمة تصدير تقارير أدوات التصنيع
class ManufacturingToolsExportService {
  static const String _csvSeparator = ',';
  static const String _jsonIndent = '  ';

  /// تصدير تحليلات استخدام الأدوات إلى CSV
  Future<String> exportToolUsageAnalyticsToCSV(
    List<ToolUsageAnalytics> analytics,
    int batchId,
  ) async {
    try {
      AppLogger.info('📊 Exporting tool usage analytics to CSV for batch: $batchId');

      final buffer = StringBuffer();
      
      // إضافة العنوان
      buffer.writeln('تقرير استخدام أدوات التصنيع - دفعة رقم $batchId');
      buffer.writeln('تاريخ التصدير: ${DateTime.now().toLocal().toString().split('.')[0]}');
      buffer.writeln('');
      
      // إضافة رؤوس الأعمدة
      buffer.writeln([
        'معرف الأداة',
        'اسم الأداة',
        'الوحدة',
        'الكمية لكل وحدة منتجة',
        'إجمالي الكمية المستخدمة',
        'المخزون المتبقي',
        'المخزون الأولي',
        'نسبة الاستهلاك (%)',
        'حالة المخزون',
      ].map(_escapeCsvField).join(_csvSeparator));

      // إضافة البيانات
      for (final analytic in analytics) {
        buffer.writeln([
          analytic.toolId.toString(),
          analytic.toolName,
          analytic.unit,
          analytic.quantityUsedPerUnit.toStringAsFixed(2),
          analytic.totalQuantityUsed.toStringAsFixed(2),
          analytic.remainingStock.toStringAsFixed(2),
          analytic.initialStock.toStringAsFixed(2),
          analytic.usagePercentage.toStringAsFixed(2),
          analytic.stockStatusText,
        ].map(_escapeCsvField).join(_csvSeparator));
      }

      // إضافة ملخص
      buffer.writeln('');
      buffer.writeln('ملخص التقرير:');
      buffer.writeln('عدد الأدوات المستخدمة,${ analytics.length}');
      
      final totalUsed = analytics.fold<double>(0, (sum, a) => sum + a.totalQuantityUsed);
      buffer.writeln('إجمالي الكمية المستخدمة,${totalUsed.toStringAsFixed(2)}');
      
      final avgUsage = analytics.isNotEmpty 
          ? analytics.fold<double>(0, (sum, a) => sum + a.usagePercentage) / analytics.length
          : 0.0;
      buffer.writeln('متوسط نسبة الاستهلاك,${avgUsage.toStringAsFixed(2)}%');

      AppLogger.info('✅ CSV export completed successfully');
      return buffer.toString();
    } catch (e) {
      AppLogger.error('❌ Error exporting tool usage analytics to CSV: $e');
      throw Exception('فشل في تصدير البيانات إلى CSV: $e');
    }
  }

  /// تصدير تحليل فجوة الإنتاج إلى JSON
  Future<String> exportProductionGapAnalysisToJSON(
    ProductionGapAnalysis gapAnalysis,
    int batchId,
  ) async {
    try {
      AppLogger.info('📊 Exporting production gap analysis to JSON for batch: $batchId');

      final data = {
        'report_info': {
          'title': 'تقرير تحليل فجوة الإنتاج',
          'batch_id': batchId,
          'export_date': DateTime.now().toIso8601String(),
          'product_id': gapAnalysis.productId,
          'product_name': gapAnalysis.productName,
        },
        'gap_analysis': gapAnalysis.toJson(),
        'summary': {
          'completion_status': gapAnalysis.statusText,
          'is_completed': gapAnalysis.isCompleted,
          'is_over_produced': gapAnalysis.isOverProduced,
          'completion_percentage': gapAnalysis.completionPercentage,
          'remaining_pieces_description': gapAnalysis.remainingPiecesText,
        },
      };

      final jsonString = const JsonEncoder.withIndent(_jsonIndent).convert(data);
      
      AppLogger.info('✅ JSON export completed successfully');
      return jsonString;
    } catch (e) {
      AppLogger.error('❌ Error exporting production gap analysis to JSON: $e');
      throw Exception('فشل في تصدير البيانات إلى JSON: $e');
    }
  }

  /// تصدير توقعات الأدوات المطلوبة إلى CSV
  Future<String> exportRequiredToolsForecastToCSV(
    RequiredToolsForecast forecast,
    int productId,
  ) async {
    try {
      AppLogger.info('📊 Exporting required tools forecast to CSV for product: $productId');

      final buffer = StringBuffer();
      
      // إضافة العنوان
      buffer.writeln('تقرير توقعات الأدوات المطلوبة - منتج رقم $productId');
      buffer.writeln('تاريخ التصدير: ${DateTime.now().toLocal().toString().split('.')[0]}');
      buffer.writeln('القطع المتبقية: ${forecast.remainingPieces.toStringAsFixed(0)}');
      buffer.writeln('يمكن إكمال الإنتاج: ${forecast.canCompleteProduction ? "نعم" : "لا"}');
      buffer.writeln('');
      
      // إضافة رؤوس الأعمدة
      buffer.writeln([
        'معرف الأداة',
        'اسم الأداة',
        'الوحدة',
        'الكمية لكل وحدة',
        'إجمالي الكمية المطلوبة',
        'المخزون المتوفر',
        'النقص',
        'متوفر',
        'حالة التوفر',
        'التكلفة المتوقعة',
      ].map(_escapeCsvField).join(_csvSeparator));

      // إضافة البيانات
      for (final tool in forecast.requiredTools) {
        buffer.writeln([
          tool.toolId.toString(),
          tool.toolName,
          tool.unit,
          tool.quantityPerUnit.toStringAsFixed(2),
          tool.totalQuantityNeeded.toStringAsFixed(2),
          tool.availableStock.toStringAsFixed(2),
          tool.shortfall.toStringAsFixed(2),
          tool.isAvailable ? 'نعم' : 'لا',
          tool.availabilityText,
          tool.estimatedCost?.toStringAsFixed(2) ?? 'غير محدد',
        ].map(_escapeCsvField).join(_csvSeparator));
      }

      // إضافة ملخص
      buffer.writeln('');
      buffer.writeln('ملخص التقرير:');
      buffer.writeln('عدد الأدوات المطلوبة,${forecast.toolsCount}');
      buffer.writeln('عدد الأدوات غير المتوفرة,${forecast.unavailableToolsCount}');
      buffer.writeln('إجمالي التكلفة المتوقعة,${forecast.totalCost.toStringAsFixed(2)} ريال');

      if (forecast.hasUnavailableTools) {
        buffer.writeln('');
        buffer.writeln('الأدوات غير المتوفرة:');
        for (final toolName in forecast.unavailableTools) {
          buffer.writeln(toolName);
        }
      }

      AppLogger.info('✅ CSV export completed successfully');
      return buffer.toString();
    } catch (e) {
      AppLogger.error('❌ Error exporting required tools forecast to CSV: $e');
      throw Exception('فشل في تصدير البيانات إلى CSV: $e');
    }
  }

  /// تصدير تقرير شامل لجميع بيانات أدوات التصنيع
  Future<String> exportComprehensiveReportToJSON({
    required int batchId,
    required int productId,
    required List<ToolUsageAnalytics> toolAnalytics,
    required ProductionGapAnalysis? gapAnalysis,
    required RequiredToolsForecast? forecast,
  }) async {
    try {
      AppLogger.info('📊 Exporting comprehensive manufacturing tools report');

      final data = {
        'report_info': {
          'title': 'تقرير شامل لأدوات التصنيع',
          'batch_id': batchId,
          'product_id': productId,
          'export_date': DateTime.now().toIso8601String(),
          'report_version': '1.0',
        },
        'tool_usage_analytics': {
          'count': toolAnalytics.length,
          'data': toolAnalytics.map((a) => a.toJson()).toList(),
          'summary': {
            'total_tools_used': toolAnalytics.length,
            'total_quantity_consumed': toolAnalytics.fold<double>(0, (sum, a) => sum + a.totalQuantityUsed),
            'average_usage_percentage': toolAnalytics.isNotEmpty 
                ? toolAnalytics.fold<double>(0, (sum, a) => sum + a.usagePercentage) / toolAnalytics.length
                : 0.0,
          },
        },
        'production_gap_analysis': gapAnalysis?.toJson(),
        'required_tools_forecast': forecast?.toJson(),
        'export_metadata': {
          'exported_by': 'SmartBizTracker Manufacturing Tools Module',
          'export_timestamp': DateTime.now().millisecondsSinceEpoch,
          'data_integrity_hash': _generateDataHash(toolAnalytics, gapAnalysis, forecast),
        },
      };

      final jsonString = const JsonEncoder.withIndent(_jsonIndent).convert(data);
      
      AppLogger.info('✅ Comprehensive JSON export completed successfully');
      return jsonString;
    } catch (e) {
      AppLogger.error('❌ Error exporting comprehensive report to JSON: $e');
      throw Exception('فشل في تصدير التقرير الشامل: $e');
    }
  }

  /// حفظ ومشاركة ملف التصدير
  Future<void> saveAndShareExport({
    required String content,
    required String fileName,
    required String mimeType,
  }) async {
    try {
      AppLogger.info('💾 Saving and sharing export file: $fileName');

      if (kIsWeb) {
        // للويب - استخدام التحميل المباشر
        await _downloadForWeb(content, fileName, mimeType);
      } else {
        // للموبايل - حفظ ومشاركة
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$fileName');
        await file.writeAsString(content, encoding: utf8);
        
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'تقرير أدوات التصنيع - SmartBizTracker',
        );
      }

      AppLogger.info('✅ Export file saved and shared successfully');
    } catch (e) {
      AppLogger.error('❌ Error saving and sharing export file: $e');
      throw Exception('فشل في حفظ ومشاركة الملف: $e');
    }
  }

  /// تنظيف حقل CSV من الأحرف الخاصة
  String _escapeCsvField(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  /// إنشاء hash للتحقق من سلامة البيانات
  String _generateDataHash(
    List<ToolUsageAnalytics> analytics,
    ProductionGapAnalysis? gapAnalysis,
    RequiredToolsForecast? forecast,
  ) {
    final dataString = '${analytics.length}_${gapAnalysis?.productId ?? 0}_${forecast?.toolsCount ?? 0}';
    return dataString.hashCode.toString();
  }

  /// تحميل ملف للويب
  Future<void> _downloadForWeb(String content, String fileName, String mimeType) async {
    // سيتم تنفيذ هذا للويب إذا لزم الأمر
    throw UnimplementedError('Web download not implemented yet');
  }
}
