

class ProductModel {

  ProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.quantity,
    required this.category,
    this.imageUrl,
    this.status = statusActive,
    required this.createdAt,
    this.updatedAt,
    this.metadata,
    required this.isActive,
    required this.sku,
    this.discountPrice,
    required this.reorderPoint,
    required this.images,
    this.purchasePrice,
    this.manufacturingCost,
    this.supplier,
    this.originalPrice,
    this.tags,
    this.minimumStock = 10,
    this.barcode,
    this.manufacturer,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    // Handle different API response formats
    double price = 0.0;
    if (json['selling_price'] != null) {
      price = (json['selling_price'] as num).toDouble();
    } else if (json['final_price'] != null) {
      price = (json['final_price'] as num).toDouble();
    } else if (json['price'] != null) {
      price = (json['price'] as num).toDouble();
    }

    int quantity = 0;
    if (json['stock_quantity'] != null) {
      quantity = json['stock_quantity'] as int;
    } else if (json['quantity'] != null) {
      quantity = json['quantity'] as int;
    } else if (json['stock'] != null) {
      quantity = json['stock'] as int;
    }

    double? purchasePrice;
    if (json['purchase_price'] != null) {
      purchasePrice = (json['purchase_price'] as num).toDouble();
    }

    String? imageUrl;
    if (json['image_url'] != null) {
      imageUrl = json['image_url'].toString();
    } else if (json['imageUrl'] != null) {
      imageUrl = json['imageUrl'].toString();
    }

    List<String> images = [];
    if (json['images'] != null && json['images'] is List) {
      images = List<String>.from(json['images'] as List);
    } else if (imageUrl != null) {
      images = [imageUrl];
    }

