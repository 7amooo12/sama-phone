/// Configuration class for Flask API
class FlaskApiConfig {
  /// Default API URL for development (local emulator)
  static const String devApiUrl = 'http://10.0.2.2:5000';

  /// Default API URL for development (local physical device)
  static const String devLocalApiUrl = 'http://192.168.1.100:5000';

  /// Production API URL (PythonAnywhere)
  static const String prodApiUrl = 'https://samastock.pythonanywhere.com/flutter/api';

  /// API version
  static const String apiVersion = 'v1';

  /// Connection timeout in milliseconds
  static const int connectionTimeout = 30000;

  /// Receive timeout in milliseconds
  static const int receiveTimeout = 30000;

  /// Whether to use secure connection (HTTPS)
  static const bool useHttps = true;

  /// Default API headers
  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// JWT token key name for storage
  static const String tokenKey = 'flask_api_token';

  /// JWT refresh token key name for storage
  static const String refreshTokenKey = 'flask_api_refresh_token';

  /// User info key name for storage
  static const String userKey = 'flask_api_user';
} 