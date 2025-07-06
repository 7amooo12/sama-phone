/// QR Token Model for Worker Attendance System
/// 
/// This model represents the secure payload structure for one-time QR tokens
/// used in the SmartBizTracker attendance tracking system.

import 'dart:convert';

class QRTokenModel {
  final String workerId;
  final int timestamp;
  final String deviceHash;
  final String nonce;
  final String signature;

  const QRTokenModel({
    required this.workerId,
    required this.timestamp,
    required this.deviceHash,
    required this.nonce,
    required this.signature,
  });

  /// Creates a QR token from JSON data
  factory QRTokenModel.fromJson(Map<String, dynamic> json) {
    return QRTokenModel(
      workerId: json['workerId'] as String,
      timestamp: json['timestamp'] as int,
      deviceHash: json['deviceHash'] as String,
      nonce: json['nonce'] as String,
      signature: json['signature'] as String,
    );
  }

  /// Converts the QR token to JSON format
  Map<String, dynamic> toJson() {
    return {
      'workerId': workerId,
      'timestamp': timestamp,
      'deviceHash': deviceHash,
      'nonce': nonce,
      'signature': signature,
    };
  }

  /// Converts the QR token to a JSON string for QR code generation
  String toJsonString() {
    return jsonEncode(toJson());
  }

  /// Creates a QR token from a JSON string
  factory QRTokenModel.fromJsonString(String jsonString) {
    final Map<String, dynamic> json = jsonDecode(jsonString);
    return QRTokenModel.fromJson(json);
  }

  /// Checks if the token is still valid based on timestamp
  /// 
  /// [validityDurationSeconds] - Token validity duration (default: 20 seconds)
  /// [clockSkewToleranceSeconds] - Clock skew tolerance (default: 5 seconds)
  bool isValid({
    int validityDurationSeconds = 20,
    int clockSkewToleranceSeconds = 5,
  }) {
    final currentTimestamp = DateTime.now().millisecondsSinceEpoch;
    final tokenAge = currentTimestamp - timestamp;
    final maxAge = (validityDurationSeconds + clockSkewToleranceSeconds) * 1000;
    
    return tokenAge <= maxAge && tokenAge >= -clockSkewToleranceSeconds * 1000;
  }

  /// Gets the remaining validity time in seconds
  int getRemainingValiditySeconds({int validityDurationSeconds = 20}) {
    final currentTimestamp = DateTime.now().millisecondsSinceEpoch;
    final tokenAge = currentTimestamp - timestamp;
    final remainingMs = (validityDurationSeconds * 1000) - tokenAge;
    
    return (remainingMs / 1000).ceil().clamp(0, validityDurationSeconds);
  }

  /// Creates a copy of the token with updated fields
  QRTokenModel copyWith({
    String? workerId,
    int? timestamp,
    String? deviceHash,
    String? nonce,
    String? signature,
  }) {
    return QRTokenModel(
      workerId: workerId ?? this.workerId,
      timestamp: timestamp ?? this.timestamp,
      deviceHash: deviceHash ?? this.deviceHash,
      nonce: nonce ?? this.nonce,
      signature: signature ?? this.signature,
    );
  }

  @override
  String toString() {
    return 'QRTokenModel(workerId: $workerId, timestamp: $timestamp, deviceHash: $deviceHash, nonce: $nonce, signature: $signature)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is QRTokenModel &&
        other.workerId == workerId &&
        other.timestamp == timestamp &&
        other.deviceHash == deviceHash &&
        other.nonce == nonce &&
        other.signature == signature;
  }

  @override
  int get hashCode {
    return workerId.hashCode ^
        timestamp.hashCode ^
        deviceHash.hashCode ^
        nonce.hashCode ^
        signature.hashCode;
  }
}

/// Device fingerprint model for enhanced security
class DeviceFingerprint {
  final String deviceModel;
  final String osVersion;
  final String deviceId;
  final String hash;

  const DeviceFingerprint({
    required this.deviceModel,
    required this.osVersion,
    required this.deviceId,
    required this.hash,
  });

  /// Creates a device fingerprint from JSON data
  factory DeviceFingerprint.fromJson(Map<String, dynamic> json) {
    return DeviceFingerprint(
      deviceModel: json['deviceModel'] as String,
      osVersion: json['osVersion'] as String,
      deviceId: json['deviceId'] as String,
      hash: json['hash'] as String,
    );
  }

  /// Converts the device fingerprint to JSON format
  Map<String, dynamic> toJson() {
    return {
      'deviceModel': deviceModel,
      'osVersion': osVersion,
      'deviceId': deviceId,
      'hash': hash,
    };
  }

  @override
  String toString() {
    return 'DeviceFingerprint(deviceModel: $deviceModel, osVersion: $osVersion, deviceId: $deviceId, hash: $hash)';
  }
}
