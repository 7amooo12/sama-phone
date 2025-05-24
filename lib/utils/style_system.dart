import 'package:flutter/material.dart';
import 'color_extension.dart'; // Import the existing ColorExtension

/// A centralized style system for the app providing consistent styling across the application
/// This includes colors, borders, shadows, and text styles
class StyleSystem {
  // Colors
  static Color primaryColor = const Color(0xFF1E88E5);
  static Color secondaryColor = const Color(0xFF42A5F5);
  static final Color errorColor = Colors.red;
  static final Color warningColor = Colors.orange;
  static final Color successColor = Colors.green;
  static final Color backgroundDark = Color(0xFF121212);
  static final Color backgroundLight = Colors.white;
  static final Color neutralLight = Color(0xFFE0E0E0);
  static final Color neutralMedium = Color(0xFF9E9E9E);
  static final Color textTertiaryDark = Color(0xFF616161);
  static Color accentColor = const Color(0xFF64B5F6);
  static final Color surfaceDark = Color(0xFF1E1E1E); // Added missing surfaceDark

  // Theme data for light mode
  static final ThemeData lightTheme = ThemeData(
    primaryColor: primaryColor,
    colorScheme: ColorScheme.light(
      primary: primaryColor,
      secondary: secondaryColor,
      error: errorColor,
      background: backgroundLight,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: backgroundLight,
    textTheme: TextTheme(
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
      background: backgroundDark,
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
  static final BorderRadius borderRadiusBottomOnly = BorderRadius.only(
    bottomLeft: Radius.circular(radiusLarge),
    bottomRight: Radius.circular(radiusLarge),
  );

  // Shadows
  static final List<BoxShadow> shadowSmall = [
    BoxShadow(
      color: Colors.black.withOpacity(0.1),
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
  ];

  static final List<BoxShadow> shadowMedium = [
    BoxShadow(
      color: Colors.black.withOpacity(0.15),
      blurRadius: 8,
      offset: Offset(0, 4),
    ),
  ];

  static final List<BoxShadow> shadowLarge = [
    BoxShadow(
      color: Colors.black.withOpacity(0.2),
      blurRadius: 12,
      offset: Offset(0, 6),
    ),
  ];

  // Text styles
  static final TextStyle displayLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
  );

  static final TextStyle displayMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
  );

  static final TextStyle displaySmall = TextStyle( // Added missing displaySmall
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );

  static final TextStyle headlineLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );

  static final TextStyle headlineMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
  );

  static final TextStyle headlineSmall = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );

  static final TextStyle titleLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );

  static final TextStyle titleMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  static final TextStyle titleSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  static final TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
  );

  static final TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
  );

  static final TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
  );

  static final TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  static final TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );

  static final TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
  );

  // Button styles
  static final ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: primaryColor,
    foregroundColor: Colors.white,
    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    shape: RoundedRectangleBorder(
      borderRadius: borderRadiusMedium,
    ),
  );

  // Additional missing button styles
  static final ButtonStyle outlinedButtonStyle = OutlinedButton.styleFrom(
    foregroundColor: primaryColor,
    side: BorderSide(color: primaryColor),
    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    shape: RoundedRectangleBorder(
      borderRadius: borderRadiusMedium,
    ),
  );

  static final ButtonStyle textButtonStyle = TextButton.styleFrom(
    foregroundColor: primaryColor,
    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    shape: RoundedRectangleBorder(
      borderRadius: borderRadiusMedium,
    ),
  );

  // Text Field Theme
  static final InputDecorationTheme textFieldTheme = InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: borderRadiusMedium,
      borderSide: BorderSide(color: neutralMedium),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: borderRadiusMedium,
      borderSide: BorderSide(color: neutralMedium),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: borderRadiusMedium,
      borderSide: BorderSide(color: primaryColor, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: borderRadiusMedium,
      borderSide: BorderSide(color: errorColor),
    ),
  );

  // Gradients
  static final List<Color> coolGradient = [
    primaryColor,
    primaryColor.withOpacity(0.7),
  ];

  static List<Color> darkModeGradient = [
    const Color(0xFF1A237E),
    const Color(0xFF0D47A1),
  ];
  
  static final List<Color> elegantGradient = [
    primaryColor,
    Color(0xFF03A9F4),
  ];
  
  static BoxDecoration glassDecoration({BorderRadius? borderRadius}) {
    return BoxDecoration(
      color: Colors.white.withOpacity(0.1),
      borderRadius: borderRadius ?? borderRadiusMedium,
      border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
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
