import 'package:flutter/material.dart';
import '../utils/constants.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    primarySwatch: AppConstants.primarySwatch,
    primaryColor: AppConstants.primaryColor,
    colorScheme: const ColorScheme.light(
      primary: AppConstants.primaryColor,
      secondary: AppConstants.secondaryColor,
      error: AppConstants.errorColor,
    ),
    scaffoldBackgroundColor: Colors.grey[50],
    appBarTheme: AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      titleTextStyle: AppConstants.headingStyle.copyWith(
        color: Colors.black,
      ),
    ),
    cardTheme: CardTheme(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: AppConstants.defaultBorderRadius,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: AppConstants.defaultButtonStyle,
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: AppConstants.outlinedButtonStyle,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: AppConstants.defaultBorderRadius,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppConstants.defaultBorderRadius,
        borderSide: BorderSide(
          color: Colors.grey.shade400,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppConstants.defaultBorderRadius,
        borderSide: const BorderSide(
          color: AppConstants.primaryColor,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppConstants.defaultBorderRadius,
        borderSide: const BorderSide(
          color: AppConstants.errorColor,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppConstants.defaultBorderRadius,
        borderSide: const BorderSide(
          color: AppConstants.errorColor,
          width: 2,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
    ),
    textTheme: const TextTheme(
      displayLarge: AppConstants.headingStyle,
      displayMedium: AppConstants.subheadingStyle,
      bodyLarge: AppConstants.bodyStyle,
      bodyMedium: AppConstants.bodyStyle,
      bodySmall: AppConstants.captionStyle,
      // These are deprecated but kept for backwards compatibility
      titleLarge: AppConstants.subheadingStyle,
      titleMedium: AppConstants.bodyStyle,
    ),
    dividerTheme: const DividerThemeData(
      space: 1,
      thickness: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: AppConstants.defaultBorderRadius,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      selectedItemColor: AppConstants.primaryColor,
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.defaultRadius),
        ),
      ),
    ),
    dialogTheme: DialogTheme(
      shape: RoundedRectangleBorder(
        borderRadius: AppConstants.defaultBorderRadius,
      ),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primarySwatch: AppConstants.primarySwatch,
    primaryColor: AppConstants.primaryColor,
    colorScheme: const ColorScheme.dark(
      primary: AppConstants.primaryColor,
      secondary: AppConstants.secondaryColor,
      error: AppConstants.errorColor,
    ),
    scaffoldBackgroundColor: Colors.grey[900],
    appBarTheme: AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: Colors.grey[850],
      titleTextStyle: AppConstants.headingStyle.copyWith(
        color: Colors.white,
      ),
    ),
    cardTheme: CardTheme(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: AppConstants.defaultBorderRadius,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: AppConstants.defaultButtonStyle,
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: AppConstants.outlinedButtonStyle,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: AppConstants.defaultBorderRadius,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppConstants.defaultBorderRadius,
        borderSide: BorderSide(
          color: Colors.grey.shade700,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppConstants.defaultBorderRadius,
        borderSide: const BorderSide(
          color: AppConstants.primaryColor,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppConstants.defaultBorderRadius,
        borderSide: const BorderSide(
          color: AppConstants.errorColor,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppConstants.defaultBorderRadius,
        borderSide: const BorderSide(
          color: AppConstants.errorColor,
          width: 2,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
    ),
    textTheme: TextTheme(
      displayLarge: AppConstants.headingStyle.copyWith(color: Colors.white),
      displayMedium: AppConstants.subheadingStyle.copyWith(color: Colors.white),
      bodyLarge: AppConstants.bodyStyle.copyWith(color: Colors.white),
      bodyMedium: AppConstants.bodyStyle.copyWith(color: Colors.white),
      bodySmall: AppConstants.captionStyle.copyWith(color: Colors.grey[400]),
      // These are deprecated but kept for backwards compatibility
      titleLarge: AppConstants.subheadingStyle.copyWith(color: Colors.white),
      titleMedium: AppConstants.bodyStyle.copyWith(color: Colors.white),
    ),
    dividerTheme: DividerThemeData(
      space: 1,
      thickness: 1,
      color: Colors.grey[700],
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.grey[800],
      shape: RoundedRectangleBorder(
        borderRadius: AppConstants.defaultBorderRadius,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      selectedItemColor: AppConstants.primaryColor,
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: Colors.grey[850],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.defaultRadius),
        ),
      ),
    ),
    dialogTheme: DialogTheme(
      backgroundColor: Colors.grey[850],
      shape: RoundedRectangleBorder(
        borderRadius: AppConstants.defaultBorderRadius,
      ),
    ),
  );
}

class AppThemes {
  static ThemeData get lightTheme => AppTheme.lightTheme;
  static ThemeData get darkTheme => AppTheme.darkTheme;
  static Color get primaryColor => AppConstants.primaryColor;
  static Color get secondaryColor => AppConstants.secondaryColor;
  static Color get accentColor => AppConstants.accentColor;
  static Color get successColor => AppConstants.successColor;
  static Color get errorColor => AppConstants.errorColor;
}
