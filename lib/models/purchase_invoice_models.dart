/// Purchase Invoice Models for Business Owner Invoice Management System
/// Handles supplier invoices with Yuan pricing, exchange rates, and profit margins

/// Model for purchase invoice items
class PurchaseInvoiceItem {
  const PurchaseInvoiceItem({
    required this.id,
    required this.productName,
    this.productImage,
    required this.yuanPrice,
    required this.exchangeRate,
    required this.profitMarginPercent,
    required this.quantity,
    required this.finalEgpPrice,
    this.notes,
    required this.createdAt,
  });

  factory PurchaseInvoiceItem.create({
    required String productName,
    String? productImage,
    required double yuanPrice,
    required double exchangeRate,
    required double profitMarginPercent,
    int quantity = 1,
    String? notes,
  }) {
    // Calculate final EGP price per unit: Yuan Price × Exchange Rate × (1 + Profit Margin/100)
    final baseEgpPrice = yuanPrice * exchangeRate;
    final profitAmount = baseEgpPrice * (profitMarginPercent / 100);
    final finalEgpPrice = baseEgpPrice + profitAmount;

    return PurchaseInvoiceItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      productName: productName,
      productImage: productImage,
      yuanPrice: yuanPrice,
      exchangeRate: exchangeRate,
      profitMarginPercent: profitMarginPercent,
      quantity: quantity,
      finalEgpPrice: finalEgpPrice,
      notes: notes,
      createdAt: DateTime.now(),
    );
  }

  factory PurchaseInvoiceItem.fromJson(Map<String, dynamic> json) {
    return PurchaseInvoiceItem(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      productName: json['product_name']?.toString() ?? 'Unknown Product',
      productImage: json['product_image_url']?.toString(),
      yuanPrice: (json['yuan_price'] as num?)?.toDouble() ?? 0.0,
      exchangeRate: (json['exchange_rate'] as num?)?.toDouble() ?? 0.0,
      profitMarginPercent: (json['profit_margin_percent'] as num?)?.toDouble() ?? 0.0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      finalEgpPrice: (json['final_egp_price'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
    );
  }

  final String id;
  final String productName;
  final String? productImage;
  final double yuanPrice;
  final double exchangeRate;
  final double profitMarginPercent;
  final int quantity;
  final double finalEgpPrice;
  final String? notes;
  final DateTime createdAt;

  // Calculated properties (per unit)
  double get baseEgpPrice => yuanPrice * exchangeRate;
  double get profitAmount => baseEgpPrice * (profitMarginPercent / 100);

  // Unit prices
  double get unitPrice => finalEgpPrice;
  double get unitProfitAmount => profitAmount;

  // Total prices (quantity-aware)
  double get totalPrice => finalEgpPrice * quantity;
  double get totalProfitAmount => profitAmount * quantity;
  double get totalBaseEgpPrice => baseEgpPrice * quantity;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_name': productName,
      'product_image_url': productImage,
      'yuan_price': yuanPrice,
      'exchange_rate': exchangeRate,
      'profit_margin_percent': profitMarginPercent,
      'quantity': quantity,
      'final_egp_price': finalEgpPrice,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  PurchaseInvoiceItem copyWith({
    String? id,
    String? productName,
    String? productImage,
    double? yuanPrice,
    double? exchangeRate,
    double? profitMarginPercent,
    int? quantity,
    double? finalEgpPrice,
    String? notes,
    DateTime? createdAt,
  }) {
    return PurchaseInvoiceItem(
      id: id ?? this.id,
      productName: productName ?? this.productName,
      productImage: productImage ?? this.productImage,
      yuanPrice: yuanPrice ?? this.yuanPrice,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      profitMarginPercent: profitMarginPercent ?? this.profitMarginPercent,
      quantity: quantity ?? this.quantity,
      finalEgpPrice: finalEgpPrice ?? this.finalEgpPrice,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PurchaseInvoiceItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'PurchaseInvoiceItem(id: $id, productName: $productName, quantity: $quantity, yuanPrice: $yuanPrice, finalEgpPrice: $finalEgpPrice)';
  }
}

/// Model for purchase invoice
class PurchaseInvoice {
  const PurchaseInvoice({
    required this.id,
    this.supplierName,
    required this.items,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.notes,
    this.userId,
  });

  factory PurchaseInvoice.create({
    String? supplierName,
    required List<PurchaseInvoiceItem> items,
    String? notes,
    String? userId,
  }) {
    final totalAmount = items.fold<double>(0.0, (sum, item) => sum + item.totalPrice);

    return PurchaseInvoice(
      id: 'PINV-${DateTime.now().millisecondsSinceEpoch}',
      supplierName: supplierName,
      items: items,
      totalAmount: totalAmount,
      status: 'pending',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      notes: notes,
      userId: userId,
    );
  }

  factory PurchaseInvoice.fromJson(Map<String, dynamic> json) {
    final itemsData = json['items'] as List<dynamic>? ?? [];
    final items = itemsData
        .map((item) => PurchaseInvoiceItem.fromJson(item as Map<String, dynamic>))
        .toList();

    return PurchaseInvoice(
      id: json['id']?.toString() ?? '',
      supplierName: json['supplier_name']?.toString(),
      items: items,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString() ?? 'pending',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'].toString())
          : DateTime.now(),
      notes: json['notes']?.toString(),
      userId: json['user_id']?.toString(),
    );
  }

  final String id;
  final String? supplierName;
  final List<PurchaseInvoiceItem> items;
  final double totalAmount;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? notes;
  final String? userId;

  // Calculated properties
  int get itemsCount => items.length;
  int get totalQuantity => items.fold<int>(0, (sum, item) => sum + item.quantity);
  double get totalYuanAmount => items.fold<double>(0.0, (sum, item) => sum + (item.yuanPrice * item.quantity));
  double get totalProfitAmount => items.fold<double>(0.0, (sum, item) => sum + item.totalProfitAmount);
  double get averageExchangeRate => items.isNotEmpty
      ? items.fold<double>(0.0, (sum, item) => sum + item.exchangeRate) / items.length
      : 0.0;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'supplier_name': supplierName,
      'items': items.map((item) => item.toJson()).toList(),
      'total_amount': totalAmount,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'notes': notes,
      'user_id': userId,
    };
  }

  PurchaseInvoice copyWith({
    String? id,
    String? supplierName,
    List<PurchaseInvoiceItem>? items,
    double? totalAmount,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? notes,
    String? userId,
  }) {
    return PurchaseInvoice(
      id: id ?? this.id,
      supplierName: supplierName ?? this.supplierName,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      notes: notes ?? this.notes,
      userId: userId ?? this.userId,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PurchaseInvoice && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'PurchaseInvoice(id: $id, supplierName: $supplierName, totalAmount: $totalAmount, status: $status)';
  }
}

/// Validation helper for purchase invoices
class PurchaseInvoiceValidator {
  static Map<String, dynamic> validateItem(PurchaseInvoiceItem item) {
    final errors = <String>[];

    if (item.productName.trim().isEmpty) {
      errors.add('اسم المنتج مطلوب');
    }

    if (item.yuanPrice <= 0) {
      errors.add('سعر اليوان يجب أن يكون أكبر من صفر');
    }

    if (item.exchangeRate <= 0) {
      errors.add('سعر الصرف يجب أن يكون أكبر من صفر');
    }

    if (item.profitMarginPercent < 0 || item.profitMarginPercent > 1000) {
      errors.add('هامش الربح يجب أن يكون بين 0% و 1000%');
    }

    if (item.quantity <= 0 || item.quantity > 9999) {
      errors.add('الكمية يجب أن تكون بين 1 و 9999');
    }

    // Note: 0% profit margin is explicitly allowed - no additional validation needed

    return {
      'isValid': errors.isEmpty,
      'errors': errors,
    };
  }

  static Map<String, dynamic> validateInvoice(PurchaseInvoice invoice) {
    final errors = <String>[];

    if (invoice.items.isEmpty) {
      errors.add('يجب إضافة عنصر واحد على الأقل للفاتورة');
    }

    // Validate each item
    for (final item in invoice.items) {
      final itemValidation = validateItem(item);
      if (!(itemValidation['isValid'] as bool)) {
        errors.addAll(itemValidation['errors'] as List<String>);
      }
    }

    if (invoice.totalAmount <= 0) {
      errors.add('إجمالي الفاتورة يجب أن يكون أكبر من صفر');
    }

    return {
      'isValid': errors.isEmpty,
      'errors': errors,
    };
  }
}
