import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';


class OrderModel {

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
    this.itemsCount,
    this.progress,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    // التحقق من أن json ليس null
    debugPrint('OrderModel.fromJson with data: ${json.keys.join(', ')}');

    List<OrderItem> orderItems = [];

    // Handle items array from API
    if (json['items'] != null) {
      try {
        final itemsList = json['items'] as List?;
        if (itemsList != null && itemsList.isNotEmpty) {
          orderItems = itemsList
              .where((item) => item != null) // تجاهل العناصر الفارغة
              .map((item) => OrderItem.fromJson(item is Map<String, dynamic>
                  ? item
                  : Map<String, dynamic>.from(item as Map<dynamic, dynamic>)))
              .toList();
          debugPrint('Parsed ${orderItems.length} order items from items array');
        }
      } catch (e) {
        debugPrint('Error parsing order items: $e');
        // Create a placeholder item if parsing fails
        orderItems = [
          OrderItem(
            id: 'error',
            productId: '',
            productName: 'Error parsing items',
            description: 'حدث خطأ في تحليل عناصر الطلب',
            price: 0,
            quantity: 1,
            subtotal: 0,
          )
        ];
      }
    }
    // Handle items_count field
    else if (json['items_count'] != null) {
      debugPrint('Using items_count: ${json['items_count']} - will need to fetch detailed items later');

      // For admin dashboard, we'll leave the items array empty and let the
      // StockWarehouseApiService.getOrderDetail() method fetch the detailed items later.
      // But we'll log that we need to fetch items later
      debugPrint('This order has ${json['items_count']} items that need to be fetched with getOrderDetail()');

      // Don't create placeholder items here, as they will be populated by getOrderDetail()
    }

    // Extract order progress if available
    double? progress;
    if (json['progress'] != null) {
      try {
        if (json['progress'] is num) {
          progress = (json['progress'] as num).toDouble();
        } else if (json['progress'] is String) {
          progress = double.tryParse(json['progress'].toString());
        }
      } catch (e) {
        debugPrint('Error parsing progress: $e');
      }
    } else if (json['overall_progress'] != null) {
      try {
        if (json['overall_progress'] is num) {
          progress = (json['overall_progress'] as num).toDouble();
        } else if (json['overall_progress'] is String) {
          progress = double.tryParse(json['overall_progress'].toString());
        }
      } catch (e) {
        debugPrint('Error parsing overall_progress: $e');
      }
    }

    // Extract items count if available
    int? itemsCount;
    if (json['items_count'] != null) {
      try {
        if (json['items_count'] is num) {
          itemsCount = (json['items_count'] as num).toInt();
        } else if (json['items_count'] is String) {
          itemsCount = int.tryParse(json['items_count'].toString());
        }
      } catch (e) {
        debugPrint('Error parsing items_count: $e');
      }
    }

    // Extract warehouse name if available
    String? warehouseName;
    if (json['warehouse_name'] != null) {
      warehouseName = json['warehouse_name'].toString();
    } else if (json['warehouse'] != null) {
      if (json['warehouse'] is Map) {
        final warehouse = json['warehouse'] as Map?;
        if (warehouse != null && warehouse['name'] != null) {
          warehouseName = warehouse['name'].toString();
        }
      } else if (json['warehouse'] is String) {
        warehouseName = json['warehouse'].toString();
      }
    }

    // Extract customer data
    String customerName = '';
    String customerPhone = '';

    if (json['customer_name'] != null) {
      customerName = json['customer_name'].toString();
    } else if (json['customer'] != null) {
      if (json['customer'] is Map) {
        final customer = json['customer'] as Map?;
        if (customer != null) {
          customerName = customer['name']?.toString() ?? '';
          customerPhone = customer['phone']?.toString() ?? '';
        }
      } else if (json['customer'] is String) {
        customerName = json['customer'].toString();
      }
    }

    // Extract order number
    String orderNumber = '';
    if (json['order_number'] != null) {
      orderNumber = json['order_number'].toString();
    } else if (json['number'] != null) {
      orderNumber = json['number'].toString();
    } else if (json['id'] != null) {
      orderNumber = 'ORD-${json['id']}';
    } else {
      // إنشاء رقم طلب عشوائي إذا لم يكن موجودًا
      orderNumber = 'ORD-${DateTime.now().millisecondsSinceEpoch}';
    }

    debugPrint('Creating OrderModel with orderNumber: $orderNumber, status: ${json['status'] ?? 'null'}');

    // Extract order status
    String status = 'pending';
    if (json['status'] != null) {
      status = json['status'].toString();
    } else if (json['order_status'] != null) {
      status = json['order_status'].toString();
    } else if (json['state'] != null) {
      status = json['state'].toString();
    }

    // Extract total amount
    double totalAmount = 0.0;
    if (json['total_amount'] != null) {
      totalAmount = _parseDoubleFromJson(json, 'total_amount');
    } else if (json['total'] != null) {
      totalAmount = _parseDoubleFromJson(json, 'total');
    } else if (json['amount'] != null) {
      totalAmount = _parseDoubleFromJson(json, 'amount');
    }

