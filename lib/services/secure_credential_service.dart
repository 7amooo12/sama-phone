/// Secure Credential Storage Service for Biometric Authentication
/// 
/// This service handles secure storage and retrieval of user credentials
/// for biometric authentication using flutter_secure_storage.

import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import '../utils/app_logger.dart';

/// Model for stored biometric credentials
class BiometricCredentials {
  final String email;
  final String encryptedPassword;
  final DateTime lastUsed;
  final bool isEnabled;

  BiometricCredentials({
    required this.email,
    required this.encryptedPassword,
    required this.lastUsed,
    required this.isEnabled,
  });

  Map<String, dynamic> toJson() => {
    'email': email,
    'encryptedPassword': encryptedPassword,
    'lastUsed': lastUsed.toIso8601String(),
    'isEnabled': isEnabled,
  };

  factory BiometricCredentials.fromJson(Map<String, dynamic> json) => BiometricCredentials(
    email: json['email'] ?? '',
    encryptedPassword: json['encryptedPassword'] ?? '',
    lastUsed: DateTime.tryParse(json['lastUsed'] ?? '') ?? DateTime.now(),
    isEnabled: json['isEnabled'] ?? false,
  );
}

/// Result of biometric authentication operations
class BiometricAuthResult {
  final bool success;
  final String? email;
  final String? password;
  final String? errorMessage;

  BiometricAuthResult({
    required this.success,
    this.email,
    this.password,
    this.errorMessage,
  });
}

/// Secure credential storage service for biometric authentication
class SecureCredentialService {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_PKCS1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const String _credentialsKey = 'biometric_credentials';
  static const String _biometricEnabledKey = 'biometric_enabled';
  static final LocalAuthentication _localAuth = LocalAuthentication();

  /// Check if biometric authentication is available on the device
  static Future<bool> isBiometricAvailable() async {
    try {
      final bool isAvailable = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();
      final List<BiometricType> availableBiometrics = await _localAuth.getAvailableBiometrics();
      
      AppLogger.info('🔍 Biometric availability check: available=$isAvailable, supported=$isDeviceSupported, types=$availableBiometrics');
      
      return isAvailable && isDeviceSupported && availableBiometrics.isNotEmpty;
    } catch (e) {
      AppLogger.error('❌ Error checking biometric availability: $e');
      return false;
    }
  }

  /// Store credentials securely for biometric authentication
  static Future<bool> storeCredentials({
    required String email,
    required String password,
  }) async {
    try {
      AppLogger.info('🔐 Storing credentials for biometric authentication: $email');

      // Check if biometric authentication is available
      if (!await isBiometricAvailable()) {
        AppLogger.warning('⚠️ Biometric authentication not available on this device');
        return false;
      }

      // Create credentials object
      final credentials = BiometricCredentials(
        email: email,
        encryptedPassword: _encryptPassword(password),
        lastUsed: DateTime.now(),
        isEnabled: true,
      );

      // Store credentials securely
      await _secureStorage.write(
        key: _credentialsKey,
        value: jsonEncode(credentials.toJson()),
      );

      // Mark biometric as enabled
      await _secureStorage.write(
        key: _biometricEnabledKey,
        value: 'true',
      );

      AppLogger.info('✅ Credentials stored successfully for biometric authentication');
      return true;
    } catch (e) {
      AppLogger.error('❌ Error storing credentials: $e');
      return false;
    }
  }

  /// Retrieve credentials using biometric authentication
  static Future<BiometricAuthResult> authenticateAndGetCredentials() async {
    try {
      AppLogger.info('🔐 Starting biometric authentication...');

      // Check if biometric is enabled
      if (!await isBiometricEnabled()) {
        return BiometricAuthResult(
          success: false,
          errorMessage: 'المصادقة البيومترية غير مفعلة',
        );
      }

      // Check if biometric authentication is available
      if (!await isBiometricAvailable()) {
        return BiometricAuthResult(
          success: false,
          errorMessage: 'المصادقة البيومترية غير متاحة على هذا الجهاز',
        );
      }

      // Perform biometric authentication
      final bool isAuthenticated = await _localAuth.authenticate(
        localizedReason: 'قم بالمصادقة للدخول إلى حسابك',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (!isAuthenticated) {
        return BiometricAuthResult(
          success: false,
          errorMessage: 'فشلت المصادقة البيومترية',
        );
      }

      // Retrieve stored credentials
      final credentialsJson = await _secureStorage.read(key: _credentialsKey);
      if (credentialsJson == null) {
        return BiometricAuthResult(
          success: false,
          errorMessage: 'لا توجد بيانات مخزنة للمصادقة البيومترية',
        );
      }

      final credentials = BiometricCredentials.fromJson(jsonDecode(credentialsJson));
      final decryptedPassword = _decryptPassword(credentials.encryptedPassword);

      // Update last used timestamp
      await _updateLastUsed(credentials);

      AppLogger.info('✅ Biometric authentication successful for: ${credentials.email}');

      return BiometricAuthResult(
        success: true,
        email: credentials.email,
        password: decryptedPassword,
      );
    } catch (e) {
      AppLogger.error('❌ Error during biometric authentication: $e');
      return BiometricAuthResult(
        success: false,
        errorMessage: 'خطأ في المصادقة البيومترية: ${e.toString()}',
      );
    }
  }

  /// Check if biometric authentication is enabled
  static Future<bool> isBiometricEnabled() async {
    try {
      final enabled = await _secureStorage.read(key: _biometricEnabledKey);
      return enabled == 'true';
    } catch (e) {
      AppLogger.error('❌ Error checking biometric enabled status: $e');
      return false;
    }
  }

  /// Disable biometric authentication and clear stored credentials
  static Future<bool> disableBiometric() async {
    try {
      AppLogger.info('🔒 Disabling biometric authentication...');
      
      await _secureStorage.delete(key: _credentialsKey);
      await _secureStorage.delete(key: _biometricEnabledKey);
      
      AppLogger.info('✅ Biometric authentication disabled successfully');
      return true;
    } catch (e) {
      AppLogger.error('❌ Error disabling biometric authentication: $e');
      return false;
    }
  }

  /// Get stored email for quick login display
  static Future<String?> getStoredEmail() async {
    try {
      final credentialsJson = await _secureStorage.read(key: _credentialsKey);
      if (credentialsJson == null) return null;
      
      final credentials = BiometricCredentials.fromJson(jsonDecode(credentialsJson));
      return credentials.email;
    } catch (e) {
      AppLogger.error('❌ Error getting stored email: $e');
      return null;
    }
  }

  /// Simple encryption for password (in production, use more robust encryption)
  static String _encryptPassword(String password) {
    // For demo purposes, using base64 encoding
    // In production, use proper encryption with device-specific keys
    return base64Encode(utf8.encode(password));
  }

  /// Simple decryption for password
  static String _decryptPassword(String encryptedPassword) {
    try {
      return utf8.decode(base64Decode(encryptedPassword));
    } catch (e) {
      AppLogger.error('❌ Error decrypting password: $e');
      return '';
    }
  }

  /// Update last used timestamp
  static Future<void> _updateLastUsed(BiometricCredentials credentials) async {
    try {
      final updatedCredentials = BiometricCredentials(
        email: credentials.email,
        encryptedPassword: credentials.encryptedPassword,
        lastUsed: DateTime.now(),
        isEnabled: credentials.isEnabled,
      );

      await _secureStorage.write(
        key: _credentialsKey,
        value: jsonEncode(updatedCredentials.toJson()),
      );
    } catch (e) {
      AppLogger.error('❌ Error updating last used timestamp: $e');
    }
  }
}
