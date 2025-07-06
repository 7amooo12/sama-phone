import 'package:flutter/material.dart';

/// ألوان أدوات التصنيع المخصصة
class ToolColors {
  // ألوان أساسية للأدوات
  static const Color primaryTool = Color(0xFF2E7D32);
  static const Color secondaryTool = Color(0xFF1976D2);
  static const Color accentTool = Color(0xFFFF9800);
  static const Color warningTool = Color(0xFFE65100);
  static const Color dangerTool = Color(0xFFD32F2F);
  
  // ألوان حالة المخزون
  static const Color highStock = Color(0xFF4CAF50);      // أخضر - مخزون عالي (70-100%)
  static const Color mediumStock = Color(0xFFFFEB3B);    // أصفر - مخزون متوسط (30-69%)
  static const Color lowStock = Color(0xFFFF9800);       // برتقالي - مخزون منخفض (10-29%)
  static const Color outOfStock = Color(0xFFF44336);     // أحمر - نفاد المخزون (0-9%)
  
  // ألوان أنواع الأدوات
  static const Color cuttingTool = Color(0xFF607D8B);
  static const Color drillingTool = Color(0xFF795548);
  static const Color measuringTool = Color(0xFF9C27B0);
  static const Color assemblyTool = Color(0xFF3F51B5);
  static const Color finishingTool = Color(0xFF009688);
  
  /// الحصول على لون حالة المخزون بناءً على النسبة المئوية
  static Color getStockStatusColor(double stockPercentage) {
    if (stockPercentage >= 70) {
      return highStock;
    } else if (stockPercentage >= 30) {
      return mediumStock;
    } else if (stockPercentage >= 10) {
      return lowStock;
    } else {
      return outOfStock;
    }
  }
  
  /// الحصول على لون الأداة بناءً على النوع
  static Color getToolTypeColor(String toolType) {
    switch (toolType.toLowerCase()) {
      case 'cutting':
      case 'قطع':
        return cuttingTool;
      case 'drilling':
      case 'حفر':
        return drillingTool;
      case 'measuring':
      case 'قياس':
        return measuringTool;
      case 'assembly':
      case 'تجميع':
        return assemblyTool;
      case 'finishing':
      case 'تشطيب':
        return finishingTool;
      default:
        return primaryTool;
    }
  }
  
  /// الحصول على تدرج لوني للأداة
  static LinearGradient getToolGradient(String toolType) {
    final baseColor = getToolTypeColor(toolType);
    return LinearGradient(
      colors: [
        baseColor,
        baseColor.withOpacity(0.7),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
  
  /// الحصول على تدرج لوني لحالة المخزون
  static LinearGradient getStockStatusGradient(double stockPercentage) {
    final baseColor = getStockStatusColor(stockPercentage);
    return LinearGradient(
      colors: [
        baseColor,
        baseColor.withOpacity(0.7),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}
