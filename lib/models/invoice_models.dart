import 'dart:convert';

/// Model for invoice items
class InvoiceItem {

  const InvoiceItem({
    required this.id,
    required this.productId,
    required this.productName,
    this.productImage,
    this.category,
    required this.unitPrice,
    required this.quantity,
    required this.subtotal,
    this.notes,
  });

  factory InvoiceItem.fromProduct({
    required String productId,
    required String productName,
    String? productImage,
    String? category,
    required double unitPrice,
    required int quantity,
    String? notes,
  }) {
    final subtotal = unitPrice * quantity;
    return InvoiceItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      productId: productId,
      productName: productName,
      productImage: productImage,
      category: category,
      unitPrice: unitPrice,
      quantity: quantity,
      subtotal: subtotal,
      notes: notes,
    );
  }

  factory InvoiceItem.fromJson(Map<String, dynamic> json) {
    return InvoiceItem(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      productId: json['product_id']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? 'Unknown Product',
      productImage: json['product_image']?.toString(),
      category: json['category']?.toString(),
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes']?.toString(),
    );
  }
  final String id;
  final String productId;
  final String productName;
  final String? productImage;
  final String? category;
  final double unitPrice;
  final int quantity;
  final double subtotal;
  final String? notes;

  InvoiceItem copyWith({
    String? id,
    String? productId,
    String? productName,
    String? productImage,
    String? category,
    double? unitPrice,
    int? quantity,
    double? subtotal,
    String? notes,
  }) {
    return InvoiceItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productImage: productImage ?? this.productImage,
      category: category ?? this.category,
      unitPrice: unitPrice ?? this.unitPrice,
      quantity: quantity ?? this.quantity,
      subtotal: subtotal ?? (unitPrice ?? this.unitPrice) * (quantity ?? this.quantity),
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'product_name': productName,
      'product_image': productImage,
      'category': category,
      'unit_price': unitPrice,
      'quantity': quantity,
      'subtotal': subtotal,
      'notes': notes,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InvoiceItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Model for invoice
class Invoice {

  const Invoice({
    required this.id,
    required this.customerName,
    this.customerPhone,
    this.customerEmail,
    this.customerAddress,
    required this.items,
    required this.subtotal,
    required this.taxAmount,
    required this.discount,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
    this.notes,
    this.pdfUrl,
  });

  factory Invoice.create({
    required String customerName,
    String? customerPhone,
    String? customerEmail,
    String? customerAddress,
    required List<InvoiceItem> items,
    double discount = 0.0,
    String? notes,
  }) {
    final subtotal = items.fold<double>(0.0, (sum, item) => sum + item.subtotal);
    final totalAmount = subtotal - discount; // No tax calculation

    return Invoice(
      id: 'INV-${DateTime.now().millisecondsSinceEpoch}',
      customerName: customerName,
      customerPhone: customerPhone,
      customerEmail: customerEmail,
      customerAddress: customerAddress,
      items: items,
      subtotal: subtotal,
      taxAmount: 0.0, // No tax
      discount: discount,
      totalAmount: totalAmount,
      status: 'pending',
      createdAt: DateTime.now(),
      notes: notes,
    );
  }

  factory Invoice.fromJson(Map<String, dynamic> json) {
    try {
      // Handle items - can be List or String (for backward compatibility)
      List<InvoiceItem> items = [];
      final itemsData = json['items'];
      if (itemsData != null) {
        if (itemsData is List) {
          items = itemsData
              .map((item) => InvoiceItem.fromJson(item as Map<String, dynamic>))
              .toList();
        } else if (itemsData is String) {
          // Handle legacy string format
          final decoded = jsonDecode(itemsData) as List;
          items = decoded
              .map((item) => InvoiceItem.fromJson(item as Map<String, dynamic>))
              .toList();
        }
      }

      return Invoice(
        id: json['id']?.toString() ?? '',
        customerName: json['customer_name']?.toString() ?? '',
        customerPhone: json['customer_phone']?.toString(),
        customerEmail: json['customer_email']?.toString(),
        customerAddress: json['customer_address']?.toString(),
        items: items,
        subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
        taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0.0,
        discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
        totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
        status: json['status']?.toString() ?? 'draft',
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'].toString())
            : DateTime.now(),
        notes: json['notes']?.toString(),
        pdfUrl: json['pdf_url']?.toString(),
      );
    } catch (e) {
      // Log error and return a default invoice to prevent crashes
      // Error parsing invoice JSON - using fallback values
      return Invoice(
        id: json['id']?.toString() ?? 'ERROR',
        customerName: json['customer_name']?.toString() ?? 'Unknown Customer',
        items: [],
        subtotal: 0.0,
        taxAmount: 0.0,
        discount: 0.0,
        totalAmount: 0.0,
        status: 'error',
        createdAt: DateTime.now(),
      );
    }
  }
  final String id;
  final String customerName;
  final String? customerPhone;
  final String? customerEmail;
  final String? customerAddress;
  final List<InvoiceItem> items;
  final double subtotal;
  final double taxAmount;
  final double discount;
  final double totalAmount;
  final String status;
  final DateTime createdAt;
  final String? notes;
  final String? pdfUrl;

  Invoice copyWith({
    String? id,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? customerAddress,
    List<InvoiceItem>? items,
    double? subtotal,
    double? taxAmount,
    double? discount,
    double? totalAmount,
    String? status,
    DateTime? createdAt,
    String? notes,
    String? pdfUrl,
  }) {
    return Invoice(
      id: id ?? this.id,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerEmail: customerEmail ?? this.customerEmail,
      customerAddress: customerAddress ?? this.customerAddress,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      taxAmount: taxAmount ?? this.taxAmount,
      discount: discount ?? this.discount,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      notes: notes ?? this.notes,
      pdfUrl: pdfUrl ?? this.pdfUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_email': customerEmail,
      'customer_address': customerAddress,
      'items': items.map((item) => item.toJson()).toList(),
      'subtotal': subtotal,
      'tax_amount': taxAmount,
      'discount': discount,
      'total_amount': totalAmount,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'notes': notes,
      'pdf_url': pdfUrl,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Invoice && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Model for product search results
class ProductSearchResult {

  const ProductSearchResult({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.availableQuantity,
    this.imageUrl,
    this.category,
    this.sku,
  });

  factory ProductSearchResult.fromJson(Map<String, dynamic> json) {
    return ProductSearchResult(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      availableQuantity: json['quantity'] as int? ?? 0,
      imageUrl: json['image_url'] as String? ?? json['imageUrl'] as String?,
      category: json['category'] as String?,
      sku: json['sku'] as String?,
    );
  }
  final String id;
  final String name;
  final String? description;
  final double price;
  final int availableQuantity;
  final String? imageUrl;
  final String? category;
  final String? sku;

  bool get inStock => availableQuantity > 0;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'quantity': availableQuantity,
      'image_url': imageUrl,
      'category': category,
      'sku': sku,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProductSearchResult && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
