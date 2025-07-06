import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

/// مزود الحالة للتنقل والشاشة الرئيسية
class HomeProvider extends ChangeNotifier {
  int _currentIndex = 0;
  final List<String> _visitedTabs = ['/'];
  bool _isLoading = false;
  String _error = '';
  bool _shouldRebuildScreen = false;

  // Getters
  int get currentIndex => _currentIndex;
  List<String> get visitedTabs => _visitedTabs;
  bool get isLoading => _isLoading;
  String get error => _error;
  bool get hasError => _error.isNotEmpty;
  bool get shouldRebuildScreen => _shouldRebuildScreen;

  void changeTab(int index, String route) {
    if (_currentIndex != index) {
      _currentIndex = index;

      // Add to visited tabs if not already the last visited
      if (_visitedTabs.isEmpty || _visitedTabs.last != route) {
        _visitedTabs.add(route);

        // Limit history to 3 items to prevent memory issues
        if (_visitedTabs.length > 3) {
          _visitedTabs.removeAt(0);
        }
      }

      // Only rebuild the necessary parts
      _shouldRebuildScreen = false;
      notifyListeners();
    }
  }

  bool canGoBack() {
    return _visitedTabs.length > 1;
  }

  String goBack() {
    if (canGoBack()) {
      _visitedTabs.removeLast();
      final lastRoute = _visitedTabs.last;

      // Update the current index based on the route
      switch (lastRoute) {
        case '/notifications':
          _currentIndex = 0;
          break;
        case '/chats':
          _currentIndex = 1;
          break;
        case '/profile':
          _currentIndex = 2;
          break;
        default:
          // Keep the current index for other routes
          break;
      }

      _shouldRebuildScreen = true;
      notifyListeners();
      return lastRoute;
    }

    return '';
  }

  void resetNavigation() {
    _currentIndex = 0;
    _visitedTabs.clear();
    _visitedTabs.add('/');
    _shouldRebuildScreen = true;
    notifyListeners();
  }

  void setRebuildFlag(bool value) {
    _shouldRebuildScreen = value;
  }

  /// حفظ آخر تبويب تم زيارته
  Future<void> saveLastTab() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_tab_index', _currentIndex);
      await prefs.setString('last_tab_route', _visitedTabs.last);
      AppLogger.info('Last tab saved: $_currentIndex, ${_visitedTabs.last}');
    } catch (e) {
      _setError('فشل في حفظ آخر تبويب: $e');
      AppLogger.error('Error saving last tab: $e');
    }
  }

  /// استعادة آخر تبويب تم زيارته
  Future<void> restoreLastTab() async {
    try {
      _setLoading(true);
      final prefs = await SharedPreferences.getInstance();
      final lastIndex = prefs.getInt('last_tab_index');
      final lastRoute = prefs.getString('last_tab_route');

      if (lastIndex != null && lastRoute != null) {
        _currentIndex = lastIndex;
        if (!_visitedTabs.contains(lastRoute)) {
          _visitedTabs.add(lastRoute);
        }
        AppLogger.info('Last tab restored: $lastIndex, $lastRoute');
      }
      _setLoading(false);
    } catch (e) {
      _setError('فشل في استعادة آخر تبويب: $e');
      AppLogger.error('Error restoring last tab: $e');
    }
  }

  /// تعيين حالة التحميل
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// تعيين رسالة الخطأ
  void _setError(String errorMessage) {
    _error = errorMessage;
    _isLoading = false;
    notifyListeners();
  }

  /// مسح رسالة الخطأ
  void clearError() {
    _error = '';
    notifyListeners();
  }
}