    return ProductModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      price: price,
      quantity: quantity,
      category: json['category']?.toString() ?? json['category_name']?.toString() ?? '',
      imageUrl: imageUrl,
      status: json['status']?.toString() ?? statusActive,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
      isActive: json['active'] as bool? ?? json['is_active'] as bool? ?? json['is_visible'] as bool? ?? true,
      sku: json['sku']?.toString() ?? 'SKU-${json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch}',
      discountPrice: json['discount_price'] != null ? (json['discount_price'] as num?)?.toDouble() : null,
      reorderPoint: json['reorder_point'] as int? ?? 10,
      images: images,
      purchasePrice: purchasePrice,
      manufacturingCost: json['manufacturing_cost'] != null ? (json['manufacturing_cost'] as num?)?.toDouble() : null,
      supplier: json['supplier']?.toString(),
      originalPrice: json['original_price'] != null ? (json['original_price'] as num?)?.toDouble() : null,
      tags: json['tags'] != null ? List<String>.from(json['tags'] as List) : null,
      minimumStock: json['minimum_stock'] as int? ?? 10,
      barcode: json['barcode']?.toString(),
      manufacturer: json['manufacturer']?.toString(),
    );
  }
  final String id;
  final String name;
  final String description;
  final double price;
  final int quantity;
  final String category;
  final String? imageUrl;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? metadata;
  final bool isActive;
  final String sku;
  final double? discountPrice;
  final int reorderPoint;
  final List<String> images;
  final double? purchasePrice;
  final double? manufacturingCost;
  final String? supplier;
  final double? originalPrice;
  final List<String>? tags;
  final int minimumStock;
  final String? barcode;
  final String? manufacturer;

  static const String statusActive = 'active';
  static const String statusInactive = 'inactive';
  static const String statusOutOfStock = 'out_of_stock';
  static const String statusDiscontinued = 'discontinued';
  static const String statusPending = 'pending';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'quantity': quantity,
      'category': category,
      'image_url': imageUrl,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'metadata': metadata,
      'is_active': isActive,
      'sku': sku,
      'discount_price': discountPrice,
      'reorder_point': reorderPoint,
      'images': images,
      'purchase_price': purchasePrice,
      'manufacturing_cost': manufacturingCost,
      'supplier': supplier,
      'original_price': originalPrice,
      'tags': tags,
      'minimum_stock': minimumStock,
      'barcode': barcode,
      'manufacturer': manufacturer,
    };
  }

  ProductModel copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    int? quantity,
    String? category,
    String? imageUrl,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
    bool? isActive,
    String? sku,
    double? discountPrice,
    int? reorderPoint,
    List<String>? images,
    double? purchasePrice,
    double? manufacturingCost,
    String? supplier,
    double? originalPrice,
    List<String>? tags,
    int? minimumStock,
    String? barcode,
    String? manufacturer,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
      isActive: isActive ?? this.isActive,
      sku: sku ?? this.sku,
      discountPrice: discountPrice ?? this.discountPrice,
      reorderPoint: reorderPoint ?? this.reorderPoint,
      images: images ?? this.images,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      manufacturingCost: manufacturingCost ?? this.manufacturingCost,
      supplier: supplier ?? this.supplier,
      originalPrice: originalPrice ?? this.originalPrice,
      tags: tags ?? this.tags,
      minimumStock: minimumStock ?? this.minimumStock,
      barcode: barcode ?? this.barcode,
      manufacturer: manufacturer ?? this.manufacturer,
    );
  }

  // Getter for best image URL
  String get bestImageUrl {
    // قائمة بجميع URLs المحتملة مرتبة حسب الأولوية
    final candidateUrls = <String>[];

    // أولاً: إضافة imageUrl الرئيسي
    if (imageUrl != null && imageUrl!.isNotEmpty && !_isPlaceholderUrl(imageUrl!)) {
      candidateUrls.add(_fixImageUrl(imageUrl!));
    }

    // ثانياً: إضافة الصور من قائمة images
    for (String img in images) {
      if (img.isNotEmpty && !_isPlaceholderUrl(img)) {
        candidateUrls.add(_fixImageUrl(img));
      }
    }

    // ثالثاً: إضافة URLs محتملة بناءً على معرف المنتج
    if (id.isNotEmpty) {
      final fallbackUrls = [
        'https://samastock.pythonanywhere.com/static/uploads/product_$id.jpg',
        'https://samastock.pythonanywhere.com/static/uploads/products/$id.jpg',
        'https://samastock.pythonanywhere.com/static/uploads/$id.png',
        'https://samastock.pythonanywhere.com/static/uploads/product_$id.png',
        'https://samastock.pythonanywhere.com/media/products/$id.jpg',
        'https://samastock.pythonanywhere.com/media/product_images/$id.jpg',
      ];
      candidateUrls.addAll(fallbackUrls);
    }

    // رابعاً: إضافة URLs بناءً على اسم المنتج (مُنظف)
    if (name.isNotEmpty) {
      final cleanName = _cleanNameForUrl(name);
      if (cleanName.isNotEmpty) {
        candidateUrls.addAll([
          'https://samastock.pythonanywhere.com/static/uploads/$cleanName.jpg',
          'https://samastock.pythonanywhere.com/static/uploads/$cleanName.png',
        ]);
      }
    }

    // إرجاع أول URL صالح أو فارغ إذا لم نجد شيئاً
    for (String url in candidateUrls) {
      if (url.isNotEmpty && _isValidImageUrl(url)) {
        return url;
      }
    }

    return '';
  }

  /// التحقق من كون URL هو placeholder
  bool _isPlaceholderUrl(String url) {
    return url.contains('placeholder') ||
           url.contains('default') ||
           url.contains('no-image') ||
           url == 'null' ||
           url.isEmpty;
  }

  /// التحقق من صحة URL الصورة
  bool _isValidImageUrl(String url) {
    if (url.isEmpty || url == 'null') return false;

    try {
      final uri = Uri.tryParse(url);
      if (uri == null) return false;

      // التحقق من امتداد الملف
      final path = uri.path.toLowerCase();
      return path.endsWith('.jpg') ||
             path.endsWith('.jpeg') ||
             path.endsWith('.png') ||
             path.endsWith('.gif') ||
             path.endsWith('.webp');
    } catch (e) {
      return false;
    }
  }

  /// تنظيف اسم المنتج لاستخدامه في URL
  String _cleanNameForUrl(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s-]'), '') // إزالة الرموز الخاصة
        .replaceAll(RegExp(r'\s+'), '_') // استبدال المسافات بـ _
        .replaceAll(RegExp(r'_+'), '_') // إزالة _ المتكررة
        .trim();
  }

  // Compatibility methods
  Map<String, dynamic> toMap() => toJson();
  static ProductModel fromMap(Map<String, dynamic> map) => ProductModel.fromJson(map);

  // Additional getters
  String get itemName => name;
  String get productName => name;
  String get clientName => '';
  String get details => description;
  String get productCategory => category;
  double get cost => price;
  int get stock => quantity;
  String get productSku => sku;
  String get productUnit => '';
  bool get inStock => quantity > 0;
  bool get needsRestock => quantity <= reorderPoint;

  // Backward compatibility getter
  List<String> get imageUrls => images;

  // Stock quantity getter for compatibility with enhanced_voucher_products_screen
  int get stockQuantity => quantity;

  // Cart-related getters (these would typically be provided by a cart provider)
  // These are placeholder getters - actual implementation should use cart provider
  bool get isInCart => false; // This should be overridden by cart provider context
  int get quantityInCart => 0; // This should be overridden by cart provider context

  String getImageUrl({String baseUrl = '', String uploadsPath = ''}) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return _fixImageUrl(imageUrl!, baseUrl: baseUrl, uploadsPath: uploadsPath);
    }

    // Return a placeholder as last resort
    return 'assets/images/placeholder.png';
  }

  String _fixImageUrl(String url, {String baseUrl = '', String uploadsPath = ''}) {
    // إذا كان URL كاملاً، أرجعه كما هو
    if (url.startsWith('http')) {
      return url;
    }

    // إذا كان URL فارغاً أو يحتوي على placeholder، أرجع فارغ
    if (url.isEmpty || url.contains('placeholder') || url == 'null') {
      return '';
    }

    // استخدام القيم الافتراضية إذا لم تُمرر
    final defaultBaseUrl = baseUrl.isEmpty ? 'https://samastock.pythonanywhere.com' : baseUrl;
    final defaultUploadsPath = uploadsPath.isEmpty ? '/static/uploads/' : uploadsPath;

    // تنظيف URL من المسارات الغريبة
    String cleanUrl = url.trim();

    // إزالة file:// إذا وجد
    if (cleanUrl.startsWith('file://')) {
      cleanUrl = cleanUrl.substring(7);
    }

    // إذا كان يحتوي على اسم ملف فقط بدون مسار، أضف المسار الكامل
    if (!cleanUrl.contains('/')) {
      return '$defaultBaseUrl$defaultUploadsPath$cleanUrl';
    }

    // إذا كان URL نسبياً مع مسار
    if (!cleanUrl.startsWith('http')) {
      if (cleanUrl.startsWith('/')) {
        return '$defaultBaseUrl$cleanUrl';
      } else {
        return '$defaultBaseUrl/$cleanUrl';
      }
    }

    return cleanUrl;
  }
}

class ProductCategory {
  static const String rawMaterials = 'RAW_MATERIALS';
  static const String finishedGoods = 'FINISHED_GOODS';
  static const String packaging = 'PACKAGING';
  static const String spareParts = 'SPARE_PARTS';
  static const String consumables = 'CONSUMABLES';
  static const String other = 'OTHER';

  static const List<String> values = [
    rawMaterials,
    finishedGoods,
    packaging,
    spareParts,
    consumables,
    other
  ];
}

class ProductUnit {
  static const String piece = 'PIECE';
  static const String kilogram = 'KILOGRAM';
  static const String meter = 'METER';
  static const String liter = 'LITER';
  static const String box = 'BOX';
  static const String roll = 'ROLL';
  static const String set = 'SET';

  static const List<String> values = [
    piece,
    kilogram,
    meter,
    liter,
    box,
    roll,
    set
  ];
}
