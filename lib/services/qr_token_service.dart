/// QR Token Service for Worker Attendance System
/// 
/// This service handles the generation of secure, time-limited QR tokens
/// for worker attendance tracking in SmartBizTracker.

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/qr_token_model.dart';
import '../utils/app_logger.dart';

class QRTokenService {
  static final QRTokenService _instance = QRTokenService._internal();
  factory QRTokenService() => _instance;
  QRTokenService._internal();

  // Shared secret key for HMAC signing (in production, this should be securely managed)
  static const String _sharedSecretKey = 'SmartBizTracker_QR_Secret_2024_v1';
  
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final Uuid _uuid = const Uuid();
  
  DeviceFingerprint? _cachedDeviceFingerprint;

  /// Generates a secure QR token for the given worker ID
  /// 
  /// Returns a Base64-encoded JSON string ready for QR code generation
  Future<String> generateQRToken(String workerId) async {
    try {
      AppLogger.info('🔄 Generating QR token for worker: $workerId');

      // Get device fingerprint
      final deviceFingerprint = await _getDeviceFingerprint();
      
      // Generate timestamp (current time in milliseconds)
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // Generate unique nonce (UUID v4)
      final nonce = _uuid.v4();
      
      // Create payload for signing
      final payload = {
        'workerId': workerId,
        'timestamp': timestamp,
        'deviceHash': deviceFingerprint.hash,
        'nonce': nonce,
      };
      
      // Generate HMAC signature
      final signature = _generateHMACSignature(payload);
      
      // Create QR token model
      final qrToken = QRTokenModel(
        workerId: workerId,
        timestamp: timestamp,
        deviceHash: deviceFingerprint.hash,
        nonce: nonce,
        signature: signature,
      );
      
      // Convert to JSON and encode as Base64
      final jsonString = qrToken.toJsonString();
      final base64String = base64Encode(utf8.encode(jsonString));
      
      AppLogger.info('✅ QR token generated successfully');
      return base64String;
      
    } catch (e) {
      AppLogger.error('❌ Error generating QR token: $e');
      throw Exception('فشل في إنشاء رمز QR: ${e.toString()}');
    }
  }

  /// Gets or creates device fingerprint
  Future<DeviceFingerprint> _getDeviceFingerprint() async {
    if (_cachedDeviceFingerprint != null) {
      return _cachedDeviceFingerprint!;
    }

    try {
      String deviceModel = 'Unknown';
      String osVersion = 'Unknown';
      String deviceId = 'Unknown';

      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await _deviceInfo.androidInfo;
        deviceModel = '${androidInfo.brand} ${androidInfo.model}';
        osVersion = 'Android ${androidInfo.version.release}';
        deviceId = androidInfo.id;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        deviceModel = '${iosInfo.name} ${iosInfo.model}';
        osVersion = '${iosInfo.systemName} ${iosInfo.systemVersion}';
        deviceId = iosInfo.identifierForVendor ?? 'Unknown';
      }

      // Create device hash using SHA-256
      final deviceString = '$deviceModel|$osVersion|$deviceId';
      final deviceHash = sha256.convert(utf8.encode(deviceString)).toString();

      _cachedDeviceFingerprint = DeviceFingerprint(
        deviceModel: deviceModel,
        osVersion: osVersion,
        deviceId: deviceId,
        hash: deviceHash,
      );

      AppLogger.info('📱 Device fingerprint created: ${deviceModel.substring(0, min(20, deviceModel.length))}...');
      return _cachedDeviceFingerprint!;
      
    } catch (e) {
      AppLogger.error('❌ Error creating device fingerprint: $e');
      
      // Fallback fingerprint
      final fallbackString = 'Fallback_${DateTime.now().millisecondsSinceEpoch}';
      final fallbackHash = sha256.convert(utf8.encode(fallbackString)).toString();
      
      _cachedDeviceFingerprint = DeviceFingerprint(
        deviceModel: 'Unknown Device',
        osVersion: 'Unknown OS',
        deviceId: fallbackString,
        hash: fallbackHash,
      );
      
      return _cachedDeviceFingerprint!;
    }
  }

  /// Generates HMAC-SHA256 signature for the payload
  String _generateHMACSignature(Map<String, dynamic> payload) {
    try {
      // Create canonical string from payload (sorted keys for consistency)
      final sortedKeys = payload.keys.toList()..sort();
      final canonicalString = sortedKeys
          .map((key) => '$key=${payload[key]}')
          .join('&');
      
      // Generate HMAC-SHA256 signature
      final key = utf8.encode(_sharedSecretKey);
      final bytes = utf8.encode(canonicalString);
      final hmacSha256 = Hmac(sha256, key);
      final digest = hmacSha256.convert(bytes);
      
      return digest.toString();
      
    } catch (e) {
      AppLogger.error('❌ Error generating HMAC signature: $e');
      throw Exception('فشل في إنشاء التوقيع الرقمي');
    }
  }

  /// Validates a QR token (for testing purposes)
  /// 
  /// In production, validation would happen on the attendance terminal
  bool validateQRToken(String base64Token) {
    try {
      // Decode Base64 and parse JSON
      final jsonString = utf8.decode(base64.decode(base64Token));
      final qrToken = QRTokenModel.fromJsonString(jsonString);
      
      // Check timestamp validity
      if (!qrToken.isValid()) {
        AppLogger.warning('⚠️ QR token expired');
        return false;
      }
      
      // Verify signature
      final payload = {
        'workerId': qrToken.workerId,
        'timestamp': qrToken.timestamp,
        'deviceHash': qrToken.deviceHash,
        'nonce': qrToken.nonce,
      };
      
      final expectedSignature = _generateHMACSignature(payload);
      if (qrToken.signature != expectedSignature) {
        AppLogger.warning('⚠️ QR token signature invalid');
        return false;
      }
      
      AppLogger.info('✅ QR token validation successful');
      return true;
      
    } catch (e) {
      AppLogger.error('❌ Error validating QR token: $e');
      return false;
    }
  }

  /// Gets device fingerprint for display purposes
  Future<DeviceFingerprint> getDeviceFingerprint() async {
    return await _getDeviceFingerprint();
  }

  /// Clears cached device fingerprint (for testing)
  void clearCache() {
    _cachedDeviceFingerprint = null;
  }
}
