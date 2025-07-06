import 'package:smartbiztracker_new/models/user_role.dart';

class UserModel {

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.phone,
    required this.status,
    this.profileImage,
    required this.createdAt,
    this.updatedAt,
    this.isApproved = false,
    this.phoneNumber,
    this.trackingLink,
  }); // Alias for compatibility

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // SECURITY FIX: Proper name handling with fallback logic
    String userName = json['name'] as String? ?? '';

    // If name is empty or just whitespace, don't use default placeholder
    // Let the UI handle empty names appropriately
    if (userName.trim().isEmpty) {
      // Check if there's a name in email (before @)
      final email = json['email'] as String? ?? '';
      if (email.isNotEmpty && email.contains('@')) {
        final emailPrefix = email.split('@')[0];
        // Only use email prefix if it looks like a name (not just numbers/random chars)
        if (emailPrefix.length > 2 && !RegExp(r'^[0-9]+$').hasMatch(emailPrefix)) {
          userName = emailPrefix;
        }
      }
    }

    return UserModel(
      id: json['id'] as String,
      name: userName, // Use processed name
      email: json['email'] as String,
      role: UserRole.fromString(json['role'] as String),
      phone: json['phone_number'] as String? ?? json['phone'] as String? ?? '',
      status: json['status'] as String,
      profileImage: _sanitizeProfileImageUrl(json['profile_image'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
      isApproved: json['status'] == 'approved' || json['status'] == 'active' || UserRole.fromString(json['role'] as String) == UserRole.admin,
      phoneNumber: json['phone_number'] as String? ?? json['phone'] as String?,
      trackingLink: json['tracking_link'] as String?,
    );
  }
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String phone;
  final String status;
  final String? profileImage;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isApproved;
  final String? phoneNumber;
  final String? trackingLink;

  String get userRole => role.value;
  String get uid => id;

  /// Get display name with fallback logic
  String get displayName {
    if (name.trim().isNotEmpty && name.trim() != 'مستخدم جديد') {
      return name.trim();
    }

    // Fallback to email prefix if name is empty or default
    if (email.isNotEmpty && email.contains('@')) {
      final emailPrefix = email.split('@')[0];
      if (emailPrefix.length > 2 && !RegExp(r'^[0-9]+$').hasMatch(emailPrefix)) {
        return emailPrefix;
      }
    }

    // Last resort fallback
    return 'مستخدم';
  }

  /// Check if the user has a valid custom name (not default or empty)
  bool get hasValidName {
    return name.trim().isNotEmpty &&
           name.trim() != 'مستخدم جديد' &&
           name.trim() != 'مستخدم';
  }

  /// Sanitize profile image URL to prevent URI parsing errors
  static String? _sanitizeProfileImageUrl(String? url) {
    if (url == null || url.isEmpty || url == 'null' || url.trim() == 'null%20') {
      return null;
    }

    final trimmedUrl = url.trim();

    // Check for invalid file:// URLs
    if (trimmedUrl.startsWith('file://')) {
      return null;
    }

    // Check for valid HTTP/HTTPS URLs
    if (trimmedUrl.startsWith('http://') || trimmedUrl.startsWith('https://')) {
      try {
        Uri.parse(trimmedUrl);
        return trimmedUrl;
      } catch (e) {
        return null;
      }
    }

    // Return null for any other invalid formats
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role.value,
      'phone_number': phone, // Fixed: Use phone_number instead of phone to match database schema
      'status': status,
      'profile_image': profileImage,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'tracking_link': trackingLink,
      // Note: Removed 'is_approved' field as database uses 'status' field instead
    };
  }

  // Alias methods for compatibility
  static UserModel fromMap(Map<String, dynamic> map) => UserModel.fromJson(map);
  Map<String, dynamic> toMap() => toJson();

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    UserRole? role,
    String? phone,
    String? status,
    String? profileImage,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isApproved,
    String? phoneNumber,
    String? trackingLink,
  }) {
    // CRITICAL FIX: Sync phone and phoneNumber fields
    // If phoneNumber is provided, use it for both phone and phoneNumber
    // If phone is provided, use it for both phone and phoneNumber
    // This ensures consistency between the two fields
    final String? updatedPhoneValue = phoneNumber ?? phone ?? this.phone;

    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      phone: updatedPhoneValue ?? '', // Use the synchronized phone value
      status: status ?? this.status,
      profileImage: profileImage ?? this.profileImage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isApproved: isApproved ?? this.isApproved,
      phoneNumber: updatedPhoneValue, // Use the same synchronized value
      trackingLink: trackingLink ?? this.trackingLink,
    );
  }

  bool isAdmin() => role == UserRole.admin;
  bool isOwner() => role == UserRole.owner;
  bool isWorker() => role == UserRole.worker;
  bool isAccountant() => role == UserRole.accountant;
  bool isClient() => role == UserRole.client;
  bool isManager() => role == UserRole.manager;
  bool isWarehouseManager() => role == UserRole.warehouseManager;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          email == other.email &&
          phone == other.phone &&
          role == other.role &&
          status == other.status &&
          profileImage == other.profileImage &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      email.hashCode ^
      phone.hashCode ^
      role.hashCode ^
      status.hashCode ^
      profileImage.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode;
}
