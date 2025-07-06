import 'package:smartbiztracker_new/models/product_model.dart';

/// نموذج المخزن
class WarehouseModel {
  final String id;
  final String name;
  final String address;
  final String? description;
  final bool isActive;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? metadata;

  const WarehouseModel({
    required this.id,
    required this.name,
    required this.address,
    this.description,
    this.isActive = true,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
    this.metadata,
  });

  factory WarehouseModel.fromJson(Map<String, dynamic> json) {
    return WarehouseModel(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      description: json['description'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String) 
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'description': description,
      'is_active': isActive,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'metadata': metadata,
    };
  }

  WarehouseModel copyWith({
    String? id,
    String? name,
    String? address,
    String? description,
    bool? isActive,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return WarehouseModel(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WarehouseModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'WarehouseModel(id: $id, name: $name, address: $address)';
  }

  /// إنشاء خيار "جميع المخازن" الخاص
  static WarehouseModel createAllWarehousesOption() {
    return WarehouseModel(
      id: 'ALL_WAREHOUSES',
      name: 'جميع المخازن',
      address: 'توزيع ذكي عبر جميع المخازن المتاحة',
      description: 'خيار التوزيع الذكي التلقائي عبر جميع المخازن حسب توفر المنتجات',
      isActive: true,
      createdBy: 'system',
      createdAt: DateTime.now(),
    );
  }

  /// التحقق من كون هذا خيار "جميع المخازن"
  bool get isAllWarehousesOption => id == 'ALL_WAREHOUSES';

  /// الحصول على أيقونة المخزن
  String get iconName {
    if (isAllWarehousesOption) return 'all_warehouses';
    return 'warehouse';
  }

  /// الحصول على وصف مختصر
  String get shortDescription {
    if (isAllWarehousesOption) return 'توزيع ذكي تلقائي';
    return address;
  }
}
