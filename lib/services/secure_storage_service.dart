import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class SecureStorageService {
  static final SecureStorageService _instance = SecureStorageService._internal();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Keys for storage
  static const String _credentialsKey = 'user_credentials';
  static const String _rememberMeKey = 'remember_me';

  factory SecureStorageService() {
    return _instance;
  }

  SecureStorageService._internal();

  // Save user credentials securely
  Future<void> saveCredentials(String email, String password) async {
    final credentials = {
      'email': email,
      'password': password,
    };
    await _storage.write(
      key: _credentialsKey,
      value: jsonEncode(credentials),
    );
  }

  // Get saved credentials
  Future<Map<String, String>?> getCredentials() async {
    final data = await _storage.read(key: _credentialsKey);
    if (data == null) return null;
    
    try {
      final Map<String, dynamic> decoded = jsonDecode(data);
      return {
        'email': decoded['email'],
        'password': decoded['password'],
      };
    } catch (e) {
      print('Error decoding credentials: $e');
      return null;
    }
  }

  // Delete saved credentials
  Future<void> deleteCredentials() async {
    await _storage.delete(key: _credentialsKey);
  }

  // Save remember me preference
  Future<void> saveRememberMe(bool value) async {
    await _storage.write(
      key: _rememberMeKey,
      value: value.toString(),
    );
  }

  // Get remember me preference
  Future<bool> getRememberMe() async {
    final value = await _storage.read(key: _rememberMeKey);
    return value == 'true';
  }

  // Clear all stored data
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
} 