    // Calculate total from items if we have items but no total amount
    if (totalAmount == 0.0 && orderItems.isNotEmpty) {
      // Only calculate if items have valid subtotals
      final bool hasValidSubtotals = orderItems.any((item) => item.subtotal > 0);
      if (hasValidSubtotals) {
        totalAmount = orderItems.fold(0.0, (total, item) => total + item.subtotal);
      }
    }

    // تأكد من وجود معرف
    String id = '';
    if (json['id'] != null) {
      id = json['id'].toString();
    } else {
      // إنشاء معرف عشوائي إذا لم يكن موجودًا
      id = DateTime.now().millisecondsSinceEpoch.toString();
    }

    // تحليل التواريخ بشكل آمن
    DateTime? createdAt = _parseDateTimeFromJson(json, 'created_at') ??
                         _parseDateTimeFromJson(json, 'date');

    // استخدام الوقت الحالي إذا لم يكن هناك تاريخ إنشاء
    createdAt ??= DateTime.now();

    return OrderModel(
      id: id,
      orderNumber: orderNumber,
      customerName: customerName,
      customerPhone: customerPhone,
      status: status,
      totalAmount: totalAmount,
      items: orderItems,
      createdAt: createdAt,
      deliveryDate: _parseDateTimeFromJson(json, 'delivery_date') ??
                   _parseDateTimeFromJson(json, 'expected_delivery'),
      notes: json['notes']?.toString() ?? json['comments']?.toString(),
      paymentMethod: json['payment_method']?.toString(),
      address: json['address']?.toString() ?? json['shipping_address']?.toString(),
      assignedTo: json['assigned_to']?.toString() ?? json['worker']?.toString(),
      trackingNumber: json['tracking_token']?.toString() ?? json['tracking_number']?.toString(),
      clientId: json['customer'] is Map ? (json['customer'] as Map)['id']?.toString() : null,
      warehouseName: warehouseName,
      itemsCount: itemsCount,
      progress: progress,
    );
  }
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
  final int? itemsCount;
  final double? progress;

  // Additional properties for client orders screen compatibility
  DateTime get date => createdAt;
  double get total => totalAmount;
  String? get warehouseNameCompat => warehouseName;
  String? get warehouse_name => warehouseName; // Compatibility getter
  String? get shippingAddress => address;

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
    int? itemsCount,
    double? progress,
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
      itemsCount: itemsCount ?? this.itemsCount,
      progress: progress ?? this.progress,
    );
  }

  // Helper method to parse double values from different format possibilities
  static double _parseDoubleFromJson(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return 0.0;

    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;

    return 0.0;
  }

  // Helper method to parse DateTime values from different format possibilities
  static DateTime? _parseDateTimeFromJson(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;

    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }

    if (value is Timestamp) {
      return value.toDate();
    }

    return null;
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
      'items_count': itemsCount,
      'progress': progress,
    };
  }

  Map<String, dynamic> toMap() => toJson();

  static OrderModel fromMap(Map<String, dynamic> map) {
    List<OrderItem> orderItems = [];
    if (map['items'] != null) {
      try {
        final itemsList = map['items'] as List?;
        if (itemsList != null && itemsList.isNotEmpty) {
          orderItems = itemsList
              .where((item) => item != null)
              .map((item) => OrderItem.fromJson(item is Map<String, dynamic>
                  ? item
                  : Map<String, dynamic>.from(item as Map<dynamic, dynamic>)))
              .toList();
        }
      } catch (e) {
        debugPrint('Error parsing order items in fromMap: $e');
      }
    }

    return OrderModel(
      id: map['id']?.toString() ?? '',
      orderNumber: map['order_number']?.toString() ?? '',
      customerName: map['customer_name']?.toString() ?? '',
      customerPhone: map['customer_phone']?.toString(),
      status: map['status']?.toString() ?? 'pending',
      totalAmount: double.tryParse(map['total_amount']?.toString() ?? '0') ?? 0.0,
      items: orderItems,
      createdAt: map['created_at'] != null
          ? map['created_at'] is Timestamp
            ? (map['created_at'] as Timestamp).toDate()
            : DateTime.parse(map['created_at'].toString())
          : DateTime.now(),
      deliveryDate: map['delivery_date'] != null
          ? map['delivery_date'] is Timestamp
            ? (map['delivery_date'] as Timestamp).toDate()
            : DateTime.parse(map['delivery_date'].toString())
          : null,
      notes: map['notes']?.toString(),
      paymentMethod: map['payment_method']?.toString(),
      address: map['address']?.toString(),
      assignedTo: map['assigned_to']?.toString(),
      trackingNumber: map['tracking_number']?.toString(),
      clientId: map['client_id']?.toString(),
      warehouseName: map['warehouse_name']?.toString(),
      itemsCount: map['items_count'] != null ? int.tryParse(map['items_count'].toString()) : null,
      progress: map['progress'] != null ? double.tryParse(map['progress'].toString()) : null,
    );
  }
}

