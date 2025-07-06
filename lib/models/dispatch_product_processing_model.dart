/// معلومات موقع المنتج في المخزن
class WarehouseLocationInfo {
  final String warehouseId;
  final String warehouseName;
  final String? warehouseAddress;
  final int availableQuantity;
  final int? minimumStock;
  final int? maximumStock;
  final DateTime lastUpdated;
  final String stockStatus; // 'in_stock', 'low_stock', 'out_of_stock'

  const WarehouseLocationInfo({
    required this.warehouseId,
    required this.warehouseName,
    this.warehouseAddress,
    required this.availableQuantity,
    this.minimumStock,
    this.maximumStock,
    required this.lastUpdated,
    required this.stockStatus,
  });

  factory WarehouseLocationInfo.fromJson(Map<String, dynamic> json) {
    return WarehouseLocationInfo(
      warehouseId: json['warehouse_id'] as String,
      warehouseName: json['warehouse_name'] as String,
      warehouseAddress: json['warehouse_address'] as String?,
      availableQuantity: json['available_quantity'] as int? ?? 0,
      minimumStock: json['minimum_stock'] as int?,
      maximumStock: json['maximum_stock'] as int?,
      lastUpdated: DateTime.parse(json['last_updated'] as String),
      stockStatus: json['stock_status'] as String? ?? 'unknown',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'warehouse_id': warehouseId,
      'warehouse_name': warehouseName,
      'warehouse_address': warehouseAddress,
      'available_quantity': availableQuantity,
      'minimum_stock': minimumStock,
      'maximum_stock': maximumStock,
      'last_updated': lastUpdated.toIso8601String(),
      'stock_status': stockStatus,
    };
  }

  /// نسخ مع تعديل
  WarehouseLocationInfo copyWith({
    String? warehouseId,
    String? warehouseName,
    String? warehouseAddress,
    int? availableQuantity,
    int? minimumStock,
    int? maximumStock,
    DateTime? lastUpdated,
    String? stockStatus,
  }) {
    return WarehouseLocationInfo(
      warehouseId: warehouseId ?? this.warehouseId,
      warehouseName: warehouseName ?? this.warehouseName,
      warehouseAddress: warehouseAddress ?? this.warehouseAddress,
      availableQuantity: availableQuantity ?? this.availableQuantity,
      minimumStock: minimumStock ?? this.minimumStock,
      maximumStock: maximumStock ?? this.maximumStock,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      stockStatus: stockStatus ?? this.stockStatus,
    );
  }

  @override
  String toString() {
    return 'WarehouseLocationInfo(warehouseName: $warehouseName, availableQuantity: $availableQuantity)';
  }
}

/// نموذج معالجة منتج في طلب الصرف
/// يتتبع حالة إكمال كل منتج في طلب الصرف مع معلومات المخازن
class DispatchProductProcessingModel {
  final String id;
  final String requestId;
  final String productId;
  final String productName;
  final String? productImageUrl;
  final int requestedQuantity;
  final bool isCompleted;
  final DateTime? completedAt;
  final String? completedBy;
  final double progress; // 0.0 to 1.0
  final bool isProcessing;
  final String? notes;

  // معلومات المخازن والموقع
  final List<WarehouseLocationInfo>? warehouseLocations;
  final int totalAvailableQuantity;
  final bool hasLocationData;
  final bool canFulfillRequest;
  final String? locationSearchError;

  const DispatchProductProcessingModel({
    required this.id,
    required this.requestId,
    required this.productId,
    required this.productName,
    this.productImageUrl,
    required this.requestedQuantity,
    this.isCompleted = false,
    this.completedAt,
    this.completedBy,
    this.progress = 0.0,
    this.isProcessing = false,
    this.notes,
    this.warehouseLocations,
    this.totalAvailableQuantity = 0,
    this.hasLocationData = false,
    this.canFulfillRequest = false,
    this.locationSearchError,
  });

  /// إنشاء من نموذج عنصر طلب الصرف
  factory DispatchProductProcessingModel.fromDispatchItem({
    required String itemId,
    required String requestId,
    required String productId,
    required String productName,
    String? productImageUrl,
    required int quantity,
    String? notes,
    List<WarehouseLocationInfo>? warehouseLocations,
    int? totalAvailableQuantity,
    bool? hasLocationData,
    bool? canFulfillRequest,
    String? locationSearchError,
  }) {
    return DispatchProductProcessingModel(
      id: itemId,
      requestId: requestId,
      productId: productId,
      productName: productName,
      productImageUrl: productImageUrl,
      requestedQuantity: quantity,
      notes: notes,
      warehouseLocations: warehouseLocations,
      totalAvailableQuantity: totalAvailableQuantity ?? 0,
      hasLocationData: hasLocationData ?? false,
      canFulfillRequest: canFulfillRequest ?? false,
      locationSearchError: locationSearchError,
    );
  }

