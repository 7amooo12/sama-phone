import 'package:flutter/material.dart';
// Import the existing ColorExtension

/// A centralized style system for the app providing consistent styling across the application
/// This includes colors, borders, shadows, and text styles
class StyleSystem {
  // Modern Color Palette for Accountant Dashboard
  static Color primaryColor = const Color(0xFF2E7D32); // Professional Green
  static Color secondaryColor = const Color(0xFF388E3C); // Lighter Green
  static Color accentColor = const Color(0xFF4CAF50); // Bright Green
  static const Color errorColor = Color(0xFFD32F2F); // Modern Red
  static const Color warningColor = Color(0xFFFF9800); // Modern Orange
  static const Color successColor = Color(0xFF4CAF50); // Success Green
  static const Color infoColor = Color(0xFF2196F3); // Info Blue

  // Background Colors
  static const Color backgroundDark = Color(0xFF0D1117);
  static const Color backgroundLight = Color(0xFFF8F9FA);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF161B22);

  // Scaffold Background Colors
  static Color get scaffoldBackgroundColor => backgroundLight;

  // Neutral Colors
  static const Color neutralLight = Color(0xFFE1E4E8);
  static const Color neutralMedium = Color(0xFF6A737D);
  static const Color neutralDark = Color(0xFF24292E);
  static const Color textPrimary = Color(0xFF24292E);
  static const Color textSecondary = Color(0xFF586069);
  static const Color textTertiaryDark = Color(0xFF6A737D);

  // Financial Colors for Accounting
  static const Color profitColor = Color(0xFF00C853); // Bright Green for profits
  static const Color lossColor = Color(0xFFFF1744); // Bright Red for losses
  static const Color pendingColor = Color(0xFFFF9800); // Orange for pending
  static const Color completedColor = Color(0xFF4CAF50); // Green for completed
  static const Color canceledColor = Color(0xFF9E9E9E); // Gray for canceled

  // Theme data for light mode
  static final ThemeData lightTheme = ThemeData(
    primaryColor: primaryColor,
    colorScheme: ColorScheme.light(
      primary: primaryColor,
      secondary: secondaryColor,
      error: errorColor,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: backgroundLight,
    textTheme: const TextTheme(
      displayLarge: displayLarge,
      displayMedium: displayMedium,
      displaySmall: displaySmall,
      headlineLarge: headlineLarge,
      headlineMedium: headlineMedium,
      headlineSmall: headlineSmall,
      titleLarge: titleLarge,
      titleMedium: titleMedium,
      titleSmall: titleSmall,
      bodyLarge: bodyLarge,
      bodyMedium: bodyMedium,
      bodySmall: bodySmall,
      labelLarge: labelLarge,
      labelMedium: labelMedium,
      labelSmall: labelSmall,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: primaryButtonStyle,
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: outlinedButtonStyle,
    ),
    textButtonTheme: TextButtonThemeData(
      style: textButtonStyle,
    ),
    inputDecorationTheme: textFieldTheme,
  );

  // Theme data for dark mode
  static final ThemeData darkTheme = ThemeData(
    primaryColor: primaryColor,
    colorScheme: ColorScheme.dark(
      primary: primaryColor,
      secondary: secondaryColor,
      error: errorColor,
      surface: surfaceDark,
    ),
    scaffoldBackgroundColor: backgroundDark,
    textTheme: TextTheme(
      displayLarge: displayLarge.copyWith(color: Colors.white),
      displayMedium: displayMedium.copyWith(color: Colors.white),
      displaySmall: displaySmall.copyWith(color: Colors.white),
      headlineLarge: headlineLarge.copyWith(color: Colors.white),
      headlineMedium: headlineMedium.copyWith(color: Colors.white),
      headlineSmall: headlineSmall.copyWith(color: Colors.white),
      titleLarge: titleLarge.copyWith(color: Colors.white),
      titleMedium: titleMedium.copyWith(color: Colors.white),
      titleSmall: titleSmall.copyWith(color: Colors.white),
      bodyLarge: bodyLarge.copyWith(color: Colors.white),
      bodyMedium: bodyMedium.copyWith(color: Colors.white),
      bodySmall: bodySmall.copyWith(color: Colors.white),
      labelLarge: labelLarge.copyWith(color: Colors.white),
      labelMedium: labelMedium.copyWith(color: Colors.white),
      labelSmall: labelSmall.copyWith(color: Colors.white),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: primaryButtonStyle,
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: outlinedButtonStyle,
    ),
    textButtonTheme: TextButtonThemeData(
      style: textButtonStyle,
    ),
    inputDecorationTheme: textFieldTheme.copyWith(
      fillColor: surfaceDark,
    ),
  );

  // Radius values
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;

  // Border radius
  static final BorderRadius borderRadiusSmall = BorderRadius.circular(radiusSmall);
  static final BorderRadius borderRadiusMedium = BorderRadius.circular(radiusMedium);
  static final BorderRadius borderRadiusLarge = BorderRadius.circular(radiusLarge);
  static const BorderRadius borderRadiusBottomOnly = BorderRadius.only(
    bottomLeft: Radius.circular(radiusLarge),
    bottomRight: Radius.circular(radiusLarge),
  );

  // Modern Shadows
  static final List<BoxShadow> shadowSmall = [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 6,
      offset: const Offset(0, 2),
      spreadRadius: 0,
    ),
  ];

  static final List<BoxShadow> shadowMedium = [
    BoxShadow(
      color: Colors.black.withOpacity(0.12),
      blurRadius: 12,
      offset: const Offset(0, 4),
      spreadRadius: 0,
    ),
  ];

  static final List<BoxShadow> shadowLarge = [
    BoxShadow(
      color: Colors.black.withOpacity(0.16),
      blurRadius: 20,
      offset: const Offset(0, 8),
      spreadRadius: 0,
    ),
  ];

  // Card Shadows
  static final List<BoxShadow> cardShadow = [
    BoxShadow(
      color: primaryColor.withOpacity(0.1),
      blurRadius: 8,
      offset: const Offset(0, 4),
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 4,
      offset: const Offset(0, 2),
      spreadRadius: 0,
    ),
  ];

  // Elevated Card Shadow
  static final List<BoxShadow> elevatedCardShadow = [
    BoxShadow(
      color: primaryColor.withOpacity(0.15),
      blurRadius: 16,
      offset: const Offset(0, 8),
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 8,
      offset: const Offset(0, 4),
      spreadRadius: 0,
    ),
  ];

  // Text styles
  static const TextStyle displayLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle displaySmall = TextStyle( // Added missing displaySmall
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle headlineLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle titleSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
  );

  // Button styles
  static final ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: primaryColor,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    shape: RoundedRectangleBorder(
      borderRadius: borderRadiusMedium,
    ),
  );

  // Additional missing button styles
  static final ButtonStyle outlinedButtonStyle = OutlinedButton.styleFrom(
    foregroundColor: primaryColor,
    side: BorderSide(color: primaryColor),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    shape: RoundedRectangleBorder(
      borderRadius: borderRadiusMedium,
    ),
  );

  static final ButtonStyle textButtonStyle = TextButton.styleFrom(
    foregroundColor: primaryColor,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    shape: RoundedRectangleBorder(
      borderRadius: borderRadiusMedium,
    ),
  );

  // Text Field Theme
  static final InputDecorationTheme textFieldTheme = InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: borderRadiusMedium,
      borderSide: const BorderSide(color: neutralMedium),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: borderRadiusMedium,
      borderSide: const BorderSide(color: neutralMedium),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: borderRadiusMedium,
      borderSide: BorderSide(color: primaryColor, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: borderRadiusMedium,
      borderSide: const BorderSide(color: errorColor),
    ),
  );

  // Modern Gradients for Accountant Dashboard
  static final List<Color> coolGradient = [
    primaryColor,
    secondaryColor,
  ];

  static final List<Color> darkModeGradient = [
    const Color(0xFF0D1117),
    const Color(0xFF161B22),
  ];

  static final List<Color> elegantGradient = [
    primaryColor,
    accentColor,
  ];

  // Financial Gradients
  static final List<Color> profitGradient = [
    const Color(0xFF00C853),
    const Color(0xFF4CAF50),
  ];

  static final List<Color> warningGradient = [
    const Color(0xFFFF9800),
    const Color(0xFFFFB74D),
  ];

  static final List<Color> infoGradient = [
    const Color(0xFF2196F3),
    const Color(0xFF64B5F6),
  ];

  static final List<Color> cardGradient = [
    const Color(0xFFFFFFFF),
    const Color(0xFFF8F9FA),
  ];

  static final List<Color> headerGradient = [
    primaryColor,
    const Color(0xFF1B5E20),
  ];

  // Error and Success Gradients
  static final List<Color> errorGradient = [
    const Color(0xFFD32F2F),
    const Color(0xFFE57373),
  ];

  static final List<Color> successGradient = [
    const Color(0xFF4CAF50),
    const Color(0xFF81C784),
  ];

  static BoxDecoration glassDecoration({BorderRadius? borderRadius}) {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: 0.1),
      borderRadius: borderRadius ?? borderRadiusMedium,
      border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
      boxShadow: shadowSmall,
    );
  }

  static InputDecoration inputDecoration = InputDecoration(
    filled: true,
    fillColor: Colors.white.withOpacity(0.1),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: Colors.white.withOpacity(0.2),
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(
        color: Colors.white,
      ),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(
        color: Colors.red,
      ),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(
        color: Colors.red,
      ),
    ),
    labelStyle: const TextStyle(
      color: Colors.white70,
    ),
    hintStyle: const TextStyle(
      color: Colors.white70,
    ),
  );
}

// Use ColorExtension from color_extension.dart
