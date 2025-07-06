import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  
  ThemeProvider() {
    _loadTheme();
  }
  static const String _themeKey = 'theme_mode';
  static const String _colorSchemeKey = 'color_scheme';
  
  ThemeMode _themeMode = ThemeMode.system;
  String _colorScheme = 'blue';
  
  ThemeMode get themeMode => _themeMode;
  String get colorScheme => _colorScheme;
  
  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      return WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }
  
  bool get isLightMode => !isDarkMode;
  
  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeModeIndex = prefs.getInt(_themeKey) ?? ThemeMode.system.index;
      _themeMode = ThemeMode.values[themeModeIndex];
      _colorScheme = prefs.getString(_colorSchemeKey) ?? 'blue';
      notifyListeners();
    } catch (e) {
      // Handle error silently, use defaults
    }
  }
  
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode != mode) {
      _themeMode = mode;
      notifyListeners();
      await _saveTheme();
    }
  }
  
  Future<void> setColorScheme(String scheme) async {
    if (_colorScheme != scheme) {
      _colorScheme = scheme;
      notifyListeners();
      await _saveTheme();
    }
  }
  
  Future<void> toggleTheme() async {
    switch (_themeMode) {
      case ThemeMode.light:
        await setThemeMode(ThemeMode.dark);
        break;
      case ThemeMode.dark:
        await setThemeMode(ThemeMode.system);
        break;
      case ThemeMode.system:
        await setThemeMode(ThemeMode.light);
        break;
    }
  }
  
  Future<void> _saveTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_themeKey, _themeMode.index);
      await prefs.setString(_colorSchemeKey, _colorScheme);
    } catch (e) {
      // Handle error silently
    }
  }
  
  // Get theme data based on current settings
  ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: _getColorScheme(Brightness.light),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
  
  ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: _getColorScheme(Brightness.dark),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
  
  ColorScheme _getColorScheme(Brightness brightness) {
    switch (_colorScheme) {
      case 'red':
        return ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: brightness,
        );
      case 'green':
        return ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: brightness,
        );
      case 'purple':
        return ColorScheme.fromSeed(
          seedColor: Colors.purple,
          brightness: brightness,
        );
      case 'orange':
        return ColorScheme.fromSeed(
          seedColor: Colors.orange,
          brightness: brightness,
        );
      case 'teal':
        return ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: brightness,
        );
      case 'blue':
      default:
        return ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: brightness,
        );
    }
  }
  
  // Available color schemes
  static const List<Map<String, dynamic>> availableColorSchemes = [
    {'name': 'Blue', 'value': 'blue', 'color': Colors.blue},
    {'name': 'Red', 'value': 'red', 'color': Colors.red},
    {'name': 'Green', 'value': 'green', 'color': Colors.green},
    {'name': 'Purple', 'value': 'purple', 'color': Colors.purple},
    {'name': 'Orange', 'value': 'orange', 'color': Colors.orange},
    {'name': 'Teal', 'value': 'teal', 'color': Colors.teal},
  ];
  
  // Get theme mode display name
  String get themeModeDisplayName {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }
  
  // Get color scheme display name
  String get colorSchemeDisplayName {
    final scheme = availableColorSchemes.firstWhere(
      (s) => s['value'] == _colorScheme,
      orElse: () => availableColorSchemes.first,
    );
    return scheme['name']?.toString() ?? 'Default';
  }
}