  /// إنشاء من JSON
  factory DispatchProductProcessingModel.fromJson(Map<String, dynamic> json) {
    List<WarehouseLocationInfo>? warehouseLocations;
    if (json['warehouse_locations'] != null) {
      warehouseLocations = (json['warehouse_locations'] as List<dynamic>)
          .map((item) => WarehouseLocationInfo.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    return DispatchProductProcessingModel(
      id: json['id']?.toString() ?? '',
      requestId: json['request_id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? '',
      productImageUrl: json['product_image_url']?.toString(),
      requestedQuantity: _parseInt(json['requested_quantity']) ?? 0,
      isCompleted: json['is_completed'] == true,
      completedAt: _parseDateTime(json['completed_at']),
      completedBy: json['completed_by']?.toString(),
      progress: _parseDouble(json['progress']) ?? 0.0,
      isProcessing: json['is_processing'] == true,
      notes: json['notes']?.toString(),
      warehouseLocations: warehouseLocations,
      totalAvailableQuantity: _parseInt(json['total_available_quantity']) ?? 0,
      hasLocationData: json['has_location_data'] == true,
      canFulfillRequest: json['can_fulfill_request'] == true,
      locationSearchError: json['location_search_error']?.toString(),
    );
  }

  /// تحويل إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'request_id': requestId,
      'product_id': productId,
      'product_name': productName,
      'product_image_url': productImageUrl,
      'requested_quantity': requestedQuantity,
      'is_completed': isCompleted,
      'completed_at': completedAt?.toIso8601String(),
      'completed_by': completedBy,
      'progress': progress,
      'is_processing': isProcessing,
      'notes': notes,
      'warehouse_locations': warehouseLocations?.map((w) => w.toJson()).toList(),
      'total_available_quantity': totalAvailableQuantity,
      'has_location_data': hasLocationData,
      'can_fulfill_request': canFulfillRequest,
      'location_search_error': locationSearchError,
    };
  }

  /// نسخ مع تعديل
  DispatchProductProcessingModel copyWith({
    String? id,
    String? requestId,
    String? productId,
    String? productName,
    String? productImageUrl,
    int? requestedQuantity,
    bool? isCompleted,
    DateTime? completedAt,
    String? completedBy,
    double? progress,
    bool? isProcessing,
    String? notes,
    List<WarehouseLocationInfo>? warehouseLocations,
    int? totalAvailableQuantity,
    bool? hasLocationData,
    bool? canFulfillRequest,
    String? locationSearchError,
  }) {
    return DispatchProductProcessingModel(
      id: id ?? this.id,
      requestId: requestId ?? this.requestId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productImageUrl: productImageUrl ?? this.productImageUrl,
      requestedQuantity: requestedQuantity ?? this.requestedQuantity,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      completedBy: completedBy ?? this.completedBy,
      progress: progress ?? this.progress,
      isProcessing: isProcessing ?? this.isProcessing,
      notes: notes ?? this.notes,
      warehouseLocations: warehouseLocations ?? this.warehouseLocations,
      totalAvailableQuantity: totalAvailableQuantity ?? this.totalAvailableQuantity,
      hasLocationData: hasLocationData ?? this.hasLocationData,
      canFulfillRequest: canFulfillRequest ?? this.canFulfillRequest,
      locationSearchError: locationSearchError ?? this.locationSearchError,
    );
  }

  /// بدء معالجة المنتج
  DispatchProductProcessingModel startProcessing() {
    return copyWith(
      isProcessing: true,
      progress: 0.1, // بداية المعالجة
    );
  }

  /// تحديث التقدم
  DispatchProductProcessingModel updateProgress(double newProgress) {
    return copyWith(
      progress: newProgress.clamp(0.0, 1.0),
      isProcessing: newProgress < 1.0,
    );
  }

  /// إكمال المعالجة
  DispatchProductProcessingModel complete({
    required String completedBy,
    String? notes,
  }) {
    return copyWith(
      isCompleted: true,
      completedAt: DateTime.now(),
      completedBy: completedBy,
      progress: 1.0,
      isProcessing: false,
      notes: notes,
    );
  }

  /// إعادة تعيين الحالة
  DispatchProductProcessingModel reset() {
    return copyWith(
      isCompleted: false,
      completedAt: null,
      completedBy: null,
      progress: 0.0,
      isProcessing: false,
    );
  }

  /// التحقق من إمكانية بدء المعالجة
  bool get canStartProcessing => !isCompleted && !isProcessing;

  /// التحقق من إمكانية الإكمال
  bool get canComplete => isProcessing && progress >= 0.9;

  /// الحصول على نص الحالة
  String get statusText {
    if (isCompleted) return 'مكتمل';
    if (isProcessing) return 'قيد المعالجة';
    return 'في الانتظار';
  }

  /// الحصول على لون الحالة
  String get statusColorHex {
    if (isCompleted) return '#10B981'; // أخضر
    if (isProcessing) return '#F59E0B'; // برتقالي
    return '#6B7280'; // رمادي
  }

  /// الحصول على نسبة التقدم كنص
  String get progressText {
    return '${(progress * 100).toInt()}%';
  }

  /// الحصول على عدد المخازن المتاحة
  int get availableWarehousesCount => warehouseLocations?.length ?? 0;

  /// الحصول على أفضل مخزن (أعلى كمية متاحة)
  WarehouseLocationInfo? get bestWarehouse {
    if (warehouseLocations == null || warehouseLocations!.isEmpty) return null;
    return warehouseLocations!.reduce((a, b) =>
      a.availableQuantity > b.availableQuantity ? a : b);
  }

  /// الحصول على نص ملخص المواقع
  String get locationSummaryText {
    if (!hasLocationData) return 'لم يتم البحث عن المواقع';
    if (locationSearchError != null) return 'خطأ في البحث: $locationSearchError';
    if (warehouseLocations == null || warehouseLocations!.isEmpty) {
      return 'غير متوفر في أي مخزن';
    }

    final warehouseCount = warehouseLocations!.length;
    if (warehouseCount == 1) {
      return 'متوفر في مخزن واحد: ${warehouseLocations!.first.warehouseName}';
    }
    return 'متوفر في $warehouseCount مخازن';
  }

  /// التحقق من إمكانية تلبية الطلب بالكامل
  bool get canFulfillCompletely => canFulfillRequest && totalAvailableQuantity >= requestedQuantity;

  /// الحصول على الكمية المتبقية المطلوبة
  int get shortfallQuantity => (requestedQuantity - totalAvailableQuantity).clamp(0, requestedQuantity);

  /// إنشاء نسخة مع معلومات المواقع
  DispatchProductProcessingModel withLocationData({
    required List<WarehouseLocationInfo> locations,
    required int totalAvailable,
    String? searchError,
  }) {
    return copyWith(
      warehouseLocations: locations,
      totalAvailableQuantity: totalAvailable,
      hasLocationData: true,
      canFulfillRequest: totalAvailable >= requestedQuantity,
      locationSearchError: searchError,
    );
  }

  /// دوال مساعدة لتحليل البيانات
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is double) return value.toInt();
    return null;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  @override
  String toString() {
    return 'DispatchProductProcessingModel(id: $id, productName: $productName, isCompleted: $isCompleted, progress: $progress)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DispatchProductProcessingModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// مجموعة من منتجات طلب الصرف قيد المعالجة
class DispatchProcessingCollection {
  final String requestId;
  final List<DispatchProductProcessingModel> products;

  const DispatchProcessingCollection({
    required this.requestId,
    required this.products,
  });

  /// عدد المنتجات المكتملة
  int get completedCount => products.where((p) => p.isCompleted).length;

  /// عدد المنتجات الإجمالي
  int get totalCount => products.length;

  /// نسبة الإكمال الإجمالية
  double get overallProgress {
    if (products.isEmpty) return 0.0;
    final totalProgress = products.fold<double>(0.0, (sum, product) => sum + product.progress);
    return totalProgress / products.length;
  }

  /// التحقق من إكمال جميع المنتجات
  bool get isAllCompleted => products.isNotEmpty && products.every((p) => p.isCompleted);

  /// التحقق من وجود منتجات قيد المعالجة
  bool get hasProcessingProducts => products.any((p) => p.isProcessing);

  /// الحصول على المنتجات المكتملة
  List<DispatchProductProcessingModel> get completedProducts => 
      products.where((p) => p.isCompleted).toList();

  /// الحصول على المنتجات قيد المعالجة
  List<DispatchProductProcessingModel> get processingProducts => 
      products.where((p) => p.isProcessing).toList();

  /// الحصول على المنتجات في الانتظار
  List<DispatchProductProcessingModel> get pendingProducts => 
      products.where((p) => !p.isCompleted && !p.isProcessing).toList();
}
