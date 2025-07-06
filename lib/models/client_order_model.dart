

enum OrderStatus {
  pending,
  confirmed,
  processing,
  shipped,
  delivered,
  cancelled,
}

enum PaymentStatus {
  pending,
  paid,
  failed,
  refunded,
}

class TrackingLink {

  TrackingLink({
    required this.id,
    required this.url,
    required this.title,
    required this.description,
    required this.createdAt,
    required this.createdBy,
  });

  factory TrackingLink.fromJson(Map<String, dynamic> json) {
    return TrackingLink(
      id: (json['id'] as String?) ?? '',
      url: (json['url'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      createdAt: DateTime.parse((json['created_at'] as String?) ?? DateTime.now().toIso8601String()),
      createdBy: (json['created_by'] as String?) ?? '',
    );
  }
  final String id;
  final String url;
  final String title;
  final String description;
  final DateTime createdAt;
  final String createdBy;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'title': title,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'created_by': createdBy,
    };
  }
}

class OrderItem {

  OrderItem({
    this.id, // Add optional id field for database record ID
    required this.productId,
    required this.productName,
    required this.productImage,
    required this.price,
    required this.quantity,
    required this.total,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id']?.toString(), // Extract database record ID
      productId: (json['product_id'] as String?) ?? '',
      productName: (json['product_name'] as String?) ?? '',
      productImage: (json['product_image'] as String?) ?? '',
      price: ((json['unit_price'] as num?) ?? (json['price'] as num?) ?? 0).toDouble(), // Handle both unit_price and price
      quantity: (json['quantity'] as int?) ?? 0,
      total: ((json['subtotal'] as num?) ?? (json['total'] as num?) ?? 0).toDouble(), // Handle both subtotal and total
    );
  }

  final String? id; // Database record ID (UUID)
  final String productId;
  final String productName;
  final String productImage;
  final double price;
  final int quantity;
  final double total;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'product_name': productName,
      'product_image': productImage,
      'price': price,
      'quantity': quantity,
      'total': total,
    };
  }
}

class ClientOrder { // Role of assigned user

  ClientOrder({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.clientEmail,
    required this.clientPhone,
    required this.items,
    required this.total,
    required this.status,
    required this.paymentStatus,
    required this.createdAt,
    this.updatedAt,
    this.notes,
    this.shippingAddress,
    required this.trackingLinks,
    this.assignedTo,
    this.assignedUserName,
    this.assignedUserRole,
    this.pricingStatus,
    this.pricingApprovedBy,
    this.pricingApprovedAt,
    this.pricingNotes,
    this.metadata,
  });

