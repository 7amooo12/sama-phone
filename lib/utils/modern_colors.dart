import 'package:flutter/material.dart';

/// Modern color palette for the SmartBizTracker app
/// Provides a comprehensive set of colors for a modern, professional look
class ModernColors {
  // Primary Brand Colors
  static const Color primaryBlue = Color(0xFF3B82F6);
  static const Color primaryBlueDark = Color(0xFF1D4ED8);
  static const Color primaryBlueLight = Color(0xFF60A5FA);

  // Secondary Colors
  static const Color emeraldGreen = Color(0xFF10B981);
  static const Color emeraldGreenDark = Color(0xFF059669);
  static const Color emeraldGreenLight = Color(0xFF34D399);

  // Accent Colors
  static const Color violet = Color(0xFF8B5CF6);
  static const Color violetDark = Color(0xFF7C3AED);
  static const Color violetLight = Color(0xFFA78BFA);

  static const Color amber = Color(0xFFF59E0B);
  static const Color amberDark = Color(0xFFD97706);
  static const Color amberLight = Color(0xFFFBBF24);

  static const Color rose = Color(0xFFEF4444);
  static const Color roseDark = Color(0xFFDC2626);
  static const Color roseLight = Color(0xFFF87171);

  static const Color cyan = Color(0xFF06B6D4);
  static const Color cyanDark = Color(0xFF0891B2);
  static const Color cyanLight = Color(0xFF22D3EE);

  static const Color pink = Color(0xFFEC4899);
  static const Color pinkDark = Color(0xFFDB2777);
  static const Color pinkLight = Color(0xFFF472B6);

  // Neutral Colors
  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate900 = Color(0xFF0F172A);

  // Gray Colors
  static const Color gray50 = Color(0xFFF9FAFB);
  static const Color gray100 = Color(0xFFF3F4F6);
  static const Color gray200 = Color(0xFFE5E7EB);
  static const Color gray300 = Color(0xFFD1D5DB);
  static const Color gray400 = Color(0xFF9CA3AF);
  static const Color gray500 = Color(0xFF6B7280);
  static const Color gray600 = Color(0xFF4B5563);
  static const Color gray700 = Color(0xFF374151);
  static const Color gray800 = Color(0xFF1F2937);
  static const Color gray900 = Color(0xFF111827);

  // Status Colors
  static const Color success = emeraldGreen;
  static const Color successDark = emeraldGreenDark;
  static const Color successLight = emeraldGreenLight;

  static const Color warning = amber;
  static const Color warningDark = amberDark;
  static const Color warningLight = amberLight;

  static const Color error = rose;
  static const Color errorDark = roseDark;
  static const Color errorLight = roseLight;

  static const Color info = cyan;
  static const Color infoDark = cyanDark;
  static const Color infoLight = cyanLight;

  // Gradients
  static const List<Color> primaryGradient = [primaryBlue, primaryBlueDark];
  static const List<Color> successGradient = [emeraldGreen, emeraldGreenDark];
  static const List<Color> warningGradient = [amber, amberDark];
  static const List<Color> errorGradient = [rose, roseDark];
  static const List<Color> infoGradient = [cyan, cyanDark];
  static const List<Color> violetGradient = [violet, violetDark];
  static const List<Color> pinkGradient = [pink, pinkDark];

  // Background Gradients
  static const List<Color> lightBackgroundGradient = [slate50, Color(0xFFFFFFFF)];
  static const List<Color> darkBackgroundGradient = [slate900, slate800];

  // Card Gradients
  static const List<Color> lightCardGradient = [Color(0xFFFFFFFF), slate50];
  static const List<Color> darkCardGradient = [slate800, slate700];

  // Background Colors
  static const Color backgroundLight = Color(0xFFF8F9FA);
  static const Color backgroundDark = Color(0xFF0D1117);

  // Surface Colors
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color darkSurface = slate800;

  // Text Colors
  static const Color lightTextPrimary = gray900;
  static const Color lightTextSecondary = gray600;
  static const Color lightTextTertiary = gray400;

  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = gray300;
  static const Color darkTextTertiary = gray500;

  // Border Colors
  static const Color lightBorder = gray200;
  static const Color darkBorder = slate600;

  // Shadow Colors
  static const Color lightShadow = Color(0x14000000); // Colors.black.withOpacity(0.08)
  static const Color darkShadow = Color(0x4D000000); // Colors.black.withOpacity(0.3)

  // Helper methods
  static List<Color> getGradientForColor(Color color) {
    if (color == primaryBlue) return primaryGradient;
    if (color == emeraldGreen) return successGradient;
    if (color == amber) return warningGradient;
    if (color == rose) return errorGradient;
    if (color == cyan) return infoGradient;
    if (color == violet) return violetGradient;
    if (color == pink) return pinkGradient;
    return [color, color.withOpacity(0.8)];
  }

  static Color getTextColorForBackground(Color backgroundColor, {bool isDark = false}) {
    if (isDark) {
      return darkTextPrimary;
    } else {
      return lightTextPrimary;
    }
  }

  static Color getSurfaceColor({bool isDark = false}) {
    return isDark ? darkSurface : lightSurface;
  }

  static Color getBorderColor({bool isDark = false}) {
    return isDark ? darkBorder : lightBorder;
  }

  static Color getShadowColor({bool isDark = false}) {
    return isDark ? darkShadow : lightShadow;
  }

  // Performance Colors
  static const Color excellentPerformance = emeraldGreen;
  static const Color goodPerformance = amber;
  static const Color poorPerformance = rose;

  // Business Metrics Colors
  static const Color revenue = primaryBlue;
  static const Color profit = emeraldGreen;
  static const Color orders = violet;
  static const Color customers = cyan;
  static const Color inventory = amber;
  static const Color expenses = rose;

  // Tab Colors
  static const List<Color> overviewTabGradient = [primaryBlue, primaryBlueDark];
  static const List<Color> productsTabGradient = [emeraldGreen, emeraldGreenDark];
  static const List<Color> workersTabGradient = [violet, violetDark];
  static const List<Color> ordersTabGradient = [amber, amberDark];
  static const List<Color> competitorsTabGradient = [rose, roseDark];
  static const List<Color> reportsTabGradient = [cyan, cyanDark];
  static const List<Color> movementTabGradient = [pink, pinkDark];
}

/// Extension to add modern color utilities to ThemeData
extension ModernThemeExtension on ThemeData {
  bool get isModernDark => brightness == Brightness.dark;

  Color get modernPrimary => ModernColors.primaryBlue;
  Color get modernSurface => ModernColors.getSurfaceColor(isDark: isModernDark);
  Color get modernTextPrimary => ModernColors.getTextColorForBackground(
    modernSurface,
    isDark: isModernDark
  );
  Color get modernBorder => ModernColors.getBorderColor(isDark: isModernDark);
  Color get modernShadow => ModernColors.getShadowColor(isDark: isModernDark);
}
