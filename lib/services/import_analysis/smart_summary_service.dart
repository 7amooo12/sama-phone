import 'dart:convert';
import 'package:smartbiztracker_new/models/import_analysis_models.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';

/// Smart Summary Service for Import Analysis
/// Generates comprehensive summary reports with totals, REMARKS grouping, and JSON output
class SmartSummaryService {
  
  /// Generate smart summary report from packing list items
  static Map<String, dynamic> generateSmartSummary(List<PackingListItem> items) {
    try {
      AppLogger.info('بدء إنشاء التقرير الذكي لـ ${items.length} عنصر...');

      // Debug: Print first few items
      if (items.isNotEmpty) {
        for (int i = 0; i < items.length && i < 3; i++) {
          final item = items[i];
          AppLogger.info('العنصر $i: رقم الصنف="${item.itemNumber}", الكمية=${item.totalQuantity}, السعر=${item.rmbPrice}');
        }
      }

      // Calculate numerical totals
      final totals = _calculateTotals(items);
      AppLogger.info('المجاميع المحسوبة: $totals');

      // Generate REMARKS summary with intelligent grouping
      final remarksSummary = _generateRemarksSummary(items);
      AppLogger.info('ملخص الملاحظات: ${remarksSummary.length} مجموعة');

      // Generate products summary
      final products = _generateProductsSummary(items);
      AppLogger.info('ملخص المنتجات: ${products.length} منتج');
      
      final summary = {
        'totals': totals,
        'remarks_summary': remarksSummary,
        'products': products,
        'generated_at': DateTime.now().toIso8601String(),
        'total_items_processed': items.length,
        'valid_items': items.where((item) => item.isValid).length,
      };
      
      AppLogger.info('تم إنشاء التقرير الذكي بنجاح');
      return summary;
      
    } catch (e) {
      AppLogger.error('خطأ في إنشاء التقرير الذكي: $e');
      rethrow;
    }
  }
  
  /// Calculate numerical column totals
  static Map<String, dynamic> _calculateTotals(List<PackingListItem> items) {
    double ctn = 0;
    double pcCtn = 0;
    double qty = 0;
    double tCbm = 0;
    double nW = 0;
    double gW = 0;
    double tNW = 0;
    double tGW = 0;
    double price = 0;
    double rmb = 0;
    
    for (final item in items) {
      // Sum cartons
      if (item.cartonCount != null) {
        ctn += item.cartonCount!.toDouble();
      }
      
      // Sum pieces per carton
      if (item.piecesPerCarton != null) {
        pcCtn += item.piecesPerCarton!.toDouble();
      }
      
      // Sum total quantity
      qty += item.totalQuantity.toDouble();
      
      // Sum total cubic meters
      if (item.totalCubicMeters != null) {
        tCbm += item.totalCubicMeters!;
      }
      
      // Sum weights from weights JSON
      if (item.weights != null) {
        final weights = item.weights!;
        if (weights['net_weight'] != null) {
          nW += (weights['net_weight'] as num).toDouble();
        }
        if (weights['gross_weight'] != null) {
          gW += (weights['gross_weight'] as num).toDouble();
        }
        if (weights['total_net_weight'] != null) {
          tNW += (weights['total_net_weight'] as num).toDouble();
        }
        if (weights['total_gross_weight'] != null) {
          tGW += (weights['total_gross_weight'] as num).toDouble();
        }
      }
      
      // Sum prices
      if (item.unitPrice != null) {
        price += item.unitPrice! * item.totalQuantity;
      }
      if (item.rmbPrice != null) {
        rmb += item.rmbPrice! * item.totalQuantity;
      }
    }
    
    return {
      'ctn': ctn.round(),
      'pc_ctn': pcCtn.round(),
      'QTY': qty.round(),
      't_cbm': _roundToDecimal(tCbm, 2),
      'N_W': _roundToDecimal(nW, 2),
      'G_W': _roundToDecimal(gW, 2),
      'T_NW': _roundToDecimal(tNW, 2),
      'T_GW': _roundToDecimal(tGW, 2),
      'PRICE': _roundToDecimal(price, 2),
      'RMB': _roundToDecimal(rmb, 2),
    };
  }
  
