class CategoryModel {

  CategoryModel({
    required this.id,
    required this.name,
    required this.description,
    this.imageUrl,
    this.iconName,
    this.productCount = 0,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
    this.metadata,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      imageUrl: json['image_url']?.toString(),
      iconName: json['icon_name']?.toString(),
      productCount: (json['product_count'] as int?) ?? 0,
      isActive: (json['is_active'] as bool?) ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'].toString())
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
  final String id;
  final String name;
  final String description;
  final String? imageUrl;
  final String? iconName;
  final int productCount;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? metadata;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'image_url': imageUrl,
      'icon_name': iconName,
      'product_count': productCount,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'metadata': metadata,
    };
  }

  CategoryModel copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    String? iconName,
    int? productCount,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      iconName: iconName ?? this.iconName,
      productCount: productCount ?? this.productCount,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CategoryModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'CategoryModel(id: $id, name: $name, productCount: $productCount)';
  }

  // Helper methods
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
  bool get hasIcon => iconName != null && iconName!.isNotEmpty;
  bool get hasProducts => productCount > 0;

  String get displayName => name.isNotEmpty ? name : 'فئة غير محددة';
  String get displayDescription => description.isNotEmpty ? description : 'لا يوجد وصف';
}

// Predefined categories for quick setup
class PredefinedCategories {
  static List<CategoryModel> get defaultCategories => [
    CategoryModel(
      id: 'electronics',
      name: 'إلكترونيات',
      description: 'أجهزة إلكترونية ومعدات تقنية',
      iconName: 'electronics',
      createdAt: DateTime.now(),
    ),
    CategoryModel(
      id: 'clothing',
      name: 'ملابس',
      description: 'ملابس وأزياء للرجال والنساء والأطفال',
      iconName: 'clothing',
      createdAt: DateTime.now(),
    ),
    CategoryModel(
      id: 'food',
      name: 'طعام ومشروبات',
      description: 'مواد غذائية ومشروبات',
      iconName: 'food',
      createdAt: DateTime.now(),
    ),
    CategoryModel(
      id: 'books',
      name: 'كتب',
      description: 'كتب ومواد تعليمية',
      iconName: 'books',
      createdAt: DateTime.now(),
    ),
    CategoryModel(
      id: 'home',
      name: 'منزل وحديقة',
      description: 'أدوات منزلية ومعدات الحديقة',
      iconName: 'home',
      createdAt: DateTime.now(),
    ),
    CategoryModel(
      id: 'sports',
      name: 'رياضة',
      description: 'معدات رياضية وأدوات اللياقة البدنية',
      iconName: 'sports',
      createdAt: DateTime.now(),
    ),
    CategoryModel(
      id: 'beauty',
      name: 'جمال وعناية',
      description: 'منتجات التجميل والعناية الشخصية',
      iconName: 'beauty',
      createdAt: DateTime.now(),
    ),
    CategoryModel(
      id: 'automotive',
      name: 'سيارات',
      description: 'قطع غيار ومعدات السيارات',
      iconName: 'automotive',
      createdAt: DateTime.now(),
    ),
  ];
}