class OrderItem {

  OrderItem({
    required this.id,
    required this.productId,
    required this.productName,
    this.description,  // إضافة الوصف كمعامل اختياري
    required this.price,
    this.purchasePrice = 0.0,  // default value
    required this.quantity,
    required this.subtotal,
    this.imageUrl,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    // التحقق من أن json ليس null
    debugPrint('OrderItem.fromJson with data: ${json.keys.join(', ')}');

    // Extract product name - multiple possible field names
    String productName = '';
    if (json['name'] != null) {
      productName = json['name'].toString();
    } else if (json['product_name'] != null) {
      productName = json['product_name'].toString();
    } else if (json['title'] != null) {
      productName = json['title'].toString();
    } else if (json['description'] != null) {
      productName = json['description'].toString();
    } else {
      productName = 'Unnamed Item';
    }

    // Extract product ID - multiple possible field names
    String productId = '';
    if (json['product_id'] != null) {
      productId = json['product_id'].toString();
    } else if (json['id'] != null) {
      productId = json['id'].toString();
    } else if (json['sku'] != null) {
      productId = json['sku'].toString();
    }

    // Parse quantities - supporting different field names
    int quantity = 1;
    try {
      if (json['quantity_requested'] != null) {
        quantity = _parseIntFromJson(json, 'quantity_requested');
      } else if (json['quantity'] != null) {
        quantity = _parseIntFromJson(json, 'quantity');
      } else if (json['qty'] != null) {
        quantity = _parseIntFromJson(json, 'qty');
      }
    } catch (e) {
      debugPrint('Error parsing quantity: $e');
    }



    // Extract image URL
    String? imageUrl;
    if (json['image_url'] != null) {
      imageUrl = json['image_url'].toString();
    } else if (json['image'] != null) {
      imageUrl = json['image'].toString();
    } else if (json['thumbnail'] != null) {
      imageUrl = json['thumbnail'].toString();
    }

    // Extract price - multiple possible field names
    double price = 0.0;
    try {
      if (json['price'] != null) {
        price = _parseDoubleFromJson(json, 'price');
      } else if (json['unit_price'] != null) {
        price = _parseDoubleFromJson(json, 'unit_price');
      } else if (json['sale_price'] != null) {
        price = _parseDoubleFromJson(json, 'sale_price');
      }
    } catch (e) {
      debugPrint('Error parsing price: $e');
    }

    // Extract purchase price if available
    double purchasePrice = 0.0;
    try {
      if (json['purchase_price'] != null) {
        purchasePrice = _parseDoubleFromJson(json, 'purchase_price');
      } else if (json['cost'] != null) {
        purchasePrice = _parseDoubleFromJson(json, 'cost');
      }
    } catch (e) {
      debugPrint('Error parsing purchase_price: $e');
    }

    // Calculate subtotal
    double subtotal = 0.0;
    try {
      if (json['subtotal'] != null) {
        subtotal = _parseDoubleFromJson(json, 'subtotal');
      } else if (json['total'] != null) {
        subtotal = _parseDoubleFromJson(json, 'total');
      } else if (json['line_total'] != null) {
        subtotal = _parseDoubleFromJson(json, 'line_total');
      } else {
        // Calculate from price and quantity
        subtotal = price * quantity;
      }
    } catch (e) {
      debugPrint('Error calculating subtotal: $e');
      // Fallback to price * quantity
      subtotal = price * quantity;
    }

    // Ensure we have a valid ID
    String id = '';
    if (json['id'] != null) {
      id = json['id'].toString();
    } else if (productId.isNotEmpty) {
      id = productId;
    } else {
      // Generate a random ID if none is available
      id = DateTime.now().millisecondsSinceEpoch.toString();
    }

    // Extract description
    String? description;
    if (json['description'] != null && json['description'].toString().isNotEmpty) {
      description = json['description'].toString();
    }

    return OrderItem(
      id: id,
      productId: productId,
      productName: productName,
      description: description,
      price: price,
      purchasePrice: purchasePrice,
      quantity: quantity,
      subtotal: subtotal,
      imageUrl: imageUrl,
    );
  }
  final String id;
  final String productId;
  final String productName;
  final String? description;  // إضافة خاصية الوصف
  final double price;  // سعر البيع
  final double purchasePrice; // سعر الشراء
  final int quantity;
  final double subtotal;
  final String? imageUrl;

  // Helper method to parse integer values from different format possibilities
  static int _parseIntFromJson(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return 0;

    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;

    return 0;
  }

  // Helper method to parse double values from different format possibilities
  static double _parseDoubleFromJson(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return 0.0;

    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;

    return 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'name': productName,
      'description': description,
      'price': price,
      'purchase_price': purchasePrice,
      'quantity': quantity,
      'subtotal': subtotal,
      'image_url': imageUrl,
    };
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
