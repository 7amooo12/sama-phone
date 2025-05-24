import 'package:flutter/foundation.dart';
import 'package:smartbiztracker_new/models/flask_models.dart';
import 'package:smartbiztracker_new/services/flask_api_service.dart';

enum FlaskAuthStatus {
  /// User has not been authenticated yet
  initial,

  /// User is in the process of authenticating
  authenticating,

  /// User has been authenticated
  authenticated,

  /// User authentication failed
  failed,

  /// User is logged out
  unauthenticated,
}

class FlaskAuthProvider with ChangeNotifier {
  // Internal states
  FlaskAuthStatus _status = FlaskAuthStatus.initial;
  String? _errorMessage;
  bool _isInitialized = false;

  // Services
  final FlaskApiService _apiService = FlaskApiService();

  // Getters
  FlaskAuthStatus get status => _status;
  String? get errorMessage => _errorMessage;
  FlaskUserModel? get currentUser => _apiService.currentUser;
  bool get isAuthenticated => _apiService.isAuthenticated;
  bool get isInitialized => _isInitialized;

  // Initialize the provider
  Future<void> initialize() async {
    if (_isInitialized) return;

    _status = FlaskAuthStatus.authenticating;
    notifyListeners();

    try {
      await _apiService.init();
      _status = _apiService.isAuthenticated
          ? FlaskAuthStatus.authenticated
          : FlaskAuthStatus.unauthenticated;
    } catch (e) {
      _status = FlaskAuthStatus.unauthenticated;
      _errorMessage = e.toString();
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  // Login
  Future<bool> login(String username, String password) async {
    if (status == FlaskAuthStatus.authenticating) return false;

    _status = FlaskAuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      final authResult = await _apiService.login(username, password);

      if (authResult.isAuthenticated) {
        _status = FlaskAuthStatus.authenticated;
        notifyListeners();
        return true;
      } else {
        _status = FlaskAuthStatus.failed;
        _errorMessage = authResult.error ?? 'Authentication failed';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _status = FlaskAuthStatus.failed;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Register
  Future<bool> register(String username, String email, String password) async {
    if (status == FlaskAuthStatus.authenticating) return false;

    _status = FlaskAuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      final authResult = await _apiService.register(username, email, password);

      if (authResult.isAuthenticated) {
        _status = FlaskAuthStatus.authenticated;
        notifyListeners();
        return true;
      } else {
        _status = FlaskAuthStatus.failed;
        _errorMessage = authResult.error ?? 'Registration failed';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _status = FlaskAuthStatus.failed;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    await _apiService.logout();
    _status = FlaskAuthStatus.unauthenticated;
    _errorMessage = null;
    notifyListeners();
  }

  // Refresh token
  Future<bool> refreshToken() async {
    try {
      final result = await _apiService.refreshAccessToken();
      if (result) {
        _status = FlaskAuthStatus.authenticated;
        _errorMessage = null;
        notifyListeners();
        return true;
      } else {
        _status = FlaskAuthStatus.unauthenticated;
        _errorMessage = 'Token refresh failed';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _status = FlaskAuthStatus.unauthenticated;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Check if user is admin
  bool get isAdmin => currentUser?.isAdmin ?? false;
} 