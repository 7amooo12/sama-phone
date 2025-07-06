

/// Model for product information
class ProductMovementProductModel {

  const ProductMovementProductModel({
    required this.id,
    required this.name,
    this.sku,
    this.description,
    this.category,
    this.purchasePrice,
    this.sellingPrice,
    this.manufacturingCost,
    this.costPrice,
    required this.currentStock,
    this.imageUrl,
  });

  factory ProductMovementProductModel.fromJson(Map<String, dynamic> json) {
    return ProductMovementProductModel(
      id: json['id'] as int,
      name: json['name'] as String,
      sku: json['sku'] as String?,
      description: json['description'] as String?,
      category: json['category'] as String?,
      purchasePrice: json['purchase_price'] != null ? (json['purchase_price'] as num).toDouble() : null,
      sellingPrice: json['selling_price'] != null ? (json['selling_price'] as num).toDouble() : null,
      manufacturingCost: json['manufacturing_cost'] != null ? (json['manufacturing_cost'] as num).toDouble() : null,
      costPrice: json['cost_price'] != null ? (json['cost_price'] as num).toDouble() : null,
      currentStock: json['current_stock'] as int? ?? 0,
      imageUrl: json['image_url'] as String?,
    );
  }
  final int id;
  final String name;
  final String? sku;
  final String? description;
  final String? category;
  final double? purchasePrice;
  final double? sellingPrice;
  final double? manufacturingCost;
  final double? costPrice;
  final int currentStock;
  final String? imageUrl;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'sku': sku,
      'description': description,
      'category': category,
      'purchase_price': purchasePrice,
      'selling_price': sellingPrice,
      'manufacturing_cost': manufacturingCost,
      'cost_price': costPrice,
      'current_stock': currentStock,
      'image_url': imageUrl,
    };
  }
}

/// Model for sales data (who bought the product)
class ProductSaleModel {

  const ProductSaleModel({
    required this.invoiceId,
    required this.customerName,
    this.customerPhone,
    this.customerEmail,
    required this.quantity,
    required this.unitPrice,
    required this.totalAmount,
    required this.discount,
    required this.saleDate,
    required this.invoiceStatus,
  });

  factory ProductSaleModel.fromJson(Map<String, dynamic> json) {
    return ProductSaleModel(
      invoiceId: json['invoice_id'] as int,
      customerName: json['customer_name'] as String,
      customerPhone: json['customer_phone'] as String?,
      customerEmail: json['customer_email'] as String?,
      quantity: json['quantity'] as int,
      unitPrice: (json['unit_price'] as num).toDouble(),
      totalAmount: (json['total_amount'] as num).toDouble(),
      discount: (json['discount'] as num).toDouble(),
      saleDate: DateTime.parse(json['sale_date'] as String),
      invoiceStatus: json['invoice_status'] as String,
    );
  }
  final int invoiceId;
  final String customerName;
  final String? customerPhone;
  final String? customerEmail;
  final int quantity;
  final double unitPrice;
  final double totalAmount;
  final double discount;
  final DateTime saleDate;
  final String invoiceStatus;

  // Date getter for compatibility with comprehensive_reports_screen
  DateTime get date => saleDate;

  Map<String, dynamic> toJson() {
    return {
      'invoice_id': invoiceId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_email': customerEmail,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_amount': totalAmount,
      'discount': discount,
      'sale_date': saleDate.toIso8601String(),
      'invoice_status': invoiceStatus,
    };
  }
}

/// Model for stock movement data
class ProductStockMovementModel {

  const ProductStockMovementModel({
    required this.id,
    required this.quantity,
    required this.reason,
    this.reference,
    this.notes,
    required this.createdAt,
    required this.createdBy,
  });

  factory ProductStockMovementModel.fromJson(Map<String, dynamic> json) {
    return ProductStockMovementModel(
      id: json['id'] as int,
      quantity: json['quantity'] as int,
      reason: json['reason'] as String,
      reference: json['reference'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      createdBy: json['created_by'] as String,
    );
  }
  final int id;
  final int quantity;
  final String reason;
  final String? reference;
  final String? notes;
  final DateTime createdAt;
  final String createdBy;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'quantity': quantity,
      'reason': reason,
      'reference': reference,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'created_by': createdBy,
    };
  }
}

/// Model for product statistics
class ProductMovementStatisticsModel {

