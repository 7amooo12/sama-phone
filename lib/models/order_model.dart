import 'package:flutter/foundation.dart';
import 'package:smartbiztracker_new/models/product_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OrderModel {
  final String id;
  final String orderNumber;
  final String customerName;
  final String? customerPhone;
  final String status;
  final double totalAmount;
  final List<OrderItem> items;
  final DateTime createdAt;
  final DateTime? deliveryDate;
  final String? notes;
  final String? paymentMethod;
  final String? address;
  final String? assignedTo;
  final String? trackingNumber;
  final String? clientId;
  final String? warehouseName;
  final String? workerId;
  final DateTime? updatedAt;
  
  // Additional properties for client orders screen compatibility
  DateTime get date => createdAt;
  double get total => totalAmount;
  String? get warehouse_name => warehouseName;
  String? get shippingAddress => address;

  OrderModel({
    required this.id,
    required this.orderNumber,
    required this.customerName,
    this.customerPhone,
    required this.status,
    required this.totalAmount,
    required this.items,
    required this.createdAt,
    this.deliveryDate,
    this.notes,
    this.paymentMethod,
    this.address,
    this.assignedTo,
    this.trackingNumber,
    this.clientId,
    this.warehouseName,
    this.workerId,
    this.updatedAt,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id']?.toString() ?? '',
      orderNumber: json['order_number']?.toString() ?? '',
      customerName: json['customer_name']?.toString() ?? '',
      customerPhone: json['customer_phone']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      totalAmount: double.tryParse(json['total_amount']?.toString() ?? '0') ?? 0.0,
      items: (json['items'] as List<dynamic>?)
          ?.map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
          .toList() ?? [],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
      deliveryDate: json['delivery_date'] != null
          ? DateTime.parse(json['delivery_date'].toString())
          : null,
      notes: json['notes']?.toString(),
      paymentMethod: json['payment_method']?.toString(),
      address: json['address']?.toString(),
      assignedTo: json['assigned_to']?.toString(),
      trackingNumber: json['tracking_number']?.toString(),
      clientId: json['client_id']?.toString(),
      warehouseName: json['warehouse_name']?.toString(),
      workerId: json['worker_id']?.toString(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_number': orderNumber,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'status': status,
      'total_amount': totalAmount,
      'items': items.map((item) => item.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'delivery_date': deliveryDate?.toIso8601String(),
      'notes': notes,
      'payment_method': paymentMethod,
      'address': address,
      'assigned_to': assignedTo,
      'tracking_number': trackingNumber,
      'client_id': clientId,
      'warehouse_name': warehouseName,
      'worker_id': workerId,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toMap() => toJson();
  
  static OrderModel fromMap(Map<String, dynamic> map) => OrderModel.fromJson(map);

  OrderModel copyWith({
    String? id,
    String? orderNumber,
    String? customerName,
    String? customerPhone,
    String? status,
    double? totalAmount,
    List<OrderItem>? items,
    DateTime? createdAt,
    DateTime? deliveryDate,
    String? notes,
    String? paymentMethod,
    String? address,
    String? assignedTo,
    String? trackingNumber,
    String? clientId,
    String? warehouseName,
    String? workerId,
    DateTime? updatedAt,
  }) {
    return OrderModel(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      status: status ?? this.status,
      totalAmount: totalAmount ?? this.totalAmount,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      notes: notes ?? this.notes,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      address: address ?? this.address,
      assignedTo: assignedTo ?? this.assignedTo,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      clientId: clientId ?? this.clientId,
      warehouseName: warehouseName ?? this.warehouseName,
      workerId: workerId ?? this.workerId,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OrderModel(
      id: doc.id,
      orderNumber: data['order_number'] as String,
      customerName: data['customer_name'] as String,
      customerPhone: data['customer_phone'] as String?,
      status: data['status'] as String,
      totalAmount: (data['total_amount'] as num).toDouble(),
      items: (data['items'] as List).map((item) => OrderItem.fromJson(item as Map<String, dynamic>)).toList(),
      createdAt: (data['created_at'] as Timestamp).toDate(),
      deliveryDate: data['delivery_date'] != null ? (data['delivery_date'] as Timestamp).toDate() : null,
      notes: data['notes'] as String?,
      paymentMethod: data['payment_method'] as String?,
      address: data['address'] as String?,
      assignedTo: data['assigned_to'] as String?,
      trackingNumber: data['tracking_number'] as String?,
      clientId: data['client_id'] as String?,
      warehouseName: data['warehouse_name'] as String?,
      workerId: data['worker_id'] as String?,
      updatedAt: data['updated_at'] != null ? (data['updated_at'] as Timestamp).toDate() : null,
    );
  }
}

class OrderItem {
  final String id;
  final String productId;
  final String productName;
  final int quantity;
  final double price;
  final double purchasePrice;
  final double subtotal;
  final String? imageUrl;
  final String? notes;
  final ProductModel? product;

  OrderItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    this.purchasePrice = 0.0,
    required this.subtotal,
    this.imageUrl,
    this.notes,
    this.product,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      productName: json['product_name'] as String,
      quantity: json['quantity'] as int,
      price: (json['price'] as num).toDouble(),
      purchasePrice: (json['purchase_price'] as num?)?.toDouble() ?? 0.0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? ((json['price'] as num).toDouble() * (json['quantity'] as int)),
      imageUrl: json['image_url'] as String?,
      notes: json['notes'] as String?,
      product: json['product'] != null ? ProductModel.fromJson(json['product'] as Map<String, dynamic>) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'price': price,
      'purchase_price': purchasePrice,
      'subtotal': subtotal,
      'image_url': imageUrl,
      'notes': notes,
      'product': product?.toJson(),
    };
  }

  OrderItem copyWith({
    String? id,
    String? productId,
    String? productName,
    int? quantity,
    double? price,
    double? purchasePrice,
    double? subtotal,
    String? imageUrl,
    String? notes,
    ProductModel? product,
  }) {
    return OrderItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      subtotal: subtotal ?? this.subtotal,
      imageUrl: imageUrl ?? this.imageUrl,
      notes: notes ?? this.notes,
      product: product ?? this.product,
    );
  }
}

class OrderStatus {
  static const String pending = 'pending';
  static const String confirmed = 'confirmed';
  static const String inProduction = 'in_production';
  static const String readyForShipping = 'ready_for_shipping';
  static const String shipped = 'shipped';
  static const String delivered = 'delivered';
  static const String cancelled = 'cancelled';
  static const String onHold = 'on_hold';
  static const String processing = 'processing';
  static const String returned = 'returned';
  static const String canceled = 'canceled';

  // Arabic status values
  static const String arPending = 'قيد الانتظار';
  static const String arProcessing = 'قيد المعالجة';
  static const String arShipped = 'تم الشحن';
  static const String arDelivered = 'تم التسليم';
  static const String arCancelled = 'ملغي';

  // Add uppercase constants for backward compatibility
  @Deprecated('Use lowercase pending instead')
  static const String PENDING = pending;
  @Deprecated('Use lowercase confirmed instead')
  static const String CONFIRMED = confirmed;
  @Deprecated('Use lowercase inProduction instead')
  static const String IN_PRODUCTION = inProduction;
  @Deprecated('Use lowercase readyForShipping instead')
  static const String READY_FOR_SHIPPING = readyForShipping;
  @Deprecated('Use lowercase shipped instead')
  static const String SHIPPED = shipped;
  @Deprecated('Use lowercase delivered instead')
  static const String DELIVERED = delivered;
  @Deprecated('Use lowercase cancelled instead')
  static const String CANCELLED = cancelled;
  @Deprecated('Use lowercase onHold instead')
  static const String ON_HOLD = onHold;
  @Deprecated('Use lowercase processing instead')
  static const String PROCESSING = processing;
  @Deprecated('Use lowercase returned instead')
  static const String RETURNED = returned;
  @Deprecated('Use lowercase canceled instead')
  static const String CANCELED = canceled;
}

class OrderPriority {
  static const String low = 'low';
  static const String medium = 'medium';
  static const String high = 'high';
  static const String rush = 'rush';

  static const List<String> values = [low, medium, high, rush];
}

class PaymentMethod {
  static const String cash = 'cash';
  static const String creditCard = 'credit_card';
  static const String bankTransfer = 'bank_transfer';
  static const String cheque = 'cheque';
  static const String online = 'online';
  static const String other = 'other';

  static const List<String> values = [
    cash,
    creditCard,
    bankTransfer,
    cheque,
    online,
    other
  ];
}
