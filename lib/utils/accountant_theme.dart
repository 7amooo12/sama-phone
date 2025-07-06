import 'package:flutter/material.dart';

/// Specialized theme configuration for the Accountant Dashboard
/// Provides enhanced colors, gradients, and styling specifically for financial interfaces
class AccountantTheme {
  // Enhanced Financial Color Palette
  static const Color primaryGreen = Color(0xFF2E7D32);
  static const Color lightGreen = Color(0xFF4CAF50);
  static const Color darkGreen = Color(0xFF1B5E20);
  static const Color accentGreen = Color(0xFF66BB6A);
  
  // Status Colors for Financial Data
  static const Color profitGreen = Color(0xFF00C853);
  static const Color lossRed = Color(0xFFFF1744);
  static const Color pendingOrange = Color(0xFFFF9800);
  static const Color completedBlue = Color(0xFF2196F3);
  static const Color warningAmber = Color(0xFFFFC107);
  
  // Background and Surface Colors
  static const Color backgroundLight = Color(0xFFF8F9FA);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFFFAFAFA);
  
  // Text Colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFFBDBDBD);
  
  // Modern Gradients for Accountant Interface
  static const List<Color> primaryGradient = [
    Color(0xFF2E7D32),
    Color(0xFF388E3C),
  ];
  
  static const List<Color> profitGradient = [
    Color(0xFF00C853),
    Color(0xFF4CAF50),
  ];
  
  static const List<Color> lossGradient = [
    Color(0xFFFF1744),
    Color(0xFFE53935),
  ];
  
  static const List<Color> pendingGradient = [
    Color(0xFFFF9800),
    Color(0xFFFFB74D),
  ];
  
  static const List<Color> cardGradient = [
    Color(0xFFFFFFFF),
    Color(0xFFF8F9FA),
  ];
  
  static const List<Color> headerGradient = [
    Color(0xFF2E7D32),
    Color(0xFF1B5E20),
  ];
  
  static const List<Color> infoGradient = [
    Color(0xFF2196F3),
    Color(0xFF64B5F6),
  ];
  
  // Enhanced Shadow Definitions
  static const List<BoxShadow> softShadow = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 8,
      offset: Offset(0, 4),
      spreadRadius: 0,
    ),
  ];
  
  static const List<BoxShadow> mediumShadow = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 16,
      offset: Offset(0, 8),
      spreadRadius: 0,
    ),
  ];
  
  static const List<BoxShadow> strongShadow = [
    BoxShadow(
      color: Color(0x1F000000),
      blurRadius: 24,
      offset: Offset(0, 12),
      spreadRadius: 0,
    ),
  ];
  
  // Card Decorations
  static BoxDecoration modernCard({
    List<Color>? gradient,
    Color? borderColor,
    double borderRadius = 20,
    List<BoxShadow>? shadows,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: gradient ?? cardGradient,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? primaryGreen.withOpacity(0.1),
        width: 1,
      ),
      boxShadow: shadows ?? softShadow,
    );
  }
  
  static BoxDecoration glassMorphism({
    double borderRadius = 16,
    Color? backgroundColor,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: (backgroundColor ?? Colors.white).withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? Colors.white.withValues(alpha: 0.2),
        width: 1.5,
      ),
      boxShadow: softShadow,
    );
  }
  
  // Button Styles
  static ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: primaryGreen,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    elevation: 0,
    shadowColor: Colors.transparent,
  );
  
  static ButtonStyle outlinedButtonStyle = OutlinedButton.styleFrom(
    foregroundColor: primaryGreen,
    side: const BorderSide(color: primaryGreen, width: 2),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
  );
  
  // Text Styles
  static const TextStyle headingLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: -0.5,
  );
  
  static const TextStyle headingMedium = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: -0.25,
  );
  
  static const TextStyle headingSmall = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );
  
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: textPrimary,
    height: 1.5,
  );
  
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: textSecondary,
    height: 1.4,
  );
  
  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: textSecondary,
    letterSpacing: 0.5,
  );
  
  // Financial Status Colors
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'paid':
      case 'مكتملة':
      case 'مدفوعة':
        return profitGreen;
      case 'pending':
      case 'معلقة':
        return pendingOrange;
      case 'cancelled':
      case 'canceled':
      case 'ملغاة':
        return lossRed;
      case 'draft':
      case 'مسودة':
        return textSecondary;
      default:
        return textSecondary;
    }
  }
  
  // Financial Amount Colors
  static Color getAmountColor(double amount) {
    if (amount > 0) return profitGreen;
    if (amount < 0) return lossRed;
    return textSecondary;
  }
  
  // Performance Colors
  static Color getPerformanceColor(double percentage) {
    if (percentage >= 80) return profitGreen;
    if (percentage >= 60) return lightGreen;
    if (percentage >= 40) return pendingOrange;
    return lossRed;
  }
}
