import 'package:flutter/material.dart';

/// نموذج أداة التصنيع مع تتبع المخزون والحالة
class ManufacturingTool {
  final int id;
  final String name;
  final double quantity;
  final double initialStock;
  final String unit;
  final String? color;
  final String? size;
  final String? imageUrl;
  final double stockPercentage;
  final String stockStatus;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;

  const ManufacturingTool({
    required this.id,
    required this.name,
    required this.quantity,
    required this.initialStock,
    required this.unit,
    this.color,
    this.size,
    this.imageUrl,
    required this.stockPercentage,
    required this.stockStatus,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
  });

  /// إنشاء من JSON
  factory ManufacturingTool.fromJson(Map<String, dynamic> json) {
    return ManufacturingTool(
      id: json['id'] as int,
      name: json['name'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      initialStock: (json['initial_stock'] as num).toDouble(),
      unit: json['unit'] as String,
      color: json['color'] as String?,
      size: json['size'] as String?,
      imageUrl: json['image_url'] as String?,
      stockPercentage: (json['stock_percentage'] as num).toDouble(),
      stockStatus: json['stock_status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      createdBy: json['created_by'] as String?,
    );
  }

  /// تحويل إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'initial_stock': initialStock,
      'unit': unit,
      'color': color,
      'size': size,
      'image_url': imageUrl,
      'stock_percentage': stockPercentage,
      'stock_status': stockStatus,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'created_by': createdBy,
    };
  }

  /// إنشاء نسخة محدثة
  ManufacturingTool copyWith({
    int? id,
    String? name,
    double? quantity,
    double? initialStock,
    String? unit,
    String? color,
    String? size,
    String? imageUrl,
    double? stockPercentage,
    String? stockStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return ManufacturingTool(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      initialStock: initialStock ?? this.initialStock,
      unit: unit ?? this.unit,
      color: color ?? this.color,
      size: size ?? this.size,
      imageUrl: imageUrl ?? this.imageUrl,
      stockPercentage: stockPercentage ?? this.stockPercentage,
      stockStatus: stockStatus ?? this.stockStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  /// الحصول على لون المؤشر بناءً على حالة المخزون
  Color get stockIndicatorColor {
    switch (stockStatus) {
      case 'green':
        return Colors.green;
      case 'yellow':
        return Colors.amber;
      case 'orange':
        return Colors.orange;
      case 'red':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// الحصول على أيقونة الحالة
  IconData get stockStatusIcon {
    switch (stockStatus) {
      case 'green':
        return Icons.check_circle;
      case 'yellow':
        return Icons.warning;
      case 'orange':
        return Icons.error_outline;
      case 'red':
        return Icons.error;
      default:
        return Icons.help_outline;
    }
  }

  /// الحصول على نص الحالة بالعربية
  String get stockStatusText {
    switch (stockStatus) {
      case 'green':
        return 'مخزون جيد';
      case 'yellow':
        return 'مخزون متوسط';
      case 'orange':
        return 'مخزون منخفض';
      case 'red':
        return 'مخزون نفد';
      default:
        return 'غير محدد';
    }
  }

  /// التحقق من توفر الكمية المطلوبة
  bool hasEnoughStock(double requiredQuantity) {
    return quantity >= requiredQuantity;
  }

  /// حساب الكمية المتبقية بعد الاستخدام
  double calculateRemainingStock(double usedQuantity) {
    return quantity - usedQuantity;
  }

  /// التحقق من صحة البيانات
  bool get isValid {
    return name.isNotEmpty && 
           unit.isNotEmpty && 
           quantity >= 0 && 
           initialStock >= 0;
  }

  @override
  String toString() {
    return 'ManufacturingTool(id: $id, name: $name, quantity: $quantity $unit, stockStatus: $stockStatus)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ManufacturingTool && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// نموذج إنشاء أداة تصنيع جديدة
class CreateManufacturingToolRequest {
  final String name;
  final double quantity;
  final String unit;
  final String? color;
  final String? size;
  final String? imageUrl;

  const CreateManufacturingToolRequest({
    required this.name,
    required this.quantity,
    required this.unit,
    this.color,
    this.size,
    this.imageUrl,
  });

  /// تحويل إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'color': color,
      'size': size,
      'image_url': imageUrl,
    };
  }

  /// التحقق من صحة البيانات
  bool get isValid {
    return name.trim().isNotEmpty && 
           unit.trim().isNotEmpty && 
           quantity >= 0;
  }

  /// الحصول على رسائل الخطأ
  List<String> get validationErrors {
    final errors = <String>[];
    
    if (name.trim().isEmpty) {
      errors.add('اسم الأداة مطلوب');
    }
    
    if (name.trim().length > 100) {
      errors.add('اسم الأداة يجب أن يكون أقل من 100 حرف');
    }
    
    if (unit.trim().isEmpty) {
      errors.add('وحدة القياس مطلوبة');
    }
    
    if (quantity < 0) {
      errors.add('الكمية يجب أن تكون أكبر من أو تساوي صفر');
    }
    
    if (size != null && size!.length > 50) {
      errors.add('المقاس يجب أن يكون أقل من 50 حرف');
    }
    
    return errors;
  }
}

/// نموذج تحديث كمية الأداة
class UpdateToolQuantityRequest {
  final int toolId;
  final double newQuantity;
  final String operationType;
  final String? notes;
  final int? batchId;

  const UpdateToolQuantityRequest({
    required this.toolId,
    required this.newQuantity,
    this.operationType = 'adjustment',
    this.notes,
    this.batchId,
  });

  /// تحويل إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'tool_id': toolId,
      'new_quantity': newQuantity,
      'operation_type': operationType,
      'notes': notes,
      'batch_id': batchId,
    };
  }

  /// التحقق من صحة البيانات
  bool get isValid {
    return toolId > 0 && newQuantity >= 0;
  }
}

/// الوحدات المتاحة للأدوات
class ToolUnits {
  static const List<String> availableUnits = [
    'قطعة',
    'لتر',
    'متر',
    'كيلو',
    'جرام',
    'طن',
    'صندوق',
    'كرتونة',
  ];

  static bool isValidUnit(String unit) {
    return availableUnits.contains(unit);
  }
}

/// الألوان المتاحة للأدوات
class ToolColors {
  static const List<String> availableColors = [
    'أحمر',
    'أزرق',
    'أخضر',
    'أصفر',
    'أسود',
    'أبيض',
    'بني',
    'رمادي',
    'بنفسجي',
    'وردي',
  ];

  static bool isValidColor(String color) {
    return availableColors.contains(color);
  }

  static Color getColorValue(String colorName) {
    switch (colorName) {
      case 'أحمر':
        return Colors.red;
      case 'أزرق':
        return Colors.blue;
      case 'أخضر':
        return Colors.green;
      case 'أصفر':
        return Colors.yellow;
      case 'أسود':
        return Colors.black;
      case 'أبيض':
        return Colors.white;
      case 'بني':
        return Colors.brown;
      case 'رمادي':
        return Colors.grey;
      case 'بنفسجي':
        return Colors.purple;
      case 'وردي':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }
}
