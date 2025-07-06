import 'package:flutter/foundation.dart';

/// Enum for distributor status
enum DistributorStatus {
  active('active', 'نشط'),
  inactive('inactive', 'غير نشط'),
  suspended('suspended', 'معلق'),
  pending('pending', 'في الانتظار');

  const DistributorStatus(this.value, this.displayName);
  final String value;
  final String displayName;

  static DistributorStatus fromString(String value) {
    return DistributorStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => DistributorStatus.active,
    );
  }
}

/// Model for Distributors in the SAMA Business system
class DistributorModel {
  const DistributorModel({
    required this.id,
    required this.distributionCenterId,
    required this.name,
    required this.contactPhone,
    required this.showroomName,
    this.showroomAddress,
    this.email,
    this.nationalId,
    this.licenseNumber,
    this.taxNumber,
    this.bankAccountNumber,
    this.bankName,
    this.commissionRate = 0.0,
    this.creditLimit = 0.0,
    this.currentBalance = 0.0,
    this.joinDate,
    this.contractStartDate,
    this.contractEndDate,
    this.status = DistributorStatus.active,
    this.notes,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
    this.centerName,
  });

  /// Creates a DistributorModel from JSON data
  factory DistributorModel.fromJson(Map<String, dynamic> json) {
    return DistributorModel(
      id: json['id'] as String,
      distributionCenterId: json['distribution_center_id'] as String,
      name: json['name'] as String,
      contactPhone: json['contact_phone'] as String,
      showroomName: json['showroom_name'] as String,
      showroomAddress: json['showroom_address'] as String?,
      email: json['email'] as String?,
      nationalId: json['national_id'] as String?,
      licenseNumber: json['license_number'] as String?,
      taxNumber: json['tax_number'] as String?,
      bankAccountNumber: json['bank_account_number'] as String?,
      bankName: json['bank_name'] as String?,
      commissionRate: (json['commission_rate'] as num?)?.toDouble() ?? 0.0,
      creditLimit: (json['credit_limit'] as num?)?.toDouble() ?? 0.0,
      currentBalance: (json['current_balance'] as num?)?.toDouble() ?? 0.0,
      joinDate: json['join_date'] != null 
          ? DateTime.parse(json['join_date'] as String) 
          : null,
      contractStartDate: json['contract_start_date'] != null 
          ? DateTime.parse(json['contract_start_date'] as String) 
          : null,
      contractEndDate: json['contract_end_date'] != null 
          ? DateTime.parse(json['contract_end_date'] as String) 
          : null,
      status: DistributorStatus.fromString(json['status'] as String? ?? 'active'),
      notes: json['notes'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String) 
          : null,
      createdBy: json['created_by'] as String?,
      updatedBy: json['updated_by'] as String?,
      centerName: json['center_name'] as String?,
    );
  }

  final String id;
  final String distributionCenterId;
  final String name;
  final String contactPhone;
  final String showroomName;
  final String? showroomAddress;
  final String? email;
  final String? nationalId;
  final String? licenseNumber;
  final String? taxNumber;
  final String? bankAccountNumber;
  final String? bankName;
  final double commissionRate;
  final double creditLimit;
  final double currentBalance;
  final DateTime? joinDate;
  final DateTime? contractStartDate;
  final DateTime? contractEndDate;
  final DistributorStatus status;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;
  final String? centerName;