  const ProductMovementStatisticsModel({
    required this.totalSoldQuantity,
    required this.totalRevenue,
    required this.averageSalePrice,
    required this.profitPerUnit,
    required this.totalProfit,
    required this.profitMargin,
    required this.totalSalesCount,
    required this.currentStock,
  });

  factory ProductMovementStatisticsModel.fromJson(Map<String, dynamic> json) {
    return ProductMovementStatisticsModel(
      totalSoldQuantity: json['total_sold_quantity'] as int? ?? 0,
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0.0,
      averageSalePrice: (json['average_sale_price'] as num?)?.toDouble() ?? 0.0,
      profitPerUnit: (json['profit_per_unit'] as num?)?.toDouble() ?? 0.0,
      totalProfit: (json['total_profit'] as num?)?.toDouble() ?? 0.0,
      profitMargin: (json['profit_margin'] as num?)?.toDouble() ?? 0.0,
      totalSalesCount: json['total_sales_count'] as int? ?? 0,
      currentStock: json['current_stock'] as int? ?? 0,
    );
  }
  final int totalSoldQuantity;
  final double totalRevenue;
  final double averageSalePrice;
  final double profitPerUnit;
  final double totalProfit;
  final double profitMargin;
  final int totalSalesCount;
  final int currentStock;

  Map<String, dynamic> toJson() {
    return {
      'total_sold_quantity': totalSoldQuantity,
      'total_revenue': totalRevenue,
      'average_sale_price': averageSalePrice,
      'profit_per_unit': profitPerUnit,
      'total_profit': totalProfit,
      'profit_margin': profitMargin,
      'total_sales_count': totalSalesCount,
      'current_stock': currentStock,
    };
  }
}

/// Main model that contains all product movement data
class ProductMovementModel {

  const ProductMovementModel({
    required this.product,
    required this.salesData,
    required this.movementData,
    required this.statistics,
  });

  factory ProductMovementModel.fromJson(Map<String, dynamic> json) {
    return ProductMovementModel(
      product: ProductMovementProductModel.fromJson(json['product'] as Map<String, dynamic>),
      salesData: (json['sales_data'] as List<dynamic>)
          .map((sale) => ProductSaleModel.fromJson(sale as Map<String, dynamic>))
          .toList(),
      movementData: (json['movement_data'] as List<dynamic>)
          .map((movement) => ProductStockMovementModel.fromJson(movement as Map<String, dynamic>))
          .toList(),
      statistics: ProductMovementStatisticsModel.fromJson(json['statistics'] as Map<String, dynamic>),
    );
  }
  final ProductMovementProductModel product;
  final List<ProductSaleModel> salesData;
  final List<ProductStockMovementModel> movementData;
  final ProductMovementStatisticsModel statistics;

  Map<String, dynamic> toJson() {
    return {
      'product': product.toJson(),
      'sales_data': salesData.map((sale) => sale.toJson()).toList(),
      'movement_data': movementData.map((movement) => movement.toJson()).toList(),
      'statistics': statistics.toJson(),
    };
  }
}

/// Model for product search results
class ProductSearchModel {

  const ProductSearchModel({
    required this.id,
    required this.name,
    this.sku,
    this.category,
    required this.currentStock,
    this.sellingPrice,
    this.purchasePrice,
    this.imageUrl,
    required this.totalSold,
    required this.totalRevenue,
  });

  factory ProductSearchModel.fromJson(Map<String, dynamic> json) {
    return ProductSearchModel(
      id: json['id'] as int,
      name: json['name'] as String,
      sku: json['sku'] as String?,
      category: json['category_name'] as String? ?? json['category'] as String?, // Handle both formats
      currentStock: json['stock_quantity'] as int? ?? json['current_stock'] as int? ?? 0, // Handle both formats
      sellingPrice: json['selling_price'] != null ? (json['selling_price'] as num).toDouble() : null,
      purchasePrice: json['purchase_price'] != null ? (json['purchase_price'] as num).toDouble() : null,
      imageUrl: json['image_url'] as String?,
      totalSold: json['total_sold'] as int? ?? 0,
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0.0,
    );
  }
  final int id;
  final String name;
  final String? sku;
  final String? category;
  final int currentStock;
  final double? sellingPrice;
  final double? purchasePrice;
  final String? imageUrl;
  final int totalSold;
  final double totalRevenue;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'sku': sku,
      'category': category,
      'current_stock': currentStock,
      'selling_price': sellingPrice,
      'purchase_price': purchasePrice,
      'image_url': imageUrl,
      'total_sold': totalSold,
      'total_revenue': totalRevenue,
    };
  }
}
