// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartbiztracker_new/utils/app_logger.dart';
import 'package:smartbiztracker_new/services/supabase_service.dart';
import 'package:smartbiztracker_new/models/user_role.dart';
import 'package:flutter/foundation.dart';

class UserModel {
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
  });

  String get userRole => role.value;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: UserRole.fromString(json['role'] as String),
      phone: json['phone'] as String,
      status: json['status'] as String,
      profileImage: json['profile_image'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
      isApproved: json['is_approved'] as bool? ?? false,
      phoneNumber: json['phone_number'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role.value,
      'phone': phone,
      'status': status,
      'profile_image': profileImage,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'is_approved': isApproved,
      'phone_number': phoneNumber,
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
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      status: status ?? this.status,
      profileImage: profileImage ?? this.profileImage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isApproved: isApproved ?? this.isApproved,
      phoneNumber: phoneNumber ?? this.phoneNumber,
    );
  }

  bool isAdmin() => role == UserRole.admin;
  bool isOwner() => role == UserRole.owner;
  bool isWorker() => role == UserRole.worker;
  bool isAccountant() => role == UserRole.accountant;
  bool isClient() => role == UserRole.client;
  bool isManager() => role == UserRole.manager;

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
