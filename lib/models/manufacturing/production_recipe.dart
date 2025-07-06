/// نموذج وصفة الإنتاج - يحدد الأدوات المطلوبة لإنتاج منتج معين
class ProductionRecipe {
  final int id;
  final int productId;
  final int toolId;
  final String toolName;
  final double quantityRequired;
  final String unit;
  final double currentStock;
  final String stockStatus;
  final DateTime createdAt;

  const ProductionRecipe({
    required this.id,
    required this.productId,
    required this.toolId,
    required this.toolName,
    required this.quantityRequired,
    required this.unit,
    required this.currentStock,
    required this.stockStatus,
    required this.createdAt,
  });

  /// إنشاء من JSON
  factory ProductionRecipe.fromJson(Map<String, dynamic> json) {
    return ProductionRecipe(
      id: json['id'] as int,
      productId: json['product_id'] as int,
      toolId: json['tool_id'] as int,
      toolName: json['tool_name'] as String,
      quantityRequired: (json['quantity_required'] as num).toDouble(),
      unit: json['unit'] as String,
      currentStock: (json['current_stock'] as num).toDouble(),
      stockStatus: json['stock_status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// تحويل إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'tool_id': toolId,
      'tool_name': toolName,
      'quantity_required': quantityRequired,
      'unit': unit,
      'current_stock': currentStock,
      'stock_status': stockStatus,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// إنشاء نسخة محدثة
  ProductionRecipe copyWith({
    int? id,
    int? productId,
    int? toolId,
    String? toolName,
    double? quantityRequired,
    String? unit,
    double? currentStock,
    String? stockStatus,
    DateTime? createdAt,
  }) {
    return ProductionRecipe(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      toolId: toolId ?? this.toolId,
      toolName: toolName ?? this.toolName,
      quantityRequired: quantityRequired ?? this.quantityRequired,
      unit: unit ?? this.unit,
      currentStock: currentStock ?? this.currentStock,
      stockStatus: stockStatus ?? this.stockStatus,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// التحقق من توفر المخزون للإنتاج
  bool canProduce(double unitsToProduceCount) {
    final requiredTotal = quantityRequired * unitsToProduceCount;
    return currentStock >= requiredTotal;
  }

  /// حساب الكمية المطلوبة لعدد معين من الوحدات
  double calculateRequiredQuantity(double unitsToProduceCount) {
    return quantityRequired * unitsToProduceCount;
  }

  /// الحصول على نص الحالة بالعربية
  String get stockStatusText {
    switch (stockStatus) {
      case 'green':
        return 'متوفر';
      case 'yellow':
        return 'محدود';
      case 'orange':
        return 'منخفض';
      case 'red':
        return 'غير متوفر';
      default:
        return 'غير محدد';
    }
  }

  @override
  String toString() {
    return 'ProductionRecipe(id: $id, toolName: $toolName, quantityRequired: $quantityRequired $unit)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProductionRecipe && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// نموذج إنشاء وصفة إنتاج جديدة
class CreateProductionRecipeRequest {
  final int productId;
  final int toolId;
  final double quantityRequired;

  const CreateProductionRecipeRequest({
    required this.productId,
    required this.toolId,
    required this.quantityRequired,
  });

  /// تحويل إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'tool_id': toolId,
      'quantity_required': quantityRequired,
    };
  }

  /// التحقق من صحة البيانات
  bool get isValid {
    return productId > 0 && toolId > 0 && quantityRequired > 0;
  }

  /// الحصول على رسائل الخطأ
  List<String> get validationErrors {
    final errors = <String>[];
    
    if (productId <= 0) {
      errors.add('معرف المنتج غير صحيح');
    }
    
    if (toolId <= 0) {
      errors.add('معرف الأداة غير صحيح');
    }
    
    if (quantityRequired <= 0) {
      errors.add('الكمية المطلوبة يجب أن تكون أكبر من صفر');
    }
    
    return errors;
  }
}

/// نموذج وصفة الإنتاج الكاملة مع جميع الأدوات المطلوبة
class CompleteProductionRecipe {
  final int productId;
  final List<ProductionRecipe> recipes;

  const CompleteProductionRecipe({
    required this.productId,
    required this.recipes,
  });

  /// إنشاء من قائمة JSON
  factory CompleteProductionRecipe.fromJsonList(int productId, List<dynamic> jsonList) {
    final recipes = jsonList
        .map((json) => ProductionRecipe.fromJson(json as Map<String, dynamic>))
        .toList();
    
    return CompleteProductionRecipe(
      productId: productId,
      recipes: recipes,
    );
  }

  /// التحقق من إمكانية الإنتاج
  bool canProduce(double unitsToProduceCount) {
    return recipes.every((recipe) => recipe.canProduce(unitsToProduceCount));
  }

  /// الحصول على الأدوات غير المتوفرة
  List<ProductionRecipe> getUnavailableTools(double unitsToProduceCount) {
    return recipes
        .where((recipe) => !recipe.canProduce(unitsToProduceCount))
        .toList();
  }

  /// حساب إجمالي التكلفة (إذا كانت متوفرة)
  double calculateTotalCost(double unitsToProduceCount) {
    // يمكن إضافة منطق حساب التكلفة هنا إذا كانت أسعار الأدوات متوفرة
    return 0.0;
  }

  /// الحصول على ملخص الوصفة
  Map<String, dynamic> getSummary(double unitsToProduceCount) {
    final totalTools = recipes.length;
    final availableTools = recipes.where((r) => r.canProduce(unitsToProduceCount)).length;
    final unavailableTools = getUnavailableTools(unitsToProduceCount);
    
    return {
      'total_tools': totalTools,
      'available_tools': availableTools,
      'unavailable_tools_count': unavailableTools.length,
      'unavailable_tools': unavailableTools.map((r) => r.toolName).toList(),
      'can_produce': canProduce(unitsToProduceCount),
      'units_to_produce': unitsToProduceCount,
    };
  }

  /// التحقق من وجود وصفات
  bool get hasRecipes => recipes.isNotEmpty;

  /// الحصول على عدد الأدوات المطلوبة
  int get toolsCount => recipes.length;

  @override
  String toString() {
    return 'CompleteProductionRecipe(productId: $productId, toolsCount: $toolsCount)';
  }
}

/// نموذج تفاصيل الإنتاج مع الكميات المحسوبة
class ProductionDetails {
  final int productId;
  final double unitsToProduceCount;
  final List<ProductionRecipe> recipes;
  final Map<int, double> calculatedQuantities;
  final bool canProduce;
  final List<String> issues;

  const ProductionDetails({
    required this.productId,
    required this.unitsToProduceCount,
    required this.recipes,
    required this.calculatedQuantities,
    required this.canProduce,
    required this.issues,
  });

  /// إنشاء تفاصيل الإنتاج من الوصفة
  factory ProductionDetails.fromRecipe(
    CompleteProductionRecipe recipe,
    double unitsToProduceCount,
  ) {
    final calculatedQuantities = <int, double>{};
    final issues = <String>[];
    
    for (final recipeItem in recipe.recipes) {
      final requiredQuantity = recipeItem.calculateRequiredQuantity(unitsToProduceCount);
      calculatedQuantities[recipeItem.toolId] = requiredQuantity;
      
      if (!recipeItem.canProduce(unitsToProduceCount)) {
        issues.add(
          'مخزون غير كافي من ${recipeItem.toolName}: '
          'متوفر ${recipeItem.currentStock} ${recipeItem.unit}، '
          'مطلوب ${requiredQuantity} ${recipeItem.unit}'
        );
      }
    }
    
    return ProductionDetails(
      productId: recipe.productId,
      unitsToProduceCount: unitsToProduceCount,
      recipes: recipe.recipes,
      calculatedQuantities: calculatedQuantities,
      canProduce: issues.isEmpty,
      issues: issues,
    );
  }

  /// الحصول على الكمية المحسوبة لأداة معينة
  double getCalculatedQuantity(int toolId) {
    return calculatedQuantities[toolId] ?? 0.0;
  }

  /// الحصول على ملخص الإنتاج
  Map<String, dynamic> toSummaryJson() {
    return {
      'product_id': productId,
      'units_to_produce': unitsToProduceCount,
      'can_produce': canProduce,
      'tools_count': recipes.length,
      'issues_count': issues.length,
      'issues': issues,
      'calculated_quantities': calculatedQuantities,
    };
  }

  @override
  String toString() {
    return 'ProductionDetails(productId: $productId, unitsToProduceCount: $unitsToProduceCount, canProduce: $canProduce)';
  }
}