  /// Converts the model to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'distribution_center_id': distributionCenterId,
      'name': name,
      'contact_phone': contactPhone,
      'showroom_name': showroomName,
      'showroom_address': showroomAddress,
      'email': email,
      'national_id': nationalId,
      'license_number': licenseNumber,
      'tax_number': taxNumber,
      'bank_account_number': bankAccountNumber,
      'bank_name': bankName,
      'commission_rate': commissionRate,
      'credit_limit': creditLimit,
      'current_balance': currentBalance,
      'join_date': joinDate?.toIso8601String().split('T')[0],
      'contract_start_date': contractStartDate?.toIso8601String().split('T')[0],
      'contract_end_date': contractEndDate?.toIso8601String().split('T')[0],
      'status': status.value,
      'notes': notes,
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
      'distribution_center_id': distributionCenterId,
      'name': name,
      'contact_phone': contactPhone,
      'showroom_name': showroomName,
      'status': status.value,
      'is_active': isActive,
      'commission_rate': commissionRate,
      'credit_limit': creditLimit,
      'current_balance': currentBalance,
    };

    if (showroomAddress != null) json['showroom_address'] = showroomAddress;
    if (email != null) json['email'] = email;
    if (nationalId != null) json['national_id'] = nationalId;
    if (licenseNumber != null) json['license_number'] = licenseNumber;
    if (taxNumber != null) json['tax_number'] = taxNumber;
    if (bankAccountNumber != null) json['bank_account_number'] = bankAccountNumber;
    if (bankName != null) json['bank_name'] = bankName;
    if (joinDate != null) json['join_date'] = joinDate!.toIso8601String().split('T')[0];
    if (contractStartDate != null) json['contract_start_date'] = contractStartDate!.toIso8601String().split('T')[0];
    if (contractEndDate != null) json['contract_end_date'] = contractEndDate!.toIso8601String().split('T')[0];
    if (notes != null) json['notes'] = notes;
    if (createdBy != null) json['created_by'] = createdBy;

    return json;
  }

  /// Creates a copy of this model with updated fields
  DistributorModel copyWith({
    String? id,
    String? distributionCenterId,
    String? name,
    String? contactPhone,
    String? showroomName,
    String? showroomAddress,
    String? email,
    String? nationalId,
    String? licenseNumber,
    String? taxNumber,
    String? bankAccountNumber,
    String? bankName,
    double? commissionRate,
    double? creditLimit,
    double? currentBalance,
    DateTime? joinDate,
    DateTime? contractStartDate,
    DateTime? contractEndDate,
    DistributorStatus? status,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
    String? centerName,
  }) {
    return DistributorModel(
      id: id ?? this.id,
      distributionCenterId: distributionCenterId ?? this.distributionCenterId,
      name: name ?? this.name,
      contactPhone: contactPhone ?? this.contactPhone,
      showroomName: showroomName ?? this.showroomName,
      showroomAddress: showroomAddress ?? this.showroomAddress,
      email: email ?? this.email,
      nationalId: nationalId ?? this.nationalId,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      taxNumber: taxNumber ?? this.taxNumber,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      bankName: bankName ?? this.bankName,
      commissionRate: commissionRate ?? this.commissionRate,
      creditLimit: creditLimit ?? this.creditLimit,
      currentBalance: currentBalance ?? this.currentBalance,
      joinDate: joinDate ?? this.joinDate,
      contractStartDate: contractStartDate ?? this.contractStartDate,
      contractEndDate: contractEndDate ?? this.contractEndDate,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      centerName: centerName ?? this.centerName,
    );
  }

  /// Gets the formatted phone number for display
  String get formattedPhone {
    if (contactPhone.startsWith('+')) {
      return contactPhone;
    } else if (contactPhone.startsWith('01')) {
      return '+2$contactPhone';
    }
    return contactPhone;
  }

  /// Gets the contract status
  String get contractStatus {
    if (contractStartDate == null || contractEndDate == null) {
      return 'لا يوجد عقد';
    }
    
    final now = DateTime.now();
    if (now.isBefore(contractStartDate!)) {
      return 'لم يبدأ بعد';
    } else if (now.isAfter(contractEndDate!)) {
      return 'منتهي الصلاحية';
    } else {
      return 'ساري';
    }
  }

  /// Checks if the contract is active
  bool get isContractActive {
    if (contractStartDate == null || contractEndDate == null) {
      return false;
    }
    
    final now = DateTime.now();
    return now.isAfter(contractStartDate!) && now.isBefore(contractEndDate!);
  }

  /// Gets the available credit amount
  double get availableCredit {
    return creditLimit - currentBalance;
  }

  /// Checks if the distributor has exceeded credit limit
  bool get hasExceededCreditLimit {
    return currentBalance > creditLimit;
  }

  /// Gets the credit utilization percentage
  double get creditUtilizationPercentage {
    if (creditLimit == 0) return 0.0;
    return (currentBalance / creditLimit) * 100;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DistributorModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'DistributorModel(id: $id, name: $name, showroomName: $showroomName, status: ${status.displayName})';
  }

  /// Validates the model data
  List<String> validate() {
    final errors = <String>[];

    if (name.trim().isEmpty) {
      errors.add('اسم الموزع مطلوب');
    }

    if (contactPhone.trim().isEmpty) {
      errors.add('رقم الهاتف مطلوب');
    } else {
      final phoneRegex = RegExp(r'^[\+]?[0-9\-\(\)\s]{10,20}$');
      if (!phoneRegex.hasMatch(contactPhone)) {
        errors.add('رقم الهاتف غير صحيح');
      }
    }

    if (showroomName.trim().isEmpty) {
      errors.add('اسم المعرض مطلوب');
    }

    if (email != null && email!.isNotEmpty) {
      final emailRegex = RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');
      if (!emailRegex.hasMatch(email!)) {
        errors.add('البريد الإلكتروني غير صحيح');
      }
    }

    if (commissionRate < 0 || commissionRate > 100) {
      errors.add('نسبة العمولة يجب أن تكون بين 0 و 100');
    }

    if (creditLimit < 0) {
      errors.add('حد الائتمان يجب أن يكون أكبر من أو يساوي صفر');
    }

    if (contractStartDate != null && contractEndDate != null) {
      if (contractEndDate!.isBefore(contractStartDate!)) {
        errors.add('تاريخ انتهاء العقد يجب أن يكون بعد تاريخ البداية');
      }
    }

    return errors;
  }

  /// Creates an empty model for form initialization
  static DistributorModel empty(String distributionCenterId) {
    return DistributorModel(
      id: '',
      distributionCenterId: distributionCenterId,
      name: '',
      contactPhone: '',
      showroomName: '',
      createdAt: DateTime.now(),
      isActive: true,
      status: DistributorStatus.active,
      joinDate: DateTime.now(),
    );
  }
}
