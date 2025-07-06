import 'package:flutter/foundation.dart';

/// Model for Distribution Centers in the SAMA Business system
class DistributionCenterModel {
  const DistributionCenterModel({
    required this.id,
    required this.name,
    this.description,
    this.address,
    this.city,
    this.region,
    this.postalCode,
    this.managerName,
    this.managerPhone,
    this.managerEmail,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
    this.distributorCount = 0,
  });

  /// Creates a DistributionCenterModel from JSON data
  factory DistributionCenterModel.fromJson(Map<String, dynamic> json) {
    return DistributionCenterModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      region: json['region'] as String?,
      postalCode: json['postal_code'] as String?,
      managerName: json['manager_name'] as String?,
      managerPhone: json['manager_phone'] as String?,
      managerEmail: json['manager_email'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String) 
          : null,
      createdBy: json['created_by'] as String?,
      updatedBy: json['updated_by'] as String?,
      distributorCount: json['distributor_count'] as int? ?? 0,
    );
  }

  /// Creates a DistributionCenterModel from Supabase response with distributor count
  factory DistributionCenterModel.fromSupabaseWithCount(Map<String, dynamic> json) {
    return DistributionCenterModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      region: json['region'] as String?,
      postalCode: json['postal_code'] as String?,
      managerName: json['manager_name'] as String?,
      managerPhone: json['manager_phone'] as String?,
      managerEmail: json['manager_email'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String) 
          : null,
      createdBy: json['created_by'] as String?,
      updatedBy: json['updated_by'] as String?,
      distributorCount: json['distributors_count'] as int? ?? 0,
    );
  }

  final String id;
  final String name;
  final String? description;
  final String? address;
  final String? city;
  final String? region;
  final String? postalCode;
  final String? managerName;
  final String? managerPhone;
  final String? managerEmail;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;
  final int distributorCount;

  /// Converts the model to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'address': address,
      'city': city,
      'region': region,
      'postal_code': postalCode,
      'manager_name': managerName,
      'manager_phone': managerPhone,
      'manager_email': managerEmail,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'created_by': createdBy,
      'updated_by': updatedBy,
    };
  }

  /// Converts the model to JSON for database insertion
  Map<String, dynamic> toInsertJson() {
    final json = <String, dynamic>{
      'name': name,
      'is_active': isActive,
    };

    if (description != null) json['description'] = description;
    if (address != null) json['address'] = address;
    if (city != null) json['city'] = city;
    if (region != null) json['region'] = region;
    if (postalCode != null) json['postal_code'] = postalCode;
    if (managerName != null) json['manager_name'] = managerName;
    if (managerPhone != null) json['manager_phone'] = managerPhone;
    if (managerEmail != null) json['manager_email'] = managerEmail;
    if (createdBy != null) json['created_by'] = createdBy;

    return json;
  }

  /// Creates a copy of this model with updated fields
  DistributionCenterModel copyWith({
    String? id,
    String? name,
    String? description,
    String? address,
    String? city,
    String? region,
    String? postalCode,
    String? managerName,
    String? managerPhone,
    String? managerEmail,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
    int? distributorCount,
  }) {
    return DistributionCenterModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      address: address ?? this.address,
      city: city ?? this.city,
      region: region ?? this.region,
      postalCode: postalCode ?? this.postalCode,
      managerName: managerName ?? this.managerName,
      managerPhone: managerPhone ?? this.managerPhone,
      managerEmail: managerEmail ?? this.managerEmail,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      distributorCount: distributorCount ?? this.distributorCount,
    );
  }

  /// Checks if this center has complete manager information
  bool get hasCompleteManagerInfo {
    return managerName != null && 
           managerName!.isNotEmpty && 
           managerPhone != null && 
           managerPhone!.isNotEmpty;
  }

  /// Gets the display location (city, region)
  String get displayLocation {
    if (city != null && region != null) {
      return '$city, $region';
    } else if (city != null) {
      return city!;
    } else if (region != null) {
      return region!;
    }
    return 'غير محدد';
  }

  /// Gets the manager contact info for display
  String get managerContactInfo {
    if (managerName != null && managerPhone != null) {
      return '$managerName - $managerPhone';
    } else if (managerName != null) {
      return managerName!;
    } else if (managerPhone != null) {
      return managerPhone!;
    }
    return 'غير محدد';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DistributionCenterModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'DistributionCenterModel(id: $id, name: $name, city: $city, distributorCount: $distributorCount, isActive: $isActive)';
  }

  /// Validates the model data
  List<String> validate() {
    final errors = <String>[];

    if (name.trim().isEmpty) {
      errors.add('اسم المركز مطلوب');
    }

    if (managerPhone != null && managerPhone!.isNotEmpty) {
      final phoneRegex = RegExp(r'^[\+]?[0-9\-\(\)\s]{10,20}$');
      if (!phoneRegex.hasMatch(managerPhone!)) {
        errors.add('رقم هاتف المدير غير صحيح');
      }
    }

    if (managerEmail != null && managerEmail!.isNotEmpty) {
      final emailRegex = RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');
      if (!emailRegex.hasMatch(managerEmail!)) {
        errors.add('البريد الإلكتروني للمدير غير صحيح');
      }
    }

    return errors;
  }

  /// Creates an empty model for form initialization
  static DistributionCenterModel empty() {
    return DistributionCenterModel(
      id: '',
      name: '',
      createdAt: DateTime.now(),
      isActive: true,
    );
  }
}

/// Statistics model for distribution center
class DistributionCenterStatistics {
  const DistributionCenterStatistics({
    required this.totalDistributors,
    required this.activeDistributors,
    required this.inactiveDistributors,
    required this.suspendedDistributors,
    required this.pendingDistributors,
    required this.totalCreditLimit,
    required this.totalCurrentBalance,
  });

  factory DistributionCenterStatistics.fromJson(Map<String, dynamic> json) {
    return DistributionCenterStatistics(
      totalDistributors: json['total_distributors'] as int? ?? 0,
      activeDistributors: json['active_distributors'] as int? ?? 0,
      inactiveDistributors: json['inactive_distributors'] as int? ?? 0,
      suspendedDistributors: json['suspended_distributors'] as int? ?? 0,
      pendingDistributors: json['pending_distributors'] as int? ?? 0,
      totalCreditLimit: (json['total_credit_limit'] as num?)?.toDouble() ?? 0.0,
      totalCurrentBalance: (json['total_current_balance'] as num?)?.toDouble() ?? 0.0,
    );
  }

  final int totalDistributors;
  final int activeDistributors;
  final int inactiveDistributors;
  final int suspendedDistributors;
  final int pendingDistributors;
  final double totalCreditLimit;
  final double totalCurrentBalance;

  /// Gets the percentage of active distributors
  double get activePercentage {
    if (totalDistributors == 0) return 0.0;
    return (activeDistributors / totalDistributors) * 100;
  }

  /// Checks if the center has any distributors
  bool get hasDistributors => totalDistributors > 0;

  /// Gets the status distribution as a map
  Map<String, int> get statusDistribution {
    return {
      'active': activeDistributors,
      'inactive': inactiveDistributors,
      'suspended': suspendedDistributors,
      'pending': pendingDistributors,
    };
  }
}