  factory ClientOrder.fromJson(Map<String, dynamic> json) {
    return ClientOrder(
      id: (json['id'] as String?) ?? '',
      clientId: (json['client_id'] as String?) ?? '',
      clientName: (json['client_name'] as String?) ?? '',
      clientEmail: (json['client_email'] as String?) ?? '',
      clientPhone: (json['client_phone'] as String?) ?? '',
      items: ((json['items'] as List<dynamic>?) ?? (json['client_order_items'] as List<dynamic>?))
          ?.map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
          .toList() ?? [],
      total: ((json['total'] as num?) ?? 0).toDouble(),
      status: OrderStatus.values.firstWhere(
        (e) => e.toString().split('.').last == ((json['status'] as String?) ?? 'pending'),
        orElse: () => OrderStatus.pending,
      ),
      paymentStatus: PaymentStatus.values.firstWhere(
        (e) => e.toString().split('.').last == ((json['payment_status'] as String?) ?? 'pending'),
        orElse: () => PaymentStatus.pending,
      ),
      createdAt: DateTime.parse((json['created_at'] as String?) ?? DateTime.now().toIso8601String()),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
      notes: json['notes'] as String?,
      shippingAddress: json['shipping_address'] as String?,
      trackingLinks: (json['tracking_links'] as List<dynamic>?)
          ?.map((link) => TrackingLink.fromJson(link as Map<String, dynamic>))
          .toList() ?? [],
      assignedTo: json['assigned_to'] as String?,
      assignedUserName: json['assigned_user_name'] as String?,
      assignedUserRole: json['assigned_user_role'] as String?,
      pricingStatus: json['pricing_status'] as String?,
      pricingApprovedBy: json['pricing_approved_by'] as String?,
      pricingApprovedAt: json['pricing_approved_at'] != null
          ? DateTime.parse(json['pricing_approved_at'] as String)
          : null,
      pricingNotes: json['pricing_notes'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
  final String id;
  final String clientId;
  final String clientName;
  final String clientEmail;
  final String clientPhone;
  final List<OrderItem> items;
  final double total;
  final OrderStatus status;
  final PaymentStatus paymentStatus;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? notes;
  final String? shippingAddress;
  final List<TrackingLink> trackingLinks;
  final String? assignedTo; // Admin/Accountant who handles this order
  final String? assignedUserName; // Name of assigned user
  final String? assignedUserRole;

  // Pricing approval fields
  final String? pricingStatus; // pending_pricing, pricing_approved, pricing_rejected
  final String? pricingApprovedBy; // User ID who approved pricing
  final DateTime? pricingApprovedAt; // When pricing was approved
  final String? pricingNotes; // Notes from pricing approval
  final Map<String, dynamic>? metadata; // Additional metadata including requires_pricing_approval

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client_id': clientId,
      'client_name': clientName,
      'client_email': clientEmail,
      'client_phone': clientPhone,
      'items': items.map((item) => item.toJson()).toList(),
      'total': total,
      'status': status.toString().split('.').last,
      'payment_status': paymentStatus.toString().split('.').last,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'notes': notes,
      'shipping_address': shippingAddress,
      'tracking_links': trackingLinks.map((link) => link.toJson()).toList(),
      'assigned_to': assignedTo,
      'assigned_user_name': assignedUserName,
      'assigned_user_role': assignedUserRole,
      'pricing_status': pricingStatus,
      'pricing_approved_by': pricingApprovedBy,
      'pricing_approved_at': pricingApprovedAt?.toIso8601String(),
      'pricing_notes': pricingNotes,
      'metadata': metadata,
    };
  }

  String get statusText {
    switch (status) {
      case OrderStatus.pending:
        return 'في انتظار التأكيد';
      case OrderStatus.confirmed:
        return 'تم التأكيد';
      case OrderStatus.processing:
        return 'قيد التجهيز';
      case OrderStatus.shipped:
        return 'تم الشحن';
      case OrderStatus.delivered:
        return 'تم التسليم';
      case OrderStatus.cancelled:
        return 'ملغي';
    }
  }

  String get paymentStatusText {
    switch (paymentStatus) {
      case PaymentStatus.pending:
        return 'في انتظار الدفع';
      case PaymentStatus.paid:
        return 'تم الدفع';
      case PaymentStatus.failed:
        return 'فشل الدفع';
      case PaymentStatus.refunded:
        return 'تم الاسترداد';
    }
  }

  ClientOrder copyWith({
    String? id,
    String? clientId,
    String? clientName,
    String? clientEmail,
    String? clientPhone,
    List<OrderItem>? items,
    double? total,
    OrderStatus? status,
    PaymentStatus? paymentStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? notes,
    String? shippingAddress,
    List<TrackingLink>? trackingLinks,
    String? assignedTo,
    String? assignedUserName,
    String? assignedUserRole,
    String? pricingStatus,
    String? pricingApprovedBy,
    DateTime? pricingApprovedAt,
    String? pricingNotes,
    Map<String, dynamic>? metadata,
  }) {
    return ClientOrder(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      clientEmail: clientEmail ?? this.clientEmail,
      clientPhone: clientPhone ?? this.clientPhone,
      items: items ?? this.items,
      total: total ?? this.total,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      notes: notes ?? this.notes,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      trackingLinks: trackingLinks ?? this.trackingLinks,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedUserName: assignedUserName ?? this.assignedUserName,
      assignedUserRole: assignedUserRole ?? this.assignedUserRole,
      pricingStatus: pricingStatus ?? this.pricingStatus,
      pricingApprovedBy: pricingApprovedBy ?? this.pricingApprovedBy,
      pricingApprovedAt: pricingApprovedAt ?? this.pricingApprovedAt,
      pricingNotes: pricingNotes ?? this.pricingNotes,
      metadata: metadata ?? this.metadata,
    );
  }

  // Helper methods for pricing approval
  bool get requiresPricingApproval {
    return metadata?['requires_pricing_approval'] == true;
  }

  bool get isPendingPricing {
    return pricingStatus == 'pending_pricing';
  }

  bool get isPricingApproved {
    return pricingStatus == 'pricing_approved';
  }

  bool get isPricingRejected {
    return pricingStatus == 'pricing_rejected';
  }

  String get pricingStatusText {
    switch (pricingStatus) {
      case 'pending_pricing':
        return 'في انتظار اعتماد التسعير';
      case 'pricing_approved':
        return 'تم اعتماد التسعير';
      case 'pricing_rejected':
        return 'تم رفض التسعير';
      default:
        return 'غير محدد';
    }
  }
}
