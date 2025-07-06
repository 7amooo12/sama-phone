import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartbiztracker_new/utils/style_system.dart';

class ThemeProviderNew extends ChangeNotifier {

  ThemeProviderNew() {
    // Enforce permanent dark mode - no loading from preferences
    _isDarkMode = true;
    _themeMode = ThemeMode.dark;
    _updateStatusBarColor();
  }

  // Permanently set to dark mode
  bool _isDarkMode = true;
  ThemeMode _themeMode = ThemeMode.dark;

  // Always return dark mode
  bool get isDarkMode => true;
  ThemeMode get themeMode => ThemeMode.dark;

  // Removed theme preference loading - permanent dark mode

  // Disabled theme switching - always dark mode
  void toggleTheme() {
    // Do nothing - theme is permanently dark
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    // Do nothing - theme is permanently dark
  }

  Future<void> setDarkMode() async {
    // Already dark mode - do nothing
  }

  Future<void> setLightMode() async {
    // Disabled - permanent dark mode only
  }

  void _updateStatusBarColor() {
    // Always set dark mode status bar styling
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF0F172A), // Luxury dark background
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  ThemeData getTheme() {
    return _buildDarkTheme(); // Always return dark theme
  }

  ThemeData get lightTheme => _buildDarkTheme(); // Return dark theme even for light
  ThemeData get darkTheme => _buildDarkTheme();

  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: StyleSystem.primaryColor,
        brightness: Brightness.light,
        primary: StyleSystem.primaryColor,
        secondary: StyleSystem.secondaryColor,
        tertiary: StyleSystem.accentColor,
        error: StyleSystem.errorColor,
      ),
      primaryColor: StyleSystem.primaryColor,
      scaffoldBackgroundColor: StyleSystem.backgroundLight,
      cardColor: StyleSystem.backgroundLight,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: StyleSystem.backgroundLight,
        foregroundColor: StyleSystem.primaryColor,
        iconTheme: IconThemeData(color: StyleSystem.primaryColor),
        titleTextStyle: StyleSystem.titleLarge.copyWith(
          color: StyleSystem.primaryColor,
          fontWeight: FontWeight.bold,
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: StyleSystem.primaryButtonStyle,
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: StyleSystem.outlinedButtonStyle,
      ),
      textButtonTheme: TextButtonThemeData(
        style: StyleSystem.textButtonStyle,
      ),
      cardTheme: CardTheme(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: StyleSystem.borderRadiusLarge,
        ),
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shadowColor: Colors.black.withOpacity(0.05),
      ),
      inputDecorationTheme: StyleSystem.textFieldTheme,
      textTheme: const TextTheme(
        displayLarge: StyleSystem.displayLarge,
        displayMedium: StyleSystem.displayMedium,
        displaySmall: StyleSystem.displaySmall,
        headlineLarge: StyleSystem.headlineLarge,
        headlineMedium: StyleSystem.headlineMedium,
        headlineSmall: StyleSystem.headlineSmall,
        titleLarge: StyleSystem.titleLarge,
        titleMedium: StyleSystem.titleMedium,
        titleSmall: StyleSystem.titleSmall,
        bodyLarge: StyleSystem.bodyLarge,
        bodyMedium: StyleSystem.bodyMedium,
        bodySmall: StyleSystem.bodySmall,
        labelLarge: StyleSystem.labelLarge,
        labelMedium: StyleSystem.labelMedium,
        labelSmall: StyleSystem.labelSmall,
      ),
      dividerTheme: const DividerThemeData(
        color: StyleSystem.neutralLight,
        thickness: 1,
        space: 1,
      ),
      iconTheme: const IconThemeData(
        color: StyleSystem.neutralMedium,
        size: 24,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: StyleSystem.neutralMedium,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(StyleSystem.radiusMedium)),
        ),
        tileColor: Colors.transparent,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: StyleSystem.backgroundLight,
        selectedItemColor: StyleSystem.primaryColor,
        unselectedItemColor: StyleSystem.neutralMedium,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: StyleSystem.labelMedium.copyWith(fontWeight: FontWeight.bold),
        unselectedLabelStyle: StyleSystem.labelMedium,
        showUnselectedLabels: true,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: StyleSystem.backgroundLight,
        selectedIconTheme: IconThemeData(color: StyleSystem.primaryColor),
        unselectedIconTheme: const IconThemeData(color: StyleSystem.neutralMedium),
        selectedLabelTextStyle: TextStyle(color: StyleSystem.primaryColor, fontWeight: FontWeight.bold),
        unselectedLabelTextStyle: const TextStyle(color: StyleSystem.neutralMedium),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: StyleSystem.primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        extendedPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ), dialogTheme: const DialogThemeData(backgroundColor: StyleSystem.backgroundLight),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: StyleSystem.primaryColor,
        brightness: Brightness.dark,
        primary: StyleSystem.primaryColor,
        secondary: StyleSystem.secondaryColor,
        tertiary: StyleSystem.accentColor,
        error: StyleSystem.errorColor,
        background: StyleSystem.backgroundDark,
        surface: StyleSystem.surfaceDark,
      ),
      primaryColor: StyleSystem.primaryColor,
      scaffoldBackgroundColor: StyleSystem.backgroundDark,
      cardColor: StyleSystem.surfaceDark,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: StyleSystem.backgroundDark,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: StyleSystem.titleLarge.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: StyleSystem.primaryButtonStyle.copyWith(
          backgroundColor: WidgetStateProperty.all(StyleSystem.primaryColor),
          shadowColor: WidgetStateProperty.all(StyleSystem.primaryColor.withValues(alpha: 0.5)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: StyleSystem.outlinedButtonStyle.copyWith(
          foregroundColor: WidgetStateProperty.all(Colors.white),
          side: WidgetStateProperty.all(const BorderSide(color: Colors.white70, width: 1.5)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: StyleSystem.textButtonStyle.copyWith(
          foregroundColor: WidgetStateProperty.all(Colors.white),
        ),
      ),
      cardTheme: CardTheme(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: StyleSystem.borderRadiusLarge,
        ),
        color: StyleSystem.surfaceDark,
        clipBehavior: Clip.antiAlias,
        shadowColor: Colors.black.withOpacity(0.3),
      ),
      inputDecorationTheme: StyleSystem.textFieldTheme.copyWith(
        fillColor: StyleSystem.surfaceDark.withOpacity(0.6),
        labelStyle: StyleSystem.bodyMedium.copyWith(color: Colors.white70),
        hintStyle: StyleSystem.bodyMedium.copyWith(color: Colors.white38),
        errorStyle: StyleSystem.labelMedium.copyWith(color: StyleSystem.errorColor),
        prefixIconColor: Colors.white70,
        suffixIconColor: Colors.white70,
        border: OutlineInputBorder(
          borderRadius: StyleSystem.borderRadiusMedium,
          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: StyleSystem.borderRadiusMedium,
          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: StyleSystem.borderRadiusMedium,
          borderSide: BorderSide(color: StyleSystem.primaryColor, width: 2),
        ),
      ),
      textTheme: TextTheme(
        displayLarge: StyleSystem.displayLarge.copyWith(color: Colors.white),
        displayMedium: StyleSystem.displayMedium.copyWith(color: Colors.white),
        displaySmall: StyleSystem.displaySmall.copyWith(color: Colors.white),
        headlineLarge: StyleSystem.headlineLarge.copyWith(color: Colors.white),
        headlineMedium: StyleSystem.headlineMedium.copyWith(color: Colors.white),
        headlineSmall: StyleSystem.headlineSmall.copyWith(color: Colors.white),
        titleLarge: StyleSystem.titleLarge.copyWith(color: Colors.white),
        titleMedium: StyleSystem.titleMedium.copyWith(color: Colors.white),
        titleSmall: StyleSystem.titleSmall.copyWith(color: Colors.white),
        bodyLarge: StyleSystem.bodyLarge.copyWith(color: Colors.white),
        bodyMedium: StyleSystem.bodyMedium.copyWith(color: Colors.white),
        bodySmall: StyleSystem.bodySmall.copyWith(color: Colors.white70),
        labelLarge: StyleSystem.labelLarge.copyWith(color: Colors.white),
        labelMedium: StyleSystem.labelMedium.copyWith(color: Colors.white70),
        labelSmall: StyleSystem.labelSmall.copyWith(color: Colors.white70),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withOpacity(0.2),
        thickness: 1,
        space: 1,
      ),
      iconTheme: const IconThemeData(
        color: Colors.white70,
        size: 24,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: Colors.white70,
        textColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(StyleSystem.radiusMedium)),
        ),
        tileColor: Colors.transparent,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: StyleSystem.surfaceDark,
        selectedItemColor: StyleSystem.primaryColor,
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: StyleSystem.labelMedium.copyWith(fontWeight: FontWeight.bold),
        unselectedLabelStyle: StyleSystem.labelMedium,
        showUnselectedLabels: true,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: StyleSystem.surfaceDark,
        selectedIconTheme: IconThemeData(color: StyleSystem.primaryColor),
        unselectedIconTheme: const IconThemeData(color: Colors.white54),
        selectedLabelTextStyle: TextStyle(color: StyleSystem.primaryColor, fontWeight: FontWeight.bold),
        unselectedLabelTextStyle: const TextStyle(color: Colors.white54),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: StyleSystem.primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        extendedPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ), dialogTheme: const DialogThemeData(backgroundColor: StyleSystem.surfaceDark),
    );
  }
} 