  /// Generate REMARKS summary with intelligent grouping
  static List<Map<String, dynamic>> _generateRemarksSummary(List<PackingListItem> items) {
    final remarksMap = <String, int>{};
    
    for (final item in items) {
      if (item.remarks != null) {
        final remarks = item.remarks!;
        
        // Combine all remarks fields intelligently
        final combinedRemarks = _combineRemarks(remarks);
        
        if (combinedRemarks.isNotEmpty) {
          // Normalize text for grouping (handle whitespace and case differences)
          final normalizedRemarks = _normalizeRemarksText(combinedRemarks);
          
          // Add quantity to the group
          remarksMap[normalizedRemarks] = (remarksMap[normalizedRemarks] ?? 0) + item.totalQuantity;
        }
      }
    }
    
    // Convert to list and sort by quantity (descending)
    final remarksList = remarksMap.entries
        .map((entry) => {
              'text': entry.key,
              'qty': entry.value,
            })
        .toList();
    
    // Sort by quantity descending
    remarksList.sort((a, b) => (b['qty'] as int).compareTo(a['qty'] as int));
    
    return remarksList;
  }
  
  /// Generate products summary
  static List<Map<String, dynamic>> _generateProductsSummary(List<PackingListItem> items) {
    final productsMap = <String, Map<String, dynamic>>{};
    
    for (final item in items) {
      final itemNo = item.itemNumber;
      
      if (productsMap.containsKey(itemNo)) {
        // Add to existing product
        productsMap[itemNo]!['total_qty'] = 
            (productsMap[itemNo]!['total_qty'] as int) + item.totalQuantity;
      } else {
        // Create new product entry
        productsMap[itemNo] = {
          'item_no': itemNo,
          'picture': item.imageUrl ?? '',
          'total_qty': item.totalQuantity,
        };
      }
    }
    
    return productsMap.values.toList();
  }
  
  /// Combine remarks from multiple fields intelligently
  static String _combineRemarks(Map<String, dynamic> remarks) {
    final remarksList = <String>[];
    
    // Priority order for remarks fields
    final fieldsOrder = ['remarks_a', 'remarks_b', 'remarks_c'];
    
    for (final field in fieldsOrder) {
      final value = remarks[field];
      if (value != null && value.toString().trim().isNotEmpty) {
        remarksList.add(value.toString().trim());
      }
    }
    
    // If we have multiple non-empty remarks, combine them
    if (remarksList.length > 1) {
      return remarksList.join(' - ');
    } else if (remarksList.isNotEmpty) {
      return remarksList.first;
    }
    
    return '';
  }
  
  /// Normalize remarks text for intelligent grouping
  static String _normalizeRemarksText(String text) {
    // Remove extra whitespace and normalize case
    String normalized = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    
    // Keep original text for Arabic support, but normalize whitespace
    return normalized;
  }
  
  /// Round number to specified decimal places
  static double _roundToDecimal(double value, int decimals) {
    final factor = 1.0 * (10 * decimals);
    return (value * factor).round() / factor;
  }
  
  /// Generate JSON string from summary
  static String generateJsonSummary(List<PackingListItem> items) {
    final summary = generateSmartSummary(items);
    return jsonEncode(summary);
  }
  
  /// Validate summary data completeness
  static Map<String, dynamic> validateSummary(Map<String, dynamic> summary) {
    final validation = <String, dynamic>{
      'is_valid': true,
      'warnings': <String>[],
      'errors': <String>[],
    };
    
    // Check totals
    final totals = summary['totals'] as Map<String, dynamic>?;
    if (totals == null) {
      validation['errors'].add('Missing totals section');
      validation['is_valid'] = false;
    } else {
      if (totals['QTY'] == 0) {
        validation['warnings'].add('Total quantity is zero');
      }
      if (totals['RMB'] == 0) {
        validation['warnings'].add('Total RMB value is zero');
      }
    }
    
    // Check remarks summary
    final remarksSummary = summary['remarks_summary'] as List<dynamic>?;
    if (remarksSummary == null || remarksSummary.isEmpty) {
      validation['warnings'].add('No remarks data found');
    }
    
    // Check products
    final products = summary['products'] as List<dynamic>?;
    if (products == null || products.isEmpty) {
      validation['errors'].add('No products data found');
      validation['is_valid'] = false;
    }
    
    return validation;
  }
}
